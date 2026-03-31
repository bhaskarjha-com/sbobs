--[[
    OBS Session Timer v3.1.0
    Session timer and environment controller for OBS Studio.
    Multiple timer modes, scene switching, chapter markers, mic control,
    source visibility, break suggestions, browser overlay, and persistence.

    https://github.com/bhaskarjha-com/sbobs
    License: MIT
]]

local obs = obslua

if not obs then
    print("[Pomodoro] Error: This script must be run within OBS Studio.")
    return
end

local VERSION = "3.1.0"

------------------------------------------------------------------------
-- State
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

------------------------------------------------------------------------
-- Configuration (loaded from settings via script_update)
------------------------------------------------------------------------
-- Timer mode: "pomodoro", "stopwatch", "countdown", "custom"
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

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function log(msg)
    print("[Pomodoro] " .. msg)
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
    return obs.script_path() .. "pomodoro_state.json"
end

-- Parse comma-separated break suggestions
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

-- Parse custom intervals: "Name:Minutes,Name:Minutes,..."
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

-- Get next break suggestion
local function get_break_suggestion()
    if #parsed_suggestions == 0 then return nil end
    suggestion_index = suggestion_index + 1
    if suggestion_index > #parsed_suggestions then
        suggestion_index = 1
    end
    return parsed_suggestions[suggestion_index]
end

------------------------------------------------------------------------
-- Session Persistence
------------------------------------------------------------------------
local function save_state()
    local path = get_state_file_path()
    local file = io.open(path, "w")
    if not file then return end

    local total = get_duration_for_session(session_type)
    local seg_name = ""
    if timer_mode == "custom" and custom_segments[custom_segment_index] then
        seg_name = custom_segments[custom_segment_index].name
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
        '  "timestamp": %d\n' ..
        '}',
        VERSION,
        timer_mode,
        tostring(is_running),
        tostring(is_paused),
        session_type,
        current_time,
        total,
        cycle_count,
        completed_focus_sessions,
        goal_sessions,
        total_focus_seconds,
        tostring(show_transition),
        transition_message:gsub('"', '\\"'),
        seg_name:gsub('"', '\\"'),
        custom_segment_index,
        #custom_segments,
        os.time()
    )

    file:write(json)
    file:close()
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
    }

    if not state.current_time then
        log("State file corrupt — ignoring")
        return nil
    end

    -- For pomodoro mode, validate session type
    if (not state.timer_mode or state.timer_mode == "pomodoro") and state.session_type then
        if state.session_type ~= "Focus" and
           state.session_type ~= "Short Break" and
           state.session_type ~= "Long Break" then
            log("Unknown session type in state: " .. state.session_type)
            return nil
        end
    end

    return state
end

local function delete_state_file()
    os.remove(get_state_file_path())
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

    if state.is_running then
        is_running = true
        is_paused = true
        log("Resumed — " .. session_type .. " at " .. format_time(current_time) .. " (paused)")
    else
        is_running = false
        is_paused = false
    end

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

    local source = obs.obs_get_source_by_name(hide_during_focus_source)
    if source then
        obs.obs_source_set_enabled(source, should_show)
        obs.obs_source_release(source)
        log("Source '" .. hide_during_focus_source .. "' " .. (should_show and "shown" or "hidden"))
    end
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

    -- Append break suggestion during breaks in pomodoro mode
    if timer_mode == "pomodoro" and session_type ~= "Focus" and
       not show_transition and #parsed_suggestions > 0 then
        local suggestion = parsed_suggestions[suggestion_index]
        if suggestion then
            message = message .. " · " .. suggestion
        end
    end

    if is_paused then message = message .. " (" .. paused_message .. ")" end
    update_obs_source_text(message_source, message)

    -- Time
    update_obs_source_text(time_source, format_time(current_time))

    -- Progress bar
    if show_progress_bar and timer_mode ~= "stopwatch" then
        local total = get_duration_for_session(session_type)
        local elapsed = total - current_time
        update_obs_source_text(progress_bar_source, create_progress_bar(elapsed, total))
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
    session_type = new_type
    current_time = duration
    show_transition_msg(message)
    update_background_media()
    play_alert_sound()
    schedule_scene_switch()
    update_mic_state()
    update_source_visibility()
    add_chapter_marker()
end

local function switch_session()
    if timer_mode == "pomodoro" then
        -- Standard Pomodoro cycling
        if session_type == "Focus" then
            completed_focus_sessions = completed_focus_sessions + 1
            cycle_count = cycle_count + 1
            -- Get a break suggestion for the upcoming break
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
        -- Countdown finished
        show_transition_msg("Countdown complete!")
        play_alert_sound()
        is_running = false
        is_paused = false
        log("Countdown complete")
        delete_state_file()
        return

    elseif timer_mode == "custom" then
        -- Advance to next segment
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
                log("All custom segments complete")
                delete_state_file()
                return
            end
        end

        local seg = custom_segments[custom_segment_index]
        if seg then
            session_type = seg.name
            current_time = seg.duration
            show_transition_msg("Next: " .. seg.name)
            play_alert_sound()
            add_chapter_marker()
        end
        save_state()
        return
    end

    if not auto_start_next then
        is_paused = true
        log("Session changed — waiting for manual resume")
    end

    save_state()
end

------------------------------------------------------------------------
-- Timer
------------------------------------------------------------------------
local function timer_tick()
    process_pending_scene_switch()

    if not is_running or is_paused then return end

    if show_transition then
        transition_timer = transition_timer - 1
        if transition_timer <= 0 then
            show_transition = false
        end
    else
        if timer_mode == "stopwatch" then
            -- Count UP
            current_time = current_time + 1
            total_focus_seconds = total_focus_seconds + 1
        else
            -- Count DOWN (pomodoro, countdown, custom)
            if current_time > 0 then
                current_time = current_time - 1
                if timer_mode == "pomodoro" and session_type == "Focus" then
                    total_focus_seconds = total_focus_seconds + 1
                elseif timer_mode == "custom" then
                    total_focus_seconds = total_focus_seconds + 1
                end
            else
                switch_session()
            end
        end
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
        is_paused = false
        log("Timer resumed")
    else
        is_running = true
        is_paused = false

        -- Initialize based on mode
        if timer_mode == "stopwatch" then
            current_time = 0
            session_type = "Stopwatch"
            log("Stopwatch started")
        elseif timer_mode == "countdown" then
            current_time = countdown_duration
            session_type = "Countdown"
            log("Countdown started — " .. format_time(countdown_duration))
        elseif timer_mode == "custom" then
            if #custom_segments == 0 then
                log("No custom segments defined — add segments like 'Work:25,Break:5'")
                is_running = false
                return
            end
            custom_segment_index = 1
            local seg = custom_segments[1]
            session_type = seg.name
            current_time = seg.duration
            log("Custom intervals started — " .. seg.name .. " (" .. format_time(seg.duration) .. ")")
        else
            -- Pomodoro: keep current state or init to focus
            if current_time <= 0 then
                current_time = focus_duration
                session_type = "Focus"
            end
            log("Timer started — " .. session_type .. " (" .. format_time(current_time) .. ")")
        end
    end
    update_display_texts()
    update_background_media()
    update_mic_state()
    update_source_visibility()
    save_state()
end

local function toggle_pause()
    if not is_running then
        start_timer()
        return
    end
    is_paused = not is_paused
    log(is_paused and "Timer paused" or "Timer resumed")
    update_display_texts()
    save_state()
end

local function stop_timer()
    is_running = false
    is_paused = false
    session_type = "Focus"
    current_time = focus_duration
    cycle_count = 0
    show_transition = false
    custom_segment_index = 1
    log("Timer stopped")
    update_display_texts()
    delete_state_file()
end

local function reset_timer()
    stop_timer()
    completed_focus_sessions = 0
    total_focus_seconds = 0
    suggestion_index = 0
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

    log("Skipping " .. session_type)
    switch_session()
    if is_paused then
        is_paused = false
    end
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

------------------------------------------------------------------------
-- Frontend Events
------------------------------------------------------------------------
local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        log("Stream started")
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
    return "Session Timer v" .. VERSION ..
        " — Multi-mode timer with scene switching, chapter markers, overlays, and more."
end

function script_properties()
    local props = obs.obs_properties_create()

    -- ── Controls ──
    obs.obs_properties_add_button(props, "start_button", "▶  Start", start_timer)
    obs.obs_properties_add_button(props, "pause_button", "⏸  Pause / Resume", toggle_pause)
    obs.obs_properties_add_button(props, "stop_button", "⏹  Stop", stop_timer)
    obs.obs_properties_add_button(props, "skip_button", "⏭  Skip Session", skip_session)
    obs.obs_properties_add_button(props, "reset_button", "↺  Reset All", reset_timer)

    if has_pending_resume then
        obs.obs_properties_add_button(props, "resume_button",
            "⏪  Resume Previous Session", resume_previous_session)
    end

    -- ── Timer Mode ──
    local mode_list = obs.obs_properties_add_list(props, "timer_mode",
        "Timer Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(mode_list, "Pomodoro", "pomodoro")
    obs.obs_property_list_add_string(mode_list, "Stopwatch (count up)", "stopwatch")
    obs.obs_property_list_add_string(mode_list, "Countdown (single)", "countdown")
    obs.obs_property_list_add_string(mode_list, "Custom Intervals", "custom")

    -- ── Pomodoro Durations ──
    obs.obs_properties_add_int(props, "focus_duration", "Focus Duration (min)", 1, 120, 1)
    obs.obs_properties_add_int(props, "short_break_duration", "Short Break (min)", 1, 30, 1)
    obs.obs_properties_add_int(props, "long_break_duration", "Long Break (min)", 1, 60, 1)
    obs.obs_properties_add_int(props, "long_break_interval", "Long Break Every (cycles)", 1, 10, 1)
    obs.obs_properties_add_int(props, "goal_sessions", "Goal Sessions", 1, 20, 1)

    -- ── Countdown Duration ──
    obs.obs_properties_add_int(props, "countdown_duration", "Countdown Duration (min)", 1, 480, 1)

    -- ── Custom Intervals ──
    obs.obs_properties_add_text(props, "custom_intervals_text",
        "Custom Intervals (Name:Min,...)", obs.OBS_TEXT_DEFAULT)

    -- ── Behavior ──
    obs.obs_properties_add_bool(props, "auto_start_next", "Auto-start Next Session / Loop")
    obs.obs_properties_add_bool(props, "show_progress_bar", "Show Progress Bar")
    obs.obs_properties_add_int(props, "transition_display_time", "Transition Message Duration (sec)", 1, 10, 1)

    -- ── Break Suggestions ──
    obs.obs_properties_add_text(props, "break_suggestions_text",
        "Break Suggestions (comma-separated)", obs.OBS_TEXT_DEFAULT)

    -- ── Stream Integration ──
    obs.obs_properties_add_bool(props, "auto_start_on_stream", "Auto-start Timer on Stream Start")
    obs.obs_properties_add_bool(props, "auto_stop_on_stream_end", "Auto-stop Timer on Stream End")
    obs.obs_properties_add_bool(props, "enable_chapter_markers", "Add Recording Chapter Markers")

    -- ── Scene Switching ──
    obs.obs_properties_add_bool(props, "enable_scene_switching", "Enable Scene Switching")

    local p

    p = obs.obs_properties_add_list(props, "focus_scene",
        "Focus Scene", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_scene_list(p)

    p = obs.obs_properties_add_list(props, "short_break_scene",
        "Short Break Scene", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_scene_list(p)

    p = obs.obs_properties_add_list(props, "long_break_scene",
        "Long Break Scene", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_scene_list(p)

    -- ── Mic Control ──
    obs.obs_properties_add_bool(props, "enable_mic_control", "Enable Mic Control")
    obs.obs_properties_add_bool(props, "mute_mic_during_focus", "Mute Mic During Focus")

    p = obs.obs_properties_add_list(props, "mic_source_name",
        "Mic Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    -- ── Source Visibility ──
    p = obs.obs_properties_add_list(props, "hide_during_focus_source",
        "Hide During Focus (e.g. webcam)", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    -- ── Text Sources ──
    p = obs.obs_properties_add_list(props, "time_source",
        "Timer Text Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    p = obs.obs_properties_add_list(props, "message_source",
        "Session Message Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    p = obs.obs_properties_add_list(props, "focus_count_source",
        "Focus Count Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    p = obs.obs_properties_add_list(props, "progress_bar_source",
        "Progress Bar Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    p = obs.obs_properties_add_list(props, "background_media_source",
        "Background Media Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    p = obs.obs_properties_add_list(props, "alert_source_name",
        "Alert Sound Source (Media)", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_source_list(p)

    -- ── Audio Files ──
    obs.obs_properties_add_path(props, "focus_alert_sound_path",
        "Focus Alert Sound", obs.OBS_PATH_FILE, "Audio (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_path(props, "short_break_alert_sound_path",
        "Short Break Alert Sound", obs.OBS_PATH_FILE, "Audio (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_path(props, "long_break_alert_sound_path",
        "Long Break Alert Sound", obs.OBS_PATH_FILE, "Audio (*.mp3 *.ogg *.wav)", nil)

    -- ── Background Media ──
    obs.obs_properties_add_path(props, "focus_background_media",
        "Focus Background", obs.OBS_PATH_FILE,
        "Media (*.png *.jpg *.jpeg *.bmp *.gif *.mp4 *.webm *.mov *.mkv)", nil)
    obs.obs_properties_add_path(props, "short_break_background_media",
        "Short Break Background", obs.OBS_PATH_FILE,
        "Media (*.png *.jpg *.jpeg *.bmp *.gif *.mp4 *.webm *.mov *.mkv)", nil)
    obs.obs_properties_add_path(props, "long_break_background_media",
        "Long Break Background", obs.OBS_PATH_FILE,
        "Media (*.png *.jpg *.jpeg *.bmp *.gif *.mp4 *.webm *.mov *.mkv)", nil)

    -- ── Messages ──
    obs.obs_properties_add_text(props, "focus_message",
        "Focus Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "short_break_message",
        "Short Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "long_break_message",
        "Long Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "transition_to_focus_message",
        "→ Focus Transition", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "transition_to_short_break_message",
        "→ Short Break Transition", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "transition_to_long_break_message",
        "→ Long Break Transition", obs.OBS_TEXT_DEFAULT)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "timer_mode", "pomodoro")
    obs.obs_data_set_default_int(settings, "focus_duration", 25)
    obs.obs_data_set_default_int(settings, "short_break_duration", 5)
    obs.obs_data_set_default_int(settings, "long_break_duration", 15)
    obs.obs_data_set_default_int(settings, "long_break_interval", 4)
    obs.obs_data_set_default_int(settings, "goal_sessions", 6)
    obs.obs_data_set_default_int(settings, "countdown_duration", 25)
    obs.obs_data_set_default_int(settings, "transition_display_time", 2)
    obs.obs_data_set_default_bool(settings, "show_progress_bar", true)
    obs.obs_data_set_default_bool(settings, "auto_start_next", true)
    obs.obs_data_set_default_bool(settings, "enable_chapter_markers", true)
    obs.obs_data_set_default_bool(settings, "mute_mic_during_focus", true)
    obs.obs_data_set_default_string(settings, "custom_intervals_text", "Work:25,Break:5,Work:25,Break:5")
    obs.obs_data_set_default_string(settings, "break_suggestions_text",
        "Stretch!,Hydrate!,Look away from screen,Take a walk,Deep breaths,Roll your shoulders,Stand up,Rest your eyes")

    obs.obs_data_set_default_string(settings, "focus_message", "Focus Time")
    obs.obs_data_set_default_string(settings, "short_break_message", "Short Break")
    obs.obs_data_set_default_string(settings, "long_break_message", "Long Break")
    obs.obs_data_set_default_string(settings, "transition_to_focus_message", "Back to focus time!")
    obs.obs_data_set_default_string(settings, "transition_to_short_break_message", "Time for a short break!")
    obs.obs_data_set_default_string(settings, "transition_to_long_break_message", "Time for a long break!")
end

function script_update(settings)
    -- Timer mode
    timer_mode = obs.obs_data_get_string(settings, "timer_mode")

    -- Durations
    focus_duration = obs.obs_data_get_int(settings, "focus_duration") * 60
    short_break_duration = obs.obs_data_get_int(settings, "short_break_duration") * 60
    long_break_duration = obs.obs_data_get_int(settings, "long_break_duration") * 60
    long_break_interval = obs.obs_data_get_int(settings, "long_break_interval")
    goal_sessions = obs.obs_data_get_int(settings, "goal_sessions")
    countdown_duration = obs.obs_data_get_int(settings, "countdown_duration") * 60
    transition_display_time = obs.obs_data_get_int(settings, "transition_display_time")
    show_progress_bar = obs.obs_data_get_bool(settings, "show_progress_bar")
    auto_start_next = obs.obs_data_get_bool(settings, "auto_start_next")

    -- Custom intervals
    custom_intervals_text = obs.obs_data_get_string(settings, "custom_intervals_text")
    custom_segments = parse_custom_intervals(custom_intervals_text)

    -- Break suggestions
    break_suggestions_text = obs.obs_data_get_string(settings, "break_suggestions_text")
    parsed_suggestions = parse_suggestions(break_suggestions_text)

    -- Stream integration
    auto_start_on_stream = obs.obs_data_get_bool(settings, "auto_start_on_stream")
    auto_stop_on_stream_end = obs.obs_data_get_bool(settings, "auto_stop_on_stream_end")
    enable_chapter_markers = obs.obs_data_get_bool(settings, "enable_chapter_markers")

    -- Scene switching
    enable_scene_switching = obs.obs_data_get_bool(settings, "enable_scene_switching")
    focus_scene = obs.obs_data_get_string(settings, "focus_scene")
    short_break_scene = obs.obs_data_get_string(settings, "short_break_scene")
    long_break_scene = obs.obs_data_get_string(settings, "long_break_scene")

    -- Mic control
    enable_mic_control = obs.obs_data_get_bool(settings, "enable_mic_control")
    mute_mic_during_focus = obs.obs_data_get_bool(settings, "mute_mic_during_focus")
    mic_source_name = obs.obs_data_get_string(settings, "mic_source_name")

    -- Source visibility
    hide_during_focus_source = obs.obs_data_get_string(settings, "hide_during_focus_source")

    -- Sources
    focus_count_source = obs.obs_data_get_string(settings, "focus_count_source")
    message_source = obs.obs_data_get_string(settings, "message_source")
    time_source = obs.obs_data_get_string(settings, "time_source")
    progress_bar_source = obs.obs_data_get_string(settings, "progress_bar_source")
    background_media_source = obs.obs_data_get_string(settings, "background_media_source")
    alert_source_name = obs.obs_data_get_string(settings, "alert_source_name")

    -- Messages
    focus_message = obs.obs_data_get_string(settings, "focus_message")
    short_break_message = obs.obs_data_get_string(settings, "short_break_message")
    long_break_message = obs.obs_data_get_string(settings, "long_break_message")
    transition_to_focus_message = obs.obs_data_get_string(settings, "transition_to_focus_message")
    transition_to_short_break_message = obs.obs_data_get_string(settings, "transition_to_short_break_message")
    transition_to_long_break_message = obs.obs_data_get_string(settings, "transition_to_long_break_message")

    -- Audio paths
    focus_alert_sound_path = obs.obs_data_get_string(settings, "focus_alert_sound_path")
    short_break_alert_sound_path = obs.obs_data_get_string(settings, "short_break_alert_sound_path")
    long_break_alert_sound_path = obs.obs_data_get_string(settings, "long_break_alert_sound_path")

    -- Background media
    focus_background_media = obs.obs_data_get_string(settings, "focus_background_media")
    short_break_background_media = obs.obs_data_get_string(settings, "short_break_background_media")
    long_break_background_media = obs.obs_data_get_string(settings, "long_break_background_media")

    -- Sync display when timer is idle
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
        "pomodoro_start_pause", "Pomodoro: Start / Pause", on_hotkey_start_pause)
    hotkey_stop = obs.obs_hotkey_register_frontend(
        "pomodoro_stop", "Pomodoro: Stop", on_hotkey_stop)
    hotkey_skip = obs.obs_hotkey_register_frontend(
        "pomodoro_skip", "Pomodoro: Skip Session", on_hotkey_skip)

    local function load_hotkey(id, key)
        local a = obs.obs_data_get_array(settings, key)
        obs.obs_hotkey_load(id, a)
        obs.obs_data_array_release(a)
    end
    load_hotkey(hotkey_start_pause, "pomodoro_hotkey_start_pause")
    load_hotkey(hotkey_stop, "pomodoro_hotkey_stop")
    load_hotkey(hotkey_skip, "pomodoro_hotkey_skip")

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
    save_hotkey(hotkey_start_pause, "pomodoro_hotkey_start_pause")
    save_hotkey(hotkey_stop, "pomodoro_hotkey_stop")
    save_hotkey(hotkey_skip, "pomodoro_hotkey_skip")

    if is_running then save_state() end
end

function script_unload()
    if is_running then
        save_state()
        log("State saved for resume")
    end

    obs.obs_frontend_remove_event_callback(on_frontend_event)
    obs.timer_remove(timer_tick)
    obs.obs_hotkey_unregister(hotkey_start_pause)
    obs.obs_hotkey_unregister(hotkey_stop)
    obs.obs_hotkey_unregister(hotkey_skip)
    log("Unloaded")
end
