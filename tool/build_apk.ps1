# Costruisce l'APK release dandogli la stessa etichetta che gli da' la pipeline:
#   MTG-Life-Counter-<versione>-build<numero>.apk
#
# Versione = tag git piu' recente raggiungibile (v1.2.3 -> 1.2.3), numero di
# build = numero di commit del ramo. Sono gli stessi due numeri che usa
# `.github/workflows/build-release.yml`, quindi l'APK costruito qui e quello
# scaricato da GitHub, per lo stesso commit, hanno lo stesso nome e lo stesso
# `versionCode`: si installano uno sopra l'altro senza sorprese.
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

# La versione dal tag piu' recente; senza tag si ripiega sul `version:` di
# pubspec.yaml, togliendo il `+numero`.
function Get-NomeVersione {
    # Se git non c'e' o non ci sono tag, l'output non e' un tag valido e si
    # finisce nel ripiego (l'errore di git arriva su stderr, non serve vederlo).
    $tag = try { "$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>&1)".Trim() } catch { '' }
    if ($tag -match '^v[0-9]') { return $tag.TrimStart('v') }

    $riga = Select-String -Path pubspec.yaml -Pattern '^version:' | Select-Object -First 1
    if (-not $riga) { throw "Nessun tag git e nessun 'version:' in pubspec.yaml" }
    return ($riga.Line -split ':', 2)[1].Trim().Split('+')[0]
}

$nome = Get-NomeVersione
# Stesso contatore della pipeline: cresce di uno a ogni commit, quindi il
# versionCode non torna mai indietro (Android rifiuta l'installazione con
# INSTALL_FAILED_VERSION_DOWNGRADE se il numero cala).
$conteggio = try { "$(git rev-list --count HEAD 2>&1)".Trim() } catch { '' }
if ($conteggio -notmatch '^\d+$' -or [int]$conteggio -le 0) {
    throw 'Conteggio dei commit non riuscito: serve un repo git con la sua storia.'
}
$numero = [int]$conteggio

# La versione in pubspec.yaml e' quella che mostra `flutter run` (e la scritta
# in fondo al menu): se resta indietro rispetto al tag, l'app dice una cosa e
# l'APK un'altra. Qui si avvisa soltanto: pubspec si aggiorna a mano, quando si
# prepara la release.
$rigaPubspec = Select-String -Path pubspec.yaml -Pattern '^version:' | Select-Object -First 1
if (($rigaPubspec.Line -split ':', 2)[1].Trim().Split('+')[0] -ne $nome) {
    Write-Warning "pubspec.yaml non e' allineato al tag: `flutter run` mostrera' un'altra versione."
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
