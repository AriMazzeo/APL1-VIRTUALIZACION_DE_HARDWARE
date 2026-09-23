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

#------------------- FUNCIONES COMPARTIDAS --------------------

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

    local cache=($(cat $ruta_cache | jq -c))
    local count_cache=$(echo ${cache[@]} | jq -s 'length')
    
    if [ $count_cache -ne 0 ]
    then
        echo ${cache[@]} | jq -c --argjson ids_buscados "$ids_json" 'select(.Id as $id | $ids_buscados | any(. == $id))'
    else
        echo ${cache[@]}
    fi

}

function get_ids_no_encontrados(){

    local ruta_cache=$1
    local url=$2
    shift 2
    local ids=("$@")

    local cache=$(get_cache $ruta_cache ${ids[@]})
    local no_encontrados=()
    local api=()

    for id in ${ids[@]}
    do
        if  ! echo "$cache" | grep -q "\"Id\":\"$id\"" 
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
        local respuesta=$(wget -qO- "${url}${id}" | jq -c '.result')
        response+=($respuesta)
    done

    echo ${response[@]} | jq -sc 'sort_by(.uid | tonumber)[]'   
}

function add_to_cache(){

    local ruta_cache=$1

    jq -c >> $ruta_cache
}

#-------------------- FUNCIONES PERSONAJES ----------------------
function get_personajes_formateados(){

    jq -c '{
        Mass: .properties.mass,
        Name: .properties.name,
        Birth_year: .properties.birth_year,
        Id: .uid,
        Height: .properties.height,
        Gender: .properties.gender
    }'

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

    local no_encontrados=($(get_ids_no_encontrados "$RUTA_CACHE_PERSONAJES" "$URL_BASE_PERSONAJES" ${ids[@]}))
    local personajes_api=($(get_api $URL_BASE_PERSONAJES ${no_encontrados[@]}))
    local api_formateados=($(echo ${personajes_api[@]} | get_personajes_formateados))
    local todos=(${personajes_cache[@]} ${api_formateados[@]})

    echo ${api_formateados[@]} | add_to_cache $RUTA_CACHE_PERSONAJES

    echo ${todos[@]}
}

function echo_personajes(){

    local personajes=("$@")

    echo "LISTADO PERSONAJES"
    echo ${personajes[@]} | jq -s 'sort_by(.Id | tonumber)[]'
}
#------------------- FUNCIONES PELICULAS --------------------
function get_peliculas_formateadas(){

    jq -c '{
        Id: .uid,
        Title: .properties.title,
        Episode_id: .properties.episode_id,
        Release_date: .properties.release_date,
        Opening_crawl: .properties.opening_crawl
    }'
}

function get_peliculas_by_id(){
    
    local ids=("$@")

    local peliculas_cache=($(get_cache $RUTA_CACHE_PELICULAS ${ids[@]}))
    local count_cache=$(echo ${peliculas_cache[@]} | jq -s 'length')
    local count_ids=${#ids[@]}

    if [ $count_cache -eq $count_ids ]
    then
        echo ${peliculas_cache[@]} | jq
        return
    fi

    local no_encontrados=($(get_ids_no_encontrados "$RUTA_CACHE_PELICULAS" "$URL_BASE_PELICULAS" ${ids[@]}))
    local peliculas_api=($(get_api $URL_BASE_PELICULAS ${no_encontrados[@]}))
    local api_formateadas=($(echo ${peliculas_api[@]} | get_peliculas_formateadas))
    local todos=(${peliculas_cache[@]} ${api_formateadas[@]})

    echo ${api_formateadas[@]} | add_to_cache $RUTA_CACHE_PELICULAS

    echo ${todos[@]}
}

function echo_peliculas(){

    local peliculas=("$@")

    echo "LISTADO PELICULAS"
    echo ${peliculas[@]} | jq -s 'sort_by(.Id | tonumber)[]'
}


function main(){

    validar_parametros 
    if [ -n "$peoples" ]
    then
        #get_personajes_by_id ${peoples[@]}
        personajes=($(get_personajes_by_id ${peoples[@]}))
        echo_personajes ${personajes[@]}
    fi

    if [ -n "$films" ]
    then
        #get_peliculas_by_id ${films[@]}
        peliculas=($(get_peliculas_by_id ${films[@]}))
        echo_peliculas ${peliculas[@]}
    fi
}

main
