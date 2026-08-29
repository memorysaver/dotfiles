-- Managed by dotfiles: omarchy-sunshine-headless
-- Opt-in virtual display for a headless Sunshine host.
--
-- Hyprland creates the output when the session starts. The explicit monitor
-- rule keeps Sunshine's capture area at a 16:10 1920x1200 instead of inheriting
-- the workstation's high-DPI fallback scale. A modest 1.25 scale keeps text
-- comfortable on the MacBook clients without sacrificing the 1920x1200 stream.

hl.monitor({
  output = "HEADLESS-1",
  mode = "1920x1200@60",
  position = "0x0",
  scale = 1.25,
})

o.exec_on_start("hyprctl output create headless")
