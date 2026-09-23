#!/bin/sh
# Trage ultimele modificari din robex2005/ps4hub (origin) si le aplica peste
# serverul local /var/www. Nu sterge nimic care nu e in repo (fara --delete):
# .git-urile proprii din payloads/* (folosite de update_payload.php pentru
# git pull/clone) si packages/*.pkg raman neatinse, exact ca pana acum.
set -e

SYNC_DIR=/opt/ps4hub-sync
WWW_DIR=/var/www

cd "$SYNC_DIR"
echo "== git pull origin main =="
git pull origin main

echo "== rsync -> $WWW_DIR (fara --delete, fara fisierele proprii repo-ului) =="
rsync -av \
  --exclude='.git' \
  --exclude='.gitignore' \
  --exclude='README.md' \
  --exclude='packages/README.md' \
  --exclude='.git-credentials-pages' \
  --exclude='server/' \
  "$SYNC_DIR"/ "$WWW_DIR"/

echo "== proprietar/permisiuni pe folderele care trebuie sa ramana scriptibile de www-data =="
chown -R www-data:www-data "$WWW_DIR"/payloads
chown www-data:www-data "$WWW_DIR" "$WWW_DIR"/payloads

echo "done"
