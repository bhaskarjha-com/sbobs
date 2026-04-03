--[[
    Runtime queue regression tests for SessionPulse.
    These verify that user-triggered controls are deferred out of OBS callbacks
    and executed later in script_tick(), which is the safer execution context.
]]

local pass_count = 0
local fail_count = 0
local test_count = 0

local function test(name, condition)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  PASS " .. name)
    else
        fail_count = fail_count + 1
        print("  FAIL " .. name)
    end
end

local function section(name)
    print("\n== " .. name .. " ==")
end

local function make_mock_obs()
    local counters = {
        get_source_by_name = 0,
        source_updates = 0,
        frontend_scene_switches = 0,
        source_releases = 0,
        data_creates = 0,
        data_releases = 0
    }

    local mock = {
        OBS_INVALID_HOTKEY_ID = -1,
        OBS_FRONTEND_EVENT_STREAMING_STARTED = 1,
        OBS_FRONTEND_EVENT_STREAMING_STOPPED = 2,
        OBS_FRONTEND_EVENT_RECORDING_STARTED = 3
    }

    function mock.obs_data_create()
        counters.data_creates = counters.data_creates + 1
        return {}
    end

    function mock.obs_data_release(data)
        counters.data_releases = counters.data_releases + 1
    end

    function mock.obs_data_set_string(data, key, value)
        data[key] = value
    end

    function mock.obs_data_set_bool(data, key, value)
        data[key] = value
    end

    function mock.obs_data_set_int(data, key, value)
        data[key] = value
    end

    function mock.obs_data_get_string(data, key)
        return data[key] or ""
    end

    function mock.obs_data_get_bool(data, key)
        return data[key] or false
    end

    function mock.obs_data_get_int(data, key)
        return data[key] or 0
    end

    function mock.obs_get_source_by_name(name)
        counters.get_source_by_name = counters.get_source_by_name + 1
        return {
            name = name,
            id = "text_gdiplus",
            volume = 1.0
        }
    end

    function mock.obs_source_release(source)
        counters.source_releases = counters.source_releases + 1
    end

    function mock.obs_source_update(source, settings)
        counters.source_updates = counters.source_updates + 1
        source.settings = settings
    end

    function mock.obs_source_get_id(source)
        return source.id
    end

    function mock.obs_source_media_restart(source)
    end

    function mock.obs_source_set_muted(source, muted)
        source.muted = muted
    end

    function mock.obs_source_set_enabled(source, enabled)
        source.enabled = enabled
    end

    function mock.obs_source_set_volume(source, volume)
        source.volume = volume
    end

    function mock.obs_source_get_volume(source)
        return source.volume or 1.0
    end

    function mock.obs_source_filter_set_enabled(source, filter_name, enabled)
    end

    function mock.obs_source_get_filter_by_name(source, filter_name)
        return { name = filter_name }
    end

    function mock.obs_frontend_recording_active()
        return false
    end

    function mock.obs_frontend_recording_add_chapter(name)
        return true
    end

    function mock.obs_frontend_set_current_scene(source)
        counters.frontend_scene_switches = counters.frontend_scene_switches + 1
        mock.last_scene = source.name
    end

    function mock.obs_frontend_add_event_callback(callback)
    end

    function mock.obs_frontend_remove_event_callback(callback)
    end

    function mock.obs_hotkey_register_frontend(name, description, callback)
        return 1
    end

    function mock.obs_hotkey_unregister(id)
    end

    function mock.obs_data_get_array(data, key)
        return {}
    end

    function mock.obs_hotkey_load(id, array)
    end

    function mock.obs_hotkey_save(id)
        return {}
    end

    function mock.obs_data_set_array(settings, key, array)
    end

    function mock.obs_data_array_release(array)
    end

    function mock.timer_add(callback, milliseconds)
    end

    function mock.timer_remove(callback)
    end

    mock.counters = counters
    return mock
end

local function reset_counters(mock_obs)
    for key in pairs(mock_obs.counters) do
        mock_obs.counters[key] = 0
    end
    mock_obs.last_scene = nil
end

local function cleanup_state_files()
    os.remove("tests/session_state.json")
    os.remove("tests/session_state.json.tmp")
end

local function load_runtime(settings)
    cleanup_state_files()

    _G.__SESSION_PULSE_TEST_HOOKS = {}
    _G.obslua = make_mock_obs()
    _G.script_path = function()
        return "tests/"
    end

    local ok, err = pcall(function()
        dofile("session_pulse.lua")
    end)

    if not ok then
        error("Failed to load session_pulse.lua: " .. tostring(err))
    end

    script_update(settings)
    reset_counters(_G.obslua)

    return _G.obslua, _G.__SESSION_PULSE_TEST_HOOKS
end

local base_settings = {
    timer_mode = "pomodoro",
    focus_duration = 25,
    short_break_duration = 5,
    long_break_duration = 15,
    long_break_interval = 4,
    goal_sessions = 6,
    transition_display_time = 2,
    show_progress_bar = true,
    auto_start_next = true,
    progress_bar_length = 10,
    countdown_duration = 25,
    custom_intervals_text = "",
    starting_session_offset = 0,
    enable_overtime = false,
    enable_warning_alerts = false,
    warning_5min_enabled = true,
    warning_1min_enabled = true,
    warning_break_end_enabled = true,
    warning_break_end_seconds = 30,
    enable_session_log = false,
    auto_start_on_stream = false,
    auto_stop_on_stream_end = false,
    enable_chapter_markers = false,
    enable_scene_switching = true,
    focus_scene = "FocusScene",
    short_break_scene = "BreakScene",
    long_break_scene = "LongScene",
    enable_mic_control = false,
    mute_mic_during_focus = true,
    mic_source_name = "",
    hide_during_focus_source = "",
    volume_source_name = "",
    focus_volume = 30,
    break_volume = 80,
    enable_volume_fade = false,
    daily_goal_minutes = 0,
    filter_source_name = "",
    focus_filters_enable = "",
    focus_filters_disable = "",
    break_suggestions_text = "",
    focus_count_source = "CountText",
    message_source = "MessageText",
    time_source = "TimeText",
    progress_bar_source = "BarText",
    background_media_source = "",
    alert_source_name = "",
    focus_message = "Focus Time",
    short_break_message = "Short Break",
    long_break_message = "Long Break",
    paused_message = "Paused",
    transition_to_focus_message = "Back to focus time!",
    transition_to_short_break_message = "Time for a short break!",
    transition_to_long_break_message = "Time for a long break!",
    focus_alert_sound_path = "",
    short_break_alert_sound_path = "",
    long_break_alert_sound_path = "",
    focus_background_media = "",
    short_break_background_media = "",
    long_break_background_media = ""
}

local real_os_clock = os.clock
local real_os_time = os.time
local fake_now = 1000
os.clock = function()
    return 1
end
os.time = function()
    return fake_now
end

section("Button Callback Queue")
do
    local mock_obs, hooks = load_runtime(base_settings)
    local initial = hooks.get_runtime_state()

    test("initial state is idle", initial.is_running == false and initial.session_type == "Focus")
    test("skip button returns true", hooks.on_skip_button_clicked(nil, nil) == true)
    test("skip button only queues work", hooks.get_pending_control_count() == 1)
    test("skip button does not touch OBS sources immediately", mock_obs.counters.get_source_by_name == 0)
    test("skip button does not switch scenes immediately", mock_obs.counters.frontend_scene_switches == 0)

    script_tick(0.016)
    local after = hooks.get_runtime_state()

    test("queue drained after script_tick", hooks.get_pending_control_count() == 0)
    test("skip executed during script_tick", after.is_running == true and after.session_type == "Short Break")
    test("skip updated OBS sources when processed", mock_obs.counters.get_source_by_name > 0)
    test("skip switched to break scene after processing", mock_obs.counters.frontend_scene_switches == 1 and mock_obs.last_scene == "BreakScene")
end

section("Frontend Event Queue")
do
    local settings = {}
    for k, v in pairs(base_settings) do settings[k] = v end
    settings.auto_start_on_stream = true

    local mock_obs, hooks = load_runtime(settings)

    hooks.on_frontend_event(mock_obs.OBS_FRONTEND_EVENT_STREAMING_STARTED)
    test("frontend event queues start", hooks.get_pending_control_count() == 1)
    test("frontend event does not start immediately", hooks.get_runtime_state().is_running == false)

    script_tick(0.016)
    local after = hooks.get_runtime_state()

    test("frontend start executes in script_tick", after.is_running == true and after.session_type == "Focus")
    test("frontend start performs deferred OBS updates", mock_obs.counters.get_source_by_name > 0)
end

section("Automatic Transition Queue")
do
    local settings = {}
    for k, v in pairs(base_settings) do settings[k] = v end
    settings.focus_duration = 1
    settings.short_break_duration = 5

    fake_now = 1000
    local mock_obs, hooks = load_runtime(settings)

    hooks.on_start_button_clicked(nil, nil)
    script_tick(0.016)
    reset_counters(mock_obs)

    fake_now = 1061
    hooks.timer_tick()

    test("timer expiry queues auto-advance", hooks.get_pending_control_count() == 1)
    test("timer expiry does not switch scenes immediately", mock_obs.counters.frontend_scene_switches == 0)
    test("timer expiry leaves current session unchanged until script_tick", hooks.get_runtime_state().session_type == "Focus")

    script_tick(0.016)
    test("auto-advance executes during script_tick", hooks.get_runtime_state().session_type == "Short Break")
    test("auto-advance switches scene during script_tick", mock_obs.counters.frontend_scene_switches == 1 and mock_obs.last_scene == "BreakScene")
end

cleanup_state_files()
os.clock = real_os_clock
os.time = real_os_time

print("\nResults: " .. pass_count .. "/" .. test_count .. " passed, " .. fail_count .. " failed")

if fail_count > 0 then
    os.exit(1)
end
