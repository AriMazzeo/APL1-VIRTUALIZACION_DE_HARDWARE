
<#
    INTEGRANTES:
        - Argain Tobias, 42998669
        - Aristimuño Iara, 45237225
        - Gambaro Guadalupe, 45206331
        - Mazzeo Ariana, 42774818
        - Melissari Pedro, 46912033
#>

<#
.SYNOPSIS
    Consulta información de personajes y películas de Star Wars a través de la API swapi.tech.

.DESCRIPTION
    Script que permite buscar información del mundo de Star Wars por ID de personaje o película.
    Realiza consultas a la API swapi.tech y guarda los resultados en una caché local (formato JSONL)
    para evitar consultar nuevamente la api. Muestra por pantalla la información básica de cada resultado.

.PARAMETER people
    ID o IDs de los personajes a buscar. Se pueden ingresar múltiples IDs separados por coma.

.PARAMETER film
    ID o IDs de las películas a buscar. Se pueden ingresar múltiples IDs separados por coma.

.EXAMPLE
    ./swapi.ps1 -people 1,2
    Busca y muestra la información de los personajes con ID 1 y 2.

.EXAMPLE
    ./swapi.ps1 -film 1,2
    Busca y muestra la información de las películas con ID 1 y 2.

.EXAMPLE
    ./swapi.ps1 -people 1,2 -film 1,2
    Busca y muestra personajes y películas al mismo tiempo.

.NOTES
    IDs de películas válidos: 1 al 7
    Los datos se cachean localmente en formato JSONL para optimizar las consultas.

.LINK
    https://www.swapi.tech/documentation
#>

Param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        foreach ($id in $_) {
            if ($id -le 0 -or $id -isnot [int]) {
                throw "ID inválido: '$id'. Los IDs deben ser números enteros positivos."
            }
        }
        return $true
    })]
    [psobject]$people, 

    [Parameter(Mandatory=$false)]
    [ValidateScript({
        foreach ($id in $_) {
            if ($id -le 0 -or $id -isnot [int]) {
                throw "ID inválido: '$id'. Los IDs deben ser números enteros positivos."
            }
        }
        return $true
    })]
    [psobject]$films
)

$RUTA_CACHE_PERSONAJES="$PSScriptRoot/cachePersonajes.jsonl"
$RUTA_CACHE_PELICULAS="$PSScriptRoot/cachePeliculas.jsonl"
$URL_PERSONAJES="https://www.swapi.tech/api/people/"
$URL_PELICULAS="https://www.swapi.tech/api/films/"

#--------------------FUNCIONES COMPARTIDAS----------------------
function Get-Cache(){ 
    #CON ESTA FUNCION OBTENEMOS EL CONTENIDO DE LA CACHÉ, Y SI NO EXISTE, LA CREAMOS.RECIBE COMO PARAMETRO LOS ID SOLICITADOS Y LA RUTA DE LA CACHE. DEVUELVE UN ARRAY CON LA INFORMACION DE LOS IDS PEDIDOS QUE SE ENCONTRABAN EN CACHE.
    Param(
        [int[]]$ids,
        [string]$rutaCache
    )
    $cache = @()
    $encontrados = @()

    if(Test-Path $rutaCache){
        $cache = Get-Content $rutaCache | ConvertFrom-Json 

        foreach($id in $ids){
        $objeto = ($cache | Where-Object Id -eq $id)

        if($null -ne $objeto){
            $encontrados += $objeto
        }
    }
    }
    else{
        New-Item -Path $rutaCache -ItemType File
        $encontrados = @()
    }

    return $encontrados
}

function Get-IdsNoEncontradosEnCache(){
    #CON ESTA FUNCION IDENTIFICAMOS LOS IDS QUE NO SE ENCONTRARON EN LA CACHE. RECIBE COMO PARAMETRO LA INFORMACION OBTENIDA DE LA CACHE Y TODOS LOS ID PEDIDOS POR EL USUARIO. DEVUELVE LOS ID QUE NO FUERON ENCONTRADOS EN LA CACHE.
    Param(
        [psobject[]]$enCache = @(),
        [Parameter(Mandatory=$true)]
        [int[]]$ids
    )

    $noEncontrados = @()

    foreach($id in $ids){
        $objeto = ($enCache | Where-Object Id -eq $id)

        if($null -eq $objeto){
            $noEncontrados += $id
        }
    }

    return $noEncontrados
}

function Get-Api(){
    #EN ESTA FUNCION REALIZAMOS LAS PETICIONES A LA API DE LOS ID QUE NO FUERON ENCONTRADOS EN LA CACHE. RECIBE COMO PARAMETRO UN ARRAY CON LOS ID A BUSCAR Y LA URL PARA CONCATENAR EL ID Y REALIZAR LA CONSULTA. DEVUELVE UN ARRAY CON LA INFORMACION DE LOS PERSONAJES OBTENIDOS DE LA CONSULTA.
    Param(
        [int[]] $ids=@(),
        [string]$url
    )

    $fromApi = @()

    try {
        foreach($id in $ids){
            $obtenido = (Invoke-RestMethod $URL$id).result
            $fromApi += $obtenido
        }
    }
    catch {
        Write-Warning "Error al realizar la peticion a la url: $url$id"
    }

    return $fromApi

}

function Add-ToCache(){
    #EN ESTA FUNCION AGREGAMOS A LA CACHE LA INFORMACION OBTENIDA DE LA API PARA EVITAR REPETIR CONSULTAS POSTERIORMENTE. RECIBE COMO PARAMETRO UN ARRAY DE OBJETOS CON LA INFORMACION A GUARDAR Y LA RUTA DE LA CACHE PARA GUARDAR AHI.
    Param(
        [psobject[]]$array=@(),
        [string]$rutaCache
    )

    $arrayJson = $array | Where-Object { $_ -ne $null } | Sort-Object {[int]$_.id} | ForEach-Object{
        $_ | ConvertTo-Json -Compress
    }  
    $arrayJson | Add-Content $rutaCache
}
#----------------------FUNCIONES PERSONAJES---------------------
function Get-PersonajesFormateados {
    #EN ESTA FUNCION GUARDAMOS EN UN ARRAY UNICAMENTE LA INFORMACION QUE NO IMPORTA ALMACENAR Y MOSTRAR. RECIBE COMO PARAMETRO UN ARRAY CON LOS OBJETOS QUE TIENEN TODA LA INFORMACION OBTENIDA DE LA CONSULTA A LA API. DEVUELVE EL ARRAY CON OBJETOS CON LA INFORMACION DE INTERES.
    param(
        [psobject[]]$personajes
    )
    
    $personajesFormateados = $personajes | Where-Object { $_ -ne $null} | ForEach-Object {
        [psobject]@{
            Id         = $_.uid
            Name       = $_.properties.name
            Gender     = $_.properties.gender
            Height     = $_.properties.height
            Mass       = $_.properties.mass
            Birth_year = $_.properties.birth_year
        }
    }
    return ($personajesFormateados | Sort-Object {[int]$_.id})
}

function Write-Personajes(){

    Param(
        [psobject[]]$personajes = @()
    )

    Write-Host "LISTADO DE PERSONAJES:"
    Write-Host
    Write-Host

    $personajes | Sort-Object {[int]$_.id} | ForEach-Object{
        Write-Host "id: $($_.id)"
        Write-Host "name: $($_.name)"
        Write-Host "gender: $($_.gender)"
        Write-Host "height: $($_.height)"
        Write-Host "mass: $($_.mass)"
        Write-Host "birth_year: $($_.birth_year)"
        Write-Host "------------------------------------"
    }
    Write-Host
    Write-Host
}

function Get-PersonajesById(){
    Param(
        [int[]]$ids
    )

    $personajesCache = Get-Cache -ids $people -rutaCache $RUTA_CACHE_PERSONAJES

    if($personajesCache.Count -eq $ids.Count)
    {
        return $personajesCache
    }

    $noEncontrados = Get-IdsNoEncontradosEnCache -enCache $personajesCache -ids $ids

    $personajesApi = Get-Api -ids $noEncontrados -url $URL_PERSONAJES

    $personajesFormateados = Get-PersonajesFormateados $personajesApi

    Add-ToCache -array $personajesFormateados -rutaCache $RUTA_CACHE_PERSONAJES

    return (@($personajesCache)+@($personajesFormateados))
}
#------------------FUNCIONES PELICULAS--------------------
function Get-PeliculasFormateadas {
    param(
        [psobject[]]$peliculas
    )
    
    $peliculasFormateadas = $peliculas | Where-Object { $_ -ne $null } | ForEach-Object {
        [psobject]@{
            Id= $_.uid
            Title= $_.properties.title
            Episode_id= $_.properties.episode_id
            Release_date= $_.properties.release_date
            Opening_crawl= $_.properties.opening_crawl
        }
    }
    return ($peliculasFormateadas | Sort-Object {[int]$_.episode_id})
}

function Write-Peliculas(){

    Param(
        [psobject[]]$peliculas = @()
    )

    Write-Host "LISTADO DE PELICULAS:"
    Write-Host
    Write-Host

    $peliculas | Sort-Object {[int]$_.episode_id} | ForEach-Object{
        Write-Host "title: $($_.title)"
        Write-Host "episode_id: $($_.episode_id)"
        Write-Host "release_date: $($_.release_date)"
        Write-Host "opening_crawl: $($_.opening_crawl)"
        Write-Host "------------------------------------"
    }
    Write-Host
    Write-Host
}
function Get-PeliculasById(){
    Param(
        [int[]]$ids
    )

    $peliculasCache = Get-Cache -ids $films -rutaCache $RUTA_CACHE_PELICULAS

    if($peliculasCache.Count -eq $ids.Count)
    {
        return $peliculasCache
    }

    $noEncontrados = Get-IdsNoEncontradosEnCache -enCache $peliculasCache -ids $ids

    $peliculasApi = Get-Api -ids $noEncontrados -url $URL_PELICULAS

    $peliculasFormateadas = Get-PeliculasFormateadas $peliculasApi

    Add-ToCache -array $peliculasFormateadas -rutaCache $RUTA_CACHE_PELICULAS

    return (@($peliculasCache)+@($peliculasFormateadas))
}

function main(){
    if($people){
        $personajes = Get-PersonajesById $people
        if($personajes.Count -gt 0){
            Write-Personajes $personajes
        }
    }
    
    if($films){
        $peliculas = Get-PeliculasById $films
        if($peliculas.Count -gt 0){
            Write-Peliculas $peliculas
        }
    }
}

main