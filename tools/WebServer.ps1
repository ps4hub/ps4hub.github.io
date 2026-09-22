# Unelte de retea locale, cu interfata grafica (Windows PowerShell, fara instalari).
#   Tab 1 - Webserver : serveste un folder prin HTTP
#   Tab 2 - Ascultare : deschide un port TCP/UDP si logheaza ce vine pe el
#   Tab 3 - Test port : verifica daca un IP:port raspunde (TCP/UDP) + ping ICMP

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$defaultRoot = if (Test-Path (Join-Path $scriptDir '..\index.html')) { (Resolve-Path (Join-Path $scriptDir '..')).Path } else { $scriptDir }

$mime = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'
  '.json'='application/json; charset=utf-8'; '.js'='application/javascript; charset=utf-8'
  '.css'='text/css; charset=utf-8'; '.txt'='text/plain; charset=utf-8'
  '.svg'='image/svg+xml'; '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'
  '.gif'='image/gif'; '.ico'='image/x-icon'; '.woff'='font/woff'; '.woff2'='font/woff2'
  '.pkg'='application/octet-stream'; '.bin'='application/octet-stream'
}

$bgDeep  = [System.Drawing.Color]::FromArgb(6, 37, 92)
$bgLog   = [System.Drawing.Color]::FromArgb(2, 26, 61)
$fgSoft  = [System.Drawing.Color]::FromArgb(200, 215, 245)
$fgLog   = [System.Drawing.Color]::FromArgb(220, 232, 255)
$green   = [System.Drawing.Color]::FromArgb(134, 239, 172)
$red     = [System.Drawing.Color]::FromArgb(252, 165, 165)
$amber   = [System.Drawing.Color]::FromArgb(252, 211, 77)

# ---------------- forma + tab-uri ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Unelte retea - webserver, ascultare port, test port'
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $bgDeep
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.Padding = New-Object System.Drawing.Point(14, 6)
$form.Controls.Add($tabs)

function New-Tab($title) {
  $t = New-Object System.Windows.Forms.TabPage
  $t.Text = $title
  $t.BackColor = $bgDeep
  $t.ForeColor = [System.Drawing.Color]::White
  $tabs.TabPages.Add($t)
  return $t
}

function New-Label($parent, $text, $x, $y, $w) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $text
  $l.Location = New-Object System.Drawing.Point($x, $y)
  $l.Size = New-Object System.Drawing.Size($w, 20)
  $l.ForeColor = $fgSoft
  $parent.Controls.Add($l); return $l
}

function New-Text($parent, $x, $y, $w, $val) {
  $t = New-Object System.Windows.Forms.TextBox
  $t.Location = New-Object System.Drawing.Point($x, $y)
  $t.Size = New-Object System.Drawing.Size($w, 24)
  $t.Text = $val
  $parent.Controls.Add($t); return $t
}

function New-Button($parent, $text, $x, $y, $w, $h) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $text
  $b.Location = New-Object System.Drawing.Point($x, $y)
  $b.Size = New-Object System.Drawing.Size($w, $h)
  $parent.Controls.Add($b); return $b
}

function New-Log($parent, $x, $y, $w, $h) {
  $t = New-Object System.Windows.Forms.TextBox
  $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = 'Vertical'
  $t.Location = New-Object System.Drawing.Point($x, $y)
  $t.Size = New-Object System.Drawing.Size($w, $h)
  $t.BackColor = $bgLog; $t.ForeColor = $fgLog
  $t.Font = New-Object System.Drawing.Font('Consolas', 9)
  $parent.Controls.Add($t); return $t
}

function Log-To($box, $msg) {
  $box.AppendText(('[{0}] {1}{2}' -f (Get-Date -Format 'HH:mm:ss'), $msg, [Environment]::NewLine))
}

function Get-LocalIPs {
  try {
    (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
      Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' }).IPAddress
  } catch {
    [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
      Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.IPAddressToString }
  }
}

# ================= TAB 1 - WEBSERVER =================
$tabWeb = New-Tab 'Webserver'

New-Label $tabWeb 'Folder servit' 16 14 120 | Out-Null
$txtRoot = New-Text $tabWeb 16 36 560 $defaultRoot
$btnBrowse = New-Button $tabWeb 'Alege...' 584 34 110 27

New-Label $tabWeb 'Port' 16 74 60 | Out-Null
$txtPort = New-Text $tabWeb 16 96 90 '8080'

$chkLan = New-Object System.Windows.Forms.CheckBox
$chkLan.Text = 'Acces din retea (necesita rulare ca Administrator)'
$chkLan.Location = New-Object System.Drawing.Point(124, 96)
$chkLan.Size = New-Object System.Drawing.Size(430, 24)
$chkLan.ForeColor = $fgSoft
$tabWeb.Controls.Add($chkLan)

$btnStart = New-Button $tabWeb 'Porneste' 16 134 120 34
$btnStop  = New-Button $tabWeb 'Opreste' 146 134 120 34
$btnStop.Enabled = $false
$btnOpen  = New-Button $tabWeb 'Deschide in browser' 276 134 170 34
$btnOpen.Enabled = $false

$lblState = New-Label $tabWeb 'Oprit' 16 180 200
$lblState.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$lblState.ForeColor = $red
$lblState.AutoSize = $true

# adresele pe care ruleaza serverul, ca linkuri pe care se poate da clic
$links = New-Object System.Windows.Forms.FlowLayoutPanel
$links.Location = New-Object System.Drawing.Point(14, 202)
$links.Size = New-Object System.Drawing.Size(700, 26)
$links.FlowDirection = 'LeftToRight'
$links.WrapContents = $false
$links.AutoScroll = $true
$tabWeb.Controls.Add($links)

function Add-UrlLink($url) {
  $lk = New-Object System.Windows.Forms.LinkLabel
  $lk.Text = $url
  $lk.AutoSize = $true
  $lk.Margin = New-Object System.Windows.Forms.Padding(2, 4, 14, 0)
  $lk.LinkColor = [System.Drawing.Color]::FromArgb(160, 205, 255)
  $lk.ActiveLinkColor = [System.Drawing.Color]::White
  $lk.VisitedLinkColor = [System.Drawing.Color]::FromArgb(160, 205, 255)
  $lk.Add_LinkClicked({ Start-Process $this.Text })
  $links.Controls.Add($lk)
}

$log = New-Log $tabWeb 16 236 700 232

$script:listener = $null
$script:ctxTask = $null
$script:url = ''

function Write-Log($msg) { Log-To $log $msg }

function Send-File($ctx, $path) {
  $ext = [System.IO.Path]::GetExtension($path).ToLower()
  $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
  # fara cache: fisierele meta trebuie recitite la fiecare reincarcare
  $ctx.Response.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate')
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Send-Text($ctx, $code, $text) {
  $ctx.Response.StatusCode = $code
  $ctx.Response.ContentType = 'text/html; charset=utf-8'
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Handle-Request($ctx, $root) {
  $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
  if ($rel -eq '') { $rel = 'index.html' }
  $rel = $rel -replace '/', '\'
  $full = Join-Path $root $rel
  $rootFull = (Resolve-Path $root).Path

  if (Test-Path $full -PathType Container) {
    $idx = Join-Path $full 'index.html'
    if (Test-Path $idx) { $full = $idx }
  }

  if (Test-Path $full -PathType Leaf) {
    $resolved = (Resolve-Path $full).Path
    if (-not $resolved.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      Send-Text $ctx 403 'Forbidden'; return '403 ' + $rel
    }
    Send-File $ctx $resolved
    return '200 ' + $rel
  }

  $ctx.Response.StatusCode = 404
  $custom = Join-Path $root '404.html'
  if (Test-Path $custom) { Send-File $ctx $custom } else { Send-Text $ctx 404 '404 - not found' }
  return '404 ' + $rel
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 40
$timer.Add_Tick({
  if ($null -eq $script:listener -or -not $script:listener.IsListening) { return }
  if ($null -eq $script:ctxTask) { $script:ctxTask = $script:listener.GetContextAsync(); return }
  if (-not $script:ctxTask.IsCompleted) { return }
  try {
    $ctx = $script:ctxTask.Result
    $script:ctxTask = $null
    $line = Handle-Request $ctx $txtRoot.Text
    $ctx.Response.OutputStream.Close()
    Write-Log $line
  } catch {
    $script:ctxTask = $null
    Write-Log ('eroare: ' + $_.Exception.Message)
  }
})

$btnBrowse.Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.SelectedPath = $txtRoot.Text
  if ($dlg.ShowDialog() -eq 'OK') { $txtRoot.Text = $dlg.SelectedPath }
})

$btnStart.Add_Click({
  if (-not (Test-Path $txtRoot.Text)) { [System.Windows.Forms.MessageBox]::Show('Folderul nu exista.'); return }
  $port = 8080
  if (-not [int]::TryParse($txtPort.Text, [ref]$port)) { [System.Windows.Forms.MessageBox]::Show('Port invalid.'); return }
  $prefix = if ($chkLan.Checked) { "http://+:$port/" } else { "http://localhost:$port/" }
  try {
    $script:listener = New-Object System.Net.HttpListener
    $script:listener.Prefixes.Add($prefix)
    $script:listener.Start()
  } catch {
    $script:listener = $null
    Write-Log ('nu am putut porni: ' + $_.Exception.Message)
    if ($chkLan.Checked) { Write-Log 'Pentru acces din retea, porneste scriptul cu clic dreapta > Run as administrator.' }
    else { Write-Log 'Incearca alt port (ex. 8081).' }
    return
  }
  $script:ctxTask = $null
  $script:url = "http://localhost:$port/"
  $timer.Start()
  $btnStart.Enabled = $false; $btnStop.Enabled = $true; $btnOpen.Enabled = $true
  $txtRoot.Enabled = $false; $txtPort.Enabled = $false; $chkLan.Enabled = $false; $btnBrowse.Enabled = $false
  $lblState.Text = 'Pornit:'
  $lblState.ForeColor = $green
  $links.Controls.Clear()
  Add-UrlLink $script:url
  Write-Log ('servesc ' + $txtRoot.Text)
  Write-Log ('local: ' + $script:url)
  if ($chkLan.Checked) {
    foreach ($ip in Get-LocalIPs) {
      $u = "http://{0}:{1}/" -f $ip, $port
      Add-UrlLink $u
      Write-Log ('din retea: ' + $u)
    }
  }
})

$btnStop.Add_Click({
  $timer.Stop()
  if ($script:listener) { try { $script:listener.Stop(); $script:listener.Close() } catch {} }
  $script:listener = $null; $script:ctxTask = $null
  $btnStart.Enabled = $true; $btnStop.Enabled = $false; $btnOpen.Enabled = $false
  $txtRoot.Enabled = $true; $txtPort.Enabled = $true; $chkLan.Enabled = $true; $btnBrowse.Enabled = $true
  $links.Controls.Clear()
  $lblState.Text = 'Oprit'
  $lblState.ForeColor = $red
  Write-Log 'server oprit'
})

$btnOpen.Add_Click({ if ($script:url) { Start-Process $script:url } })

# ================= TAB 2 - ASCULTARE PORT =================
# Deschide un port si doar asculta: nu serveste fisiere, doar arata cine se
# conecteaza si ce trimite. Util ca sa verifici ca portul e accesibil.
$tabLis = New-Tab 'Ascultare port'

New-Label $tabLis 'Port' 16 14 60 | Out-Null
$txtLisPort = New-Text $tabLis 16 36 90 '9090'

$grpProto = New-Object System.Windows.Forms.GroupBox
$grpProto.Text = 'Protocol'
$grpProto.Location = New-Object System.Drawing.Point(124, 16)
$grpProto.Size = New-Object System.Drawing.Size(240, 52)
$grpProto.ForeColor = $fgSoft
$tabLis.Controls.Add($grpProto)

$rbTcp = New-Object System.Windows.Forms.RadioButton
$rbTcp.Text = 'TCP'; $rbTcp.Checked = $true
$rbTcp.Location = New-Object System.Drawing.Point(14, 20); $rbTcp.Size = New-Object System.Drawing.Size(60, 22)
$grpProto.Controls.Add($rbTcp)

$rbUdp = New-Object System.Windows.Forms.RadioButton
$rbUdp.Text = 'UDP'
$rbUdp.Location = New-Object System.Drawing.Point(80, 20); $rbUdp.Size = New-Object System.Drawing.Size(60, 22)
$grpProto.Controls.Add($rbUdp)

$rbBoth = New-Object System.Windows.Forms.RadioButton
$rbBoth.Text = 'Ambele'
$rbBoth.Location = New-Object System.Drawing.Point(146, 20); $rbBoth.Size = New-Object System.Drawing.Size(80, 22)
$grpProto.Controls.Add($rbBoth)

$chkLisAll = New-Object System.Windows.Forms.CheckBox
$chkLisAll.Text = 'Asculta pe toate interfetele (0.0.0.0)'
$chkLisAll.Checked = $true
$chkLisAll.Location = New-Object System.Drawing.Point(380, 38)
$chkLisAll.Size = New-Object System.Drawing.Size(280, 24)
$chkLisAll.ForeColor = $fgSoft
$tabLis.Controls.Add($chkLisAll)

$chkEcho = New-Object System.Windows.Forms.CheckBox
$chkEcho.Text = 'Raspunde clientului (echo)'
$chkEcho.Location = New-Object System.Drawing.Point(380, 64)
$chkEcho.Size = New-Object System.Drawing.Size(280, 24)
$chkEcho.ForeColor = $fgSoft
$tabLis.Controls.Add($chkEcho)

$btnLisStart = New-Button $tabLis 'Deschide portul' 16 82 140 32
$btnLisStop  = New-Button $tabLis 'Inchide' 166 82 110 32
$btnLisStop.Enabled = $false

$lblLisState = New-Label $tabLis 'Inchis' 16 126 400
$lblLisState.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$lblLisState.ForeColor = $red
$lblLisState.AutoSize = $true

$logLis = New-Log $tabLis 16 154 700 314

$script:tcpL = $null
$script:udpL = $null
$script:tcpTask = $null
$script:udpTask = $null

function Preview-Bytes($bytes, $n) {
  if ($null -eq $bytes -or $bytes.Length -eq 0) { return '(0 octeti)' }
  $take = [Math]::Min($n, $bytes.Length)
  $txt = ([System.Text.Encoding]::UTF8.GetString($bytes, 0, $take)) -replace '[^\u0020-\u007E]', '.'
  return ('{0} octeti | {1}' -f $bytes.Length, $txt)
}

$lisTimer = New-Object System.Windows.Forms.Timer
$lisTimer.Interval = 80
$lisTimer.Add_Tick({
  # TCP: acceptam conexiuni, citim ce e disponibil, optional raspundem
  if ($script:tcpL) {
    if ($null -eq $script:tcpTask) { $script:tcpTask = $script:tcpL.AcceptTcpClientAsync() }
    elseif ($script:tcpTask.IsCompleted) {
      try {
        $client = $script:tcpTask.Result
        $script:tcpTask = $null
        $remote = $client.Client.RemoteEndPoint.ToString()
        Log-To $logLis ("TCP conexiune de la $remote")
        $client.ReceiveTimeout = 300
        $ns = $client.GetStream()
        Start-Sleep -Milliseconds 120
        if ($client.Available -gt 0) {
          $buf = New-Object byte[] $client.Available
          $read = $ns.Read($buf, 0, $buf.Length)
          if ($read -gt 0) { Log-To $logLis ('  date: ' + (Preview-Bytes $buf 200)) }
        }
        if ($chkEcho.Checked) {
          $msg = [System.Text.Encoding]::UTF8.GetBytes("OK - port deschis`r`n")
          $ns.Write($msg, 0, $msg.Length)
        }
        $client.Close()
      } catch {
        $script:tcpTask = $null
        Log-To $logLis ('TCP eroare: ' + $_.Exception.Message)
      }
    }
  }
  # UDP: logam fiecare datagrama primita
  if ($script:udpL) {
    if ($null -eq $script:udpTask) { $script:udpTask = $script:udpL.ReceiveAsync() }
    elseif ($script:udpTask.IsCompleted) {
      try {
        $res = $script:udpTask.Result
        $script:udpTask = $null
        Log-To $logLis ('UDP pachet de la ' + $res.RemoteEndPoint.ToString() + ' | ' + (Preview-Bytes $res.Buffer 200))
        if ($chkEcho.Checked) {
          $msg = [System.Text.Encoding]::UTF8.GetBytes('OK')
          [void]$script:udpL.Send($msg, $msg.Length, $res.RemoteEndPoint)
        }
      } catch {
        $script:udpTask = $null
        Log-To $logLis ('UDP eroare: ' + $_.Exception.Message)
      }
    }
  }
})

$btnLisStart.Add_Click({
  $p = 0
  if (-not [int]::TryParse($txtLisPort.Text, [ref]$p) -or $p -lt 1 -or $p -gt 65535) {
    [System.Windows.Forms.MessageBox]::Show('Port invalid.'); return
  }
  $addr = if ($chkLisAll.Checked) { [System.Net.IPAddress]::Any } else { [System.Net.IPAddress]::Loopback }
  $wantTcp = $rbTcp.Checked -or $rbBoth.Checked
  $wantUdp = $rbUdp.Checked -or $rbBoth.Checked
  try {
    if ($wantTcp) {
      $script:tcpL = New-Object System.Net.Sockets.TcpListener($addr, $p)
      $script:tcpL.Start()
      Log-To $logLis ("TCP asculta pe {0}:{1}" -f $addr, $p)
    }
    if ($wantUdp) {
      $ep = New-Object System.Net.IPEndPoint($addr, $p)
      $script:udpL = New-Object System.Net.Sockets.UdpClient($ep)
      Log-To $logLis ("UDP asculta pe {0}:{1}" -f $addr, $p)
    }
  } catch {
    Log-To $logLis ('nu am putut deschide portul: ' + $_.Exception.Message)
    if ($script:tcpL) { try { $script:tcpL.Stop() } catch {} ; $script:tcpL = $null }
    if ($script:udpL) { try { $script:udpL.Close() } catch {} ; $script:udpL = $null }
    return
  }
  $script:tcpTask = $null; $script:udpTask = $null
  $lisTimer.Start()
  $btnLisStart.Enabled = $false; $btnLisStop.Enabled = $true
  $txtLisPort.Enabled = $false; $grpProto.Enabled = $false; $chkLisAll.Enabled = $false
  $lblLisState.Text = ('Deschis pe portul {0}' -f $p)
  $lblLisState.ForeColor = $green
  foreach ($ip in Get-LocalIPs) { Log-To $logLis ("testeaza din retea catre {0}:{1}" -f $ip, $p) }
})

$btnLisStop.Add_Click({
  $lisTimer.Stop()
  if ($script:tcpL) { try { $script:tcpL.Stop() } catch {} ; $script:tcpL = $null }
  if ($script:udpL) { try { $script:udpL.Close() } catch {} ; $script:udpL = $null }
  $script:tcpTask = $null; $script:udpTask = $null
  $btnLisStart.Enabled = $true; $btnLisStop.Enabled = $false
  $txtLisPort.Enabled = $true; $grpProto.Enabled = $true; $chkLisAll.Enabled = $true
  $lblLisState.Text = 'Inchis'
  $lblLisState.ForeColor = $red
  Log-To $logLis 'port inchis'
})

# ================= TAB 3 - TEST PORT =================
$tabTest = New-Tab 'Test port'

New-Label $tabTest 'IP / host' 16 14 120 | Out-Null
$txtTestHost = New-Text $tabTest 16 36 240 '10.0.0.2'

New-Label $tabTest 'Port (sau interval 9000-9010)' 272 14 220 | Out-Null
$txtTestPort = New-Text $tabTest 272 36 160 '9090'

New-Label $tabTest 'Timeout (ms)' 448 14 100 | Out-Null
$txtTestTimeout = New-Text $tabTest 448 36 80 '1000'

$grpTProto = New-Object System.Windows.Forms.GroupBox
$grpTProto.Text = 'Protocol'
$grpTProto.Location = New-Object System.Drawing.Point(544, 16)
$grpTProto.Size = New-Object System.Drawing.Size(170, 52)
$grpTProto.ForeColor = $fgSoft
$tabTest.Controls.Add($grpTProto)

$rbTTcp = New-Object System.Windows.Forms.RadioButton
$rbTTcp.Text = 'TCP'; $rbTTcp.Checked = $true
$rbTTcp.Location = New-Object System.Drawing.Point(14, 20); $rbTTcp.Size = New-Object System.Drawing.Size(60, 22)
$grpTProto.Controls.Add($rbTTcp)

$rbTUdp = New-Object System.Windows.Forms.RadioButton
$rbTUdp.Text = 'UDP'
$rbTUdp.Location = New-Object System.Drawing.Point(84, 20); $rbTUdp.Size = New-Object System.Drawing.Size(60, 22)
$grpTProto.Controls.Add($rbTUdp)

$btnTest = New-Button $tabTest 'Testeaza portul' 16 76 150 32
$btnPing = New-Button $tabTest 'Ping ICMP' 176 76 120 32
$btnTestClear = New-Button $tabTest 'Curata log' 306 76 110 32

$lblTestState = New-Label $tabTest 'Gata.' 16 120 660
$lblTestState.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$lblTestState.ForeColor = $fgSoft
$lblTestState.AutoSize = $true

$lblPingState = New-Label $tabTest '' 16 144 660
$lblPingState.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
$lblPingState.ForeColor = $fgSoft
$lblPingState.AutoSize = $true

$logTest = New-Log $tabTest 16 172 700 296

function Parse-PortRange($text) {
  $t = ($text -replace '\s', '')
  if ($t -match '^(\d+)-(\d+)$') {
    $a = [int]$matches[1]; $b = [int]$matches[2]
    if ($a -lt 1 -or $b -gt 65535 -or $a -gt $b) { return $null }
    if (($b - $a) -gt 200) { return $null }
    return $a..$b
  }
  $p = 0
  if ([int]::TryParse($t, [ref]$p) -and $p -ge 1 -and $p -le 65535) { return @($p) }
  return $null
}

function Test-TcpPort($hostName, $port, $timeout) {
  $c = New-Object System.Net.Sockets.TcpClient
  try {
    $task = $c.ConnectAsync($hostName, $port)
    if ($task.Wait($timeout) -and $c.Connected) { return @{ ok = $true; msg = 'DESCHIS' } }
    return @{ ok = $false; msg = 'INCHIS sau filtrat (nimic nu asculta / firewall)' }
  } catch {
    $m = $_.Exception.InnerException
    $reason = if ($m) { $m.Message } else { $_.Exception.Message }
    return @{ ok = $false; msg = 'INCHIS (' + $reason + ')' }
  } finally { try { $c.Close() } catch {} }
}

function Test-UdpPort($hostName, $port, $timeout) {
  # UDP nu confirma: raspuns = deschis, ICMP unreachable = inchis, tacere = incert
  $u = New-Object System.Net.Sockets.UdpClient
  try {
    $u.Client.ReceiveTimeout = $timeout
    $u.Connect($hostName, $port)
    $probe = [System.Text.Encoding]::UTF8.GetBytes('ping')
    [void]$u.Send($probe, $probe.Length)
    $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    $data = $u.Receive([ref]$ep)
    return @{ ok = $true; msg = 'DESCHIS - a raspuns ' + $data.Length + ' octeti' }
  } catch [System.Net.Sockets.SocketException] {
    if ($_.Exception.SocketErrorCode -eq 'ConnectionReset') { return @{ ok = $false; msg = 'INCHIS (ICMP port unreachable)' } }
    if ($_.Exception.SocketErrorCode -eq 'TimedOut') { return @{ ok = $null; msg = 'INCERT - fara raspuns (UDP nu confirma; poate fi deschis, filtrat sau mut)' } }
    return @{ ok = $false; msg = 'eroare: ' + $_.Exception.Message }
  } catch {
    return @{ ok = $false; msg = 'eroare: ' + $_.Exception.Message }
  } finally { try { $u.Close() } catch {} }
}

$btnTest.Add_Click({
  $h = $txtTestHost.Text.Trim()
  if (-not $h) { [System.Windows.Forms.MessageBox]::Show('Completeaza IP-ul sau host-ul.'); return }
  $ports = Parse-PortRange $txtTestPort.Text
  if ($null -eq $ports) { [System.Windows.Forms.MessageBox]::Show('Port invalid. Foloseste 9090 sau 9000-9010 (max 200 porturi).'); return }
  $to = 1000
  if (-not [int]::TryParse($txtTestTimeout.Text, [ref]$to)) { $to = 1000 }
  $proto = if ($rbTUdp.Checked) { 'UDP' } else { 'TCP' }

  $btnTest.Enabled = $false
  $lblTestState.Text = 'Testez...'; $lblTestState.ForeColor = $amber
  $form.Refresh()
  $openCount = 0
  foreach ($p in $ports) {
    $r = if ($proto -eq 'UDP') { Test-UdpPort $h $p $to } else { Test-TcpPort $h $p $to }
    if ($r.ok -eq $true) { $openCount++ }
    Log-To $logTest ("{0} {1}:{2} -> {3}" -f $proto, $h, $p, $r.msg)
    [System.Windows.Forms.Application]::DoEvents()
  }
  $btnTest.Enabled = $true
  if ($ports.Count -eq 1) {
    $verdict = if ($openCount -gt 0) { 'DESCHIS' } else { 'nu e deschis (niciun raspuns pe port)' }
    $lblTestState.Text = ("PORT {0} {1}:{2} - {3}" -f $proto, $h, $ports[0], $verdict)
  } else {
    $lblTestState.Text = ("PORT {0}: {1} porturi testate, {2} deschise" -f $proto, $ports.Count, $openCount)
  }
  $lblTestState.ForeColor = if ($openCount -gt 0) { $green } else { $red }
})

# ping continuu: ruleaza pe timer pana la apasarea butonului de oprire
$script:pingHost = ''
$script:pingTimeout = 1000
$script:pingSent = 0
$script:pingOk = 0

$pingTimer = New-Object System.Windows.Forms.Timer
$pingTimer.Interval = 1000
$pingTimer.Add_Tick({
  $script:pingSent++
  try {
    $p = New-Object System.Net.NetworkInformation.Ping
    $r = $p.Send($script:pingHost, $script:pingTimeout)
    if ($r.Status -eq 'Success') {
      $script:pingOk++
      Log-To $logTest ("ping {0} -> {1} ms (TTL {2})" -f $script:pingHost, $r.RoundtripTime, $r.Options.Ttl)
    } else {
      Log-To $logTest ("ping {0} -> {1}" -f $script:pingHost, $r.Status)
    }
  } catch {
    Log-To $logTest ('ping eroare: ' + $_.Exception.Message)
  }
  $lost = $script:pingSent - $script:pingOk
  $lblPingState.Text = ("PING (gazda, nu portul) {0}: {1} trimise, {2} raspunsuri, {3} pierdute" -f $script:pingHost, $script:pingSent, $script:pingOk, $lost)
  $lblPingState.ForeColor = if ($script:pingOk -gt 0 -and $lost -eq 0) { $green } elseif ($script:pingOk -gt 0) { $amber } else { $red }
})

function Stop-Ping {
  $pingTimer.Stop()
  $btnPing.Text = 'Ping ICMP'
  if ($script:pingSent -gt 0) { Log-To $logTest ('ping oprit - ' + $script:pingOk + '/' + $script:pingSent + ' raspunsuri') }
}

$btnPing.Add_Click({
  if ($pingTimer.Enabled) { Stop-Ping; return }
  $h = $txtTestHost.Text.Trim()
  if (-not $h) { [System.Windows.Forms.MessageBox]::Show('Completeaza IP-ul sau host-ul.'); return }
  $to = 1000
  if (-not [int]::TryParse($txtTestTimeout.Text, [ref]$to)) { $to = 1000 }
  $script:pingHost = $h
  $script:pingTimeout = $to
  $script:pingSent = 0
  $script:pingOk = 0
  $pingTimer.Interval = [Math]::Max(300, $to)
  $btnPing.Text = 'Opreste ping'
  $lblPingState.Text = 'Ping continuu...'; $lblPingState.ForeColor = $amber
  Log-To $logTest ('ping continuu catre ' + $h + ' - ICMP testeaza gazda, NU portul (apasa Opreste ping)')
  $pingTimer.Start()
})

$btnTestClear.Add_Click({ $logTest.Clear() })

# ---------------- inchidere ----------------
$form.Add_FormClosing({
  $timer.Stop(); $lisTimer.Stop(); $pingTimer.Stop()
  if ($script:listener) { try { $script:listener.Stop(); $script:listener.Close() } catch {} }
  if ($script:tcpL) { try { $script:tcpL.Stop() } catch {} }
  if ($script:udpL) { try { $script:udpL.Close() } catch {} }
})

Write-Log 'Alege folderul cu index.html, apoi Porneste.'
Log-To $logLis 'Deschide un port ca sa verifici daca e accesibil din retea.'
Log-To $logTest 'Completeaza IP si port, apoi Testeaza portul.'
Log-To $logTest 'Atentie: ping-ul ICMP raspunde pentru gazda, chiar daca portul e inchis.'
[void]$form.ShowDialog()
