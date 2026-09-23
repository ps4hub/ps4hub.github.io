#!/bin/sh
# Oprește automat rpi-ul după ce GoldHEN devine activ pe PS4,
# dar doar dacă bifa "Oprire automată" din index.html e activă
# (flag pe /etc/luckfox-hub/auto_shutdown.enabled, comutat de shutdown_toggle.php;
# pe /etc, nu pe /var/www, ca sa persiste real si sa poata fi scris de php-fpm).
#
# IP-ul consolei vine din /etc/luckfox-hub/ps4_ip. La fiecare verificare
# apelam console_ip.php (detectie in retea: PS4 Device Discovery pe toate
# interfetele active, lease DHCP pe eth0), care actualizeaza fisierul;
# goldhen_status.php il scrie si cand browserul PS4 deschide hub-ul.
# Rezerva: 10.1.1.2 (rezervarea DHCP de pe eth0).

IP_FILE="/etc/luckfox-hub/ps4_ip"
DEFAULT_IP="10.1.1.2"
PORT="9090"
WAIT_MINUTES=5
FLAG="/etc/luckfox-hub/auto_shutdown.enabled"

ps4_ip() {
  ip=$(head -n 1 "$IP_FILE" 2>/dev/null | tr -d ' \r\n')
  if echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then echo "$ip"; else echo "$DEFAULT_IP"; fi
}

echo "[Auto-Shutdown] Astept activarea GoldHEN pe PS4 (port $PORT)..."
while true; do
  curl -s -m 4 -o /dev/null http://127.0.0.1/console_ip.php
  PS4_IP=$(ps4_ip)
  if nc -z -w 2 "$PS4_IP" "$PORT" 2>/dev/null; then
    echo "[Auto-Shutdown] GoldHEN activ pe $PS4_IP:$PORT!"

    if [ ! -f "$FLAG" ]; then
      echo "[Auto-Shutdown] Bifa e debifata -> nu opresc placa acum."
      echo "[Auto-Shutdown] Astept sa fie bifata din pagina web..."
      while [ ! -f "$FLAG" ]; do sleep 5; done
      echo "[Auto-Shutdown] Bifa activata -> continui cu oprirea programata."
    fi

    echo "[Auto-Shutdown] Oprire programata in $WAIT_MINUTES minute..."
    sleep $((WAIT_MINUTES * 60))

    if [ -f "$FLAG" ]; then
      echo "[Auto-Shutdown] Se opreste placa..."
      poweroff
    else
      echo "[Auto-Shutdown] Anulat -- bifa a fost debifata in timpul asteptarii."
    fi
    exit 0
  fi
  sleep 5
done
