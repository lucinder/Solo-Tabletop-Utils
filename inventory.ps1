# inventory.ps1 - Manage the active character's inventory
# Usage: inventory
#        inventory <item name>
#        inventory -a|--add <item name> [-q|--qty <n>]
#        inventory -r|--remove <item name> [-q|--qty <n>]

param(
    [Alias('a')][switch]$Add,
    [Alias('r')][switch]$Remove,
    [Alias('q')][int]$Qty = 1,
    [Parameter(Position=0, ValueFromRemainingArguments=$true)][string[]]$Item
)

$cachePath = Join-Path $PSScriptRoot "Character Sheets\CACHE.json"

if (-not (Test-Path $cachePath)) {
    Write-Host "Error: No active character. Use 'loadchar' to load one."
    exit
}

$sheet = Get-Content $cachePath -Raw | ConvertFrom-Json

# Normalize inventory: JSON {} becomes a PSCustomObject, [] becomes an array.
# PS5.1 ConvertTo-Json also collapses a single-element array to a plain object on save,
# so a one-item inventory reads back as a PSCustomObject with a 'name' property.
# Use if-statement form (not if-expression) so @() assignment is direct and never
# pipeline-unrolled into a bare PSCustomObject.
if ($sheet.inventory -is [array]) {
    $inv = @($sheet.inventory)
} elseif ($null -ne $sheet.inventory -and $sheet.inventory.PSObject.Properties['name']) {
    $inv = @($sheet.inventory)   # single item stored as collapsed object
} else {
    $inv = @()
}

$itemName = ($Item -join ' ').Trim()

function Find-ItemIndex([string]$Name) {
    for ($i = 0; $i -lt $inv.Count; $i++) {
        if ($inv[$i].name -ieq $Name) { return $i }
    }
    return -1
}

function Save-Inventory {
    $sheet.inventory = $inv
    $json = $sheet | ConvertTo-Json -Depth 10
    # PS5.1 ConvertTo-Json collapses single-element arrays to plain objects.
    # Detect this case and wrap the inventory block in array brackets.
    if ($inv.Count -eq 1) {
        $json = [regex]::Replace($json, '("inventory":\s+)(\{[^}]*\})', '$1[$2]')
    }
    $json | Set-Content $cachePath
}

# Validation
if ($Add -and $Remove) {
    Write-Host "Error: Cannot use --add and --remove together."
    exit
}

# No flags, no item name: list entire inventory
if (-not $Add -and -not $Remove -and -not $itemName) {
    if ($inv.Count -eq 0) {
        Write-Host "$($sheet.name)'s inventory is empty."
    } else {
        Write-Host "$($sheet.name)'s Inventory:"
        foreach ($entry in $inv) {
            Write-Host "  $($entry.name) - $($entry.quantity)x"
        }
    }
    exit
}

# No flags, item name given: query
if (-not $Add -and -not $Remove) {
    $idx = Find-ItemIndex $itemName
    if ($idx -ge 0) {
        Write-Host "$($inv[$idx].name) - $($inv[$idx].quantity)x"
    } else {
        Write-Host "Item not found in inventory!"
    }
    exit
}

# --add
if ($Add) {
    if (-not $itemName) {
        Write-Host "Error: Specify an item name to add."
        exit
    }
    $idx = Find-ItemIndex $itemName
    if ($idx -ge 0) {
        $inv[$idx].quantity += $Qty
        Write-Host "Updated: $($inv[$idx].name) - $($inv[$idx].quantity)x"
    } else {
        $inv += [pscustomobject]@{ name = $itemName; quantity = $Qty }
        Write-Host "Added: $itemName - ${Qty}x"
    }
    Save-Inventory
    exit
}

# --remove
if ($Remove) {
    if (-not $itemName) {
        Write-Host "Error: Specify an item name to remove."
        exit
    }
    $idx = Find-ItemIndex $itemName
    if ($idx -lt 0) {
        Write-Host "Item not found in inventory!"
        exit
    }
    $inv[$idx].quantity -= $Qty
    if ($inv[$idx].quantity -le 0) {
        $removedName = $inv[$idx].name
        $inv = @($inv | Where-Object { $_.name -ine $itemName })
        Write-Host "Removed: $removedName"
    } else {
        Write-Host "Updated: $($inv[$idx].name) - $($inv[$idx].quantity)x"
    }
    Save-Inventory
    exit
}
