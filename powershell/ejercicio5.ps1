
Param(

    [Parameter(Mandatory=$false)]
    [int[]]$idsPersonajes, 

    [Parameter(Mandatory=$false)]
    [int[]]$idsPeliculas
)

$RUTA_CACHE_PERSONAJES="$PSScriptRoot/cachePersonajes.jsonl"
$RUTA_CACHE_PELICULAS="$PSScriptRoot/cachePeliculas.jsonl"
$URL_PERSONAJES="https://www.swapi.tech/api/people/"
$URL_PELICULAS="https://www.swapi.tech/api/films/"


function Get-Cache(){ 
    #CON ESTA FUNCION OBTENEMOS EL CONTENIDO DE LA CACHÉ, Y SI NO EXISTE, LA CREAMOS. DEVUELVE UN ARRAY CON LOS PERSONAJES QUE ESTABAN EN CACHE Y TIENEN LOS ID PEDIDOS.
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
    #CON ESTA FUNCION SEPARAMOS LOS IDS QUE SE ENCONTRARON EN LA CACHE. RECIBE COMO PARAMETRO LA INFORMACION OBTENIDA DE LA CACHE Y TODOS LOS ID PEDIDOS POR EL USUARIO. DEVUELVE LOS PERSONAJES QUE PIDIO EL USUARIO QUE ESTABAN EN CACHE.
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
    #EN ESTA FUNCION OBTENEMOS LOS PERSONAJES QUE NO FUERON ENCONTRADOS EN LA CACHE, RECIBE COMO PARAMETRO UN ARRAY CON LOS ID A BUSCAR. DEVUELVE UN ARRAY CON LA INFORMACION DE LOS PERSONAJES.
    Param(
        [int[]] $ids=@(),
        [string]$url
    )

    $fromApi = @()

    <#AGREGAR:
        - TRY-CATCH POR SI FALLA LA PETICION
    #> 
    foreach($id in $ids){
        $obtenido = (Invoke-RestMethod $URL$id).result
        $fromApi += $obtenido
    }

    return $fromApi

}

function Add-ToCache(){
    Param(
        [psobject[]]$array=@(),
        [string]$rutaCache
    )

    $arrayJson = $array | Where-Object { $_ -ne $null } | Sort-Object {[int]$_.id} | ForEach-Object{
        $_ | ConvertTo-Json -Compress
    }  
    $arrayJson | Add-Content $rutaCache
}

function Get-PersonajesFormateados {
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

    $personajes | Sort-Object {[int]$_.id} | ForEach-Object{
        Write-Host "------------------------------------"
        Write-Host "id: $($_.id)"
        Write-Host "name: $($_.name)"
        Write-Host "gender: $($_.gender)"
        Write-Host "height: $($_.height)"
        Write-Host "mass: $($_.mass)"
        Write-Host "birth_year: $($_.birth_year)"
    }

}

function Get-PersonajesById(){
    Param(
        [int[]]$ids
    )

    $personajesCache = Get-Cache -ids $idsPersonajes -rutaCache $RUTA_CACHE_PERSONAJES

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
            Id       = $_.uid
            Title         = $_.properties.title
            Episode_id       = $_.properties.episode_id
            Release_date     = $_.properties.release_date
            Opening_crawl     = $_.properties.opening_crawl
        }
    }
    return ($peliculasFormateadas | Sort-Object {[int]$_.episode_id})
}

function Write-Peliculas(){

    Param(
        [psobject[]]$peliculas = @()
    )

    Write-Host "LISTADO DE PELICULAS:"

    $peliculas | Sort-Object {[int]$_.episode_id} | ForEach-Object{
        Write-Host "------------------------------------"
        Write-Host "title: $($_.title)"
        Write-Host "episode_id: $($_.episode_id)"
        Write-Host "release_date: $($_.release_date)"
        Write-Host "opening_crawl: $($_.opening_crawl)"
    }

}
function Get-PeliculasById(){
    Param(
        [int[]]$ids
    )

    $peliculasCache = Get-Cache -ids $idsPeliculas -rutaCache $RUTA_CACHE_PELICULAS

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

if($null -ne $idsPersonajes){
    Write-Personajes (Get-PersonajesById $idsPersonajes)
}

if($null -ne $idsPeliculas){
    Write-Peliculas (Get-PeliculasById $idsPeliculas)
}