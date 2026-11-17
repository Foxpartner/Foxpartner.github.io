# Adds NEW YouTube videos/shorts and Patreon posts to catalogo.csv, then rebuilds data/catalog.js.
# Existing rows are never changed, so your manual edits in catalogo.csv are kept.
# Run:  double-click update-catalog.bat   (or: powershell -ExecutionPolicy Bypass -File tools\update-catalog.ps1)
# -Unattended: used by the daily scheduled task (never waits for input, writes tools\update-log.txt)
param([switch]$DryRun, [switch]$Unattended)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Unattended) {
  $log = Join-Path $PSScriptRoot 'update-log.txt'
  if ((Test-Path $log) -and (Get-Item $log).Length -gt 1MB) { Remove-Item $log -Force }
  Start-Transcript -Path $log -Append | Out-Null
}
. (Join-Path $PSScriptRoot 'catalog-rules.ps1')

$channel   = 'https://www.youtube.com/@thefoxpartner'
$campaign  = '15646611'
$csvPath   = Join-Path $root 'catalogo.csv'
$ignore    = Join-Path $PSScriptRoot 'ignore-urls.txt'
$bin       = Join-Path $PSScriptRoot 'bin'
$ytdlp     = Join-Path $bin 'yt-dlp.exe'
$tmp       = Join-Path $env:TEMP ('fox-update-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp, $bin | Out-Null

function Say([string]$msg, [string]$color = 'Gray') { Write-Host $msg -ForegroundColor $color }

try {
  # ---------- 0. current catalog ----------
  $existing = @(Import-Csv $csvPath -Encoding UTF8)
  $known = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($r in $existing) { [void]$known.Add($r.url) }
  if (Test-Path $ignore) { foreach ($u in (Get-Content $ignore -Encoding utf8)) { $u = $u.Trim(); if ($u -and -not $u.StartsWith('#')) { [void]$known.Add($u) } } }
  Say "Catalog now: $($existing.Count) reactions"

  # ---------- 1. yt-dlp (download / self-update) ----------
  if (-not (Test-Path $ytdlp)) {
    Say 'Downloading yt-dlp...'
    curl.exe -sL -o $ytdlp 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Could not download yt-dlp.' }
  } else {
    & $ytdlp -U --quiet 2>$null | Out-Null
  }

  # ---------- 2. YouTube ----------
  Say 'Reading YouTube channel...'
  $ytFile = Join-Path $tmp 'yt.tsv'
  foreach ($tab in 'videos', 'shorts') {
    & $ytdlp --flat-playlist --quiet --no-warnings --extractor-args 'youtubetab:approximate_date' --print-to-file "%(id)s`t%(upload_date)s`t%(duration)s`t%(title)s" $ytFile "$channel/$tab"
  }
  $ytLines = @(); if (Test-Path $ytFile) { $ytLines = @(Get-Content $ytFile -Encoding utf8 | Where-Object { $_ }) }
  if ($ytLines.Count -lt 10) { throw "YouTube returned only $($ytLines.Count) videos - something went wrong, nothing was changed." }
  Say "  $($ytLines.Count) videos/shorts on the channel"

  # ---------- 3. Patreon ----------
  Say 'Reading Patreon posts...'
  $url = "https://www.patreon.com/api/posts?filter[campaign_id]=$campaign&filter[contains_exclusive_posts]=true&filter[is_draft]=false&fields[post]=title,published_at,url,post_type&sort=-published_at&json-api-version=1.0&page[count]=100"
  $pat = @(); $page = 0; $pf = Join-Path $tmp 'pat.json'
  while ($url -and $page -lt 50) {
    $page++
    curl.exe -g -s -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -o $pf $url
    $o = Get-Content $pf -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($p in $o.data) {
      if ($p.attributes.post_type -eq 'text_only') { continue }   # notes / welcome posts, not reactions
      $pat += [pscustomobject]@{ date = ([string]$p.attributes.published_at).Substring(0, 10); title = ([string]$p.attributes.title).Trim(); url = $p.attributes.url }
    }
    $url = $o.links.next
  }
  if ($pat.Count -eq 0) { throw 'Patreon returned no posts - something went wrong, nothing was changed.' }
  Say "  $($pat.Count) reaction posts on Patreon"

  # ---------- 4. new items ----------
  $new = New-Object System.Collections.Generic.List[object]
  foreach ($line in $ytLines) {
    $f = $line -split "`t", 4
    $u = "https://www.youtube.com/watch?v=$($f[0])"
    if ($known.Contains($u)) { continue }
    $title = ([string]$f[3]).Trim()
    if ($title -match 'PATREON ANNOUNCEMENT') { continue }
    $a = Get-Artist $title
    $date = ''; if ($f[1] -match '^\d{8}$') { $date = $f[1].Substring(0,4) + '-' + $f[1].Substring(4,2) + '-' + $f[1].Substring(6,2) }
    if (-not $date) { $date = (Get-Date).ToString('yyyy-MM-dd') }
    $new.Add([pscustomobject]@{ artist = $a[0]; group = $a[1]; featuring = (Get-Feat $title $a[1]); reacted = (Get-Clean $title); type = (Get-Type $title); platform = 'YouTube'; date = $date; url = $u; original_title = $title })
    [void]$known.Add($u)
  }
  foreach ($p in $pat) {
    if ($known.Contains($p.url)) { continue }
    $title = $p.title; $a = Get-Artist $title
    $new.Add([pscustomobject]@{ artist = $a[0]; group = $a[1]; featuring = (Get-Feat $title $a[1]); reacted = (Get-Clean $title); type = (Get-Type $title); platform = 'Patreon'; date = $p.date; url = $p.url; original_title = $title })
    [void]$known.Add($p.url)
  }

  # catalog rows that are no longer online (deleted / private) - only reported, never removed
  $online = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($line in $ytLines) { [void]$online.Add('https://www.youtube.com/watch?v=' + ($line -split "`t", 2)[0]) }
  foreach ($p in $pat) { [void]$online.Add($p.url) }
  $gone = @($existing | Where-Object { -not $online.Contains($_.url) })

  Say ''
  if ($new.Count -eq 0) {
    Say 'No new reactions. The catalog is up to date.' Green
  } else {
    Say "NEW reactions found: $($new.Count)" Green
    foreach ($n in ($new | Sort-Object date -Descending)) {
      $who = $n.artist; if (-not $who) { $who = '(artist not recognized!)' }
      $feat = ''; if ($n.featuring) { $feat = "  [with $($n.featuring)]" }
      Say ("  {0}  {1,-8} [{2}] {3}{4}" -f $n.date, $n.platform, $who, $n.reacted, $feat)
    }
    $unknown = @($new | Where-Object { -not $_.artist })
    if ($unknown.Count) { Say "  -> $($unknown.Count) without artist: fill the 'artist' and 'group' columns in catalogo.csv and run this again." Yellow }
  }
  if ($gone.Count) {
    Say ''
    Say "Not found online anymore ($($gone.Count)) - kept in the catalog; delete the row in catalogo.csv if you want:" Yellow
    foreach ($g in $gone) { Say "  $($g.platform)  $($g.artist) - $($g.reacted)  $($g.url)" Yellow }
  }

  if ($DryRun) { Say ''; Say 'Dry run: nothing was saved.' Cyan; return }

  # ---------- 5. save ----------
  if ($new.Count) {
    # stable sort: newest first, new items before older ones of the same day, existing order kept
    [object[]]$merged = $new.ToArray() + @($existing)
    $all = @([Linq.Enumerable]::OrderByDescending($merged, [Func[object, string]] { param($x) [string]$x.date }))
    $out = Join-Path $tmp 'catalogo.csv'
    $all | Export-Csv $out -NoTypeInformation -Encoding UTF8
    $copied = $false; $tries = 0
    while (-not $copied) {
      try { Copy-Item $out $csvPath -Force -ErrorAction Stop; $copied = $true }
      catch {
        $tries++
        if ($Unattended) {
          if ($tries -ge 20) { throw 'catalogo.csv stayed open in another program (Excel?) for 10 minutes - try again later.' }
          Say 'catalogo.csv is open in another program, waiting 30s...' Yellow; Start-Sleep 30
        } else { Say ''; Say 'catalogo.csv is open in another program (Excel?). Close it and press Enter...' Yellow; [void][Console]::ReadLine() }
      }
    }
    Say "Saved catalogo.csv ($($all.Count) reactions)" Green
  }
  & (Join-Path $PSScriptRoot 'build-data.ps1') | Out-Null
  Say 'Website data updated (data/catalog.js).' Green
}
catch {
  Say ''
  Say "ERROR: $($_.Exception.Message)" Red
  $failed = $true
}
finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  if ($Unattended) { Say "--- finished $(Get-Date -Format 'yyyy-MM-dd HH:mm')"; Say ''; Stop-Transcript | Out-Null }
}
if ($failed) { exit 1 }
