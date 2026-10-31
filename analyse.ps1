param([string]$Key, [string]$Scratch, [string]$OutDir)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

function Decode-Polyline([string]$enc) {
  $pts = New-Object System.Collections.ArrayList
  [int]$i = 0; [long]$la = 0; [long]$lo = 0
  while ($i -lt $enc.Length) {
    for ($k = 0; $k -lt 2; $k++) {
      [int]$shift = 0; [long]$res = 0; [int]$b = 0
      do { $b = [int][char]$enc[$i] - 63; $i++; $res = $res -bor ([long]($b -band 31) -shl $shift); $shift += 5 } while ($b -ge 32)
      [long]$d = 0
      if (($res -band 1) -eq 1) { $d = -1 - ($res -shr 1) } else { $d = $res -shr 1 }
      if ($k -eq 0) { $la += $d } else { $lo += $d }
    }
    [void]$pts.Add(@(([double]$la / 1e5), ([double]$lo / 1e5)))
  }
  return ,$pts
}
function Dist($a, $b) { $dy = ($b[0] - $a[0]) * 111320; $dx = ($b[1] - $a[1]) * 111320 * [Math]::Cos($a[0] * [Math]::PI / 180); [Math]::Sqrt($dx * $dx + $dy * $dy) }
function Bearing($a, $b) { $r = [Math]::PI / 180; $y = [Math]::Sin(($b[1] - $a[1]) * $r) * [Math]::Cos($b[0] * $r); $x = [Math]::Cos($a[0] * $r) * [Math]::Sin($b[0] * $r) - [Math]::Sin($a[0] * $r) * [Math]::Cos($b[0] * $r) * [Math]::Cos(($b[1] - $a[1]) * $r); $h = [Math]::Atan2($y, $x) / $r; if ($h -lt 0) { $h += 360 }; [int]$h }

# Fraction of open sky in an upward-looking image (blue/bright low-saturation pixels)
function Sky-Fraction([string]$file) {
  $bmp = [System.Drawing.Bitmap]::FromFile($file)
  $sky = 0; $n = 0
  for ($x = 0; $x -lt $bmp.Width; $x += 2) { for ($y = 0; $y -lt $bmp.Height; $y += 2) {
    $c = $bmp.GetPixel($x, $y); $mx = [Math]::Max($c.R, [Math]::Max($c.G, $c.B)); $mn = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
    $sat = if ($mx -eq 0) { 0 } else { ($mx - $mn) / $mx }
    if (($c.B -ge $c.R -and $c.B -ge ($c.G - 5) -and $mx -gt 150) -or ($mx -gt 215 -and $sat -lt 0.12)) { $sky++ }
    $n++ } }
  $bmp.Dispose(); return [Math]::Round($sky / $n, 3)
}

$routes = @(
  @{ key = "direct"; file = "routes_alt.json" },
  @{ key = "estate"; file = "route_east.json" },
  @{ key = "west"; file = "route_west.json" }
)
New-Item -ItemType Directory -Force "$OutDir\sky" | Out-Null
$result = @()
foreach ($r in $routes) {
  $j = Get-Content "$Scratch\$($r.file)" -Raw | ConvertFrom-Json
  $route = $j.routes[0]
  $pts = Decode-Polyline $route.polyline.encodedPolyline
  # sample every 40 m along the line
  $samples = @(); $acc = 0; $next = 0
  for ($i = 1; $i -lt $pts.Count; $i++) {
    $p0 = $pts[$i - 1]; $p1 = $pts[$i]
    $seg = [double](Dist $p0 $p1)
    while ($next -le $acc + $seg -and $seg -gt 0) {
      $t = ($next - $acc) / $seg
      $samples += , @(($p0[0] + $t * ($p1[0] - $p0[0])), ($p0[1] + $t * ($p1[1] - $p0[1])), $next)
      $next += 40
    }
    $acc += $seg
  }
  $out = @(); $n = 0
  foreach ($s in $samples) {
    $n++
    $meta = Invoke-RestMethod "https://maps.googleapis.com/maps/api/streetview/metadata?location=$($s[0]),$($s[1])&radius=20&source=outdoor&key=$Key"
    $rec = [ordered]@{ m = [int]$s[2]; lat = [Math]::Round($s[0], 6); lng = [Math]::Round($s[1], 6); sky = $null; img = $null }
    if ($meta.status -eq "OK") {
      $f = "$OutDir\sky\$($r.key)-$('{0:d2}' -f $n).jpg"
      Invoke-WebRequest "https://maps.googleapis.com/maps/api/streetview?size=160x160&location=$($s[0]),$($s[1])&radius=20&pitch=90&fov=120&source=outdoor&key=$Key" -OutFile $f -UseBasicParsing
      $rec.sky = Sky-Fraction $f
      $rec.img = "photos/sky/$($r.key)-$('{0:d2}' -f $n).jpg"
    }
    $out += [pscustomobject]$rec
  }
  $steps = $route.legs[0].steps
  $stairs = @($steps | Where-Object { $_.navigationInstruction.instructions -match "steps|stairs" }).Count
  $mainRoad = ($steps | Where-Object { $_.navigationInstruction.instructions -match "onto .*(Ave|Avenue|Road)" } | Measure-Object distanceMeters -Sum).Sum
  $result += [pscustomobject]@{
    key = $r.key; distance = $route.distanceMeters; seconds = [int]($route.duration -replace "s", "")
    stairs = $stairs; turns = $steps.Count; mainRoadM = [int]$mainRoad
    steps = @($steps | ForEach-Object { [pscustomobject]@{ m = $_.distanceMeters; text = $_.navigationInstruction.instructions; lat = $_.startLocation.latLng.latitude; lng = $_.startLocation.latLng.longitude } })
    samples = $out
  }
  Write-Host "$($r.key): $($samples.Count) samples"
}
$result | ConvertTo-Json -Depth 6 | Out-File "$Scratch\analysis.json" -Encoding utf8
