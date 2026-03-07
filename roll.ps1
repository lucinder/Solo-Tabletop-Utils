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
$Abilities    = @("str","dex","con","int","wis","cha")
$SkillMap     = @{
    "acrobatics"      = "dex"; "animal handling" = "wis"; "arcana"        = "int"
    "athletics"       = "str"; "deception"       = "cha"; "history"       = "int"
    "insight"         = "wis"; "intimidation"    = "cha"; "investigation" = "int"
    "medicine"        = "wis"; "nature"          = "int"; "perception"    = "wis"
    "performance"     = "cha"; "persuasion"      = "cha"; "religion"      = "int"
    "sleight of hand" = "dex"; "stealth"         = "dex"; "survival"      = "wis"
}
$SkillAliases = @{
    "animal"  = "animal handling"
    "sleight" = "sleight of hand"
}

# --- Parse arguments ---
$RepeatCount = 1
$DiceStr     = ""
$DC          = $null
$Silent      = $false
$CheckName   = ""
$TableName   = ""
$TableFile   = ""
$TableDir    = Join-Path $PSScriptRoot "Rollable Tables"

# Separate --silent from positional args
$posArgs = [System.Collections.ArrayList]@()
foreach ($arg in $args) {
    if ($arg -eq "--silent") { $Silent = $true } else { [void]$posArgs.Add($arg) }
}

# Scan positional args for a table name or ability/skill name.
# Try longest match first (3 tokens, then 2, then 1) to support multi-word names.
for ($i = 0; $i -lt $posArgs.Count -and $CheckName -eq "" -and $TableName -eq ""; $i++) {
    foreach ($len in @(3, 2, 1)) {
        if ($i + $len -le $posArgs.Count) {
            $candidate = ($posArgs[$i..($i + $len - 1)] -join " ")
            # Check rollable table first
            $tPath = Join-Path $TableDir "$candidate.json"
            if ((Test-Path $TableDir) -and (Test-Path $tPath)) {
                $TableName = $candidate
                $TableFile = $tPath
                if ($i -gt 0 -and $posArgs[0] -match '^\d+$') { $RepeatCount = [int]$posArgs[0] }
                break
            }
            # Then check ability/skill
            $lower = $candidate.ToLower()
            if ($Abilities -contains $lower -or $SkillMap.ContainsKey($lower) -or $SkillAliases.ContainsKey($lower)) {
                $CheckName = if ($SkillAliases.ContainsKey($lower)) { $SkillAliases[$lower] } else { $lower }
                if ($i -gt 0 -and $posArgs[0] -match '^\d+$')           { $RepeatCount = [int]$posArgs[0] }
                $afterIdx = $i + $len
                if ($afterIdx -lt $posArgs.Count -and $posArgs[$afterIdx] -match '^\d+$') { $DC = [int]$posArgs[$afterIdx] }
                break
            }
        }
    }
}

# No check/table found — parse normally for a dice expression
if ($CheckName -eq "" -and $TableName -eq "") {
    foreach ($arg in $posArgs) {
        if ($arg -match '[dD]') {
            $DiceStr = $arg.ToLower()
        } elseif ($DiceStr -eq "") {
            if ($arg -match '^\d+$') { $RepeatCount = [int]$arg }
        } else {
            if ($arg -match '^\d+$') { $DC = [int]$arg }
        }
    }
}

if ($DiceStr -eq "" -and $CheckName -eq "" -and $TableName -eq "") {
    Write-Host "Usage: roll [repeat] XdY[kh[Z]|kl[Z]][+/-N] [DC] [--silent]"
    Write-Host "       roll [repeat] <ability|skill> [DC] [--silent]"
    Write-Host "       roll [repeat] <table name> [--silent]"
    Write-Host "  roll 3d20          Roll 3d20"
    Write-Host "  roll 2d10kh1       Roll 2d10, keep highest 1"
    Write-Host "  roll d20+5 15      Roll d20+5 against DC 15"
    Write-Host "  roll str           Strength check (uses CACHE.json)"
    Write-Host "  roll perception 15 Perception check against DC 15"
    Write-Host "  roll weather       Roll on the weather table"
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

# --- Parse dice expression ---
$DiceGroups = $null  # $null = single-group mode

if ($DiceStr -match '^(\d*)d(\d+)(k([hl])(\d*))?([+-]\d+)?$') {
    # Single-group (standard format, backward-compatible)
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
} elseif ($DiceStr -ne "") {
    # Multi-group: split on + and - boundaries, parse each term as a dice group or constant
    $DiceGroups = @()
    $parts = $DiceStr -split '(?=[+-])' | Where-Object { $_ -ne "" }
    foreach ($part in $parts) {
        if ($part -match '^([+-]?)(\d*)d(\d+)(k([hl])(\d*))?$') {
            $sign = if ($Matches[1] -eq '-') { -1 } else { 1 }
            $nd   = if ($Matches[2]) { [int]$Matches[2] } else { 1 }
            $si   = [int]$Matches[3]
            $kt   = if ($Matches[5]) { $Matches[5] } else { "" }
            $kc   = if ($kt -and $Matches[6]) { [int]$Matches[6] } elseif ($kt) { 1 } else { 0 }
            if ($kt -and $kc -gt $nd) { $kc = $nd }
            $DiceGroups += @{ IsNumber=$false; Sign=$sign; NumDice=$nd; Sides=$si; KeepType=$kt; KeepCount=$kc }
        } elseif ($part -match '^([+-]?\d+)$') {
            $DiceGroups += @{ IsNumber=$true; Value=[int]$Matches[1] }
        } else {
            Write-Host "Error: Invalid term '$part' in expression '$DiceStr'"
            exit
        }
    }
    if ($DiceGroups.Count -lt 2) {
        Write-Host "Error: Invalid dice expression '$DiceStr'"
        exit
    }
    $DiceLabel = $DiceStr
}

# --- Roll function ---
function Invoke-DiceRoll {
    if ($null -ne $DiceGroups) {
        # Multi-group roll: iterate each term, roll dice, accumulate total and display strings
        $total         = 0
        $groupDisplays = @()

        foreach ($grp in $DiceGroups) {
            if ($grp.IsNumber) {
                $total += $grp.Value
                $groupDisplays += @{ Str=$([Math]::Abs($grp.Value).ToString()); SignStr=if ($grp.Value -ge 0) { "+" } else { "-" } }
            } else {
                $rolls    = @(1..$grp.NumDice | ForEach-Object { Get-Random -Minimum 1 -Maximum ($grp.Sides + 1) })
                $keepMask = New-Object int[] $grp.NumDice
                $grpTotal = 0

                if ($grp.KeepType) {
                    $indexed = 0..($grp.NumDice-1) | ForEach-Object { [PSCustomObject]@{ Value=$rolls[$_]; Index=$_ } }
                    $sorted  = $indexed | Sort-Object Value
                    if ($grp.KeepType -eq "h") { $sorted | Select-Object -Last  $grp.KeepCount | ForEach-Object { $keepMask[$_.Index] = 1 } }
                    else                        { $sorted | Select-Object -First $grp.KeepCount | ForEach-Object { $keepMask[$_.Index] = 1 } }
                    for ($i = 0; $i -lt $grp.NumDice; $i++) { if ($keepMask[$i]) { $grpTotal += $rolls[$i] } }
                } else {
                    $grpTotal = ($rolls | Measure-Object -Sum).Sum
                }

                $total   += $grp.Sign * $grpTotal
                $parts    = @(0..($grp.NumDice-1) | ForEach-Object {
                    if ($grp.KeepType -and -not $keepMask[$_]) { "${ST}$($rolls[$_])${RST}" } else { "$($rolls[$_])" }
                })
                $str      = if ($grp.NumDice -gt 1) { "[" + ($parts -join ", ") + "]" } else { $parts[0] }
                $groupDisplays += @{ Str=$str; SignStr=if ($grp.Sign -ge 0) { "+" } else { "-" } }
            }
        }

        $displayParts = @($groupDisplays[0].Str)
        for ($i = 1; $i -lt $groupDisplays.Count; $i++) {
            $displayParts += "$($groupDisplays[$i].SignStr) $($groupDisplays[$i].Str)"
        }
        $displayStr = $displayParts -join " "
        $rollLabel  = "${DiceLabel}: "
        if ($null -ne $DC) {
            if ($total -ge $DC) { $rollLabel += "${GRN}${displayStr}${RST}" } else { $rollLabel += "${RED}${displayStr}${RST}" }
        } else { $rollLabel += $displayStr }

        if ($RepeatCount -gt 1) {
            Write-Host $rollLabel
        } else {
            Write-Host "Rolling $rollLabel"
            if ($null -ne $DC) { Write-Host "${BOLD}${YLW}Total: ${total} (1 successes, 0 failures)${RST}" }
            else                { Write-Host "${BOLD}${YLW}Total: ${total}${RST}" }
        }
        return $total
    }

    # Single-group roll
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

# --- Roll table ---
if ($TableName -ne "") {
    $table    = Get-Content $TableFile -Raw | ConvertFrom-Json
    $rollExpr = $table.roll.ToLower()

    # Parse the roll expression into groups
    $tGroups = @()
    $tParts  = $rollExpr -split '(?=[+-])' | Where-Object { $_ -ne "" }
    foreach ($part in $tParts) {
        if ($part -match '^([+-]?)(\d*)d(\d+)(k([hl])(\d*))?$') {
            $sign = if ($Matches[1] -eq '-') { -1 } else { 1 }
            $nd   = if ($Matches[2]) { [int]$Matches[2] } else { 1 }
            $si   = [int]$Matches[3]
            $kt   = if ($Matches[5]) { $Matches[5] } else { "" }
            $kc   = if ($kt -and $Matches[6]) { [int]$Matches[6] } elseif ($kt) { 1 } else { 0 }
            if ($kt -and $kc -gt $nd) { $kc = $nd }
            $tGroups += @{ Sign=$sign; NumDice=$nd; Sides=$si; KeepType=$kt; KeepCount=$kc }
        }
    }

    Invoke-DiceSound
    for ($r = 1; $r -le $RepeatCount; $r++) {
        $outcomes    = @()
        $diceDisplay = @()

        for ($g = 0; $g -lt $tGroups.Count; $g++) {
            $grp      = $tGroups[$g]
            $rolls    = @(1..$grp.NumDice | ForEach-Object { Get-Random -Minimum 1 -Maximum ($grp.Sides + 1) })
            $keepMask = New-Object int[] $grp.NumDice
            $grpTotal = 0

            if ($grp.KeepType) {
                $indexed = 0..($grp.NumDice-1) | ForEach-Object { [PSCustomObject]@{ Value=$rolls[$_]; Index=$_ } }
                $sorted  = $indexed | Sort-Object Value
                if ($grp.KeepType -eq "h") { $sorted | Select-Object -Last  $grp.KeepCount | ForEach-Object { $keepMask[$_.Index] = 1 } }
                else                        { $sorted | Select-Object -First $grp.KeepCount | ForEach-Object { $keepMask[$_.Index] = 1 } }
                for ($i = 0; $i -lt $grp.NumDice; $i++) { if ($keepMask[$i]) { $grpTotal += $rolls[$i] } }
            } else {
                $grpTotal = ($rolls | Measure-Object -Sum).Sum
            }

            $parts = @(0..($grp.NumDice-1) | ForEach-Object {
                if ($grp.KeepType -and -not $keepMask[$_]) { "${ST}$($rolls[$_])${RST}" } else { "$($rolls[$_])" }
            })
            $str = if ($grp.NumDice -gt 1) { "[" + ($parts -join ", ") + "]" } else { $parts[0] }
            $diceDisplay += $str

            if ($g -lt $table.results.Count) {
                $outcome = $table.results[$g].("$grpTotal")
                if ($null -eq $outcome) {
                    foreach ($prop in $table.results[$g].PSObject.Properties) {
                        if ($prop.Name -match '^(\d+)-(\d+)$' -and $grpTotal -ge [int]$Matches[1] -and $grpTotal -le [int]$Matches[2]) {
                            $outcome = $prop.Value
                            break
                        }
                    }
                }
                $outcomes += if ($null -ne $outcome) { $outcome } else { "($grpTotal)" }
            }
        }

        $diceStr2   = $diceDisplay -join " + "
        $outcomeStr = $outcomes -join ", "
        if ($RepeatCount -gt 1) {
            Write-Host "${TableName}: $diceStr2 → ${BOLD}$outcomeStr${RST}"
        } else {
            Write-Host "Rolling ${TableName} ($rollExpr): $diceStr2"
            Write-Host "${BOLD}${YLW}Result: $outcomeStr${RST}"
        }
    }
    exit
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
