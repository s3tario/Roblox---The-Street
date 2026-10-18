--!strict
-- Work tasks: tuning and player-facing text (owned by `work`; contracts §8, spec §5/§11, design v3 §3/§6).
-- Pure data plus a text helper: safe on the server, the client and under Lune. Task CONTENT (questions, cases,
-- dialogue) lives in each Logic/Tasks/<taskId> module; everything generic the UI and services show lives here.
--
--   Tasks.board        how the daily board is built (Logic/Tasks/_shared/Board)
--   Tasks.rewards      XP / pay calibration (Logic/Tasks/_shared/Rewards)
--   Tasks.timing       timers, grace, expiry
--   Tasks.categories   [category] = { name, glyph, color }   (contracts §8 category ids)
--   Tasks.kinds        [kind] = { name, how }                 renderer instructions per payload kind
--   Tasks.strings      every generic string;  Tasks.text(key, vars?) -> string with "{var}" substitution
--   Tasks.ERRORS       [errKey] = string key in Tasks.strings (remote error -> toast text)

local Tasks = {}

---------------------------------------------------------------------------------------------------
-- Board (each workday = 8 active minutes; spec §3, v3 §6)
---------------------------------------------------------------------------------------------------
Tasks.board = {
	minTasks = 3, -- fresh tasks per workday (before offered tasks)
	maxTasks = 5,
	minCore = 1, -- at least this many core tasks when the role has any
	maxCore = 3,
	coreWeight = 2.2, -- core tasks are drawn more often
	carryCore = true, -- unfinished core tasks stay on the next day's board until done
	maxCarry = 3, -- at most this many carried tasks (oldest dropped first)
	offerTtl = 45 * 60, -- an offered task (interview, event) without its own expiry lasts this many seconds
	maxOffered = 4,
	recentPenalty = 0.35, -- weight multiplier for a task done on the previous board (variety)
}

---------------------------------------------------------------------------------------------------
-- Rewards. Spec §11 salary scale: about 70% of cash per active hour comes from tasks and projects, the rest
-- from the weekly pay. XP follows Logic/Leveling.XP_RATE (typical XP per active minute by rank).
-- xp  = module.baseXp  x qualityFactor x Leveling.rankXpScale(rank) x boosts
-- pay = module.basePay x qualityFactor x payScale[rank] x company payMult x events x (late ? lateMult : 1)
---------------------------------------------------------------------------------------------------
Tasks.rewards = {
	-- rank 0 = student; ranks above 5 are for longer ladders (M5+)
	payScale = { [0] = 0.08, 1, 1.9, 3.1, 4.0, 5.6, 6.6, 7.6, 8.8 } :: { [number]: number },
	-- fallback when Logic/Leveling is unavailable (mirrors Leveling.XP_RATE / XP_RATE[1])
	xpScale = { [0] = 0.6, 1, 1.35, 1.7, 2.05, 2.35, 2.65, 2.95, 3.25 } :: { [number]: number },
	qualityFloor = 20, -- below this quality only the participation share is paid
	participation = 0.1, -- share of XP/pay at (or below) the floor
	lateMult = 0.6, -- pay multiplier for late work (reviews also discount it)
	deskBonus = 1.1, -- XP multiplier when working at your own desk
	deskRadius = 30, -- studs from a usable work desk that count as "at your desk"
	maxXp = 20000, -- hard caps per task (sanity)
	maxPay = 250000,
	repExcellent = 85, -- quality from which client-facing work earns an extra reputation point
	seasonXpShare = 0.25, -- Season XP = this share of task XP (when SeasonService exists)
}

---------------------------------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------------------------------
Tasks.timing = {
	graceSeconds = 5, -- network grace on every deadline
	expireMult = 3, -- an unsubmitted task is voided after timeLimit x this
	minPerItem = 0.6, -- seconds per answer below which a high score looks automated (flag only)
	startCooldown = 1, -- seconds between starts (anti-spam)
	defaultLimit = 180,
}

---------------------------------------------------------------------------------------------------
-- Categories (contracts §8)
---------------------------------------------------------------------------------------------------
Tasks.categories = {
	academics = { name = "Academics", glyph = "✎", color = "accent" },
	campus = { name = "Campus", glyph = "♜", color = "accent" },
	networking = { name = "Networking", glyph = "☕", color = "good" },
	interview = { name = "Interview", glyph = "☎", color = "warn" },
	work = { name = "Desk work", glyph = "▦", color = "accent" },
	client = { name = "Client", glyph = "✦", color = "good" },
	reentry = { name = "Re-entry", glyph = "↺", color = "warn" },
	headtohead = { name = "Head-to-head", glyph = "⚔", color = "bad" },
} :: { [string]: { name: string, glyph: string, color: string } }

Tasks.CATEGORY_IDS = { "academics", "campus", "networking", "interview", "work", "client", "reentry", "headtohead" }

---------------------------------------------------------------------------------------------------
-- Payload kinds (renderers in src/client/UI/WorkKinds/<kind>)
---------------------------------------------------------------------------------------------------
Tasks.KIND_IDS = { "mcq", "fill", "order", "match", "spot", "alloc", "dialogue", "call", "format", "multi" }

Tasks.kinds = {
	mcq = { name = "Questions", how = "Pick one answer for each question." },
	fill = { name = "Calculations", how = "Type a number in every box. Close answers earn partial credit." },
	order = { name = "Sequence", how = "Put the steps in order. Tap an item, then use the arrows to move it." },
	match = { name = "Match", how = "Pair every item on the left with one on the right." },
	spot = { name = "Find the errors", how = "Tap the cells that look wrong. Wrong flags cost points." },
	alloc = { name = "Allocate", how = "Split the total across the items. Use the arrows or type a number." },
	dialogue = { name = "Conversation", how = "Choose what you say at each turn." },
	call = { name = "Make the call", how = "Read the chart and the news, then make a call for each one." },
	format = { name = "Review", how = "Tap each line and flag what's wrong with it. Leave clean lines alone." },
	multi = { name = "Multi-part", how = "Finish every part, then submit." },
} :: { [string]: { name: string, how: string } }

---------------------------------------------------------------------------------------------------
-- Strings
---------------------------------------------------------------------------------------------------
Tasks.strings = {
	-- menu / prompts
	menu = "Work",
	prompt = "Work",
	prompt_object = "Desk",
	employees_only = "Employees only. This desk belongs to {company}.",
	employees_only_generic = "Employees only.",
	campus_students_only = "Campus desks are for students. Your desk is at {company}.",
	campus_students_only_generic = "Campus desks are for students. Your desk is at your firm now.",
	office_students = "This desk belongs to {company}. Land a job there first.",

	-- board
	board_title = "Today's work",
	board_title_student = "Campus to-do",
	board_subtitle = "{day} · {done}/{total} done",
	board_day_student = "Campus day {n}",
	board_empty = "Nothing on your board right now.",
	board_all_done = "All done for today. New work lands in about {time}.",
	board_all_done_soon = "All done for today. New work lands soon.",
	board_unemployed = "You're between jobs. Practice here, then head to Career Services to get back in.",
	board_loading = "Loading your board…",
	board_error = "Couldn't load your board. Try again in a moment.",
	board_offered = "Offered",
	board_core = "Core",
	board_done = "Done",
	board_carry = "Carried over",
	board_expires = "Expires in {time}",
	board_desk_bonus = "At your desk: +{pct}% XP",
	board_no_desk = "Work at your desk for +{pct}% XP",
	board_estimate = "~{xp} XP · ~{pay}",
	board_time = "{time} limit",
	board_quality = "Last: {q}",
	board_resume = "Resume",
	board_start = "Start",
	board_retry = "Retry",
	board_refresh = "Refresh",
	board_week = "Week {week} · {day}",
	board_cooldown = "Ready in {time}",
	board_offer_from = "From {source}",
	board_trained = "Trains {stats}",
	board_kind = "{kind} · {time}",
	board_core_hint = "Core work counts toward your promotion.",
	board_next_day = "Next workday in {time}",
	board_friday = "Friday: head to your weekly review when it's ready.",

	-- runner
	runner_submit = "Submit",
	runner_submitting = "Submitting…",
	runner_abandon = "Abandon",
	runner_abandon_title = "Abandon this task?",
	runner_abandon_body = "You'll lose this attempt. Nothing else is affected.",
	runner_time_left = "{time}",
	runner_overtime = "Overtime {time}",
	runner_hints = "Hints",
	runner_incomplete = "{left} unanswered. Submit anyway?",
	runner_incomplete_title = "Not finished",
	runner_part = "Part {i} of {n}",
	runner_how = "How it works",
	runner_part_error = "This part couldn't be drawn. Submit what you can; it won't count against you twice.",
	runner_answered = "{n}/{total} answered",
	runner_desk = "At your desk: +{pct}% XP",
	runner_hints_show = "Show hints ({n})",
	runner_hints_hide = "Hide hints",
	runner_late_warn = "Past the deadline: it still counts, but pays less.",

	-- renderers
	fill_placeholder = "Type a number",
	fill_not_number = "Enter a number, like 1,250 or 12.5",
	match_pick = "Choose…",
	spot_counter = "Flags: {n}/{max}",
	alloc_total = "Allocated {used} of {total} {unit} · {left} left",
	alloc_over = "Over budget: {used} of {total} {unit}",
	format_flags = "⚑ {n}",
	call_move = "{pct} over the period",

	-- results
	result_title = "Results",
	result_quality = "Quality",
	result_correct = "{correct}/{total} right",
	result_on_time = "On time",
	result_late = "Late",
	result_xp = "+{xp} XP",
	result_pay = "+{pay}",
	result_stats = "Trained: {stats}",
	result_back = "Back to board",
	result_close = "Close",
	result_great = "Outstanding work.",
	result_good = "Solid work.",
	result_ok = "Passable, with gaps.",
	result_weak = "Not there yet.",
	result_bad = "That needs a redo.",

	-- grading notes (generic)
	note_fill_miss = "{label}: about {expected} (you entered {given}).",
	note_fill_blank = "{label}: left blank. It's about {expected}.",
	note_order = "Right order: {list}.",
	note_order_perfect = "Sequence spot on.",
	note_match_miss = "Pair: {label}.",
	note_spot_false = "{n} of your flags were on clean cells.",
	note_spot_perfect = "Every error found, no false alarms.",
	note_format_false = "{n} of your flags were on lines that were fine.",
	note_format_missed = "Missed on “{element}”: {issue}.",
	note_alloc_band = "{label}: aim for {lo}–{hi}{unit} (you gave {given}{unit}).",
	note_alloc_over = "You allocated {given}{unit} of {total}{unit}.",
	note_call_perfect = "Every call right.",
	note_dialogue_good = "You read the room well.",
	note_dialogue_weak = "That line didn't land. Think about what the other person needs to hear.",
	note_call_partial = "{label}: close, but the news points further than that.",

	-- toasts
	toast_done = "{title}: {q} quality · +{xp} XP · +{pay}",
	toast_done_nopay = "{title}: {q} quality · +{xp} XP",
	toast_late = "Late: the deadline passed, so the pay was cut.",
	toast_void = "Sorry, that task hit a glitch on our side. It didn't count against you. Try another one.",
	toast_expired = "Your task timed out and was dropped.",
	toast_offered = "New on your board: {title}.",
	toast_client_rep = "The client noticed: +{rep} reputation.",
	toast_desk_bonus = "Desk bonus applied.",
	toast_new_day = "New work on your board: {n} tasks.",
	toast_xp_capped = "XP is capped at your title's top level until you're promoted.",

	-- errors (remote error keys)
	err_not_loaded = "Your save is still loading. Try again in a moment.",
	err_unknown_task = "That task isn't available.",
	err_not_on_board = "That task isn't on your board.",
	err_done = "You've already finished that one today.",
	err_cooldown = "That task is on cooldown. Try another one.",
	err_busy = "Finish or abandon your current task first.",
	err_no_active = "You don't have a task in progress.",
	err_wrong_task = "That isn't your current task.",
	err_bad_answers = "Your answers couldn't be read. Please try again.",
	err_not_allowed = "You can't do that task right now.",
	err_generate = "Couldn't set up that task. Try another one.",
	err_rate = "Slow down a little.",
	err_timeout = "The server didn't answer. Check your connection.",
	err_generic = "Something went wrong. Please try again.",
	err_expired = "That task timed out.",
	err_unavailable = "Work isn't available right now.",
}

Tasks.WEEKDAYS = { "Mon", "Tue", "Wed", "Thu", "Fri" }

-- Display names for the eight attributes (Config/LifeRoll owns the full definitions).
Tasks.STAT_NAMES = {
	knowledge = "Knowledge",
	skill = "Skill",
	speed = "Speed",
	charisma = "Charisma",
	network = "Network",
	discipline = "Discipline",
	risk = "Risk Sense",
	luck = "Luck",
} :: { [string]: string }

Tasks.ERRORS = {
	not_loaded = "err_not_loaded",
	unknown_task = "err_unknown_task",
	not_on_board = "err_not_on_board",
	done = "err_done",
	cooldown = "err_cooldown",
	busy = "err_busy",
	no_active = "err_no_active",
	wrong_task = "err_wrong_task",
	bad_answers = "err_bad_answers",
	not_allowed = "err_not_allowed",
	generate = "err_generate",
	rate_limited = "err_rate",
	timeout = "err_timeout",
	expired = "err_expired",
	unavailable = "err_unavailable",
	void = "toast_void",
} :: { [string]: string }

function Tasks.text(key: string, vars: { [string]: any }?): string
	local s = (Tasks.strings :: any)[key]
	if type(s) ~= "string" then
		return key
	end
	if vars then
		local v = vars
		s = string.gsub(s, "{([%w_]+)}", function(name: string): string
			local value = v[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return tostring(value)
		end)
	end
	return s
end

function Tasks.errorText(errKey: any): string
	local key = if type(errKey) == "string" then Tasks.ERRORS[errKey] else nil
	return Tasks.text(key or "err_generic")
end

function Tasks.category(id: any): { name: string, glyph: string, color: string }
	local def = if type(id) == "string" then Tasks.categories[id] else nil
	return def or Tasks.categories.work
end

return Tasks
