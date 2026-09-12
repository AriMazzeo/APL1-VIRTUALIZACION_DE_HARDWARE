Param(
    $id,
    $nombre
)

Write-Host "Name: $($(Invoke-RestMethod https://www.swapi.tech/api/people/$id).result.properties.name)"