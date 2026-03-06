# rest.ps1 - Take a short or long rest
# Usage: rest [short|long]  (default: long)

param(
    [Parameter(Position=0)][string]$RestType = "long"
)

$ESC  = [char]27
$BOLD = "$ESC[1m"
$GRN  = "$ESC[32m"
$YLW  = "$ESC[33m"
$RST  = "$ESC[0m"

$cachePath = Join-Path $PSScriptRoot "Character Sheets\CACHE.json"

if (-not (Test-Path $cachePath)) {
    Write-Host "Error: No active character. Use 'loadchar' to load one."
    exit
}

$RestType = $RestType.ToLower()
if ($RestType -notin @('short', 'long')) {
    Write-Host "Usage: rest [short|long]"
    exit
}

$sheet = Get-Content $cachePath -Raw | ConvertFrom-Json

function Get-FullSlotsAt([int]$effectiveLevel) {
    if ($effectiveLevel -lt 1) { return @{} }
    $slots = @{}
    for ($s = 1; $s -le 9; $s++) {
        $unlockAt = 2 * $s - 1
        if ($effectiveLevel -lt $unlockAt) { continue }
        $nextUnlock = $unlockAt + 2
        $base  = if ($s -le 3) { 2 } else { 1 }
        $extra = [Math]::Max(0, [Math]::Min([Math]::Min($effectiveLevel, 10), $nextUnlock - 1) - $unlockAt)
        $slots["$s"] = $base + $extra
    }
    if ($effectiveLevel -ge  3 -and $slots.ContainsKey("1")) { $slots["1"] += 1 }
    if ($effectiveLevel -ge  9 -and $slots.ContainsKey("4")) { $slots["4"] += 1 }
    if ($effectiveLevel -ge 18 -and $slots.ContainsKey("5")) { $slots["5"] += 1 }
    if ($effectiveLevel -ge 19 -and $slots.ContainsKey("6")) { $slots["6"] += 1 }
    if ($effectiveLevel -ge 20 -and $slots.ContainsKey("7")) { $slots["7"] += 1 }
    return $slots
}

function Get-SpellSlots([string]$casterType, [int]$level) {
    switch ($casterType.ToLower()) {
        "full"    { return Get-FullSlotsAt $level }
        "half"    { return Get-FullSlotsAt ([Math]::Floor($level / 2)) }
        "warlock" {
            $maxSlot = [Math]::Min(9, [Math]::Floor(($level + 1) / 2))
            if ($maxSlot -lt 1) { return @{} }
            $count = if ($level -eq 1) { 1 } elseif ($level -le 10) { 2 } elseif ($level -le 16) { 3 } else { 4 }
            return @{ "$maxSlot" = $count }
        }
        default   { return @{} }
    }
}

$casterType = if ($sheet.caster_type) { $sheet.caster_type } else { "none" }
$level      = [int]$sheet.level

# Warlocks recover slots on short or long rest; full/half only on long rest
$shouldReset = ($RestType -eq 'short' -and $casterType -eq 'warlock') -or
               ($RestType -eq 'long'  -and $casterType -in @('full', 'half', 'warlock'))

$restLabel = if ($RestType -eq 'short') { "short rest" } else { "long rest" }
Write-Host "${BOLD}$($sheet.name) takes a $restLabel.${RST}"

if ($shouldReset) {
    $newSlots = Get-SpellSlots $casterType $level

    $slotObj = [PSCustomObject]@{}
    foreach ($key in ($newSlots.Keys | Sort-Object { [int]$_ })) {
        $slotObj | Add-Member -NotePropertyName $key -NotePropertyValue $newSlots[$key]
    }
    $sheet.spell_slots = $slotObj

    $sheet | ConvertTo-Json -Depth 10 | Set-Content $cachePath

    if ($newSlots.Count -gt 0) {
        $slotSummary = ($newSlots.Keys | Sort-Object { [int]$_ } | ForEach-Object { "L${_}: $($newSlots[$_])" }) -join ', '
        Write-Host "${GRN}Spell slots restored:${RST} $slotSummary"
    }
} elseif ($casterType -ne 'none' -and $RestType -eq 'short') {
    Write-Host "${YLW}Spell slots are not restored on a short rest for $casterType casters.${RST}"
}
