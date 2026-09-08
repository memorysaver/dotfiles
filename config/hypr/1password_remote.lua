-- Opt-in visibility for 1Password on a trusted remote desktop.
-- Load after Omarchy defaults. This also permits screenshots and screen sharing
-- to capture 1Password; the rule is not limited to Moonlight or Tailscale.
o.window("^(1[pP]assword)$", { no_screen_share = false })
