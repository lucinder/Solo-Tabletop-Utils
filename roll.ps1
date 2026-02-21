# r.ps1 - Dice roller
# Usage: r [repeat] XdY[kh[Z]|kl[Z]] [DC]

$ESC  = [char]27
$ST   = "$ESC[9m"   # strikethrough on
$BOLD = "$ESC[1m"   # bold on
$GRN  = "$ESC[32m"  # green text
$RED  = "$ESC[31m"  # red text
$YLW  = "$ESC[33m"  # yellow text
$RST  = "$ESC[0m"   # reset all

# --- Ability/skill check data ---
$Abilities = @("str","dex","con","int","wis","cha")
$SkillMap  = @{
    "acrobatics"      = "dex"; "animal handling" = "wis"; "arcana"        = "int"
    "athletics"       = "str"; "deception"       = "cha"; "history"       = "int"
    "insight"         = "wis"; "intimidation"    = "cha"; "investigation" = "int"
    "medicine"        = "wis"; "nature"          = "int"; "perception"    = "wis"
    "performance"     = "cha"; "persuasion"      = "cha"; "religion"      = "int"
    "sleight of hand" = "dex"; "stealth"         = "dex"; "survival"      = "wis"
}

# --- Parse arguments ---
$RepeatCount = 1
$DiceStr     = ""
$DC          = $null
$Silent      = $false
$CheckName   = ""

foreach ($arg in $args) {
    if ($arg -eq "--silent") {
        $Silent = $true
    } else {
        $lower = $arg.ToLower()
        if ($Abilities -contains $lower -or $SkillMap.ContainsKey($lower)) {
            $CheckName = $lower
        } elseif ($arg -match '[dD]') {
            $DiceStr = $lower
        } elseif ($DiceStr -eq "" -and $CheckName -eq "") {
            if ($arg -match '^\d+$') { $RepeatCount = [int]$arg }
        } else {
            if ($arg -match '^\d+$') { $DC = [int]$arg }
        }
    }
}

if ($DiceStr -eq "" -and $CheckName -eq "") {
    Write-Host "Usage: roll [repeat] XdY[kh[Z]|kl[Z]][+/-N] [DC] [--silent]"
    Write-Host "       roll [repeat] <ability|skill> [DC] [--silent]"
    Write-Host "  roll 3d20          Roll 3d20"
    Write-Host "  roll 2d10kh1       Roll 2d10, keep highest 1"
    Write-Host "  roll d20+5 15      Roll d20+5 against DC 15"
    Write-Host "  roll str           Strength check (uses CACHE.json)"
    Write-Host "  roll perception 15 Perception check against DC 15"
    exit
}

# --- Resolve named ability/skill check into a dice expression ---
if ($CheckName -ne "") {
    $cachePath = Join-Path $PSScriptRoot "Character Sheets\CACHE.json"
    if (-not (Test-Path $cachePath)) {
        Write-Host "Error: No cached character sheet found at 'Character Sheets\CACHE.json'."
        Write-Host "Create one to use ability/skill checks."
        exit
    }
    $sheet      = Get-Content $cachePath -Raw | ConvertFrom-Json
    $ability    = if ($Abilities -contains $CheckName) { $CheckName } else { $SkillMap[$CheckName] }
    $statScore  = $sheet.stats.$ability
    $profEntry  = $sheet.proficiencies | Where-Object { ($_ -replace '\*$') -eq $CheckName } | Select-Object -First 1
    $isExpert   = $null -ne $profEntry -and $profEntry.EndsWith('*')
    $isProf     = $null -ne $profEntry -and ($Abilities -notcontains $CheckName)
    $pbMult     = if ($isExpert) { 2 } elseif ($isProf) { 1 } else { 0 }
    $totalMod   = [Math]::Floor(($statScore - 10) / 2) + ($pbMult * $sheet.proficiency_bonus)

    if     ($totalMod -gt 0) { $DiceStr = "d20+$totalMod" }
    elseif ($totalMod -lt 0) { $DiceStr = "d20$totalMod"  }
    else                     { $DiceStr = "d20"            }
}

# --- Parse dice format: [X]d[Y][k[h|l][Z]][+/-N] ---
if ($DiceStr -notmatch '^(\d*)d(\d+)(k([hl])(\d*))?([+-]\d+)?$') {
    Write-Host "Error: Invalid dice format '$DiceStr'"
    Write-Host "Expected: XdY, dY, XdYkhZ, XdYklZ, XdY+N, XdY-N, etc."
    exit
}

$NumDice   = if ($Matches[1]) { [int]$Matches[1] } else { 1 }
$Sides     = [int]$Matches[2]
$KeepType  = if ($Matches[4]) { $Matches[4] } else { "" }
$KeepCount = if ($KeepType -and $Matches[5]) { [int]$Matches[5] } `
             elseif ($KeepType)               { 1 } `
             else                             { 0 }
$Modifier  = if ($Matches[6]) { [int]$Matches[6] } else { 0 }

if ($KeepType -and $KeepCount -gt $NumDice) { $KeepCount = $NumDice }

$DiceLabel = "${NumDice}d${Sides}"
if ($KeepType) { $DiceLabel += "k${KeepType}${KeepCount}" }
if ($Modifier -gt 0) { $DiceLabel += "+${Modifier}" }
elseif ($Modifier -lt 0) { $DiceLabel += "${Modifier}" }

if ($CheckName -ne "") {
    $displayName = if ($Abilities -contains $CheckName) {
        $CheckName.ToUpper()
    } else {
        (Get-Culture).TextInfo.ToTitleCase($CheckName)
    }
    $modStr    = if ($Modifier -gt 0) { "+$Modifier" } elseif ($Modifier -lt 0) { "$Modifier" } else { "" }
    $DiceLabel = "$displayName (d20$modStr)"
}

# --- Roll function ---
function Invoke-DiceRoll {
    # Roll all dice
    $rolls = @(1..$NumDice | ForEach-Object { Get-Random -Minimum 1 -Maximum ($Sides + 1) })
    $keepMask = New-Object int[] $NumDice
    $total    = 0

    if ($KeepType) {
        # Pair each value with its original index, then sort by value
        $indexed = 0..($NumDice - 1) | ForEach-Object {
            [PSCustomObject]@{ Value = $rolls[$_]; Index = $_ }
        }
        $sorted = $indexed | Sort-Object Value

        if ($KeepType -eq "h") {
            $sorted | Select-Object -Last  $KeepCount | ForEach-Object { $keepMask[$_.Index] = 1 }
        } else {
            $sorted | Select-Object -First $KeepCount | ForEach-Object { $keepMask[$_.Index] = 1 }
        }

        for ($i = 0; $i -lt $NumDice; $i++) {
            if ($keepMask[$i]) { $total += $rolls[$i] }
        }
    } else {
        $total = ($rolls | Measure-Object -Sum).Sum
    }

    $total += $Modifier

    # Build comma-separated result string (dropped dice get strikethrough)
    $parts = 0..($NumDice - 1) | ForEach-Object {
        if ($KeepType -and -not $keepMask[$_]) { "${ST}$($rolls[$_])${RST}" }
        else                                   { "$($rolls[$_])" }
    }
    $partsStr = $parts -join ", "
    $rollLabel = "${DiceLabel}: "
    if ($null -ne $DC) {
        if ($total -ge $DC) {  $rollLabel += "${GRN}${partsStr}${RST}" }
        else                 { $rollLabel += "${RED}${partsStr}${RST}" }
    } else {
        $rollLabel += "${partsStr}"
    }
    if ($RepeatCount -gt 1) {
        Write-Host "${rollLabel}"
    } else {
        Write-Host "Rolling ${rollLabel}"
        if ($null -ne $DC) {
            Write-Host "${BOLD}${YLW}Total: ${total} (1 successes, 0 failures)${RST}"
        } else {
            Write-Host "${BOLD}${YLW}Total: ${total}${RST}"
        }
    }

    return $total
}

# --- Sound ---
function Invoke-DiceSound {
    if ($Silent) { return }
    $soundFile = Join-Path $PSScriptRoot "assets\dice.ogg"
    if (-not (Test-Path $soundFile)) { return }
    try {
        $resolved = (Resolve-Path $soundFile).Path
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName        = "ffplay"
        $psi.Arguments       = "-nodisp -autoexit -loglevel quiet `"$resolved`""
        $psi.CreateNoWindow  = $true
        $psi.UseShellExecute = $false
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch { }
}

# --- Execute rolls ---
Invoke-DiceSound
$TotalSuccesses = 0
$TotalFailures  = 0
$CumulativeTotal = 0

for ($r = 1; $r -le $RepeatCount; $r++) {
    $rollTotal = Invoke-DiceRoll
    $CumulativeTotal += $rollTotal
    if ($null -ne $DC) {
        if ($rollTotal -ge $DC) { $TotalSuccesses++ } else { $TotalFailures++ }
    }
}

if ($RepeatCount -gt 1) {
    if ($null -ne $DC) {
        Write-Host "${BOLD}${YLW}Total: ${CumulativeTotal} (${TotalSuccesses} successes, ${TotalFailures} failures)${RST}"
    } else {
        Write-Host "${BOLD}${YLW}Total: ${CumulativeTotal}${RST}"
    }
}
