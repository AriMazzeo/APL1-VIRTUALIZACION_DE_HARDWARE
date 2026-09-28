
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'iniciar')]
    [Parameter(Mandatory = $true, ParameterSetName = 'finalizar')]
    [string]
    $directorio,
    [Parameter(Mandatory = $false, ParameterSetName = 'iniciar')]
    [string]
    $salida,
    [Parameter(Mandatory = $false, ParameterSetName = 'finalizar')]
    [switch]$kill
)

function Main {

    $jobExistente = Get-Job -Name $directorio -ErrorAction SilentlyContinue
    if ($kill -and $jobExistente) {
        Stop-Monitoreo -directorio $directorio 
    }
    elseif ($kill -and -not $jobExistente) {
        Write-Host "No hay ningun proceso de monitoreo activo para ese directorio"
    }   
    elseif ($jobExistente) {
        Write-Host "Ya hay un proceso monitoreando ese directorio"
    }
    else {
        Start-Monitoreo -directorio $directorio -salida $salida
    }

}

function Stop-Monitoreo {
    param(
        $directorio
    )

    Stop-Job -Name $directorio
    Remove-Job -Name $directorio
}

function Start-Monitoreo {
    param(
        $directorio,
        $salida
    )

    Start-Job -Name $directorio -ArgumentList $directorio, $salida -ScriptBlock {
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
            #New-Item -Path $archivo -ItemType Directory

            Add-Content -Path "/tmp/log.txt" -Value "$nombre"
            foreach ($duplicado in $duplicados) {
                Add-Content -Path "/tmp/log.txt" -Value "$($duplicado.DirectoryName)"
                #Copy-Item -Path $(duplicado.FullName) $archivo
            }
            $rutasDuplicados = @($duplicados.FullName)
            $rutasDuplicados += "/tmp/log.txt"
            $fecha = Get-Date -Format "yyyyMMdd-HHmmss"
            $archivoZip = "$salida/$fecha.zip"
            #$archivosAComprimir = @("/tmp/log.txt") + $rutasDuplicados
            Compress-Archive -Path $rutasDuplicados -DestinationPath $archivoZip


            Remove-Item -Path "/tmp/log.txt"
 
        }
        function Get-Duplicados {
            param(
                $nombre,
                $tamanio,
                $ruta,
                $salida
            )

            $duplicados = Get-ChildItem -Path $ruta -Recurse -File | Where-Object { $_.Name -eq $nombre -and $_.Size -eq $tamanio }
            New-BackUp -duplicados $duplicados -nombre $nombre -salida $salida
            
        }
        while ($true) {
            $evento = Wait-Event 
            $evento | Remove-Event

            $nombre = ($evento.SourceArgs.FullPath | Get-ChildItem).Name
            $tamanio = ($evento.SourceArgs.FullPath | Get-ChildItem).Size

            Get-Duplicados -nombre $nombre -tamanio $tamanio -ruta $dir -salida $sal
        }

        
    }

}
Start-Monitoreo -directorio $directorio -salida $salida
