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

Per installare usare `adb install -r`, **non** `flutter install`: quest'ultimo disinstalla prima,
e con l'app se ne va il salvataggio delle vite (i dati stanno nella cartella privata dell'app).
`-r` lascia la cartella intatta e la sostituzione riesce perche' la firma (debug key) non cambia
fra una build e l'altra. La release e' firmata con la debug key, quindi va bene per il sideload
ma non si pubblica sul Play Store: e' un'app personale.

Per l'APK con lo stesso nome della release c'e' `tool/build_apk.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1            # solo build
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 -Install   # build + adb install -r
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_apk.ps1 -Snapshot  # etichetta -SNAPSHOT, come su develop
```

Versione e numero di build vengono dal `version:` di `pubspec.yaml` (`nome+numero`), cioe' dalla
**stessa riga** che usa `flutter run`: APK locale, APK della pipeline e scritta in fondo al menu
dicono cosi' sempre la stessa cosa. Il numero dopo il `+` e' il `versionCode` di Android e **non
deve mai calare**: se cala, `adb install -r` fallisce con `INSTALL_FAILED_VERSION_DOWNGRADE` e
`flutter run`, che dopo il fallimento disinstalla la versione vecchia, si porta via vite, colori
e timer salvati. L'APK esce come
`build\app\outputs\flutter-apk\MTG-Life-Counter-<versione>.apk`, accanto a
`app-release.apk` che resta; con `-Snapshot` diventa
`MTG-Life-Counter-<versione>-SNAPSHOT.apk`, come sui tag di `develop`. Il numero dopo il `+`
**non** compare nel nome del file: resta nel `versionCode` dell'APK, dove serve ad Android.

## Regole operative

- **Non eseguire mai `flutter test`**, ne' aggiungere golden test o loop di verifica a misura
  di pixel. L'app e' personale e la verifica visiva la fa l'utente sul telefono.
- **Fare commit, mai `git push`**, se non e' stato chiesto esplicitamente.
- Messaggi di commit **in italiano**: titolo conciso, **riga vuota**, poi elenco puntato
  **senza righe vuote** tra i bullet. Passare il messaggio con un solo `-m` e una here-string.
  La riga vuota dopo il titolo non va mai persa: senza, git non separa titolo e descrizione e
  il messaggio si legge tutto su una riga (es. in `git log --oneline`, nel grafo, ecc.).
- L'inglese nel progetto ha **due soli** posti: quello che esce all'esterno (le note della
  release e il messaggio Telegram, che li legge chi non ha scritto l'app) e i **commenti della
  pipeline** (`.github/workflows/*.yml`, scelta esplicita dell'utente: si leggono su GitHub,
  accanto ai workflow di tutti gli altri). Tutto il resto — codice, commenti, commit,
  documentazione — resta in italiano.
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
  I plugin in uso sono tre: `shared_preferences` (vite, colori, veleni e timer),
  `package_info_plus` (la versione in fondo al menu) e `wakelock_plus` (schermo acceso).

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
- **Niente `Tooltip` su un widget che ha gia' una pressione lunga**: il `Tooltip` registra un
  proprio `LongPressGestureRecognizer`, il cui `Listener` sta **sopra** il figlio, quindi entra
  nell'arena dei gesti dopo quello del figlio e non vince mai. Il testo non comparirebbe e il
  gesto del figlio resterebbe l'unico a rispondere: una promessa invisibile. Il suggerimento
  visibile va dove la pressione lunga e' libera (la voce del menu, che si preme e basta) e il
  testo per i lettori di schermo lo mette `Semantics(tooltip: ...)`. E' il motivo per cui il box
  del timer e la pillola dei veleni hanno `Semantics` e non `Tooltip`.
- `_MenuIconButton` e' il bottone unico del menu (hexagon centrale, voci radiali, chiusura
  dado). Dipinge la propria forma con `_MenuButtonShapePainter` invece di usare
  `Material`/`InkWell`: il feedback premuto e' un velo di colore, scelta preferita dall'utente.
  Regola generale per questa app: **disegnare le forme, non ritagliarle**, tranne cerchi e
  rettangoli arrotondati.
- `GameTimerBox` / `_FloatingTimer`: il timer e' un box **fluttuante sopra** le zone (uno per
  ogni verso di lettura, quando il flip e' attivo), non una fascia che sposta il contatore.
  Tocco = avvia/pausa, long press = azzera. La voce "Nuova partita" **non** tocca il timer
  (le vite si azzerano solo dal menu, il tempo no).
  Il timer **conta sull'orologio**, non sui tick: `_timerDeadline` e' un istante assoluto
  (salvato in `timerDeadline` mentre scorre), quindi il tempo resta giusto anche chiudendo
  l'app e il conto riprende da solo alla riapertura. Fuori dal primo piano il ticker si
  ferma e al ritorno `_syncTimerWithClock()` rimette il tempo in pari: se la scadenza e'
  passata mentre l'app era via il tempo finisce **senza** suono (nessuno era li' a sentirlo).
  A fine tempo vibra e suona la sveglia di sistema sul canale delle sveglie: il suono lo fa
  `android/.../MainActivity.kt` (canale `mtg_lifecounter/alarm`, `STREAM_ALARM`), perche' non
  deve dipendere dal volume dei media; altrove si ripiega su `SystemSound.alert`. Suona una
  volta sola, e toccare il timer (o azzerarlo) la zittisce.
- Segnalini veleno (`_PoisonCounter` dentro `_FloatingPoison`): una pillola per zona,
  **fluttuante** come il timer, quindi accendere i veleni non rimpicciolisce il contatore delle
  vite. Sta in un angolo **opposto** a quello del timer (che occupa il centro del bordo esterno):
  in verticale la zona in alto la tiene in basso a sinistra e quella in basso in alto a destra
  (speculari rispetto alla linea di mezzo, dove non c'e' nessuna barra di sistema), in
  orizzontale finiscono agli angoli opposti dello schermo e li' il `MediaQuery.paddingOf` conta
  (`screenInsets`). Tocco = **+1**, pressione lunga = **-1** (primo segnalino subito, poi
  140 ms come la vita): i veleni si mettono quando si colpisce, quello che si corregge sono gli
  errori. Vanno da zero a `kLethalPoison` (**10**) e a dieci si **perde senza passare dalle
  vite**: `_gameOutcome` guarda anche i veleni, la pillola si accende di verde (verde anche
  l'icona, nera la scritta su fondo chiaro) e la zona mostra il cartello VINCE/PERDE. Si
  accendono dalla voce del menu (icona virus, tooltip "Mostra/Nascondi i segnalini veleno
  (tocco: +1, tieni premuto: -1)", chiave `poisonVisible`) e **all'inizio stanno spenti**: chi non
  gioca infect non se li trova sullo schermo. Spegnerli **non** azzera i valori: chi e' a dieci resta avvelenato a morte
  anche a pillole nascoste. I veleni tornano a zero con "Nuova partita" (`resetLife`), non dal
  menu dei veleni.
- La voce "Nuova partita" (icona refresh) non apre nessun popup: mostra `_LifePresetPicker`,
  cioe' i tre pulsanti 20/30/40 con sopra la scritta "Seleziona i Punti Vita iniziali".
  In **verticale** il picker e' attaccato sopra la voce del menu (una `Column` dentro
  `FittedBox(scaleDown)`, ordine: `AnimatedSize(picker)` -> `RadialMenu` -> `AnimatedSize(copia
  invisibile del picker)`). La copia (`IgnorePointer` + `Opacity: 0`) tiene il gruppo
  **simmetrico rispetto al centro del menu**, cosi' il menu **non si sposta di un pixel**
  quando i pulsanti compaiono; i due `AnimatedSize` devono durare lo stesso tempo
  (`_kLifePickerDuration`). In **orizzontale** l'altezza e' poca, quindi la scelta si stacca e
  va a sinistra (`Alignment.centerLeft`, `_kLifePickerInset` dal bordo) e il menu resta al
  centro a misura piena. La scelta e' **identica nelle due direzioni**: i tre pulsanti nudi,
  senza fondo proprio, appoggiati al velo scuro del menu.
  Tutto questo lo monta `_buildMenuOverlay()`.
  Toccando un valore la partita riparte subito (`startNewGame` → `resetLife`), la scelta e il
  menu si chiudono. La quantita' resta in `_startingLife` ed e' ricordata (chiave
  `startingLife`), quindi il tooltip della voce dice sempre il numero corrente.
  `_lifePickerOpen` si spegne anche in `closeMenu()`: la scelta vive appesa al menu.
- Il velo scuro che copre la partita col menu aperto e' `Colors.black.withOpacity(0.82)`.
- `RadialMenu` + `TimerSetupDialog` / `ColorPalette`: overlay che **non si
  chiudono** con un tocco sullo sfondo (`AbsorbPointer`, non un `GestureDetector` vuoto).
- `_PresetButton` (etichetta + stato scelto) e' il pulsante tondo condiviso dai preset del
  timer e dalla scelta delle vite.
- `_AppVersionLabel` scrive la versione dell'app piccola in fondo a sinistra mentre il menu e'
  aperto (stessa animazione delle voci, `Opacity` + `IgnorePointer`). Il numero lo legge
  `_loadAppVersion()` da `package_info_plus` (`versione+build`, quindi c'e' anche il numero di
  build delle release); se la lettura fallisce o torna vuota (sul web `version.json` non c'e')
  la scritta non compare.
- Lo schermo resta acceso finche' l'app e' davanti: `_keepScreenOn()` in `initState` e
  `_releaseScreen()` in `dispose` usano `wakelock_plus`, perche' fra un turno e l'altro si tocca
  il contatore di rado e lo schermo si spegnerebbe da solo. Se il plugin non e' disponibile si
  torna al comportamento normale e l'app funziona lo stesso.
- Persistenza in `shared_preferences` con chiavi `player1Life`, `player2Life`, `player1Color`,
  `player2Color`, `player1Poison`, `player2Poison`, `flipFirstLife`, `opponentLifeVisible`,
  `poisonVisible`, `timerOn`, `timerMinutes`, `timerSeconds`, `timerDeadline`, `startingLife`.
  `_restoreGame()` in `initState`, `_saveGame()` dopo ogni modifica, flag `_touched` per non
  sovrascrivere quello che l'utente ha gia' fatto. `SharedPreferences` e' sempre in `try/catch`.
- Costanti notevoli in cima al file: `kStartingLife`, `kMinStartingLife`, `kMaxStartingLife`,
  `kLethalPoison`, `kDefaultPanelColor`, `kPlayerColors`,
  `kNumberFontSize`, `kNumberBoxWidth`, `kSignBoxWidth`, `kCounterGap`,
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

La pipeline e' **sei file** in `.github/workflows/`: un orchestratore e cinque workflow
riusabili, uno per blocco di lavoro, con il nome di quello che fanno.

| file | ruolo |
| --- | --- |
| `build-release.yml` | l'unico con gli inneschi: tiene l'ordine dei job, ognuno di una riga |
| `read-version.yml` | legge la versione dal pubspec e ne ricava nomi dei file ed etichetta |
| `build-apk.yml` | APK su `ubuntu-latest` (unico dal quale dipende la release) |
| `build-ipa.yml` | IPA su `macos-latest`, solo sui tag stabili |
| `release.yml` | GitHub Release + notifica Telegram |
| `publish-private.yml` | copia di APK e IPA sul repository privato |

- **Perche' file e non cartelle**: le *composite action* obbligano a `cartella/action.yml`
  (verificato sulla documentazione GitHub), quindi per avere file piatti con un nome parlante
  si usano i **workflow riusabili** (`on: workflow_call`). Il prezzo e' che gli input si
  passano a mano (`with:`/`secrets:`), non sono piu' variabili del chiamante.
- Un workflow chiamato **non vede l'`env` del chiamante**: per questo `FLUTTER_VERSION: 3.47.4`
  e' scritto **due volte** (`build-apk.yml` e `build-ipa.yml`) e va alzato in entrambi insieme
  all'SDK locale. L'`env` non e' nemmeno un contesto ammesso in `jobs.<id>.with`.
- I `permissions` di un workflow chiamato sono **l'intersezione** fra quelli del chiamante e i
  suoi: `contents: write` serve sia in `build-release.yml` sia in `release.yml`.
- Il contesto `secrets` **non e' ammesso nell'`if:` di uno step**: la presenza dei segreti si
  controlla dentro lo script (`if [ -z "$..." ]`), non con un `if:`.
- Inneschi (tutti in `build-release.yml`):

| evento | cosa succede |
| --- | --- |
| push su `master` | build del solo APK, salvato come artefatto del workflow (il job `ios` non parte) |
| tag `v1.0.4` (release, da `master`) | build di APK e IPA + GitHub Release con i due allegati, marcata "latest" |
| tag `v1.0.4-SNAPSHOT` (da `develop`) | build del solo APK + GitHub Release **pre-release**: la "latest" non si tocca |
| `workflow_dispatch` | a mano dalla scheda Actions (solo APK) |

- **GitHub esegue il workflow che sta nel commit spinto**: se i file non ci sono sul ramo o sul
  commit taggato, la pipeline non parte. Un tag su `develop` funziona (i file sono li'), un push
  su `master` funziona solo quando `master` conterra' davvero il codice.
- **La versione si legge una volta sola** nel job `version` e da li' il job `build` e il job
  `ios` prendono `build-name`, `build-number` e `file-name`: partono **in parallelo** e non
  possono divergere ne' nel nome ne' nel numero.
- L'APK esce come `MTG-Life-Counter-<versione>.apk` (non `app-release.apk`): ci
  pensa lo step `Stage the APK in dist/`, che copia con il nome definitivo. Stesso nome che da'
  `tool/build_apk.ps1` per lo stesso commit (con `-Snapshot` per gli snapshot di `develop`, dove
  l'etichetta diventa `<versione>-SNAPSHOT`).
- L'IPA esce come `MTG-Life-Counter-<versione>.ipa`: il file lo costruisce con
  `flutter build ios --release --no-codesign` e poi impacchetta `build/ios/iphoneos/Runner.app`
  in `Payload/Runner.app` con `ditto`. Non si usa `flutter build ipa` perche' con `--no-codesign`
  si ferma prima dell'esportazione ("Codesigning disabled with --no-codesign, skipping IPA.")
  e lascia solo l'archivio.
- I plugin iOS passano da **Swift Package Manager** (`Runner.xcodeproj` contiene
  `FlutterGeneratedPluginSwiftPackage`), quindi in CI non servono ne' Podfile ne' CocoaPods:
  e' il motivo per cui il progetto non ha un Podfile committato.
- **L'IPA non e' firmato** e non si installa con un doppio clic. Per firmarlo in pipeline
  servirebbe un account Apple Developer a pagamento (certificato e provisioning profile nei
  segreti `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `PROVISIONING_PROFILE_BASE64`, piu'
  `DEVELOPMENT_TEAM` e `--export-method`). Si installa con Sideloadly o AltStore, che lo
  rifirmano con il proprio Apple ID (con un Apple ID gratuito la firma dura 7 giorni).
- Il job `ios` gira su un runner **macOS**, l'unico che ha Xcode: i minuti macOS si pagano
  **10 volte** quelli di Linux, quindi quel job parte **solo per le release stabili**:
  `if: startsWith(github.ref, 'refs/tags/v') && !contains(github.ref_name, '-SNAPSHOT')`.
  Restano fuori i push su `master`, i `workflow_dispatch` e gli snapshot di `develop`: sono
  minuti che non cambierebbero niente (l'IPA di uno snapshot va comunque rifirmato per
  installarlo, e chi prova `develop` vuole l'APK). Il prezzo e' che uno snapshot esce **col solo
  APK**, ed e' esattamente quello che dicono le note e il messaggio Telegram.
- **La release non dipende da iOS**: il job `release` ha
  `if: !cancelled() && startsWith(github.ref, 'refs/tags/v') && needs.build.result == 'success'`,
  lo step che scarica l'IPA ha `if: inputs.ios-result == 'success'` e `files:` tiene i due
  pattern con `fail_on_unmatched_files: false`. Un runner macOS senza minuti, o Xcode che cambia
  idea, non possono impedire di pubblicare l'APK gia' costruito.
- Versione: **tutta dal `version:` di `pubspec.yaml`** (`nome+numero`), unica fonte per
  `flutter run`, `tool/build_apk.ps1` e questa pipeline. Il tag fornisce solo l'etichetta della
  release (`v1.2.3` → `1.2.3`, `v1.2.3-SNAPSHOT` → `1.2.3-SNAPSHOT`), e se non combacia col
  pubspec la pipeline lo segnala con un `::warning::`; senza tag l'etichetta viene dal pubspec.
  Il `-SNAPSHOT` finisce nel nome dei file e nel titolo della release, **mai** in `--build-name`:
  iOS (`CFBundleShortVersionString`) accetta solo numeri. Il numero dopo il `+` e' il
  `versionCode` e viene passato a `--build-number`: **non deve mai calare**.
- Lo snapshot di `develop` esce con `prerelease: true` e `make_latest: false`: GitHub non lo
  mette in cima alle release, quindi `releases/latest/download/...` continua a servire la stable
  di `master`. Note e messaggio Telegram dicono che e' una build di sviluppo.
- Le note della release (step `Prepare the release notes`, `body_path: note.md`) sono
  **in inglese**, come il messaggio Telegram: le legge chi arriva sulla pagina delle release dal
  di fuori, quindi raccontano cosa e' l'app, cosa c'e' negli allegati e come si installano
  (APK firmato con la debug key, IPA non firmato da rifirmare con un Apple ID, requisiti di
  sistema). Tutto quello che riguarda l'IPA compare **solo se l'IPA c'e'** (`IOS_RESULT`, cioe'
  `needs.ios.result`): niente allegati promessi e non consegnati.
- A release pubblicata lo step `Notify on Telegram` manda un messaggio con i link diretti
  all'APK (e all'IPA, quando c'e': `releases/download/<tag>/<file>`) e quello alle note. Richiede
  i segreti `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID`: se mancano la notifica viene saltata con
  un `::warning::` e la release resta comunque valida.
- La notifica ha `continue-on-error: true`: Telegram e' un di piu', e un rifiuto (token scaduto,
  bot bloccato, rate limit) non deve rendere rosso un run che ha gia' pubblicato la release.
- L'`flutter analyze` del workflow e' **non bloccante** (`continue-on-error`): i 12 `info`
  preesistenti farebbero altrimenti fallire la build.

### Secondo canale: il repository privato

`publish-private.yml` carica gli stessi file su un repository di artefatti privato
(`repository.axelhome.me`), **oltre** alla release su GitHub. Stessi inneschi della release,
quindi solo sui tag, stabili e snapshot.

- E' un job a se' (e non uno step in piu' in `release.yml`) per due motivi: non passa da GitHub,
  quindi non deve poter bloccare o rallentare la release, ed e' la prima cosa che si rompe
  mentre il server viene messo su.
- L'upload e' un `PUT` con il file come corpo e basic auth, quello che si aspettano sia Nexus
  sia Artifactory su un repository generico: `PUT <url>/<repository>/<path>/<file>`, dove
  `url` si ferma al segmento dell'istanza (`/repository`, o `/artifactory`) e `path` e'
  l'etichetta della release.
- URL e nome del repository sono **input con valore predefinito** in `publish-private.yml`
  (`https://repository.axelhome.me/repository` e `mtg-lifecounter`), sovrascrivibili da
  *Settings > Secrets and variables > Actions > Variables* con `PRIVATE_REPO_URL` e
  `PRIVATE_REPO_NAME` senza toccare il file. Le credenziali sono i segreti
  `PRIVATE_REPO_USER` e `PRIVATE_REPO_PASSWORD`: se mancano l'upload viene **saltato** con un
  `::warning::` e la release resta valida.
- Finche' il server non risponde lo step `Upload with curl` ha `continue-on-error: true`:
  un errore non deve rendere rosso un run che ha gia' pubblicato la release.
  **Va tolto quando il server risponde**, altrimenti gli upload potranno fallire in silenzio.
- `curl` usa `--upload-file` (PUT in streaming, un APK da 40 MB non finisce in memoria),
  `--fail-with-body` (un errore HTTP diventa codice di uscita diverso da zero e la risposta del
  server — "401 Unauthorized", "400 Bad Request" — viene comunque stampata), `--retry 3` e
  `--retry-connrefused`. Le barre finali di `url` e `path` vengono tolte prima di comporre
  l'indirizzo, cosi' si possono scrivere con o senza.

### Controlli in locale (solo sviluppo)

Due script in `build/` (cartella gitignored) provano la pipeline senza spingere niente:
`python build\estrai_run.py` fa i controlli statici (YAML, `bash -n` su ogni blocco `run:`,
`uses: ./...` che punta a file esistenti con `on: workflow_call`, input e segreti passati
dichiarati, `inputs.X`/`secrets.X` mai dichiarati), `python build\prova_pipeline.py` esegue i
blocchi `run:` con un `curl` finto e verifica etichette di versione, note, messaggio Telegram e
indirizzi di upload. Il primo test vero resta il run su GitHub.

### Come si pubblica una release

Il tag lo crea `git flow release finish`: non si tagga a mano.

1. `git flow release start 1.0.4`: il ramo nasce da `develop`;
2. sulla release solo le ultime correzioni (niente roba nuova) e `pubspec.yaml` portato alla
   versione che si sta taggando **alzando il numero di build** (es. `1.0.3+4` → `1.0.4+5`):
   e' quella che mostreranno `flutter run`, la scritta in fondo al menu e i file della release;
3. `git flow release finish 1.0.4`: unisce a `master`, crea il tag `v1.0.4` e riporta tutto
   su `develop`;
4. `git push origin master develop --follow-tags`.

**E' il tag che fa partire tutto**: build + release + notifica Telegram. Deve stare su un commit
che contiene `.github/workflows/build-release.yml` (e i workflow che chiama), perche' GitHub
esegue il workflow del commit spinto: una pipeline modificata solo su `develop` non si vede
nella release finche' non e' arrivata su `master`.

Subito dopo, per riaprire lo sviluppo: su `develop` si porta `pubspec.yaml` alla versione
successiva (`1.0.5+6`) e si committa.

Per pubblicare invece lo **snapshot** di `develop` basta un tag sull'ultimo commit del ramo:

```powershell
git tag v1.0.4-SNAPSHOT
git push origin v1.0.4-SNAPSHOT
```

Esce come pre-release, quindi la "latest" del repository resta la stable di `master`, e contiene
il solo APK: l'IPA si costruisce solo per le release stabili.

## Fonti di verita'

- `lib/main.dart` — l'app.
- `pubspec.yaml` — dipendenze, font, configurazione icona e **versione** (unica fonte).
- `tool/make_icon.ps1` — l'icona.
- `tool/build_apk.ps1` — l'APK locale, con il nome della release.
- `.github/workflows/` — la pipeline: `build-release.yml` (inneschi e ordine dei job) piu' i
  workflow riusabili `read-version.yml`, `build-apk.yml`, `build-ipa.yml`, `release.yml` e
  `publish-private.yml`. L'IPA si costruisce solo sui tag stabili.
- `android/app/src/main/kotlin/.../MainActivity.kt` — il canale del suono di fine tempo.
- `android/app/src/main/AndroidManifest.xml` — nome app (`MTG Life Counter`) e icona.
- `ios/Runner.xcodeproj/project.pbxproj` — progetto iOS (Swift Package Manager, bundle id,
  firma automatica, iOS 15).

## Git flow (rami e versioni)

Il repository segue **git flow** (git-flow AVH, gia' inizializzato: si vede con
`git config --get-regexp gitflow`). I due rami stabili sono `master` (produzione) e `develop`
(integrazione); **su `master` non si committa mai a mano**, ci arrivano solo i rami di release
e di hotfix.

| ramo | nasce da | torna in | serve a |
| --- | --- | --- | --- |
| `feature/<nome>` | `develop` | `develop` | una cosa nuova |
| `bugfix/<nome>` | `develop` | `develop` | una correzione che non e' un'emergenza |
| `release/<versione>` | `develop` | `master` **e** `develop` | congela la versione da pubblicare |
| `hotfix/<versione>` | `master` | `master` **e** `develop` | ripara una release gia' pubblicata |

```powershell
git flow feature start <nome>     # apre il ramo da develop
git flow feature finish <nome>    # lo chiude e lo unisce a develop
git flow release start 1.0.4      # congela: da qui in poi solo correzioni
git flow release finish 1.0.4     # unisce a master, tagga v1.0.4 e riporta su develop
git flow hotfix start 1.0.4       # come release, ma parte da master
git flow hotfix finish 1.0.4
```

`release finish` e `hotfix finish` creano da soli il tag `v<versione>` (prefisso
`gitflow.prefix.versiontag`), quindi la versione del tag e quella in `pubspec.yaml` devono
combaciare.

### Versioni e tag

| dove | `version:` in pubspec.yaml | tag | come esce |
| --- | --- | --- | --- |
| `develop` | la versione **in sviluppo**, es. `1.0.4+5` | `v1.0.4-SNAPSHOT` | pre-release, non tocca la "latest" |
| `master` | la versione **pubblicata**, es. `1.0.4+5` | `v1.0.4` | release, diventa la "latest" |

- Il suffisso `-SNAPSHOT` sta **solo nel tag**, mai nel `version:` di `pubspec.yaml`: iOS
  (`CFBundleShortVersionString`) accetta solo numeri e il suffisso finirebbe dentro l'app.
- `develop` porta sempre la versione **successiva**: pubblicata la `1.0.4`, `develop` passa a
  `1.0.5+6`. Il numero dopo il `+` e' il `versionCode` di Android, sale di uno a ogni release e
  **non cala mai** (vedi "Comandi"); l'etichetta `-SNAPSHOT` vive solo nel nome del file, quindi
  l'app dice comunque `1.0.4+5`.
- Un tag snapshot va messo su un commit il cui `pubspec.yaml` porta **proprio quella versione**,
  altrimenti la pipeline avvisa con un `::warning::` e il file esce con l'etichetta del tag.

## Git

- Rami stabili `master` (produzione) e `develop` (integrazione): vedi "Git flow".
- Si lavora su `develop` o su un ramo `feature/*`, `bugfix/*`, `release/*`, `hotfix/*`.
- Commit in italiano, push **solo se richiesto**.
