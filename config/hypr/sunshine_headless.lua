-- Managed by dotfiles: omarchy-sunshine-headless
-- Opt-in virtual display for a headless Sunshine host.
--
-- Hyprland creates the output when the session starts. The explicit monitor
-- rule keeps Sunshine's capture area at a 16:10 1920x1200 instead of inheriting
-- the workstation's high-DPI fallback scale. Scale 1.25 keeps text comfortable
-- on MacBook clients while preserving the 1920x1200 stream.

hl.monitor({
  output = "HEADLESS-1",
  mode = "1920x1200@60",
  position = "0x0",
  scale = 1.25,
})

o.exec_on_start("hyprctl output create headless")
