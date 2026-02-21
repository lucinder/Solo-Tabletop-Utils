# Solo Tabletop Utils
CLI Utils for running solo TTRPGS in Windows. Right now, this is just a shell script for doing command line rolls and python script for generating character sheet json files, but I will likely add more utils in the future.

## Dice Roller
Usage:
```powershell
roll [num rolls] <num dice>d<die size>[kh/kl][num dice to keep] [DC]
```
Num dice and die size are required; all other params are optional.

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
-i, --input: Input file to read character attributes from (attributes are overridden by CLI args).
-o, --output: Output file to save attributes to (default: character.json in the Character Sheets folder).
--interactive: Prompt the user interactively for character attributes rather than using command-line arguments.
```