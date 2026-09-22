<?php
// Raporteaza starea curenta a bifei "Oprire automata Luckfox".
// Citit de index.html (loadShutdown) la incarcarea paginii.
header('Content-Type: application/json');
$flag = '/etc/luckfox-hub/auto_shutdown.enabled';
echo json_encode(['enabled' => file_exists($flag)]);
