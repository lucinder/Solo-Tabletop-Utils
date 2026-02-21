# loadchar.ps1 - Load a character sheet into the roll cache
# Usage: loadchar <filename>

param([string]$FileName)

if (-not $FileName) {
    Write-Host "Usage: loadchar <filename>"
    Write-Host "  loadchar character.json"
    Write-Host "  loadchar Hero"
    exit
}

# Allow omitting the .json extension
if ($FileName -notmatch '\.json$') { $FileName += ".json" }

$srcPath   = Join-Path $PSScriptRoot "Character Sheets\$FileName"
$cachePath = Join-Path $PSScriptRoot "Character Sheets\CACHE.json"

if (-not (Test-Path $srcPath)) {
    Write-Host "Error: '$FileName' not found in Character Sheets."
    exit
}

Copy-Item $srcPath $cachePath
$name = (Get-Content $cachePath -Raw | ConvertFrom-Json).name
Write-Host "Loaded '$name' as active character."
