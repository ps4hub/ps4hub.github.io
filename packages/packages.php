<?php
// Listare automată a pachetelor din folderul propriu.
// Pune-l în packages/packages.php — pagina packages.html îl interoghează primul.
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$dir = __DIR__;
$out = array();

foreach (scandir($dir) as $f) {
    if ($f === '.' || $f === '..') continue;
    if (!is_file($dir . '/' . $f)) continue;
    if (strtolower(pathinfo($f, PATHINFO_EXTENSION)) !== 'pkg') continue;
    $out[] = array(
        'name'  => $f,
        'bytes' => filesize($dir . '/' . $f),
        'mtime' => filemtime($dir . '/' . $f),
    );
}

usort($out, function ($a, $b) { return strcasecmp($a['name'], $b['name']); });

echo json_encode(array('packages' => $out));
