"""
Container for common functions for D&D5e gameplay.
"""
def stat_to_mod(stat):
    """Convert a stat score to its corresponding modifier"""
    return (stat - 10) // 2

def level_to_pb(level):
    """Calculate proficiency bonus based on character level"""
    return 2 + (level - 1) // 4