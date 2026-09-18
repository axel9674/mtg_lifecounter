# Genera le immagini dell'icona dell'app.
#
# Il disegno riprende l'identita' visiva dell'app: fondo scuro, esagono bianco
# (lo stesso bordo del tasto centrale del menu, vedi _HexagonBorder in
# lib/main.dart) e il valore di vita "20" nel font delle cifre (MedulaOne).
#
# Produce in assets/launcher/:
#   icon.png            1024x1024 opaca, sfondo + esagono + cifre (icona classica)
#   icon_background.png 1024x1024 opaca, solo sfondo (adaptive icon, layer di fondo)
#   icon_foreground.png 1024x1024 trasparente, glifo dentro la safe zone (adaptive icon)
#   icon_monochrome.png 1024x1024 trasparente, glifo monocromatico (icone a tema, Android 13+)
#
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File tool\make_icon.ps1
# Le immagini cosi' prodotte vengono poi applicate alle piattaforme da
# `dart run flutter_launcher_icons` (vedi la sezione flutter_launcher_icons in
# pubspec.yaml).

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'assets\launcher'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$SIZE = 1024
$LIFE = '20'
$HEX_CORNER = 0.25

# Canvas usato per misurare l'inchiostro: sta larghissimo attorno al testo, cosi'
# le cifre non vengono mai tagliate o mandate a capo durante la misura.
$MEASURE = 1024

# Safe zone delle adaptive icon: il glifo deve stare dentro il cerchio di 66/108
# del layer, quindi il raggio dell'esagono resta sotto 0.30 * SIZE.
$HEX_LEGACY = $SIZE * 0.315
$HEX_ADAPTIVE = $SIZE * 0.285
$HEX_MONO = $SIZE * 0.270
$HEX_STROKE = $SIZE * 0.032

$COLOR_DIGITS = [System.Drawing.Color]::FromArgb(255, 0x12, 0x12, 0x12)
$COLOR_HEX = [System.Drawing.Color]::White
$COLOR_BG_TOP = [System.Drawing.Color]::FromArgb(255, 0x26, 0x26, 0x26)
$COLOR_BG_BOTTOM = [System.Drawing.Color]::FromArgb(255, 0x0a, 0x0a, 0x0a)

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $root 'assets\fonts\MedulaOne-Regular.ttf'))
$numberFamily = $pfc.Families[0]

function New-HexagonPath {
    param([double]$Radius, [double]$CenterX, [double]$CenterY, [double]$CornerRatio = $HEX_CORNER)

    $sides = 6
    $phase = [Math]::PI / 2  # vertice in alto e in basso, come _HexagonBorder
    $corners = @()
    for ($i = 0; $i -lt $sides; $i++) {
        $angle = $phase + 2 * [Math]::PI * $i / $sides
        $corners += [System.Drawing.PointF]::new(
            [float]($CenterX + $Radius * [Math]::Cos($angle)),
            [float]($CenterY + $Radius * [Math]::Sin($angle)))
    }

    $from = @()
    $to = @()
    $control = @()
    for ($i = 0; $i -lt $sides; $i++) {
        $corner = $corners[$i]
        $prev = $corners[(($i - 1 + $sides) % $sides)]
        $next = $corners[(($i + 1) % $sides)]
        $f = [System.Drawing.PointF]::new(
            [float]($corner.X + ($prev.X - $corner.X) * $CornerRatio),
            [float]($corner.Y + ($prev.Y - $corner.Y) * $CornerRatio))
        $t = [System.Drawing.PointF]::new(
            [float]($corner.X + ($next.X - $corner.X) * $CornerRatio),
            [float]($corner.Y + ($next.Y - $corner.Y) * $CornerRatio))
        $from += $f
        $to += $t
        $control += $corner
    }

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.StartFigure()
    $path.AddLine($to[$sides - 1], $from[0])
    for ($i = 0; $i -lt $sides; $i++) {
        # Gli angoli sono raccordati con una quadratica: la cubica con i punti di
        # controllo a 2/3 verso il vertice la riproduce esattamente.
        $c1 = [System.Drawing.PointF]::new(
            [float]($from[$i].X + ($control[$i].X - $from[$i].X) * 2 / 3),
            [float]($from[$i].Y + ($control[$i].Y - $from[$i].Y) * 2 / 3))
        $c2 = [System.Drawing.PointF]::new(
            [float]($to[$i].X + ($control[$i].X - $to[$i].X) * 2 / 3),
            [float]($to[$i].Y + ($control[$i].Y - $to[$i].Y) * 2 / 3))
        $path.AddBezier($from[$i], $c1, $c2, $to[$i])
    }
    $path.CloseFigure()
    return $path
}

function New-NumberFont {
    param([double]$FontSize)
    return [System.Drawing.Font]::new(
        $numberFamily,
        [float]$FontSize,
        [System.Drawing.FontStyle]::Regular,
        [System.Drawing.GraphicsUnit]::Pixel)
}

function New-CenteredFormat {
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    # NoWrap e' obbligatorio: con un font grande GDI+ altrimenti manda a capo il
    # testo quando la larghezza con i margini supera quella del riquadro, e la
    # seconda cifra finisce fuori dal canvas (spariva lo "0").
    $format.FormatFlags = [System.Drawing.StringFormatFlags]::NoClip -bor [System.Drawing.StringFormatFlags]::NoWrap
    return $format
}

# Riquadro dell'inchiostro realmente disegnato: le metriche del font (altezza di
# riga, spazio laterale) non sono simmetriche, quindi il testo si centra sulle
# cifre e non sulla scatola del layout.
function Get-InkBounds {
    param([System.Drawing.Bitmap]$Bitmap)

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 12) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt 0) { throw "Nessun pixel disegnato: impossibile misurare l'inchiostro." }

    return [pscustomobject]@{
        X = $minX
        Y = $minY
        Width = $maxX - $minX + 1
        Height = $maxY - $minY + 1
        CenterX = ($minX + $maxX) / 2.0
        CenterY = ($minY + $maxY) / 2.0
    }
}

function Get-NumberInk {
    param([string]$Text, [double]$FontSize)

    $bitmap = New-Object System.Drawing.Bitmap($MEASURE, $MEASURE, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $font = New-NumberFont $FontSize
    $brush = [System.Drawing.Brushes]::Black
    $graphics.DrawString($Text, $font, $brush, [System.Drawing.RectangleF]::new(0, 0, $MEASURE, $MEASURE), (New-CenteredFormat))
    $graphics.Dispose()
    $font.Dispose()

    $ink = Get-InkBounds $bitmap
    $bitmap.Dispose()
    return $ink
}

# Dimensione (px) che fa entrare le cifre esattamente nella scatola richiesta.
function Get-FittedFontSize {
    param([string]$Text, [double]$MaxWidth, [double]$MaxHeight)

    $trial = 300.0
    $ink = Get-NumberInk -Text $Text -FontSize $trial
    $scale = [Math]::Min($MaxWidth / $ink.Width, $MaxHeight / $ink.Height)
    return $trial * $scale
}

function Draw-Number {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [double]$FontSize,
        [double]$CenterX,
        [double]$CenterY,
        [System.Drawing.Color]$Color)

    $ink = Get-NumberInk -Text $Text -FontSize $FontSize
    $font = New-NumberFont $FontSize
    $brush = New-Object System.Drawing.SolidBrush($Color)
    $box = [Math]::Max($MEASURE, $FontSize * 1.6)
    $rect = [System.Drawing.RectangleF]::new(
        [float]($CenterX - $box / 2 - ($ink.CenterX - $MEASURE / 2)),
        [float]($CenterY - $box / 2 - ($ink.CenterY - $MEASURE / 2)),
        [float]$box,
        [float]$box)
    $Graphics.DrawString($Text, $font, $brush, $rect, (New-CenteredFormat))
    $brush.Dispose()
    $font.Dispose()
}

function New-Canvas {
    param([bool]$Opaque, [bool]$Gradient)

    $bitmap = New-Object System.Drawing.Bitmap($SIZE, $SIZE, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    if ($Opaque) {
        $rect = [System.Drawing.RectangleF]::new(0, 0, $SIZE, $SIZE)
        if ($Gradient) {
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $COLOR_BG_TOP, $COLOR_BG_BOTTOM, 90.0)
        } else {
            $brush = New-Object System.Drawing.SolidBrush($COLOR_BG_TOP)
        }
        $graphics.FillRectangle($brush, $rect)
        $brush.Dispose()
    }

    return [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics }
}

# Scatola disponibile per le cifre dentro un esagono con quel raggio.
function Get-DigitBox {
    param([double]$HexRadius)
    return [pscustomobject]@{
        Width = $HexRadius * [Math]::Sqrt(3) * 0.80
        Height = $HexRadius * 2 * 0.58
    }
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Name)
    $path = Join-Path $outDir $Name
    $Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    return $path
}

# "20" nero dentro un esagono bianco pieno.
$digitBoxLegacy = Get-DigitBox -HexRadius $HEX_LEGACY
$digitBoxAdaptive = Get-DigitBox -HexRadius $HEX_ADAPTIVE
$digitsLegacy = Get-FittedFontSize -Text $LIFE -MaxWidth $digitBoxLegacy.Width -MaxHeight $digitBoxLegacy.Height
$digitsAdaptive = Get-FittedFontSize -Text $LIFE -MaxWidth $digitBoxAdaptive.Width -MaxHeight $digitBoxAdaptive.Height

# --- icon.png: icona classica, sfondo pieno ---
$canvas = New-Canvas -Opaque $true -Gradient $true
$hexagon = New-HexagonPath -Radius $HEX_LEGACY -CenterX ($SIZE / 2) -CenterY ($SIZE / 2)
for ($i = 1; $i -le 4; $i++) {
    $shadowPath = $hexagon.Clone()
    $matrix = New-Object System.Drawing.Drawing2D.Matrix
    $matrix.Translate(0, $i * 9)
    $shadowPath.Transform($matrix)
    $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 0, 0, 0))
    $canvas.Graphics.FillPath($shadow, $shadowPath)
    $shadow.Dispose()
    $shadowPath.Dispose()
    $matrix.Dispose()
}
$white = New-Object System.Drawing.SolidBrush($COLOR_HEX)
$canvas.Graphics.FillPath($white, $hexagon)
$white.Dispose()
Draw-Number -Graphics $canvas.Graphics -Text $LIFE -FontSize $digitsLegacy -CenterX ($SIZE / 2) -CenterY ($SIZE / 2) -Color $COLOR_DIGITS
$canvas.Graphics.Dispose()
$iconPath = Save-Png -Bitmap $canvas.Bitmap -Name 'icon.png'
$canvas.Bitmap.Dispose()

# --- icon_background.png: solo sfondo per l'adaptive icon ---
$canvas = New-Canvas -Opaque $true -Gradient $true
$canvas.Graphics.Dispose()
$backgroundPath = Save-Png -Bitmap $canvas.Bitmap -Name 'icon_background.png'
$canvas.Bitmap.Dispose()

# --- icon_foreground.png: glifo trasparente nella safe zone ---
$canvas = New-Canvas -Opaque $false -Gradient $false
$hexagon = New-HexagonPath -Radius $HEX_ADAPTIVE -CenterX ($SIZE / 2) -CenterY ($SIZE / 2)
$white = New-Object System.Drawing.SolidBrush($COLOR_HEX)
$canvas.Graphics.FillPath($white, $hexagon)
$white.Dispose()
Draw-Number -Graphics $canvas.Graphics -Text $LIFE -FontSize $digitsAdaptive -CenterX ($SIZE / 2) -CenterY ($SIZE / 2) -Color $COLOR_DIGITS
$hexagon.Dispose()
$canvas.Graphics.Dispose()
$foregroundPath = Save-Png -Bitmap $canvas.Bitmap -Name 'icon_foreground.png'
$canvas.Bitmap.Dispose()

# --- icon_monochrome.png: contorno + cifre, tutto bianco (Android 13+) ---
$canvas = New-Canvas -Opaque $false -Gradient $false
$hexagon = New-HexagonPath -Radius $HEX_MONO -CenterX ($SIZE / 2) -CenterY ($SIZE / 2)
$pen = New-Object System.Drawing.Pen($COLOR_HEX, [float]$HEX_STROKE)
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$canvas.Graphics.DrawPath($pen, $hexagon)
$pen.Dispose()
$innerWidth = ($HEX_MONO * [Math]::Sqrt(3) - 2 * $HEX_STROKE) * 0.66
$innerHeight = ($HEX_MONO * 2 - 2 * $HEX_STROKE) * 0.40
$digitsMono = Get-FittedFontSize -Text $LIFE -MaxWidth $innerWidth -MaxHeight $innerHeight
Draw-Number -Graphics $canvas.Graphics -Text $LIFE -FontSize $digitsMono -CenterX ($SIZE / 2) -CenterY ($SIZE / 2) -Color $COLOR_HEX
$hexagon.Dispose()
$canvas.Graphics.Dispose()
$monoPath = Save-Png -Bitmap $canvas.Bitmap -Name 'icon_monochrome.png'
$canvas.Bitmap.Dispose()

"cifre: classica {0:N1} px, adaptive {1:N1} px, mono {2:N1} px (font MedulaOne)" -f $digitsLegacy, $digitsAdaptive, $digitsMono

# --- verifica: le cifre devono stare dentro l'esagono, centrate ---
$check = [System.Drawing.Bitmap]::FromFile($foregroundPath)
$half = 700
$first = [int](($SIZE - $half) / 2)
$hex = [pscustomobject]@{ MinX = $SIZE; MinY = $SIZE; MaxX = -1; MaxY = -1 }
$ink = [pscustomobject]@{ MinX = $SIZE; MinY = $SIZE; MaxX = -1; MaxY = -1 }
for ($y = $first; $y -lt $first + $half; $y++) {
    for ($x = $first; $x -lt $first + $half; $x++) {
        $pixel = $check.GetPixel($x, $y)
        if ($pixel.A -le 12) { continue }
        $target = if ($pixel.R + $pixel.G + $pixel.B -gt 500) { $hex } else { $ink }
        if ($x -lt $target.MinX) { $target.MinX = $x }
        if ($x -gt $target.MaxX) { $target.MaxX = $x }
        if ($y -lt $target.MinY) { $target.MinY = $y }
        if ($y -gt $target.MaxY) { $target.MaxY = $y }
    }
}
$check.Dispose()
if ($ink.MaxX -lt 0) { throw "Le cifre non sono state disegnate." }
"esagono: x {0}..{1}, y {2}..{3}" -f $hex.MinX, $hex.MaxX, $hex.MinY, $hex.MaxY
"cifre:   x {0}..{1}, y {2}..{3} (margini l/r {4}/{5}, sopra/sotto {6}/{7})" -f `
    $ink.MinX, $ink.MaxX, $ink.MinY, $ink.MaxY,
    ($ink.MinX - $hex.MinX), ($hex.MaxX - $ink.MaxX),
    ($ink.MinY - $hex.MinY), ($hex.MaxY - $ink.MaxY)

Get-Item $iconPath, $backgroundPath, $foregroundPath, $monoPath |
    Select-Object Name, @{ Name = 'KB'; Expression = { [Math]::Round($_.Length / 1KB, 1) } } |
    Format-Table -AutoSize
