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
    shift 1 #descarto los dos primeros parametros y el resto son ids
    local ids_json=$(printf '%s\n' "$@" | jq -R . | jq -s .) #convierto los id recibidos por parametro a un array json (de enteros) para poder trabajarlo con jq

    if [ ! -f $ruta_cache ]
    then
        touch $ruta_cache
    fi

    jq -c --argjson ids_buscados "$ids_json" 'select(.Id as $id | $ids_buscados | any(. == $id))' "$ruta_cache"
}

function get_ids_no_encontrados(){

    local ids=("$@")

    local cache=$(get_cache $RUTA_CACHE_PERSONAJES ${ids[@]})
    local no_encontrados=()

    for id in ${ids[@]}
    do
        if  ! echo "$cache" | grep -q "\"Id\":\"$id\"" 
        then
            no_encontrados+=$id
        fi
    done

    echo ${no_encontrados[@]}

}

validar_parametros 
get_ids_no_encontrados ${peoples[@]}