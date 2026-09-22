<?php
// Comuta bifa "Oprire automata Luckfox".
// Apelat de index.html (toggleShutdown) cu ?enabled=1 sau ?enabled=0.
// Nu opreste nimic direct -- doar creeaza/sterge un flag pe care
// auto_shutdown.sh il verifica inainte sa dea poweroff.
header('Content-Type: application/json');
$flag = '/etc/luckfox-hub/auto_shutdown.enabled';

$enabled = isset($_GET['enabled']) ? $_GET['enabled'] : null;
if ($enabled === '1') {
    @touch($flag);
} elseif ($enabled === '0') {
    @unlink($flag);
}

echo json_encode(['enabled' => file_exists($flag)]);
