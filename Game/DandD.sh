#!/usr/bin/env bash


# Capturar cualquier cosa que me cierre el juego culero para cerrar ffplay
cleanup() {
    pkill -f ffplay 2>/dev/null
}
trap cleanup EXIT
# Mini D&D con Inventario, Obstáculos y Mapa Descubierto

# Configuración del tablero 10x10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      easter_egg_activated=0 
player_pos=54
enemies_pos=(10 18 81)   # Posiciones de enemigos (añadí uno más para probar) ojo con esto facu y flor
declare -A enemies_hp
for pos in "${enemies_pos[@]}"; do enemies_hp[$pos]=8; done
turno=0
player_hp=10
next_attack_double=0

# Inventario
inventory=()

# Mapa de ítems: posición -> tipo (ej: H = Health)
declare -A items_map
items_map[22]="H"    # Poción de vida (Ahora la cerveza xd)
items_map[65]="A"    # Arma

# Mapa de paredes (1 = pared)
declare -A walls_map
for i in {0..9}; do
  walls_map[$((i*10+4))]=1
done
walls_map[34]=0
walls_map[54]=0
walls_map[74]=0
walls_map[77]=1
walls_map[78]=1
walls_map[79]=1
walls_map[80]=1

# Mapa de visibilidad (0 = no visible, 1 = visible)
declare -A visible_map #el -A es un array asocioativo, permite cargar números letras y otras cosas como strings y diccionarios

# Funcones de Guardado y Carga (Miren estos cambios gurises si no entienden algo consulten)

# Funcion para guardar la partida

# Los echo se pueden quitar son decorativos no afectan a la función
save_game() {
    local save_file="dnd_save.txt"
    echo "Guardando partida en $save_file..."

    # Guardar estado del jugador
    echo "player_pos=$player_pos" > "$save_file"
    echo "player_hp=$player_hp" >> "$save_file"
    echo "next_attack_double=$next_attack_double" >> "$save_file"

    # Guardar inventario
    echo "inventory=(${inventory[@]})" >> "$save_file"

    # Guardar enemigos y sus HP
    echo -n "enemies_pos=(" >> "$save_file"
    for pos in "${enemies_pos[@]}"; do
        echo -n "$pos " >> "$save_file"
    done
    echo ")" >> "$save_file"
    echo -n "enemies_hp=(" >> "$save_file"
    for pos in "${!enemies_hp[@]}"; do
        echo -n "[$pos]=${enemies_hp[$pos]} " >> "$save_file"
    done
    echo ")" >> "$save_file"

    # Guardar items activos (solo los que quedan en items_map)
    echo -n "items_map=(" >> "$save_file"
    for pos in "${!items_map[@]}"; do
        echo -n "[$pos]=\"${items_map[$pos]}\" " >> "$save_file"
    done
    echo ")" >> "$save_file"

    # Guardar paredes activas (solo las que son 1)
    echo -n "walls_map=(" >> "$save_file"
    for pos in "${!walls_map[@]}"; do
        if [[ ${walls_map[$pos]} == 1 ]]; then
            echo -n "[$pos]=1 " >> "$save_file"
        fi
    done
    echo ")" >> "$save_file"

    echo "Partida guardada con éxito."
    sleep 2
}

# Función para cargar la partida
load_game() {
    local save_file="dnd_save.txt"
    if [[ ! -f "$save_file" ]]; then
        echo "No se encontró un archivo de partida guardada ($save_file)."
        sleep 2
        return 1
    fi

    echo "Cargando partida desde $save_file..."
    source "$save_file"

    update_visibility
    turno=0 # Siempre comienza el turno del jugador al cargar

    echo "Partida cargada con éxito."
    sleep 2
    return 0
}

# Actualizar visión.

update_visibility() {
  local pr=$((player_pos / 10)) #pr es Player Row y pc Player columna
  local pc=$((player_pos % 10))
  for r in $((pr-2)) $((pr-1)) $pr $((pr+1)) $((pr+2)); do #for recorre un cuadro de 5x5 celdas centrado en el jugador: desde dos celdas arriba/izquierda hasta dos celdas abajo/derecha
    for c in $((pc-2)) $((pc-1)) $pc $((pc+1)) $((pc+2)); do
      if (( r >= 0 && r < 10 && c >= 0 && c < 10 )); then #if que se asegura de que la fila r y columna c estén dentro de los límites del tablero
        visible_map[$((r*10+c))]=1
      fi
    done
  done
}

# Función para encontrar enemigos adyacentes al jugador
adjacent_enemies() {
  local -a adjacent=() #la -a es un Array indexado o sea númerico
  for d in -10 10 -1 1; do #-10: una fila arriba (porque el tablero es 10 columnas ancho). 10: una fila abajo. -1: una celda a la izquierda. 1: una celda a la derecha.
    local adj_pos=$((player_pos + d)) #esto básicamente detecta si hay un enemigo cerca recorriendo el for
    if [[ -n "${enemies_hp[$adj_pos]}" ]]; then #si enemies_hp[$adj_pos] (el malo maloso) existe y tiene valor (vida del enemigo), el enemigo está ahí.
      adjacent+=("$adj_pos") #Esto confima que existe y le da valar a adjacent
    fi
  done
  echo "${adjacent[@]}"
}

draw_battlefield() {
  clear
  echo "     0  1  2  3  4  5  6  7  8  9           HUD" # Fila de números de columna

  local -a adjacent_enemies_array=($(adjacent_enemies))
  local enemy1_icon=""
  local enemy1_hp_display=""
  local enemy2_icon=""
  local enemy2_hp_display=""

  
  if [[ -n "${adjacent_enemies_array[0]}" ]]; then
    local enemy1_pos="${adjacent_enemies_array[0]}"
    enemy1_icon="|👹"
    enemy1_hp_display="HP: ${enemies_hp[$enemy1_pos]}/8"
  else
    enemy1_hp_display="No hay enemigo adyacente"
  fi


  if [[ -n "${adjacent_enemies_array[1]}" ]]; then
    local enemy2_pos="${adjacent_enemies_array[1]}"
    enemy2_icon="|👹"
    enemy2_hp_display="HP: ${enemies_hp[$enemy2_pos]}/8"
  fi

  # Dibujar el tablero y el HUD básico por separado
  for r in {0..9}; do
    printf "%2d   " "$r" # Número de fila
    for c in {0..9}; do
      idx=$((r*10+c))
      if [[ ${visible_map[$idx]} != 1 ]]; then
        printf "?  "
        continue
      fi
      if [[ ${walls_map[$idx]} == 1 ]]; then
        printf "#  "
      elif [[ $idx -eq $player_pos ]]; then
        printf "🧝 "
      elif [[ -n "${enemies_hp[$idx]}" ]]; then
        printf "👹 "
      elif [[ -n "${items_map[$idx]}" ]]; then
        case "${items_map[$idx]}" in #Estos son Case's donde cambian lo establecido en las variables de cada item o dibujo del mapa por emotes para dar mejor aspecto
          H) printf "🍺 " ;;
          A) printf "🗡️  " ;;
          *) printf "❓  " ;;
        esac
      else
        printf ".  "
      fi
    done

    # HUD a la derecha del tablero
    # Ajusta este espacio según sea necesario para la alineación
    local hud_offset="       " #xd me mamé fue la solución más rápida que hice avisen si no entienden gurises

    if (( r == 0 )); then
      # Muestra la información del primer enemigo
      printf "%s 🧝♥:%s  %s %s" "$hud_offset" "$player_hp" "$enemy1_icon" "$enemy1_hp_display"
    elif (( r == 1 )); then
      # Muestra la información del segundo enemigo
      printf "%s         %s %s" "$hud_offset" "$enemy2_icon" "$enemy2_hp_display"
    fi
    echo # Nueva línea después de cada fila del tablero y HUD
  done

  echo
  echo -n "🎒 Inventario: "
  if (( ${#inventory[@]} == 0 )); then
    echo "(vacío)"
  else
    for i in "${inventory[@]}"; do
      case "$i" in
        H) printf "🍺 " ;;
        A) printf "🗡️ " ;;
        *) printf "❓ " ;;
      esac
    done
    echo
  fi
}

are_adjacent() {
  local a=$1 b=$2 #Esta función recibe dos posiciones a y b (del 0 al 99) y devuelve si estas dos posiciones son adyacentes ortogonalmente (es decir, arriba, abajo, izquierda o derecha, no diagonales).
  local ar=$((a / 10)) ac=$((a % 10))
  local br=$((b / 10)) bc=$((b % 10))
  local dr=$((ar - br)) dc=$((ac - bc))
  (( dr < 0 )) && dr=$(( -dr ))
  (( dc < 0 )) && dc=$(( -dc ))
  (( dr + dc == 1 ))
}

distance() {
  local a=$1 b=$2 #lo mismo toma dos argumentos, las posiciones a y b.
  local ar=$((a / 10)) ac=$((a % 10)) #calcula la fila (ar) y columna (ac) de la posición a.
  local br=$((b / 10)) bc=$((b % 10)) #calcula la fila (br) y columna (bc) de la posición b.
  local dr=$((ar - br)) dc=$((ac - bc)) #calcula la diferencia en filas y columnas.
  (( dr < 0 )) && dr=$(( -dr )) #toma el valor absoluto de la diferencia en filas.
  (( dc < 0 )) && dc=$(( -dc )) #toma el valor absoluto de la diferencia en columnas.
  echo $((dr + dc))
}

can_move_to() {
  local pos=$1
  if (( pos < 0 || pos >= 100 )); then return 1; fi
  if [[ ${walls_map[$pos]} == 1 ]]; then return 1; fi
  if [[ -n "${enemies_hp[$pos]}" ]]; then return 1; fi
  return 0
}

check_for_item() {
  local idx=$1
  if [[ -n "${items_map[$idx]}" ]]; then ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/grab.ogg' > /dev/null 2>&1 & # Sonidito de encontrar un item
    item="${items_map[$idx]}"
    case "$item" in
      H) echo "Encontraste una 🍺 Hidromiel!" ;;
      A) echo "Encontraste una 🗡️ Arma afilada!" ;;
      *) echo "No se que encontraste" ;;
    esac
    inventory+=("$item")
    unset items_map[$idx]
    sleep 1
  fi
}

show_inventory() {
  echo
  echo "=== 🎒 Inventario ==="
  if (( ${#inventory[@]} == 0 )); then
    echo "Vacío"
    echo "Presiona una tecla para continuar..."
    read -n 1
    return 0 # Indica éxito, no cambia el turno del jugador principal (estaba pensando poner 2 player's pero no me animé)
  fi
  for i in "${!inventory[@]}"; do
    case "${inventory[$i]}" in
      H) echo "$((i+1)). 🍺 Hidromiel (Restaura HP)" ;;
      A) echo "$((i+1)). 🗡️ Arma" ;;
      *) echo "$((i+1)). ❓ Desconocido" ;;
    esac
  done
  echo
  echo "Ingresa el número del ítem que deseas usar, o ENTER para salir:"
  read -r choice
  [[ -z "$choice" ]] && return 0 # Regresar al menú sin usar nada, no cambia el turno

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#inventory[@]} )); then
    echo "Selección inválida."
    sleep 1
    return 1 # Indica que no se usó un ítem válido, el turno no debería avanzar
  fi
  idx=$((choice - 1))
  item="${inventory[$idx]}"
  case $item in
    H) ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/plop.ogg' > /dev/null 2>&1 & # Ruido de usar item 
      heal=$((RANDOM % 4 + 3))
      echo "🍺Usas una Hidromiel! te cura. +$heal HP."
      ((player_hp += heal))
      (( player_hp > 10 )) && player_hp=10
      ;;
    A) ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/plop.ogg' > /dev/null 2>&1 & # Ruido de usar item 
      echo "🗡️ Usas un arma. ¡Tu próximo ataque hará el doble de daño!"
      next_attack_double=1
      ;;
    *)
      echo "❓ No sabes cómo usar esto."
      return 1 # No se pudo usar, retorna error, el turno no debería avanzar
      ;;
  esac

  unset 'inventory[idx]'
  inventory=("${inventory[@]}")
  sleep 1
  return 0 # Indica que se usó un ítem con éxito
}

# Opciones de partida
game_options() {
    clear
    echo "=== Opciones de Partida ==="
    echo "1. Guardar partida"
    echo "2. Cerrar juego y guardar"
    echo "3. Cerrar juego sin guardar"
    echo "4. Volver al juego"
    echo
    echo "Elige una opción:"
    read -r choice

    case "$choice" in
        1)
            save_game
            return 1 # Indica que se guardó, pero el juego continúa
            ;;
        2)
            save_game
            if [[ -n "$FFPLAY_PID" ]]; then
              kill "$FFPLAY_PID" 2>/dev/null
                fi
            exit 0 # Sale del juego después de guardar
            
            ;;
        3)
            echo "Cerrando juego sin guardar..."
            sleep 1
            if [[ -n "$FFPLAY_PID" ]]; then
              kill "$FFPLAY_PID" 2>/dev/null
                fi
            exit 0 # Sale del juego sin guardar
            
            ;;
        4)
            return 1 # Vuelve al juego, no consume el turno
            ;;
        *)
            echo "Opción inválida."
            sleep 1
            return 1 # Vuelve al juego, no consume el turno
            ;;
    esac
}


player_turn() {
  echo "Movimiento (w/a/s/d), atacar (espacio), inventario (i), opciones (o):"
  IFS= read -rsn1 action
  local action_result=1 # Por defecto, la acción no es exitosa (1 para reintentar)

  case $action in
    w) new_pos=$((player_pos - 10)); if can_move_to "$new_pos"; then player_pos=$new_pos; ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/move.ogg' > /dev/null 2>&1 & action_result=0; else echo "❌ ¡Hay una pared en esa dirección!"; sleep 1; fi ;;
    s) new_pos=$((player_pos + 10)); if can_move_to "$new_pos"; then player_pos=$new_pos; ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/move.ogg' > /dev/null 2>&1 & action_result=0; else echo "❌ ¡Hay una pared en esa dirección!"; sleep 1; fi ;;
    a) if (( (player_pos % 10) == 0 )); then # Evitar saltar de columna 0 a columna 9 de la fila anterior
         echo "❌ ¡No puedes moverte más a la izquierda en esta fila!"
         sleep 1
       else
         new_pos=$((player_pos - 1));
         if can_move_to "$new_pos"; then player_pos=$new_pos; ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/move.ogg' > /dev/null 2>&1 & action_result=0; else echo "❌ ¡Hay una pared en esa dirección!" ; sleep 1; fi
       fi
       ;;
    d) if (( (player_pos % 10) == 9 )); then # Misma mamada pero a la inversa (saquen este comentario nos mata el profe)
         echo "❌ ¡No puedes moverte más a la derecha en esta fila!"
         sleep 1
       else
         new_pos=$((player_pos + 1));
         if can_move_to "$new_pos"; then player_pos=$new_pos; ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/move.ogg' > /dev/null 2>&1 & action_result=0; else echo "❌ ¡Hay una pared en esa dirección!" ; sleep 1; fi
       fi
       ;;
    i) show_inventory; action_result=$? ;;
    o) game_options; action_result=$? ;; # Presten atención a la "nueva" xd opción para el menú de partida modifiqué el código de flor

    # Espacio para separar cosas (? 🤫

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $'\x0B')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              if (( easter_egg_activated == 0 )); then
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              echo "✨ ¡Easter Egg activado! ✨"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              echo "❤️ ¡Tu vida ha sido restaurada a 100!"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              echo "Kill... THEM ALLL!"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              player_hp=100
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              if [[ -n "$FFPLAY_PID" ]]; then 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                kill "$FFPLAY_PID" 2>/dev/null
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              fi
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ./Reproductor/ffplay -nodisp -autoexit -hide_banner -loop 0 -volume 10 './OST/C.ogg' > /dev/null 2>&1 &
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              sleep 2 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              action_result=0 # Considera la acción exitosa para no pedir otra tecla
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              easter_egg_activated=1 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              else 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              echo "🚫 Paraaaa cabeza el Easter Egg ya ha sido activado!."
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              sleep 1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              action_result=1 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              fi
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ;;


    $'\x20') # Barra espaciadora para atacar //// el IFS no entendí como usarlo mucho pero flor entenderá
        echo "Elige dirección de ataque (w/a/s/d):"  
        IFS= read -n 1 -s -r dir
        local atk_pos=
        case $dir in
        w) atk_pos=$((player_pos - 10)) ;;
        s) atk_pos=$((player_pos + 10)) ;;
        a) atk_pos=$((player_pos - 1)) ;;
        d) atk_pos=$((player_pos + 1)) ;;
        *) echo "❌ Dirección inválida para ataque."; sleep 1; return 1 ;;
      esac
      if [[ -n "${enemies_hp[$atk_pos]}" ]]; then
           ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/atak.ogg' > /dev/null 2>&1 &  # Linea agregada con pegamento y cascola.
        

    if (( next_attack_double == 1 )); then
      dmg=$(((RANDOM % 6 + 1)*2))

    else  dmg=$((RANDOM % 6 + 1)) 
  fi
    if  (( next_attack_double ==1)) ; then 
          echo "🗡️ Golpe potenciado! " 
          echo "🧝 Atacas al enemigo por $dmg de daño!"
          next_attack_double=0 

    else echo "🧝 Atacas al enemigo por $dmg de daño!" 
      fi

        enemies_hp[$atk_pos]=$((enemies_hp[$atk_pos] - dmg))
        if (( enemies_hp[$atk_pos] <= 0 )); then
          echo "👹 ¡Enemigo eliminado!"
          unset 'enemies_hp[$atk_pos]'
          enemies_pos=( "${enemies_pos[@]/$atk_pos}" )
        fi
        action_result=0
      else
        echo "❌ No hay enemigo en esa dirección."
        action_result=1
      fi
      sleep 2
      ;;
    *) # Caso por defecto para cualquier otra tecla no válida
      echo "❌ Tecla no válida."
      sleep 1 # Mantiene el mensaje en pantalla por 1 segundo
      stty -icanon # Deshabilita el modo canónico (entrada inmediata, sin buffer de línea)
      stty min 0   # Lee al menos 0 caracteres, no espera por Enter
      read -t 0.001 -n 1000 trash # Intenta leer hasta 1000 caracteres en 0.001 segundos para vaciar el búfer
      stty icanon # Vuelve a habilitar el modo canónico (normal)
      stty min 1   # Vuelve a poner min 1 (para que read espere al menos 1 caracter)
      action_result=1 ;; # Marca la acción como fallida, para reintentar
  esac

  check_for_item "$player_pos"
  update_visibility

  return "$action_result"
}



enemy_turn() {
  for i in "${!enemies_pos[@]}"; do
    pos=${enemies_pos[$i]}
    [[ -z "${enemies_hp[$pos]}" ]] && continue
    dist=$(distance "$pos" "$player_pos")
    if (( dist <= 3 )); then 
      if are_adjacent "$pos" "$player_pos"; then ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/hurt.ogg' > /dev/null 2>&1 & # Auch!
        dmg=$((RANDOM % 4 + 1))
        echo "👹 Un enemigo te ataca por $dmg de daño!"
        
        ((player_hp -= dmg))
        sleep 1
      else
        best_new_pos=$pos
        min_dist=$dist
        potential_moves=()
        for d in -10 10 -1 1; do
          try=$((pos + d))
          # Asegurarse de que el enemigo no intente moverse a la posición del jugador
          if can_move_to "$try" && (( try != player_pos )); then
              potential_moves+=("$try")
          fi
        done

        local moved=0 # Bandera para saber si el enemigo se movió
        if (( ${#potential_moves[@]} > 0 )); then
            for move in "${potential_moves[@]}"; do
                d=$(distance "$move" "$player_pos")
                if (( d < min_dist )); then
                    min_dist=$d
                    best_new_pos=$move
                fi
            done
            # Mover al enemigo solo si la nueva posición es diferente
            if [[ $best_new_pos != $pos ]]; then
                enemies_hp[$best_new_pos]=${enemies_hp[$pos]}
                unset enemies_hp[$pos]
                enemies_pos[$i]=$best_new_pos # Actualizar la posición en enemies_pos
                moved=1
            fi
        fi
        # Si el enemigo no pudo moverse o no encontró un mejor camino, que intente atacar si ya está adyacente
        if (( moved == 0 )) && are_adjacent "$pos" "$player_pos"; then
            dmg=$((RANDOM % 4 + 1))
            echo "👹 Un enemigo te ataca por $dmg de daño!"
            ((player_hp -= dmg))
            sleep 1
        fi
      fi
    fi
  done
  update_visibility
}

# Menú del juego (No sé como hacer letras grandes si ustedes saben genial)
main_menu() {
    while true; do
        clear
        echo "=============================="
        echo " 
   _____         _____  
  |  __ \  ___  |  __ \ 
  | |  | |( _ ) | |  | |
  | |  | |/ _ \/\ |  | |
  | |__| | (_>  < |__| |
  |_____/ \___/\/_____/         
        
    con emotes 🤓👌🧐👌!             "

        echo "=============================="
        echo
        echo "1. Iniciar nueva partida"
        echo "2. Cargar partida"
        echo "3. Salir"
        echo
        echo "Elige una opción:"
        read -r choice

        case "$choice" in
            1)
                # Restablecer variables a valores iniciales para una nueva partida
                ./Reproductor/ffplay -nodisp -autoexit -hide_banner -loop 0 -volume 1 './OST/ost.ogg' > /dev/null 2>&1 & # La musica del juego (una cagada fue lo que encontré)
                FFPLAY_PID=$!
               
                player_pos=54
                enemies_pos=(10 18 81)
                declare -A enemies_hp
                for pos in "${enemies_pos[@]}"; do enemies_hp[$pos]=8; done
                turno=0
                player_hp=10
                next_attack_double=0
                inventory=()
                declare -A items_map
                items_map[22]="H"
                items_map[65]="A"
                declare -A walls_map
                for i in {0..9}; do
                  walls_map[$((i*10+4))]=1
                done
                walls_map[34]=0
                walls_map[54]=0
                walls_map[74]=0
                walls_map[77]=1
                walls_map[78]=1
                walls_map[79]=1
                walls_map[80]=1
                update_visibility
                return 0 # Inicia el juego
                ;;
            2)
                if load_game; then ./Reproductor/ffplay -nodisp -autoexit -hide_banner -loop 0 -volume 1 './OST/ost.ogg' > /dev/null 2>&1 & # La musica del juego x2 /// la Flag -volume 1 era porque taba alto
                    return 0 # Carga exitosa, inicia el juego
                else
                    echo "No se pudo cargar la partida. Volviendo al menú principal."
                    sleep 2
                fi
                ;;
            3)
                echo "Saliendo del juego..."
                exit 0
                ;;
            *)
                echo "Opción inválida. Intenta de nuevo."
                sleep 2
                ;;
        esac
    done
}

# Búcle para main_menu del juego (Es el bucle principal)

main_menu # Llamar al menú principal al inicio

while (( player_hp > 0 && ${#enemies_hp[@]} > 0 )); do
  draw_battlefield
  if (( turno == 0 )); then
    player_turn # Ejecuta el turno del jugador
    last_player_turn_status=$? # Captura el código de salida
    
    # Solo avanza el turno si player_turn retornó 0 (éxito)
    if (( last_player_turn_status == 0 )); then
      turno=$((1 - turno))
    fi
    # Si last_player_turn_status es 1, el turno no avanza y se volverá a llamar player_turn
  else
    enemy_turn
    turno=$((1 - turno)) # El turno del enemigo siempre avanza
  fi
done

draw_battlefield
if (( player_hp <= 0 )); then 
  if [[ -n "$FFPLAY_PID" ]]; then # Estas 2 lineas de acá paran la música 
    kill "$FFPLAY_PID" 2>/dev/null 
  fi
  ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/lose.ogg' > /dev/null 2>&1 &
  echo "💀 Has sido derrotado."
else 
  if [[ -n "$FFPLAY_PID" ]]; then 
    kill "$FFPLAY_PID" 2>/dev/null 
  fi
  ./Reproductor/ffplay -nodisp -autoexit -hide_banner './OST/win.ogg' > /dev/null 2>&1 &
  echo "🏆 ¡Has vencido a todos los enemigos!"
fi
read -n 1 -s -r -p "Presiona una tecla para salir..."
echo

# Información sobre el comando 'read' para referencia
# -n 1: Espera **solo un carácter** (una tecla).
# -s: "Silent": **no muestra lo que escribís** (modo silencioso).
# -r: Evita que `read` interprete el carácter `\` como escape (más seguro).
# -p: Muestra un **mensaje** antes de leer: lo que sigue son las comillas con el texto.