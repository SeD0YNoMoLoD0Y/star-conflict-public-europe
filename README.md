# Star Conflict Unofficial Server Kit

Scripts and configuration changes for running a **Star Conflict Unofficial Server** on Windows. We use this kit for the EU Unofficial Server, and it is meant for anyone who wants to host their own.

The official servers shut down on 2026-10-09. Gaijin released the server files and allows unofficial servers on two conditions:
- **no monetization of any kind** (no donations, no paid items, no paid access);
- the server must be labelled **"Unofficial Server"**.

This project is not affiliated with Gaijin or StarGem. Star Conflict and its files belong to their owners. The repo contains only our changes to a few configuration files and our own scripts, not the game itself.

## What you get
- **One-command setup** on a Windows machine (VPS or home PC): copies the game out of the Steam folder, applies the changes, sets the public address and configures the firewall and daily backups.
- **Start, stop and backup** scripts that shut MongoDB down safely.
- **Restart with an in-game countdown**: players get the built-in "maintenance in N minutes" notice and are disconnected cleanly.
- **Gameplay fixes and low-population tuning**:
  - Detonation bots pick up, carry and plant bombs, support their carrier, and retarget when a bomb site is destroyed;
  - broken loot tables fixed;
  - iridium in every battle;
  - PvP and vs-AI pools split by tier;
  - more bots in PvP;
  - GS for wins;
  - easier trading;
  - a softer flood limit.

  Each change is documented, so you can keep it, tune it or revert it.
- **Player messaging**: a login notification, a one-time welcome letter (premium as a gift) and notes on mail, broadcasts and admin tasks.

## Docs
- [docs/SETUP.md](docs/SETUP.md): requirements, installation, ports, first start, updating.
- [docs/CHANGES.md](docs/CHANGES.md): every change against the stock server, with the reason and how to revert it.
- [docs/ADMIN.md](docs/ADMIN.md): restarts, MOTD, mail and broadcasts, admin tasks, the database, regenerating game data.
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md): what doesn't work yet, what we tried, and stock quirks.

## Layout
```
deploy/
  setup.ps1, start.ps1, stop.ps1, backup.ps1   install and run the server
  files/                                      our modified game files, copied over the stock install
  maintenance/                                restart with countdown (Hub SSH console + Node.js)
  welcome.js, welcome-msg.js                  welcome letter and login notification (MongoDB shell)
```

## Our server
EU Unofficial Server (Warsaw): address `57.131.200.242`, port `3801`.
- Website: https://star-conflict-eu-server.mak17.workers.dev
- Discord: https://discord.gg/83YkbJbwxx
- Telegram: https://t.me/star_conflict_europe

Issues and pull requests are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md). If you run your own server with this kit, feel free to tell us.
