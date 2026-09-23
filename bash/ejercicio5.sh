#!/bin/bash

function ayuda(){
    echo "Ayuda"
}

options=$(getopt -o p:f:h --l people:,film:help -- "$@" 2> /dev/null)

if [ "$?" != "0" ]
then
    echo 'Opciones incorrectas'
    exit 1
fi

eval set -- "$options"
while true
do
    case "$1" in
    -p | --people)
        IFS=',' read -ra peoples <<< "$2"
        shift 2
        ;;
    -f | --film)
        IFS=',' read -ra films <<< "$2"
        shift 2
        ;;
    -h | --help)
        ayuda
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *) #default
        echo "error"
        exit 1
        ;;
    esac
done

#DEFINO COLORES PARA ERRORES Y FLUJO NORMAL
RED='\033[0;31m'
RESET='\033[0m'

#CONSTANTES DE UTILIDAD
RUTA_CACHE_PERSONAJES="$(pwd)/cache_personajes.jsonl"
RUTA_CACHE_PELICULAS="$(pwd)/cache_peliculas.jsonl"
URL_BASE_PERSONAJES="https://www.swapi.tech/api/people/"
URL_BASE_PELICULAS="https://www.swapi.tech/api/films/"

function validar_parametros(){
    for n in "${peoples[@]}" "${films[@]}"
    do
        if [[ ! "$n" =~ ^[1-9][0-9]*$ ]] #chequeo que sean enteros con una REGEX
        then
            echo -e "${RED}Error: Los parametros deben ser enteros positivos${RESET}"
            exit 1
        fi
    done
}

function get_cache()
{
    local ruta_cache=$1
    shift 1 #descarto el primer parametro y el resto son ids
    local ids_json=$(printf '%s\n' "$@" | jq -R . | jq -s .) #convierto los id recibidos por parametro a un array json (de enteros) para poder trabajarlo con jq

    if [ ! -f $ruta_cache ]
    then
        touch $ruta_cache
    fi

    jq -c --argjson ids_buscados "$ids_json" 'select(.Id as $id | $ids_buscados | any(. == $id))' "$ruta_cache"
}

function get_ids_no_encontrados(){

    local ruta_cache=$1
    local url=$2
    shift 2
    local ids=("$@")

    local personajes_cache=$(get_cache $ruta_cache ${ids[@]})
    local no_encontrados=()
    local personajes_api=()

    for id in ${ids[@]}
    do
        if  ! echo "$personajes_cache" | grep -q "\"Id\":\"$id\"" 
        then
            no_encontrados+=($id)
        fi
    done

    echo ${no_encontrados[@]}
}

function get_api(){
    
    local url=$1
    shift 1
    local ids=("$@")

    local response=()

    for id in ${ids[@]}
    do
        local respuesta=$(wget -qO- "${url}${id}" | jq -c '{
            Mass: .result.properties.mass,
            Name: .result.properties.name,
            Birth_year: .result.properties.birth_year,
            Id: .result.uid,
            Height: .result.properties.height,
            Gender: .result.properties.gender}'
        )
        response+=($respuesta)

    done

    echo ${response[@]} | jq -sc 'sort_by(.Id | tonumber)[]'
    
}

function get_personajes_by_id(){
    
    local ids=("$@")

    local personajes_cache=($(get_cache $RUTA_CACHE_PERSONAJES ${ids[@]}))
    local count_cache=$(echo ${personajes_cache[@]} | jq -s 'length')
    local count_ids=${#ids[@]}

    if [ $count_cache -eq $count_ids ]
    then
        echo ${personajes_cache[@]} | jq
        return
    fi

    local no_encontrados=($(get_ids_no_encontrados "$RUTA_CACHE_PERSONAJES" "$URL_BASE_PERSONAJES" ${peoples[@]}))
    local personajes_api=($(get_api $URL_BASE_PERSONAJES ${no_encontrados[@]}))

    local todos=(${personajes_cache[@]} ${personajes_api[@]})

    echo ${personajes_api[@]} | add_to_cache $RUTA_CACHE_PERSONAJES

    echo ${todos[@]}
}

function add_to_cache(){

    local ruta_cache=$1

    jq -c >> $ruta_cache
}

function echo_personajes(){

    local personajes=("$@")

    echo "LISTADO PERSONAJES"
    echo ${personajes[@]} | jq -s 'sort_by(.Id | tonumber)[]'
}

function main(){

    validar_parametros 
    if [ -n "$peoples" ]
    then
        personajes=($(get_personajes_by_id ${peoples[@]}))
        echo_personajes ${personajes[@]}
    fi
}

main
