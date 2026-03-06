# Solo Tabletop Utils
CLI utils for running solo TTRPGs on Windows. Includes a dice roller, character sheet loader, inventory manager, spell caster, and D&D 5e character sheet generator.

## Dice Roller
Usage:
```powershell
roll [num rolls] <num dice>d<die size>[kh/kl][num dice to keep] [DC]
```
Num dice and die size are required; all other params are optional.

Alternatively, you can roll a stat from a cached sheet (in Character Sheets/CACHE.json, if it exists):
```powershell
roll [skill/stat]
```
e.g. `roll str` or `roll perception`.

## Spell Caster
Cast spells from your character's known spell list, consuming spell slots tracked in the cached sheet.
```powershell
cast <spell name>          # cast at lowest available slot (escalates if needed)
cast <spell name> -l <N>  # cast using exactly slot level N
```
- Cantrips (level 0) are cast freely with no slot consumption.
- Without `-l`: uses the spell's base slot level. If unavailable, escalates to the next available higher slot.
- With `-l`: uses exactly that level. Reports failure rather than escalating if unavailable.
- Slot counts are saved back to `Character Sheets/CACHE.json` after each cast.

## Character Sheet Generator (D&D 5e)
Usage:
```powershell
python scripts/create_character_sheet.py
```
Optional parameters:
```powershell
-name: Character name
-l, --level: Character level (default 1)
-str: Strength score (default 10)
-dex: Dexterity score (default 10)
-con: Constitution score (default 10)
-int: Intelligence score (default 10)
-wis: Wisdom score (default 10)
-cha: Charisma score (default 10)
-profs: Comma-separated list of skill proficiencies. For expertise, add a * after the skill name.
-caster: Caster type — full, half, warlock, or none (default: none). Auto-generates spell slots.
-spells: Comma-separated known spells in "level:name" format (e.g. "0:Fire Bolt,1:Magic Missile").
-slots: Comma-separated spell slot counts in "level:count" format (e.g. "1:4,2:3"). Overrides -caster auto-generation.
-i, --input: Input file to read character attributes from (attributes are overridden by CLI args).
-o, --output: Output file to save attributes to (default: character.json in the Character Sheets folder).
--interactive: Prompt the user interactively for character attributes rather than using command-line arguments.
```

### Spell Slot Auto-Generation
When `-caster` is set, spell slots are calculated automatically based on character level:
- **full**: Standard full-caster progression (wizard, cleric, etc.).
- **half**: Full-caster formula applied to half the character level (rounded down) — paladin, ranger, etc.
- **warlock**: Only slots of the highest unlocked level (every 2 levels); 1/2/3/4 slots by tier.
- **none**: No spell slots generated.

### Sheet Caching
You can cache the values of a stored character sheet json file by using the `loadchar.ps1` script.
```powershell
loadchar [filename]
```
Include only the file name, not the path- this loader only looks in the Character Sheets folder. Once cached, rolling stats or skills with the `roll` command uses the values stored in the cached sheet.

### Additional Credits
- Dice rolling sound effect is from [Sound Effect Generator](https://soundeffectgenerator.org/audio-editor?url=https%3A%2F%2Fstore.soundeffectgenerator.org%2Finstants%2Fdice-roll-sound-effect%2F71e08973-rolling-dice.mp3). This is the same SFX used by Foundry VTT in their software!
- Some rollable tables are derived from [Juice Oracle](https://thunder9861.itch.io/juice-oracle).