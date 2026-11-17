param([string]$YtFile, [string]$PatFile, [string]$OutFile)
. (Join-Path $PSScriptRoot 'catalog-rules.ps1')

$rows = New-Object System.Collections.Generic.List[object]
foreach ($line in (Get-Content $YtFile -Encoding utf8)) {
  if (-not $line) { continue }
  $f = $line -split "`t", 4
  $title = $f[3]
  if ($title -match 'PATREON ANNOUNCEMENT') { continue }   # channel news, not a reaction
  $a = Get-Artist $title
  $date = ''; if ($f[1] -match '^\d{8}$') { $date = $f[1].Substring(0,4) + '-' + $f[1].Substring(4,2) + '-' + $f[1].Substring(6,2) }
  $kind = 'youtube'; if ($f[2] -eq 'NA') { $kind = 'youtube short' }
  $rows.Add([pscustomobject]@{ artist = $a[0]; group = $a[1]; featuring = (Get-Feat $title $a[1]); reacted = (Get-Clean $title); type = (Get-Type $title); platform = 'YouTube'; date = $date; url = "https://www.youtube.com/watch?v=$($f[0])"; original_title = $title })
}
foreach ($p in (Import-Csv $PatFile -Encoding UTF8)) {
  $title = $p.title; $a = Get-Artist $title
  $rows.Add([pscustomobject]@{ artist = $a[0]; group = $a[1]; featuring = (Get-Feat $title $a[1]); reacted = (Get-Clean $title); type = (Get-Type $title); platform = 'Patreon'; date = $p.date; url = $p.url; original_title = $title })
}
$rows | Sort-Object date -Descending | Export-Csv $OutFile -NoTypeInformation -Encoding UTF8
"rows: $($rows.Count)"
"no artist: $(($rows | Where-Object { -not $_.artist }).Count)"
$rows | Group-Object type | Sort-Object Count -Descending | ForEach-Object { "  $($_.Name): $($_.Count)" }
