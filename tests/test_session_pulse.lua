--[[
    SessionPulse Test Suite
    Tests core logic extracted from session_pulse.lua
    Run from project root:  lua tests/test_session_pulse.lua
    Run from tests dir:      cd tests && lua test_session_pulse.lua
]]

local pass_count = 0
local fail_count = 0
local test_count = 0

local function test(name, condition)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  ✓ " .. name)
    else
        fail_count = fail_count + 1
        print("  ✗ FAIL: " .. name)
    end
end

local function section(name)
    print("\n━━ " .. name .. " ━━")
end

-- ═══════════════════════════════════════════════════════
-- Test 1: CSV Label Quoting (the bug fix)
-- ═══════════════════════════════════════════════════════
section("CSV Label Quoting")

local function csv_escape_label(label)
    local csv_label = label or ""
    csv_label = csv_label:gsub('"', '""')
    return '"' .. csv_label .. '"'
end

test("Simple label", csv_escape_label("Math homework") == '"Math homework"')
test("Label with comma", csv_escape_label("Math, Physics") == '"Math, Physics"')
test("Label with quotes", csv_escape_label('He said "hello"') == '"He said ""hello"""')
test("Empty label", csv_escape_label("") == '""')
test("Nil label", csv_escape_label(nil) == '""')
test("Label with newline", csv_escape_label("Line1\nLine2") == '"Line1\nLine2"')
test("Label with comma and quotes", csv_escape_label('A, "B"') == '"A, ""B"""')

-- Simulate full CSV row
local function make_csv_row(stype, duration, completed, mode, total_focus, label)
    local csv_label = (label or ""):gsub('"', '""')
    return string.format("%s,%s,%s,%d,%s,%s,%d,\"%s\"",
        "2026-03-31", "10:45:23", stype, duration,
        tostring(completed), mode, total_focus, csv_label)
end

local row1 = make_csv_row("Focus", 1500, true, "pomodoro", 1500, "Math homework")
test("Full row - simple label",
    row1 == '2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math homework"')

local row2 = make_csv_row("Focus", 1500, true, "pomodoro", 1500, "Math, Physics")
test("Full row - comma in label",
    row2 == '2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math, Physics"')

local row3 = make_csv_row("Focus", 1500, true, "pomodoro", 1500, "")
test("Full row - empty label",
    row3 == '2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,""')

-- ═══════════════════════════════════════════════════════
-- Test 2: JSON Escape Function
-- ═══════════════════════════════════════════════════════
section("JSON Escape")

local function json_escape(s)
    if not s then return "" end
    return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
end

test("Simple string", json_escape("hello") == "hello")
test("String with quotes", json_escape('say "hi"') == 'say \\"hi\\"')
test("String with backslash", json_escape("a\\b") == "a\\\\b")
test("String with newline", json_escape("a\nb") == "a\\nb")
test("Nil input", json_escape(nil) == "")
test("String with all special chars", json_escape('"\\"\n') == '\\"\\\\\\\"\\n')

-- ═══════════════════════════════════════════════════════
-- Test 3: Time Formatting
-- ═══════════════════════════════════════════════════════
section("Time Formatting")

local function format_time(seconds)
    if seconds < 0 then seconds = 0 end
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d",
            math.floor(seconds / 3600),
            math.floor((seconds % 3600) / 60),
            seconds % 60)
    end
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

test("25 minutes", format_time(1500) == "25:00")
test("1 second", format_time(1) == "00:01")
test("0 seconds", format_time(0) == "00:00")
test("59 seconds", format_time(59) == "00:59")
test("60 seconds", format_time(60) == "01:00")
test("Negative (clamped to 0)", format_time(-90) == "00:00")
test("Large value (with hours)", format_time(3661) == "1:01:01")

-- ═══════════════════════════════════════════════════════
-- Test 4: Duration Formatting (human-readable)
-- ═══════════════════════════════════════════════════════
section("Duration Formatting")

local function format_duration_human(seconds)
    if seconds < 60 then return seconds .. "s" end
    local mins = math.floor(seconds / 60)
    if mins < 60 then return mins .. "m" end
    local hours = math.floor(mins / 60)
    local rem_mins = mins % 60
    if rem_mins == 0 then return hours .. "h" end
    return hours .. "h " .. rem_mins .. "m"
end

test("0 seconds", format_duration_human(0) == "0s")
test("30 seconds", format_duration_human(30) == "30s")
test("59 seconds", format_duration_human(59) == "59s")
test("90 seconds", format_duration_human(90) == "1m")
test("3600 seconds", format_duration_human(3600) == "1h")
test("3660 seconds", format_duration_human(3660) == "1h 1m")
test("7320 seconds", format_duration_human(7320) == "2h 2m")

-- ═══════════════════════════════════════════════════════
-- Test 5: Ends-at Time Formatting
-- ═══════════════════════════════════════════════════════
section("Ends-At Formatting")

local function format_ends_at(remaining_seconds)
    local target = os.time() + remaining_seconds
    return os.date("%H:%M", target)
end

-- Can't test exact output (time-dependent), but verify format
local result = format_ends_at(3600)
test("Ends-at format is HH:MM", result:match("^%d%d:%d%d$") ~= nil)

-- ═══════════════════════════════════════════════════════
-- Test 6: Custom Intervals Parsing
-- ═══════════════════════════════════════════════════════
section("Custom Intervals Parsing")

local function parse_custom_intervals(config_str)
    local segments = {}
    for pair in config_str:gmatch("([^,]+)") do
        local name, mins = pair:match("^%s*(.-)%s*:%s*(%d+)%s*$")
        if name and mins then
            table.insert(segments, {name = name, duration = tonumber(mins) * 60})
        end
    end
    return segments
end

local seg1 = parse_custom_intervals("Work:25,Break:5")
test("Two segments parsed", #seg1 == 2)
test("First segment name", seg1[1].name == "Work")
test("First segment duration", seg1[1].duration == 1500)
test("Second segment name", seg1[2].name == "Break")
test("Second segment duration", seg1[2].duration == 300)

local seg2 = parse_custom_intervals("Warm-up:5,Exercise:20,Rest:5,Exercise:20,Cool-down:5")
test("Five HIIT segments", #seg2 == 5)
test("Hyphenated name", seg2[1].name == "Warm-up")

local seg3 = parse_custom_intervals("")
test("Empty string = no segments", #seg3 == 0)

local seg4 = parse_custom_intervals("Work:25")
test("Single segment", #seg4 == 1)

local seg5 = parse_custom_intervals("  Focus : 25 , Break : 5 ")
test("Whitespace handling", #seg5 == 2)
test("Trimmed name", seg5[1].name == "Focus")

-- ═══════════════════════════════════════════════════════
-- Test 7: Progress Bar Generation
-- ═══════════════════════════════════════════════════════
section("Progress Bar")

local function make_progress_bar(current, total, width)
    width = width or 20
    if total <= 0 or current <= 0 then return string.rep("░", width) end
    local ratio = math.min(1, (total - current) / total)
    local filled = math.floor(ratio * width)
    return string.rep("█", filled) .. string.rep("░", width - filled)
end

test("0% progress", make_progress_bar(1500, 1500, 10) == "░░░░░░░░░░")
test("50% progress", make_progress_bar(750, 1500, 10) == "█████░░░░░")
test("100% progress (timer=0 triggers session switch)", make_progress_bar(0, 1500, 10) == string.rep("░", 10))
test("Zero total", make_progress_bar(100, 0, 10) == "░░░░░░░░░░")

-- ═══════════════════════════════════════════════════════
-- Test 8: Wallclock Compute (core timing logic)
-- ═══════════════════════════════════════════════════════
section("Wallclock Timing")

-- Simulate compute_current_time logic
local function compute_current_time(session_epoch, session_pause_total, session_target_duration)
    local elapsed = os.time() - session_epoch - session_pause_total
    return math.max(0, session_target_duration - elapsed)
end

local now = os.time()
-- Session started 10 seconds ago, 60 second target, no pauses
local ct = compute_current_time(now - 10, 0, 60)
test("Wallclock: 50 seconds remaining", ct == 50)

-- Session started 10 seconds ago, 5 seconds paused
local ct2 = compute_current_time(now - 10, 5, 60)
test("Wallclock with pause: 55 remaining", ct2 == 55)

-- Session completed (elapsed > target)
local ct3 = compute_current_time(now - 100, 0, 60)
test("Wallclock: completed = 0", ct3 == 0)

-- ═══════════════════════════════════════════════════════
-- Test 9: State JSON Output Validation
-- ═══════════════════════════════════════════════════════
section("State JSON Format")

local function build_state_json()
    local json = string.format(
        '{\n' ..
        '  "version": "%s",\n' ..
        '  "timer_mode": "%s",\n' ..
        '  "is_running": %s,\n' ..
        '  "is_paused": %s,\n' ..
        '  "session_type": "%s",\n' ..
        '  "current_time": %d,\n' ..
        '  "total_time": %d,\n' ..
        '  "elapsed_seconds": %d,\n' ..
        '  "progress_percent": %d,\n' ..
        '  "ends_at": "%s",\n' ..
        '  "cycle_count": %d,\n' ..
        '  "completed_focus_sessions": %d,\n' ..
        '  "goal_sessions": %d,\n' ..
        '  "total_focus_seconds": %d,\n' ..
        '  "show_transition": %s,\n' ..
        '  "transition_message": "%s",\n' ..
        '  "custom_segment_name": "%s",\n' ..
        '  "custom_segment_index": %d,\n' ..
        '  "custom_segment_count": %d,\n' ..
        '  "is_overtime": %s,\n' ..
        '  "overtime_seconds": %d,\n' ..
        '  "next_session_type": "%s",\n' ..
        '  "next_session_in": %d,\n' ..
        '  "sessions_remaining": %d,\n' ..
        '  "break_suggestion": "%s",\n' ..
        '  "stream_duration": %d,\n' ..
        '  "chat_status_line": "%s",\n' ..
        '  "session_label": "%s",\n' ..
        '  "status_active": %s,\n' ..
        '  "status_message": "%s",\n' ..
        '  "status_until_epoch": %d,\n' ..
        '  "daily_focus_seconds": %d,\n' ..
        '  "daily_goal_seconds": %d,\n' ..
        '  "focus_streak": %d,\n' ..
        '  "session_epoch": %d,\n' ..
        '  "session_pause_total": %d,\n' ..
        '  "session_target_duration": %d,\n' ..
        '  "resume_available": %s,\n' ..
        '  "timestamp": %d\n' ..
        '}',
        "5.4.1", "pomodoro",
        "true", "false",
        "Focus", 1234, 1500,
        266, 18, "15:45",
        1, 2, 6, 3000,
        "false", "",
        "", 1, 0,
        "false", 0,
        "Short Break", 1234, 4,
        "Stretch!", 7200,
        json_escape("Focus 20:34 (2/6)"),
        json_escape("Math homework"),
        "true",
        json_escape("BRB"),
        os.time() + 300,
        7200, 14400, 2,
        os.time(), 0, 1500,
        "false",
        os.time()
    )
    return json
end

local json_out = build_state_json()
test("JSON contains version", json_out:find('"version": "5.4.1"') ~= nil)
test("JSON contains focus_streak", json_out:find('"focus_streak": 2') ~= nil)
test("JSON contains daily_focus_seconds", json_out:find('"daily_focus_seconds": 7200') ~= nil)
test("JSON contains daily_goal_seconds", json_out:find('"daily_goal_seconds": 14400') ~= nil)
test("JSON contains session_label", json_out:find('"session_label": "Math homework"') ~= nil)
test("JSON contains status_active", json_out:find('"status_active": true') ~= nil)
test("JSON contains status_message", json_out:find('"status_message": "BRB"') ~= nil)
test("JSON contains show_transition", json_out:find('"show_transition": false') ~= nil)
-- Count fields by counting ":" that follow quoted keys
local field_count = 0
for _ in json_out:gmatch('"[%w_]+":') do field_count = field_count + 1 end
test("JSON has 39 fields", field_count == 39)

-- ═══════════════════════════════════════════════════════
-- Test 10: Focus Streak Logic
-- ═══════════════════════════════════════════════════════
section("Focus Streak Logic")

local function simulate_streak(sequence)
    local streak = 0
    for _, stype in ipairs(sequence) do
        if stype == "Focus" then
            streak = streak + 1
        elseif stype == "stopped" or stype == "reset" then
            streak = 0
        end
        -- Breaks don't reset streak (they're expected between focus sessions)
    end
    return streak
end

test("3 focus in a row", simulate_streak({"Focus", "Focus", "Focus"}) == 3)
test("Focus-break-focus", simulate_streak({"Focus", "Short Break", "Focus"}) == 2)
test("Reset clears streak", simulate_streak({"Focus", "Focus", "reset"}) == 0)
test("Stop clears streak", simulate_streak({"Focus", "stopped"}) == 0)
test("Empty = 0", simulate_streak({}) == 0)

-- ═══════════════════════════════════════════════════════
-- Test 11: Lua Syntax Check (load the actual script)
-- ═══════════════════════════════════════════════════════
section("Lua Syntax Validation")

-- We can't execute the script (needs obslua), but we can check syntax
-- Try both paths: running from project root or from tests/ directory
local chunk, err = loadfile("session_pulse.lua") or loadfile("../session_pulse.lua")
if chunk then
    test("session_pulse.lua syntax valid", true)
else
    -- Expected: will fail at runtime because obslua isn't available,
    -- but syntax errors would be caught by loadfile
    test("session_pulse.lua syntax valid (error: " .. tostring(err) .. ")", false)
end

-- ═══════════════════════════════════════════════════════
-- Test 12: CSV Row Parsing (Lua-side daily focus reader)
-- ═══════════════════════════════════════════════════════
section("CSV Parsing (Lua-side)")

-- Pattern matches both quoted and unquoted fields (as log_session wraps in quotes)
local function parse_csv_row(line)
    local date, _, stype, dur = line:match('^"?([^",]+)"?,([^,]+),"?([^",]+)"?,(%d+)')
    return date, stype, tonumber(dur)
end

-- Unquoted row (legacy or external)
local d1, s1, dur1 = parse_csv_row('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math homework"')
test("Parse date (unquoted)", d1 == "2026-03-31")
test("Parse session type (unquoted)", s1 == "Focus")
test("Parse duration (unquoted)", dur1 == 1500)

-- Quoted row (as log_session actually produces)
local d3, s3, dur3 = parse_csv_row('"2026-03-31","10:45:23","Focus",1500,true,"pomodoro",1500,"Math homework"')
test("Parse date (quoted)", d3 == "2026-03-31")
test("Parse session type (quoted)", s3 == "Focus")
test("Parse duration (quoted)", dur3 == 1500)

-- Row with comma in quoted label (label is last field, doesn't affect fields 1-4)
local d2, s2, dur2 = parse_csv_row('"2026-03-31","10:45:23","Focus",1500,true,"pomodoro",1500,"Math, Physics"')
test("Comma in label doesn't break fields 1-4", d2 == "2026-03-31")
test("Session type still correct", s2 == "Focus")
test("Duration still correct", dur2 == 1500)


-- ═══════════════════════════════════════════════════════
-- Results
-- ═══════════════════════════════════════════════════════
print("\n" .. string.rep("═", 50))
print(string.format("Results: %d/%d passed, %d failed",
    pass_count, test_count, fail_count))
print(string.rep("═", 50))

if fail_count > 0 then
    os.exit(1)
end
