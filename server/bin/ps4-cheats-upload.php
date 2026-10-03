<?php
// php ps4-cheats-upload.php <ip> <port> <listfile> <srcdir> <manifest>
// listfile: "<hash>\t<path>" lines. Uploads each file to /data/GoldHEN/cheats/<path>
// over GoldHEN FTP and appends the line to <manifest> only after a successful transfer.
list(, $ip, $port, $list, $src, $manifest) = $argv;
$dest = '/data/GoldHEN/cheats';
function conn($ip, $port) {
    $c = @ftp_connect($ip, (int)$port, 10);
    if (!$c || !@ftp_login($c, 'anonymous', '')) return false;
    @ftp_pasv($c, true);
    return $c;
}
$c = conn($ip, $port);
if (!$c) { fwrite(STDERR, "ftp connect failed\n"); exit(1); }
foreach (array('/data/GoldHEN', $dest, "$dest/json", "$dest/mc4", "$dest/shn") as $d) @ftp_mkdir($c, $d);

$lines = file($list, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$total = count($lines); $ok = 0; $fail = 0; $t0 = time();
foreach ($lines as $i => $line) {
    list($hash, $path) = explode("\t", $line, 2);
    $sub = dirname($path);
    $done = false;
    for ($try = 0; $try < 2 && !$done; $try++) {
        if (@ftp_put($c, "$dest/$path", "$src/$path", FTP_BINARY)) { $done = true; break; }
        if ($sub !== '.') @ftp_mkdir($c, "$dest/$sub");
        @ftp_close($c); $c = conn($ip, $port);
        if (!$c) break;
    }
    if ($done) { $ok++; $fail = 0; file_put_contents($manifest, $line . "\n", FILE_APPEND); }
    else { $fail++; if ($fail >= 10 || !$c) { fwrite(STDERR, "console went away after $ok files\n"); exit(1); } }
    if (($i + 1) % 200 === 0) echo date('H:i:s') . " uploaded " . ($i + 1) . "/$total\n";
}
if ($c) @ftp_close($c);
echo "uploaded $ok/$total files in " . (time() - $t0) . "s\n";
exit(0);
