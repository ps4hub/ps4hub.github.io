<?php
// Actualizeaza o sursa locala (RawGame, WebKitty, etc.) prin git clone/pull.
// Lista de surse valide vine EXCLUSIV din discover_sources() -- acelasi
// mecanism folosit de list_sources.php, ca sa nu poata diverge intre ce se
// afiseaza si ce se accepta. Clientul trimite doar "key", niciodata repo/dir,
// ca sa nu poata cere clonarea unui repo arbitrar sau scrierea in afara
// folderului lui.
header('Content-Type: application/json');
require __DIR__ . '/sources_lib.php';

$repos = discover_sources(realpath(__DIR__));

$key = isset($_GET['key']) ? (string) $_GET['key'] : '';
$entry = null;
foreach ($repos as $r) {
    if (($r['key'] ?? '') === $key) { $entry = $r; break; }
}

function fail($code, $msg, $extra = []) {
    http_response_code($code);
    echo json_encode(array_merge(['ok' => false, 'error' => $msg], $extra));
    exit;
}

if (!$entry) fail(404, 'sursa necunoscuta');
if (empty($entry['dir'])) fail(400, 'sursa nu are copie locala (dir)');

$dir = trim((string) $entry['dir'], '/');
if ($dir === '' || strpos($dir, '..') !== false) fail(400, 'dir invalid');

$repo = (string) ($entry['repo'] ?? '');
if (!preg_match('#^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$#', $repo)) fail(400, 'repo invalid');

$docroot = realpath(__DIR__);
$target = $docroot . '/' . $dir;
$targetParent = dirname(rtrim($target, '/'));

if (!is_dir($targetParent)) fail(500, 'folder parinte lipsa: ' . $targetParent);

$remote = escapeshellarg('https://github.com/' . $repo . '.git');
$targetEsc = escapeshellarg(rtrim($target, '/'));

$gitDirExists = is_dir(rtrim($target, '/') . '/.git');

// Backup-urile stau centralizate in /opt/ps4mods-backups/pre-update/<key>/ (in afara docroot, ca sa nu fie servite prin HTTP) -- un singur snapshot
// pastrat per sursa (cel vechi e sters inainte, nu se acumuleaza un folder
// nou la fiecare update). Facut la FIECARE update (nu doar la prima clonare),
// ca sa existe mereu o cale de rollback la starea de dinaintea ultimei
// actualizari, cu data exacta cand s-a intamplat.
$backupRoot = '/opt/ps4mods-backups/pre-update';
if (!is_dir($backupRoot)) mkdir($backupRoot, 0775, true);
$backup = $backupRoot . '/' . $key;
if (is_dir($target)) {
    if (is_dir($backup)) exec('rm -rf ' . escapeshellarg($backup));
    exec('cp -a ' . $targetEsc . ' ' . escapeshellarg($backup));
    file_put_contents($backup . '/.backed-up-at', date('c') . "\n");
    touch($backup);
}

if ($gitDirExists) {
    // repo existent -- doar pull, fast-forward only (nu suprascriem modificari
    // locale neasteptate si nu facem merge-uri surprinzatoare)
    exec("cd $targetEsc && timeout 60 git pull --ff-only 2>&1", $out, $rc);
} else {
    // prima actualizare: folderul exista deja ca fisiere simple (nu git),
    // il clonam intr-un folder temporar apoi il punem la locul lui.
    // Temporarul trebuie sa fie pe ACELASI filesystem ca $target -- rename()
    // esueaza cu "Invalid cross-device link" daca vine din /tmp (alt mount).
    $tmp = $targetParent . '/.clone_tmp_' . bin2hex(random_bytes(6));
    exec("timeout 90 git clone --depth 1 $remote " . escapeshellarg($tmp) . " 2>&1", $out, $rc);
    if ($rc === 0 && is_dir($tmp)) {
        // Mutam vechiul folder deoparte cu rename() -- asta are nevoie doar de
        // drept de scriere pe $targetParent, NU pe folderul mutat insusi, deci
        // functioneaza chiar daca folderul original a ramas cu owner root de
        // dinainte sa fie convertit la git (spre deosebire de un rm -rf direct
        // pe el, care are nevoie de scriere PE el ca sa-i stearga continutul
        // si esueaza silentios -- exact ce s-a intamplat prima data cu
        // mansoor0x). Avem oricum backup complet in /opt/ps4mods-backups/pre-update/, deci
        // stergerea vechiului e doar curatenie, best-effort.
        $stale = null;
        if (is_dir($target)) {
            $stale = $targetParent . '/.stale_' . bin2hex(random_bytes(6));
            rename($target, $stale);
        }
        rename($tmp, rtrim($target, '/'));
        if ($stale !== null && is_dir($stale)) exec('rm -rf ' . escapeshellarg($stale));
        // .url-ul care identifica sursa (discover_sources) nu face parte din
        // repo-ul upstream, deci git clone nu-l aduce -- fara asta, sursa
        // devine "necunoscuta" la urmatoarea verificare. Il recuperam din
        // backup ca sa supravietuiasca peste clonare.
        foreach (glob(rtrim($backup, '/') . '/*.url') as $urlFile) {
            @copy($urlFile, rtrim($target, '/') . '/' . basename($urlFile));
        }
        $out[] = 'Clonat proaspat (varianta veche pastrata in /opt/ps4mods-backups/pre-update/' . $key . ').';
    }
}

if ($rc !== 0) fail(500, 'git a esuat', ['log' => implode("\n", $out)]);

echo json_encode(['ok' => true, 'key' => $key, 'log' => implode("\n", $out), 'updatedAt' => date('c')]);
