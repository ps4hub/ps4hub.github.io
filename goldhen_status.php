<?php
// Verifica daca GoldHEN ruleaza pe PS4 (portul sau de RPC, 9090, e deschis).
// Verificarea se face AICI, pe Luckfox (fsockopen = conexiune TCP reala),
// nu printr-un fetch direct din browserul PS4 -- de acolo un port refuzat
// si un server viu raspund identic (opac), deci orice test ar da fals-pozitiv.
header('Content-Type: application/json');

$ps4_ip = '10.0.0.2';
$port = 9090;
$timeout = 1.5;

$detected = false;
$conn = @fsockopen($ps4_ip, $port, $errno, $errstr, $timeout);
if ($conn) {
    $detected = true;
    fclose($conn);
}

echo json_encode(['detected' => $detected]);
