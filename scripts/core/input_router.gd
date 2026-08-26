extends Node
## Autoload: routes raw input into game contexts. UI and gameplay scripts
## poll actions only while their context is on top of the stack, so opening
## a dialogue or menu automatically freezes world movement.

enum Context { NONE, TITLE, WORLD, DIALOGUE, MENU, BATTLE, OBSERVE }

var _stack: Array[int] = []


func set_base_context(context: int) -> void:
	_stack = [context]


func push_context(context: int) -> void:
	_stack.append(context)


func pop_context() -> void:
	if _stack.size() > 0:
		_stack.pop_back()


func current() -> int:
	return _stack.back() if _stack.size() > 0 else Context.NONE


func is_context(context: int) -> bool:
	return current() == context


## Cardinal-only movement input; axes never combine, so no diagonal steps.
func movement_dir() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO
