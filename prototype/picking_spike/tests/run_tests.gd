extends SceneTree
## Behaviour tests from docs/design/picking.md §5 (T1–T16), a few from
## expressions.md §10, and the full example sheet from picking.md §4.3.
## Run: ./run.sh <path-to-godot-binary>

const ENEMY := preload("res://objects/enemy.gd")
const PLAYER := preload("res://objects/player.gd")
const BULLET := preload("res://objects/bullet.tscn")
const COIN := preload("res://objects/coin.tscn")
const EXAMPLE := preload("res://example_level.gd")

var failures: Array[String] = []
var passed := 0
var level: Node2D
var runner: EsRunner


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tests: Array[Callable] = [
		t01_filter_destroys_matching, t02_empty_pick_stops_event, t03_inverted_filter,
		t04_unreferenced_type_is_all, t05_sub_event_narrows, t06_sibling_sub_events,
		t07_top_level_events_independent, t08_else, t09_created_are_picked,
		t10_destroyed_not_picked, t11_for_each, t12_wait_keeps_pick, t13_trigger_once,
		t14_trigger_picks_participants, t14b_trigger_binds_spawned, t15_or_block,
		t16_level_closed_during_wait, e_text_and_math, example_sheet,
	]
	for test in tests:
		await _setup(RefCounted.new() if test != example_sheet else null)
		await test.call()
		await _teardown()
	print("\n%d passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	quit(1 if failures else 0)


# --- harness -----------------------------------------------------------------

func _setup(plain_runner) -> void:
	level = Node2D.new()
	root.add_child(level)
	runner = EsRunner.new() if plain_runner != null else EXAMPLE.new()
	level.add_child(runner)
	await process_frame


func _teardown() -> void:
	if is_instance_valid(level):
		level.free()
	await process_frame


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passed += 1
		print("ok   ", name)
	else:
		failures.append(name + (" — " + detail if detail else ""))
		print("FAIL ", name, " ", detail)


func _make(type: StringName, script: Script = null, props := {}) -> Node2D:
	var node := Node2D.new()
	if script:
		node.set_script(script)
	for key in props:
		node.set(key, props[key])
	node.add_to_group(type)
	level.add_child(node)
	return node


func _enemy(health: int, x := 0.0) -> Node2D:
	return _make(&"Enemy", ENEMY, {health = health, position = Vector2(x, 0)})


func _alive(type: StringName) -> int:
	return runner.new_sol().get_picked(type).size()


# --- compiled-style events used by several tests -----------------------------

## Enemy: health ≤ 0 (optionally inverted) → Enemy: destroy
func _ev_destroy_dead(parent: EsSol, invert := false) -> bool:
	var sol := parent.copy()
	if not sol.filter(&"Enemy", func(enemy): return (enemy.health <= 0) != invert):
		return false
	for enemy in sol.get_picked(&"Enemy"):
		enemy.queue_free()
	return true


# --- picking.md §5 ------------------------------------------------------------

func t01_filter_destroys_matching() -> void:
	var keep := _enemy(5)
	_enemy(0)
	_enemy(0)
	_ev_destroy_dead(runner.new_sol())
	await process_frame
	_check("T1 filter destroys only matching", _alive(&"Enemy") == 1 and is_instance_valid(keep))


func t02_empty_pick_stops_event() -> void:
	for i in 3:
		_enemy(5)
	var ran := _ev_destroy_dead(runner.new_sol())
	await process_frame
	_check("T2 empty pick stops event", not ran and _alive(&"Enemy") == 3)


func t03_inverted_filter() -> void:
	var dies := _enemy(5)
	_enemy(0)
	_enemy(0)
	_ev_destroy_dead(runner.new_sol(), true)
	await process_frame
	_check("T3 inverted filter", _alive(&"Enemy") == 2 and not is_instance_valid(dies))


func t04_unreferenced_type_is_all() -> void:
	_make(&"Player", PLAYER)
	_make(&"Player", PLAYER)
	var enemies := [_enemy(5), _enemy(6), _enemy(7)]
	var score := 0.0
	# Score ≥ 0 → Enemy: health = 1
	var sol := runner.new_sol()
	if score >= 0:
		for enemy in sol.get_picked(&"Enemy"):
			enemy.health = 1
	_check("T4 unreferenced type acts on all", enemies.all(func(e): return e.health == 1))


func t05_sub_event_narrows() -> void:
	var e1 := _enemy(1, 1)
	var e2 := _enemy(1, 2)
	var e3 := _enemy(1, 3)
	var sol := runner.new_sol().copy()
	if sol.filter(&"Enemy", func(enemy): return enemy.position.x > 1):
		var sub := sol.copy()
		if sub.filter(&"Enemy", func(enemy): return enemy.position.x > 2):
			for enemy in sub.get_picked(&"Enemy"):
				enemy.queue_free()
	await process_frame
	_check("T5 sub-event narrows parent pick",
			is_instance_valid(e1) and is_instance_valid(e2) and not is_instance_valid(e3))


func t06_sibling_sub_events() -> void:
	var e1 := _enemy(0, 1)
	var e2 := _enemy(0, 2)
	var e3 := _enemy(0, 3)
	var sol := runner.new_sol().copy()
	if sol.filter(&"Enemy", func(enemy): return enemy.position.x > 1):
		var a := sol.copy()
		if a.filter(&"Enemy", func(enemy): return enemy.position.x > 2):
			for enemy in a.get_picked(&"Enemy"):
				enemy.set_meta(&"a", true)
		var b := sol.copy()
		for enemy in b.get_picked(&"Enemy"):
			enemy.set_meta(&"b", true)
	_check("T6 sibling sub-events start from parent pick",
			not e1.has_meta(&"b") and e2.has_meta(&"b") and e3.has_meta(&"b")
			and not e2.has_meta(&"a") and e3.has_meta(&"a"))


func t07_top_level_events_independent() -> void:
	var enemies := [_enemy(0, 1), _enemy(0, 2), _enemy(0, 3)]
	var root_sol := runner.new_sol()
	var first := root_sol.copy()
	first.filter(&"Enemy", func(enemy): return enemy.position.x > 2)
	var second := root_sol.copy()
	for enemy in second.get_picked(&"Enemy"):
		enemy.health = 9
	_check("T7 top-level events are independent", enemies.all(func(e): return e.health == 9))


func t08_else() -> void:
	var score := 3.0
	var trace := []
	var ev := func() -> bool:
		if not (score > 5):
			return false
		trace.append("a")
		return true
	if not ev.call():
		trace.append("b")
	_check("T8 else runs when previous did not", trace == ["b"])


func t09_created_are_picked() -> void:
	var old: Node = BULLET.instantiate()
	level.add_child(old)
	var p1 := _make(&"Player", PLAYER, {position = Vector2(10, 0)})
	var p2 := _make(&"Player", PLAYER, {position = Vector2(20, 0)})
	var sol := runner.new_sol().copy()
	var created := []
	for player in sol.get_picked(&"Player"):
		created.append(runner.spawn(BULLET, player.position))
	sol.pick_only(&"Bullet", created)
	for bullet in sol.get_picked(&"Bullet"):
		bullet.speed = 100
	_check("T9 created instances are picked", created.size() == 2
			and created.all(func(b): return b.speed == 100) and old.speed == 0
			and created[0].position == p1.position and created[1].position == p2.position)


func t10_destroyed_not_picked() -> void:
	_enemy(0)
	_enemy(5)
	var root_sol := runner.new_sol()
	_ev_destroy_dead(root_sol)
	var counted := 0
	for enemy in root_sol.copy().get_picked(&"Enemy"):
		counted += 1
	_check("T10 destroyed instances leave the pick in the same frame", counted == 1)


func t11_for_each() -> void:
	for x in [10.0, 20.0, 30.0]:
		_enemy(1, x)
	var sol := runner.new_sol().copy()
	for enemy in sol.get_picked(&"Enemy"):
		var it := sol.copy()
		it.pick_only(&"Enemy", [enemy])
		var only = it.first(&"Enemy")
		runner.spawn(COIN, only.position)
	var xs := runner.new_sol().get_picked(&"Coin").map(func(c): return c.position.x)
	xs.sort()
	_check("T11 for each runs once per instance", xs == [10.0, 20.0, 30.0], str(xs))


func t12_wait_keeps_pick() -> void:
	var a := _enemy(1)
	var b := _enemy(1)
	var sol := runner.new_sol().copy()
	var done := [false]
	var actions := func() -> void:
		for enemy in sol.get_picked(&"Enemy"):
			enemy.visible = false
		await runner.wait(0.1)
		for enemy in sol.get_picked(&"Enemy"):
			enemy.visible = true
		done[0] = true
	actions.call()
	a.queue_free()
	await create_timer(0.3).timeout
	_check("T12 wait keeps pick minus destroyed", done[0] and b.visible and not is_instance_valid(a))


func t13_trigger_once() -> void:
	var state := {once = -1, score = 0.0, runs = 0}
	var tick := func() -> void:
		if not (state.score >= 10):
			return
		var frame := Engine.get_process_frames()
		var was_true: bool = state.once == frame - 1
		state.once = frame
		if was_true:
			return
		state.runs += 1
	for score in [10.0, 10.0, 10.0, 0.0, 10.0]:
		state.score = score
		tick.call()
		await process_frame
	_check("T13 trigger once while true", state.runs == 2, "runs=%d" % state.runs)


func t14_trigger_picks_participants() -> void:
	var player := _make(&"Player", PLAYER)
	var coin_a := COIN.instantiate()
	var coin_b := COIN.instantiate()
	level.add_child(coin_a)
	level.add_child(coin_b)
	runner.bind_trigger(&"Player", &"collided", func(p: Node, other: Node) -> void:
		if not other.is_in_group(&"Coin"):
			return
		var sol := runner.new_sol()
		sol.pick_only(&"Player", [p])
		sol.pick_only(&"Coin", [other])
		for coin in sol.get_picked(&"Coin"):
			coin.queue_free())
	player.collided.emit(coin_a)
	await process_frame
	_check("T14 trigger picks only participants", not is_instance_valid(coin_a) and is_instance_valid(coin_b))


func t14b_trigger_binds_spawned() -> void:
	var hits := []
	runner.bind_trigger(&"Bullet", &"collided", func(b: Node, other: Node) -> void: hits.append(other))
	var bullet = runner.spawn(BULLET, Vector2.ZERO)
	var target := _enemy(1)
	bullet.collided.emit(target)
	_check("T14b trigger binds instances created later", hits == [target])


func t15_or_block() -> void:
	var low := _enemy(1, 1)
	var mid := _enemy(1, 3)
	var high := _enemy(1, 5)
	# OR: Enemy: x < 2  OR  Enemy: x > 4 → destroy (П12: union, in order of first appearance)
	var sol := runner.new_sol().copy()
	var input := sol.get_picked(&"Enemy")
	var union := []
	for keep in [func(e): return e.position.x < 2, func(e): return e.position.x > 4]:
		for e in input.filter(keep):
			if e not in union:
				union.append(e)
	if not union.is_empty():
		sol.pick_only(&"Enemy", union)
		for enemy in sol.get_picked(&"Enemy"):
			enemy.queue_free()
	await process_frame
	_check("T15 OR block picks union",
			not is_instance_valid(low) and is_instance_valid(mid) and not is_instance_valid(high))


func t16_level_closed_during_wait() -> void:
	var finished := [false]
	var actions := func() -> void:
		await runner.wait(0.1)
		finished[0] = true
	actions.call()
	level.free()
	await create_timer(0.3).timeout
	# Errors, if any, show up in the log; run.sh fails on "SCRIPT ERROR".
	_check("T16 closing the level during wait drops the rest", not finished[0])


# --- expressions.md §10 (runtime part) ---------------------------------------

func e_text_and_math() -> void:
	_check("E1 7 / 2 with floats", 7.0 / 2 == 3.5)
	_check("E2 fmod keeps dividend sign", fmod(7, 3) == 1 and fmod(-7, 3) == -1)
	_check("E3 pow right-assoc", pow(2, pow(3, 2)) == 512 and -pow(2, 2) == -4)
	var cases := {3.0: "3", 2.5: "2.5", -0.0: "0", -4.0: "-4", 0.1: "0.1"}
	var wrong := []
	for v in cases:
		if Es.text(v) != cases[v]:
			wrong.append("%s -> %s" % [cases[v], Es.text(v)])
	_check("E4 Es.text drops .0", wrong.is_empty() and Es.text(7) == "7" and Es.text("a") == "a", str(wrong))


# --- picking.md §4.3: the full example sheet, extracted verbatim -------------

func example_sheet() -> void:
	var player := _make(&"Player", PLAYER, {position = Vector2(0, 0)})
	var coin := COIN.instantiate()
	level.add_child(coin)
	var dead := _enemy(0, 100)
	var near := _enemy(3, 5)
	var hud := Label.new()
	hud.add_to_group(&"HUD")
	level.add_child(hud)

	player.collided.emit(coin)
	await process_frame
	await process_frame
	_check("X1 event 2: coin collected", not is_instance_valid(coin) and runner.score == 1.0)
	_check("X2 event 4: dead enemy destroyed", not is_instance_valid(dead) and is_instance_valid(near))
	_check("X3 event 7 (else): HUD shows score", hud.text == "Монети: 1", hud.text)

	runner.score = 10.0
	await process_frame
	await process_frame
	_check("X4 event 6.1: victory text", hud.text == "Перемога!", hud.text)
	hud.text = "x"
	await process_frame
	_check("X5 event 6.1: only once while true", hud.text == "x", hud.text)

	var bullets_before := _alive(&"Bullet")
	Input.action_press(&"shoot")
	await process_frame
	Input.action_release(&"shoot")
	await process_frame
	_check("X6 event 1: shoot spawns a bullet per player", _alive(&"Bullet") == bullets_before + 1,
			"%d -> %d" % [bullets_before, _alive(&"Bullet")])
	_check("X7 runner keeps dt and time updated", runner.dt > 0.0 and runner.time > 0.0,
			"dt=%s time=%s" % [runner.dt, runner.time])
