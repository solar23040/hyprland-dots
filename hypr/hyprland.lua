-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Hyprland Lua config for solar                            --
-- https://wiki.hypr.land/Configuring/                      --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Primary 4K display on the right; laptop panel is placed to its left.
hl.monitor({
    output   = "DP-1",
    mode     = "3840x2160@60",
    position = "0x0",
    scale    = 1,
})
hl.monitor({
    output   = "DP-2",
    mode     = "3840x2160@60",
    position = "0x0",
    scale    = 1,
})
-- Laptop panel: always sits to the left of the external monitor, so
-- moving the cursor past the left edge of the monitor lands on it.
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto-left",
    scale    = 1,
})
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use (only installed apps).
local terminal    = "alacritty"
local fileManager = "dolphin"
local menu        = "rofi -show drun"
local browser     = "brave-origin"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar &")
    hl.exec_cmd("hyprpaper &")
    hl.exec_cmd("sleep 1 && waypaper --restore")
    -- Manual rotation only: Super+I controls eDP-1; auto-rotate is disabled.
    hl.exec_cmd("sleep 1 && /home/solar/.config/hypr/scripts/screen-invert.sh apply")
    hl.exec_cmd("/home/solar/.config/hypr/scripts/desktop-clock.py &")
    hl.exec_cmd("qs -d -n -c brightness")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
end)

-- Keep the saved laptop-panel rotation after Hyprland reapplies monitor config.
local function restore_screen_orientation()
    hl.exec_cmd("/home/solar/.config/hypr/scripts/screen-invert.sh apply")
end

hl.on("config.reloaded", restore_screen_orientation)
hl.on("monitor.added", restore_screen_orientation)
hl.on("monitor.removed", restore_screen_orientation)
hl.on("monitor.layout_changed", restore_screen_orientation)

-------------------
---- OSD POPUPS ----
-------------------

-- Popup whenever the active workspace changes
hl.on("workspace.active", function(ws)
    local text = "Workspace shifted to " .. ws.name
    if ws.special then
        text = "Scratchpad: " .. (ws.name:match("^special:(.+)$") or ws.name)
    end
    hl.notification.create({ text = text, timeout = 1500, color = "rgb(b4befe)", icon = 5 })
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- hl.config({
--     ecosystem = { enforce_permissions = true },
-- })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 5,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
-- Opening windows: long duration, but an ease-out curve so the first ~30%
-- of the animation does most of the work -> looks unhurried but reacts fast.
-- The terminal gets an even subtler style via a window rule further down.
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 7.0,  bezier = "easeOutQuint", style = "popin 95%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 5.2,  bezier = "easeOutQuint", style = "popin 97%" })
hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 5.8,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 7.0,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 5.2,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
-- Workspace switches: short slide + cross-fade. 20% keeps it subtle;
-- raise to 40-50% for a more pronounced swipe, lower to 10% for almost pure fade.
hl.animation({ leaf = "workspaces",     enabled = true,  speed = 3.2,  bezier = "easeInOutCubic", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesIn",   enabled = true,  speed = 3.2,  bezier = "easeInOutCubic", style = "slidefade 20%" })
hl.animation({ leaf = "workspacesOut",  enabled = true,  speed = 3.2,  bezier = "easeInOutCubic", style = "slidefade 20%" })
-- Scratchpad / dropdown terminal: drop down and fade, quick enough to feel instant.
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 2.4, bezier = "easeOutQuint", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2.4, bezier = "easeOutQuint", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.0, bezier = "easeOutQuint", style = "slidefadevert 15%" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only" - uncomment to use.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

hl.config({
    debug = {
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing  = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Example per-device config
-- hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/dropdown-alacritty.sh")) -- floating dropdown terminal
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager .. " ~"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("pkill -x waybar; sleep 0.2; waybar &")) -- restart waybar
hl.bind("CTRL + EQUAL", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/monitor-scale.sh up"), { repeating = true }) -- scale focused monitor up
hl.bind("CTRL + MINUS", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/monitor-scale.sh down"), { repeating = true }) -- scale focused monitor down
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu)) -- rofi app launcher
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/wallpaper-cycle.sh next")) -- cycle wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/wallpaper-rofi.sh")) -- fast wallpaper selector
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/screen-invert.sh")) -- invert laptop screen
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/power-menu.sh"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("/opt/brave-origin-bin/brave-origin --profile-directory=Default --app-id=lodlkdfmihgonocnmddehnfgiljnadcf")) -- open X webapp
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/lock.sh"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Multimedia (volume + playerctl; brightness via systemd-logind, no root needed)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- Screen brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/brightness.sh up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/brightness.sh down"), { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Screenshots (grim + slurp + wl-clipboard): saved to ~/Pictures/Screenshots + clipboard
hl.bind("Print",         hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/screenshot.sh region"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/screenshot.sh window"), { locked = true })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("/home/solar/.config/hypr/scripts/screenshot.sh full"),   { locked = true })
--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Float common dialogs
hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Open|Save|Save As|File Upload).*$" },
    float = true,
})

-- Terminal open/close: nearly pure fade, barely any zoom. The global
-- windowsIn/windowsOut timing still applies, so this stays in sync.
-- Matches both Alacritty and the AlacrittyDropdown scratchpad.
hl.window_rule({
    name      = "alacritty-smooth-animation",
    match     = { class = "^Alacritty" },
    animation = "popin 98%",
})

-- Floating dropdown terminal (Super+Shift+Enter)
hl.window_rule({
    name  = "dropdown-alacritty",
    match = { class = "^AlacrittyDropdown$" },
    float     = true,
    size      = { "(monitor_w)", "(monitor_h*0.4)" },
    move      = { 0, 0 },
    workspace = "special:dropdown",
})

----------------------------------
---------- LAYER RULES -----------
----------------------------------

-- Frosted glass for waybar: blur the layer while the panel
-- stays translucent (see window#waybar alpha in style.css).
hl.layer_rule({
    name  = "waybar-blur",
    match = { namespace = "waybar.*" },
    blur  = true,
    ignore_alpha = 0.2,
})
