"""
Create a character sheet from command line arguments or user input

Usage:
    python create_character_sheet.py [options]
  - -name: name of the character
  - -l or --level: character level (default: 1)
  - -pb: proficiency bonus (default: 2; if not indicated, it will be calculated based on level)
  - -str: strength score (default: 10)
  - -dex: dexterity score (default: 10)
  - -con: constitution score (default: 10)
  - -int: intelligence score (default: 10)
  - -wis: wisdom score (default: 10)
  - -cha: charisma score (default: 10)
  - -profs: comma-separated list of proficiencies (e.g. "Stealth, Perception")
  - -i or --input: file name to load character data from (sets values from the file, but can be overridden by other command line arguments)
  - -o or --output: file name to save the character sheet to (default: character.json)
  - --interactive: if set, prompts the user for input instead of using command line arguments
"""

import argparse, sys, json
from pathlib import Path
from dnd_common import level_to_pb

workspace = Path(__file__).parent.parent # Get working directory
DEBUG = False

cached_sheet = {
    "name": "Character",
    "level": 1,
    "proficiency_bonus": 2,
    "stats": {
        "str": 10,
        "dex": 10,
        "con": 10,
        "int": 10,
        "wis": 10,
        "cha": 10
    },
    "proficiencies": []
}

def build_sheet(args):
    if DEBUG: print("[DEBUG] Building character sheet from command line arguments")
    sheet = cached_sheet.copy()
    if args.input:
        with open(args.input, "r") as f:
            sheet.update(json.load(f))
    if args.name:
        sheet["name"] = args.name
    if args.level:
        sheet["level"] = args.level
    if args.pb:
        sheet["proficiency_bonus"] = args.pb
    else:
        sheet["proficiency_bonus"] = level_to_pb(sheet["level"])
    for stat in ["str", "dex", "con", "int", "wis", "cha"]:
        arg_value = getattr(args, stat)
        if arg_value is not None:
            sheet["stats"][stat] = arg_value
    if args.profs:
        sheet["proficiencies"] = [prof.strip() for prof in args.profs.split(",")]
    return sheet

def build_sheet_interactive(args):
    if DEBUG: print("[DEBUG] Building character sheet interactively")
    sheet = cached_sheet.copy()
    sheet["name"] = input("Character name: ")
    level_str = input("Character level: ")
    sheet["level"] = int(level_str) if level_str else 1
    sheet["proficiency_bonus"] = level_to_pb(sheet["level"])
    for stat in ["str", "dex", "con", "int", "wis", "cha"]:
        score_str = input(f"{stat.upper()} score: ")
        sheet["stats"][stat] = int(score_str) if score_str else 10
    profs_input = input("Proficiencies (comma-separated): ")
    sheet["proficiencies"] = [prof.strip() for prof in profs_input.split(",")] if profs_input else []
    return sheet

def export_sheet(sheet, output_file):
    output_path = str(workspace / "Character Sheets" / output_file)
    if DEBUG: print(f"[DEBUG] Exporting character sheet to {output_path}")
    with open(output_path, "w") as f:
        json.dump(sheet, f, indent=4)
    print(f"Character sheet saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("-name", type=str, help="Name of the character (and output file, if not otherwise specified)")
    parser.add_argument("-l", "--level", type=int, default=1, help="Character level (default: 1)")
    parser.add_argument("-pb", type=int, help="Proficiency bonus (default: calculated based on level)")
    parser.add_argument("-str", type=int, default=10, help="Strength score (default: 10)")
    parser.add_argument("-dex", type=int, default=10, help="Dexterity score (default: 10)")
    parser.add_argument("-con", type=int, default=10, help="Constitution score (default: 10)")
    parser.add_argument("-int", type=int, default=10, help="Intelligence score (default: 10)")
    parser.add_argument("-wis", type=int, default=10, help="Wisdom score (default: 10)")
    parser.add_argument("-cha", type=int, default=10, help="Charisma score (default: 10)")
    parser.add_argument("-profs", type=str, help="Comma-separated list of proficiencies (e.g. \"Stealth, Perception\")")
    parser.add_argument("-i", "--input", type=str, help="File name to load character data from (sets values from the file, but can be overridden by other command line arguments)")
    parser.add_argument("-o", "--output", type=str, help="File name to save the character sheet to (default: character.json)")
    parser.add_argument("--interactive", action="store_true", help="If set, prompts the user for input instead of using command line arguments")
    parser.add_argument("--debug", action="store_true", help="Verbose output for debugging")
    args = parser.parse_args()

    # Set debug flag
    DEBUG = args.debug

    # Validate files
    if args.input:
        if DEBUG: print(f"[DEBUG] Checking if input file exists: {args.input}")
        if not args.input.exists():
            print(f"[ERROR] File not found: {args.input}", file=sys.stderr)
            sys.exit(1)
        else:
            input_file = args.input
    output_file = args.output or (args.name + ".json" if args.name else "character.json")
    if DEBUG: print(f"[DEBUG] Output file set to: {output_file}")

    if args.interactive:
        sheet = build_sheet_interactive(args)
    else:
        sheet = build_sheet(args)
    export_sheet(sheet, output_file)
    sys.exit(0)

if __name__ == "__main__":
    main()