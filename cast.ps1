# cast.ps1 - Cast a spell using the active character's spell slots
# Usage: cast <spell name> [-l <level>]

param(
    [Alias('l')][int]$Level = 0,
    [Parameter(Position=0, ValueFromRemainingArguments=$true)][string[]]$Spell
)

$ESC  = [char]27
$BOLD = "$ESC[1m"
$GRN  = "$ESC[32m"
$RED  = "$ESC[31m"
$YLW  = "$ESC[33m"
$RST  = "$ESC[0m"

$cachePath = Join-Path $PSScriptRoot "Character Sheets\CACHE.json"

if (-not (Test-Path $cachePath)) {
    Write-Host "Error: No active character. Use 'loadchar' to load one."
    exit
}

$sheet = Get-Content $cachePath -Raw | ConvertFrom-Json

$spellName = ($Spell -join ' ').Trim()

if (-not $spellName) {
    Write-Host "Usage: cast <spell name> [-l <level>]"
    exit
}

# Find spell in character's spell list (case-insensitive)
$matched = $null
if ($sheet.spells -and $sheet.spells.PSObject.Properties.Count -gt 0) {
    foreach ($prop in $sheet.spells.PSObject.Properties) {
        if ($prop.Name -ieq $spellName) {
            $matched = $prop
            break
        }
    }
}

if (-not $matched) {
    Write-Host "${RED}$spellName${RST} is not in $($sheet.name)'s spell list."
    exit
}

$spellBaseLevel = [int]$matched.Value

# Cantrips (level 0) don't consume spell slots
if ($spellBaseLevel -eq 0) {
    Write-Host "Cast ${BOLD}$($matched.Name)${RST} as a cantrip."
    exit
}

function Get-SlotCount([int]$slotLevel) {
    $val = $sheet.spell_slots."$slotLevel"
    if ($null -eq $val) { return 0 }
    return [int]$val
}

function Use-Slot([int]$slotLevel) {
    $current = Get-SlotCount $slotLevel
    $sheet.spell_slots."$slotLevel" = [Math]::Max(0, $current - 1)
    $sheet | ConvertTo-Json -Depth 10 | Set-Content $cachePath
}

# Manually specified slot level
if ($Level -gt 0) {
    if ($Level -lt $spellBaseLevel) {
        Write-Host "${RED}Cannot cast $($matched.Name) (level $spellBaseLevel) using a level $Level slot - slot level must be at least $spellBaseLevel.${RST}"
        exit
    }
    $count = Get-SlotCount $Level
    if ($count -le 0) {
        Write-Host "No level $Level spell slots available to cast ${RED}$($matched.Name)${RST}."
        exit
    }
    Use-Slot $Level
    Write-Host "Cast ${BOLD}$($matched.Name)${RST} using a level $Level slot. ($($count - 1) level $Level slot$(if ($count - 1 -ne 1) {'s'}) remaining)"
    exit
}

# Auto: try base level first, escalate to next available higher slot
$usedLevel = -1
for ($sl = $spellBaseLevel; $sl -le 9; $sl++) {
    if ((Get-SlotCount $sl) -gt 0) {
        $usedLevel = $sl
        break
    }
}

if ($usedLevel -lt 0) {
    Write-Host "No spell slots available to cast ${RED}$($matched.Name)${RST}."
    exit
}

$remaining = (Get-SlotCount $usedLevel) - 1
Use-Slot $usedLevel

if ($usedLevel -gt $spellBaseLevel) {
    Write-Host "Cast ${BOLD}$($matched.Name)${RST} ${YLW}(upcasted to level $usedLevel)${RST}. ($remaining level $usedLevel slot$(if ($remaining -ne 1) {'s'}) remaining)"
} else {
    Write-Host "Cast ${BOLD}$($matched.Name)${RST} at level $usedLevel. ($remaining level $usedLevel slot$(if ($remaining -ne 1) {'s'}) remaining)"
}
