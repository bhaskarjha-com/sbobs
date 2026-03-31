--[[
    SessionPulse v5.0.0
    Session automation engine for OBS Studio.
    Wallclock-based timing, WebSocket dock control, scene/source/filter/volume
    automation, warning alerts, time adjustment, session logging, chapter markers,
    browser overlays, and state persistence with atomic writes.

    https://github.com/bhaskarjha-com/sbobs
    License: MIT
]]

local obs = obslua

if not obs then
    print("[SessionPulse] Error: This script must be run within OBS Studio.")
    return
end

local VERSION = "5.0.0"

------------------------------------------------------------------------
-- State
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
local pending_scene_switch = nil
local suggestion_index = 0
local custom_segments = {}
local custom_segment_index = 1
local overtime_seconds = 0
local is_overtime = false
local stream_start_time = 0

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
local fade_duration = 3

------------------------------------------------------------------------
-- Configuration (loaded from settings via script_update)
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
local enable_scene_switching = false
local enable_chapter_markers = true
local enable_mic_control = false
local auto_start_on_stream = false
local auto_stop_on_stream_end = false

-- Scene names
local focus_scene = ""
local short_break_scene = ""
local long_break_scene = ""

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
-- Hotkey IDs
------------------------------------------------------------------------
local hotkey_start_pause = obs.OBS_INVALID_HOTKEY_ID
local hotkey_stop = obs.OBS_INVALID_HOTKEY_ID
local hotkey_skip = obs.OBS_INVALID_HOTKEY_ID
local hotkey_add_time = obs.OBS_INVALID_HOTKEY_ID
local hotkey_sub_time = obs.OBS_INVALID_HOTKEY_ID

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function log(msg)
    print("[SessionPulse] " .. msg)
end

local function mark_dirty()
    state_dirty = true
end

local function json_escape(str)
    if not str then return "" end
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    -- Escape control characters (0x00-0x1F)
    str = str:gsub('[%c]', function(c)
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
-- Session History Log
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
        file:write("date,time,session_type,duration_seconds,completed,mode,total_focus\n")
    end

    file:write(string.format("%s,%s,%s,%d,%s,%s,%d\n",
        os.date("%Y-%m-%d"),
        os.date("%H:%M:%S"),
        stype,
        duration,
        tostring(completed),
        timer_mode,
        total_focus_seconds
    ))
    file:close()
end

------------------------------------------------------------------------
-- Session Persistence
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

    local json = string.format(
        '{\n' ..
        '  "version": "%s",\n' ..
        '  "timer_mode": "%s",\n' ..
        '  "is_running": %s,\n' ..
        '  "is_paused": %s,\n' ..
        '  "session_type": "%s",\n' ..
        '  "current_time": %d,\n' ..
        '  "total_time": %d,\n' ..
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
-- OBS Source Interaction
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

local function update_background_media()
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

------------------------------------------------------------------------
-- Scene Switching
------------------------------------------------------------------------
local function do_scene_switch()
    if not enable_scene_switching then return end
    local scene_map = {
        Focus = focus_scene,
        ["Short Break"] = short_break_scene,
        ["Long Break"] = long_break_scene
    }
    local target_scene = scene_map[session_type]
    if not target_scene or target_scene == "" then return end

    local source = obs.obs_get_source_by_name(target_scene)
    if source then
        obs.obs_frontend_set_current_scene(source)
        obs.obs_source_release(source)
        log("Switched to scene: " .. target_scene)
    end
end

local function schedule_scene_switch()
    if not enable_scene_switching then return end
    pending_scene_switch = true
end

local function process_pending_scene_switch()
    if pending_scene_switch then
        pending_scene_switch = nil
        do_scene_switch()
    end
end

------------------------------------------------------------------------
-- Mic Control
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
-- Source Visibility
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
-- Volume Ducking
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
    fade_duration = 3
    fade_active = true
end

local function process_volume_fade()
    if not fade_active then return end
    fade_elapsed = fade_elapsed + 1
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
-- Filter Toggle
------------------------------------------------------------------------
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
                obs.obs_source_filter_set_enabled(source, name, in_focus)
            end
        end
    end

    -- Disable filters during focus (enable during break)
    if focus_filters_disable and focus_filters_disable ~= "" then
        for fname in focus_filters_disable:gmatch("([^,]+)") do
            local name = fname:match("^%s*(.-)%s*$")
            if name and name ~= "" then
                obs.obs_source_filter_set_enabled(source, name, not in_focus)
            end
        end
    end

    obs.obs_source_release(source)
    log("Filters updated for " .. session_type)
end

------------------------------------------------------------------------
-- Chapter Markers
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
-- Display
------------------------------------------------------------------------
local function create_progress_bar(elapsed, total)
    if not show_progress_bar or total <= 0 then return "" end
    local filled = math.floor((elapsed / total) * progress_bar_length)
    filled = math.min(filled, progress_bar_length)
    return string.rep("█", filled) .. string.rep("░", progress_bar_length - filled)
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

local function update_display_texts()
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
        local total = get_duration_for_session(session_type)
        if is_overtime then
            update_obs_source_text(progress_bar_source,
                string.rep("█", progress_bar_length))
        else
            local elapsed = total - current_time
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
-- Session Management
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
    update_background_media()
    play_alert_sound()
    schedule_scene_switch()
    update_mic_state()
    update_source_visibility()
    update_volume()
    update_filters()
    add_chapter_marker()
    mark_dirty()
end

local function switch_session()
    if timer_mode == "pomodoro" then
        if session_type == "Focus" then
            completed_focus_sessions = completed_focus_sessions + 1
            cycle_count = cycle_count + 1
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
-- Timer
------------------------------------------------------------------------
local function fire_warning_alert()
    -- Uses focus_alert_sound_path as the warning sound (same alert source)
    if not alert_source_name or alert_source_name == "" then return end
    if not focus_alert_sound_path or focus_alert_sound_path == "" then return end
    local source = obs.obs_get_source_by_name(alert_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "local_file", focus_alert_sound_path)
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

    -- 5-minute warning
    if warning_5min_enabled and not warning_5min_fired and time_remaining <= 300 and time_remaining > 298 then
        warning_5min_fired = true
        fire_warning_alert()
        log("Warning: 5 minutes remaining")
    end

    -- 1-minute warning
    if warning_1min_enabled and not warning_1min_fired and time_remaining <= 60 and time_remaining > 58 then
        warning_1min_fired = true
        fire_warning_alert()
        log("Warning: 1 minute remaining")
    end

    -- Break ending warning (during breaks only)
    if warning_break_end_enabled and not warning_break_end_fired
       and session_type ~= "Focus" and timer_mode == "pomodoro"
       and time_remaining <= warning_break_end_seconds and time_remaining > (warning_break_end_seconds - 2) then
        warning_break_end_fired = true
        fire_warning_alert()
        log("Warning: break ending in " .. warning_break_end_seconds .. "s")
    end
end

local function timer_tick()
    process_pending_scene_switch()
    process_volume_fade()

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
                    overtime_seconds = 0
                    play_alert_sound()
                    log("Overtime started for " .. session_type)
                elseif is_overtime then
                    overtime_seconds = overtime_seconds + 1
                else
                    switch_session()
                end
            end
        end
        mark_dirty()
    end
    update_display_texts()
    save_state()
end

------------------------------------------------------------------------
-- Controls
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
    session_type = "Focus"
    current_time = focus_duration
    cycle_count = 0
    show_transition = false
    custom_segment_index = 1
    is_overtime = false
    overtime_seconds = 0

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
        is_running = true
        is_paused = false
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
    current_time = compute_current_time()

    -- Reset warnings that might fire again
    if current_time > 300 then warning_5min_fired = false end
    if current_time > 60 then warning_1min_fired = false end

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

------------------------------------------------------------------------
-- Hotkey Callbacks
------------------------------------------------------------------------
local function on_hotkey_start_pause(pressed)
    if not pressed then return end
    toggle_pause()
end

local function on_hotkey_stop(pressed)
    if not pressed then return end
    stop_timer()
end

local function on_hotkey_skip(pressed)
    if not pressed then return end
    skip_session()
end

local function on_hotkey_add_time(pressed)
    if not pressed then return end
    add_time()
end

local function on_hotkey_sub_time(pressed)
    if not pressed then return end
    subtract_time()
end

------------------------------------------------------------------------
-- Frontend Events
------------------------------------------------------------------------
local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        log("Stream started")
        stream_start_time = os.time()
        if auto_start_on_stream and not is_running then
            start_timer()
        end

    elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        log("Stream stopped")
        if auto_stop_on_stream_end and is_running then
            show_session_summary()
            stop_timer()
        elseif is_running then
            show_session_summary()
        end

    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        log("Recording started")
        if enable_chapter_markers and is_running then
            add_chapter_marker()
        end
    end
end

------------------------------------------------------------------------
-- Source / Scene Enumeration
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
-- OBS Script Interface
------------------------------------------------------------------------
function script_description()
    return "SessionPulse v" .. VERSION ..
        " — Session automation engine for OBS Studio."
end

function script_properties()
    local props = obs.obs_properties_create()
    local p

    -- ── Controls ──
    obs.obs_properties_add_button(props, "start_button", "▶  Start", start_timer)
    obs.obs_properties_add_button(props, "pause_button", "⏸  Pause / Resume", toggle_pause)
    obs.obs_properties_add_button(props, "stop_button", "⏹  Stop", stop_timer)
    obs.obs_properties_add_button(props, "skip_button", "⏭  Skip Session", skip_session)
    obs.obs_properties_add_button(props, "reset_button", "↺  Reset All", reset_timer)
    obs.obs_properties_add_button(props, "add_time_button", "+  Add Time", add_time)
    obs.obs_properties_add_button(props, "sub_time_button", "−  Subtract Time", subtract_time)

    if has_pending_resume then
        obs.obs_properties_add_button(props, "resume_button",
            "⏪  Resume Previous Session", resume_previous_session)
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

    -- ── Scene Switching (checkable group) ──
    local scene_group = obs.obs_properties_create()
    p = obs.obs_properties_add_list(scene_group, "focus_scene",
        "Focus Scene", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_scene_list(p)
    p = obs.obs_properties_add_list(scene_group, "short_break_scene",
        "Short Break Scene", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_scene_list(p)
    p = obs.obs_properties_add_list(scene_group, "long_break_scene",
        "Long Break Scene", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_scene_list(p)
    obs.obs_properties_add_group(props, "enable_scene_switching", "Scene Switching",
        obs.OBS_GROUP_CHECKABLE, scene_group)

    -- ── Mic Control (checkable group) ──
    local mic_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(mic_group, "mute_mic_during_focus", "Mute Mic During Focus")
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
    obs.obs_properties_add_bool(vol_group, "enable_volume_fade", "Smooth Volume Fade (3s)")
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

    enable_scene_switching = obs.obs_data_get_bool(settings, "enable_scene_switching")
    focus_scene = obs.obs_data_get_string(settings, "focus_scene")
    short_break_scene = obs.obs_data_get_string(settings, "short_break_scene")
    long_break_scene = obs.obs_data_get_string(settings, "long_break_scene")

    enable_mic_control = obs.obs_data_get_bool(settings, "enable_mic_control")
    mute_mic_during_focus = obs.obs_data_get_bool(settings, "mute_mic_during_focus")
    mic_source_name = obs.obs_data_get_string(settings, "mic_source_name")

    hide_during_focus_source = obs.obs_data_get_string(settings, "hide_during_focus_source")

    volume_source_name = obs.obs_data_get_string(settings, "volume_source_name")
    focus_volume = obs.obs_data_get_int(settings, "focus_volume") / 100.0
    break_volume = obs.obs_data_get_int(settings, "break_volume") / 100.0
    enable_volume_fade = obs.obs_data_get_bool(settings, "enable_volume_fade")

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

    focus_alert_sound_path = obs.obs_data_get_string(settings, "focus_alert_sound_path")
    short_break_alert_sound_path = obs.obs_data_get_string(settings, "short_break_alert_sound_path")
    long_break_alert_sound_path = obs.obs_data_get_string(settings, "long_break_alert_sound_path")

    focus_background_media = obs.obs_data_get_string(settings, "focus_background_media")
    short_break_background_media = obs.obs_data_get_string(settings, "short_break_background_media")
    long_break_background_media = obs.obs_data_get_string(settings, "long_break_background_media")
end

function script_update(settings)
    update_timer_config(settings)
    update_automation_config(settings)
    update_source_config(settings)

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
-- Lifecycle
------------------------------------------------------------------------
function script_load(settings)
    obs.timer_add(timer_tick, 1000)

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

    obs.obs_frontend_add_event_callback(on_frontend_event)

    local saved_state = load_state()
    if saved_state and saved_state.is_running then
        has_pending_resume = true
        log("Found saved session — use 'Resume Previous Session' button to restore")
    end

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
    log("Unloaded")
end
