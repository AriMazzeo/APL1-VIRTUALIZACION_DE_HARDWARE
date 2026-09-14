
Param(

    [Parameter(Mandatory=$false)]
    [int[]]$idsPersonajes, 

    [Parameter(Mandatory=$false)]
    [int[]]$idsPeliculas
)

$RUTA_CACHE_PERSONAJES="$PSScriptRoot/cache.jsonl"

function Get-Personajes-Cache(){ 

    if(Test-Path $RUTA_CACHE_PERSONAJES){
        $personajesCache = Get-Content $RUTA_CACHE_PERSONAJES | ConvertFrom-Json 
    }
    else{
        New-Item -Path $RUTA_CACHE_PERSONAJES -ItemType File
        $personajesCache = @()
    }


    #HASTA ACA (DEVOLVIENDO EL ARRAY) TIENE QUE SER LA GET-PERSONAJES-CACHE

    $encontrados = @()
    $noEncontrados = @()

    foreach($id in $idsPersonajes){
        $objeto = ($personajesCache | Where-Object Id -eq $id)

        if($objeto -ne $NULL){
            $encontrados += $objeto
        }else{
            $noEncontrados += $id
        }
    }
    
    $encontrados
    $noEncontrados

    return 
}

function Get-Personajes-Api(){
    Param(
        [Parameter(Mandatory=$true)]
        [int[]] $ids
    )

    $personajesApi = @()

    <#AGREGAR:
        - TRY-CATCH POR SI FALLA LA PETICION
        - VARIABLE CON LA URL-BASE
    #> 
    foreach($id in $ids){
        $personajeObtenido = (Invoke-RestMethod https://www.swapi.tech/api/people/$id).result
        $personajesApi += $personajeObtenido
    }

}

Get-Personajes-Cache