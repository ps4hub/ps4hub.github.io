<?php
// Descopera sursele urmarite pentru update-checker: fiecare folder din
// meta/readme.json -> "updateDirs" trebuie sa contina un fisier .url
// (shortcut standard, cu o linie "URL=https://github.com/<owner>/<repo>").
// Asta e sursa unica de adevar -- atat listarea (list_sources.php) cat si
// actualizarea (update_payload.php) folosesc aceeasi functie, ca sa nu poata
// diverge intre ce se afiseaza si ce se accepta la update.
//
// Adaugi un folder nou in "updateDirs" + un .url in el = apare sursa noua.
// Stergi intrarea din "updateDirs" (sau folderul) = dispare.

function discover_sources($docroot) {
    $metaFile = $docroot . '/meta/readme.json';
    $meta = json_decode(@file_get_contents($metaFile), true);
    $dirs = is_array($meta['updateDirs'] ?? null) ? $meta['updateDirs'] : [];

    $out = [];
    foreach ($dirs as $rawDir) {
        $dir = trim((string) $rawDir, '/');
        if ($dir === '' || strpos($dir, '..') !== false) continue;

        $full = $docroot . '/' . $dir;
        if (!is_dir($full)) continue;

        $repo = null;
        foreach (glob($full . '/*.url') as $urlFile) {
            $content = @file_get_contents($urlFile);
            if ($content && preg_match('#github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)#', $content, $m)) {
                $repo = $m[1] . '/' . $m[2];
                break;
            }
        }
        if (!$repo) continue;

        $out[] = ['key' => basename($dir), 'dir' => $dir . '/', 'repo' => $repo];
    }
    return $out;
}
