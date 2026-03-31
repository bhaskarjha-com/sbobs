--[[ 
The provided Lua script is designed to run within OBS Studio, a popular software for video recording and live streaming. The script implements a customizable Pomodoro timer, which helps users manage their work and break intervals effectively. The script begins by checking if it is running in the OBS Studio environment by verifying the presence of the obslua module. If the script is not running within OBS Studio, it prints an error message and terminates.

The script defines several timer variables, including durations for focus sessions, short breaks, and long breaks, as well as the interval for long breaks. It also initializes variables to keep track of the current time, cycle count, session type, and whether the timer is running or paused. Additionally, it sets up various text sources in OBS to display information such as the number of completed focus sessions, the current session message, the timer display, and a progress bar.

The script includes functions to update the background image based on the current session type, format the time for display, and update specific OBS text sources with provided text content. It also defines a function to create a simple progress bar using filled and empty characters. The script updates the OBS text sources with the current timer and session information, including the focus count, session message, time display, and progress bar.

To enhance the user experience, the script plays alert sounds for session transitions and shows transition messages before switching sessions. It includes functions to update the session type, duration, and message, as well as to switch between focus and break sessions. The timer tick function, which is called every second, handles the countdown and session transitions.

The script provides control functions to start, stop, pause, resume, reset, and skip sessions. It also defines the OBS settings UI, allowing users to configure various properties such as alert sound paths, background images, session durations, and transition messages. The script sets default settings and updates the settings based on user input.

Finally, the script includes functions for initialization and cleanup, ensuring that the timer tick function is added and removed appropriately when the script is loaded and unloaded. The script description provides an overview of the Pomodoro timer's features and setup instructions for users.
]]

--[[
Pomodoro Timer Script for OBS Studio

This script implements a customizable Pomodoro timer for OBS Studio. It includes features such as configurable transition messages, adjustable durations for focus, short breaks, and long breaks, visual progress bar, background image updates, and audio alerts.

Features:
- Configurable transition messages for seamless session changes.
- Adjustable durations for focus, short breaks, and long breaks.
- Transition messages and audio alerts.
- Visual progress bar and background image updates.
- Control buttons for start, pause, stop, reset, and skip.

Setup Instructions:
1. Set paths for audio files: Focus Sound, Short Break Sound, Long Break Sound.
2. Set paths for background images: Focus Background Image, Short Break Background Image, Long Break Background Image.
3. Create the following OBS sources:
    - Text Sources: FocusCount, SessionMessage, TimeDisplay, ProgressBar.
    - Image Source: BackgroundImage.
    - Audio Source: AlertSound.

Variables:
- Timer Variables:
    - focus_duration: Duration of focus session in seconds (default 25 mins).
    - short_break_duration: Duration of short break in seconds (default 5 mins).
    - long_break_duration: Duration of long break in seconds (default 15 mins).
    - long_break_interval: Number of focus sessions before a long break.
    - current_time: Current timer value in seconds.
    - cycle_count: Number of completed cycles.
    - is_running: Boolean indicating if the timer is running.
    - is_paused: Boolean indicating if the timer is paused.
    - session_type: Current session type ("Focus", "Short Break", or "Long Break").

- Display Settings:
    - show_progress_bar: Boolean to show/hide progress bar.
    - completed_focus_sessions: Number of completed focus sessions.
    - goal_sessions: Goal number of focus sessions.
    - progress_bar_length: Length of progress bar in characters.
    - show_transition: Boolean to show/hide transition messages.
    - transition_timer: Timer for transition messages.
function script_load(settings)
    - transition_message: Current transition message.

- Background Image Source and Path:
    - background_image_source: Name of the background image source. 1000)
    - focus_background_image: Path to focus background image.
    - short_break_background_image: Path to short break background image.
    - long_break_background_image: Path to long break background image.


- Sound Source and Path:ction script_unload()
    - alert_source_name: Name of the alert sound source.
    - focus_alert_sound_path: Path to focus alert sound.
    - short_break_alert_sound_path: Path to short break alert sound.
    - long_break_alert_sound_path: Path to long break alert sound.
Functions:er_tick)
- update_background_image: Updates the background image based on the current session type.
- format_time: Formats time in MM:SS or HH:MM:SS for longer sessions.- update_obs_source_text: Updates a specific OBS text source with the provided text content.
- create_progress_bar: Creates a simple progress bar with filled and empty parts.
- get_session_message: Returns the current session message.
- update_focus_count: Updates the focus count text source.
- update_session_message: Updates the session message text source.
- update_time_display: Updates the time display text source.
- update_progress_bar: Updates the progress bar text source.
- update_display_texts: Updates all display texts.
- play_alert_sound: Plays an alert sound for session transitions.
- show_transition_message: Shows a transition message before switching sessions.
- update_session: Updates the session type, duration, and message.
- switch_session: Switches to the next session.
- timer_tick: Timer tick function, called every second.
- toggle_pause: Toggles the pause state.
- start_timer: Starts the timer.
- stop_timer: Stops and resets the timer.
- reset_timer: Resets the timer.
- skip_session: Skips the current session and goes to the next one.

OBS Settings UI:
- script_properties: Defines the properties for the OBS settings UI.
- script_defaults: Sets default settings for the script.
- script_update: Updates the script settings.

Initialization and Cleanup:
- script_description: Returns the script description.
- script_load: Initializes the script and starts the timer.
- script_unload: Cleans up the script and stops the timer.
]]

-- Check if the script is running in OBS Studio
obs = obslua

-- Ensure the script is running in OBS Studio environment
if not obs then
    print("This script must be run within OBS Studio.") 
    return
end

-- Timer Variables
local focus_duration = 1500          -- Default 25 mins in seconds
local short_break_duration = 300     -- Default 5 mins in seconds
local long_break_duration = 900      -- Default 15 mins in seconds
local long_break_interval = 4        -- Long break after every 4 focus sessions
local current_time = focus_duration
local cycle_count = 0
local is_running = false
local is_paused = false
local session_type = "Focus"         -- "Focus", "Short Break", or "Long Break"

local show_progress_bar = true
local completed_focus_sessions = 0
local goal_sessions = 6

-- Separate text sources for different elements
local focus_count_source = "FocusCount"           -- Source for completed sessions
local message_source = "SessionMessage"           -- Source for current session message
local time_source = "TimeDisplay"                 -- Source for the timer display
local progress_bar_source = "ProgressBar"         -- Source for the progress bar

-- Timer and Transition Messages
local focus_message = "Focus Time"
local short_break_message = "Short Break"
local long_break_message = "Long Break"
local paused_message = "Paused"
local transition_to_short_break_message = "Time for a short break!"
local transition_to_focus_message = "Back to focus time!"
local transition_to_long_break_message = "Time for a long break!"
local transition_display_time = 2    -- Time (in seconds) to show transition messages

-- Display Settings
local progress_bar_length = 100       -- Length of progress bar in characters
local show_transition = false
local transition_timer = 0
local transition_message = ""

-- Background Image Source and Path
local background_image_source = "BackgroundImage"
local focus_background_image = ""
local short_break_background_image = ""
local long_break_background_image = ""


-- Sound Source and Path
local alert_source_name = "AlertSound"
local focus_alert_sound_path = ""
local short_break_alert_sound_path = ""
local long_break_alert_sound_path = ""

-- Updates the background image based on the current session type
local function update_background_image()
    local image_map = {
        Focus = focus_background_image,
        ["Short Break"] = short_break_background_image,
        ["Long Break"] = long_break_background_image
    }
    local image_path = image_map[session_type]

    if background_image_source ~= "" then
        local source = obs.obs_get_source_by_name(background_image_source)
        if source and image_path then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "file", image_path)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end
end


-- Formats time in MM:SS or HH:MM:SS for longer sessions
local function format_time(seconds)
    if seconds < 0 then seconds = 0 end
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        local minutes = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%02d:%02d", minutes, secs)
    end
end

-- Updates a specific OBS text source with the provided text content
local function update_obs_source_text(source_name, text)
    if source_name == "" then return end
    local source = obs.obs_get_source_by_name(source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

-- Creates a simple progress bar with filled and empty parts
local function create_progress_bar(current, total)
    if not show_progress_bar then return "" end
    local filled_length = math.floor((current / total) * progress_bar_length)
    return string.format("%s%s", string.rep("█", filled_length), string.rep("░", progress_bar_length - filled_length))
end

-- Updates OBS text source with the current timer and session information
local function get_session_message()
    return session_type == "Focus" and focus_message or
           (session_type == "Short Break" and short_break_message or long_break_message)
end

local function update_focus_count()
    update_obs_source_text(focus_count_source, string.format("Done: %d/%d", completed_focus_sessions, goal_sessions))
end

local function update_session_message()
    local message = show_transition and transition_message or get_session_message()
    if is_paused then
        message = message .. " (" .. paused_message .. ")"
    end
    update_obs_source_text(message_source, message)
end

local function update_time_display()
    local time_text = format_time(current_time)
    update_obs_source_text(time_source, time_text)
end

local function update_progress_bar()
    if not show_progress_bar then
        update_obs_source_text(progress_bar_source, "")
        return
    end
    local total_time = session_type == "Focus" and focus_duration or 
                     (session_type == "Short Break" and short_break_duration or long_break_duration)
    local progress_text = create_progress_bar(current_time, total_time)
    update_obs_source_text(progress_bar_source, progress_text)
end

local update_functions = {update_focus_count, update_session_message, update_time_display, update_progress_bar}

local function update_display_texts()
    for _, func in ipairs(update_functions) do func() end
end


-- Plays an alert sound for session transitions
local function play_alert_sound()
    local sound_map = {
        Focus = focus_alert_sound_path,
        ["Short Break"] = short_break_alert_sound_path,
        ["Long Break"] = long_break_alert_sound_path
    }
    local sound_path = sound_map[session_type]
    if not sound_path or sound_path == "" then return end

    local source = obs.obs_get_source_by_name(alert_source_name) or 
                   obs.obs_source_create("ffmpeg_source", alert_source_name, nil, nil)
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

-- Shows a transition message before switching sessions
local function show_transition_message(message)
    transition_message = message
    show_transition = true
    transition_timer = transition_display_time
    update_display_texts()
end

local function update_session(new_type, duration, message)
    session_type = new_type
    current_time = duration
    show_transition_message(message)
    update_background_image()
    play_alert_sound()
end

local function switch_session()
    if session_type == "Focus" then
        completed_focus_sessions = completed_focus_sessions + 1
        cycle_count = cycle_count + 1
        local next_type = (cycle_count % long_break_interval == 0) and "Long Break" or "Short Break"
        local next_duration = (next_type == "Long Break") and long_break_duration or short_break_duration
        local next_message = (next_type == "Long Break") and transition_to_long_break_message or transition_to_short_break_message
        update_session(next_type, next_duration, next_message)
    else
        update_session("Focus", focus_duration, transition_to_focus_message)
    end
end

-- Timer tick function, called every second
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

-- Toggles pause state
local function toggle_pause()
    is_paused = not is_paused
    update_display_texts()
end

-- Starts the timer
local function start_timer()
    if is_running then return end
    is_running, is_paused = true, false
    update_display_texts()
    update_background_image()
end

-- Stops and resets the timer
local function stop_timer()
    is_running, is_paused = false, false
    current_time, cycle_count, session_type, show_transition = focus_duration, 0, "Focus", false
    update_display_texts()
end

function reset_timer()
    stop_timer()
    current_time, cycle_count, completed_focus_sessions, session_type = focus_duration, 0, 0, "Focus"
    update_display_texts()
end

-- Skips the current session and goes to the next one
local function skip_session()
    switch_session()
    start_timer()
end

-- OBS settings UI
function script_properties()
    local props = obs.obs_properties_create()
    
    -- Control Buttons
    obs.obs_properties_add_button(props, "start_button", "Start Timer", start_timer)
    obs.obs_properties_add_button(props, "pause_button", "Pause/Resume Timer", toggle_pause)
    obs.obs_properties_add_button(props, "stop_button", "Stop Timer", stop_timer)
    obs.obs_properties_add_button(props, "skip_button", "Skip to Next Session", skip_session)
    obs.obs_properties_add_button(props, "reset_button", "Reset Timer", reset_timer)

    -- Alert Sounds
    obs.obs_properties_add_path(props, "focus_alert_sound_path", "Focus Sound", obs.OBS_PATH_FILE, "Audio files (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_path(props, "short_break_alert_sound_path", "Short Break Sound", obs.OBS_PATH_FILE, "Audio files (*.mp3 *.ogg *.wav)", nil)
    obs.obs_properties_add_path(props, "long_break_alert_sound_path", "Long Break Sound", obs.OBS_PATH_FILE, "Audio files (*.mp3 *.ogg *.wav)", nil)
    
    -- Background Images
    obs.obs_properties_add_path(props, "focus_background_image", "Focus Background Image", obs.OBS_PATH_FILE, "Image files (*.jpeg *.jpg *.png *.bmp)", nil)
    obs.obs_properties_add_path(props, "short_break_background_image", "Short Break Background Image", obs.OBS_PATH_FILE, "Image files (*.jpeg *.jpg *.png *.bmp)", nil)
    obs.obs_properties_add_path(props, "long_break_background_image", "Long Break Background Image", obs.OBS_PATH_FILE, "Image files (*.jpeg *.jpg *.png *.bmp)", nil)
    
    -- Session Durations
    obs.obs_properties_add_int(props, "focus_duration", "Focus Duration (minutes)", 1, 120, 1)
    obs.obs_properties_add_int(props, "short_break_duration", "Short Break Duration (minutes)", 1, 30, 1)
    obs.obs_properties_add_int(props, "long_break_duration", "Long Break Duration (minutes)", 1, 60, 1)
    obs.obs_properties_add_int(props, "long_break_interval", "Long Break Every (cycles)", 1, 10, 1)

    -- Display Settings
    obs.obs_properties_add_int(props, "goal_sessions", "Goal Sessions", 1, 20, 1)
    obs.obs_properties_add_int(props, "transition_display_time", "Transition Display Time (seconds)", 1, 10, 1)
    obs.obs_properties_add_bool(props, "show_progress_bar", "Show Progress Bar")
    
    -- Transition Messages
    obs.obs_properties_add_text(props, "focus_message", "Focus Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "short_break_message", "Short Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "long_break_message", "Long Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "transition_to_short_break_message", "Transition to Short Break Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "transition_to_focus_message", "Transition to Focus Message", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "transition_to_long_break_message", "Transition to Long Break Message", obs.OBS_TEXT_DEFAULT)

    -- Text Source Names
    obs.obs_properties_add_text(props, "focus_count_source", "Focus Count Source Name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "message_source", "Session Message Source Name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "time_source", "Time Display Source Name", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "progress_bar_source", "Progress Bar Source Name", obs.OBS_TEXT_DEFAULT)    

    return props
end

-- Set default settings
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "goal_sessions", 6)
    obs.obs_data_set_default_int(settings, "focus_duration", 25)
    obs.obs_data_set_default_int(settings, "short_break_duration", 5)
    obs.obs_data_set_default_int(settings, "long_break_duration", 15)
    obs.obs_data_set_default_int(settings, "long_break_interval", 4)
    obs.obs_data_set_default_int(settings, "transition_display_time", 2)
    obs.obs_data_set_default_bool(settings, "show_progress_bar", true)

    obs.obs_data_set_default_string(settings, "focus_message", "Focus Time")
    obs.obs_data_set_default_string(settings, "short_break_message", "Short Break")
    obs.obs_data_set_default_string(settings, "long_break_message", "Long Break")
    obs.obs_data_set_default_string(settings, "transition_to_short_break_message", "Time for a short break!")
    obs.obs_data_set_default_string(settings, "transition_to_focus_message", "Back to focus time!")
    obs.obs_data_set_default_string(settings, "transition_to_long_break_message", "Time for a long break!")

    obs.obs_data_set_default_string(settings, "focus_count_source", "FocusCount")
    obs.obs_data_set_default_string(settings, "message_source", "SessionMessage")
    obs.obs_data_set_default_string(settings, "time_source", "TimeDisplay")
    obs.obs_data_set_default_string(settings, "progress_bar_source", "ProgressBar")

end

function script_update(settings)
    focus_count_source = obs.obs_data_get_string(settings, "focus_count_source")
    message_source = obs.obs_data_get_string(settings, "message_source")
    time_source = obs.obs_data_get_string(settings, "time_source")
    progress_bar_source = obs.obs_data_get_string(settings, "progress_bar_source")

    goal_sessions = obs.obs_data_get_int(settings, "goal_sessions")
    focus_duration = obs.obs_data_get_int(settings, "focus_duration") * 60
    short_break_duration = obs.obs_data_get_int(settings, "short_break_duration") * 60
    long_break_duration = obs.obs_data_get_int(settings, "long_break_duration") * 60
    long_break_interval = obs.obs_data_get_int(settings, "long_break_interval")
    transition_display_time = obs.obs_data_get_int(settings, "transition_display_time")
    focus_alert_sound_path = obs.obs_data_get_string(settings, "focus_alert_sound_path")
    short_break_alert_sound_path = obs.obs_data_get_string(settings, "short_break_alert_sound_path")
    long_break_alert_sound_path = obs.obs_data_get_string(settings, "long_break_alert_sound_path")
    show_progress_bar = obs.obs_data_get_bool(settings, "show_progress_bar")

    focus_message = obs.obs_data_get_string(settings, "focus_message")
    short_break_message = obs.obs_data_get_string(settings, "short_break_message")
    long_break_message = obs.obs_data_get_string(settings, "long_break_message")
    transition_to_short_break_message = obs.obs_data_get_string(settings, "transition_to_short_break_message")
    transition_to_focus_message = obs.obs_data_get_string(settings, "transition_to_focus_message")
    transition_to_long_break_message = obs.obs_data_get_string(settings, "transition_to_long_break_message")

    focus_background_image = obs.obs_data_get_string(settings, "focus_background_image")
    short_break_background_image = obs.obs_data_get_string(settings, "short_break_background_image")
    long_break_background_image = obs.obs_data_get_string(settings, "long_break_background_image")

    if not is_running then stop_timer() end
end

-- Timer description
function script_description()
    return [[
Customizable Pomodoro timer for OBS Studio. Features include: 
- Configurable transition messages for seamless session changes. 
- Adjustable durations for focus, short breaks, and long breaks.
- Transition messages and audio alerts.
- Visual progress bar and background image updates.
- Control buttons for start, pause, stop, reset, and skip.
Setup Instructions:
- Set paths for audio files: Focus Sound, Short Break Sound, Long Break Sound.
- Set paths for background images: Focus Background Image, Short Break Background Image, Long Break Background Image.
- Create the following OBS sources:
    - Text Sources: FocusCount, SessionMessage, TimeDisplay, ProgressBar.
    - Image Source: BackgroundImage.
    - Audio Source: AlertSound.    
]]
end

-- Initialization and cleanup
function script_load(settings)
    script_defaults(settings)
    obs.timer_add(timer_tick, 1000)
end

function script_unload()
    obs.timer_remove(timer_tick)
end
