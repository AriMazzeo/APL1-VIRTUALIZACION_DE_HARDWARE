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
    Script que monitorea la creacion de archivos en un directorio buscando duplicados y genera backups con ellos, si los hay.

.DESCRIPTION
    Este script crea un proceso demonio en segundo plano que monitorea un directorio 
    y sus subdirectorios usando FileSystemWatcher. Cuando detecta que se creó un 
    archivo duplicado (mismo nombre y tamaño que otro existente), genera un log con 
    las rutas de los duplicados y los archiva en un archivo .zip con el formato 
    de nombre "yyyyMMdd-HHmmss" en el directorio de salida indicado.

    El script puede ejecutarse nuevamente con -kill para detener el demonio iniciado
    sobre un directorio específico. No se puede iniciar más de un demonio para el 
    mismo directorio al mismo tiempo.

.PARAMETER directorio
    Ruta del directorio a monitorear, incluyendo sus subdirectorios.
    Acepta rutas absolutas, relativas y rutas con espacios siempre y cuando se envien entre "".
    Parametro obligatorio.

.PARAMETER salida
    Ruta del directorio donde se van a crear los archivos de backup comprimidos (.zip).
    No se puede usar junto con -kill.

.PARAMETER kill
    Detiene el proceso demonio previamente iniciado para el directorio indicado.
    Solo se puede usar junto con -directorio.

.EXAMPLE
    ./ejercicio4.ps1 -directorio "../monitor" -salida "../salida"
    Inicia el monitoreo del directorio ../monitor y guarda los backups en ../salida.

.EXAMPLE
    ./ejercicio4.ps1 -directorio "../monitor" -kill
    Detiene el proceso demonio que monitorea el directorio ../monitor.
#>

[CmdletBinding(DefaultParameterSetName = 'iniciar')]
param(   
    [Parameter(Mandatory = $true, ParameterSetName = 'iniciar')]
    [Parameter(Mandatory = $true, ParameterSetName = 'finalizar')]
    [ValidateScript({
        if( -not (Test-Path $_ -PathType Container)){
            throw "El directorio '$_' no existe o no es valido"
        }
        return $true
    })]
    [string]
    $directorio,
    [Parameter(Mandatory = $false, ParameterSetName = 'iniciar')]
     [ValidateScript({
        if( -not (Test-Path $_ -PathType Container)){
            throw "El directorio '$_' no existe o no es valido"
        }
        return $true
    })]
    [string]
    $salida,
    [Parameter(Mandatory = $false, ParameterSetName = 'finalizar')]
    [switch]$kill
)

function Main {

    $jobExistente = Get-Job -Name "$directorio" -ErrorAction SilentlyContinue
    if ($kill -and $jobExistente) {
        Stop-Monitoreo -directorio "$directorio" 
    }
    elseif ($kill -and -not $jobExistente) {
        Write-Host "No hay ningun proceso de monitoreo activo para ese directorio"
    }   
    elseif ($jobExistente -and -not $kill) {
        Write-Host "Ya hay un proceso monitoreando ese directorio"
    }
    elseif (-not $salida) {
        Write-Host "Debe indicar un directorio de salida con -salida para iniciar el monitoreo"
    }
    else {
        Start-Monitoreo -directorio "$directorio" -salida $salida
    }
}

function Stop-Monitoreo {
    param(
        $directorio
    )

    Stop-Job -Name "$directorio"
    Remove-Job -Name "$directorio"
}

function Start-Monitoreo {
    param(
        $directorio,
        $salida
    )

    Start-Job -Name "$directorio" -ArgumentList "$directorio", $salida -ScriptBlock {
        param($dir, $sal)
        
        $fw = New-Object System.IO.FileSystemWatcher;
        $fw.Path = $dir;
        $fw.EnableRaisingEvents = $true;
        $fw.IncludeSubdirectories = $true;

        Register-ObjectEvent -InputObject $fw -EventName Created -SourceIdentifier archivoCreado
        Register-ObjectEvent -InputObject $fw -EventName Renamed -SourceIdentifier archivoRenombrado

        function New-BackUp {
            param(
                $duplicados,
                $nombre,
                $salida
            )

            Add-Content -Path "/tmp/log.txt" -Value "$nombre"
            foreach ($duplicado in $duplicados) {
                Add-Content -Path "/tmp/log.txt" -Value "$($duplicado.DirectoryName)"
            }
            $rutasDuplicados = @($duplicados.FullName)
            $rutasDuplicados += "/tmp/log.txt"
            $fecha = Get-Date -Format "yyyyMMdd-HHmmss"
            $archivoZip = "$salida/$fecha.zip"
            Compress-Archive -Path $rutasDuplicados -DestinationPath $archivoZip
 
        }
        function Get-Duplicados {
            param(
                $nombre,
                $tamanio,
                $ruta,
                $salida
            )

            $duplicados = Get-ChildItem -Path $ruta -Recurse -File | Where-Object { $_.Name -eq $nombre -and $_.Size -eq $tamanio }
            return $duplicados
        }
        while ($true) {
            $evento = Wait-Event 
            $evento | Remove-Event

            $nombre = ($evento.SourceArgs.FullPath | Get-ChildItem).Name
            $tamanio = ($evento.SourceArgs.FullPath | Get-ChildItem).Size

            $duplicados = Get-Duplicados -nombre $nombre -tamanio $tamanio -ruta $dir -salida $sal
            if ($duplicados.Count -gt 1) {
                try{
                    New-BackUp -duplicados $duplicados -nombre $nombre -salida $sal
                } catch {
                    Write-Host "Ocurrió un error al generar el backup: $_"
                } finally {
                    if(Test-Path "/tmp/log.txt"){
                        Remove-Item -Path "/tmp/log.txt"
                    }
                }  
            }
        }  
    }
}

Main