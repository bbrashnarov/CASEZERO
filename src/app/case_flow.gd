class_name CaseFlow
extends RefCounted
## Shared navigation decisions used by more than one screen (Board card, Reward "next case").

## Spec Part 4: unlocked card -> not started: INTRO, started: SCENE, solved: replay confirmation.
static func enter_case(ctx: AppContext, case_id: String, source: String) -> void:
	var status := Selectors.board_status(ctx.db, ctx.state(), case_id)
	match status:
		"locked":
			return
		"new":
			ctx.router.set_base(Router.intro(case_id, source))
		"in_progress":
			ctx.perform(CZ.NAVIGATE, {"case_id": case_id}, func(_r):
				var def := ctx.db.case_def(case_id)
				var run := ctx.run(case_id)
				ctx.analytics.track("CASE_RESUMED", {"case_id": case_id, "evidence_count": run["evidence"].size(),
					"stage": Selectors.stage_label(def, run, ctx.state()["campaign"])})
				ctx.router.set_base(Router.scene(case_id)))
		"solved":
			if ctx.router.base["kind"] != Router.BOARD:
				ctx.router.set_base(Router.board())
			ctx.router.push(Router.confirm_reset(case_id, "BOARD"))

## Pause -> Board before solve: progress is already committed; record the explicit exit.
static func exit_to_board(ctx: AppContext, case_id: String) -> void:
	var run := ctx.run(case_id)
	if not run.is_empty() and not run.get("solved", false):
		var def := ctx.db.case_def(case_id)
		ctx.analytics.track("CASE_EXITED", {"case_id": case_id, "stage": Selectors.stage_label(def, run, ctx.state()["campaign"]),
			"evidence_count": run["evidence"].size(), "reason": "board"})
	ctx.router.set_base(Router.board())
