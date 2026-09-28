-- Opt-in visibility for 1Password on a trusted remote desktop.
-- Load after Omarchy defaults. This also permits screenshots and screen sharing
-- to capture 1Password; the rule is not limited to Moonlight or Tailscale.
-- 1Password 8.12 renamed its app id to com.onepassword.OnePassword; match both like Omarchy's default rule.
o.window("^(1[pP]assword|com\\.onepassword\\.OnePassword)$", { no_screen_share = false })
