# server/ — files that live outside the web root

Everything in the repo root is the website (copy it to your web root, e.g. `/var/www`).
This folder holds the pieces that belong **elsewhere on the server**. They are copies of the
files running on the reference deployment (a Raspberry Pi 3B with DietPi / Debian 13), and
are **not** served by the web server — don't copy `server/` into the web root.

| File in repo | Goes to | What it is |
|---|---|---|
| `bin/auto_shutdown.sh` | `/usr/local/bin/auto_shutdown.sh` | auto-shutdown daemon |
| `systemd/auto_shutdown.service` | `/etc/systemd/system/auto_shutdown.service` | runs the daemon at boot |
| `bin/fake-ps4` | `/usr/local/bin/fake-ps4` | PS4 simulator for testing the hub without a console |
| `nginx/default` | `/etc/nginx/sites-available/default` | nginx site (PHP, `.pkg` range downloads, `/packages/` listing, 404 page) |
| `dnsmasq/ps4-lan.conf` | `/etc/dnsmasq.d/ps4-lan.conf` | DHCP for the isolated PS4 network on `eth0` |
| `maintenance/pull-to-local.sh` | `/opt/pull-to-local.sh` | pulls this repo and applies it over the live web root |

All commands below run as root (prefix with `sudo` otherwise), from the repo checkout.

## Packages needed

```sh
apt install nginx php-fpm curl netcat-openbsd git dnsmasq rsync
```

PHP must have the `sockets` extension (`php -m | grep sockets`) — `console_ip.php` uses it
to find the PS4 on the network. `git` is only needed for the in-page **Update** button,
`dnsmasq` only if the server hands out addresses on a dedicated PS4 network.

## Auto-shutdown

When the hub's **Auto server shutdown** checkbox is ticked, the daemon powers the server off
5 minutes after the GoldHEN payloader starts answering on port 9090 on the console. It finds
the console by calling the hub's own `console_ip.php` (so the web server must be running).
Unticking the box during those 5 minutes cancels the shutdown.

```sh
# the daemon and the unit file
install -m 755 -o root -g root server/bin/auto_shutdown.sh /usr/local/bin/auto_shutdown.sh
install -m 644 -o root -g root server/systemd/auto_shutdown.service /etc/systemd/system/auto_shutdown.service

# state directory: the web server (www-data) writes the checkbox flag and the console IP here
mkdir -p /etc/luckfox-hub
chown root:www-data /etc/luckfox-hub
chmod 775 /etc/luckfox-hub

# start it now and at every boot
systemctl daemon-reload
systemctl enable --now auto_shutdown

# check
systemctl status auto_shutdown
journalctl -u auto_shutdown -f
```

Keep the unit file at mode `644` (root-owned, not writable by others). The service runs as
root, so a unit file other users can edit is a way to get root.

Stop it with `systemctl disable --now auto_shutdown`. The daemon logs in Romanian.

**Before relying on it:** after a real `poweroff`, a Raspberry Pi only starts again when its
power is unplugged and plugged back in (it has no suspend, and Wake-on-LAN doesn't work
after a full halt on the Pi 3). A smart plug is the usual way to power it back on remotely.

## fake-ps4 (testing)

Pretends to be a PS4 on the server itself, so you can see the hub react without a console.
It answers the PS4 discovery broadcast (UDP 987) with the server's own IP.

```sh
install -m 755 -o root -g root server/bin/fake-ps4 /usr/local/bin/fake-ps4

fake-ps4                 # console on        -> IP next to FW on the hub
fake-ps4 standby         # rest mode         -> IP shown dimmed
fake-ps4 goldhen         # on + port 9090    -> GoldHEN badge turns green
fake-ps4 goldhen 120 --fw=11.00   # 120 s, reports firmware 11.00 (default 300 s, 13.00)
```

Run it on the server (over SSH is fine). A simulator on another machine won't work, because
the hub looks for the console on the server's own local networks. Ctrl+C stops it and
cleans up. It refuses the `goldhen` mode while the auto-shutdown checkbox is ticked,
since the fake GoldHEN would otherwise shut the server down.

## nginx

`nginx/default` is written for DietPi, where `/etc/nginx/nginx.conf` already defines
`upstream php { server unix:/run/php/php-fpm.sock; }` and a `sites-dietpi` include
directory. On plain Debian/Ubuntu, replace `fastcgi_pass php;` with your PHP-FPM socket
(for example `fastcgi_pass unix:/run/php/php8.4-fpm.sock;`) and drop the
`include /etc/nginx/sites-dietpi/*.conf;` line.

```sh
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
install -m 644 server/nginx/default /etc/nginx/sites-available/default
nginx -t && systemctl reload nginx
```

The update button (`update_payload.php`) replaces folders under `payloads/`, so the web
server user needs write access there:

```sh
chown www-data:www-data /var/www /var/www/payloads
chown -R www-data:www-data /var/www/payloads
```


**Any-path fallback:** `location /` falls back to `index.html` for any unmatched path, not a 404. This is what lets the hub open from the PS4 without the browser app: point the console's network proxy at this server, then Settings → System → User's Guide sends a request through it for a fixed Sony URL whose exact path varies by firmware — the catch-all means whatever path it asks for still opens the hub. The trade-off: a genuinely broken link under the site (e.g. a missing image) also silently serves the hub instead of a real 404.

## dnsmasq (optional — dedicated PS4 network)

The reference setup gives the PS4 its own Ethernet segment with no internet:
the server's `eth0` is `10.1.1.1/24` with no gateway, IP forwarding is off, and dnsmasq
hands the PS4 an address from `10.1.1.2–10.1.1.200`. Adjust `interface=` / the range to
your network, and uncomment the `dhcp-host=` line with your PS4's MAC to pin it to `.2`.

```sh
install -m 644 server/dnsmasq/ps4-lan.conf /etc/dnsmasq.d/ps4-lan.conf
dnsmasq --test && systemctl enable --now dnsmasq
```

## pull-to-local.sh (maintenance)

Used on the reference server to apply changes made on GitHub: it runs `git pull` in the
repo checkout (`/opt/ps4hub-sync`) and copies the site over `/var/www` without deleting
anything, leaving `server/`, the per-payload git checkouts and local `.pkg` files alone.
Edit `SYNC_DIR` / `WWW_DIR` at the top for your paths.

```sh
install -m 755 server/maintenance/pull-to-local.sh /opt/pull-to-local.sh
/opt/pull-to-local.sh
```
