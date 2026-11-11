## Crisis kinds used as `kind` in [signal Events.crisis_started] (EPIC.md 整合約定).
##
## Compare against these constants instead of typing the literal:
## [codeblock]
## if kind == CrisisKind.BREACH:
##     pass
## [/codeblock]
class_name CrisisKind
extends RefCounted

## Meteor hull breach (隕石破洞).
const BREACH := &"breach"

## Equipment malfunction (設備故障).
const MALFUNCTION := &"malfunction"

## Every valid kind, in contract order.
const ALL := [BREACH, MALFUNCTION]
