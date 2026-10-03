#!/bin/bash
# At boot: download GoldHEN cheats from GitHub, then copy new/changed ones to the PS4 over FTP.
REPO=https://github.com/GoldHEN/GoldHEN_Cheat_Repository.git
DIR=/opt/ps4-cheats; SRC=$DIR/repo; MAN=$DIR/uploaded.list; CUR=$DIR/current.list; TODO=$DIR/todo.list
PORT=2121; WAIT_NET=900; WAIT_PS4=43200
log() { echo "$(date '+%F %T') $*"; }
mkdir -p "$DIR"; touch "$MAN"

# 1) GitHub (retry while WiFi/DNS come up)
t0=$(date +%s)
until { if [ -d "$SRC/.git" ]; then git -C "$SRC" fetch -q --depth 1 origin main && git -C "$SRC" reset -q --hard FETCH_HEAD
        else rm -rf "$SRC"; git clone -q --depth 1 "$REPO" "$SRC"; fi; }; do
  [ $(( $(date +%s) - t0 )) -gt $WAIT_NET ] && { log "GitHub unreachable, giving up"; exit 1; }
  log "GitHub not reachable yet, retrying"; sleep 15
done
REV=$(git -C "$SRC" rev-parse --short HEAD); log "cheats repo at $REV"

# 2) What is new vs. what the console already received
git -C "$SRC" ls-files -s -- json mc4 shn | awk -F'\t' '{split($1,a," "); print a[2] "\t" $2}' | sort > "$CUR"
sort "$MAN" | comm -23 "$CUR" - > "$TODO"
N=$(wc -l < "$TODO"); log "$(wc -l < "$CUR") cheat files in repo, $N to send"
[ "$N" -eq 0 ] && { log "console already up to date"; exit 0; }

# 3) Wait for the console (GoldHEN FTP), then upload
t0=$(date +%s)
while :; do
  IP=$(cat /etc/luckfox-hub/ps4_ip 2>/dev/null); IP=${IP:-10.1.1.10}
  if timeout 3 bash -c "echo > /dev/tcp/$IP/$PORT" 2>/dev/null; then
    log "console $IP:$PORT is up, uploading"
    php /usr/local/bin/ps4-cheats-upload.php "$IP" "$PORT" "$TODO" "$SRC" "$MAN" && { log "done"; exit 0; }
    sort "$MAN" | comm -23 "$CUR" - > "$TODO"; log "interrupted, $(wc -l < "$TODO") left"
  fi
  [ $(( $(date +%s) - t0 )) -gt $WAIT_PS4 ] && { log "console never came up, giving up until next boot"; exit 1; }
  sleep 20
done
