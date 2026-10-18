--!strict
-- Player-facing text for big deals (owned by `projects`; contracts §9). Pure data: shared by ProjectService (toasts,
-- errors, prompts), ProjectController and the Project screen, so everything can be localized later. Deal CONTENT
-- (questions, dialogue, documents) lives in each Logic/Projects/<id> module.
--
--   Strings[key] = text with "{var}" placeholders (filled by _registry.text(key, vars))
--   Error keys are "err_<key>": the remotes answer (false, key) and the client shows text("err_" .. key).

return {
	---------------------------------------------------------------------------------------------------
	-- Menu, prompt, list
	---------------------------------------------------------------------------------------------------
	menu = "Deals",
	prompt_action = "Deals & Projects",
	prompt_object = "Deal desk",
	title = "Deals & Projects",
	subtitle_role = "{track} · {title}",
	subtitle_none = "Big deals for bankers on the Street",
	loading = "Loading your deal pipeline…",
	retry = "Try again",
	list_intro = "Big deals are multi-stage projects. Each one closes with a deal plaque for your desk.",
	empty_student = "Big deals are for bankers with a job. Land an offer through campus recruiting first.",
	empty_fired = "Your pipeline went with the job. Career Services can get you back on a desk.",
	empty_track = "Your team has no big deals yet. They arrive in a later update.",

	card_signature = "Signature deal",
	card_stages = "{n} stages",
	card_best = "Best {q}",
	card_closed = "Closed {n}×",
	card_repeat = "Repeat run: {pct}% rewards",
	card_estimate = "~{xp} XP · ~{pay}",
	card_estimate_xp = "~{xp} XP",
	card_ranks = "{lo} to {hi}",
	card_rank_one = "{lo}",
	card_start = "Start deal",
	card_resume = "Resume · stage {i} of {n}",
	card_locked_rank = "Unlocks at {title}",
	card_locked_past = "Handed to juniors after {title}",
	card_cooldown = "Next deal in {time}",
	card_unavailable = "Unavailable",
	card_active = "In progress",

	---------------------------------------------------------------------------------------------------
	-- Runner
	---------------------------------------------------------------------------------------------------
	runner_stage = "Stage {i} of {n}",
	runner_submit = "Submit stage",
	runner_final = "Close the deal",
	runner_submitting = "Submitting…",
	runner_abandon = "Abandon",
	runner_abandon_title = "Abandon this deal?",
	runner_abandon_body = "You'll lose the progress on this deal and the client will be disappointed. You can start a fresh one in a minute.",
	runner_incomplete_title = "Submit anyway?",
	runner_incomplete = "{left} answer(s) are still blank. Blank answers score zero.",
	runner_answered = "{n}/{total} answered",
	runner_hints_show = "Show hints ({n})",
	runner_hints_hide = "Hide hints",
	runner_part_error = "This part couldn't be shown. Abandon the deal and start it again, or try later.",
	runner_back = "All deals",
	runner_metrics = "Deal room",

	debrief_title = "{stage}",
	debrief_score = "Stage score {score}",
	debrief_next = "Up next: {stage}",
	debrief_continue = "Continue",
	debrief_final = "See how it closed",

	stage_done = "Done · {score}",
	stage_now = "Now",
	stage_next = "Next",

	---------------------------------------------------------------------------------------------------
	-- Results story
	---------------------------------------------------------------------------------------------------
	result_closed = "DEAL CLOSED",
	result_pulled = "DEAL PULLED",
	result_quality = "Deal quality",
	result_plaque = "Deal plaque added to your desk",
	result_no_plaque = "No plaque: the deal didn't close",
	result_xp = "+{xp} XP",
	result_pay = "+{pay}",
	result_rep = "+{rep} reputation",
	result_repeat = "Repeat run: reduced rewards",
	result_stats = "Trained: {stats}",
	result_stages = "How it went",
	result_feedback = "Notes from the team",
	result_back = "Back to deals",
	result_close = "Close",
	result_band_great = "A deal people will talk about for years.",
	result_band_good = "A strong deal. The MD is pleased.",
	result_band_ok = "It got done, with a few bruises.",
	result_band_weak = "A rough process. The client noticed.",
	result_band_bad = "A painful one. Learn from it and go again.",

	---------------------------------------------------------------------------------------------------
	-- Toasts and prompts (server)
	---------------------------------------------------------------------------------------------------
	toast_started = "{title} kicked off. The client is counting on you.",
	toast_closed = "{name} closed! +{xp} XP",
	toast_closed_pay = "{name} closed! +{xp} XP · +{pay}",
	toast_pulled = "{title} fell through. +{xp} XP for the work.",
	toast_cancel_fired = "Your active deals went with the job.",
	toast_cancel_role = "{title} was handed to another team after your move.",
	toast_cancel_reset = "{title} was updated since you started it. Start it again from the deal desk.",
	toast_abandoned = "Deal abandoned.",
	employees_only = "Employees only: this deal desk belongs to {company}.",
	employees_only_generic = "Employees only.",
	no_job = "Deals are for bankers with a job on the Street.",

	---------------------------------------------------------------------------------------------------
	-- Errors (remote answers)
	---------------------------------------------------------------------------------------------------
	err_not_loaded = "Your data is still loading. Try again in a moment.",
	err_unknown = "That deal doesn't exist.",
	err_not_employed = "You need a job on the Street to work on deals.",
	err_wrong_track = "That deal isn't run by your team.",
	err_rank_low = "That deal unlocks at {title}.",
	err_rank_high = "Senior bankers hand that deal to their juniors.",
	err_cooldown = "The next deal like this arrives in {time}.",
	err_not_active = "That deal isn't in progress.",
	err_done = "That deal has already closed.",
	err_bad_answers = "Those answers couldn't be read. Try again.",
	err_too_many = "You're already running {n} deals. Finish one first.",
	err_busy = "Still working on your last request…",
	err_broken = "This deal couldn't continue, so it was reset. Start it again from the list.",
	err_unavailable = "Deals are unavailable right now.",
	err_timeout = "The server took too long. Try again.",
	err_rate_limited = "Slow down a little.",
	err_stale = "That stage was already handed in. Here's where the deal stands now.",
	err_generic = "Something went wrong. Try again.",

	---------------------------------------------------------------------------------------------------
	-- Stats (what a deal trains)
	---------------------------------------------------------------------------------------------------
	stat_knowledge = "Knowledge",
	stat_skill = "Skill",
	stat_speed = "Speed",
	stat_charisma = "Charisma",
	stat_network = "Network",
	stat_discipline = "Discipline",
	stat_risk = "Risk Sense",
	stat_luck = "Luck",
}
