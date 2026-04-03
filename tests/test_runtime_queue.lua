--[[
    Runtime queue regression tests for SessionPulse.
    These verify that user-triggered controls are deferred out of OBS callbacks
    and executed later in script_tick(), which is the safer execution context.
]]

local pass_count = 0
local fail_count = 0
local test_count = 0
local PATH_SEP = package.config:sub(1, 1)
local TEST_STATE_FILE = "tests" .. PATH_SEP .. "session_state.json"
local TEST_STATE_TMP_FILE = TEST_STATE_FILE .. ".tmp"

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
    local sources = {}

    local function infer_source_id(name)
        if name == "SP Overlay" then
            return "browser_source"
        end
        if name == "SP Background Image" then
            return "image_source"
        end
        if name == "SP Background Video" or name == "SP Background Music" or name == "SP Alert Sound" then
            return "ffmpeg_source"
        end
        return "text_gdiplus"
    end

    local mock = {
        OBS_INVALID_HOTKEY_ID = -1,
        OBS_FRONTEND_EVENT_STREAMING_STARTED = 1,
        OBS_FRONTEND_EVENT_STREAMING_STOPPED = 2,
        OBS_FRONTEND_EVENT_RECORDING_STARTED = 3
    }
    local current_scene = {
        name = "Current Scene",
        items = {}
    }
    local current_scene_source = {
        name = "Current Scene",
        id = "scene",
        scene = current_scene
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

    function mock.obs_data_set_obj(data, key, value)
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
        if not sources[name] then
            sources[name] = {
                name = name,
                id = infer_source_id(name),
                volume = 1.0
            }
        end
        return sources[name]
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

    function mock.obs_source_get_name(source)
        return source.name
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

    function mock.obs_frontend_get_current_scene()
        return current_scene_source
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

    function mock.obs_scene_from_source(source)
        return source and source.scene or nil
    end

    function mock.obs_scene_find_source(scene, source_name)
        return scene and scene.items[source_name] or nil
    end

    function mock.obs_scene_add(scene, source)
        local item = {
            source = source
        }
        scene.items[source.name] = item
        return item
    end

    function mock.obs_sceneitem_set_pos(item, pos)
        item.pos = { x = pos.x, y = pos.y }
    end

    function mock.vec2()
        return { x = 0, y = 0 }
    end

    mock.counters = counters
    mock.sources = sources
    mock.current_scene = current_scene
    return mock
end

local function reset_counters(mock_obs)
    for key in pairs(mock_obs.counters) do
        mock_obs.counters[key] = 0
    end
    mock_obs.last_scene = nil
end

local function cleanup_state_files()
    local file = io.open(TEST_STATE_FILE, "w")
    if file then
        file:write("")
        file:close()
    end

    local tmp_file = io.open(TEST_STATE_TMP_FILE, "w")
    if tmp_file then
        tmp_file:write("")
        tmp_file:close()
    end
end

local function load_runtime(settings, options)
    options = options or {}
    if not options.preserve_state then
        cleanup_state_files()
    end

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
    enable_scene_switching = false,
    focus_scene = "",
    short_break_scene = "",
    long_break_scene = "",
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
    background_music_source_name = "",
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
    long_break_background_media = "",
    focus_background_image = "",
    short_break_background_image = "",
    long_break_background_image = "",
    focus_background_video = "",
    short_break_background_video = "",
    long_break_background_video = "",
    background_music_track_path = ""
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
    test("skip does not switch scenes", mock_obs.counters.frontend_scene_switches == 0)
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
    test("auto-advance does not switch scenes", mock_obs.counters.frontend_scene_switches == 0)
end

section("Resume Previous Session")
do
    local mock_obs, hooks = load_runtime(base_settings)

    fake_now = 1035
    local state_file = io.open(TEST_STATE_FILE, "w")
    state_file:write(table.concat({
        "{",
        '  "version": "5.4.1",',
        '  "timer_mode": "pomodoro",',
        '  "is_running": true,',
        '  "is_paused": false,',
        '  "session_type": "Focus",',
        '  "current_time": 90,',
        '  "cycle_count": 2,',
        '  "completed_focus_sessions": 2,',
        '  "total_focus_seconds": 1500,',
        '  "custom_segment_index": 0,',
        '  "session_epoch": 1000,',
        '  "session_pause_total": 0,',
        '  "session_target_duration": 120,',
        '  "timestamp": 1030',
        "}"
    }, "\n"))
    state_file:close()

    hooks.on_resume_button_clicked(nil, nil)
    script_tick(0.016)

    local resumed = hooks.get_runtime_state()
    test("resume restores running state", resumed.is_running == true)
    test("resume preserves unpaused sessions", resumed.is_paused == false)
    test("resume restores exact saved remaining time", resumed.current_time == 90)
    local progress_source = mock_obs.sources["BarText"]
    local progress_text = progress_source and progress_source.settings and progress_source.settings.text or ""
    local filled_count = select(2, progress_text:gsub("█", ""))
    local empty_count = select(2, progress_text:gsub("░", ""))
    test("resume preserves progress bar position", filled_count == 25 and empty_count == 75)
end

section("Resume State Preservation")
do
    cleanup_state_files()
    local state_file = io.open(TEST_STATE_FILE, "w")
    state_file:write(table.concat({
        "{",
        '  "version": "5.4.1",',
        '  "timer_mode": "pomodoro",',
        '  "is_running": true,',
        '  "is_paused": false,',
        '  "session_type": "Focus",',
        '  "current_time": 90,',
        '  "cycle_count": 2,',
        '  "completed_focus_sessions": 2,',
        '  "total_focus_seconds": 1500,',
        '  "custom_segment_index": 0,',
        '  "session_epoch": 1000,',
        '  "session_pause_total": 0,',
        '  "session_target_duration": 120,',
        '  "timestamp": 1030',
        "}"
    }, "\n"))
    state_file:close()

    load_runtime(base_settings, { preserve_state = true })

    local after_file = io.open(TEST_STATE_FILE, "r")
    local after_content = after_file:read("*all")
    after_file:close()

    test("script_update preserves resumable running state", after_content:find('"is_running": true', 1, true) ~= nil)
    test("script_update preserves saved current time", after_content:find('"current_time": 90', 1, true) ~= nil)
    cleanup_state_files()
end

section("Idle State Persistence")
do
    fake_now = 1000
    local _, hooks = load_runtime(base_settings)

    hooks.on_start_button_clicked(nil, nil)
    script_tick(0.016)
    hooks.on_stop_button_clicked(nil, nil)
    script_tick(0.016)

    local stopped = hooks.get_runtime_state()
    test("stop returns runtime to idle", stopped.is_running == false and stopped.session_type == "Focus")
    test("stop clears completed sessions in runtime", stopped.completed_focus_sessions == 0)
end

section("Starting Session Offset")
do
    cleanup_state_files()
    local settings = {}
    for k, v in pairs(base_settings) do settings[k] = v end
    settings.starting_session_offset = 2

    local mock_obs = load_runtime(settings)
    local count_source = mock_obs.sources["CountText"]
    local count_text = count_source and count_source.settings and count_source.settings.text or ""

    test("offset is visible before first start", count_text == "Done: 2/6")
end

section("Quick Setup Placement")
do
    local mock_obs, hooks = load_runtime(base_settings)

    test("quick setup returns true", hooks.quick_setup(nil, nil) == true)
    test("quick setup places timer in current scene", mock_obs.current_scene.items["SP Timer"] ~= nil)
    test("quick setup places session label in current scene", mock_obs.current_scene.items["SP Session"] ~= nil)
    test("quick setup places count in current scene", mock_obs.current_scene.items["SP Count"] ~= nil)
    test("quick setup places progress in current scene", mock_obs.current_scene.items["SP Progress"] ~= nil)
    test("quick setup places overlay in current scene", mock_obs.current_scene.items["SP Overlay"] ~= nil)
    test("quick setup places background image in current scene", mock_obs.current_scene.items["SP Background Image"] ~= nil)
    test("quick setup places background video in current scene", mock_obs.current_scene.items["SP Background Video"] ~= nil)
    test("quick setup places background music in current scene", mock_obs.current_scene.items["SP Background Music"] ~= nil)
    test("quick setup places alert sound in current scene", mock_obs.current_scene.items["SP Alert Sound"] ~= nil)
end

section("Background Visual Routing")
do
    local settings = {}
    for k, v in pairs(base_settings) do settings[k] = v end
    settings.background_media_source = "SP Background Image"
    settings.focus_background_image = "focus.png"
    settings.short_break_background_image = "break.png"
    settings.background_music_source_name = "SP Background Music"
    settings.background_music_track_path = "music.mp3"

    local mock_obs, hooks = load_runtime(settings)
    hooks.on_start_button_clicked(nil, nil)
    script_tick(0.016)

    local image_source = mock_obs.sources["SP Background Image"]
    local video_source = mock_obs.sources["SP Background Video"]
    local music_source = mock_obs.sources["SP Background Music"]
    test("image mode enables image source", image_source and image_source.enabled == true)
    test("image mode disables video source", video_source and video_source.enabled == false)
    test("image mode applies focus image path", image_source and image_source.settings and image_source.settings.file == "focus.png")
    test("music source starts enabled", music_source and music_source.enabled == true)
    test("music source loads configured track", music_source and music_source.settings and music_source.settings.local_file == "music.mp3")

    hooks.on_stop_button_clicked(nil, nil)
    script_tick(0.016)
    test("music source disables on stop", music_source and music_source.enabled == false)
end

section("Background Video Routing")
do
    local settings = {}
    for k, v in pairs(base_settings) do settings[k] = v end
    settings.background_media_source = "SP Background Video"
    settings.focus_background_video = "focus.mp4"

    local mock_obs, hooks = load_runtime(settings)
    hooks.on_start_button_clicked(nil, nil)
    script_tick(0.016)

    local image_source = mock_obs.sources["SP Background Image"]
    local video_source = mock_obs.sources["SP Background Video"]
    test("video mode disables image source", image_source and image_source.enabled == false)
    test("video mode enables video source", video_source and video_source.enabled == true)
    test("video mode applies focus video path", video_source and video_source.settings and video_source.settings.local_file == "focus.mp4")
end

cleanup_state_files()
os.clock = real_os_clock
os.time = real_os_time

print("\nResults: " .. pass_count .. "/" .. test_count .. " passed, " .. fail_count .. " failed")

if fail_count > 0 then
    os.exit(1)
end
