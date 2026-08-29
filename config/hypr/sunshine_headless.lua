-- Opt-in virtual display for a headless Sunshine host.
--
-- Hyprland creates the output when the session starts. The explicit monitor
-- rule keeps Sunshine's capture area at a native 1920x1080 instead of inheriting
-- the workstation's high-DPI fallback scale.

hl.monitor({
  output = "HEADLESS-1",
  mode = "1920x1080@60",
  position = "0x0",
  scale = 1,
})

o.exec_on_start("hyprctl output create headless")
