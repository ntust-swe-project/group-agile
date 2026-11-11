## Build-point readout and one build button per room (story 005).
##
## Display plus requests only: a click calls `auto_repair.build(room_id)`, which
## decides whether it is allowed. Sits at the top, right of the day/integrity
## HUD text, so the top-left HUD area stays free. The buttons wrap into rows of
## [constant BUTTON_COLUMNS] so even with every room built the panel stays on
## screen and above the station hull (which starts at y 143).
extends CanvasLayer

const FONT_SIZE := 24
const PANEL_POSITION := Vector2(460, 16)
const BUTTON_COLUMNS := 3

## The AutoRepair node to read and ask; set by it.
var auto_repair: Node

var _points_label: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	var row := HBoxContainer.new()
	row.position = PANEL_POSITION
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(_points_label)
	var grid := GridContainer.new()
	grid.columns = BUTTON_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	row.add_child(grid)
	for room_id in auto_repair.map.room_ids:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(auto_repair.build.bind(room_id))
		grid.add_child(button)
		_buttons[room_id] = button


func _process(_delta: float) -> void:
	_points_label.text = "Build points: %d (module %d)" % [auto_repair.build_points.points, auto_repair.module_cost]
	for room_id: StringName in _buttons:
		var button: Button = _buttons[room_id]
		var room_name: String = auto_repair.map.get_room(room_id)["name"]
		button.text = "AUTO %s%s" % [room_name, " (built)" if auto_repair.modules.has(room_id) else ""]
		button.disabled = not auto_repair.can_build(room_id)
