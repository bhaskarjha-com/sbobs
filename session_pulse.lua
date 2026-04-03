--[[
    SessionPulse v5.4.1
    Session automation engine for OBS Studio.
    Wallclock-based timing, WebSocket dock control, scene/source/filter/volume
    automation, warning alerts, time adjustment, session labeling, daily goal
    tracking, session logging, chapter markers, "ends at" time display, and
    state persistence with atomic writes.

    https://github.com/bhaskarjha-com/sbobs
    License: MIT
]]

local obs = obslua

if not obs then
    print("[SessionPulse] Error: This script must be run within OBS Studio.")
    return
end

local VERSION = "5.4.1"

------------------------------------------------------------------------
-- 1. State Variables
--
-- Defines all runtime state (timers, flags, counters).
-- Functions: None (variable declarations only)
--
-- State Machine (valid combinations only):
--   IDLE:          is_running=false, is_paused=false, is_overtime=false
--   RUNNING:       is_running=true,  is_paused=false, is_overtime=false
--   PAUSED:        is_running=true,  is_paused=true,  is_overtime=false
--   OVERTIME:      is_running=true,  is_paused=false, is_overtime=true
--   TRANSITIONING: is_running=true,  show_transition=true
--
-- All other boolean combinations are invalid.
------------------------------------------------------------------------
local current_time = 0
local cycle_count = 0
local completed_focus_sessions = 0
local total_focus_seconds = 0
local is_running = false
local is_paused = false
local session_type = "Focus"
local show_transition = false
local transition_timer = 0
local transition_message = ""
local has_pending_resume = false
local suggestion_index = 0
local custom_segments = {}
local custom_segment_index = 1
local overtime_seconds = 0
local overtime_epoch = 0         -- os.time() when overtime began (drift-proof)
local is_overtime = false
local stream_start_time = 0
local session_label = ""              -- user-defined label for current work
local daily_focus_seconds_today = 0   -- computed from CSV on load
local focus_streak = 0                -- consecutive completed focus sessions

-- Wallclock timing (drift-proof)
local session_epoch = 0           -- os.time() when current segment counting started
local session_pause_total = 0     -- accumulated seconds paused in current segment
local pause_epoch = 0             -- os.time() when current pause began
local session_target_duration = 0 -- target seconds for current segment (adjustable)

-- File I/O optimization
local state_dirty = false
local last_save_time = 0

-- Time adjustment
local time_adjust_increment = 5   -- minutes to add/subtract per hotkey press

-- Warning alerts
local warning_5min_fired = false
local warning_1min_fired = false
local warning_break_end_fired = false

-- Volume fade state
local fade_active = false
local fade_source_name = ""
local fade_from = 1.0
local fade_to = 1.0
local fade_elapsed = 0
local fade_duration = 3               -- will be set from volume_fade_duration config

------------------------------------------------------------------------
-- 2. Configuration
--
-- Variables loaded from OBS properties (durations, toggles, paths).
-- Updated during `script_update()`.
-- Debugging: If a setting change isn't applied, check `script_update`.
------------------------------------------------------------------------
local timer_mode = "pomodoro"

local focus_duration = 1500
local short_break_duration = 300
local long_break_duration = 900
local long_break_interval = 4
local goal_sessions = 6
local transition_display_time = 2
local show_progress_bar = true
local auto_start_next = true
local progress_bar_length = 100

-- Countdown mode
local countdown_duration = 1500

-- Custom intervals mode
local custom_intervals_text = ""

-- Session offset
local starting_session_offset = 0

-- Negative timer / overtime
local enable_overtime = false

-- Warning alert settings
local enable_warning_alerts = false
local warning_5min_enabled = true
local warning_1min_enabled = true
local warning_break_end_enabled = true
local warning_break_end_seconds = 30

-- Session history logging
local enable_session_log = false

-- Stream integration toggles
local enable_chapter_markers = true
local enable_mic_control = false
local auto_start_on_stream = false
local auto_stop_on_stream_end = false

-- Mic source
local mic_source_name = ""
local mute_mic_during_focus = true

-- Source visibility
local hide_during_focus_source = ""

-- Volume ducking
local volume_source_name = ""
local focus_volume = 0.3
local break_volume = 0.8
local enable_volume_fade = true
local volume_fade_duration = 3        -- seconds, user-configurable

-- Daily goal
local daily_goal_minutes = 0          -- 0 = disabled

-- Filter toggle
local filter_source_name = ""
local focus_filters_enable = ""
local focus_filters_disable = ""

-- Break suggestions
local break_suggestions_text = "Stretch!,Hydrate!,Look away from screen,Take a walk,Deep breaths,Roll your shoulders,Stand up,Rest your eyes"
local parsed_suggestions = {}

-- Source names
local focus_count_source = ""
local message_source = ""
local time_source = ""
local progress_bar_source = ""
local background_media_source = ""
local alert_source_name = ""

-- Session messages
local focus_message = "Focus Time"
local short_break_message = "Short Break"
local long_break_message = "Long Break"
local paused_message = "Paused"
local transition_to_short_break_message = "Time for a short break!"
local transition_to_focus_message = "Back to focus time!"
local transition_to_long_break_message = "Time for a long break!"

-- Asset paths
local focus_background_media = ""
local short_break_background_media = ""
local long_break_background_media = ""
local focus_alert_sound_path = ""
local short_break_alert_sound_path = ""
local long_break_alert_sound_path = ""

------------------------------------------------------------------------
-- 3. Hotkey IDs
--
-- Storage for OBS frontend hotkey handles.
------------------------------------------------------------------------
local hotkey_start_pause = obs.OBS_INVALID_HOTKEY_ID
local hotkey_stop = obs.OBS_INVALID_HOTKEY_ID
local hotkey_skip = obs.OBS_INVALID_HOTKEY_ID
local hotkey_add_time = obs.OBS_INVALID_HOTKEY_ID
local hotkey_sub_time = obs.OBS_INVALID_HOTKEY_ID
local hotkey_reset = obs.OBS_INVALID_HOTKEY_ID

-- Queued control actions
local pending_control_actions = {}
local pending_runtime_effects = {}
local scene_switching_deprecation_logged = false

------------------------------------------------------------------------
-- 4. Helpers
--
-- Utility routines for time math, formatting, string parsing, and paths.
-- Functions: log, mark_dirty, json_escape, get_session_elapsed,
-- compute_current_time, get_duration_for_session, format_time,
-- format_overtime, format_duration_human, get_state_file_path,
-- get_log_file_path, parse_suggestions, parse_custom_intervals,
-- get_break_suggestion
-- Debugging: Check `get_session_elapsed` if drift or timer math is off.
------------------------------------------------------------------------
local function log(msg)
    print("[SessionPulse] " .. msg)
end

local function mark_dirty()
    state_dirty = true
end

local function queue_control_action(action, origin)
    if not action or action == "" then return end
    pending_control_actions[#pending_control_actions + 1] = {
        action = action,
        origin = origin or "unknown"
    }
    log("Control queued (" .. (origin or "unknown") .. "): " .. action)
end

local function has_pending_control_action(action)
    for i = 1, #pending_control_actions do
        if pending_control_actions[i].action == action then
            return true
        end
    end
    return false
end

local function queue_runtime_effect(effect, origin)
    if not effect or effect == "" then return end
    pending_runtime_effects[#pending_runtime_effects + 1] = {
        effect = effect,
        origin = origin or "unknown"
    }
    log("Runtime effect queued (" .. (origin or "unknown") .. "): " .. effect)
end

local function json_escape(str)
    if not str then return "" end
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    -- Escape remaining control characters (0x00-0x1F) that weren't handled above.
    -- Exclude \n (0x0A), \r (0x0D), \t (0x09) since they've already been replaced.
    str = str:gsub('[%z\1-\8\11\12\14-\31]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end)
    return str
end

local function get_session_elapsed()
    if session_epoch == 0 then return 0 end
    local now = os.time()
    local paused = session_pause_total
    if is_paused and pause_epoch > 0 then
        paused = paused + (now - pause_epoch)
    end
    return math.max(0, now - session_epoch - paused)
end

local function compute_current_time()
    if not is_running then return current_time end
    local elapsed = get_session_elapsed()
    if timer_mode == "stopwatch" then
        return elapsed
    else
        return math.max(0, session_target_duration - elapsed)
    end
end

local function get_duration_for_session(stype)
    if timer_mode == "custom" then
        if custom_segments[custom_segment_index] then
            return custom_segments[custom_segment_index].duration
        end
        return 0
    end
    if timer_mode == "countdown" then return countdown_duration end
    if timer_mode == "stopwatch" then return 0 end
    if stype == "Focus" then return focus_duration end
    if stype == "Short Break" then return short_break_duration end
    return long_break_duration
end

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

local function format_overtime(seconds)
    return "+" .. format_time(seconds)
end

local function format_duration_human(seconds)
    if seconds < 60 then return seconds .. "s" end
    local mins = math.floor(seconds / 60)
    if mins < 60 then return mins .. "m" end
    local hours = math.floor(mins / 60)
    local rem_mins = mins % 60
    if rem_mins == 0 then return hours .. "h" end
    return hours .. "h " .. rem_mins .. "m"
end

local function get_state_file_path()
    return script_path() .. "session_state.json"
end

local function get_log_file_path()
    return script_path() .. "session_history.csv"
end

local function parse_suggestions(text)
    local result = {}
    if not text or text == "" then return result end
    for item in text:gmatch("([^,]+)") do
        local trimmed = item:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            result[#result + 1] = trimmed
        end
    end
    return result
end

local function parse_custom_intervals(text)
    local result = {}
    if not text or text == "" then return result end
    for segment in text:gmatch("([^,]+)") do
        local name, mins = segment:match("^%s*(.-)%s*:%s*(%d+)%s*$")
        if name and mins then
            result[#result + 1] = { name = name, duration = tonumber(mins) * 60 }
        end
    end
    -- Validation feedback in log
    if #result > 0 then
        local parts = {}
        for _, seg in ipairs(result) do
            parts[#parts + 1] = seg.name .. ":" .. (seg.duration / 60) .. "m"
        end
        log("Custom intervals parsed: " .. #result .. " segments → " .. table.concat(parts, ", "))
    end
    return result
end

local function get_break_suggestion()
    if #parsed_suggestions == 0 then return nil end
    suggestion_index = suggestion_index + 1
    if suggestion_index > #parsed_suggestions then
        suggestion_index = 1
    end
    return parsed_suggestions[suggestion_index]
end

------------------------------------------------------------------------
-- 5. Session History Log
--
-- CSV file read/write operations for tracking daily progress.
-- Functions: log_session, compute_daily_focus
-- Debugging: If session goals aren't updating, verify CSV headers.
------------------------------------------------------------------------
local function log_session(stype, duration, completed)
    if not enable_session_log then return end
    local path = get_log_file_path()

    -- Write header if file doesn't exist
    local check = io.open(path, "r")
    local needs_header = (check == nil)
    if check then check:close() end

    local file = io.open(path, "a")
    if not file then return end

    if needs_header then
        file:write("date,time,session_type,duration_seconds,completed,mode,total_focus,label\n")
    end

    -- CSV-escape label: wrap in quotes, double any internal quotes
    local csv_label = session_label or ""
    csv_label = csv_label:gsub('"', '""')

    file:write(string.format("\"%s\",\"%s\",\"%s\",%d,%s,\"%s\",%d,\"%s\"\n",
        os.date("%Y-%m-%d"),
        os.date("%H:%M:%S"),
        stype,
        duration,
        tostring(completed),
        timer_mode,
        total_focus_seconds,
        csv_label
    ))
    file:close()
end

-- Read CSV to compute today's total focus seconds (for daily goal tracking)
local function compute_daily_focus()
    local path = get_log_file_path()
    local file = io.open(path, "r")
    if not file then
        daily_focus_seconds_today = 0
        return
    end

    local today = os.date("%Y-%m-%d")
    local total = 0
    local first_line = true

    for line in file:lines() do
        if first_line then
            first_line = false  -- skip header
        else
            -- log_session wraps fields in quotes: "date","time","type",duration,...
            -- Strip optional surrounding quotes from each field before matching
            local date, _, stype, dur = line:match('^"?([^",]+)"?,([^,]+),"?([^",]+)"?,(%d+)')
            if date == today and stype == "Focus" then
                total = total + (tonumber(dur) or 0)
            end
        end
    end
    file:close()

    daily_focus_seconds_today = total
    log("Daily focus loaded from CSV: " .. format_duration_human(total))
end

------------------------------------------------------------------------
-- 6. Session Persistence
--
-- JSON state saving, loading, migration, and application.
-- Functions: get_next_session_type, save_state, load_state,
-- delete_state_file, apply_saved_state
-- Debugging: Check `state_dirty` if files aren't writing, or JSON parser if corrupt.
------------------------------------------------------------------------
local function get_next_session_type()
    if timer_mode ~= "pomodoro" then return "" end
    if session_type == "Focus" then
        if (cycle_count + 1) % long_break_interval == 0 then
            return "Long Break"
        end
        return "Short Break"
    end
    return "Focus"
end

local function save_state(force)
    -- Throttle: only write when dirty or forced, max once per second
    if not force and not state_dirty then return end
    local now = os.time()
    if not force and now == last_save_time then return end

    local path = get_state_file_path()
    local tmp_path = path .. ".tmp"
    local file = io.open(tmp_path, "w")
    if not file then return end

    local display_time = compute_current_time()
    local total = session_target_duration
    if not is_running or total == 0 then
        total = get_duration_for_session(session_type)
    end
    local seg_name = ""
    if timer_mode == "custom" and custom_segments[custom_segment_index] then
        seg_name = custom_segments[custom_segment_index].name
    end

    local next_type = get_next_session_type()
    local sessions_remaining = math.max(0, goal_sessions - completed_focus_sessions)
    local next_in = display_time
    if is_overtime then next_in = 0 end

    local stream_dur = 0
    if stream_start_time > 0 then
        stream_dur = now - stream_start_time
    end

    local suggestion_text = ""
    if suggestion_index > 0 and suggestion_index <= #parsed_suggestions then
        suggestion_text = parsed_suggestions[suggestion_index]
    end

    -- Build chat-ready status line
    local chat_status = ""
    if is_running then
        if is_overtime then
            chat_status = string.format("%s +%s", session_type, format_time(overtime_seconds))
        elseif timer_mode == "stopwatch" then
            chat_status = "Stopwatch " .. format_time(display_time)
        elseif timer_mode == "pomodoro" then
            chat_status = string.format("%s %s (%d/%d)",
                session_type, format_time(display_time),
                completed_focus_sessions, goal_sessions)
        elseif timer_mode == "custom" and seg_name ~= "" then
            chat_status = string.format("%s %s (%d/%d)",
                seg_name, format_time(display_time),
                custom_segment_index, #custom_segments)
        else
            chat_status = string.format("%s %s", session_type, format_time(display_time))
        end
        if is_paused then chat_status = chat_status .. " [Paused]" end
    end

    -- Compute derived fields for external consumption
    local elapsed_seconds = get_session_elapsed()
    local progress_pct = 0
    if total > 0 then
        progress_pct = math.min(100, math.floor(((total - display_time) / total) * 100))
    end
    if is_overtime then progress_pct = 100 end

    -- "Ends at" local time string (e.g., "15:45")
    local ends_at = ""
    if is_running and not is_paused and not is_overtime and timer_mode ~= "stopwatch" then
        ends_at = os.date("%H:%M", now + display_time)
    end

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
        '  "daily_focus_seconds": %d,\n' ..
        '  "daily_goal_seconds": %d,\n' ..
        '  "focus_streak": %d,\n' ..
        '  "session_epoch": %d,\n' ..
        '  "session_pause_total": %d,\n' ..
        '  "session_target_duration": %d,\n' ..
        '  "timestamp": %d\n' ..
        '}',
        json_escape(VERSION),
        json_escape(timer_mode),
        tostring(is_running),
        tostring(is_paused),
        json_escape(session_type),
        display_time,
        total,
        elapsed_seconds,
        progress_pct,
        json_escape(ends_at),
        cycle_count,
        completed_focus_sessions,
        goal_sessions,
        total_focus_seconds,
        tostring(show_transition),
        json_escape(transition_message),
        json_escape(seg_name),
        custom_segment_index,
        #custom_segments,
        tostring(is_overtime),
        overtime_seconds,
        json_escape(next_type),
        next_in,
        sessions_remaining,
        json_escape(suggestion_text),
        stream_dur,
        json_escape(chat_status),
        json_escape(session_label),
        daily_focus_seconds_today + total_focus_seconds,
        daily_goal_minutes * 60,
        focus_streak,
        session_epoch,
        session_pause_total,
        session_target_duration,
        now
    )

    file:write(json)
    file:close()

    -- Atomic rename
    os.remove(path)
    os.rename(tmp_path, path)

    state_dirty = false
    last_save_time = now
end

local function load_state()
    local path = get_state_file_path()
    local file = io.open(path, "r")
    if not file then return nil end

    local content = file:read("*all")
    file:close()

    if not content or content == "" then return nil end

    local function get_string(key)
        return content:match('"' .. key .. '":%s*"([^"]*)"')
    end
    local function get_number(key)
        local val = content:match('"' .. key .. '":%s*(%d+)')
        return val and tonumber(val) or nil
    end
    local function get_bool(key)
        local val = content:match('"' .. key .. '":%s*(%a+)')
        return val == "true"
    end

    local state = {
        version = get_string("version"),
        timer_mode = get_string("timer_mode"),
        is_running = get_bool("is_running"),
        is_paused = get_bool("is_paused"),
        session_type = get_string("session_type"),
        current_time = get_number("current_time"),
        cycle_count = get_number("cycle_count"),
        completed_focus_sessions = get_number("completed_focus_sessions"),
        total_focus_seconds = get_number("total_focus_seconds"),
        custom_segment_index = get_number("custom_segment_index"),
        timestamp = get_number("timestamp"),
        -- v5.0 wallclock fields
        session_epoch = get_number("session_epoch"),
        session_pause_total = get_number("session_pause_total"),
        session_target_duration = get_number("session_target_duration"),
    }

    if not state.current_time then
        log("State file corrupt — ignoring")
        return nil
    end

    if (not state.timer_mode or state.timer_mode == "pomodoro") and state.session_type then
        if state.session_type ~= "Focus" and
           state.session_type ~= "Short Break" and
           state.session_type ~= "Long Break" then
            log("Unknown session type in state: " .. state.session_type)
            return nil
        end
    end

    -- Detect v4.x state files (no wallclock fields) — migrate gracefully
    if state.session_epoch == nil or state.session_epoch == 0 then
        state.is_v4_migration = true
        log("Migrating v4.x state — wallclock will be freshly initialized")
    end

    return state
end

local function delete_state_file()
    os.remove(get_state_file_path())
    -- Clean up temp file if it exists
    os.remove(get_state_file_path() .. ".tmp")
end

-- Forward declarations (referenced by apply_saved_state before definition)
local update_display_texts
local update_background_media

local function apply_saved_state(state)
    session_type = state.session_type or "Focus"
    current_time = state.current_time
    cycle_count = state.cycle_count or 0
    completed_focus_sessions = state.completed_focus_sessions or 0
    total_focus_seconds = state.total_focus_seconds or 0

    if state.custom_segment_index and state.timer_mode == "custom" then
        custom_segment_index = state.custom_segment_index
    end

    -- Initialize wallclock state for resume
    if state.is_running then
        is_running = true
        is_paused = true  -- Always resume into paused state for safety

        if state.is_v4_migration or not state.session_epoch or state.session_epoch == 0 then
            -- Migrate from v4: synthesize epoch from current_time
            local dur = get_duration_for_session(session_type)
            local elapsed = dur - state.current_time
            session_epoch = os.time() - elapsed
            session_pause_total = 0
            pause_epoch = os.time()
            session_target_duration = dur
            log("v4→v5 migration: synthesized wallclock from " .. format_time(state.current_time))
        else
            -- v5 resume: restore wallclock state
            session_epoch = state.session_epoch
            session_pause_total = state.session_pause_total or 0
            session_target_duration = state.session_target_duration or get_duration_for_session(session_type)
            pause_epoch = os.time()  -- We're resuming paused, so pause starts now
        end

        log("Resumed — " .. session_type .. " at " .. format_time(current_time) .. " (paused)")
    else
        is_running = false
        is_paused = false
        session_epoch = 0
        session_pause_total = 0
        pause_epoch = 0
        session_target_duration = 0
    end

    -- Reset warning flags
    warning_5min_fired = false
    warning_1min_fired = false
    warning_break_end_fired = false

    has_pending_resume = false
    update_display_texts()
    update_background_media()
end

------------------------------------------------------------------------
-- 7. OBS Source Interaction
--
-- Text, background media, and alert sound updates via OBS data API.
-- Functions: update_obs_source_text, update_background_media, play_alert_sound
-- Debugging: Ensure sources exist exactly as named if they don't update.
------------------------------------------------------------------------
local function update_obs_source_text(source_name, text)
    if not source_name or source_name == "" then return end
    local source = obs.obs_get_source_by_name(source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

update_background_media = function()
    if not background_media_source or background_media_source == "" then return end

    local media_map = {
        Focus = focus_background_media,
        ["Short Break"] = short_break_background_media,
        ["Long Break"] = long_break_background_media
    }
    local media_path = media_map[session_type]

    local source = obs.obs_get_source_by_name(background_media_source)
    if source then
        if media_path and media_path ~= "" then
            local source_id = obs.obs_source_get_id(source)
            local settings = obs.obs_data_create()

            if source_id == "ffmpeg_source" then
                obs.obs_data_set_string(settings, "local_file", media_path)
                obs.obs_data_set_bool(settings, "is_local_file", true)
                obs.obs_data_set_bool(settings, "looping", true)
                obs.obs_data_set_bool(settings, "restart_on_activate", true)
                obs.obs_source_update(source, settings)
                obs.obs_source_media_restart(source)
            else
                obs.obs_data_set_string(settings, "file", media_path)
                obs.obs_source_update(source, settings)
            end

            obs.obs_data_release(settings)
        end
        obs.obs_source_release(source)
    end
end

local function play_alert_sound()
    local sound_map = {
        Focus = focus_alert_sound_path,
        ["Short Break"] = short_break_alert_sound_path,
        ["Long Break"] = long_break_alert_sound_path
    }
    local sound_path = sound_map[session_type]
    if not sound_path or sound_path == "" then return end
    if not alert_source_name or alert_source_name == "" then return end

    local source = obs.obs_get_source_by_name(alert_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "local_file", sound_path)
        obs.obs_data_set_bool(settings, "is_local_file", true)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_media_restart(source)
        obs.obs_source_release(source)
    end
end

local function harden_sessionpulse_browser_source(source_name)
    if not source_name or source_name == "" then return false end

    local source = obs.obs_get_source_by_name(source_name)
    if not source then return false end

    local changed = false
    local ok, settings = pcall(function()
        return obs.obs_source_get_settings(source)
    end)

    if ok and settings and obs.obs_source_get_id(source) == "browser_source" then
        local is_local = obs.obs_data_get_bool(settings, "is_local_file")
        local local_file = obs.obs_data_get_string(settings, "local_file") or ""
        local is_sessionpulse_page =
            local_file:find("timer_overlay%.html", 1, false) ~= nil or
            local_file:find("timer_overlay_bar%.html", 1, false) ~= nil or
            local_file:find("timer_stats%.html", 1, false) ~= nil or
            local_file:find("timer_remote%.html", 1, false) ~= nil

        if source_name == "SP Overlay" or (is_local and is_sessionpulse_page) then
            if not obs.obs_data_get_bool(settings, "shutdown") then
                obs.obs_data_set_bool(settings, "shutdown", true)
                changed = true
            end
            if not obs.obs_data_get_bool(settings, "refreshnocache") then
                obs.obs_data_set_bool(settings, "refreshnocache", true)
                changed = true
            end

            if changed then
                obs.obs_source_update(source, settings)
                log("Hardened browser source '" .. source_name .. "' for scene-switch stability")
            end
        end

        obs.obs_data_release(settings)
    end

    obs.obs_source_release(source)
    return changed
end

------------------------------------------------------------------------
-- 8. Legacy Scene Switching Notes
--
-- Automatic OBS scene switching has been removed from SessionPulse's
-- supported workflow because it was the only reproducible trigger for
-- transition-time crashes in this project.
--
-- ARCHITECTURE NOTE — WHY script_tick AND NOT timer_add:
-- obs_frontend_set_current_scene() posts to the Qt UI thread and blocks.
-- When called from a timer_add callback (graphics thread, Lua mutex held),
-- if the Qt UI thread needs the Lua mutex for any reason, both threads
-- wait for each other → DEADLOCK → OBS "Not Responding".
-- script_tick() runs in the main application loop's execution context,
-- which is the documented safe context for frontend API calls from Lua.
------------------------------------------------------------------------
--[[ legacy scene-switch code removed
    log("Scene switch queued → " .. target)
end

]]
------------------------------------------------------------------------
-- 8. Mic Control
--
-- Mute/unmute microphone logic for Focus vs. Break sessions.
-- Functions: update_mic_state
-- Debugging: Check if mic_source_name exists if muting doesn't occur.
------------------------------------------------------------------------
local function update_mic_state()
    if not enable_mic_control then return end
    if not mic_source_name or mic_source_name == "" then return end

    local source = obs.obs_get_source_by_name(mic_source_name)
    if source then
        local should_mute = (session_type == "Focus" and mute_mic_during_focus) or
                           (session_type ~= "Focus" and not mute_mic_during_focus)
        obs.obs_source_set_muted(source, should_mute)
        obs.obs_source_release(source)
        log("Mic " .. (should_mute and "muted" or "unmuted") .. " for " .. session_type)
    end
end

------------------------------------------------------------------------
-- 10. Source Visibility
--
-- Show/hide specific sources (supports comma-separated list).
-- Functions: update_source_visibility
-- Debugging: Check for typos in the comma-separated source names.
------------------------------------------------------------------------
local function update_source_visibility()
    if not hide_during_focus_source or hide_during_focus_source == "" then return end

    local should_show = (session_type ~= "Focus")

    -- Support comma-separated source names
    for name in hide_during_focus_source:gmatch("[^,]+") do
        name = name:match("^%s*(.-)%s*$")  -- trim whitespace
        if name ~= "" then
            local source = obs.obs_get_source_by_name(name)
            if source then
                obs.obs_source_set_enabled(source, should_show)
                obs.obs_source_release(source)
            else
                log("Warning: source '" .. name .. "' not found for visibility toggle")
            end
        end
    end
end

------------------------------------------------------------------------
-- 11. Volume Ducking
--
-- Background audio fade out/in with ease-in-out interpolation.
-- Functions: set_source_volume, start_volume_fade, process_volume_fade, update_volume
-- Debugging: If volume drops but doesn't fade, enable_volume_fade may be unchecked.
------------------------------------------------------------------------
local function set_source_volume(source_name, volume)
    if not source_name or source_name == "" then return end
    local source = obs.obs_get_source_by_name(source_name)
    if source then
        obs.obs_source_set_volume(source, math.max(0, math.min(1.0, volume)))
        obs.obs_source_release(source)
    end
end

local function start_volume_fade(target_vol)
    if not volume_source_name or volume_source_name == "" then return end
    if not enable_volume_fade then
        set_source_volume(volume_source_name, target_vol)
        return
    end

    local source = obs.obs_get_source_by_name(volume_source_name)
    if source then
        fade_from = obs.obs_source_get_volume(source)
        obs.obs_source_release(source)
    else
        fade_from = 1.0
    end

    fade_to = target_vol
    fade_source_name = volume_source_name
    fade_elapsed = 0
    fade_duration = volume_fade_duration
    fade_active = true
end

local function process_volume_fade(seconds_passed)
    if not fade_active then return end
    fade_elapsed = fade_elapsed + seconds_passed
    local t = math.min(fade_elapsed / fade_duration, 1.0)
    -- Ease-in-out
    local eased = t < 0.5 and (2 * t * t) or (1 - (-2 * t + 2) ^ 2 / 2)
    local vol = fade_from + (fade_to - fade_from) * eased
    set_source_volume(fade_source_name, vol)
    if t >= 1.0 then
        fade_active = false
        log(string.format("Volume fade complete: %.0f%%", fade_to * 100))
    end
end

local function update_volume()
    if not volume_source_name or volume_source_name == "" then return end
    local target = (session_type == "Focus") and focus_volume or break_volume
    start_volume_fade(target)
    log(string.format("Volume → %.0f%% for %s", target * 100, session_type))
end

------------------------------------------------------------------------
-- 12. Filter Toggle
--
-- Enable/disable OBS filters (e.g., color correction) per session.
-- Functions: set_filter_enabled, update_filters
-- Debugging: Verify exact filter name; fallback applies if OBS < 30.2.
------------------------------------------------------------------------
local function set_filter_enabled(source, filter_name, enabled)
    -- obs_source_filter_set_enabled(source, name, enabled) requires OBS 30.2+.
    -- Wrap in pcall for backward compatibility with OBS 28-30.1.
    local ok, err = pcall(function()
        obs.obs_source_filter_set_enabled(source, filter_name, enabled)
    end)
    if not ok then
        -- Fallback: try the manual get-filter-by-name approach
        local filter = obs.obs_source_get_filter_by_name(source, filter_name)
        if filter then
            obs.obs_source_set_enabled(filter, enabled)
            obs.obs_source_release(filter)
        else
            log("Warning: filter '" .. filter_name .. "' not found")
        end
    end
end

local function update_filters()
    if not filter_source_name or filter_source_name == "" then return end

    local source = obs.obs_get_source_by_name(filter_source_name)
    if not source then return end

    local in_focus = (session_type == "Focus")

    -- Enable filters during focus
    if focus_filters_enable and focus_filters_enable ~= "" then
        for fname in focus_filters_enable:gmatch("([^,]+)") do
            local name = fname:match("^%s*(.-)%s*$")
            if name and name ~= "" then
                set_filter_enabled(source, name, in_focus)
            end
        end
    end

    -- Disable filters during focus (enable during break)
    if focus_filters_disable and focus_filters_disable ~= "" then
        for fname in focus_filters_disable:gmatch("([^,]+)") do
            local name = fname:match("^%s*(.-)%s*$")
            if name and name ~= "" then
                set_filter_enabled(source, name, not in_focus)
            end
        end
    end

    obs.obs_source_release(source)
    log("Filters updated for " .. session_type)
end

------------------------------------------------------------------------
-- 13. Chapter Markers
--
-- Add markers to active recordings when sessions change.
-- Functions: add_chapter_marker
-- Debugging: Feature only works if an active recording is happening.
------------------------------------------------------------------------
local function add_chapter_marker()
    if not enable_chapter_markers then return end
    if not obs.obs_frontend_recording_active() then return end

    local chapter_name
    if timer_mode == "custom" and custom_segments[custom_segment_index] then
        chapter_name = custom_segments[custom_segment_index].name
    elseif session_type == "Focus" then
        chapter_name = "Focus Session " .. (completed_focus_sessions + 1)
    else
        chapter_name = session_type
    end

    local ok, result = pcall(function()
        return obs.obs_frontend_recording_add_chapter(chapter_name)
    end)

    if ok and result then
        log("Chapter marker: " .. chapter_name)
    end
end

------------------------------------------------------------------------
-- 14. Display
--
-- Progress bar rendering, status strings, and time formatting.
-- Functions: create_progress_bar, get_session_message, update_display_texts,
-- show_session_summary
-- Debugging: If UI is stalled, ensure update_display_texts is called.
------------------------------------------------------------------------
local function create_progress_bar(elapsed, total)
    if not show_progress_bar or total <= 0 then return "" end
    local filled = math.floor((elapsed / total) * progress_bar_length)
    filled = math.max(0, math.min(filled, progress_bar_length))
    return string.rep("█", filled) .. string.rep("░", math.max(0, progress_bar_length - filled))
end

local function get_session_message()
    if timer_mode == "custom" and custom_segments[custom_segment_index] then
        local seg = custom_segments[custom_segment_index]
        return seg.name .. " (" .. custom_segment_index .. "/" .. #custom_segments .. ")"
    end
    if timer_mode == "countdown" then return "Countdown" end
    if timer_mode == "stopwatch" then return "Stopwatch" end
    if session_type == "Focus" then return focus_message end
    if session_type == "Short Break" then return short_break_message end
    return long_break_message
end

update_display_texts = function()
    -- Focus count
    if timer_mode == "pomodoro" then
        update_obs_source_text(focus_count_source,
            string.format("Done: %d/%d", completed_focus_sessions, goal_sessions))
    elseif timer_mode == "custom" then
        update_obs_source_text(focus_count_source,
            string.format("Segment: %d/%d", custom_segment_index, #custom_segments))
    elseif timer_mode == "stopwatch" then
        update_obs_source_text(focus_count_source, format_duration_human(current_time))
    else
        update_obs_source_text(focus_count_source, "")
    end

    -- Session message
    local message = show_transition and transition_message or get_session_message()

    if timer_mode == "pomodoro" and session_type ~= "Focus" and
       not show_transition and #parsed_suggestions > 0 then
        local suggestion = parsed_suggestions[suggestion_index]
        if suggestion then
            message = message .. " · " .. suggestion
        end
    end

    if is_overtime then
        message = message .. " [OVERTIME]"
    end

    if is_paused then message = message .. " (" .. paused_message .. ")" end
    update_obs_source_text(message_source, message)

    -- Time display
    if is_overtime then
        update_obs_source_text(time_source, format_overtime(overtime_seconds))
    else
        update_obs_source_text(time_source, format_time(current_time))
    end

    -- Progress bar
    if show_progress_bar and timer_mode ~= "stopwatch" then
        local total = session_target_duration
        if total <= 0 then total = get_duration_for_session(session_type) end
        if is_overtime then
            update_obs_source_text(progress_bar_source,
                string.rep("█", progress_bar_length))
        else
            -- Use freshly computed time to avoid stale current_time during transitions
            local fresh_time = (is_running and session_epoch > 0) and compute_current_time() or current_time
            local elapsed = total - fresh_time
            update_obs_source_text(progress_bar_source, create_progress_bar(elapsed, total))
        end
    else
        update_obs_source_text(progress_bar_source, "")
    end
end

local function show_session_summary()
    local summary = string.format("Session complete: %d focus sessions, %s total focus time",
        completed_focus_sessions, format_duration_human(total_focus_seconds))
    update_obs_source_text(message_source, summary)
    log(summary)
end

------------------------------------------------------------------------
-- 15. Session Management
--
-- Core logic: state transitions, segment logic, streak tracking.
-- Functions: show_transition_msg, update_session, switch_session
-- Debugging: This is the orchestrator. Start here if timers do not loop properly.
------------------------------------------------------------------------
local function show_transition_msg(message)
    transition_message = message
    show_transition = true
    transition_timer = transition_display_time
    update_display_texts()
end

local function update_session(new_type, duration, message)
    -- Log the completed session
    local completed_duration = get_duration_for_session(session_type)
    log_session(session_type, completed_duration, true)

    session_type = new_type
    current_time = duration
    is_overtime = false
    overtime_seconds = 0

    -- Initialize wallclock for new session
    session_epoch = os.time()
    session_pause_total = 0
    pause_epoch = 0
    session_target_duration = duration

    -- Reset warning flags
    warning_5min_fired = false
    warning_1min_fired = false
    warning_break_end_fired = false

    show_transition_msg(message)
    if background_media_source and background_media_source ~= "" then
        queue_runtime_effect("background_media", "session_transition")
    end
    if alert_source_name and alert_source_name ~= "" then
        queue_runtime_effect("alert_sound", "session_transition")
    end
    if enable_mic_control and mic_source_name and mic_source_name ~= "" then
        queue_runtime_effect("mic_state", "session_transition")
    end
    if hide_during_focus_source and hide_during_focus_source ~= "" then
        queue_runtime_effect("source_visibility", "session_transition")
    end
    if volume_source_name and volume_source_name ~= "" then
        queue_runtime_effect("volume", "session_transition")
    end
    if filter_source_name and filter_source_name ~= "" then
        queue_runtime_effect("filters", "session_transition")
    end
    if enable_chapter_markers then
        queue_runtime_effect("chapter_marker", "session_transition")
    end
    mark_dirty()
end

local function switch_session()
    if timer_mode == "pomodoro" then
        if session_type == "Focus" then
            completed_focus_sessions = completed_focus_sessions + 1
            cycle_count = cycle_count + 1
            focus_streak = focus_streak + 1
            if focus_streak > 1 then
                log("🔥 Focus streak: " .. focus_streak .. " in a row!")
            end
            get_break_suggestion()
            if cycle_count % long_break_interval == 0 then
                update_session("Long Break", long_break_duration, transition_to_long_break_message)
            else
                update_session("Short Break", short_break_duration, transition_to_short_break_message)
            end
        else
            update_session("Focus", focus_duration, transition_to_focus_message)
        end

    elseif timer_mode == "countdown" then
        log_session("Countdown", countdown_duration, true)
        show_transition_msg("Countdown complete!")
        play_alert_sound()
        is_running = false
        is_paused = false
        session_epoch = 0
        session_target_duration = 0
        log("Countdown complete")
        delete_state_file()
        return

    elseif timer_mode == "custom" then
        local completed_seg = custom_segments[custom_segment_index]
        if completed_seg then
            log_session(completed_seg.name, completed_seg.duration, true)
        end

        custom_segment_index = custom_segment_index + 1
        if custom_segment_index > #custom_segments then
            if auto_start_next then
                custom_segment_index = 1
                log("Custom intervals restarting from beginning")
            else
                show_transition_msg("All segments complete!")
                play_alert_sound()
                is_running = false
                is_paused = false
                session_epoch = 0
                session_target_duration = 0
                log("All custom segments complete")
                delete_state_file()
                return
            end
        end

        local seg = custom_segments[custom_segment_index]
        if seg then
            session_type = seg.name
            current_time = seg.duration
            is_overtime = false
            overtime_seconds = 0

            -- Wallclock for new segment
            session_epoch = os.time()
            session_pause_total = 0
            pause_epoch = 0
            session_target_duration = seg.duration

            -- Reset warnings
            warning_5min_fired = false
            warning_1min_fired = false
            warning_break_end_fired = false

            show_transition_msg("Next: " .. seg.name)
            play_alert_sound()
            add_chapter_marker()
        end
        mark_dirty()
        save_state(true)
        return
    end

    if not auto_start_next then
        is_paused = true
        pause_epoch = os.time()
        log("Session changed — waiting for manual resume")
    end

    mark_dirty()
    save_state(true)
end

------------------------------------------------------------------------
-- 16. Timer
--
-- The 1-second interval tick: warning alerts, overtime, time computation.
-- Functions: fire_warning_alert, check_warning_alerts, timer_tick
-- Debugging: If time freezes, verify `timer_tick` is still registered via `obs.timer_add`.
------------------------------------------------------------------------
local function fire_warning_alert()
    -- Pick the correct alert sound based on current session type
    if not alert_source_name or alert_source_name == "" then return end
    local sound_map = {
        Focus = focus_alert_sound_path,
        ["Short Break"] = short_break_alert_sound_path,
        ["Long Break"] = long_break_alert_sound_path
    }
    local sound_path = sound_map[session_type] or focus_alert_sound_path
    if not sound_path or sound_path == "" then return end
    local source = obs.obs_get_source_by_name(alert_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "local_file", sound_path)
        obs.obs_data_set_bool(settings, "is_local_file", true)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_media_restart(source)
        obs.obs_source_release(source)
    end
end

local function check_warning_alerts(time_remaining)
    if not enable_warning_alerts then return end
    if timer_mode == "stopwatch" then return end
    if is_overtime then return end

    -- 5-minute warning (flag-only: fires once when crossing the threshold)
    if warning_5min_enabled and not warning_5min_fired and time_remaining <= 300 then
        warning_5min_fired = true
        if not has_pending_control_action("warning_alert") then
            queue_control_action("warning_alert", "timer")
        end
        log("Warning: 5 minutes remaining")
    end

    -- 1-minute warning
    if warning_1min_enabled and not warning_1min_fired and time_remaining <= 60 then
        warning_1min_fired = true
        if not has_pending_control_action("warning_alert") then
            queue_control_action("warning_alert", "timer")
        end
        log("Warning: 1 minute remaining")
    end

    -- Break / segment ending warning (non-Focus sessions in any timed mode)
    if warning_break_end_enabled and not warning_break_end_fired
       and session_type ~= "Focus"
       and (timer_mode == "pomodoro" or timer_mode == "custom" or timer_mode == "countdown")
       and time_remaining <= warning_break_end_seconds then
        warning_break_end_fired = true
        if not has_pending_control_action("warning_alert") then
            queue_control_action("warning_alert", "timer")
        end
        log("Warning: session ending in " .. warning_break_end_seconds .. "s")
    end
end

local function timer_tick()
    if not is_running or is_paused then
        -- Still save periodically when paused (for UI polling)
        if is_running and is_paused then
            mark_dirty()
            save_state()
        end
        return
    end

    if show_transition then
        transition_timer = transition_timer - 1
        if transition_timer <= 0 then
            show_transition = false
        end
        mark_dirty()
    else
        -- Wallclock-based time computation
        current_time = compute_current_time()

        if timer_mode == "stopwatch" then
            total_focus_seconds = total_focus_seconds + 1
        else
            -- Track focus time (tick-based is fine for aggregate stat)
            if current_time > 0 then
                if timer_mode == "pomodoro" and session_type == "Focus" then
                    total_focus_seconds = total_focus_seconds + 1
                elseif timer_mode == "custom" then
                    total_focus_seconds = total_focus_seconds + 1
                end

                -- Check warning alerts
                check_warning_alerts(current_time)
            else
                -- Timer hit zero
                if enable_overtime and not is_overtime then
                    is_overtime = true
                    overtime_epoch = os.time()
                    overtime_seconds = 0
                    if not has_pending_control_action("play_alert_sound") then
                        queue_control_action("play_alert_sound", "timer")
                    end
                    log("Overtime started for " .. session_type)
                elseif is_overtime then
                    -- Wallclock-based overtime (drift-proof)
                    overtime_seconds = os.time() - overtime_epoch
                else
                    if not has_pending_control_action("auto_advance") then
                        queue_control_action("auto_advance", "timer")
                    end
                end
            end
        end
        mark_dirty()
    end
    update_display_texts()
    save_state()
end

------------------------------------------------------------------------
-- 17. Controls
--
-- Start, stop, pause, skip, reset, and time adjustment commands.
-- Functions: start_timer, toggle_pause, stop_timer, reset_timer, skip_session,
-- add_time, subtract_time, resume_previous_session
-- Debugging: These wrappers mostly manage state flags; output goes through `save_state()`.
------------------------------------------------------------------------
local function start_timer()
    if is_running and not is_paused then return end
    if is_paused then
        -- Resume: accumulate pause duration into session_pause_total
        if pause_epoch > 0 then
            session_pause_total = session_pause_total + (os.time() - pause_epoch)
            pause_epoch = 0
        end
        is_paused = false
        log("Timer resumed")
    else
        is_running = true
        is_paused = false
        is_overtime = false
        overtime_seconds = 0

        -- Initialize wallclock for new session
        session_epoch = os.time()
        session_pause_total = 0
        pause_epoch = 0

        -- Reset warnings
        warning_5min_fired = false
        warning_1min_fired = false
        warning_break_end_fired = false

        if timer_mode == "stopwatch" then
            current_time = 0
            session_type = "Stopwatch"
            session_target_duration = 0
            log("Stopwatch started")
        elseif timer_mode == "countdown" then
            current_time = countdown_duration
            session_type = "Countdown"
            session_target_duration = countdown_duration
            log("Countdown started — " .. format_time(countdown_duration))
        elseif timer_mode == "custom" then
            if #custom_segments == 0 then
                log("No custom segments defined — add segments like 'Work:25,Break:5'")
                is_running = false
                session_epoch = 0
                return
            end
            custom_segment_index = 1
            local seg = custom_segments[1]
            session_type = seg.name
            current_time = seg.duration
            session_target_duration = seg.duration
            log("Custom intervals started — " .. seg.name .. " (" .. format_time(seg.duration) .. ")")
        else
            -- Pomodoro
            if current_time <= 0 then
                current_time = focus_duration
                session_type = "Focus"
            end
            session_target_duration = current_time
            -- Apply session offset on first start
            if starting_session_offset > 0 and completed_focus_sessions == 0 then
                completed_focus_sessions = starting_session_offset
                cycle_count = starting_session_offset
                log("Session offset applied: starting at session " .. (starting_session_offset + 1))
            end
            log("Timer started — " .. session_type .. " (" .. format_time(current_time) .. ")")
        end

        -- Track stream start time
        if stream_start_time == 0 then
            stream_start_time = os.time()
        end
    end
    mark_dirty()
    update_display_texts()
    update_background_media()
    update_mic_state()
    update_source_visibility()
    update_volume()
    update_filters()
    save_state(true)
end

local function toggle_pause()
    if not is_running then
        start_timer()
        return
    end
    if is_paused then
        -- Resume: accumulate pause duration
        if pause_epoch > 0 then
            session_pause_total = session_pause_total + (os.time() - pause_epoch)
            pause_epoch = 0
        end
        is_paused = false
        log("Timer resumed")
    else
        -- Pause: record when pause started
        is_paused = true
        pause_epoch = os.time()
        log("Timer paused")
    end
    mark_dirty()
    update_display_texts()
    save_state(true)
end

local function stop_timer()
    -- Log incomplete session
    if is_running then
        local elapsed = get_session_elapsed()
        log_session(session_type, elapsed, false)
    end

    is_running = false
    is_paused = false
    show_transition = false
    is_overtime = false
    overtime_seconds = 0
    overtime_epoch = 0
    focus_streak = 0
    completed_focus_sessions = 0

    -- Reset to correct initial state for current timer mode
    if timer_mode == "pomodoro" then
        session_type = "Focus"
        current_time = focus_duration
        cycle_count = 0
    elseif timer_mode == "countdown" then
        session_type = "Countdown"
        current_time = countdown_duration
    elseif timer_mode == "stopwatch" then
        session_type = "Stopwatch"
        current_time = 0
    elseif timer_mode == "custom" then
        custom_segment_index = 1
        if #custom_segments > 0 then
            session_type = custom_segments[1].name
            current_time = custom_segments[1].duration
        else
            session_type = "Custom"
            current_time = 0
        end
    else
        session_type = "Focus"
        current_time = focus_duration
        cycle_count = 0
    end

    -- Reset wallclock
    session_epoch = 0
    session_pause_total = 0
    pause_epoch = 0
    session_target_duration = 0

    -- Reset warnings
    warning_5min_fired = false
    warning_1min_fired = false
    warning_break_end_fired = false

    log("Timer stopped")
    update_display_texts()
    delete_state_file()
end

local function reset_timer()
    stop_timer()
    completed_focus_sessions = 0
    total_focus_seconds = 0
    suggestion_index = 0
    stream_start_time = 0
    log("Timer reset — all progress cleared")
    update_display_texts()
    delete_state_file()
end

local function skip_session()
    if not is_running then
        -- Properly initialize timer state before skipping
        start_timer()
        if not is_running then return end  -- start_timer may fail (e.g. no custom segments)
    end

    if timer_mode == "stopwatch" then
        log("Stopwatch — nothing to skip")
        return
    end

    -- Skip overtime if active
    if is_overtime then
        is_overtime = false
        overtime_seconds = 0
    end

    log("Skipping " .. session_type)
    -- Skipping a focus session breaks the streak
    if session_type == "Focus" then
        focus_streak = 0
    end
    switch_session()
    if is_paused then
        -- Resume after skip: accumulate pause and clear
        if pause_epoch > 0 then
            session_pause_total = session_pause_total + (os.time() - pause_epoch)
            pause_epoch = 0
        end
        is_paused = false
    end
end

local function add_time()
    if not is_running then return end
    if timer_mode == "stopwatch" then return end

    local add_seconds = time_adjust_increment * 60
    session_target_duration = session_target_duration + add_seconds

    if is_overtime then
        if session_target_duration > get_session_elapsed() then
            is_overtime = false
            overtime_epoch = 0
            overtime_seconds = 0
            log("Added time recovered session from overtime")
        end
    end

    current_time = compute_current_time()

    -- Reset warnings that might fire again
    if current_time > 300 then warning_5min_fired = false end
    if current_time > 60 then warning_1min_fired = false end
    if current_time > warning_break_end_seconds then warning_break_end_fired = false end

    mark_dirty()
    log("Added " .. time_adjust_increment .. " min — now " .. format_time(current_time) .. " remaining")
    update_display_texts()
    save_state(true)
end

local function subtract_time()
    if not is_running then return end
    if timer_mode == "stopwatch" then return end

    local sub_seconds = time_adjust_increment * 60
    session_target_duration = math.max(0, session_target_duration - sub_seconds)
    current_time = compute_current_time()
    mark_dirty()
    log("Subtracted " .. time_adjust_increment .. " min — now " .. format_time(current_time) .. " remaining")

    -- Only trigger session switch if NOT paused — subtracting time while paused
    -- should not unexpectedly advance to the next session
    if not is_paused and current_time <= 0 and not show_transition then
        if enable_overtime and not is_overtime then
            is_overtime = true
            overtime_epoch = os.time()
            overtime_seconds = 0
            if not has_pending_control_action("play_alert_sound") then
                queue_control_action("play_alert_sound", "subtract_time")
            end
            log("Overtime started for " .. session_type)
        elseif not is_overtime then
            if not has_pending_control_action("auto_advance") then
                queue_control_action("auto_advance", "subtract_time")
            end
        end
    end

    update_display_texts()
    save_state(true)
end

local function resume_previous_session()
    local state = load_state()
    if state then
        apply_saved_state(state)
        log("Resumed previous session")
    else
        log("No saved session to resume")
    end
end

-- OBS invokes button/hotkey/frontend callbacks while it is inside its callback
-- machinery. Queue state-changing controls and execute them in script_tick()
-- so session transitions happen from one predictable context.
local function process_pending_control_actions()
    local processed = 0

    while #pending_control_actions > 0 and processed < 8 do
        local item = table.remove(pending_control_actions, 1)
        processed = processed + 1

        log("Control executing (" .. item.origin .. "): " .. item.action)

        if item.action == "start" then
            start_timer()
        elseif item.action == "pause" then
            toggle_pause()
        elseif item.action == "stop" then
            stop_timer()
        elseif item.action == "skip" then
            skip_session()
        elseif item.action == "reset" then
            reset_timer()
        elseif item.action == "add_time" then
            add_time()
        elseif item.action == "subtract_time" then
            subtract_time()
        elseif item.action == "resume_previous_session" then
            resume_previous_session()
        elseif item.action == "auto_advance" then
            switch_session()
        elseif item.action == "warning_alert" then
            fire_warning_alert()
        elseif item.action == "play_alert_sound" then
            play_alert_sound()
        elseif item.action == "stream_started_start" then
            if auto_start_on_stream and not is_running then
                start_timer()
            end
        elseif item.action == "stream_stopped_stop" then
            if auto_stop_on_stream_end and is_running then
                show_session_summary()
                stop_timer()
            elseif is_running then
                show_session_summary()
            end
        else
            log("Warning: unknown queued control action '" .. tostring(item.action) .. "'")
        end
    end

    return processed
end

local function process_pending_runtime_effects()
    if #pending_runtime_effects == 0 then return 0 end

    local item = table.remove(pending_runtime_effects, 1)
    log("Runtime effect executing (" .. item.origin .. "): " .. item.effect)

    if item.effect == "background_media" then
        update_background_media()
    elseif item.effect == "alert_sound" then
        play_alert_sound()
    elseif item.effect == "mic_state" then
        update_mic_state()
    elseif item.effect == "source_visibility" then
        update_source_visibility()
    elseif item.effect == "volume" then
        update_volume()
    elseif item.effect == "filters" then
        update_filters()
    elseif item.effect == "chapter_marker" then
        add_chapter_marker()
    else
        log("Warning: unknown runtime effect '" .. tostring(item.effect) .. "'")
    end

    return 1
end

local function on_start_button_clicked(props, prop)
    queue_control_action("start", "button")
    return true
end

local function on_pause_button_clicked(props, prop)
    queue_control_action("pause", "button")
    return true
end

local function on_stop_button_clicked(props, prop)
    queue_control_action("stop", "button")
    return true
end

local function on_skip_button_clicked(props, prop)
    queue_control_action("skip", "button")
    return true
end

local function on_reset_button_clicked(props, prop)
    queue_control_action("reset", "button")
    return true
end

local function on_add_time_button_clicked(props, prop)
    queue_control_action("add_time", "button")
    return true
end

local function on_subtract_time_button_clicked(props, prop)
    queue_control_action("subtract_time", "button")
    return true
end

local function on_resume_button_clicked(props, prop)
    queue_control_action("resume_previous_session", "button")
    return true
end

if rawget(_G, "__SESSION_PULSE_TEST_HOOKS") then
    _G.__SESSION_PULSE_TEST_HOOKS.on_start_button_clicked = on_start_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_pause_button_clicked = on_pause_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_stop_button_clicked = on_stop_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_skip_button_clicked = on_skip_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_reset_button_clicked = on_reset_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_add_time_button_clicked = on_add_time_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_subtract_time_button_clicked = on_subtract_time_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.on_resume_button_clicked = on_resume_button_clicked
    _G.__SESSION_PULSE_TEST_HOOKS.get_pending_control_count = function()
        return #pending_control_actions
    end
    _G.__SESSION_PULSE_TEST_HOOKS.get_pending_runtime_effect_count = function()
        return #pending_runtime_effects
    end
    _G.__SESSION_PULSE_TEST_HOOKS.get_runtime_state = function()
        return {
            is_running = is_running,
            is_paused = is_paused,
            session_type = session_type,
            current_time = current_time,
            completed_focus_sessions = completed_focus_sessions
        }
    end
end

------------------------------------------------------------------------
-- 18. Hotkey Callbacks
--
-- Thin wrappers for hotkey presses routing to Control functions.
-- Functions: on_hotkey_*
-- Debugging: Ensure hotkeys are bound in OBS Settings -> Hotkeys.
------------------------------------------------------------------------
local function on_hotkey_start_pause(pressed)
    if not pressed then return end
    queue_control_action("pause", "hotkey")
end

local function on_hotkey_stop(pressed)
    if not pressed then return end
    queue_control_action("stop", "hotkey")
end

local function on_hotkey_skip(pressed)
    if not pressed then return end
    queue_control_action("skip", "hotkey")
end

local function on_hotkey_add_time(pressed)
    if not pressed then return end
    queue_control_action("add_time", "hotkey")
end

local function on_hotkey_sub_time(pressed)
    if not pressed then return end
    queue_control_action("subtract_time", "hotkey")
end

local function on_hotkey_reset(pressed)
    if not pressed then return end
    queue_control_action("reset", "hotkey")
end

------------------------------------------------------------------------
-- 19. Frontend Events
--
-- Hooks for OBS stream/recording start/stop events.
-- Functions: on_frontend_event
-- Debugging: If auto-start fails, check OBS stream event dispatching.
------------------------------------------------------------------------
local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        log("Stream started")
        stream_start_time = os.time()
        queue_control_action("stream_started_start", "frontend_event")

    elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        log("Stream stopped")
        stream_start_time = 0
        queue_control_action("stream_stopped_stop", "frontend_event")

    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        log("Recording started")
        if enable_chapter_markers and is_running then
            add_chapter_marker()
        end
    end
end

if rawget(_G, "__SESSION_PULSE_TEST_HOOKS") then
    _G.__SESSION_PULSE_TEST_HOOKS.on_hotkey_skip = on_hotkey_skip
    _G.__SESSION_PULSE_TEST_HOOKS.on_frontend_event = on_frontend_event
    _G.__SESSION_PULSE_TEST_HOOKS.timer_tick = timer_tick
end

------------------------------------------------------------------------
-- 20. Source/Scene Enumeration
--
-- Helpers to populate OBS property dropdowns with current items.
-- Functions: populate_source_list, populate_scene_list
-- Debugging: If properties show "(None)", these might run before sources exist.
------------------------------------------------------------------------
local function populate_source_list(prop)
    obs.obs_property_list_clear(prop)
    obs.obs_property_list_add_string(prop, "(None)", "")
    local sources = obs.obs_enum_sources()
    if sources then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(prop, name, name)
        end
        obs.source_list_release(sources)
    end
end

local function populate_scene_list(prop)
    obs.obs_property_list_clear(prop)
    obs.obs_property_list_add_string(prop, "(None)", "")
    local scene_names = obs.obs_frontend_get_scene_names()
    if scene_names then
        for _, name in ipairs(scene_names) do
            obs.obs_property_list_add_string(prop, name, name)
        end
    end
end

------------------------------------------------------------------------
-- 21. Quick Setup Wizard
--
-- Auto-create sources, scenes, and overlays to streamline onboarding.
-- Functions: get_text_source_id, get_or_create_source, add_source_obj_to_scene,
-- get_or_create_scene, populate_scene, quick_setup
-- Debugging: Make sure to re-apply settings `obs_properties_apply_settings` at end.
------------------------------------------------------------------------
local quick_setup_settings = nil   -- reference to current settings, set by script_update

local function get_text_source_id()
    -- Windows: text_gdiplus, Mac/Linux: text_ft2_source
    local sep = package.config:sub(1, 1)
    if sep == "\\" then
        return "text_gdiplus"
    else
        return "text_ft2_source"
    end
end

local function get_or_create_source(name, source_id, settings)
    -- Try to find existing source first
    local source = obs.obs_get_source_by_name(name)
    if source then
        return source, false  -- source, was_created
    end
    -- Create new source
    source = obs.obs_source_create(source_id, name, settings, nil)
    if source then
        return source, true
    end
    return nil, false
end

local function add_source_obj_to_scene(scene, source, x, y)
    if not scene or not source then return end

    local source_name = obs.obs_source_get_name(source)
    local existing_item = obs.obs_scene_find_source(scene, source_name)
    if existing_item then return end

    local item = obs.obs_scene_add(scene, source)
    if item then
        local pos = obs.vec2()
        pos.x = x
        pos.y = y
        obs.obs_sceneitem_set_pos(item, pos)
    end
end

local function get_or_create_scene(name)
    -- Check if scene already exists
    local scene_source = obs.obs_get_source_by_name(name)
    if scene_source then
        local scene = obs.obs_scene_from_source(scene_source)
        obs.obs_source_release(scene_source)
        return scene, false  -- scene, was_created
    end
    -- Create new scene
    local scene = obs.obs_scene_create(name)
    return scene, true
end

local function populate_scene(scene, source_list, overlay_source)
    -- Add text sources
    local positions = {
        { source = source_list[1], x = 700, y = 300 },  -- Session
        { source = source_list[2], x = 700, y = 350 },  -- Timer
        { source = source_list[3], x = 700, y = 450 },  -- Count
        { source = source_list[4], x = 700, y = 490 },  -- Progress
    }
    for _, p in ipairs(positions) do
        if p.source then
            add_source_obj_to_scene(scene, p.source, p.x, p.y)
        end
    end
    -- Add overlay in top-left
    if overlay_source then
        add_source_obj_to_scene(scene, overlay_source, 30, 30)
    end
end

local function quick_setup(props, p)
    log("Quick Setup: Starting automated setup...")

    local created_count = 0
    local skipped_count = 0
    local source_handles = {}   -- hold references until we're done

    -- ── 1. Create text sources ──
    local text_id = get_text_source_id()
    local text_specs = {
        { name = "SP Session",  text = "Focus",       size = 36 },
        { name = "SP Timer",    text = "25:00",       size = 72 },
        { name = "SP Count",    text = "0/6",         size = 24 },
        { name = "SP Progress", text = "░░░░░░░░░░",  size = 20 },
    }

    local text_sources = {}   -- ordered: Session, Timer, Count, Progress
    for i, spec in ipairs(text_specs) do
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", spec.text)

        local font = obs.obs_data_create()
        obs.obs_data_set_string(font, "face", "Arial")
        obs.obs_data_set_int(font, "size", spec.size)
        obs.obs_data_set_int(font, "flags", 0)
        obs.obs_data_set_obj(settings, "font", font)
        obs.obs_data_release(font)

        obs.obs_data_set_int(settings, "color", 0xFFFFFF)

        local source, was_created = get_or_create_source(spec.name, text_id, settings)
        obs.obs_data_release(settings)

        if source then
            text_sources[i] = source
            table.insert(source_handles, source)  -- prevent GC
            if was_created then
                log("Quick Setup: Created '" .. spec.name .. "'")
                created_count = created_count + 1
            else
                log("Quick Setup: '" .. spec.name .. "' already exists")
                skipped_count = skipped_count + 1
            end
        else
            log("Quick Setup: Failed to create '" .. spec.name .. "'")
            text_sources[i] = nil
        end
    end

    -- ── 2. Create overlay browser source ──
    local overlay_path = script_path() .. "timer_overlay.html"
    local overlay_settings = obs.obs_data_create()
    obs.obs_data_set_bool(overlay_settings, "is_local_file", true)
    obs.obs_data_set_string(overlay_settings, "local_file", overlay_path)
    obs.obs_data_set_int(overlay_settings, "width", 220)
    obs.obs_data_set_int(overlay_settings, "height", 220)
    obs.obs_data_set_bool(overlay_settings, "shutdown", true)
    obs.obs_data_set_bool(overlay_settings, "refreshnocache", true)

    local overlay_source, overlay_created = get_or_create_source(
        "SP Overlay", "browser_source", overlay_settings)
    obs.obs_data_release(overlay_settings)

    if overlay_source then
        table.insert(source_handles, overlay_source)
        harden_sessionpulse_browser_source("SP Overlay")
        if overlay_created then
            log("Quick Setup: Created 'SP Overlay'")
            created_count = created_count + 1
        else
            log("Quick Setup: 'SP Overlay' already exists")
            skipped_count = skipped_count + 1
        end
    else
        log("Quick Setup: Failed to create 'SP Overlay'")
    end

    -- ── 3. Create/populate Focus and Break scenes ──
    local scene_names = { "SP Focus", "SP Break" }

    for _, scene_name in ipairs(scene_names) do
        local scene, was_created = get_or_create_scene(scene_name)
        if scene then
            populate_scene(scene, text_sources, overlay_source)
            if was_created then
                log("Quick Setup: Created scene '" .. scene_name .. "' with sources")
                created_count = created_count + 1
                obs.obs_scene_release(scene)
            else
                log("Quick Setup: Checked existing scene '" .. scene_name .. "' for missing sources")
                skipped_count = skipped_count + 1
                -- Don't release — obs_scene_from_source doesn't add a ref
            end
        else
            log("Quick Setup: Failed to create scene '" .. scene_name .. "'")
        end
    end

    -- ── 4. Release all source handles ──
    for _, source in ipairs(source_handles) do
        obs.obs_source_release(source)
    end

    -- ── 5. Auto-assign sources to script settings ──
    if quick_setup_settings then
        obs.obs_data_set_string(quick_setup_settings, "time_source", "SP Timer")
        obs.obs_data_set_string(quick_setup_settings, "message_source", "SP Session")
        obs.obs_data_set_string(quick_setup_settings, "focus_count_source", "SP Count")
        obs.obs_data_set_string(quick_setup_settings, "progress_bar_source", "SP Progress")

        -- Apply the settings immediately
        time_source = "SP Timer"
        message_source = "SP Session"
        focus_count_source = "SP Count"
        progress_bar_source = "SP Progress"

        log("Quick Setup: Auto-assigned sources to settings")
    end

    -- ── 6. Switch to Focus scene ──

    -- ── 7. Report results ──
    if created_count > 0 then
        log("Quick Setup: ✓ Complete! Created " .. created_count .. " items (" .. skipped_count .. " skipped). Press Start to begin!")
    else
        log("Quick Setup: All items already exist (" .. skipped_count .. " skipped). Setup was already done.")
    end

    -- ── Re-populate scene list dropdowns ──
    -- Refresh source dropdowns so the newly-created SessionPulse sources
    -- are valid selections before we apply settings back into OBS.
    local src_grp = obs.obs_properties_get(props, "text_sources_group")
    if src_grp then
        local src_grp_props = obs.obs_property_group_content(src_grp)
        if src_grp_props then
            local source_keys = {
                "time_source", "message_source", "focus_count_source",
                "progress_bar_source", "background_media_source", "alert_source_name"
            }
            for _, key in ipairs(source_keys) do
                local sp = obs.obs_properties_get(src_grp_props, key)
                if sp then populate_source_list(sp) end
            end
        end
    end

    -- Force the properties UI to re-read our modified settings.
    -- Now that dropdowns contain the newly-created scene/source names,
    -- obs_properties_apply_settings will correctly select them instead of
    -- falling back to "(None)".
    obs.obs_properties_apply_settings(props, quick_setup_settings)

    return true
end

------------------------------------------------------------------------
-- 22. OBS Script Interface
--
-- GUI definitions, default values, and setting update handlers.
-- Functions: script_description, script_properties, script_defaults, script_update,
-- update_timer_config, update_automation_config, update_source_config
-- Debugging: If property UI breaks, check `script_properties` definitions.
------------------------------------------------------------------------
function script_description()
    return "SessionPulse v" .. VERSION ..
        " — Session automation engine for OBS Studio."
end


function script_properties()
    local props = obs.obs_properties_create()
    local p

    -- ── Quick Setup ──
    obs.obs_properties_add_button(props, "quick_setup_button",
        "🚀  Quick Setup (auto-create sources, scenes, overlay)", quick_setup)

    -- ── Controls ──
    obs.obs_properties_add_button(props, "start_button", "▶  Start", on_start_button_clicked)
    obs.obs_properties_add_button(props, "pause_button", "⏸  Pause / Resume", on_pause_button_clicked)
    obs.obs_properties_add_button(props, "stop_button", "⏹  Stop", on_stop_button_clicked)
    obs.obs_properties_add_button(props, "skip_button", "⏭  Skip Session", on_skip_button_clicked)
    obs.obs_properties_add_button(props, "reset_button", "↺  Reset All", on_reset_button_clicked)
    obs.obs_properties_add_button(props, "add_time_button", "+  Add Time", on_add_time_button_clicked)
    obs.obs_properties_add_button(props, "sub_time_button", "−  Subtract Time", on_subtract_time_button_clicked)

    if has_pending_resume then
        obs.obs_properties_add_button(props, "resume_button",
            "⏪  Resume Previous Session", on_resume_button_clicked)
    end

    -- ── Timer Mode & Durations ──
    local mode_list = obs.obs_properties_add_list(props, "timer_mode",
        "Timer Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(mode_list, "Pomodoro", "pomodoro")
    obs.obs_property_list_add_string(mode_list, "Stopwatch (count up)", "stopwatch")
    obs.obs_property_list_add_string(mode_list, "Countdown (single)", "countdown")
    obs.obs_property_list_add_string(mode_list, "Custom Intervals", "custom")

    obs.obs_properties_add_int(props, "focus_duration", "Focus Duration (min)", 1, 120, 1)
    obs.obs_properties_add_int(props, "short_break_duration", "Short Break (min)", 1, 30, 1)
    obs.obs_properties_add_int(props, "long_break_duration", "Long Break (min)", 1, 60, 1)
    obs.obs_properties_add_int(props, "long_break_interval", "Long Break Every (cycles)", 1, 10, 1)
    obs.obs_properties_add_int(props, "goal_sessions", "Goal Sessions", 1, 20, 1)
    obs.obs_properties_add_int(props, "starting_session_offset", "Starting Session Offset", 0, 20, 1)
    obs.obs_properties_add_int(props, "countdown_duration", "Countdown Duration (min)", 1, 480, 1)
    obs.obs_properties_add_text(props, "custom_intervals_text",
        "Custom Intervals (Name:Min,...)", obs.OBS_TEXT_DEFAULT)

    -- ── Behavior ──
    obs.obs_properties_add_bool(props, "auto_start_next", "Auto-start Next Session / Loop")
    obs.obs_properties_add_bool(props, "show_progress_bar", "Show Progress Bar")
    obs.obs_properties_add_bool(props, "enable_overtime", "Enable Overtime (negative timer)")
    obs.obs_properties_add_int(props, "transition_display_time", "Transition Message Duration (sec)", 1, 10, 1)
    obs.obs_properties_add_int(props, "time_adjust_increment", "Time Adjust Increment (min)", 1, 30, 1)
    obs.obs_properties_add_text(props, "break_suggestions_text",
        "Break Suggestions (comma-separated)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_bool(props, "enable_session_log", "Log Sessions to CSV File")
    obs.obs_properties_add_text(props, "session_label",
        "Session Label (what you're working on)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "daily_goal_minutes",
        "Daily Focus Goal (min, 0 = disabled)", 0, 720, 15)

    -- ── Text Sources ──
    local src_group = obs.obs_properties_create()
    p = obs.obs_properties_add_list(src_group, "time_source",
        "Timer Text Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    p = obs.obs_properties_add_list(src_group, "message_source",
        "Session Message Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    p = obs.obs_properties_add_list(src_group, "focus_count_source",
        "Focus Count Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    p = obs.obs_properties_add_list(src_group, "progress_bar_source",
        "Progress Bar Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    p = obs.obs_properties_add_list(src_group, "background_media_source",
        "Background Media Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    p = obs.obs_properties_add_list(src_group, "alert_source_name",
        "Alert Sound Source (Media)", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    obs.obs_properties_add_group(props, "text_sources_group", "OBS Sources",
        obs.OBS_GROUP_NORMAL, src_group)

    -- Scene switching has been removed for stability.
    -- ── Mic Control (checkable group) ──
    local mic_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(mic_group, "mute_mic_during_focus",
        "Mute During Focus (uncheck to mute during breaks instead)")
    p = obs.obs_properties_add_list(mic_group, "mic_source_name",
        "Mic Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    obs.obs_properties_add_group(props, "enable_mic_control", "Mic Control",
        obs.OBS_GROUP_CHECKABLE, mic_group)

    -- ── Source Visibility ──
    obs.obs_properties_add_text(props, "hide_during_focus_source",
        "Hide During Focus (source names, comma-sep)", obs.OBS_TEXT_DEFAULT)

    -- ── Volume Ducking (group) ──
    local vol_group = obs.obs_properties_create()
    p = obs.obs_properties_add_list(vol_group, "volume_source_name",
        "Music/Audio Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    obs.obs_properties_add_int_slider(vol_group, "focus_volume", "Focus Volume %", 0, 100, 5)
    obs.obs_properties_add_int_slider(vol_group, "break_volume", "Break Volume %", 0, 100, 5)
    obs.obs_properties_add_bool(vol_group, "enable_volume_fade", "Smooth Volume Fade")
    obs.obs_properties_add_int(vol_group, "volume_fade_duration", "Fade Duration (sec)", 1, 15, 1)
    obs.obs_properties_add_group(props, "volume_ducking_group", "Volume Ducking",
        obs.OBS_GROUP_NORMAL, vol_group)

    -- ── Filter Toggle (group) ──
    local filt_group = obs.obs_properties_create()
    p = obs.obs_properties_add_list(filt_group, "filter_source_name",
        "Source (e.g. Camera)", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)
    obs.obs_properties_add_text(filt_group, "focus_filters_enable",
        "Enable During Focus (comma-sep)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(filt_group, "focus_filters_disable",
        "Disable During Focus (comma-sep)", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_group(props, "filter_toggle_group", "Filter Toggle",
        obs.OBS_GROUP_NORMAL, filt_group)

    -- ── Warning Alerts (checkable group) ──
    local warn_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(warn_group, "warning_5min_enabled", "5-Minute Warning Sound")
    obs.obs_properties_add_bool(warn_group, "warning_1min_enabled", "1-Minute Warning Sound")
    obs.obs_properties_add_bool(warn_group, "warning_break_end_enabled", "Break Ending Warning")
    obs.obs_properties_add_int(warn_group, "warning_break_end_seconds", "Break Warning At (sec)", 10, 120, 5)
    obs.obs_properties_add_group(props, "enable_warning_alerts", "Warning Alerts",
        obs.OBS_GROUP_CHECKABLE, warn_group)

    -- ── Audio Files (group) ──
    local audio_group = obs.obs_properties_create()
    obs.obs_properties_add_path(audio_group, "focus_alert_sound_path",
        "Focus Alert Sound", obs.OBS_PATH_FILE, "Audio (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_path(audio_group, "short_break_alert_sound_path",
        "Short Break Alert Sound", obs.OBS_PATH_FILE, "Audio (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_path(audio_group, "long_break_alert_sound_path",
        "Long Break Alert Sound", obs.OBS_PATH_FILE, "Audio (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_group(props, "audio_files_group", "Alert Sounds",
        obs.OBS_GROUP_NORMAL, audio_group)

    -- ── Background Media (group) ──
    local bg_group = obs.obs_properties_create()
    obs.obs_properties_add_path(bg_group, "focus_background_media",
        "Focus Background", obs.OBS_PATH_FILE,
        "Media (*.png *.jpg *.jpeg *.bmp *.gif *.mp4 *.webm *.mov *.mkv)", nil)
    obs.obs_properties_add_path(bg_group, "short_break_background_media",
        "Short Break Background", obs.OBS_PATH_FILE,
        "Media (*.png *.jpg *.jpeg *.bmp *.gif *.mp4 *.webm *.mov *.mkv)", nil)
    obs.obs_properties_add_path(bg_group, "long_break_background_media",
        "Long Break Background", obs.OBS_PATH_FILE,
        "Media (*.png *.jpg *.jpeg *.bmp *.gif *.mp4 *.webm *.mov *.mkv)", nil)
    obs.obs_properties_add_group(props, "background_media_group", "Background Media",
        obs.OBS_GROUP_NORMAL, bg_group)

    -- ── Stream Integration (checkable group) ──
    local stream_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(stream_group, "auto_start_on_stream", "Auto-start Timer on Stream Start")
    obs.obs_properties_add_bool(stream_group, "auto_stop_on_stream_end", "Auto-stop Timer on Stream End")
    obs.obs_properties_add_bool(stream_group, "enable_chapter_markers", "Add Recording Chapter Markers")
    obs.obs_properties_add_group(props, "stream_integration_group", "Stream Integration",
        obs.OBS_GROUP_NORMAL, stream_group)

    -- ── Messages (collapsible group) ──
    local msg_group = obs.obs_properties_create()
    obs.obs_properties_add_text(msg_group, "focus_message",
        "Focus Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(msg_group, "short_break_message",
        "Short Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(msg_group, "long_break_message",
        "Long Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(msg_group, "paused_message",
        "Paused Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(msg_group, "transition_to_focus_message",
        "→ Focus Transition", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(msg_group, "transition_to_short_break_message",
        "→ Short Break Transition", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(msg_group, "transition_to_long_break_message",
        "→ Long Break Transition", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_group(props, "messages_group", "Session Messages",
        obs.OBS_GROUP_NORMAL, msg_group)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "timer_mode", "pomodoro")
    obs.obs_data_set_default_int(settings, "focus_duration", 25)
    obs.obs_data_set_default_int(settings, "short_break_duration", 5)
    obs.obs_data_set_default_int(settings, "long_break_duration", 15)
    obs.obs_data_set_default_int(settings, "long_break_interval", 4)
    obs.obs_data_set_default_int(settings, "goal_sessions", 6)
    obs.obs_data_set_default_int(settings, "starting_session_offset", 0)
    obs.obs_data_set_default_int(settings, "countdown_duration", 25)
    obs.obs_data_set_default_int(settings, "transition_display_time", 2)
    obs.obs_data_set_default_bool(settings, "show_progress_bar", true)
    obs.obs_data_set_default_bool(settings, "auto_start_next", true)
    obs.obs_data_set_default_bool(settings, "enable_chapter_markers", true)
    obs.obs_data_set_default_bool(settings, "mute_mic_during_focus", true)
    obs.obs_data_set_default_bool(settings, "enable_volume_fade", true)
    obs.obs_data_set_default_int(settings, "focus_volume", 30)
    obs.obs_data_set_default_int(settings, "break_volume", 80)
    obs.obs_data_set_default_int(settings, "time_adjust_increment", 5)
    obs.obs_data_set_default_int(settings, "volume_fade_duration", 3)
    obs.obs_data_set_default_int(settings, "daily_goal_minutes", 0)
    obs.obs_data_set_default_string(settings, "session_label", "")
    obs.obs_data_set_default_string(settings, "custom_intervals_text", "Work:25,Break:5,Work:25,Break:5")
    obs.obs_data_set_default_string(settings, "break_suggestions_text",
        "Stretch!,Hydrate!,Look away from screen,Take a walk,Deep breaths,Roll your shoulders,Stand up,Rest your eyes")

    -- Warning alerts
    obs.obs_data_set_default_bool(settings, "enable_warning_alerts", false)
    obs.obs_data_set_default_bool(settings, "warning_5min_enabled", true)
    obs.obs_data_set_default_bool(settings, "warning_1min_enabled", true)
    obs.obs_data_set_default_bool(settings, "warning_break_end_enabled", true)
    obs.obs_data_set_default_int(settings, "warning_break_end_seconds", 30)

    -- Messages
    obs.obs_data_set_default_string(settings, "focus_message", "Focus Time")
    obs.obs_data_set_default_string(settings, "short_break_message", "Short Break")
    obs.obs_data_set_default_string(settings, "long_break_message", "Long Break")
    obs.obs_data_set_default_string(settings, "paused_message", "Paused")
    obs.obs_data_set_default_string(settings, "transition_to_focus_message", "Back to focus time!")
    obs.obs_data_set_default_string(settings, "transition_to_short_break_message", "Time for a short break!")
    obs.obs_data_set_default_string(settings, "transition_to_long_break_message", "Time for a long break!")
end

-- Split into helpers to stay under Lua 5.1's 60-upvalue limit per function

local function update_timer_config(settings)
    timer_mode = obs.obs_data_get_string(settings, "timer_mode")

    focus_duration = obs.obs_data_get_int(settings, "focus_duration") * 60
    short_break_duration = obs.obs_data_get_int(settings, "short_break_duration") * 60
    long_break_duration = obs.obs_data_get_int(settings, "long_break_duration") * 60
    long_break_interval = obs.obs_data_get_int(settings, "long_break_interval")
    goal_sessions = obs.obs_data_get_int(settings, "goal_sessions")
    starting_session_offset = obs.obs_data_get_int(settings, "starting_session_offset")
    countdown_duration = obs.obs_data_get_int(settings, "countdown_duration") * 60
    transition_display_time = obs.obs_data_get_int(settings, "transition_display_time")
    show_progress_bar = obs.obs_data_get_bool(settings, "show_progress_bar")
    auto_start_next = obs.obs_data_get_bool(settings, "auto_start_next")
    enable_overtime = obs.obs_data_get_bool(settings, "enable_overtime")
    time_adjust_increment = obs.obs_data_get_int(settings, "time_adjust_increment")

    custom_intervals_text = obs.obs_data_get_string(settings, "custom_intervals_text")
    custom_segments = parse_custom_intervals(custom_intervals_text)

    break_suggestions_text = obs.obs_data_get_string(settings, "break_suggestions_text")
    parsed_suggestions = parse_suggestions(break_suggestions_text)

    enable_session_log = obs.obs_data_get_bool(settings, "enable_session_log")
    session_label = obs.obs_data_get_string(settings, "session_label")
    daily_goal_minutes = obs.obs_data_get_int(settings, "daily_goal_minutes")

    -- Warning alerts
    enable_warning_alerts = obs.obs_data_get_bool(settings, "enable_warning_alerts")
    warning_5min_enabled = obs.obs_data_get_bool(settings, "warning_5min_enabled")
    warning_1min_enabled = obs.obs_data_get_bool(settings, "warning_1min_enabled")
    warning_break_end_enabled = obs.obs_data_get_bool(settings, "warning_break_end_enabled")
    warning_break_end_seconds = obs.obs_data_get_int(settings, "warning_break_end_seconds")
end

local function update_automation_config(settings)
    auto_start_on_stream = obs.obs_data_get_bool(settings, "auto_start_on_stream")
    auto_stop_on_stream_end = obs.obs_data_get_bool(settings, "auto_stop_on_stream_end")
    enable_chapter_markers = obs.obs_data_get_bool(settings, "enable_chapter_markers")

    if obs.obs_data_get_bool(settings, "enable_scene_switching") and not scene_switching_deprecation_logged then
        log("Scene switching is disabled in SessionPulse for stability; the saved setting is ignored.")
        scene_switching_deprecation_logged = true
    end

    enable_mic_control = obs.obs_data_get_bool(settings, "enable_mic_control")
    mute_mic_during_focus = obs.obs_data_get_bool(settings, "mute_mic_during_focus")
    mic_source_name = obs.obs_data_get_string(settings, "mic_source_name")

    hide_during_focus_source = obs.obs_data_get_string(settings, "hide_during_focus_source")

    volume_source_name = obs.obs_data_get_string(settings, "volume_source_name")
    focus_volume = obs.obs_data_get_int(settings, "focus_volume") / 100.0
    break_volume = obs.obs_data_get_int(settings, "break_volume") / 100.0
    enable_volume_fade = obs.obs_data_get_bool(settings, "enable_volume_fade")
    volume_fade_duration = obs.obs_data_get_int(settings, "volume_fade_duration")

    filter_source_name = obs.obs_data_get_string(settings, "filter_source_name")
    focus_filters_enable = obs.obs_data_get_string(settings, "focus_filters_enable")
    focus_filters_disable = obs.obs_data_get_string(settings, "focus_filters_disable")
end

local function update_source_config(settings)
    focus_count_source = obs.obs_data_get_string(settings, "focus_count_source")
    message_source = obs.obs_data_get_string(settings, "message_source")
    time_source = obs.obs_data_get_string(settings, "time_source")
    progress_bar_source = obs.obs_data_get_string(settings, "progress_bar_source")
    background_media_source = obs.obs_data_get_string(settings, "background_media_source")
    alert_source_name = obs.obs_data_get_string(settings, "alert_source_name")

    focus_message = obs.obs_data_get_string(settings, "focus_message")
    short_break_message = obs.obs_data_get_string(settings, "short_break_message")
    long_break_message = obs.obs_data_get_string(settings, "long_break_message")
    transition_to_focus_message = obs.obs_data_get_string(settings, "transition_to_focus_message")
    transition_to_short_break_message = obs.obs_data_get_string(settings, "transition_to_short_break_message")
    transition_to_long_break_message = obs.obs_data_get_string(settings, "transition_to_long_break_message")
    paused_message = obs.obs_data_get_string(settings, "paused_message")

    focus_alert_sound_path = obs.obs_data_get_string(settings, "focus_alert_sound_path")
    short_break_alert_sound_path = obs.obs_data_get_string(settings, "short_break_alert_sound_path")
    long_break_alert_sound_path = obs.obs_data_get_string(settings, "long_break_alert_sound_path")

    focus_background_media = obs.obs_data_get_string(settings, "focus_background_media")
    short_break_background_media = obs.obs_data_get_string(settings, "short_break_background_media")
    long_break_background_media = obs.obs_data_get_string(settings, "long_break_background_media")
end

function script_update(settings)
    quick_setup_settings = settings   -- allow Quick Setup to write source assignments
    update_timer_config(settings)
    update_automation_config(settings)
    update_source_config(settings)
    harden_sessionpulse_browser_source("SP Overlay")

    if not is_running then
        if timer_mode == "pomodoro" then
            current_time = focus_duration
        elseif timer_mode == "countdown" then
            current_time = countdown_duration
        elseif timer_mode == "stopwatch" then
            current_time = 0
        elseif timer_mode == "custom" and #custom_segments > 0 then
            current_time = custom_segments[1].duration
        end
        update_display_texts()
    end
end

------------------------------------------------------------------------
-- 23. Lifecycle
--
-- Core OBS script entry points: load, save, unload.
-- Functions: script_load, script_save, script_unload, script_tick
-- Debugging: Hotkey registrations happen in `script_load`, unregister in `script_unload`.
------------------------------------------------------------------------
function script_tick(seconds)
    process_volume_fade(seconds)
    local controls_processed = process_pending_control_actions()
    if controls_processed > 0 then return end

    local effects_processed = process_pending_runtime_effects()
    if effects_processed > 0 then return end

    return

    --[[ scene switching removed for stability.
    -- This is the fix for the cross-thread deadlock: obs_frontend_set_current_scene
    -- must NOT be called from timer_add callbacks (graphics thread, Lua mutex held).
    -- script_tick runs in the main app loop, which is safe for frontend API calls.
        -- Cooldown: skip if a switch was executed less than 100ms ago
        local now = os.clock()
        if now - scene_switch_cooldown < 0.1 then return end

        -- Stale safety: abandon if request is older than 3 seconds
        if os.time() - pending_scene_epoch > 3 then
            log("Scene switch expired (stale): " .. pending_scene_name)
            pending_scene_name = nil
            return
        end

        local target = pending_scene_name
        pending_scene_name = nil  -- clear BEFORE calling (prevents re-entry)

        local source = obs.obs_get_source_by_name(target)
        if source then
            local ok, err = pcall(function()
                obs.obs_frontend_set_current_scene(source)
            end)
            obs.obs_source_release(source)
            scene_switch_cooldown = os.clock()
            if ok then
                log("Switched to scene: " .. target)
            else
                log("Scene switch failed: " .. tostring(err))
            end
        else
            log("Scene switch failed — source not found: " .. target)
        end
    end
]]
end

function script_load(settings)
    obs.timer_add(timer_tick, 1000)
    harden_sessionpulse_browser_source("SP Overlay")

    hotkey_start_pause = obs.obs_hotkey_register_frontend(
        "session_pulse_start_pause", "SessionPulse: Start / Pause", on_hotkey_start_pause)
    hotkey_stop = obs.obs_hotkey_register_frontend(
        "session_pulse_stop", "SessionPulse: Stop", on_hotkey_stop)
    hotkey_skip = obs.obs_hotkey_register_frontend(
        "session_pulse_skip", "SessionPulse: Skip Session", on_hotkey_skip)
    hotkey_add_time = obs.obs_hotkey_register_frontend(
        "session_pulse_add_time", "SessionPulse: Add Time", on_hotkey_add_time)
    hotkey_sub_time = obs.obs_hotkey_register_frontend(
        "session_pulse_sub_time", "SessionPulse: Subtract Time", on_hotkey_sub_time)
    hotkey_reset = obs.obs_hotkey_register_frontend(
        "session_pulse_reset", "SessionPulse: Reset All", on_hotkey_reset)

    local function load_hotkey(id, key)
        local a = obs.obs_data_get_array(settings, key)
        obs.obs_hotkey_load(id, a)
        obs.obs_data_array_release(a)
    end
    load_hotkey(hotkey_start_pause, "session_pulse_hotkey_start_pause")
    load_hotkey(hotkey_stop, "session_pulse_hotkey_stop")
    load_hotkey(hotkey_skip, "session_pulse_hotkey_skip")
    load_hotkey(hotkey_add_time, "session_pulse_hotkey_add_time")
    load_hotkey(hotkey_sub_time, "session_pulse_hotkey_sub_time")
    load_hotkey(hotkey_reset, "session_pulse_hotkey_reset")

    obs.obs_frontend_add_event_callback(on_frontend_event)

    local saved_state = load_state()
    if saved_state and saved_state.is_running then
        has_pending_resume = true
        log("Found saved session — use 'Resume Previous Session' button to restore")
    end

    -- Load today's focus total from CSV for daily goal tracking
    compute_daily_focus()

    log("Loaded v" .. VERSION)
end

function script_save(settings)
    local function save_hotkey(id, key)
        local a = obs.obs_hotkey_save(id)
        obs.obs_data_set_array(settings, key, a)
        obs.obs_data_array_release(a)
    end
    save_hotkey(hotkey_start_pause, "session_pulse_hotkey_start_pause")
    save_hotkey(hotkey_stop, "session_pulse_hotkey_stop")
    save_hotkey(hotkey_skip, "session_pulse_hotkey_skip")
    save_hotkey(hotkey_add_time, "session_pulse_hotkey_add_time")
    save_hotkey(hotkey_sub_time, "session_pulse_hotkey_sub_time")
    save_hotkey(hotkey_reset, "session_pulse_hotkey_reset")

    if is_running then save_state(true) end
end

function script_unload()
    if is_running then
        save_state(true)
        log("State saved for resume")
    end

    obs.obs_frontend_remove_event_callback(on_frontend_event)
    obs.timer_remove(timer_tick)
    obs.obs_hotkey_unregister(hotkey_start_pause)
    obs.obs_hotkey_unregister(hotkey_stop)
    obs.obs_hotkey_unregister(hotkey_skip)
    obs.obs_hotkey_unregister(hotkey_add_time)
    obs.obs_hotkey_unregister(hotkey_sub_time)
    obs.obs_hotkey_unregister(hotkey_reset)
    log("Unloaded")
end
