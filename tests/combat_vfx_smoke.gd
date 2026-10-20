extends SceneTree
## Focused regression test for the texture-free combat slash effects.

const SlashFX := preload("res://scripts/combat/slash_fx.gd")

var failures: PackedStringArray = []
var passes := 0


func _initialize() -> void:
	call_deferred("_run_test")


func check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
	else:
		failures.append(message)
		push_error(message)


func _run_test() -> void:
	var holder := Node2D.new()
	root.add_child(holder)

	var styles: Array[String] = ["slash", "cross", "claw", "tornado", "dash"]
	for i in range(styles.size()):
		var style: String = styles[i]
		var pos := Vector2(24.0 * float(i), 12.0 * float(i + 1))
		SlashFX.spawn(holder, pos, Vector2.RIGHT, Color(0.9, 0.7, 1.0), style, 1.0)

	await process_frame
	check(holder.get_child_count() == styles.size(), "Each VFX style should spawn one effect node.")

	for i in range(mini(holder.get_child_count(), styles.size())):
		var fx := holder.get_child(i)
		check(String(fx.get("style")) == styles[i], "%s style should be retained." % styles[i])
		var expected := Vector2(24.0 * float(i), 12.0 * float(i + 1))
		check((fx as Node2D).global_position.is_equal_approx(expected), "%s should spawn at the requested world position." % styles[i])

	await create_timer(0.30).timeout
	await process_frame
	check(holder.get_child_count() == 0, "All VFX nodes should clean themselves up after their 0.22s lifetime.")

	if failures.is_empty():
		print("Combat VFX smoke test passed (%d checks): all five styles spawn at the requested positions and self-remove." % passes)
		holder.free()
		quit(0)
	else:
		push_error("%d combat VFX checks failed (%d passed)." % [failures.size(), passes])
		holder.free()
		quit(1)
