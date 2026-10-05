class_name PManager
extends InteractionProfile
## P_MANAGER (spec Part 2): P_INSPECT behind a content gate (q.C01_Q1). While the gate is false
## the object stays visible with a lock icon and the tap shows its locked_text; the reducer
## handles the gate generically, this profile only marks the object as lockable for the UI.

func id() -> String:
	return CZ.P_MANAGER

func shows_lock_icon() -> bool:
	return true
