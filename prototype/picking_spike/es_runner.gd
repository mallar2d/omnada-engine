class_name EsRunner
extends Node
## Base for a compiled event sheet (picking.md §4.1).

var dt := 0.0
var time := 0.0


func _process(delta: float) -> void:
	dt = delta
	time += delta


func new_sol() -> EsSol:
	return EsSol.new(get_tree())


## П7: position is set before _ready, so "On created" sees it.
func spawn(scene: PackedScene, at) -> Node:
	var inst := scene.instantiate()
	inst.position = at
	get_parent().add_child(inst)
	return inst


## П14: the timer is a child of the runner, so closing the level drops the wait silently.
func wait(seconds: float) -> Signal:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	add_child(timer)
	timer.timeout.connect(timer.queue_free)
	timer.start()
	return timer.timeout


func count(type: StringName) -> int:
	return get_tree().get_nodes_in_group(type).size()


## П16: connect existing instances of the type and every one added later.
func bind_trigger(type: StringName, signal_name: StringName, handler: Callable) -> void:
	for node in get_tree().get_nodes_in_group(type):
		_bind(node, signal_name, handler)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.is_in_group(type):
			_bind(node, signal_name, handler))


func _bind(node: Node, signal_name: StringName, handler: Callable) -> void:
	node.connect(signal_name, func(other: Node) -> void: handler.call(node, other))
