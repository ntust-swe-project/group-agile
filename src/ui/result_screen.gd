## End-of-run screen (story 006): result, survived days, integrity, colonists.
##
## Display only. Hidden until [signal Events.game_ended] arrives. The numbers are
## read from [member day_cycle], [member station_integrity] and
## [member colonists], which Main injects (main.gd INJECTIONS); they are not
## usable inside [method Node._ready]. Any of them may be null, and the field
## then shows [constant MISSING] instead of failing. The text is built by the
## pure static [method summary_lines], so it can be tested without a scene.
## [codeblock]
## const RESULT_SCREEN := preload("res://src/ui/result_screen.gd")
## var lines := RESULT_SCREEN.summary_lines(false, &"integrity_depleted", cycle, integrity, colonists)
## # ["STATION LOST", "Reason: Integrity depleted", "Days survived: 3 / 30", ...]
## [/codeblock]
extends CanvasLayer

## Shown for a field whose source is missing.
const MISSING := "—"
## First line of the summary for a win.
const TITLE_WON := "VICTORY"
## First line of the summary for a loss.
const TITLE_LOST := "STATION LOST"

## Loss reason (as in DayCycle.REASON_*) -> text shown to the player.
const REASON_TEXT := {
	&"integrity_depleted": "Integrity depleted",
	&"colonists_collapsed": "All colonists collapsed",
}

## The DayCycle node; set by Main before the first frame.
var day_cycle: Node
## The StationIntegrity node; set by Main before the first frame.
var station_integrity: Node
## The Colonists node; set by Main before the first frame.
var colonists: Node

@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _play_again: Button = %PlayAgainButton


func _ready() -> void:
	visible = false
	Events.game_ended.connect(_on_game_ended)
	_play_again.pressed.connect(restart)


## Lines of the result screen. Index 0 is the title ("VICTORY" or
## "STATION LOST"); a loss follows with its reason, then days survived,
## integrity and the colonists. A node that is null shows [constant MISSING].
## Days survived: the whole run when [param won], else the day in progress
## did not count. Example: [code]summary_lines(true, &"survived", cycle, null, null)[/code]
static func summary_lines(won: bool, reason: StringName, p_day_cycle: Node,
		p_integrity: Node, p_colonists: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(TITLE_WON if won else TITLE_LOST)
	if not won:
		var reason_text: String = REASON_TEXT.get(reason, String(reason))
		lines.append("Reason: " + reason_text)
	lines.append("Days survived: " + _days_text(won, p_day_cycle))
	lines.append("Integrity: " + _integrity_text(p_integrity))
	lines.append_array(_colonist_lines(p_colonists))
	return lines


## Starts a new run by reloading the main scene.
func restart() -> void:
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("ResultScreen.restart: reload_current_scene failed (%s)" % error_string(error))


static func _days_text(won: bool, p_day_cycle: Node) -> String:
	if p_day_cycle == null:
		return MISSING
	var survived: int = p_day_cycle.total_days if won else maxi(p_day_cycle.current_day - 1, 0)
	return "%d / %d" % [survived, p_day_cycle.total_days]


static func _integrity_text(p_integrity: Node) -> String:
	if p_integrity == null:
		return MISSING
	return "%d / %d" % [ceili(p_integrity.current), ceili(p_integrity.max_value)]


static func _colonist_lines(p_colonists: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	if p_colonists == null or p_colonists.colonists.is_empty():
		lines.append("Colonists: " + MISSING)
		return lines
	lines.append("Colonists:")
	for colonist: Colonist in p_colonists.colonists:
		lines.append("  %s: %s" % [colonist.display_name, ColonistStatus.label(ColonistStatus.of(colonist))])
	return lines


# The first result is final: DayCycle emits game_ended once, and a stray later
# emit must not rewrite the screen the player is reading.
func _on_game_ended(won: bool, reason: StringName) -> void:
	if visible:
		return
	var lines := summary_lines(won, reason, day_cycle, station_integrity, colonists)
	_title.text = lines[0]
	_body.text = "\n".join(lines.slice(1))
	visible = true
	_play_again.grab_focus()
