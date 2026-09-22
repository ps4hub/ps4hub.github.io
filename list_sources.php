<?php
header('Content-Type: application/json');
require __DIR__ . '/sources_lib.php';
echo json_encode(['ok' => true, 'sources' => discover_sources(realpath(__DIR__))]);
