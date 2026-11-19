# Shared classification rules (artist, feats, type, clean title). Used by build-catalog.ps1 and update-catalog.ps1.

# --- artist patterns: [regex, display name, group] ---
# Special / solo patterns checked first (in order); then the earliest match among the rest.
$special = @(
  @('Who is Jimin', 'Jimin', 'BTS'),
  @('Who is Jungkook', 'Jungkook', 'BTS'),
  @('Who is Jin\b', 'Jin', 'BTS'),
  @('Who is V\b', 'V', 'BTS'),
  @('Who is j-hope', 'j-hope', 'BTS'),
  @('Who is RM\b', 'RM', 'BTS'),
  @('Who is AGUST D', 'Agust D', 'BTS'),
  @('^\s*(\[CHOREOGRAPHY\]\s*)?j-hope', 'j-hope', 'BTS'),
  @('^\s*HAN "', 'HAN', 'Stray Kids'),
  @('^\s*Hyunjin', 'Hyunjin', 'Stray Kids'),
  @('^\s*YEJI X', 'YEJI (collab)', 'ITZY'),
  @('^\s*Lee Know X', 'Lee Know, Hyunjin, Felix', 'Stray Kids'),
  @('^\s*Dany and Orianthi', 'The Warning', 'The Warning'),
  @('^\s*Changes \(Live From Villa Park', 'YUNGBLUD', 'YUNGBLUD'),
  @('^\s*Ren - ', 'Ren', 'Ren'),
  @('Sokoninaru', 'Sokoninaru', 'Sokoninaru'),
  @('^@TheWarning', 'The Warning', 'The Warning'),
  @('PATREON ANNOUNCEMENT', 'Channel news', 'Channel news')
)
$artists = @(
  @('The Warning', 'The Warning', ''), @('ATEEZ', 'ATEEZ', ''), @('\bBTS\b', 'BTS', ''),
  @('Stray Kids', 'Stray Kids', ''), @('BABYMONSTER', 'BABYMONSTER', ''), @('BABYMETAL', 'BABYMETAL', ''),
  @('\bXG\b|XGALX', 'XG', ''), @('LE SSERAFIM', 'LE SSERAFIM', ''), @('\bILLIT\b', 'ILLIT', ''),
  @('KATSEYE', 'KATSEYE', ''), @('NMIXX', 'NMIXX', ''), @('\baespa\b', 'aespa', ''), @('CORTIS', 'CORTIS', ''),
  @('\bXLOV\b', 'XLOV', ''), @('Hearts2Hearts', 'Hearts2Hearts', ''), @('\bITZY\b', 'ITZY', ''),
  @('MEOVV', 'MEOVV', ''), @('ENHYPEN', 'ENHYPEN', ''), @('\bTXT\b', 'TXT', ''), @('\bRIIZE\b', 'RIIZE', ''),
  @('LNGSHOT', 'LNGSHOT', ''), @('ALLDAY PROJECT', 'ALLDAY PROJECT', ''), @('BLACKPINK', 'BLACKPINK', ''),
  @('\bJISOO\b', 'JISOO', 'BLACKPINK'), @('\bJENNIE\b', 'JENNIE', 'BLACKPINK'), @('\bROS.\s*-', 'ROSE', 'BLACKPINK'),
  @('\bLISA\b', 'LISA', 'BLACKPINK'), @('BIGBANG', 'BIGBANG', ''), @('T\.O\.P', 'T.O.P', 'BIGBANG'),
  @('\bTWICE\b', 'TWICE', ''), @('SEVENTEEN', 'SEVENTEEN', ''), @('NewJeans', 'NewJeans', ''),
  @('KiiiKiii', 'KiiiKiii', ''), @('UNCHILD', 'UNCHILD', ''), @('\bno na\b', 'no na', ''),
  @('\bmanifest\b', 'manifest', ''), @('xikers', 'xikers', ''), @('TREASURE', 'TREASURE', ''),
  @('A2O LITE', 'A2O LITE', ''), @('Alice Syndrome', 'Alice Syndrome', ''), @('YG NEXT MONSTER', 'YG NEXT MONSTER', ''),
  @('YEONJUN', 'YEONJUN', 'TXT'), @('K/DA', 'K/DA', ''), @('True Damage', 'True Damage', ''),
  @('Linkin Park', 'Linkin Park', ''), @('Sleep Token', 'Sleep Token', ''), @('YUNGBLUD', 'YUNGBLUD', ''),
  @('\bPoppy\b', 'Poppy', ''), @('BAND[- ]?MAID', 'BAND-MAID', ''), @('Freeze the Fall', 'Freeze the Fall', ''),
  @('MIXED UP EVERYTHING', 'MIXED UP EVERYTHING', ''), @('NOVELISTS', 'NOVELISTS', ''), @('VIOLETT', 'VIOLETT', ''),
  @('BAD OMENS', 'BAD OMENS', ''), @('Nene Royal', 'Nene Royal', ''), @('The Big Push', 'The Big Push', ''),
  @('VoicePlay', 'VoicePlay', ''), @('Pentatonix', 'Pentatonix', ''), @('livia Rodrigo', 'Olivia Rodrigo', ''),
  @('AZ Chike', 'AZ Chike', ''), @('Ice Nine Kills', 'Ice Nine Kills', ''), @('Against The Current', 'Against The Current', ''),
  @('Spiritbox', 'Spiritbox', ''), @('Halsey', 'Halsey', ''), @('Twenty One Pilots', 'Twenty One Pilots', ''),
  @('Aerosmith', 'Aerosmith', ''), @('Pabllo Vittar', 'Pabllo Vittar', ''), @('Maggie Lindemann', 'Maggie Lindemann', ''),
  @('Dead Poet Society', 'Dead Poet Society', ''), @('P1Harmony', 'P1Harmony', '')
)

function Get-GuessedArtist([string]$t) {
  $q = [string][char]0x201C + [char]0x201D + [char]0x2018 + [char]0x2019 + [char]0x300C + [char]0x3010
  $dash = [string][char]0x2013 + [char]0x2014
  # remove intros like "Former DANCER reacts to", "Who is", "First time hearing", "Proud Brazilian reacts to"
  $intro = '(?i)^\s*((former|forner)\s+dancer\s+("?reacts?"?\s*(\([^)]*\))?\s*(to\s+)?|falling in love with\s+)|proud brazilian reacts to\s+|first time (hearing|listening to|watching)\s+|learning about\s+|who is\s+|meet\s+)'
  $h = $t -replace $intro, ''
  $hadIntro = ($h -ne $t)
  $h = $h -replace '(?i)\s+\d\s*in\s*1\b.*$', '' -replace '(?i)\s+for the first time\b.*$', ''
  # cut at the first separator: " - ", " / ", " | ", "(", "[", quotes, ":" or " ~ "
  $h = [regex]::Split($h, '\s[-' + $dash + '/|~]\s|\s?[(\[":' + $q + ']|\s''')[0]
  # drop Korean / Japanese / Chinese text, then keep only the first of several artists
  $h = $h -replace ('[' + [char]0x1100 + '-' + [char]0x11FF + [char]0x3040 + '-' + [char]0x30FF + [char]0x3400 + '-' + [char]0x9FFF + [char]0xAC00 + '-' + [char]0xD7A3 + ']'), ''
  $h = [regex]::Split($h, ',\s|\s(x|X|and|&|feat\.?|ft\.?|with)\s')[0]
  $h = $h -replace '(?i)\s+(dance practice|choreography|official|m/?v|music video|teaser|visualizer|live)\b.*$', ''
  $h = $h.Trim(" '.?!-")
  $words = @($h -split '\s+').Count
  $min = 2; if ($hadIntro) { $min = 1 }   # "Who is V???" -> V
  if ($h.Length -lt $min -or $h.Length -gt 40 -or $words -gt 5) { return '' }
  if ($h -match '(?i)reaction|react|first time|official|episode|\bfull\b|\blive\b|cover|dancer|tier list|\brank\b|inside the studio|tourists|performance|audition') { return '' }
  return $h
}

function Get-Artist([string]$t) {
  $script:artistGuessed = $false
  foreach ($a in $special) { if ($t -match $a[0]) { return @($a[1], $a[2]) } }
  $best = $null; $bestIdx = [int]::MaxValue
  foreach ($a in $artists) {
    $m = [regex]::Match($t, $a[0], 'IgnoreCase')
    if ($m.Success -and $m.Index -lt $bestIdx) { $bestIdx = $m.Index; $best = $a }
  }
  if ($best) { $g = $best[2]; if (-not $g) { $g = $best[1] }; return @($best[1], $g) }
  # new artist not in the list yet: use the start of the title, e.g. "P1Harmony (...) - 'BLOW UP' MV" -> P1Harmony
  $script:artistGuessed = $true
  $name = Get-GuessedArtist $t
  if ($name) { return @($name, $name) }
  return @('', '')
}

# --- other artists that appear in a title (feats / collabs / covers with guests) ---
# [pattern, artist name, regex option]  - artists that only show up as feats/guests are listed here too
$featExtra = @(
  @('G-DRAGON', 'BIGBANG', 'IgnoreCase'), @('GISELLE', 'aespa', 'IgnoreCase'), @('j-hope', 'BTS', 'IgnoreCase'),
  @('HYUNJIN', 'Stray Kids', 'IgnoreCase'), @('YEJI', 'ITZY', 'IgnoreCase'),
  @('Tyler, The Creator', 'Tyler, The Creator', 'IgnoreCase'), @('Chappell Roan', 'Chappell Roan', 'IgnoreCase'),
  @('\bSeori\b', 'Seori', 'IgnoreCase'), @('Megan Thee Stallion', 'Megan Thee Stallion', 'IgnoreCase'),
  @('Juicy J', 'Juicy J', 'IgnoreCase'), @('i-dle', '(G)I-DLE', 'IgnoreCase'), @('Sophie Powers', 'Sophie Powers', 'IgnoreCase'),
  @('Mimi Webb', 'Mimi Webb', 'IgnoreCase'), @('Madison Beer', 'Madison Beer', 'IgnoreCase'), @('Jaira Burns', 'Jaira Burns', 'IgnoreCase'),
  @('Lexie Liu', 'Lexie Liu', 'IgnoreCase'), @('\bBazzi\b', 'Bazzi', 'IgnoreCase'), @('Anderson \.Paak', 'Anderson .Paak', 'IgnoreCase'),
  @('GloRilla', 'GloRilla', 'IgnoreCase'), @('Travis Barker', 'Travis Barker', 'IgnoreCase'),
  @('Car.n Le.n', ('Car' + [char]0xED + 'n Le' + [char]0xF3 + 'n'), 'IgnoreCase'), @('Orianthi', 'Orianthi', 'IgnoreCase'),
  @('AMY LEE', 'Amy Lee', 'IgnoreCase'), @('COURTNEY LAPLANTE', 'Spiritbox', 'IgnoreCase'), @('\bLiSA\b', 'LiSA', 'None'),
  @('Grace Kinstler', 'Grace Kinstler', 'IgnoreCase'), @('Anthony Gargiula', 'Anthony Gargiula', 'IgnoreCase'),
  @('J\.None', 'J.None', 'IgnoreCase'), @('of HANA', 'HANA', 'None'), @('JULIE|KISSOFLIFE|KISS OF LIFE', 'KISS OF LIFE', 'None'),
  @('Steve Aoki', 'Steve Aoki', 'IgnoreCase'), @('youjeen', 'youjeen', 'IgnoreCase')
)
$caseSensitive = @('LISA', 'JISOO', 'JENNIE', 'ROSE', 'T.O.P')
function Get-Feat([string]$t, [string]$mainGroup) {
  # remove known false positives before scanning
  $scan = $t -replace 'MONA LISA', '' -replace 'JISOO, MOMOKA of HANA', 'of HANA' -replace 'Cover \(Bruno Mars, Anderson \.Paak, Silk Sonic\)', ''
  $found = New-Object System.Collections.Generic.List[string]
  foreach ($a in $artists) {
    $g = $a[2]; if (-not $g) { $g = $a[1] }
    $opt = 'IgnoreCase'; if ($caseSensitive -contains $a[1]) { $opt = 'None' }
    if ([regex]::IsMatch($scan, $a[0], $opt) -and $g -ne $mainGroup -and -not $found.Contains($g)) { $found.Add($g) }
  }
  foreach ($e in $featExtra) {
    if ([regex]::IsMatch($scan, $e[0], $e[2]) -and $e[1] -ne $mainGroup -and -not $found.Contains($e[1])) { $found.Add($e[1]) }
  }
  return ($found -join '; ')
}

function Get-Type([string]$t) {
  $i = 'IgnoreCase'
  if ($t -match '^@\w+') { return 'Short' }
  if ([regex]::IsMatch($t, 'acapella|medley|Enter Sandman \(evolution|You Oughta Know', $i)) { return 'Cover' }
  if ([regex]::IsMatch($t, '\bMMA 20|BAND Ver|in BUSAN|acoustic|' + [char]0xC778 + [char]0xAE30 + [char]0xAC00 + [char]0xC694, $i) -and -not [regex]::IsMatch($t, 'full (album|ep)', $i)) { return 'Live / Stage' }
  if ([regex]::IsMatch($t, 'Art Film', $i)) { return 'Dance / Performance Video' }
  if ([regex]::IsMatch($t, 'full (album|ep)|\(album\)|ep/album|album/ep', $i) -and -not [regex]::IsMatch($t, 'full album on patreon', $i)) { return 'Full Album / EP' }
  if ([regex]::IsMatch($t, '\d in 1|double reaction|2 in 1', $i)) { return 'Multi (several songs)' }
  if ([regex]::IsMatch($t, 'WANTEEZ|LPTV|TEDx|Truth or Drink|Last Meal|Aftermovie|Inside the Studio|Killing Voice|Tourists in|Super Bowl|Rebranding|Choreo-Record|X Anniversary|primera vez', $i)) { return 'Show / Behind the Scenes' }
  if ([regex]::IsMatch($t, 'tier list|favorite THE WARNING song|ANNOUNCEMENT|album of the year|Lets talk', $i)) { return 'Talk / Review' }
  $mv = [regex]::IsMatch($t, 'M/V|\bMV\b|music video|official video|visualizer|lyric video|trailer|teaser|special clip|\bvideo\b', $i)
  $dance = [regex]::IsMatch($t, 'dance practice|choreograph|dance performance|performance video|performance film|studio choom|dance\)', $i)
  if ($mv -and $dance -and -not [regex]::IsMatch($t, '^[^/]*(performance video|performance film)[^/]*$', $i)) { if ([regex]::IsMatch($t, 'dance practice|choreograph', $i)) { return 'MV + Dance Practice' } }
  if ($dance) { return 'Dance / Performance Video' }
  if ([regex]::IsMatch($t, '\bcover\b|covered|SKZ-PLAYER|Live Lounge', $i)) { return 'Cover' }
  if ([regex]::IsMatch($t, '\blive\b|gayo|mama awards|music ?bank|musiccore|got talent|\bAGT\b|concert|festival|hellfest|\bVMA|stage|sessions|first take|music lounge|full show|golden disc|lollapalooza|performance|MusicCore', $i)) { return 'Live / Stage' }
  return 'Music Video'
}

function Get-Clean([string]$t) {
  $c = $t.Trim()
  $c = [regex]::Replace($c, '^(former|forner) DANCER\s*("?reacts"?)(\([^)]*\))?\s*(to\s*)?(\([^)]*\)\s*)?', '', 'IgnoreCase')
  $c = [regex]::Replace($c, '^(Proud Brazilian reacts to|First time hearing|Learning about)\s*', '', 'IgnoreCase')
  # multi / double reactions: the songs come right after "REACTION - "
  $mm = [regex]::Match($c, '^(.*?)(\d in 1 |double )reaction\W*-\s*(.+?)(\s-\s|\s/\s|(?<=\S)/\s|$)', 'IgnoreCase')
  if ($mm.Success) {
    $pre = [regex]::Replace($mm.Groups[1].Value, '[\s/\-]+$', '')
    $c = ($pre + ' (' + $mm.Groups[2].Value.Trim() + '): ' + $mm.Groups[3].Value).Trim()
    $c = [regex]::Replace($c, '^\s*\(', '(')
    return [regex]::Replace($c, '\s{2,}', ' ').Trim()
  }
  # content = text before the first " / " (the rest is usually commentary)
  $parts = [regex]::Split($c, ' / |(?<=\S)/ ')
  if ($parts.Count -gt 1) {
    $first = $parts[0].Trim()
    if ($first -notmatch ' - ' -and $first.Length -le 15 -and $parts[1] -notmatch '^\s*(reaction|reacton)') { $c = $first + ' - ' + $parts[1] }
    elseif ($first.Length -ge 4) { $c = $first }
  }
  $c = [regex]::Replace($c, [string][char]0x3010 + 'Official Music Video' + [char]0x3011, ' ')
  $c = [regex]::Replace($c, '\s*[-/]?\s*(REACTION|REACTON|Reaction)\b.*$', '')
  $hangul = '\(\s*[' + [char]0xAC00 + '-' + [char]0xD7A3 + '\s]+\)'
  $c = [regex]::Replace($c, $hangul, '')
  $c = [regex]::Replace($c, '\s{2,}', ' ')
  $c = [regex]::Replace($c, '^livia Rodrigo', 'Olivia Rodrigo')
  return $c.Trim(' ', '-', '/', '|')
}
