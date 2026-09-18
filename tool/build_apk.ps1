# Costruisce l'APK release dandogli la stessa etichetta che gli da' la pipeline:
#   MTG-Life-Counter-<versione>-build<numero>.apk
#
# Versione e numero di build vengono dal `version:` di `pubspec.yaml` (`nome+numero`),
# cioe' dalla stessa riga che usa `flutter run`: l'APK costruito qui, quello della
# pipeline e la versione mostrata dentro il menu dicono sempre la stessa cosa.
# Il tag git non serve a costruire, serve solo a ricordare qual e' l'ultima
# versione pubblicata (se non combacia, lo script avvisa).
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 -Install
#
# `-Install` finisce con `adb install -r`, che conserva i dati dell'app (vite,
# colori, timer): **non** usare `flutter install`, che prima disinstalla.

[CmdletBinding()]
param(
    # Installa l'APK appena costruito sul telefono collegato.
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# Unica fonte della versione: `nome+numero` dal `version:` di pubspec.yaml.
$riga = Select-String -Path pubspec.yaml -Pattern '^version:' | Select-Object -First 1
if (-not $riga) { throw "Nessuna 'version:' in pubspec.yaml" }
$versione = ($riga.Line -split ':', 2)[1].Trim()
if ($versione -notmatch '^(\d+\.\d+\.\d+)\+([1-9]\d*)$') {
    throw "version: '$versione' non ha la forma nome+numero (es. 1.0.2+3)"
}
$nome = $Matches[1]
# Il numero di build e' il versionCode di Android: solo un avviso se il tag piu'
# recente racconta un'altra storia (pubspec non allineato al momento del tag).
$numero = [int]$Matches[2]
$tag = try { "$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>&1)".Trim() } catch { '' }
if ($tag -match '^v[0-9]' -and $tag.TrimStart('v') -ne $nome) {
    Write-Warning "pubspec.yaml dice $versione, ma l'ultimo tag e' $tag"
}

$file = "MTG-Life-Counter-$nome-build$numero.apk"
Write-Host "Versione $nome+$numero  ->  $file" -ForegroundColor Cyan

flutter build apk --release --build-name $nome --build-number $numero
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --release non e'' riuscita' }

# La copia col nome della release sta accanto a `app-release.apk` (che resta).
$cartella = 'build\app\outputs\flutter-apk'
$dest = Join-Path $cartella $file
Copy-Item -LiteralPath (Join-Path $cartella 'app-release.apk') -Destination $dest -Force

if ($Install) {
    adb install -r $dest
    if ($LASTEXITCODE -ne 0) { throw "adb install non e' riuscita" }
    Write-Host "Installato: $file" -ForegroundColor Green
} else {
    Write-Host "Pronto: $dest"
    Write-Host "Per installarlo: adb install -r `"$dest`""
}
