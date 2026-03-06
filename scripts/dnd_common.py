"""
Container for common functions for D&D5e gameplay.
"""
def stat_to_mod(stat):
    """Convert a stat score to its corresponding modifier"""
    return (stat - 10) // 2

def level_to_pb(level):
    """Calculate proficiency bonus based on character level"""
    return 2 + (level - 1) // 4

def _full_slots_at(effective_level):
    """
    Calculate spell slots for a full caster at the given effective level.

    Unlock schedule: spell slot level S unlocks at effective level (2S - 1).
    On unlock: 2 slots for levels 1-3, 1 slot for levels 4-9.
    For effective levels 1-10, each level after an unlock and before the next
    unlock grants +1 slot of that level.
    Exceptions: +1 1st-level slot at eff. level 3; +1 4th-level slot at eff.
    level 9; +1 5th, 6th, 7th at eff. levels 18, 19, 20 respectively.
    """
    if effective_level < 1:
        return {}
    slots = {}
    for s in range(1, 10):
        unlock_at = 2 * s - 1
        if effective_level < unlock_at:
            continue
        next_unlock = unlock_at + 2
        base = 2 if s <= 3 else 1
        extra = max(0, min(effective_level, 10, next_unlock - 1) - unlock_at)
        slots[str(s)] = base + extra
    # Exceptions
    if effective_level >= 3 and "1" in slots:
        slots["1"] += 1
    if effective_level >= 9 and "4" in slots:
        slots["4"] += 1
    if effective_level >= 18 and "5" in slots:
        slots["5"] += 1
    if effective_level >= 19 and "6" in slots:
        slots["6"] += 1
    if effective_level >= 20 and "7" in slots:
        slots["7"] += 1
    return slots

def calc_spell_slots(caster_type, level):
    """
    Calculate spell slots given a caster type and character level.

    caster_type: "full" | "half" | "warlock" | "none"
    Returns a dict mapping slot level strings ("1"-"9") to slot counts.
    """
    ct = caster_type.lower()
    if ct == "full":
        return _full_slots_at(level)
    elif ct == "half":
        return _full_slots_at(level // 2)
    elif ct == "warlock":
        max_slot = min(9, (level + 1) // 2)
        if max_slot < 1:
            return {}
        if level == 1:
            count = 1
        elif level <= 10:
            count = 2
        elif level <= 16:
            count = 3
        else:
            count = 4
        return {str(max_slot): count}
    else:
        return {}