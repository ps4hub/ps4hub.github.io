# ps4hub

A self-hosted, local-network webserver that acts as a **central hub for PS4 WebKit-based jailbreak exploits** — a single landing page for a PS4 to reach on an isolated LAN, offering several known WebKit exploit chains, GoldHEN status, and a package installer, without the console ever needing internet access.

This repo is a **synced mirror** of a working local deployment (nginx + PHP-FPM on a Raspberry Pi). It's meant to be cloned onto your own local server, not run as a public website — the PS4 connects to it over a private, isolated network segment with no internet access, by design.

## What it does

- **Hub** — a controller-friendly rail: Packages · Payloads · **RawGame** · Online · Info, with RawGame (the primary exploit) selected in the middle. The top bar shows the console's firmware, its IP when one is detected on the network, and a live GoldHEN status badge.
- **Two languages** — Romanian (default) and English, switched with the flag buttons on the hub; the choice is remembered in the browser and applies to every page.
- **Payloads** — a rail of alternative exploit chains (PSPULSE, **WebKitty**, polpNO/mansoor0x, raw13g), WebKitty selected by default.
- **Packages** — a `.pkg` installer page for sideloading homebrew/games directly from the console's browser. Left empty in this repo — see [`packages/README.md`](packages/README.md).
- **Online** — links out to the internet-hosted versions of the same exploits, as a fallback if the local server isn't reachable (rawgame selected by default).
- **Info** — an update checker showing each exploit source's status against its upstream GitHub repo (commit + date per source, updatable in place via `git pull`/`git clone`), how the auto-shutdown works, and links to the ConsoleMods wiki.

## Structure

```
index.html, info.html, payloads.html, online.html, packages.html, 404.html
    the site itself (single-file bundled pages)
meta/<page>.json, meta/<page>.en.json
    editable text/config for each page, Romanian and English
    (labels, tile order, the "main" tile, tracked update sources) — see meta/README.txt
payloads/
    the actual exploit sources — see Credits below, each is a full copy of its
    own upstream repo so the whole hub works with zero internet access
packages/
    intentionally empty in this repo, see packages/README.md
*.php
    console_ip.php      finds the PS4 on the server's networks (PS4 Device Discovery
                        on UDP 987, or a DHCP lease) and reports its IP, name and firmware
    goldhen_status.php  checks whether the GoldHEN payloader answers on port 9090
    shutdown_*.php      the hub's auto-shutdown checkbox
    list_sources.php, update_payload.php, sources_lib.php
                        the update-checker backend
```

## Credits

The actual exploit chains are not original work — full credit to their authors. Each is vendored here as a complete local copy (not a submodule) so the hub keeps working with **no internet access** once deployed, which is the whole point of running it on an isolated PS4-only network.

| Source | Repo | Firmware / notes |
|---|---|---|
| RawGame | [gomgo-github/PS4-13.00-Webkit-Jelbrek](https://github.com/gomgo-github/PS4-13.00-Webkit-Jelbrek) | PS4 11.50–13.00 |
| WebKitty | [ArabPixel/WebKitty](https://github.com/ArabPixel/WebKitty) | PS4 6.70–13.52 |
| raw13g | [raw13g/raw13g.github.io](https://github.com/raw13g/raw13g.github.io) | PS4 13.02–13.52 |
| PSPULSE (psx8 pulse) | [psx8/psx8.github.io](https://github.com/psx8/psx8.github.io) | PS4 5.05–13.00 |
| polpNO | [mansoor0x/polpNO-use](https://github.com/mansoor0x/polpNO-use) | PS4 9.00–13.52 |

If you're one of the authors above and want your work removed or credited differently, please open an issue.

## Self-hosting

Requires nginx + PHP-FPM (with the `sockets` extension, used for console detection). The hub is designed to run on a second network interface with **no route to the internet** — the PS4 should never be able to reach anything but this server.

The update checker (on `info.html`) discovers tracked sources from `meta/info.json`'s `updateDirs` list — each entry is a folder containing a `.url` shortcut pointing at its GitHub repo. Add a new folder + `.url` file and list it in `updateDirs` to track another source; delete the entry to stop tracking it.

The auto-shutdown daemon itself (a small shell script run as a systemd service, which powers the server off a few minutes after GoldHEN appears on port 9090 when the hub's checkbox is ticked) lives outside the web root and is not part of this repo.

On the static GitHub Pages mirror there is no PHP, so console detection, the GoldHEN badge, auto-shutdown and the in-place **Update** button don't work there — the pages and the update-status check (which runs in the browser against the GitHub API) do.
