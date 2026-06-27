------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
------------------
---- AUTOSTART ----
-------------------
------------------
---- AUTOSTART ----
-------------------
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function () 
    -- Chaining them in a single shell invocation ensures they execute sequentially in the correct environment
    hl.exec_cmd("swaybg -i /home/solar/Downloads/wallhaven-jevokm_1920x1080.png & waybar & swaync & hypridle")
end)
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
--- ------------------
--- KEYBINDINGS 
--- ------------------
-- Note: Keybinds must use hl.bind instead of hl.exec_cmd.
 
-- For hardware switch hooks, use the explicit prefix names directly:
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("swaylock"), { locked = true })

-- For brightness control keys, ensure there are no commas separating the keysym:
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })
