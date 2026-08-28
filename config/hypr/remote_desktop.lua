-- Moonlight remote-desktop mode for an Omarchy/Hyprland client.
--
-- Omarchy's Hyprland configuration is Lua on current releases.  This module
-- is intentionally additive: it is required from the host-owned
-- ~/.config/hypr/bindings.lua instead of replacing any Omarchy config.
--
-- The submap temporarily disables the normal local bindings so Super,
-- Alt+Tab, and other shortcuts can reach the focused Moonlight stream.  The
-- escape hatch remains available while input capture is active.

local remote_desktop_submap = "moonlight_remote_desktop"
local moonlight_class = "com.moonlight_stream.Moonlight"

-- Moonlight uses the Wayland keyboard-shortcuts-inhibit protocol when
-- "Capture system keyboard shortcuts" is set to Always.  Without this rule,
-- Hyprland can keep suppressing local bindings after the submap is reset.
-- Ignore that inhibitor for Moonlight; the submap below still controls which
-- bindings are available while remote-desktop mode is active.
hl.window_rule({
  name = "moonlight-allow-local-shortcuts",
  match = { class = moonlight_class },
  no_shortcuts_inhibit = true,
})

local function notify(message)
  hl.dispatch(hl.dsp.exec_cmd(o.notify(message)))
end

hl.bind("SUPER + F12", function()
  hl.dispatch(hl.dsp.submap(remote_desktop_submap))
  notify("Remote Desktop Mode ON — Super+F12 to exit")
end, {
  description = "Enter Moonlight remote-desktop mode",
  dont_inhibit = true,
  allow_input_capture = true,
})

hl.define_submap(remote_desktop_submap, function()
  -- Keep only the escape hatch in this submap.  Other keys are unbound here
  -- and therefore pass through to the focused Moonlight window.
  hl.bind("SUPER + F12", function()
    hl.dispatch(hl.dsp.submap("reset"))
    notify("Remote Desktop Mode OFF")
  end, {
    description = "Exit Moonlight remote-desktop mode",
    dont_inhibit = true,
    allow_input_capture = true,
  })
end)
