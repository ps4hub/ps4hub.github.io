<?php
// Verifica daca GoldHEN ruleaza pe PS4 (portul payloader-ului, 9090, e deschis).
// Verificarea se face pe server (fsockopen = conexiune TCP reala), nu din
// browserul PS4 -- de acolo un port refuzat si unul viu raspund identic (opac).
//
// IP-ul consolei se invata singur: cand browserul PS4 deschide hub-ul de pe
// acest server (pe orice retea a rpi-ului: eth0 sau wlan0), REMOTE_ADDR e chiar
// consola; il salvam ca auto_shutdown.sh sa stie pe cine sa verifice.
header('Content-Type: application/json');

$ipFile = '/etc/luckfox-hub/ps4_ip';
$port = 9090;
$timeout = 1.5;

$ua = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : '';
$remote = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '';

if (stripos($ua, 'PlayStation') !== false && filter_var($remote, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
    $ps4_ip = $remote;
    if (@file_get_contents($ipFile) !== $ps4_ip . "\n") {
        @file_put_contents($ipFile, $ps4_ip . "\n");
    }
} else {
    $saved = trim((string)@file_get_contents($ipFile));
    $ps4_ip = filter_var($saved, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) ? $saved : '10.1.1.2';
}

$detected = false;
$conn = @fsockopen($ps4_ip, $port, $errno, $errstr, $timeout);
if ($conn) {
    $detected = true;
    fclose($conn);
}

echo json_encode(['detected' => $detected, 'ip' => $ps4_ip]);
