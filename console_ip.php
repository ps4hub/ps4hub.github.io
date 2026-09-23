<?php
// Detecteaza consola PS4 pe retelele rpi-ului si intoarce IP-ul ei.
// Surse, in ordine: (1) browserul care cere pagina e chiar PS4-ul;
// (2) raspuns la Device Discovery Protocol (broadcast UDP 987, "SRCH"),
// pe fiecare interfata activa; (3) un lease dnsmasq pe eth0 (LAN-ul
// dedicat PS4) cu intrare ARP completa. Rezultatul scanarii e tinut
// cateva secunde in cache, ca polling-ul hub-ului sa nu inunde reteaua.
// IP-ul gasit e scris si in /etc/luckfox-hub/ps4_ip, de unde il citesc
// auto_shutdown.sh (care apeleaza acest endpoint la fiecare verificare)
// si goldhen_status.php.
header('Content-Type: application/json');
header('Cache-Control: no-store');

const DDP_PORT = 987;
const CACHE_TTL = 15;
const LISTEN_SEC = 1.2;
const IP_FILE = '/etc/luckfox-hub/ps4_ip';
$cacheFile = sys_get_temp_dir() . '/ps4hub_console.json';

function remember_ip($ip) {
    if (@file_get_contents(IP_FILE) !== $ip . "\n") @file_put_contents(IP_FILE, $ip . "\n");
}

$ua = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : '';
$remote = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '';
if (stripos($ua, 'PlayStation') !== false && filter_var($remote, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
    remember_ip($remote);
    echo json_encode(['detected' => true, 'ip' => $remote, 'via' => 'browser']);
    exit;
}

$cached = @json_decode((string)@file_get_contents($cacheFile), true);
if (is_array($cached) && isset($cached['t']) && time() - $cached['t'] < CACHE_TTL) {
    echo json_encode($cached['r']);
    exit;
}

// Doar un proces scaneaza; ceilalti primesc ultimul rezultat cunoscut.
$lock = @fopen($cacheFile . '.lock', 'c');
if (!$lock || !flock($lock, LOCK_EX | LOCK_NB)) {
    echo json_encode(is_array($cached) && isset($cached['r']) ? $cached['r'] : ['detected' => false]);
    exit;
}

function active_ipv4_interfaces() {
    $out = [];
    foreach (glob('/sys/class/net/*') as $dir) {
        $if = basename($dir);
        if ($if === 'lo' || trim((string)@file_get_contents("$dir/operstate")) !== 'up') continue;
        $line = (string)@shell_exec('ip -o -4 addr show dev ' . escapeshellarg($if) . ' scope global 2>/dev/null');
        if (preg_match('#inet (\d+\.\d+\.\d+\.\d+)/(\d+)#', $line, $m)) {
            $ip = ip2long($m[1]);
            $mask = $m[2] == 0 ? 0 : (~0 << (32 - (int)$m[2])) & 0xFFFFFFFF;
            $out[$if] = ['ip' => $m[1], 'bcast' => long2ip(($ip & $mask) | (~$mask & 0xFFFFFFFF))];
        }
    }
    return $out;
}

function ddp_search($ifaces) {
    $found = [];
    $msg = "SRCH * HTTP/1.1\ndevice-discovery-protocol-version:00020020\n";
    $socks = [];
    foreach ($ifaces as $if => $a) {
        $s = @socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
        if (!$s) continue;
        socket_set_option($s, SOL_SOCKET, SO_BROADCAST, 1);
        if (!@socket_bind($s, $a['ip'], 0)) { socket_close($s); continue; }
        @socket_sendto($s, $msg, strlen($msg), 0, $a['bcast'], DDP_PORT);
        socket_set_nonblock($s);
        $socks[$if] = $s;
    }
    $deadline = microtime(true) + LISTEN_SEC;
    while ($socks && ($left = $deadline - microtime(true)) > 0) {
        $r = array_values($socks); $w = null; $e = null;
        if (@socket_select($r, $w, $e, 0, (int)($left * 1e6)) < 1) break;
        foreach ($r as $s) {
            $buf = ''; $from = ''; $port = 0;
            while (@socket_recvfrom($s, $buf, 2048, 0, $from, $port) > 0) {
                if (stripos($buf, 'host-type:PS') === false) continue;
                $status = preg_match('#^HTTP/1\.1 (\d+)#', $buf, $m) ? (int)$m[1] : 0;
                $name = preg_match('#host-name:([^\r\n]*)#i', $buf, $m) ? trim($m[1]) : '';
                // system-version e.g. 07020001 -> 7.02, 13000000 -> 13.00
                $fw = preg_match('#system-version:(\d{2})(\d{2})\d*#i', $buf, $m) ? ((int)$m[1]) . '.' . $m[2] : '';
                $found[$from] = ['ip' => $from, 'name' => $name, 'fw' => $fw, 'state' => $status === 200 ? 'on' : ($status === 620 ? 'standby' : 'unknown')];
            }
        }
    }
    foreach ($socks as $s) socket_close($s);
    return array_values($found);
}

function eth0_lease_alive() {
    $leases = @file('/var/lib/misc/dnsmasq.leases', FILE_IGNORE_NEW_LINES) ?: [];
    $arp = @file('/proc/net/arp', FILE_IGNORE_NEW_LINES) ?: [];
    foreach ($leases as $l) {
        $p = preg_split('/\s+/', trim($l));
        if (count($p) < 3) continue;
        foreach ($arp as $row) {
            $a = preg_split('/\s+/', trim($row));
            if (count($a) >= 6 && $a[0] === $p[2] && $a[2] === '0x2' && $a[5] === 'eth0') return $p[2];
        }
    }
    return null;
}

$ifaces = active_ipv4_interfaces();
$hits = ddp_search($ifaces);
if ($hits) {
    $r = ['detected' => true, 'ip' => $hits[0]['ip'], 'name' => $hits[0]['name'], 'fw' => $hits[0]['fw'], 'state' => $hits[0]['state'], 'via' => 'ddp'];
} elseif (isset($ifaces['eth0']) && ($ip = eth0_lease_alive())) {
    $r = ['detected' => true, 'ip' => $ip, 'via' => 'dhcp'];
} else {
    $r = ['detected' => false];
}
if ($r['detected']) remember_ip($r['ip']);

@file_put_contents($cacheFile, json_encode(['t' => time(), 'r' => $r]));
flock($lock, LOCK_UN);
echo json_encode($r);
