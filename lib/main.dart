import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Font arrotondato e molto leggibile usato in tutta l'app.
/// E' un variable font: il peso si sceglie con FontVariation('wght', n).
const String kAppFontFamily = 'Nunito';

/// Font display condensato usato **solo** per le cifre (vita e dadi).
const String kNumberFontFamily = 'MedulaOne';

/// Font di testo con il font dell'app.
///
/// [weight] usa l'asse variabile "wght" del font, quindi il grassetto e'
/// reale e non sintetico; [fontWeight] viene impostato allo stesso valore
/// come ripiego nel caso le variazioni non siano supportate.
TextStyle appTextStyle({
  double? fontSize,
  double weight = 400,
  Color? color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: kAppFontFamily,
    fontSize: fontSize,
    color: color,
    letterSpacing: letterSpacing,
    fontWeight: weight >= 700
        ? FontWeight.w700
        : (weight >= 600 ? FontWeight.w600 : FontWeight.w400),
    fontVariations: [FontVariation('wght', weight)],
  );
}

/// Stile per le cifre grandi (vita e risultato dei dadi).
///
/// Medula One ha un solo peso, quindi qui non servono le variazioni.
TextStyle appNumberStyle({
  double? fontSize,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: kNumberFontFamily,
    fontSize: fontSize,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontWeight: FontWeight.w400,
  );
}

/// Dimensione (px) delle cifre grandi: la vita e il risultato dei dadi.
///
/// I segni "-" e "+" usano la stessa dimensione, cosi' condividono con le
/// cifre anche l'altezza di riga e restano allineati al loro centro senza
/// correzioni a mano.
///
/// E' una misura di progetto: la riga del contatore viene poi ridimensionata
/// per stare nella zona (vedi [LifeCounterPanelTouch]), quindi questo valore e'
/// anche la dimensione massima che il contatore puo' raggiungere.
const double kNumberFontSize = 300;

/// Larghezza fissa riservata alle cifre grandi (vita e dado).
///
/// La scatola e' sempre della stessa larghezza, quindi i segni accanto ("-" e
/// "+", oppure il dado) restano fermi anche quando il numero cambia numero di
/// cifre. Se il numero e' piu' lungo della scatola viene rimpicciolito invece di
/// allargare la riga.
///
/// Tutte le misure della riga sono multiple di [kNumberFontSize]: cosi' resta
/// tutto in proporzione qualunque valore le si dia.
const double kNumberBoxWidth = kNumberFontSize * 0.66;

/// Cifre grandi centrate in una scatola di larghezza fissa.
class FixedWidthNumber extends StatelessWidget {
  final String text;
  final TextStyle style;

  /// Larghezza della scatola. Di serie quella della vita, larga abbastanza per
  /// tre cifre; il dado ne usa una piu' stretta, perche' ha una cifra sola o
  /// due al massimo.
  final double width;

  const FixedWidthNumber(
    this.text, {
    super.key,
    required this.style,
    this.width = kNumberBoxWidth,
  });

  @override
  Widget build(BuildContext context) =>
      _FixedWidthBox(text, style: style, width: width);
}

/// Dimensione dei segni "-" e "+" accanto alle cifre.
///
/// E' la meta' della cifra della vita: i segni indicano dove si tocca, non
/// devono competere con il numero.
const double kSignFontSize = kNumberFontSize * 0.5;

/// Larghezza fissa riservata ai segni "-" e "+" accanto alle cifre.
///
/// Nel font le due larghezze non sono identiche, quindi fissarle mantiene la
/// riga simmetrica rispetto al numero e impedisce ai segni di spostarsi.
const double kSignBoxWidth = kSignFontSize * 0.29;

/// Spazio fra i segni e le cifre nella riga del contatore.
const double kCounterGap = kNumberFontSize * 0.13;

/// Margine ai due lati della riga del contatore, in frazione della zona.
///
/// La riga viene ridimensionata per stare nella zona (vedi
/// [LifeCounterPanelTouch]): senza margine arriva a filo del pannello e i segni
/// "-" e "+" finiscono sul bordo, addosso alla linea di mezzo e al bordo dello
/// schermo. Con il margine i segni restano dentro al pannello, piu' vicini al
/// numero.
const double kCounterSideInset = 0.08;

/// Larghezza della scatola del risultato del dado.
///
/// Un dado ha una cifra sola, due al massimo ("10"): una scatola larga quanto
/// quella della vita lascerebbe troppo vuoto attorno al numero.
const double kDiceBoxWidth = kNumberFontSize * 0.5;

/// Massima pausa fra due tocchi perche' facciano parte della stessa serie.
///
/// Con una pausa piu' lunga la serie e' finita e il tocco successivo riparte
/// da un saldo nuovo.
const Duration kComboWindow = Duration(milliseconds: 900);

/// Quanto e' piccolo il saldo della serie di tocchi ("-6", "+3").
///
/// E' piu' piccolo delle cifre della vita: il saldo e' un'informazione di
/// contorno e non deve competere con la cifra della vita. Il saldo e' la stessa
/// scritta del segno, solo rimpicciolita, quindi non serve ricalcolare
/// allineamento e linea di base: resta esattamente dove stava il segno.
const double kComboScale = 0.8;

/// Dimensione del valore di vita dell'avversario, scritto accanto al contatore.
///
/// Serve quando le due vite guardano in versi opposti (visualizzazione girata):
/// ognuno vede il numero dell'altro capovolto, quindi vicino al proprio numero ne
/// trova il valore. E' un'informazione di contorno, come i segni "-" e "+".
const double kOpponentLifeFontSize = kNumberFontSize * 0.3;

/// Di quanto la scritta va spostata, sopra o sotto la vita, per stare vicino
/// alle cifre.
///
/// La scritta e' fuori dal layout (vedi [_OpponentLife]), quindi la distanza
/// dalle cifre si sceglie a mano. Le cifre stanno sedute sulla linea di base e
/// intorno a loro c'e' tutto il vuoto del font, che e' diverso sopra e sotto:
/// una scritta appoggiata subito fuori dalla riga cadrebbe decine di px (di
/// progetto) staccata dal numero. Le misure si ricavano dalle metriche di Medula
/// One (ascendente 0,846, discendente 0,162, altezza delle cifre 0,605) e da uno
/// stacco di 19,3 px fra i due inchiostri, uguale nei due casi:
///
/// * scritta sopra la vita: discendente della scritta 0,162 x 90 = 14,6, vuoto
///   sopra le cifre (0,846 - 0,605) x 300 = 72,3 -> 14,6 + 72,3 - 19,3 = 67,6,
///   ossia 0,225 x 300;
/// * scritta sotto la vita: discendente delle cifre 0,162 x 300 = 48,6, vuoto
///   sopra la scritta (0,846 - 0,605) x 90 = 21,7 -> 48,6 + 21,7 - 19,3 = 51,
///   ossia 0,17 x 300.
///
/// Valgono per le vite fino a tre cifre, che sono le uniche che lasciano la riga
/// alta come una riga intera di [kNumberFontSize].
const double kOpponentLifeDrop = kNumberFontSize * 0.225;
const double kOpponentLifeRise = kNumberFontSize * 0.17;

/// Lunghezza del box del timer, prima di essere ruotato.
///
/// Il timer si legge nel verso delle cifre della zona a cui appartiene, quindi
/// il box viene ruotato di un quarto di giro: questa e' la sua lunghezza, cioe'
/// lo spazio che occupa nel verso in cui si legge ("MM:SS" piu' l'icona).
const double kTimerBoxWidth = kNumberFontSize * 0.36;

/// Altezza del box del timer, prima di essere ruotato.
const double kTimerBoxHeight = kNumberFontSize * 0.17;

/// Dimensione delle cifre del tempo rimasto.
///
/// Il tempo si legge da lontano ma non e' la vita: sta un gradino sotto.
const double kTimerFontSize = kNumberFontSize * 0.1;

/// Durata con cui il timer si accende la prima volta.
const int kTimerDefaultMinutes = 20;

/// Durata minima e massima scegliibile per il timer, in minuti.
const int kTimerMinMinutes = 1;
const int kTimerMaxMinutes = 180;

/// Canale verso il sistema per l'avviso di fine tempo.
///
/// Su Android risponde [MainActivity] con la sveglia di sistema, riprodotta sul
/// canale delle sveglie: si sente anche con i suoni dei media a zero, che e'
/// esattamente quello che serve quando il tempo scade mentre si sta giocando.
const MethodChannel _kAlarmChannel = MethodChannel('mtg_lifecounter/alarm');

/// Fa suonare l'avviso di fine tempo.
///
/// Fuori da Android (o se il canale non risponde) resta il suono di sistema,
/// che e' meglio di niente: il tempo e' comunque finito.
Future<void> _playTimerAlarm() async {
  try {
    await _kAlarmChannel.invokeMethod<void>('playAlarm');
  } catch (_) {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}

/// Zittisce l'avviso di fine tempo: il tempo e' stato rimesso in gioco (o
/// azzerato) e un allarme che continua a suonare non serve piu' a nessuno.
Future<void> _stopTimerAlarm() async {
  try {
    await _kAlarmChannel.invokeMethod<void>('stopAlarm');
  } catch (_) {
    // Fuori da Android non c'e' niente da fermare.
  }
}

/// Segno "-" o "+" accanto alle cifre, in una scatola di larghezza fissa.
class FixedWidthSign extends StatelessWidget {
  final String sign;
  final TextStyle style;

  const FixedWidthSign(this.sign, {super.key, required this.style});

  @override
  Widget build(BuildContext context) =>
      _FixedWidthBox(sign, style: style, width: kSignBoxWidth);
}

/// Testo di una riga sola, centrato in una scatola di larghezza fissa.
///
/// La scatola non cambia mai larghezza, quindi quello che le sta accanto resta
/// fermo anche quando il testo cambia. Se il testo non entra nella scatola
/// viene rimpicciolito invece di allargare (o far traboccare) la riga.
class _FixedWidthBox extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double width;

  const _FixedWidthBox(this.text, {required this.style, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lo schermo segue l'orientamento del telefono: le due zone si mettono una
  // sopra l'altra col telefono in verticale e una accanto all'altra in
  // orizzontale (vedi [_twoZones]).
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitDown,
  ]);
  // Schermo intero: la barra di stato (ora, batteria, notifiche) sparisce e le
  // due zone guadagnano la sua altezza. La barra di navigazione resta, perche'
  // serve a uscire dall'app: per toglierla basta svuotare la lista `overlays`.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: const [SystemUiOverlay.bottom],
  );
  runApp(LifeCounterApp());
}

class LifeCounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'MTG Life Counter',
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: kAppFontFamily),
      ),
      home: LifeCounterHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LifeCounterHome extends StatefulWidget {
  @override
  _LifeCounterHomeState createState() => _LifeCounterHomeState();
}

/// Colore predefinito (nessuna personalizzazione) della zona di un giocatore.
const Color kDefaultPanelColor = Color(0xFF121212);

/// Colori predefiniti selezionabili per la zona di un giocatore.
/// Sono tinte accese ma ancora abbastanza scure da lasciare leggibile
/// il testo bianco del contatore.
const List<PlayerColorOption> kPlayerColors = [
  PlayerColorOption(kDefaultPanelColor, 'Predefinito'),
  PlayerColorOption(Color(0xFF37474F), 'Ardesia'),
  PlayerColorOption(Color(0xFFC62828), 'Rosso'),
  PlayerColorOption(Color(0xFFEF6C00), 'Ambra'),
  PlayerColorOption(Color(0xFF2E7D32), 'Verde'),
  PlayerColorOption(Color(0xFF00897B), 'Verde acqua'),
  PlayerColorOption(Color(0xFF1565C0), 'Blu'),
  PlayerColorOption(Color(0xFF4527A0), 'Indaco'),
  PlayerColorOption(Color(0xFF6A1B9A), 'Viola'),
  PlayerColorOption(Color(0xFFAD1457), 'Magenta'),
];

/// Una scelta di colore per la zona del giocatore.
class PlayerColorOption {
  final Color color;
  final String name;

  const PlayerColorOption(this.color, this.name);
}

/// Esito della partita: la partita e' finita quando una delle due vite arriva a
/// zero (o sotto) e l'altra no.
///
/// Se sono a zero tutte e due non c'e' un vincitore: non e' successo niente di
/// decisivo, quindi nessuna delle due zone viene segnata.
enum GameOutcome { none, player1, player2 }

/// Vite con cui si comincia la partita la prima volta. La quantita' si sceglie
/// dalla voce "Nuova partita" del menu e resta ricordata fra una partita e
/// l'altra (vedi [_LifeCounterHomeState._startingLife]).
const int kStartingLife = 20;

/// Limiti della quantita' di vite scegliibile per una nuova partita.
const int kMinStartingLife = 1;
const int kMaxStartingLife = 999;

/// Chiavi con cui la partita in corso (vite e colori delle due zone) viene
/// ricordata fra un avvio e l'altro, ricaricamento della pagina compreso.
const String _kPlayer1LifeKey = 'player1Life';
const String _kPlayer2LifeKey = 'player2Life';
const String _kPlayer1ColorKey = 'player1Color';
const String _kPlayer2ColorKey = 'player2Color';

/// Vite con cui e' cominciata l'ultima nuova partita: la voce "Nuova partita"
/// del menu si riapre su questa quantita'.
const String _kStartingLifeKey = 'startingLife';

/// Se in verticale la vita del primo giocatore e' girata dall'altra parte,
/// cosi' i due numeri guardano in versi opposti (vedi [_twoZones]).
const String _kFlipFirstLifeKey = 'flipFirstLife';

/// Se la vita dell'avversario si vede accanto al contatore. La scritta compare
/// solo con la visualizzazione girata (vedi [_LifeCounterHomeState._buildLifeView]):
/// con le due vite nello stesso verso ognuno legge il numero dell'altro
/// capovolto, quindi non serve a niente.
const String _kOpponentLifeVisibleKey = 'opponentLifeVisible';

/// Impostazioni del timer di partita: se e' acceso, quanto dura e quanto tempo
/// resta. Il timer fermo resta fermo anche riaprendo l'app: a farlo ripartire
/// e' un tocco sul suo box.
const String _kTimerOnKey = 'timerOn';
const String _kTimerMinutesKey = 'timerMinutes';
const String _kTimerSecondsKey = 'timerSeconds';

/// Istante (millisecondi dall'epoca) in cui il timer finira', scritto solo
/// mentre scorre. E' un momento assoluto, non un tempo che resta: cosi' il conto
/// si ricalcola dall'orologio e non si perde nemmeno se l'app viene chiusa.
const String _kTimerDeadlineKey = 'timerDeadline';

/// Trasforma un colore letto dalla memoria in un [Color]; `null` se non
/// c'era niente da leggere.
Color? _storedColor(int? value) => value == null ? null : Color(value);

/// Durata dell'animazione con cui i tre pulsanti delle vite compaiono sopra la
/// voce "Nuova partita" del menu. La usano sia il picker sia la sua copia
/// invisibile: se i due tempi non fossero identici il menu si muoverebbe
/// mentre i pulsanti crescono.
const Duration _kLifePickerDuration = Duration(milliseconds: 180);

class _LifeCounterHomeState extends State<LifeCounterHome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int player1Life = kStartingLife;
  int player2Life = kStartingLife;

  /// Vite con cui si comincia una nuova partita: e' la quantita' scelta la
  /// volta scorsa dal menu (all'inizio [kStartingLife]).
  int _startingLife = kStartingLife;

  /// Colore di sfondo scelto da ciascun giocatore per la propria zona.
  Color _player1Color = kDefaultPanelColor;
  Color _player2Color = kDefaultPanelColor;

  /// Se la tavolozza dei colori e' aperta nella zona del giocatore.
  /// Si apre con uno swipe (verso il basso o verso l'alto) e si chiude
  /// toccando un colore o facendo lo swipe nella direzione opposta.
  bool _player1Palette = false;
  bool _player2Palette = false;

  /// Direzione dello swipe che ha aperto la tavolozza: +1 verso il basso,
  /// -1 verso l'alto. Serve per animare la "scheda" nel verso giusto e
  /// per sapere quale swipe chiude la tavolozza (quello opposto).
  int _player1OpenDirection = 1;
  int _player2OpenDirection = 1;

  bool _menuOpen = false;
  late final AnimationController _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// True mentre si sta scegliendo con quante vite ricominciare: i tre valori
  /// pronti compaiono sopra la voce "Nuova partita" del menu. Si spegne
  /// scegliendo un valore o richiudendo il menu (vedi [closeMenu]).
  bool _lifePickerOpen = false;

  /// Versione del pacchetto installato, numero di build compreso ("1.0.0+1"):
  /// e' quella che compare in fondo a sinistra col menu aperto. Resta vuota
  /// finche' non e' stata letta, e dove non c'e' (sul web in sviluppo il file
  /// della versione non viene generato) la scritta semplicemente non compare.
  String _appVersion = '';

  static const int _diceSides = 20;

  final math.Random _random = math.Random();

  /// Risultato dei dadi per stabilire chi inizia.
  bool _diceVisible = false;
  bool _rolling = false;
  int _player1Roll = 1;
  int _player2Roll = 1;
  Timer? _rollTimer;

  /// True appena l'utente cambia vite o colori: se la lettura della partita
  /// salvata arriva dopo, non deve piu' sovrascrivere quello che ha fatto.
  bool _touched = false;

  /// True se in verticale la vita del primo giocatore e' girata dall'altra
  /// parte: i due numeri guardano in versi opposti, cosi' ognuno dei due
  /// giocatori legge il proprio contatore dal proprio lato del telefono.
  bool _flipFirstLife = false;

  /// True se la vita dell'avversario si vede accanto al contatore quando le due
  /// vite guardano in versi opposti. Si puo' nascondere: e' un'informazione in
  /// piu' che non tutti vogliono avere sotto gli occhi per tutta la partita.
  bool _opponentLifeVisible = true;

  /// Timer di partita: se e' acceso, quanto dura e quanto tempo resta.
  /// Il timer non parte da solo: resta fermo finche' non si tocca il suo box.
  bool _timerOn = false;
  int _timerMinutes = kTimerDefaultMinutes;
  Duration _timerRemaining = const Duration(minutes: kTimerDefaultMinutes);
  bool _timerRunning = false;

  /// Momento in cui il timer finira': il tempo rimasto si ricalcola da qui a
  /// ogni tick, invece di sommarsi a mano, cosi' il conteggio non accumula
  /// ritardo. Essendo un istante assoluto e' anche quello che si salva in
  /// memoria, e da li' il tempo riparte giusto anche dopo che l'app e' stata
  /// chiusa.
  DateTime? _timerDeadline;

  Timer? _timerTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreGame());
    unawaited(_keepScreenOn());
    unawaited(_loadAppVersion());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rollTimer?.cancel();
    _timerTicker?.cancel();
    _menuController.dispose();
    // Un allarme lasciato suonare dopo la chiusura della schermata (o dopo un
    // hot restart) non lo ferma piu' nessuno.
    unawaited(_stopTimerAlarm());
    unawaited(_releaseScreen());
    super.dispose();
  }

  /// Il timer conta sull'orologio, non sui tick: quando l'app non e' piu'
  /// davanti il ticker si ferma (non serve a niente, e il sistema lo rallenta
  /// comunque) ma la scadenza resta, e al ritorno il tempo si ricalcola da li'.
  /// Cosi' il conto non si perde ne' mettendo l'app in secondo piano ne'
  /// chiudendola.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimerWithClock();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timerTicker?.cancel();
    }
  }

  /// Tiene acceso lo schermo finche' l'app e' davanti: fra un turno e l'altro si
  /// tocca il contatore di rado e lo schermo si spegnerebbe da solo.
  Future<void> _keepScreenOn() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Dove non e' supportato si torna al comportamento di prima (schermo che
      // si spegne): l'app funziona lo stesso.
    }
  }

  Future<void> _releaseScreen() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  /// Legge la versione dell'app (quella scritta da `flutter build` nel
  /// pacchetto, quindi anche il numero di build delle release) e la tiene da
  /// parte per la scritta del menu. Se non si riesce a leggerla la scritta non
  /// compare: e' un'informazione in piu', non deve dare errore.
  Future<void> _loadAppVersion() async {
    final String version;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
      version = '${info.version}$build';
    } catch (_) {
      return;
    }
    // Sul web, dove la versione vera non c'e', resta una stringa vuota.
    if (version.isEmpty || !mounted) return;
    setState(() => _appVersion = version);
  }

  /// Rilegge la partita lasciata in sospeso: vite e colori delle due zone.
  /// Se non c'e' niente in memoria si parte da [kStartingLife] e dal colore
  /// predefinito. Se la memoria non e' disponibile non succede nulla: si
  /// gioca con i valori di partenza.
  Future<void> _restoreGame() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    // Le impostazioni del tavolo (timer, vite della nuova partita) si
    // rileggono comunque: non fanno parte della partita in corso.
    final timerMinutes =
        (prefs.getInt(_kTimerMinutesKey) ?? kTimerDefaultMinutes).clamp(
          kTimerMinMinutes,
          kTimerMaxMinutes,
        );
    final timerSeconds = prefs.getInt(_kTimerSecondsKey);
    final timerOn = prefs.getBool(_kTimerOnKey) ?? false;

    // Il timer che stava scorrendo riprende da solo: il tempo che resta si
    // ricava dalla scadenza salvata, che e' un istante assoluto. Se la scadenza
    // e' passata mentre l'app era chiusa il tempo e' finito, ma senza suono:
    // nessuno era li' a sentirlo.
    final deadlineMillis = prefs.getInt(_kTimerDeadlineKey) ?? 0;
    final now = DateTime.now();
    final deadline = deadlineMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(deadlineMillis)
        : null;
    final running = timerOn && deadline != null && deadline.isAfter(now);
    final expired = timerOn && deadline != null && !running;

    setState(() {
      _timerMinutes = timerMinutes;
      _timerOn = timerOn;
      _timerRemaining = running
          ? deadline.difference(now)
          : Duration(
              seconds: expired
                  ? 0
                  : (timerSeconds ?? timerMinutes * 60).clamp(
                      0,
                      timerMinutes * 60,
                    ),
            );
      _timerRunning = running;
      _timerDeadline = running ? deadline : null;
      _startingLife = (prefs.getInt(_kStartingLifeKey) ?? kStartingLife).clamp(
        kMinStartingLife,
        kMaxStartingLife,
      );
      _flipFirstLife = prefs.getBool(_kFlipFirstLifeKey) ?? false;
      _opponentLifeVisible = prefs.getBool(_kOpponentLifeVisibleKey) ?? true;
    });
    if (running) {
      _startTicker();
    }

    if (_touched) return;

    final color1 = _storedColor(prefs.getInt(_kPlayer1ColorKey));
    final color2 = _storedColor(prefs.getInt(_kPlayer2ColorKey));
    setState(() {
      player1Life = prefs.getInt(_kPlayer1LifeKey) ?? _startingLife;
      player2Life = prefs.getInt(_kPlayer2LifeKey) ?? _startingLife;
      if (color1 != null) _player1Color = color1;
      if (color2 != null) _player2Color = color2;
    });
  }

  /// Ricorda la partita in corso e le impostazioni del tavolo (verso della vita
  /// del primo giocatore, vita avversaria a vista o no, timer). Sono quattro
  /// numeri e quattro impostazioni, si scrive a ogni cambiamento senza attese ne'
  /// salvataggi programmati.
  Future<void> _saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPlayer1LifeKey, player1Life);
      await prefs.setInt(_kPlayer2LifeKey, player2Life);
      await prefs.setInt(_kPlayer1ColorKey, _player1Color.toARGB32());
      await prefs.setInt(_kPlayer2ColorKey, _player2Color.toARGB32());
      await prefs.setBool(_kFlipFirstLifeKey, _flipFirstLife);
      await prefs.setBool(_kOpponentLifeVisibleKey, _opponentLifeVisible);
      await prefs.setBool(_kTimerOnKey, _timerOn);
      await prefs.setInt(_kTimerMinutesKey, _timerMinutes);
      await prefs.setInt(_kStartingLifeKey, _startingLife);
      // Il tempo rimasto si scrive arrotondato al secondo: e' quello che si
      // legge nel box del timer.
      await prefs.setInt(_kTimerSecondsKey, _timerRemaining.inSeconds);
      // La scadenza serve solo mentre il timer scorre (0 = fermo).
      await prefs.setInt(
        _kTimerDeadlineKey,
        _timerDeadline?.millisecondsSinceEpoch ?? 0,
      );
    } catch (_) {
      // Senza memoria la partita si gioca comunque, semplicemente non
      // viene ricordata.
    }
  }

  void updateLife(int player, int delta) {
    _touched = true;
    setState(() {
      if (player == 1)
        player1Life += delta;
      else
        player2Life += delta;
    });
    unawaited(_saveGame());
  }

  /// Nuova partita: le due vite tornano a [life], la quantita' scelta dal menu
  /// (che resta ricordata per le partite successive). Il timer non viene
  /// toccato: si azzera solo dal suo box (long press) o dalle impostazioni.
  void resetLife(int life) {
    _touched = true;
    final target = life.clamp(kMinStartingLife, kMaxStartingLife);
    setState(() {
      _startingLife = target;
      player1Life = target;
      player2Life = target;
    });
    unawaited(_saveGame());
  }

  /// True se un giocatore sta scegliendo il colore della propria zona.
  /// In quel momento il menu centrale non deve essere ne' visibile ne'
  /// utilizzabile (vedi [build]).
  bool get _paletteOpen => _player1Palette || _player2Palette;

  /// Mostra/nasconde la tavolozza dei colori nella zona del giocatore.
  ///
  /// [direction] e' +1 per uno swipe verso il basso e -1 per uno swipe
  /// verso l'alto: la "scheda" del contatore scorre in quel verso per
  /// rivelare la tavolozza sottostante. Una volta aperta, la tavolozza si
  /// chiude solo con lo swipe nella direzione opposta a quella di apertura.
  void togglePalette(int player, int direction) {
    final paletteOpen = player == 1 ? _player1Palette : _player2Palette;

    // Aprendo la tavolozza il menu centrale viene chiuso e nascosto.
    if (!paletteOpen) closeMenu();

    setState(() {
      final openDirection = player == 1
          ? _player1OpenDirection
          : _player2OpenDirection;

      if (!paletteOpen) {
        // Apre, ricordando da che parte e' arrivato lo swipe.
        if (player == 1) {
          _player1Palette = true;
          _player1OpenDirection = direction;
        } else {
          _player2Palette = true;
          _player2OpenDirection = direction;
        }
      } else if (direction == -openDirection) {
        // Chiude solo se lo swipe e' nella direzione opposta.
        if (player == 1) {
          _player1Palette = false;
        } else {
          _player2Palette = false;
        }
      }
    });
  }

  /// Applica il colore scelto alla zona del giocatore e torna a mostrare
  /// il contatore delle vite.
  void setPlayerColor(int player, Color color) {
    _touched = true;
    setState(() {
      if (player == 1) {
        _player1Color = color;
        _player1Palette = false;
      } else {
        _player2Color = color;
        _player2Palette = false;
      }
    });
    unawaited(_saveGame());
  }

  /// Chiude il menu e apre la schermata del tiro di dado, che fa "girare"
  /// i dadi per qualche istante e poi si ferma su un risultato definitivo
  /// (in caso di parita' si ritira).
  void rollForFirstPlayer() {
    closeMenu();
    _rollTimer?.cancel();
    setState(() {
      _diceVisible = true;
      _rolling = true;
      _player1Palette = false;
      _player2Palette = false;
    });

    var ticks = 0;
    _rollTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      ticks++;
      if (ticks < 12) {
        setState(() {
          _player1Roll = 1 + _random.nextInt(_diceSides);
          _player2Roll = 1 + _random.nextInt(_diceSides);
        });
        return;
      }

      timer.cancel();
      var result1 = 1 + _random.nextInt(_diceSides);
      var result2 = 1 + _random.nextInt(_diceSides);
      while (result1 == result2) {
        result1 = 1 + _random.nextInt(_diceSides);
        result2 = 1 + _random.nextInt(_diceSides);
      }
      setState(() {
        _player1Roll = result1;
        _player2Roll = result2;
        _rolling = false;
      });
    });
  }

  /// Chiude la schermata del tiro di dado e torna al contatore delle vite.
  void closeDiceRoll() {
    _rollTimer?.cancel();
    setState(() {
      _diceVisible = false;
      _rolling = false;
    });
  }

  void toggleMenu() {
    setState(() {
      _menuOpen = !_menuOpen;
      if (!_menuOpen) _lifePickerOpen = false;
    });
    if (_menuOpen) {
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
  }

  void closeMenu() {
    if (!_menuOpen) return;
    setState(() {
      _menuOpen = false;
      // La scelta delle vite vive appesa al menu: chiuso quello non ha piu'
      // senso lasciarla in giro.
      _lifePickerOpen = false;
    });
    _menuController.reverse();
  }

  void runMenuAction(VoidCallback action) {
    action();
    closeMenu();
  }

  /// Gira la vita del primo giocatore: le due zone restano dove sono, ma i
  /// numeri guardano in versi opposti, cosi' ognuno dei due giocatori legge il
  /// proprio contatore dal proprio lato del tavolo. Vale in tutti e due gli
  /// orientamenti: col telefono in verticale gira la zona in alto, in
  /// orizzontale quella di sinistra (vedi [_twoZones]).
  void toggleFlipFirstLife() {
    setState(() => _flipFirstLife = !_flipFirstLife);
    unawaited(_saveGame());
  }

  /// Mostra o nasconde la vita dell'avversario accanto al contatore.
  ///
  /// La scritta compare solo con la vita girata: fuori da li' la voce del menu
  /// resta in elenco ma spenta (vedi [_buildMenuItems]), cosi' il menu ha
  /// sempre le stesse voci nella stessa posizione.
  void toggleOpponentLife() {
    setState(() => _opponentLifeVisible = !_opponentLifeVisible);
    unawaited(_saveGame());
  }

  /// Accende o spegne il timer. Accendendolo il tempo torna da capo e resta
  /// fermo: a farlo partire e' il tocco sul suo box.
  void setTimerOn(bool enabled) {
    _timerTicker?.cancel();
    unawaited(_stopTimerAlarm());
    setState(() {
      _timerOn = enabled;
      _timerRunning = false;
      _timerDeadline = null;
      _timerRemaining = Duration(minutes: _timerMinutes);
    });
    unawaited(_saveGame());
  }

  /// Cambia la durata del timer, in minuti. Il tempo torna da capo e fermo.
  void setTimerMinutes(int minutes) {
    final clamped = minutes.clamp(kTimerMinMinutes, kTimerMaxMinutes);
    _timerTicker?.cancel();
    unawaited(_stopTimerAlarm());
    setState(() {
      _timerMinutes = clamped;
      _timerRunning = false;
      _timerDeadline = null;
      _timerRemaining = Duration(minutes: clamped);
    });
    unawaited(_saveGame());
  }

  /// Riporta il timer alla durata scelta, fermo: e' quello che fanno la voce
  /// delle impostazioni del timer e il long press sul box del timer.
  void resetTimer() {
    _timerTicker?.cancel();
    unawaited(_stopTimerAlarm());
    setState(() {
      _timerRunning = false;
      _timerDeadline = null;
      _timerRemaining = Duration(minutes: _timerMinutes);
    });
    // Il long press non ha nessun altro segno che sia andato a buon fine.
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_saveGame());
  }

  /// Fa scorrere il timer, o lo ferma se sta gia' scorrendo. Quando il tempo e'
  /// finito un tocco lo fa ripartire da capo.
  void toggleTimer() {
    if (!_timerOn) return;
    // Toccare il timer zittisce l'avviso di fine tempo: il tempo e' stato
    // rimesso in gioco (o fermato) e l'allarme non serve piu'.
    unawaited(_stopTimerAlarm());
    if (_timerRunning) {
      _pauseTimer();
      return;
    }
    if (_timerRemaining <= Duration.zero) {
      _timerRemaining = Duration(minutes: _timerMinutes);
    }
    _timerDeadline = DateTime.now().add(_timerRemaining);
    _startTicker();
    setState(() => _timerRunning = true);
    unawaited(_saveGame());
  }

  /// Fa scorrere il tempo rimasto verso lo zero: un tick ogni 200 ms, ma la
  /// schermata si ridisegna solo quando cambia il secondo scritto nel box.
  void _startTicker() {
    _timerTicker?.cancel();
    _timerTicker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _tickTimer(),
    );
  }

  /// Rimette il tempo rimasto in pari con l'orologio. Serve al ritorno in primo
  /// piano, quando il ticker era fermo: o la scadenza e' ancora la' e il timer
  /// riprende a scorrere, oppure e' passata mentre l'app era via e il tempo e'
  /// finito senza suono, perche' non c'era nessuno a sentirlo.
  void _syncTimerWithClock() {
    final deadline = _timerDeadline;
    if (deadline == null) return;

    final left = deadline.difference(DateTime.now());
    if (left > Duration.zero) {
      setState(() {
        _timerRemaining = left;
        _timerRunning = true;
      });
      _startTicker();
      return;
    }

    setState(() {
      _timerRemaining = Duration.zero;
      _timerRunning = false;
      _timerDeadline = null;
    });
    unawaited(_saveGame());
  }

  void _pauseTimer() {
    final deadline = _timerDeadline;
    _timerTicker?.cancel();
    setState(() {
      if (deadline != null) {
        final left = deadline.difference(DateTime.now());
        _timerRemaining = left > Duration.zero ? left : Duration.zero;
      }
      _timerDeadline = null;
      _timerRunning = false;
    });
    unawaited(_saveGame());
  }

  /// Aggiorna il tempo rimasto. La schermata viene ridisegnata solo quando
  /// cambia il secondo scritto nel box, non a ogni tick.
  void _tickTimer() {
    final deadline = _timerDeadline;
    if (deadline == null) return;

    final left = deadline.difference(DateTime.now());
    if (left > Duration.zero) {
      if (left.inSeconds != _timerRemaining.inSeconds) {
        setState(() => _timerRemaining = left);
      }
      return;
    }

    _timerTicker?.cancel();
    setState(() {
      _timerRemaining = Duration.zero;
      _timerRunning = false;
      _timerDeadline = null;
    });
    // Il tempo finito si sente anche senza guardare lo schermo: la vibrazione
    // piu' forte e la sveglia di sistema, sul canale delle sveglie.
    unawaited(HapticFeedback.heavyImpact());
    unawaited(_playTimerAlarm());
    unawaited(_saveGame());
  }

  /// Apre le impostazioni del timer: acceso/spento, durata in minuti e azzera.
  Future<void> showTimerSetup() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TimerSetupDialog(
        enabled: _timerOn,
        minutes: _timerMinutes,
        onEnabledChanged: setTimerOn,
        onMinutesChanged: setTimerMinutes,
        onReset: resetTimer,
      ),
    );
  }

  /// Mostra o nasconde la scelta delle vite con cui ricominciare: i tre valori
  /// pronti compaiono sopra la voce "Nuova partita", dentro al menu aperto
  /// (per questo la voce non lo chiude, al contrario delle altre).
  void toggleLifePresetPicker() {
    setState(() => _lifePickerOpen = !_lifePickerOpen);
  }

  /// Fa ripartire la partita con le vite scelte: azzera i contatori e richiude
  /// la scelta e il menu, cosi' le nuove vite si vedono subito.
  void startNewGame(int life) {
    resetLife(life);
    setState(() => _lifePickerOpen = false);
    closeMenu();
  }

  List<RadialMenuItem> _buildMenuItems() {
    return [
      RadialMenuItem(
        icon: Icons.refresh,
        tooltip: 'Nuova partita: $_startingLife vite',
        onTap: toggleLifePresetPicker,
      ),
      RadialMenuItem(
        icon: Icons.casino,
        tooltip: 'Chi inizia? (dado)',
        onTap: () => runMenuAction(rollForFirstPlayer),
      ),
      // Il verso della vita si sceglie in tutti e due gli orientamenti: in
      // verticale gira la zona in alto, in orizzontale quella di sinistra.
      RadialMenuItem(
        icon: Icons.flip,
        tooltip: _flipFirstLife
            ? 'Vita del giocatore 1 normale'
            : 'Gira la vita del giocatore 1',
        onTap: () => runMenuAction(toggleFlipFirstLife),
      ),
      // La voce resta sempre in elenco, anche quando non e' utilizzabile:
      // cosi' il menu ha sempre le stesse voci nella stessa posizione. Senza
      // la vita girata pero' la scritta dell'avversario non c'e' e la voce
      // resta spenta (scura e non toccabile), perche' altrimenti si potrebbe
      // "nascondere" qualcosa che non si vede.
      RadialMenuItem(
        icon: _opponentLifeVisible ? Icons.visibility : Icons.visibility_off,
        enabled: _flipFirstLife,
        tooltip: !_flipFirstLife
            ? 'Vita avversaria: prima gira la vita del giocatore 1'
            : _opponentLifeVisible
            ? 'Nascondi la vita avversaria'
            : 'Mostra la vita avversaria',
        onTap: () => runMenuAction(toggleOpponentLife),
      ),
      RadialMenuItem(
        icon: Icons.timer,
        tooltip: 'Timer di partita',
        onTap: () => runMenuAction(showTimerSetup),
      ),
    ];
  }

  /// Chi ha vinto, se la partita e' finita.
  GameOutcome get _gameOutcome {
    final out1 = player1Life <= 0;
    final out2 = player2Life <= 0;
    if (out1 == out2) return GameOutcome.none;
    return out1 ? GameOutcome.player2 : GameOutcome.player1;
  }

  /// True se lo schermo e' piu' largo che alto: le due zone vanno affiancate.
  static bool _isWide(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Dispone le due zone secondo l'orientamento: una sopra l'altra col telefono
  /// in verticale, una accanto all'altra in orizzontale, con la linea bianca in
  /// mezzo.
  ///
  /// Le cifre seguono lo schermo: col telefono in verticale si leggono in
  /// verticale, in orizzontale si leggono in orizzontale, come tutto il resto
  /// dell'app. Nessuna zona e' ruotata per conto suo, altrimenti girando il
  /// telefono i numeri resterebbero inclinati come prima. Se la vita del primo
  /// giocatore e' girata la sua zona ruota di mezzo giro, cosi' la legge dritta
  /// il giocatore seduto dall'altra parte del tavolo: vale in tutti e due gli
  /// orientamenti (in verticale la zona girata e' quella in alto, in
  /// orizzontale quella di sinistra).
  Widget _twoZones({
    required bool wide,
    required Widget first,
    required Widget second,
  }) {
    final flipFirst = _flipFirstLife;
    final zones = <Widget>[
      Expanded(
        child: RotatedBox(quarterTurns: flipFirst ? 2 : 0, child: first),
      ),
      _ZoneDivider(vertical: wide),
      Expanded(child: second),
    ];
    return wide ? Row(children: zones) : Column(children: zones);
  }

  /// Schermata del contatore delle vite, con il menu radiale al centro.
  /// Ogni zona mostra il contatore oppure la tavolozza dei colori.
  ///
  /// Se il timer e' acceso compare anche il suo box, ruotato come le cifre
  /// della zona che lo legge. Finche' le due vite guardano nello stesso verso
  /// ne basta uno solo (un numero dritto si legge da tutte e due le parti del
  /// tavolo); quando la vita del primo giocatore e' girata ne servono due, uno
  /// per giocatore, con lo stesso tempo:
  ///
  /// * in verticale, con le due vite nello stesso verso, un timer solo in cima
  ///   alla schermata;
  /// * in verticale, con la vita del primo giocatore girata, due timer (in cima
  ///   e in fondo), ognuno davanti a chi deve leggerlo;
  /// * in orizzontale, un timer solo in cima e centrato oppure, con la vita del
  ///   primo giocatore girata, due timer centrati ognuno sulla propria meta'
  ///   (in cima quella di sinistra, in fondo quella di destra): come in
  ///   verticale, ogni giocatore ha il timer sotto le cifre che legge.
  ///
  /// Il box fluttua sopra le zone: non toglie spazio al contatore, che resta
  /// grande come quando il timer e' spento.
  Widget _buildLifeView() {
    final outcome = _gameOutcome;
    final wide = _isWide(context);
    final flipped = _flipFirstLife;
    // La vita dell'avversario si vede solo se le due vite guardano in versi
    // opposti (ognuno legge il proprio numero) e se non e' stata nascosta dal
    // menu.
    final opponentLife = flipped && _opponentLifeVisible;

    final zones = _twoZones(
      wide: wide,
      first: PlayerZone(
        life: player1Life,
        onIncrease: () => updateLife(1, 1),
        onDecrease: () => updateLife(1, -1),
        backgroundColor: _player1Color,
        paletteVisible: _player1Palette,
        openDirection: _player1OpenDirection,
        onTogglePalette: (direction) => togglePalette(1, direction),
        onColorSelected: (color) => setPlayerColor(1, color),
        winner: outcome == GameOutcome.player1,
        defeated: outcome == GameOutcome.player2,
        // Con la visualizzazione girata le due vite guardano in versi opposti:
        // ognuno legge la propria, quindi accanto c'e' quella dell'altro.
        opponentLife: opponentLife ? player2Life : null,
        // Il timer di questa zona e' in cima allo schermo, che per le sue
        // cifre girate di mezzo giro vuol dire sotto il contatore: il posto
        // libero per la scritta e' dall'altra parte.
        opponentLifeAbove: true,
      ),
      second: PlayerZone(
        life: player2Life,
        onIncrease: () => updateLife(2, 1),
        onDecrease: () => updateLife(2, -1),
        backgroundColor: _player2Color,
        paletteVisible: _player2Palette,
        openDirection: _player2OpenDirection,
        onTogglePalette: (direction) => togglePalette(2, direction),
        onColorSelected: (color) => setPlayerColor(2, color),
        winner: outcome == GameOutcome.player2,
        defeated: outcome == GameOutcome.player1,
        opponentLife: opponentLife ? player1Life : null,
        // Questa zona non e' ruotata: le sue cifre si leggono come lo schermo e
        // il suo timer sta in fondo (in orizzontale in fondo alla meta' di
        // destra), quindi sopra il contatore c'e' posto per la scritta.
        opponentLifeAbove: true,
      ),
    );

    if (!_timerOn) return zones;

    // Il box sta sopra la zona, non accanto: accendere il timer non cambia di
    // un pixel il contatore delle vite. Il verso e' quello delle cifre che gli
    // stanno sotto, e ne serve uno per giocatore solo quando le due vite
    // guardano in versi opposti (cioe' con la vita del primo giocatore girata).
    Widget timer(int quarterTurns) => GameTimerBox(
      remaining: _timerRemaining,
      running: _timerRunning,
      quarterTurns: quarterTurns,
      onTap: toggleTimer,
      onLongPress: resetTimer,
    );

    // Il primo box sta in cima alla zona che lo legge, il secondo in fondo:
    // ognuno e' davanti al giocatore a cui appartiene, e per nessuno dei due
    // finisce dove sta la vita dell'avversario (che in ogni zona sta sopra il
    // contatore).
    final firstTimer = _FloatingTimer(
      alignment: Alignment.topCenter,
      child: timer(flipped ? 2 : 0),
    );
    final secondTimer = _FloatingTimer(
      alignment: Alignment.bottomCenter,
      child: timer(0),
    );

    // I due box ricalcano la disposizione delle zone (una sopra l'altra in
    // verticale, una accanto all'altra in orizzontale, con la stessa linea in
    // mezzo), cosi' ognuno e' centrato sulla zona che lo legge e non su un
    // quarto di schermo: in orizzontale il contatore sta al centro della sua
    // meta', non a meta' fra il centro e il bordo.
    final timers = wide
        ? Row(
            children: [
              Expanded(child: firstTimer),
              const SizedBox(width: _ZoneDivider._thickness),
              Expanded(child: secondTimer),
            ],
          )
        : Column(
            children: [
              Expanded(child: firstTimer),
              Expanded(child: secondTimer),
            ],
          );

    return Stack(
      children: [
        Positioned.fill(child: zones),
        // Finche' le due vite guardano nello stesso verso basta il primo box:
        // da tutte e due le parti del tavolo si legge lo stesso numero, e sta
        // in cima come le cifre.
        Positioned.fill(child: flipped ? timers : firstTimer),
      ],
    );
  }

  /// Schermata del tiro di dado: stesso layout delle vite, ma ogni
  /// pannello mostra il risultato del dado del giocatore.
  /// I pannelli non reagiscono ai tocchi: per uscire si usa solo il
  /// pulsante centrale di chiusura.
  Widget _buildRollView() {
    return _twoZones(
      wide: _isWide(context),
      first: DiceRollPanel(
        value: _player1Roll,
        rolling: _rolling,
        winner: !_rolling && _player1Roll > _player2Roll,
      ),
      second: DiceRollPanel(
        value: _player2Roll,
        rolling: _rolling,
        winner: !_rolling && _player2Roll > _player1Roll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // La scelta delle vite e' lo stesso widget in due posti: quello vero sopra
    // la voce "Nuova partita" e una copia invisibile sotto il menu, che serve
    // solo a tenere il gruppo simmetrico attorno al centro del menu.
    final lifePicker = _LifePresetPicker(
      life: _startingLife,
      onSelected: startNewGame,
    );

    return Scaffold(
      body: Stack(
        children: [
          if (_diceVisible)
            AbsorbPointer(absorbing: true, child: _buildRollView())
          else
            _buildLifeView(),
          if (_diceVisible)
            Center(
              child: _MenuIconButton(
                icon: Icons.close,
                tooltip: 'Chiudi',
                size: kMenuButtonSize,
                onTap: closeDiceRoll,
              ),
            )
          else ...[
            if (_menuOpen)
              Positioned.fill(
                // Sfondo scuro mentre il menu è aperto: assorbe i tocchi
                // (così non modificano le vite) ma non chiude il menu.
                // Per chiudere si usa solo la X al centro.
                child: AbsorbPointer(
                  child: Container(color: Colors.black.withOpacity(0.68)),
                ),
              ),
            // Mentre si sceglie un colore il menu centrale sparisce del
            // tutto: non è né visibile né utilizzabile.
            if (!_paletteOpen)
              Center(
                // Un filo di margine perche' in orizzontale, dove il gruppo
                // arriva a occupare tutta l'altezza, la scritta non finisca a
                // filo del bordo.
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  // La scelta delle vite e il menu sono un gruppo unico, quindi
                  // i tre pulsanti stanno esattamente sopra la voce "Nuova
                  // partita". La copia invisibile sotto il menu tiene il
                  // gruppo simmetrico rispetto al suo centro: cosi' i pulsanti
                  // compaiono **senza che il menu si sposti**, nemmeno di un
                  // pixel. In orizzontale, dove il gruppo non entrerebbe,
                  // l'insieme si rimpicciolisce invece di uscire dallo schermo.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSize(
                          duration: _kLifePickerDuration,
                          curve: Curves.easeOutCubic,
                          // Cresce verso l'alto, staccandosi dal menu: e' cosi'
                          // che compare, appesa alla sua voce.
                          alignment: Alignment.bottomCenter,
                          child: _lifePickerOpen
                              ? lifePicker
                              : const SizedBox.shrink(),
                        ),
                        RadialMenu(
                          animation: _menuController,
                          open: _menuOpen,
                          items: _buildMenuItems(),
                          onToggle: toggleMenu,
                        ),
                        AnimatedSize(
                          duration: _kLifePickerDuration,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          // Solo il posto occupato dalla scelta, senza
                          // disegnarla e senza lasciarla toccare.
                          child: _lifePickerOpen
                              ? IgnorePointer(
                                  child: Opacity(opacity: 0, child: lifePicker),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Versione dell'app, in fondo a sinistra: e' l'ultima cosa dello
            // Stack, quindi sta sopra il velo scuro del menu. Compare e
            // sparisce con le voci, cosi' mentre si gioca il pannello resta
            // pulito.
            if (_appVersion.isNotEmpty)
              Positioned(
                left: 0,
                bottom: 0,
                child: _AppVersionLabel(
                  version: _appVersion,
                  animation: _menuController,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Una voce del menu radiale: solo un'icona e l'azione associata.
class RadialMenuItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// False = voce spenta: si vede scura e non risponde ai tocchi. Serve alla
  /// voce della vita avversaria, che ha effetto solo con i valori specchiati.
  final bool enabled;

  const RadialMenuItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });
}

/// Dimensione del pulsante principale del menu (l'esagono bianco).
///
/// E' anche la misura della X che chiude il tiro di dado: sono lo stesso
/// pulsante, quindi conviene che siano uguali.
const double kMenuButtonSize = 88;

/// Pannello del tiro di dado: stessa disposizione del pannello delle vite,
/// ma mostra il risultato del dado. Non reagisce ai tocchi.
class DiceRollPanel extends StatelessWidget {
  final int value;
  final bool rolling;
  final bool winner;

  const DiceRollPanel({
    required this.value,
    required this.rolling,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    final resultColor = rolling
        ? Colors.white38
        : winner
        ? Colors.amber
        : Colors.white;

    return Container(
      color: winner
          ? Colors.amber.withOpacity(0.08)
          : Colors.black.withOpacity(0.08),
      child: Center(
        // Come il contatore delle vite: la riga e' disegnata a misura piena e
        // poi ridimensionata per stare nella zona, cosi' non ne esce mai.
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.casino,
                    size: 80,
                    color: winner ? Colors.amber : Colors.grey[400],
                  ),
                  SizedBox(width: 24),
                  FixedWidthNumber(
                    '$value',
                    width: kDiceBoxWidth,
                    style: appNumberStyle(
                      fontSize: kNumberFontSize,
                      color: resultColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  rolling
                      ? 'Lancio...'
                      : winner
                      ? 'INIZIA!'
                      : '',
                  key: ValueKey('$rolling-$winner'),
                  style: appTextStyle(
                    fontSize: 40,
                    weight: 700,
                    letterSpacing: 1.2,
                    color: winner ? Colors.amber : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu circolare: le voci compaiono in modo radiale attorno al pulsante
/// centrale, che si trasforma in una X per chiudere il menu.
class RadialMenu extends StatelessWidget {
  static const double _menuSize = 330;
  static const double _radius = 112;
  static const double _itemSize = 72;

  final Animation<double> animation;
  final bool open;
  final List<RadialMenuItem> items;
  final VoidCallback onToggle;

  const RadialMenu({
    required this.animation,
    required this.open,
    required this.items,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _menuSize,
      height: _menuSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !open,
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(items.length, (index) {
                  final angle =
                      -math.pi / 2 + (2 * math.pi * index) / items.length;
                  final destination = Offset(
                    math.cos(angle) * _radius,
                    math.sin(angle) * _radius,
                  );
                  final progress = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return AnimatedBuilder(
                    animation: progress,
                    builder: (context, child) {
                      final t = progress.value.clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: destination * t,
                        child: Transform.scale(
                          scale: t,
                          child: Opacity(opacity: t, child: child),
                        ),
                      );
                    },
                    child: _MenuIconButton(
                      icon: items[index].icon,
                      tooltip: items[index].tooltip,
                      size: _itemSize,
                      onTap: items[index].onTap,
                      enabled: items[index].enabled,
                      // Voci bianche piene: si staccano dallo sfondo scuro del
                      // menu e dalla zona che sta sotto.
                      background: _MenuIconButton.itemBackground,
                      foreground: _MenuIconButton.itemForeground,
                    ),
                  );
                }),
              ),
            ),
          ),
          _MenuIconButton(
            icon: open ? Icons.close : Icons.menu,
            tooltip: open ? 'Chiudi menu' : 'Apri menu',
            size: kMenuButtonSize,
            onTap: onToggle,
            // Il pulsante principale del menu e' l'esagono bianco pieno: e'
            // l'unico elemento dell'app che non prende il colore del
            // giocatore, cosi' si trova subito su qualunque sfondo.
            shape: _MenuIconButton.hexagonShape,
            background: _MenuIconButton.hexagonBackground,
            foreground: _MenuIconButton.hexagonForeground,
          ),
        ],
      ),
    );
  }
}

/// Versione dell'app, scritta piccola in fondo a sinistra mentre il menu e'
/// aperto.
///
/// Serve a sapere quale build sta girando: gli APK della release si chiamano
/// come la versione, ma una volta installati non lo dicono piu'. Compare e
/// sparisce con le voci del menu ([animation] e' la stessa) e non prende i
/// tocchi, cosi' non cambia niente di quello che c'e' sotto.
class _AppVersionLabel extends StatelessWidget {
  final String version;
  final Animation<double> animation;

  const _AppVersionLabel({required this.version, required this.animation});

  /// Distanza dal bordo dello schermo (o dalle barre di sistema) e misura del
  /// testo: piccola, ma con peso e spaziatura che la tengono leggibile.
  static const double _inset = 16;
  static const double _fontSize = 13;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) =>
            Opacity(opacity: animation.value, child: child),
        child: Padding(
          padding: EdgeInsets.only(
            left: insets.left + _inset,
            bottom: insets.bottom + _inset,
          ),
          child: Text(
            'v$version',
            style: appTextStyle(
              fontSize: _fontSize,
              weight: 700,
              letterSpacing: 1.2,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

/// Esagono regolare con un vertice in alto e uno in basso: e' la forma del
/// pulsante principale del menu.
///
/// La forma e' iscritta nella scatola che la usa, quindi l'esagono riempie
/// l'altezza e resta largo circa l'86%, come un esagono regolare. I vertici
/// partono da destra e la figura e' ruotata di un quarto di giro (`_phase`),
/// cosi' i due vertici finiscono sopra e sotto.
///
/// Gli angoli sono arrotondati: ogni vertice viene tagliato staccandosi di
/// `_cornerRatio * raggio` lungo i due lati che vi arrivano, e i due punti
/// sono uniti da una curva che passa per il vertice stesso.
class _HexagonBorder extends ShapeBorder {
  static const int _sides = 6;
  static const double _phase = math.pi / 2;
  static const double _cornerRatio = 0.25;

  const _HexagonBorder();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final radius = rect.shortestSide / 2;
    final corners = <Offset>[
      for (var i = 0; i < _sides; i++)
        Offset(
          center.dx + radius * math.cos(_phase + 2 * math.pi * i / _sides),
          center.dy + radius * math.sin(_phase + 2 * math.pi * i / _sides),
        ),
    ];

    // In un esagono regolare il lato e' lungo quanto il raggio, quindi
    // avanzare di `_cornerRatio` verso il vertice vicino equivale a
    // staccarsi dal vertice di `_cornerRatio * radius` lungo il lato.
    final path = Path();
    for (var i = 0; i < _sides; i++) {
      final corner = corners[i];
      final from = Offset.lerp(
        corner,
        corners[(i - 1 + _sides) % _sides],
        _cornerRatio,
      )!;
      final to = Offset.lerp(corner, corners[(i + 1) % _sides], _cornerRatio)!;
      if (i == 0) {
        path.moveTo(from.dx, from.dy);
      } else {
        path.lineTo(from.dx, from.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, to.dx, to.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// Pulsante del menu, con sola icona.
///
/// Le voci del menu e il pulsante principale usano i colori pieni definiti qui
/// sotto: cerchio bianco per le voci, esagono bianco per il centro. Gli altri
/// pulsanti della stessa famiglia (la X che chiude la schermata del dado e il
/// meno/piu' del timer) restano semitrasparenti.
///
/// Lo sfondo lo disegna un `CustomPaint` che riempie la forma, invece di un
/// `Material` ritagliato: il ritaglio di un tracciato (l'esagono) obbliga il
/// motore a compilare uno shader di "maschera di copertura" che su certe
/// schede video web non e' disponibile, e il primo tocco lasciava lo schermo
/// bianco per un istante. Il tocco lo mostra il colore della forma, come fa
/// la zona delle vite.
class _MenuIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onTap;

  /// False = voce spenta: lo sfondo si scurisce e i tocchi non fanno niente.
  final bool enabled;

  /// Forma dello sfondo: cerchio per le voci del menu, esagono per il
  /// pulsante principale.
  final ShapeBorder shape;

  /// Colori dello sfondo e dell'icona.
  final Color background;
  final Color foreground;

  /// Forma del pulsante principale del menu.
  static const ShapeBorder hexagonShape = _HexagonBorder();

  /// Sfondo bianco **pieno** e icona nera, senza trasparenze: il pulsante
  /// principale deve restare leggibile su qualunque colore di scheda.
  static const Color hexagonBackground = Color(0xFFFFFFFF);
  static const Color hexagonForeground = Color(0xFF000000);

  /// Colori delle voci del menu, quelle attorno al pulsante principale: bianco
  /// **pieno** e icona nera, come il centro. La trasparenza lasciava vedere la
  /// zona che sta sotto, e sopra il velo scuro del menu le voci si distinguevano
  /// meno.
  static const Color itemBackground = Color(0xFFFFFFFF);
  static const Color itemForeground = Color(0xFF000000);

  /// Colori di serie degli altri pulsanti: nero al 65% e bianco al 70%.
  static const Color _defaultBackground = Color(0xA6000000);
  static const Color _defaultForeground = Color(0xB3FFFFFF);

  /// Quanto si avvicina il fondo all'icona mentre il pulsante e' premuto.
  static const double _pressedMix = 0.22;

  /// Quanto si scurisce lo sfondo di una voce spenta: da bianco a un grigio
  /// scuro, che si stacca sia dalle voci accese sia dallo sfondo del menu.
  static const double _disabledMix = 0.6;

  const _MenuIconButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.enabled = true,
    this.shape = const CircleBorder(),
    this.background = _defaultBackground,
    this.foreground = _defaultForeground,
  });

  @override
  State<_MenuIconButton> createState() => _MenuIconButtonState();
}

class _MenuIconButtonState extends State<_MenuIconButton> {
  bool _pressed = false;

  /// Rotazione dell'icona mentre entra: un quarto di giro indietro fino a
  /// dritta. Con `turns: animation` (un giro intero) l'icona faceva un giro
  /// completo a ogni pressione, e sembrava una ruota che gira a vuoto.
  static final Tween<double> _iconTurn = Tween<double>(begin: -0.25, end: 0);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final background = !enabled
        // Voce spenta: sfondo scurito invece che bianco pieno, cosi' si legge
        // come "c'e' ma non si tocca" anche sopra una zona di colore chiaro.
        ? Color.lerp(
            widget.background,
            Colors.black,
            _MenuIconButton._disabledMix,
          )!
        : _pressed
        ? Color.lerp(
            widget.background,
            widget.foreground,
            _MenuIconButton._pressedMix,
          )!
        : widget.background;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Senza i gestori la voce non entra nell'arena dei tocchi: non si
        // preme, non si illumina e non lascia il velo appiccicato.
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled
            ? (_) {
                _setPressed(false);
                widget.onTap();
              }
            : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _MenuButtonShapePainter(
              shape: widget.shape,
              color: background,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: _iconTurn.animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  widget.icon,
                  key: ValueKey(widget.icon),
                  size: widget.size * 0.5,
                  color: widget.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Riempie la forma di un pulsante del menu: nessun ritaglio, solo il
/// tracciato riempito.
class _MenuButtonShapePainter extends CustomPainter {
  final ShapeBorder shape;
  final Color color;

  const _MenuButtonShapePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      shape.getOuterPath(Offset.zero & size),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_MenuButtonShapePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
}

/// Linea che separa le due zone.
///
/// Segue l'orientamento: in verticale e' orizzontale (le zone sono una sopra
/// l'altra), in orizzontale e' verticale (le zone sono affiancate).
class _ZoneDivider extends StatelessWidget {
  final bool vertical;

  /// Spessore della linea e colore: bianco pieno, cosi' la separazione fra le
  /// due meta' si vede sempre.
  static const double _thickness = 3;
  static const Color _color = Colors.white;

  const _ZoneDivider({required this.vertical});

  @override
  Widget build(BuildContext context) => vertical
      ? const VerticalDivider(
          width: _thickness,
          thickness: _thickness,
          color: _color,
        )
      : const Divider(height: _thickness, thickness: _thickness, color: _color);
}

/// Zona di un giocatore: mostra il contatore delle vite con la tavolozza
/// dei colori "sotto". Lo swipe puo' arrivare dall'alto o dal basso: il
/// contatore e' una scheda che scorre via nel verso dello swipe scoprendo
/// la tavolozza; per chiuderla serve uno swipe nel verso opposto.
class PlayerZone extends StatelessWidget {
  final int life;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final Color backgroundColor;
  final bool paletteVisible;

  /// True se questo giocatore ha vinto la partita in corso.
  final bool winner;

  /// True se questo giocatore e' a zero mentre l'altro e' ancora in gioco.
  final bool defeated;

  /// Vita dell'avversario, scritta sopra o sotto il contatore. Si usa solo con
  /// la visualizzazione girata, quando le due vite guardano in versi opposti:
  /// cosi' ognuno legge il numero dell'altro senza doverlo capovolgere. Null = la
  /// scritta non compare.
  final int? opponentLife;

  /// True se la scritta va sopra la vita, false se va sotto. Si sceglie il lato
  /// libero dal timer, che in ogni zona fluttua in fondo alle cifre di chi le
  /// legge: il posto libero e' sopra il contatore.
  final bool opponentLifeAbove;

  /// Direzione dello swipe che ha aperto la tavolozza (+1 verso il basso,
  /// -1 verso l'alto): determina da che parte scorre la "scheda".
  final int openDirection;

  /// Riceve la direzione dello swipe: +1 verso il basso, -1 verso l'alto.
  final ValueChanged<int> onTogglePalette;
  final ValueChanged<Color> onColorSelected;

  const PlayerZone({
    required this.life,
    required this.onIncrease,
    required this.onDecrease,
    required this.backgroundColor,
    required this.paletteVisible,
    required this.openDirection,
    required this.onTogglePalette,
    required this.onColorSelected,
    this.winner = false,
    this.defeated = false,
    this.opponentLife,
    this.opponentLifeAbove = true,
  });

  /// Velocita' minima (px/s) perche' uno swipe venga considerato tale.
  static const double _minSwipeVelocity = 100;

  /// Quanto della scheda del contatore resta visibile mentre si scelgono i
  /// colori: e' la striscia con la maniglia, da cui si riporta indietro la
  /// scheda.
  static const double _peekHeight = 38;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Lo swipe puo' arrivare dall'alto o dal basso. E' riconosciuto solo
      // se il dito si muove oltre la soglia di trascinamento, quindi non
      // interferisce con i tocchi che cambiano le vite.
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < _minSwipeVelocity) return;
        onTogglePalette(velocity > 0 ? 1 : -1);
      },
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            if (maxHeight <= 0) return const SizedBox.expand();

            final slideDistance = math.max(0.0, maxHeight - _peekHeight);

            // Lo swipe verso il basso manda la card verso il basso (bordo
            // scoperto in alto), lo swipe verso l'alto la manda verso
            // l'alto (bordo scoperto in basso).
            final cardGoesDown = openDirection >= 0;

            return Stack(
              fit: StackFit.expand,
              children: [
                ColorPalette(
                  selected: backgroundColor,
                  onSelect: onColorSelected,
                ),
                // La tavolozza sta "sotto": il contatore e' una scheda che
                // scorre nel verso dello swipe, lasciando scoperto il
                // bordo dal quale si e' entrati.
                AnimatedSlide(
                  offset: paletteVisible
                      ? Offset(
                          0,
                          (cardGoesDown ? slideDistance : -slideDistance) /
                              maxHeight,
                        )
                      : Offset.zero,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    color: backgroundColor,
                    child: Column(
                      children: [
                        // La maniglia compare solo mentre si modifica il
                        // colore: sulla schermata principale non c'e'
                        // nessun elemento di disturbo, e sta sempre sul
                        // bordo scoperto della card.
                        if (paletteVisible && cardGoesDown)
                          _ZoneCardHandle(cardColor: backgroundColor),
                        Expanded(
                          child: LifeCounterPanelTouch(
                            life: life,
                            onIncrease: onIncrease,
                            onDecrease: onDecrease,
                            winner: winner,
                            defeated: defeated,
                            opponentLife: opponentLife,
                            opponentLifeAbove: opponentLifeAbove,
                          ),
                        ),
                        if (paletteVisible && !cardGoesDown)
                          _ZoneCardHandle(cardColor: backgroundColor),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bordo visibile della scheda del contatore mentre si scelgono i colori.
///
/// E' una barra arrotondata al centro del bordo scoperto, come la maniglia di
/// una dock: si capisce che la scheda si riporta indietro trascinandola, senza
/// bisogno di una scritta. La barra e' centrata, quindi non deve sapere da che
/// parte e' il bordo scoperto.
class _ZoneCardHandle extends StatelessWidget {
  /// Colore della scheda su cui la maniglia sta: da qui si ricava la tinta
  /// della barra.
  final Color cardColor;

  /// Quanto e' lunga la barra: abbastanza da leggersi come maniglia, molto
  /// meno della scheda, cosi' non sembra un bordo della card.
  static const double _barWidth = 72;

  /// Spessore della barra (e raggio delle sue estremita').
  static const double _barThickness = 5;

  const _ZoneCardHandle({required this.cardColor});

  /// Tinta della maniglia: quella della scheda ma piu' scura, cosi' si stacca
  /// dal bordo della scheda su cui e' disegnata.
  ///
  /// Se la scheda e' gia' quasi nera (il colore predefinito) scurirla la
  /// renderebbe invisibile: in quel caso la maniglia si schiarisce invece.
  static Color _barColor(Color card) {
    final darker = Color.lerp(card, Colors.black, 0.35)!;
    if (darker.computeLuminance() < 0.02) {
      return Color.lerp(card, Colors.white, 0.4)!;
    }
    return darker;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PlayerZone._peekHeight,
      child: Center(
        child: Container(
          width: _barWidth,
          height: _barThickness,
          decoration: BoxDecoration(
            color: _barColor(cardColor),
            borderRadius: BorderRadius.circular(_barThickness / 2),
          ),
        ),
      ),
    );
  }
}

/// Tavolozza con i colori predefiniti per la zona del giocatore.
class ColorPalette extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onSelect;

  const ColorPalette({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Velo scuro: rende gli swatch leggibili anche quando il colore
      // attualmente selezionato coincide con quello di uno di essi.
      color: Colors.black.withValues(alpha: 0.55),
      // Spazio ai bordi pari al bordo visibile della scheda, cosi' gli
      // swatch non finiscono mai sotto di essa.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PlayerZone._peekHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final option in kPlayerColors)
                  _ColorSwatch(
                    color: option.color,
                    label: option.name,
                    selected: option.color == selected,
                    onTap: () => onSelect(option.color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Singolo swatch di colore: solo colore, con spunta se selezionato.
///
/// E' un rettangolo pieno senza bordo: il colore si vede tutto, senza una
/// cornice che intorno a un colore scuro si legge come un anello bianco. La
/// scelta si vede dalla spunta.
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Swatch piu' largo che alto, con gli angoli appena arrotondati.
  static const double _width = 68;
  static const double _height = 48;
  static const double _cornerRadius = 8;

  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_cornerRadius);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: borderRadius),
          child: Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(color: color, borderRadius: borderRadius),
            child: selected
                ? const Icon(Icons.check, size: 30, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Cartello che dice com'e' finita la partita: "VINCE" per chi ha vinto,
/// "PERDE" per chi e' a zero.
///
/// E' disegnato con le stesse proporzioni della cifra della vita (le misure
/// sono multipli di [kNumberFontSize]) e sta dentro la riga ridimensionata
/// insieme al contatore, quindi entra sempre nel pannello e resta dritto per
/// il giocatore a cui la zona appartiene.
///
/// I colori sono pieni e opposti (ambra con scritta nera, nero con scritta
/// bianca) invece di seguire la tinta della zona: cosi' il cartello si legge
/// su qualunque colore il giocatore abbia scelto.
class _OutcomeBadge extends StatelessWidget {
  final bool winner;

  const _OutcomeBadge({required this.winner});

  /// Altezza della scritta: e' un cartello, non deve competere con la cifra
  /// della vita.
  static const double _fontSize = kNumberFontSize * 0.14;

  /// Il trofeo e' poco piu' alto della scritta, cosi' si riconosce subito.
  static const double _iconSize = kNumberFontSize * 0.16;

  /// Spazio fra il contatore e il cartello.
  static const double _gap = kNumberFontSize * 0.03;

  /// Spazio fra il bordo e il contenuto, e raggio degli angoli.
  static const double _paddingHorizontal = kNumberFontSize * 0.06;
  static const double _paddingVertical = kNumberFontSize * 0.02;
  static const double _radius = 14;

  /// Colore di chi ha vinto: ambra piena, con la scritta nera.
  static const Color _winnerBackground = Colors.amber;
  static const Color _winnerForeground = Colors.black;

  /// Colore di chi e' a zero: nero quasi pieno, con la scritta chiara.
  static const Color _defeatedBackground = Color(0xE6000000);
  static const Color _defeatedForeground = Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    final background = winner ? _winnerBackground : _defeatedBackground;
    final foreground = winner ? _winnerForeground : _defeatedForeground;

    return Padding(
      padding: const EdgeInsets.only(top: _gap),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingHorizontal,
          vertical: _paddingVertical,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              winner ? Icons.emoji_events : Icons.close,
              size: _iconSize,
              color: foreground,
            ),
            const SizedBox(width: _gap),
            Text(
              winner ? 'VINCE' : 'PERDE',
              maxLines: 1,
              softWrap: false,
              style: appTextStyle(
                fontSize: _fontSize,
                weight: 800,
                color: foreground,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contatore delle vite di una zona.
///
/// Il tocco sulla meta' sinistra toglie una vita, quello sulla meta' destra
/// la aggiunge. La meta' premuta si scurisce per un attimo, cosi' si vede
/// subito quale lato si sta toccando senza spostare nulla sullo schermo.
///
/// I tocchi ravvicinati (meno di [kComboWindow] l'uno dall'altro) formano una
/// serie: il saldo della serie prende il posto del segno del lato verso cui sta
/// andando ("-6" a sinistra, "+3" a destra), cosi' si vede quante vite si sono
/// tolte o aggiunte senza contare i tocchi. Il saldo e' una somma, quindi
/// continuare la serie dal lato opposto non la interrompe: il saldo si sposta
/// sull'altro segno.
///
/// I segni "-" e "+" sono testo e non icone: usano lo stesso font dei numeri
/// ([kNumberFontFamily]), cosi' il pannello ha una sola famiglia tipografica.
///
/// Quando la partita e' finita la zona lo dice: chi ha vinto si accende (velo
/// ambra e cartello "VINCE" sotto il contatore), chi e' a zero si spegne (velo
/// scuro, cifre rosse e cartello "PERDE").
class LifeCounterPanelTouch extends StatefulWidget {
  final int life;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  /// True se questo giocatore ha vinto la partita.
  final bool winner;

  /// True se questo giocatore e' a zero mentre l'altro e' ancora in gioco.
  final bool defeated;

  /// Vita dell'avversario, da scrivere accanto al contatore: si usa solo quando
  /// la visualizzazione e' girata (vedi [PlayerZone.opponentLife]). Null = la
  /// scritta non compare.
  final int? opponentLife;

  /// True se la scritta va sopra la vita, false se va sotto.
  final bool opponentLifeAbove;

  const LifeCounterPanelTouch({
    super.key,
    required this.life,
    required this.onIncrease,
    required this.onDecrease,
    this.winner = false,
    this.defeated = false,
    this.opponentLife,
    this.opponentLifeAbove = true,
  });

  /// Colore dei segni "-" e "+": come il numero (bianco) ma con opacita'
  /// ridotta, cosi' indicano dove toccare senza rubare attenzione alla
  /// cifra della vita.
  static const Color _signColor = Color(0x8CFFFFFF);

  /// Velo della zona di chi ha vinto: un'ombra di ambra, la zona si "accende".
  /// E' un velo e non un colore di sfondo, cosi' vale su qualunque tinta abbia
  /// scelto il giocatore.
  static const Color _winnerVeil = Color(0x29FFC107);

  /// Velo della zona di chi e' a zero: nero, la zona si spegne.
  static const Color _defeatedVeil = Color(0x73000000);

  /// Colore delle cifre di chi e' a zero: rosso, si legge anche da lontano.
  static const Color _defeatedNumberColor = Color(0xFFFF5252);

  @override
  State<LifeCounterPanelTouch> createState() => _LifeCounterPanelTouchState();
}

class _LifeCounterPanelTouchState extends State<LifeCounterPanelTouch> {
  /// Meta' premuta: -1 sinistra (toglie vita), +1 destra (aggiunge vita),
  /// 0 nessuna. Serve solo al feedback visivo.
  int _pressedSide = 0;

  /// Per quanto il lato toccato resta scuro dopo che il dito si e' alzato:
  /// un tocco veloce e' quasi istantaneo, senza questa pausa il velo
  /// sarebbe invisibile.
  static const Duration _shadeHold = Duration(milliseconds: 180);

  /// Pausa fra due passi mentre il dito resta premuto su un lato.
  ///
  /// Toccando si cambia la vita di un punto per volta: per toglierne venti
  /// servirebbero venti tocchi. Tenendo premuto il punto si ripete da solo
  /// a questo ritmo, cosi' una vita intera si cambia in un gesto solo.
  static const Duration _holdStep = Duration(milliseconds: 140);

  Timer? _shadeTimer;

  /// Ripetizione in corso sotto il dito: finche' e' attivo il contatore va da
  /// solo.
  Timer? _holdTimer;

  /// Saldo della serie di tocchi in corso: negativo se si sta togliendo vita,
  /// positivo se la si sta aggiungendo. 0 = nessuna serie da mostrare.
  int _combo = 0;

  Timer? _comboTimer;

  @override
  void dispose() {
    _shadeTimer?.cancel();
    _comboTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  /// Aggiunge un tocco alla serie in corso, o ne apre una nuova.
  ///
  /// Il saldo e' una somma algebrica, quindi continuare la serie dal lato
  /// opposto non la interrompe: togliere vita dopo averla aggiunta (o
  /// viceversa) riduce il saldo invece di ripartire da capo.
  void _addToCombo(int delta) {
    // Ogni tocco rimanda la fine della serie. Se il timer e' ancora in attesa
    // la serie continua; se e' gia' scaduto il saldo e' tornato a 0, quindi
    // questo tocco vale come inizio di una serie nuova.
    _comboTimer?.cancel();
    setState(() => _combo += delta);
    _comboTimer = Timer(kComboWindow, () {
      if (mounted) setState(() => _combo = 0);
    });
  }

  void _showShade(int side) {
    _shadeTimer?.cancel();
    if (_pressedSide != side) setState(() => _pressedSide = side);
  }

  /// Applica un punto di vita dal lato indicato (-1 toglie, +1 aggiunge).
  ///
  /// E' lo stesso lavoro del tocco: il velo si accende, la vita cambia e il
  /// punto entra nella serie in corso, cosi' tenendo premuto il saldo sale
  /// come se si stesse toccando velocemente.
  void _applySide(int side) {
    if (!mounted) return;
    _showShade(side);
    if (side < 0) {
      widget.onDecrease();
    } else {
      widget.onIncrease();
    }
    _addToCombo(side);
  }

  /// Il dito si e' fermato su un lato: il primo punto parte subito, poi il
  /// contatore va da solo finche' il dito resta li'.
  void _startHold(int side) {
    _shadeTimer?.cancel();
    _applySide(side);
    // Un colpo secco avvisa che la ripetizione e' partita: da li' in poi la
    // vita cambia da sola e non serve guardare lo schermo.
    unawaited(HapticFeedback.selectionClick());
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(_holdStep, (_) => _applySide(side));
  }

  /// Il dito si e' alzato (o il gesto e' stato annullato): la ripetizione
  /// finisce, il saldo della serie resta invece in vista per un momento.
  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _hideShadeAfterHold() {
    _shadeTimer?.cancel();
    _shadeTimer = Timer(_shadeHold, () {
      if (mounted) setState(() => _pressedSide = 0);
    });
  }

  void _hideShadeNow() {
    _shadeTimer?.cancel();
    if (_pressedSide != 0) setState(() => _pressedSide = 0);
  }

  @override
  Widget build(BuildContext context) {
    // La cifra e' bianca, tranne per chi e' a zero: li' diventa rossa.
    final numberStyle = appNumberStyle(
      fontSize: kNumberFontSize,
      color: widget.defeated
          ? LifeCounterPanelTouch._defeatedNumberColor
          : null,
    );
    final decided = widget.winner || widget.defeated;
    // A partita decisa non c'e' posto per la vita dell'avversario: li' va il
    // cartello di chi ha vinto e di chi ha perso.
    final opponentLife = decided ? null : widget.opponentLife;

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = constraints.maxWidth / 2;
        // Margine ai lati: senza, il ridimensionamento porta la riga a filo
        // del pannello e i segni "-" e "+" finiscono sul bordo.
        final sideInset = constraints.maxWidth * kCounterSideInset;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Il velo si accende gia' al tocco, ma e' onTapUp a cambiare la
          // vita: cosi' il tocco che fa parte di uno swipe (quello che apre
          // la tavolozza dei colori) non viene contato come modifica.
          onTapDown: (details) =>
              _showShade(details.localPosition.dx < halfWidth ? -1 : 1),
          onTapCancel: _hideShadeNow,
          onTapUp: (details) {
            final decreasing = details.localPosition.dx < halfWidth;
            _showShade(decreasing ? -1 : 1);
            if (decreasing) {
              widget.onDecrease();
              _addToCombo(-1);
            } else {
              widget.onIncrease();
              _addToCombo(1);
            }
            _hideShadeAfterHold();
          },
          // Dito fermo su un lato: la vita cambia di continuo, senza dover
          // toccare venti volte. Il tocco lungo sostituisce il tocco singolo
          // (il riconoscitore del tocco perde il confronto appena scatta
          // questo), quindi a mettere il primo punto e' [_startHold].
          onLongPressStart: (details) =>
              _startHold(details.localPosition.dx < halfWidth ? -1 : 1),
          onLongPressEnd: (_) {
            _stopHold();
            _hideShadeAfterHold();
          },
          onLongPressCancel: () {
            _stopHold();
            _hideShadeNow();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Partita finita: il velo sta sotto al contatore, cosi' non
              // tocca la leggibilita' delle cifre.
              if (widget.winner)
                const ColoredBox(color: LifeCounterPanelTouch._winnerVeil),
              if (widget.defeated)
                const ColoredBox(color: LifeCounterPanelTouch._defeatedVeil),
              Center(
                // La riga del contatore e' disegnata a misura piena e poi
                // ridimensionata per stare nella zona: cosi' il contatore
                // riempie il pannello su qualunque schermo, senza misure da
                // ricalcolare a mano. Su un pannello molto largo resta della
                // dimensione di progetto, che fa da tetto.
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: sideInset),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // La vita dell'avversario e' disegnata fuori dal layout,
                        // quindi il suo posto nella colonna decide solo da che
                        // parte esce: prima della riga sale, dopo scende. In
                        // nessuno dei due casi sposta il contatore o lo fa
                        // rimpicciolire. Il lato lo sceglie chi costruisce la
                        // zona, in modo che non finisca sotto al timer.
                        if (opponentLife != null && widget.opponentLifeAbove)
                          _OpponentLife(life: opponentLife, above: true),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Lato sinistro della zona: diminuisce la vita.
                            _SignWithCombo(
                              sign: '-',
                              style: appNumberStyle(
                                fontSize: kSignFontSize,
                                color: LifeCounterPanelTouch._signColor,
                              ),
                              // Il saldo si mostra solo dal lato che gli
                              // corrisponde: quello negativo accanto al "-",
                              // l'altro al "+".
                              combo: _combo < 0 ? _combo : 0,
                            ),
                            const SizedBox(width: kCounterGap),
                            FixedWidthNumber(
                              '${widget.life}',
                              style: numberStyle,
                            ),
                            const SizedBox(width: kCounterGap),
                            // Lato destro della zona: aumenta la vita.
                            _SignWithCombo(
                              sign: '+',
                              style: appNumberStyle(
                                fontSize: kSignFontSize,
                                color: LifeCounterPanelTouch._signColor,
                              ),
                              combo: _combo > 0 ? _combo : 0,
                            ),
                          ],
                        ),
                        if (opponentLife != null && !widget.opponentLifeAbove)
                          _OpponentLife(life: opponentLife, above: false),
                        // Il cartello sta nella stessa riga ridimensionata del
                        // contatore: cosi' entra sempre nel pannello, e siccome
                        // la zona e' ruotata ogni giocatore lo legge dritto
                        // dalla propria parte.
                        if (decided) _OutcomeBadge(winner: widget.winner),
                      ],
                    ),
                  ),
                ),
              ),
              // Velo scuro sulla meta' premuta: "-" a sinistra, "+" a destra.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: _TapShade(visible: _pressedSide < 0),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: _TapShade(visible: _pressedSide > 0),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Velo scuro che copre una meta' del pannello delle vite: e' l'unico
/// feedback del tocco, quindi deve restare leggero.
class _TapShade extends StatelessWidget {
  final bool visible;

  const _TapShade({required this.visible});

  /// Nero al 32%: si nota subito ma lascia leggibili il numero della vita
  /// e l'icona sotto.
  static const Color _color = Color(0x52000000);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: const ColoredBox(color: _color),
      ),
    );
  }
}

/// Segno "-" o "+" del contatore, che diventa il saldo della serie di tocchi
/// quando ce n'e' una in corso: "-" -> "-6", "+" -> "+3".
///
/// Il saldo e' piu' largo della scatola del segno, ma e' disegnato dentro un
/// [OverflowBox] e quindi non partecipa al layout: comparendo o sparendo non
/// sposta di un pixel il segno a riposo ne' il numero della vita. [combo] vale
/// 0 quando non c'e' nessuna serie da mostrare.
class _SignWithCombo extends StatelessWidget {
  final String sign;
  final TextStyle style;
  final int combo;

  const _SignWithCombo({
    required this.sign,
    required this.style,
    required this.combo,
  });

  /// Il saldo e' l'informazione che conta in quel momento, quindi si accende
  /// rispetto al segno a riposo, che serve solo a indicare dove toccare. Cosi'
  /// resta leggibile anche sotto il velo scuro del tocco.
  static const Color _activeColor = Color(0xFFFFFFFF);

  /// Il "+" si scrive solo quando si aggiunge vita: quando il saldo e'
  /// negativo il segno e' gia' nella cifra.
  String get _label => combo > 0 ? '+$combo' : '$combo';

  @override
  Widget build(BuildContext context) {
    final showing = combo != 0;

    return Stack(
      alignment: Alignment.center,
      // Il saldo sporge ai lati della scatola del segno e non va ritagliato.
      clipBehavior: Clip.none,
      children: [
        // Il segno a riposo resta nell'albero anche mentre e' invisibile: e'
        // lui a dare alla scatola la sua larghezza e la sua altezza, cosi' il
        // saldo che lo sostituisce non cambia le misure della riga.
        Visibility(
          visible: !showing,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: FixedWidthSign(sign, style: style),
        ),
        if (showing)
          Positioned.fill(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              // Il saldo e' il segno rimpicciolito dello stesso fattore in ogni
              // direzione: la riga resta alta come quella del segno e la cifra
              // cade nella stessa posizione, solo piu' piccola.
              child: Transform.scale(
                scale: kComboScale,
                child: Text(
                  _label,
                  maxLines: 1,
                  softWrap: false,
                  // Bianco pieno: si accende rispetto al segno a riposo, che
                  // serve solo a indicare dove toccare.
                  style: style.copyWith(color: _activeColor),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Vita dell'avversario, scritta sopra o sotto il contatore quando le due vite
/// guardano in versi opposti (visualizzazione girata).
///
/// E' **fuori dal layout**: la scatola che la contiene e' di misura zero, quindi
/// la scritta non occupa spazio e il contatore resta centrato e della stessa
/// dimensione di quando la scritta non c'e'. [OverflowBox] la fa uscire sopra o
/// sotto la riga, e [kOpponentLifeDrop] / [kOpponentLifeRise] la riportano
/// vicino alle cifre, perche' intorno a loro c'e' tutto il vuoto del font.
class _OpponentLife extends StatelessWidget {
  final int life;

  /// True se la scritta sale sopra la vita, false se scende sotto.
  final bool above;

  const _OpponentLife({required this.life, required this.above});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 0,
      height: 0,
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        // La scatola di misura zero e' un pezzo della colonna del contatore:
        // giace sul bordo della riga da cui la scritta esce, quindi si aggancia
        // con il bordo inferiore quando sale e con quello superiore quando
        // scende.
        alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, above ? kOpponentLifeDrop : -kOpponentLifeRise),
          child: Text(
            '$life',
            maxLines: 1,
            softWrap: false,
            // Grigio come i segni "-" e "+": la vita dell'avversario si legge
            // senza rubare attenzione alla propria.
            style: appNumberStyle(
              fontSize: kOpponentLifeFontSize,
              color: LifeCounterPanelTouch._signColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tempo rimasto scritto come "MM:SS".
///
/// La durata massima ([kTimerMaxMinutes] minuti) sta in tre cifre, quindi il
/// minuto non va mai accorciato: cosi' la scritta non cambia larghezza mentre
/// il tempo scorre.
String _formatTime(Duration remaining) {
  final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
}

/// Box del tempo rimasto nel timer di partita.
///
/// E' una pillola scura con l'icona di avvio/pausa e il tempo: un tocco la fa
/// partire (o la ferma), perche' il timer non parte mai da solo. Quando il
/// tempo e' finito la pillola diventa ambra, che e' il segnale di turno
/// scaduto.
///
/// Tenendola premuta il tempo torna da capo e il timer si ferma: e' il modo per
/// ricominciare il turno senza passare dal menu. Non e' un tocco, quindi non
/// puo' succedere per sbaglio mentre si mette in pausa.
///
/// La pillola e' ruotata come le cifre della zona a cui appartiene: chi legge
/// la vita legge anche il timer nel suo verso.
class GameTimerBox extends StatelessWidget {
  final Duration remaining;
  final bool running;

  /// Quarti di giro della rotazione: 0 per la zona dritta, 2 per la zona
  /// girata (mezzo giro).
  final int quarterTurns;

  final VoidCallback onTap;

  /// Tenere premuto: riporta il tempo da capo e fermo.
  final VoidCallback onLongPress;

  const GameTimerBox({
    super.key,
    required this.remaining,
    required this.running,
    required this.onTap,
    required this.onLongPress,
    this.quarterTurns = 0,
  });

  /// Velo scuro quando il timer e' fermo, quasi pieno quando scorre: si
  /// distingue a colpo d'occhio se sta contando. Resta trasparente perche' il
  /// box fluttua sopra i numeri della vita.
  static const Color _idleBackground = Color(0xC0000000);
  static const Color _runningBackground = Color(0xF0000000);

  /// Tempo finito: ambra piena, la pillola si accende.
  static const Color _expiredBackground = Color(0xF2FFC107);

  static const Color _foreground = Color(0xFFFFFFFF);
  static const Color _expiredForeground = Color(0xFF000000);

  /// Misure interne, tutte ricavate dalla dimensione delle cifre.
  static const double _iconSize = kTimerFontSize * 0.6;
  static const double _iconGap = kTimerFontSize * 0.2;
  static const double _padding = kTimerFontSize * 0.3;

  @override
  Widget build(BuildContext context) {
    final expired = remaining <= Duration.zero;
    final background = expired
        ? _expiredBackground
        : (running ? _runningBackground : _idleBackground);
    final foreground = expired ? _expiredForeground : _foreground;

    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Tooltip(
        message: expired
            ? 'Tempo scaduto: tocca per ripartire, tieni premuto per azzerare'
            : (running
                  ? 'Ferma il timer (tieni premuto per azzerare)'
                  : 'Fai partire il timer (tieni premuto per azzerare)'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: kTimerBoxWidth,
            height: kTimerBoxHeight,
            padding: const EdgeInsets.symmetric(horizontal: _padding),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(kTimerBoxHeight / 2),
              // Ombra leggera: stacca il box dal contatore e gli da' l'aria di
              // una cosa appoggiata sopra, non di una parte del pannello.
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  running ? Icons.pause : Icons.play_arrow,
                  size: _iconSize,
                  color: foreground,
                ),
                const SizedBox(width: _iconGap),
                Expanded(
                  child: FixedWidthNumber(
                    _formatTime(remaining),
                    width: kTimerBoxWidth * 0.55,
                    style: appNumberStyle(
                      fontSize: kTimerFontSize,
                      color: foreground,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Box del timer appoggiato sopra la schermata.
///
/// E' fluttuante: sta sopra la zona delle vite in uno [Stack] e non le toglie
/// spazio, quindi accendere il timer non rimpicciolisce il contatore. Tutto
/// intorno al box la zona risponde come sempre: i tocchi li prende solo il box.
class _FloatingTimer extends StatelessWidget {
  /// Dove appoggiare il box dentro lo spazio che gli viene dato: in cima o in
  /// fondo, centrato. Chi costruisce il box lo mette in una meta' dello schermo
  /// quando le due zone sono affiancate, quindi [Alignment.topCenter] e
  /// [Alignment.bottomCenter] lo centrano sulla zona e non sullo schermo.
  final Alignment alignment;

  final Widget child;

  const _FloatingTimer({required this.alignment, required this.child});

  /// Distanza fra il box e il bordo dello schermo, o la barra di sistema
  /// quando il box sta in fondo.
  static const double _gap = kTimerFontSize * 0.6;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final atTop = alignment.y < 0;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(
          top: atTop ? insets.top + _gap : 0,
          bottom: atTop ? 0 : insets.bottom + _gap,
        ),
        child: child,
      ),
    );
  }
}

/// Impostazioni del timer: acceso/spento, durata in minuti e azzeramento.
///
/// E' un dialogo, quindi le modifiche si vedono subito nella schermata dietro
/// (il box del timer compare e cambia durata mentre si tocca) e non c'e' niente
/// da confermare.
class _TimerSetupDialog extends StatefulWidget {
  final bool enabled;
  final int minutes;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onMinutesChanged;
  final VoidCallback onReset;

  const _TimerSetupDialog({
    required this.enabled,
    required this.minutes,
    required this.onEnabledChanged,
    required this.onMinutesChanged,
    required this.onReset,
  });

  @override
  State<_TimerSetupDialog> createState() => _TimerSetupDialogState();
}

class _TimerSetupDialogState extends State<_TimerSetupDialog> {
  /// Durate pronte: sono i tempi che si usano di solito, cosi' quasi sempre non
  /// serve nemmeno toccare il "-" e il "+".
  static const List<int> _presets = [5, 10, 15, 20, 30, 45, 60, 90];

  late bool _enabled = widget.enabled;
  late int _minutes = widget.minutes;

  void _setEnabled(bool value) {
    setState(() => _enabled = value);
    widget.onEnabledChanged(value);
  }

  void _setMinutes(int value) {
    final clamped = value.clamp(kTimerMinMinutes, kTimerMaxMinutes);
    if (clamped == _minutes) return;
    setState(() => _minutes = clamped);
    widget.onMinutesChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'Timer',
        style: appTextStyle(fontSize: 24, weight: 800, letterSpacing: 2),
      ),
      // Scorrevole: col telefono in orizzontale le impostazioni non entrano
      // tutte nello schermo.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Abilitato',
                  style: appTextStyle(fontSize: 18, weight: 600),
                ),
                const Spacer(),
                Switch(value: _enabled, onChanged: _setEnabled),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Durata',
              style: appTextStyle(
                fontSize: 16,
                weight: 700,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MenuIconButton(
                  icon: Icons.remove,
                  tooltip: 'Un minuto in meno',
                  size: 52,
                  onTap: () => _setMinutes(_minutes - 1),
                ),
                // Il numero ha la sua scatola di larghezza fissa, cosi' il "-" e
                // il "+" non si spostano passando da 9 a 10 minuti.
                Container(
                  width: 110,
                  alignment: Alignment.center,
                  child: FixedWidthNumber(
                    '$_minutes',
                    width: 96,
                    style: appNumberStyle(fontSize: 60),
                  ),
                ),
                _MenuIconButton(
                  icon: Icons.add,
                  tooltip: 'Un minuto in piu',
                  size: 52,
                  onTap: () => _setMinutes(_minutes + 1),
                ),
              ],
            ),
            Text(
              'minuti',
              style: appTextStyle(
                fontSize: 15,
                weight: 600,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  _PresetButton(
                    label: '$preset',
                    selected: _minutes == preset,
                    onTap: () => _setMinutes(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () {
            widget.onReset();
            Navigator.of(context).pop();
          },
          child: const Text('Azzera'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}

/// Valore pronto su un pulsante tondo: lo usano le durate del timer e le vite
/// della nuova partita.
///
/// Quello scelto e' bianco pieno, come il pulsante principale del menu: si
/// legge subito quale valore e' impostato.
class _PresetButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: appTextStyle(
            fontSize: 16,
            weight: 700,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Scelta delle vite con cui cominciare una nuova partita: i tre valori pronti
/// che compaiono sopra la voce "Nuova partita" del menu.
///
/// Non e' una finestra a parte perche' la scelta e' di un tocco solo: si tocca
/// la quantita' e la partita riparte. Il valore in uso e' quello bianco pieno,
/// come nei preset del timer. La quantita' scelta resta ricordata (vedi
/// [_LifeCounterHomeState._startingLife]), cosi' la volta dopo e' ancora
/// quella.
class _LifePresetPicker extends StatelessWidget {
  /// Vite pronte: sono quelle dei formati che si giocano di solito (partita
  /// normale, due contro due, Commander), cosi' quasi sempre basta un tocco.
  static const List<int> _presets = [20, 30, 40];

  final int life;
  final ValueChanged<int> onSelected;

  const _LifePresetPicker({required this.life, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Stacco dalla voce del menu, che sta appena sotto.
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Seleziona i Punti Vita iniziali',
            style: appTextStyle(
              fontSize: 15,
              weight: 700,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final preset in _presets)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _PresetButton(
                    label: '$preset',
                    selected: life == preset,
                    onTap: () => onSelected(preset),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
