# Common computer profiles

Choose the destination computer's owner-declared role, or use the profile named by its private
orchestration entry. These are generic profiles, not a deployment inventory.

- [mac.md](./mac.md): macOS workstation.
- [omarchy-desktop.md](./omarchy-desktop.md): user-facing Omarchy desktop.
- [omarchy-server.md](./omarchy-server.md): Omarchy server workstation.
- [grok-bot.md](./grok-bot.md): Cursor / Grok Bot Debian agent sandbox.

OS evidence identifies the platform. A graphical session does not by itself distinguish a server
workstation from a desktop, and SSH does not change either role. Resolve ambiguity before making
machine-specific changes. Return to the [orchestration entrypoint](../README.md) for task routing.
