# ps4hub

A self-hosted, local-network webserver that acts as a **central hub for PS4 WebKit-based jailbreak exploits** — a single landing page for a PS4 to reach on an isolated LAN, offering several known WebKit exploit chains, GoldHEN status, and a package installer, without the console ever needing internet access.

This repo is a **synced mirror** of a working local deployment (nginx + PHP-FPM on a Raspberry Pi). It's meant to be cloned onto your own local server, not run as a public website — the PS4 connects to it over a private, isolated network segment with no internet access, by design.

## What it does

- **Hub / RawGame** — the primary exploit entry point (WebKit jailbreak + payload serving).
- **Payloads** — a rail of alternative exploit chains (WebKitty, raw13g, PSPULSE, polpNO) for when the primary one doesn't work on a given firmware.
- **Packages** — a `.pkg` installer page for sideloading homebrew/games directly from the console's browser. Left empty in this repo — see [`packages/README.md`](packages/README.md).
- **Online** — links out to the internet-hosted versions of the same exploits, as a fallback if the local server isn't reachable.
- **Readme** — network setup instructions, the auto-shutdown daemon toggle, and an update checker that shows each exploit source's status against its upstream GitHub repo (and can update it in place via `git pull`/`git clone`).

## Structure

```
index.html, readme.html, payloads.html, online.html, packages.html, 404.html
    the site itself (single-file bundled pages)
meta/*.json
    editable text/config for each page (labels, tile order, tracked update sources)
payloads/
    the actual exploit sources — see Credits below, each is a full copy of its
    own upstream repo so the whole hub works with zero internet access
packages/
    intentionally empty in this repo, see packages/README.md
*.php
    GoldHEN/shutdown status endpoints, and the update-checker backend
    (list_sources.php, update_payload.php, sources_lib.php)
```

## Credits

The actual exploit chains are not original work — full credit to their authors. Each is vendored here as a complete local copy (not a submodule) so the hub keeps working with **no internet access** once deployed, which is the whole point of running it on an isolated PS4-only network.

| Source | Repo | Firmware / notes |
|---|---|---|
| RawGame | [gomgo-github/PS4-13.00-Webkit-Jelbrek](https://github.com/gomgo-github/PS4-13.00-Webkit-Jelbrek) | PS4 11.50–13.00 |
| WebKitty | [ArabPixel/WebKitty](https://github.com/ArabPixel/WebKitty) | Alternative exploit, useful when RawGame doesn't land |
| raw13g | [raw13g/raw13g.github.io](https://github.com/raw13g/raw13g.github.io) | |
| PSPULSE (psx8 pulse) | [psx8/psx8.github.io](https://github.com/psx8/psx8.github.io) | Multi-firmware payload sets (505/672/700/900/1300) |
| polpNO | [mansoor0x/polpNO-use](https://github.com/mansoor0x/polpNO-use) | |

If you're one of the authors above and want your work removed or credited differently, please open an issue.

## Self-hosting

Requires nginx + PHP-FPM. The hub is designed to run on a second network interface with **no route to the internet** — the PS4 should never be able to reach anything but this server. See `readme.html` (served by the hub itself) for the network setup this was built against.

The update checker (in `readme.html`) discovers tracked sources from `meta/readme.json`'s `updateDirs` list — each entry is a folder containing a `.url` shortcut pointing at its GitHub repo. Add a new folder + `.url` file and list it in `updateDirs` to track another source; delete the entry to stop tracking it.
