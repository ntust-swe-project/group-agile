## Shared signal bus for Orbit Shift (autoload `Events`).
##
## Systems never look each other up; they talk only through these signals.
## This file declares signals only and holds no logic. The contract (who
## emits, who listens) lives in `production/epics/orbit-shift/EPIC.md`,
## section 整合約定. Change that section in a PR before changing a signal here.
extends Node

# Signals here are emitted by other scripts, so silence UNUSED_SIGNAL for this file.
@warning_ignore_start("unused_signal")

## A new day begins. Emitted by DayCycle (001); CrisisDirector (004) schedules the day's crises.
signal day_started(day: int)

## A day is over. Emitted by DayCycle (001); AutoRepair (005) grants build points.
signal day_ended(day: int)

## Station integrity changed. Emitted by StationIntegrity (001); the UI listens.
signal integrity_changed(current: float, max_value: float)

## The run is over. Emitted by 001; ResultScreen (006) shows the result and every system stops.
signal game_ended(won: bool, reason: StringName)

## All colonists collapsed. Emitted by Colonists (002); 001 treats it as a loss.
signal colonists_collapsed()

## A crisis began. `kind` is `&"breach"` or `&"malfunction"`; `room_id` comes
## from 002's room data. Emitted by CrisisDirector (004); 002, 003 and 005 listen.
signal crisis_started(crisis_id: int, kind: StringName, room_id: StringName)

## A crisis was resolved. Emitted by CrisisDirector (004); 002 and the UI listen.
signal crisis_resolved(crisis_id: int)

## A task that answers a crisis is done. Emitted by TaskBoard (003) and
## AutoRepair (005); CrisisDirector (004) stops the damage and resolves the crisis.
signal task_completed(task_id: int, crisis_id: int)
