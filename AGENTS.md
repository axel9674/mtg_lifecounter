# AGENTS.md

Istruzioni per agenti AI che lavorano su questo repository.

## Il progetto

`mtg_lifecounter` e' un'app Flutter personale: un segnapunti di vita per due giocatori a Magic.
La UI e' **interamente in italiano**, con commenti in italiano.

- **Tutto il codice sta in `lib/main.dart`** (unico file, ~2300 righe: tema, helper di stile,
  widget pubblici, widget privati `_Xxx`, `main()`). Non e' un errore: e' una scelta, perche'
  l'app e' piccola e i widget sono tutti legati fra loro. Non splittare in piu' file senza
  che sia stato chiesto esplicitamente.
- `test/widget_test.dart` esiste ma **non va eseguito** (vedi "Regole operative").
- Cartelle `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/` sono generate da
  `flutter create`: si toccano solo quando serve davvero (es. manifest, gradle, icona).
- `tool/` contiene script di supporto, `assets/` i font e i PNG dell'icona.

Sviluppo su Windows, Flutter **3.47.4** stable / Dart **3.13.3**, SDK in `C:\DEV\flutter`.

## Comandi

```powershell
flutter pub get                 # dipendenze
flutter analyze lib             # validazione statica (baseline: 12 info, 0 errori)
dart format lib                 # formattazione (usare questo, non editare a mano)
flutter run -d RFCWC0VE01P      # telefono: Galaxy S24 (SM S921B), Android 16 / API 36
flutter build apk --release     # APK in build\app\outputs\flutter-apk\
adb install -r build\app\outputs\flutter-apk\app-release.apk   # aggiorna l'APK sul telefono
```

Per l'APK: la `release` e' firmata **con la debug key** (`android/app/build.gradle.kts`), quindi
si installa per sideload ma non si pubblica. Va bene cosi': e' un'app personale.

Per installare usare `adb install -r`, **non** `flutter install`: quest'ultimo disinstalla prima,
e con l'app se ne va il salvataggio delle vite (i dati stanno nella cartella privata dell'app).
`-r` lascia la cartella intatta e la sostituzione riesce perche' la firma (debug key) non cambia
fra una build e l'altra.

## Regole operative

- **Non eseguire mai `flutter test`**, ne' aggiungere golden test o loop di verifica a misura
  di pixel. L'app e' personale e la verifica visiva la fa l'utente sul telefono.
- **Fare commit, mai `git push`**, se non e' stato chiesto esplicitamente.
- Messaggi di commit **in italiano**: titolo conciso, **riga vuota**, poi elenco puntato
  **senza righe vuote** tra i bullet. Passare il messaggio con un solo `-m` e una here-string.
  La riga vuota dopo il titolo non va mai persa: senza, git non separa titolo e descrizione e
  il messaggio si legge tutto su una riga (es. in `git log --oneline`, nel grafo, ecc.).
- Non fare refactoring o "pulizie" non richieste.
- Rispondere in italiano, tono breve e concreto.

## Ambiente: vincoli da non rompere

- Il pub cache e' su `C:`, il progetto su `D:`. Il compilatore incrementale di Kotlin non
  riesce a gestire path su root diverse e la build fallisce con
  `IllegalArgumentException: this and base files have different roots`.
  **`kotlin.incremental=false` in `android/gradle.properties` deve restare.**
  Se la build si incastra: `.\android\gradlew.bat --stop` e cancellare `build\<plugin>`.
- `build/` e `.dart_tool/` sono gitignored: `build/` e' anche il posto giusto per script o
  file di appoggio temporanei.
- Aggiungere un **plugin** richiede un riavvio completo di `flutter run` (non basta l'hot
  restart); per le modifiche a widget basta l'hot reload. Su web usare `navigate_page`
  per ricaricare la pagina dell'app quando l'albero dei widget sembra vecchio.

## Architettura (mappa rapida di `lib/main.dart`)

- `main()` → `LifeCounterApp` (`MaterialApp` con `ThemeData.dark()`, font Nunito).
- `_twoZones(context)` e' il layout condiviso da vista vita e vista dado: in portrait una
  `Column` (zona 1 sopra, zona 2 sotto), in landscape una `Row` (zona 1 a sinistra,
  zona 2 a destra).
- **Le cifre seguono lo schermo, non c'e' nessuna rotazione di 90°.** L'unica rotazione e'
  il mezzo giro (`quarterTurns: 2`) della prima zona quando il flip e' attivo.
  `portrait → 1` e' una versione gia' bocciata dall'utente: non riproporla.
- `PlayerZone` = pila di due "card": `ColorPalette` sotto, contatore sopra, animati con
  `AnimatedSlide`; `_ZoneCardHandle` e' la maniglia che resta visibile a pila aperta.
  Swipe verticale apre/chiude la tavolozza (`primaryVelocity`, soglia 100 px/s) e chiude
  solo con lo swipe opposto.
- -1/+1 si applicano su `onTapUp` (non `onTapDown`), altrimenti uno swipe cambierebbe la
  vita; `onTapDown` serve solo al velo di feedback `_TapShade`.
- Long press su un lato: primo punto immediato + `Timer.periodic(140 ms)`.
- `_MenuIconButton` e' il bottone unico del menu (hexagon centrale, voci radiali, chiusura
  dado). Dipinge la propria forma con `_MenuButtonShapePainter` invece di usare
  `Material`/`InkWell`: il feedback premuto e' un velo di colore, scelta preferita dall'utente.
  Regola generale per questa app: **disegnare le forme, non ritagliarle**, tranne cerchi e
  rettangoli arrotondati.
- `GameTimerBox` / `_FloatingTimer`: il timer e' un box **fluttuante sopra** le zone (uno per
  ogni verso di lettura, quando il flip e' attivo), non una fascia che sposta il contatore.
  Tocco = avvia/pausa, long press = azzera. "Reset a 20" **non** tocca il timer
  (le vite si azzerano solo dal menu, il tempo no).
- `RadialMenu` + `TimerSetupDialog` / `ColorPalette`: overlay che **non si chiudono** con un
  tocco sullo sfondo (`AbsorbPointer`, non un `GestureDetector` vuoto).
- Persistenza in `shared_preferences` con chiavi `player1Life`, `player2Life`, `player1Color`,
  `player2Color`, `flipFirstLife`, `opponentLifeVisible`, `timerOn`, `timerMinutes`,
  `timerSeconds`.
  `_restoreGame()` in `initState`, `_saveGame()` dopo ogni modifica, flag `_touched` per non
  sovrascrivere quello che l'utente ha gia' fatto. `SharedPreferences` e' sempre in `try/catch`.
- Costanti notevoli in cima al file: `kStartingLife`, `kDefaultPanelColor`, `kPlayerColors`,
  `kNumberFontSize`, `kNumberBoxWidth`, `kSignBoxWidth`, `kCounterGap`, `kLifeCounterScale`,
  `kCounterSideInset`, `kComboWindow`, `kComboScale`, `kNumberFontFamily`.

## Stile e tipografia

- Mai `TextStyle` grezzi: usare `appTextStyle({fontSize, weight, color, letterSpacing})` per
  la UI e `appNumberStyle({...})` per le cifre grandi.
- Due font: **Nunito** (variable, `assets/fonts/Nunito.ttf`) per tutto il testo, **MedulaOne**
  (`assets/fonts/MedulaOne-Regular.ttf`, `kNumberFontFamily`) solo per cifre e segni `+`/`-`.
  I segni sono testo in MedulaOne, non icone Material, cosi' hanno lo stesso peso delle cifre.
- Ogni testo dentro una `Row` a misura intrinseca deve stare in una `SizedBox` a larghezza
  fissa (con `FittedBox(fit: BoxFit.scaleDown)` se serve): senza, le metriche del font
  spostano i vicini quando cambia il numero di cifre.
- Nei widget **privati** (`_Xxx`) non mettere `super.key`: da' `unused_element_parameter`.
- Aggiungere un font richiede `flutter pub get` **e** hot restart.

## Icona dell'app

L'icona e' generata da uno script, non disegnata a mano:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\make_icon.ps1   # -> assets\launcher\*.png
dart run flutter_launcher_icons                                          # -> android\...\res\...
```

`tool/make_icon.ps1` (GDI+, `System.Drawing`) disegna l'esagono bianco arrotondato con le
cifre "20" in MedulaOne e scrive quattro PNG 1024×1024 in `assets/launcher/`:

| file | uso |
| --- | --- |
| `icon.png` | icona classica (`image_path`), sfondo gradiente + esagono |
| `icon_background.png` | solo sfondo, `adaptive_icon_background` |
| `icon_foreground.png` | trasparente, esagono + cifre, `adaptive_icon_foreground` |
| `icon_monochrome.png` | contorno + cifre bianche, `adaptive_icon_monochrome` (Android 13+) |

La configurazione sta in fondo a `pubspec.yaml` (`flutter_launcher_icons:`), con
`adaptive_icon_foreground_inset: 0` perche' il disegno tiene gia' conto della safe zone
Android (66/108). Lo script termina con un auto-controllo che misura l'inchiostro delle cifre
e la stampa, quindi non serve guardare l'immagine per sapere se e' venuta bene.

Per cambiare l'icona si modificano le costanti in cima a `tool/make_icon.ps1` e si rilanciano
i due comandi; non si editano i PNG.

## Pipeline GitHub Actions

`.github/workflows/build-release.yml` costruisce l'APK e pubblica la release. Tre inneschi:

| evento | cosa succede |
| --- | --- |
| push su `main` | build dell'APK, salvato come artefatto del workflow |
| push di un tag `v*` | build dell'APK + GitHub Release con l'APK allegato |
| `workflow_dispatch` | a mano dalla scheda Actions |

- **GitHub esegue il workflow che sta nel commit spinto**: se il file non c'e' sul ramo o sul
  commit taggato, la pipeline non parte. Un tag su `develop` funziona (il file e' li'), un push
  su `main` funziona solo quando `main` conterra' davvero il codice.
- L'APK esce come `MTG-Life-Counter-<versione>-build<numero>.apk` (non `app-release.apk`):
  ci pensa lo step `Prepara l'artefatto`, che rinomina la copia in `dist/`. Il numero di build
  serve perche' due run sulla stessa versione restino due file distinti.
- Versione: da `v1.2.3` diventa `1.2.3`, altrimenti si legge il `version:` di `pubspec.yaml`;
  il numero di build e' sempre `GITHUB_RUN_NUMBER`, passato a `--build-number` (quindi ogni APK
  ha un `versionCode` diverso anche se pubspec non cambia).
- A release pubblicata lo step `Notifica su Telegram` manda un messaggio con il link diretto
  all'APK (`releases/download/<tag>/<file>`) e quello alle note. Serve il nome del file, che
  il job `build` espone come output (`outputs.file` da `steps.versione.outputs.file`).
  Richiede i segreti `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID`: se mancano la notifica viene
  saltata con un `::warning::` e la release resta comunque valida.
- L'`flutter analyze` del workflow e' **non bloccante** (`continue-on-error`): i 12 `info`
  preesistenti farebbero altrimenti fallire la build.
- Flutter pinnato a `3.47.4` in cima al file (`env.FLUTTER_VERSION`): da aggiornare insieme
  all'SDK locale.

## Fonti di verita'

- `lib/main.dart` — l'app.
- `pubspec.yaml` — dipendenze, font, configurazione icona.
- `tool/make_icon.ps1` — l'icona.
- `.github/workflows/build-release.yml` — build e release dell'APK.
- `android/app/src/main/AndroidManifest.xml` — nome app (`MTG Life Counter`) e icona.

## Git

- `main` = **un solo commit con albero vuoto** (0 file), per scelta dell'utente.
- `develop` = ramo di `main` con tutto il lavoro; `main` e' antenato di `develop`.
- Si lavora su `develop`. Commit in italiano, push **solo se richiesto**.
