--[[
    OBS Pomodoro Timer v2.0.0
    Focus/Break session timer with hotkeys, alerts, backgrounds, and progress tracking.

    https://github.com/bhaskarjha-com/sbobs
    License: MIT
]]

local obs = obslua

if not obs then
    print("[Pomodoro] Error: This script must be run within OBS Studio.")
    return
end

local VERSION = "2.0.0"

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local current_time = 0
local cycle_count = 0
local completed_focus_sessions = 0
local is_running = false
local is_paused = false
local session_type = "Focus"
local show_transition = false
local transition_timer = 0
local transition_message = ""

------------------------------------------------------------------------
-- Configuration (loaded from settings via script_update)
------------------------------------------------------------------------
local focus_duration = 1500
local short_break_duration = 300
local long_break_duration = 900
local long_break_interval = 4
local goal_sessions = 6
local transition_display_time = 2
local show_progress_bar = true
local auto_start_next = true
local progress_bar_length = 100

-- Source names (selected via dropdowns)
local focus_count_source = ""
local message_source = ""
local time_source = ""
local progress_bar_source = ""
local background_image_source = ""
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
local focus_background_image = ""
local short_break_background_image = ""
local long_break_background_image = ""
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

local function update_background_image()
    if not background_image_source or background_image_source == "" then return end

    local image_map = {
        Focus = focus_background_image,
        ["Short Break"] = short_break_background_image,
        ["Long Break"] = long_break_background_image
    }
    local image_path = image_map[session_type]

    local source = obs.obs_get_source_by_name(background_image_source)
    if source then
        if image_path and image_path ~= "" then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "file", image_path)
            obs.obs_source_update(source, settings)
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

    if not alert_source_name or alert_source_name == "" then
        log("Alert source not configured — skipping sound")
        return
    end

    local source = obs.obs_get_source_by_name(alert_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "local_file", sound_path)
        obs.obs_data_set_bool(settings, "is_local_file", true)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_media_restart(source)
        obs.obs_source_release(source)
    else
        log("Alert source '" .. alert_source_name .. "' not found — create a Media Source with that name")
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
    if session_type == "Focus" then return focus_message end
    if session_type == "Short Break" then return short_break_message end
    return long_break_message
end

local function update_display_texts()
    -- Focus count
    update_obs_source_text(focus_count_source,
        string.format("Done: %d/%d", completed_focus_sessions, goal_sessions))

    -- Session message
    local message = show_transition and transition_message or get_session_message()
    if is_paused then message = message .. " (" .. paused_message .. ")" end
    update_obs_source_text(message_source, message)

    -- Time
    update_obs_source_text(time_source, format_time(current_time))

    -- Progress bar (fills UP as time elapses)
    if show_progress_bar then
        local total = get_duration_for_session(session_type)
        local elapsed = total - current_time
        update_obs_source_text(progress_bar_source, create_progress_bar(elapsed, total))
    else
        update_obs_source_text(progress_bar_source, "")
    end
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
    update_background_image()
    play_alert_sound()
end

local function switch_session()
    if session_type == "Focus" then
        completed_focus_sessions = completed_focus_sessions + 1
        cycle_count = cycle_count + 1
        if cycle_count % long_break_interval == 0 then
            update_session("Long Break", long_break_duration, transition_to_long_break_message)
        else
            update_session("Short Break", short_break_duration, transition_to_short_break_message)
        end
    else
        update_session("Focus", focus_duration, transition_to_focus_message)
    end

    if not auto_start_next then
        is_paused = true
        log("Session changed — waiting for manual resume")
    end
end

------------------------------------------------------------------------
-- Timer
------------------------------------------------------------------------
local function timer_tick()
    if not is_running or is_paused then return end

    if show_transition then
        transition_timer = transition_timer - 1
        if transition_timer <= 0 then
            show_transition = false
        end
    else
        if current_time > 0 then
            current_time = current_time - 1
        else
            switch_session()
        end
    end
    update_display_texts()
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
        log("Timer started — " .. session_type .. " (" .. format_time(current_time) .. ")")
    end
    update_display_texts()
    update_background_image()
end

local function toggle_pause()
    if not is_running then
        start_timer()
        return
    end
    is_paused = not is_paused
    log(is_paused and "Timer paused" or "Timer resumed")
    update_display_texts()
end

local function stop_timer()
    is_running = false
    is_paused = false
    session_type = "Focus"
    current_time = focus_duration
    cycle_count = 0
    show_transition = false
    log("Timer stopped")
    update_display_texts()
end

local function reset_timer()
    stop_timer()
    completed_focus_sessions = 0
    log("Timer reset — all progress cleared")
    update_display_texts()
end

local function skip_session()
    if not is_running then
        is_running = true
        is_paused = false
    end
    log("Skipping " .. session_type)
    switch_session()
    if is_paused then
        is_paused = false
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
-- Source Enumeration Helper
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

------------------------------------------------------------------------
-- OBS Script Interface
------------------------------------------------------------------------
function script_description()
    return "Pomodoro Timer v" .. VERSION ..
        " — Focus/Break sessions with alerts, backgrounds, and progress tracking."
end

function script_properties()
    local props = obs.obs_properties_create()

    -- ── Controls ──
    obs.obs_properties_add_button(props, "start_button", "▶  Start", start_timer)
    obs.obs_properties_add_button(props, "pause_button", "⏸  Pause / Resume", toggle_pause)
    obs.obs_properties_add_button(props, "stop_button", "⏹  Stop", stop_timer)
    obs.obs_properties_add_button(props, "skip_button", "⏭  Skip Session", skip_session)
    obs.obs_properties_add_button(props, "reset_button", "↺  Reset All", reset_timer)

    -- ── Durations ──
    obs.obs_properties_add_int(props, "focus_duration", "Focus Duration (min)", 1, 120, 1)
    obs.obs_properties_add_int(props, "short_break_duration", "Short Break (min)", 1, 30, 1)
    obs.obs_properties_add_int(props, "long_break_duration", "Long Break (min)", 1, 60, 1)
    obs.obs_properties_add_int(props, "long_break_interval", "Long Break Every (cycles)", 1, 10, 1)
    obs.obs_properties_add_int(props, "goal_sessions", "Goal Sessions", 1, 20, 1)

    -- ── Behavior ──
    obs.obs_properties_add_bool(props, "auto_start_next", "Auto-start Next Session")
    obs.obs_properties_add_bool(props, "show_progress_bar", "Show Progress Bar")
    obs.obs_properties_add_int(props, "transition_display_time", "Transition Message Duration (sec)", 1, 10, 1)

    -- ── OBS Sources (dropdowns) ──
    local p

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

    p = obs.obs_properties_add_list(props, "background_image_source",
        "Background Image Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
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

    -- ── Background Images ──
    obs.obs_properties_add_path(props, "focus_background_image",
        "Focus Background", obs.OBS_PATH_FILE, "Images (*.png *.jpg *.jpeg *.bmp *.gif)", nil)
    obs.obs_properties_add_path(props, "short_break_background_image",
        "Short Break Background", obs.OBS_PATH_FILE, "Images (*.png *.jpg *.jpeg *.bmp *.gif)", nil)
    obs.obs_properties_add_path(props, "long_break_background_image",
        "Long Break Background", obs.OBS_PATH_FILE, "Images (*.png *.jpg *.jpeg *.bmp *.gif)", nil)

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
    obs.obs_data_set_default_int(settings, "focus_duration", 25)
    obs.obs_data_set_default_int(settings, "short_break_duration", 5)
    obs.obs_data_set_default_int(settings, "long_break_duration", 15)
    obs.obs_data_set_default_int(settings, "long_break_interval", 4)
    obs.obs_data_set_default_int(settings, "goal_sessions", 6)
    obs.obs_data_set_default_int(settings, "transition_display_time", 2)
    obs.obs_data_set_default_bool(settings, "show_progress_bar", true)
    obs.obs_data_set_default_bool(settings, "auto_start_next", true)

    obs.obs_data_set_default_string(settings, "focus_message", "Focus Time")
    obs.obs_data_set_default_string(settings, "short_break_message", "Short Break")
    obs.obs_data_set_default_string(settings, "long_break_message", "Long Break")
    obs.obs_data_set_default_string(settings, "transition_to_focus_message", "Back to focus time!")
    obs.obs_data_set_default_string(settings, "transition_to_short_break_message", "Time for a short break!")
    obs.obs_data_set_default_string(settings, "transition_to_long_break_message", "Time for a long break!")
end

function script_update(settings)
    -- Durations (UI shows minutes, internal uses seconds)
    focus_duration = obs.obs_data_get_int(settings, "focus_duration") * 60
    short_break_duration = obs.obs_data_get_int(settings, "short_break_duration") * 60
    long_break_duration = obs.obs_data_get_int(settings, "long_break_duration") * 60
    long_break_interval = obs.obs_data_get_int(settings, "long_break_interval")
    goal_sessions = obs.obs_data_get_int(settings, "goal_sessions")
    transition_display_time = obs.obs_data_get_int(settings, "transition_display_time")
    show_progress_bar = obs.obs_data_get_bool(settings, "show_progress_bar")
    auto_start_next = obs.obs_data_get_bool(settings, "auto_start_next")

    -- Sources
    focus_count_source = obs.obs_data_get_string(settings, "focus_count_source")
    message_source = obs.obs_data_get_string(settings, "message_source")
    time_source = obs.obs_data_get_string(settings, "time_source")
    progress_bar_source = obs.obs_data_get_string(settings, "progress_bar_source")
    background_image_source = obs.obs_data_get_string(settings, "background_image_source")
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

    -- Background images
    focus_background_image = obs.obs_data_get_string(settings, "focus_background_image")
    short_break_background_image = obs.obs_data_get_string(settings, "short_break_background_image")
    long_break_background_image = obs.obs_data_get_string(settings, "long_break_background_image")

    -- Sync display when timer is idle
    if not is_running then
        current_time = focus_duration
        update_display_texts()
    end
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------
function script_load(settings)
    obs.timer_add(timer_tick, 1000)

    -- Register hotkeys
    hotkey_start_pause = obs.obs_hotkey_register_frontend(
        "pomodoro_start_pause", "Pomodoro: Start / Pause", on_hotkey_start_pause)
    hotkey_stop = obs.obs_hotkey_register_frontend(
        "pomodoro_stop", "Pomodoro: Stop", on_hotkey_stop)
    hotkey_skip = obs.obs_hotkey_register_frontend(
        "pomodoro_skip", "Pomodoro: Skip Session", on_hotkey_skip)

    -- Load saved hotkey bindings
    local function load_hotkey(id, key)
        local a = obs.obs_data_get_array(settings, key)
        obs.obs_hotkey_load(id, a)
        obs.obs_data_array_release(a)
    end
    load_hotkey(hotkey_start_pause, "pomodoro_hotkey_start_pause")
    load_hotkey(hotkey_stop, "pomodoro_hotkey_stop")
    load_hotkey(hotkey_skip, "pomodoro_hotkey_skip")

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
end

function script_unload()
    obs.timer_remove(timer_tick)
    obs.obs_hotkey_unregister(hotkey_start_pause)
    obs.obs_hotkey_unregister(hotkey_stop)
    obs.obs_hotkey_unregister(hotkey_skip)
    log("Unloaded")
end
