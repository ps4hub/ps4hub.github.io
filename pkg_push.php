<?php
// Copiază un .pkg din packages/ pe consolă (GoldHEN FTP, /data/pkg), apoi se instalează
// din Settings > Debug Settings > Game > Package Installer.
//   ?action=start&name=X.pkg   pornește copierea în fundal
//   ?action=status&name=X.pkg  {state: running|done|error, sent, total}
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function out($a) { echo json_encode($a); exit; }

$dir  = __DIR__ . '/packages';
$name = basename(isset($_GET['name']) ? $_GET['name'] : '');
$file = $dir . '/' . $name;
if ($name === '' || strtolower(pathinfo($name, PATHINFO_EXTENSION)) !== 'pkg' || !is_file($file)) {
    out(array('state' => 'error', 'error' => 'pachet necunoscut'));
}

// Consola: IP-ul cerut doar dacă e în rețeaua PS4 (10.1.1.0/24); altfel cel detectat.
$ip = isset($_GET['host']) ? trim($_GET['host']) : '';
if (!preg_match('/^10\.1\.1\.\d{1,3}$/', $ip)) {
    $ip = @trim(file_get_contents('/etc/luckfox-hub/ps4_ip'));
}
if (!preg_match('/^\d{1,3}(\.\d{1,3}){3}$/', $ip)) out(array('state' => 'error', 'error' => 'consola nedetectată'));

$total = filesize($file);
$key   = md5($name);
$flag  = "/tmp/pkgpush_$key";
$port  = 2121;

if (isset($_GET['action']) && $_GET['action'] === 'start') {
    if (is_file("$flag.pid") && posix_kill((int)file_get_contents("$flag.pid"), 0)) {
        out(array('state' => 'running', 'total' => $total));
    }
    @unlink("$flag.done"); @unlink("$flag.err");
    $cmd = 'curl -s --max-time 3600 --ftp-create-dirs -T ' . escapeshellarg($file) .
           ' ' . escapeshellarg("ftp://$ip:$port/data/pkg/" . rawurlencode($name)) .
           ' && touch ' . escapeshellarg("$flag.done") . ' || touch ' . escapeshellarg("$flag.err");
    $pid = shell_exec('nohup sh -c ' . escapeshellarg($cmd) . ' >/dev/null 2>&1 & echo $!');
    file_put_contents("$flag.pid", trim($pid));
    out(array('state' => 'running', 'total' => $total));
}

if (is_file("$flag.done")) out(array('state' => 'done', 'sent' => $total, 'total' => $total));
if (is_file("$flag.err"))  out(array('state' => 'error', 'error' => 'copierea a eșuat (FTP GoldHEN pornit?)', 'total' => $total));

$sent = 0;
$c = @ftp_connect($ip, $port, 3);
if ($c && @ftp_login($c, 'anonymous', '')) { $s = @ftp_size($c, "/data/pkg/$name"); if ($s > 0) $sent = $s; }
if ($c) @ftp_close($c);
out(array('state' => 'running', 'sent' => $sent, 'total' => $total));
