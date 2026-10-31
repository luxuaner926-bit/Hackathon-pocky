Add-Type -AssemblyName System.Drawing
$d = "C:\Users\28792\Desktop\AR5958A AI for Urban Planning\Hackathon\demo\photos"

function Features([string]$file) {
  $src = [System.Drawing.Image]::FromFile($file)
  $bmp = New-Object System.Drawing.Bitmap 32, 24
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = "HighQualityBilinear"
  # crop off the bottom 8% (Google watermark strip) like the app does
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, 32, 24), 0, 0, $src.Width, [int]($src.Height * 0.92), "Pixel"); $g.Dispose(); $src.Dispose()
  $hist = New-Object double[] 19; $lum = New-Object double[] 768
  for ($y = 0; $y -lt 24; $y++) { for ($x = 0; $x -lt 32; $x++) {
    $c = $bmp.GetPixel($x, $y); $r = $c.R / 255; $gg = $c.G / 255; $b = $c.B / 255
    $mx = [Math]::Max($r, [Math]::Max($gg, $b)); $mn = [Math]::Min($r, [Math]::Min($gg, $b)); $v = $mx; $s = if ($mx -eq 0) { 0 } else { ($mx - $mn) / $mx }
    $lum[$y * 32 + $x] = 0.299 * $r + 0.587 * $gg + 0.114 * $b
    if ($s -lt 0.2 -or $v -lt 0.15) { $bin = 16 + [Math]::Min(2, [int][Math]::Floor($v * 3)) }
    else {
      $h = 0; $dl = $mx - $mn
      if ($mx -eq $r) { $h = (($gg - $b) / $dl) % 6 } elseif ($mx -eq $gg) { $h = ($b - $r) / $dl + 2 } else { $h = ($r - $gg) / $dl + 4 }
      $h = $h * 60; if ($h -lt 0) { $h += 360 }
      $bin = [Math]::Min(7, [int][Math]::Floor($h / 45)) * 2 + $(if ($s -lt 0.5) { 0 } else { 1 })
    }
    $hist[$bin] += 1 } }
  $bmp.Dispose()
  for ($i = 0; $i -lt 19; $i++) { $hist[$i] /= 768 }
  $grid = New-Object double[] 192
  for ($y = 0; $y -lt 12; $y++) { for ($x = 0; $x -lt 16; $x++) { $grid[$y * 16 + $x] = ($lum[(2 * $y) * 32 + 2 * $x] + $lum[(2 * $y) * 32 + 2 * $x + 1] + $lum[(2 * $y + 1) * 32 + 2 * $x] + $lum[(2 * $y + 1) * 32 + 2 * $x + 1]) / 4 } }
  $m = ($grid | Measure-Object -Average).Average; $sd = [Math]::Sqrt((($grid | ForEach-Object { ($_ - $m) * ($_ - $m) }) | Measure-Object -Average).Average) + 1e-6
  for ($i = 0; $i -lt 192; $i++) { $grid[$i] = ($grid[$i] - $m) / $sd }
  return @{ hist = $hist; grid = $grid }
}
function Score($a, $b) {
  $hi = 0; for ($i = 0; $i -lt 19; $i++) { $hi += [Math]::Min($a.hist[$i], $b.hist[$i]) }
  $ncc = 0; for ($i = 0; $i -lt 192; $i++) { $ncc += $a.grid[$i] * $b.grid[$i] }; $ncc /= 192
  return [Math]::Round(0.6 * $hi + 0.4 * [Math]::Max(0, $ncc), 3)
}
$cands = "amk-002","amk-003","amk-004","amk-005","amk-006","est-04","est-05","est-06","est-07"
$F = @{}; foreach ($c in $cands) { $F[$c] = Features "$d\$c.jpg" }
foreach ($t in "test-a","test-b","test-c","test-d") {
  $tf = Features "$d\$t.jpg"
  $res = $cands | ForEach-Object { [pscustomobject]@{ c = $_; s = (Score $tf $F[$_]) } } | Sort-Object s -Descending
  "$t -> " + (($res | Select-Object -First 4 | ForEach-Object { "$($_.c)=$($_.s)" }) -join "  ")
}
