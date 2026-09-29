# Costruisce l'APK release dandogli la stessa etichetta che gli da' la pipeline:
#   MTG-Life-Counter-<versione>.apk
#
# Versione e numero di build vengono dal `version:` di `pubspec.yaml` (`nome+numero`),
# cioe' dalla stessa riga che usa `flutter run`: l'APK costruito qui, quello della
# pipeline e la versione mostrata dentro il menu dicono sempre la stessa cosa.
# Il tag git non serve a costruire, serve solo a ricordare qual e' l'ultima
# versione pubblicata (se non combacia, lo script avvisa). Sui tag di `develop`,
# che portano `-SNAPSHOT` (v1.0.4-SNAPSHOT), il suffisso non conta nel confronto:
# e' la stessa versione del pubspec, solo non ancora pubblicata.
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 -Install
#   powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 -Snapshot
#
# `-Install` finisce con `adb install -r`, che conserva i dati dell'app (vite,
# colori, timer): **non** usare `flutter install`, che prima disinstalla.
# `-Snapshot` mette `-SNAPSHOT` nell'etichetta del file, come fa la pipeline sui tag
# di `develop`; il nome dentro l'APK resta quello del pubspec, perche' iOS
# (CFBundleShortVersionString) accetta solo numeri.

[CmdletBinding()]
param(
    # Installa l'APK appena costruito sul telefono collegato.
    [switch]$Install,

    # Mette -SNAPSHOT nell'etichetta del file, come la pipeline su develop.
    [switch]$Snapshot
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
# Un tag `v1.0.4-SNAPSHOT` e' la stessa versione del pubspec senza il suffisso:
# senza toglierlo lo script avviserebbe a ogni build su develop.
$tagBase = if ($tag -match '^v[0-9]') { $tag.TrimStart('v') -replace '-SNAPSHOT$', '' } else { $tag }
if ($tagBase -match '^[0-9]' -and $tagBase -ne $nome) {
    Write-Warning "pubspec.yaml dice $versione, ma l'ultimo tag e' $tag"
}

# `-Snapshot` cambia solo l'etichetta del file, non il nome dentro l'APK (e il numero di
# build non compare nel nome: resta nel versionCode, dove lo mette `--build-number`).
$suffisso = if ($Snapshot) { '-SNAPSHOT' } else { '' }
$file = "MTG-Life-Counter-$nome$suffisso.apk"
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
