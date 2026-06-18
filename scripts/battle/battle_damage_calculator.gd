class_name BattleDamageCalculator
extends RefCounted

# Centralizes battle damage formulas so future changes such as armor, elements,
# critical hits, and skill tags can be added without expanding BattleManager.
const PARTY_BASIC_ATTACK_BONUS := 3
const ENEMY_BASIC_ATTACK_BONUS := 2
const GUARDED_DAMAGE_MULTIPLIER := 0.5


func basic_attack_damage(attacker: Dictionary, attacker_side: String) -> int:
	var attack_bonus := PARTY_BASIC_ATTACK_BONUS if attacker_side == "party" else ENEMY_BASIC_ATTACK_BONUS
	return max(1, int(attacker.get("strength", 0)) + attack_bonus)


func skill_damage(attacker: Dictionary, skill: Dictionary) -> int:
	var stat_id := String(skill.get("scaling_stat", "intelligence"))
	var stat_value := int(attacker.get(stat_id, 0))
	var base_damage := int(skill.get("base_damage", 0))
	var power := int(skill.get("power", 1))
	return max(1, base_damage + stat_value * power)


func guarded_damage(damage: int) -> int:
	return max(1, int(float(damage) * GUARDED_DAMAGE_MULTIPLIER))
