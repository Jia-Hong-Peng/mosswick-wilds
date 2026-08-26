extends RefCounted
## Inventory: add, use, deplete, never negative, serialization roundtrip.

const InventoryScript := preload("res://scripts/core/inventory_service.gd")


func run(t: TestContext) -> void:
	var inventory: Node = InventoryScript.new()
	inventory.add_item("berry_tonic", 2)
	t.check_eq(inventory.count("berry_tonic"), 2, "add_item must accumulate")
	inventory.add_item("berry_tonic")
	t.check_eq(inventory.count("berry_tonic"), 3, "default add amount is 1")
	t.check(inventory.use_item("berry_tonic"), "using an owned item succeeds")
	t.check_eq(inventory.count("berry_tonic"), 2, "use_item must deduct exactly one")
	t.check(inventory.use_item("berry_tonic"), "second use succeeds")
	t.check(inventory.use_item("berry_tonic"), "third use succeeds")
	t.check(not inventory.use_item("berry_tonic"), "using a depleted item must fail")
	t.check_eq(inventory.count("berry_tonic"), 0, "count never goes negative")
	t.check(not inventory.use_item("unknown_item"), "unknown items cannot be used")
	t.check_eq(inventory.count("unknown_item"), 0, "unknown items count as zero")
	inventory.add_item("snare_orb", 0)
	t.check_eq(inventory.count("snare_orb"), 0, "adding zero is a no-op")

	inventory.add_item("snare_orb", 5)
	var saved: Dictionary = inventory.to_dict()
	var restored: Node = InventoryScript.new()
	restored.load_from(saved)
	t.check_eq(restored.count("snare_orb"), 5, "roundtrip keeps counts")
	t.check_eq(restored.count("berry_tonic"), 0, "depleted items stay absent after roundtrip")
	inventory.free()
	restored.free()
