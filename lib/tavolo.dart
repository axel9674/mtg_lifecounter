/// Collegamento al tavolo di un torneo.
///
/// Il segnapunti resta **autonomo**: questo file e' il "di piu'", quello che si
/// accende quando c'e' una serata in corso. Se il collegamento non c'e' o cade,
/// l'app continua a contare la vita come sempre: qui non passa niente del gioco.
///
/// Il ponte e' un codice di sei caratteri che nasce con la partita (lo mostra
/// l'app dei tornei sulla riga del tavolo). Il codice **e'** la credenziale: no
/// login, no account, e vale solo per quella partita di quel turno.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Dove vive l'app dei tornei. Fisso: e' il tuo server, non una configurazione
/// che qualcuno deve cercare nei menu.
const String kBaseApiTornei = 'https://mtg-tournaments.axelhome.me/api/v1';

/// Oltre questo tempo il telefono considera il tavolo irraggiungibile: al tavolo
/// si aspetta poco, e un'attesa lunga bloccherebbe solo i dadi.
const Duration kTimeoutTavolo = Duration(seconds: 12);

/// Un errore da mostrare all'utente, gia' scritto in italiano.
class TavoloErrore implements Exception {
  const TavoloErrore(this.messaggio);

  final String messaggio;

  @override
  String toString() => messaggio;
}

/// Il tavolo a cui l'app e' agganciata: chi gioca, in che turno, e se si puo'
/// ancora refertare.
class TavoloCollegato {
  const TavoloCollegato({
    required this.codice,
    required this.torneo,
    required this.turno,
    required this.giocatoreA,
    this.tavolo,
    this.giocatoreB,
    this.risultato,
    this.canReport = false,
    this.whyNot,
  });

  final String codice;
  final String torneo;
  final int turno;
  final int? tavolo;
  final String giocatoreA;
  final String? giocatoreB;
  final String? risultato;
  final bool canReport;
  final String? whyNot;

  factory TavoloCollegato.daJson(Map<String, dynamic> json) {
    return TavoloCollegato(
      codice: json['code'] as String? ?? '',
      torneo: json['tournament_name'] as String? ?? 'Torneo',
      turno: (json['round_number'] as num?)?.toInt() ?? 1,
      tavolo: (json['table_number'] as num?)?.toInt(),
      giocatoreA: json['player_a'] as String? ?? '',
      giocatoreB: json['player_b'] as String?,
      risultato: json['result'] as String?,
      canReport: json['can_report'] as bool? ?? false,
      whyNot: json['why_not'] as String?,
    );
  }

  /// Come si legge a colpo d'occhio: "T2 · QA 3 vs QA 4".
  String get etichetta =>
      'T${tavolo ?? '—'} · $giocatoreA vs ${giocatoreB ?? 'riposo'}';

  /// Il risultato in italiano, se c'e'.
  String? get risultatoLeggibile => switch (risultato) {
    'player_a' => 'vince $giocatoreA',
    'player_b' => 'vince ${giocatoreB ?? 'l\'avversario'}',
    'draw' => 'pareggio',
    _ => null,
  };
}

/// Le due chiamate che servono: leggere il tavolo e scrivere il risultato.
class TavoloApi {
  const TavoloApi({this.base = kBaseApiTornei});

  final String base;

  /// Ripulisce un codice digitato: l'alfabeto dei codici non ha O/0 ne' I/1/L,
  /// quindi quel che resta sono lettere e cifre, in maiuscolo.
  static String pulisci(String codice) =>
      codice.toUpperCase().replaceAll(RegExp('[^A-Z2-9]'), '');

  Uri _uri(String percorso) => Uri.parse('$base$percorso');

  Future<TavoloCollegato> leggi(String codice) async {
    final corpo = await _chiama(
      () => http.get(_uri('/tables/${pulisci(codice)}')).timeout(kTimeoutTavolo),
    );
    return TavoloCollegato.daJson(corpo);
  }

  Future<TavoloCollegato> referta(
    String codice, {
    required String risultato,
    required int gamesVintiA,
    required int gamesVintiB,
  }) async {
    final corpo = await _chiama(
      () => http
          .patch(
            _uri('/tables/${pulisci(codice)}/result'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'result': risultato,
              'games_won_a': gamesVintiA,
              'games_won_b': gamesVintiB,
            }),
          )
          .timeout(kTimeoutTavolo),
    );
    return TavoloCollegato.daJson(corpo);
  }

  /// Una chiamata sola con un modo solo di fallire: o torna il corpo JSON, o
  /// arriva un [TavoloErrore] con la frase da mostrare.
  Future<Map<String, dynamic>> _chiama(
    Future<http.Response> Function() invio,
  ) async {
    final http.Response risposta;
    try {
      risposta = await invio();
    } on TimeoutException {
      throw const TavoloErrore(
        'Il torneo non risponde: controlla la connessione e riprova.',
      );
    } catch (_) {
      throw const TavoloErrore(
        'Non riesco a raggiungere il torneo: controlla la connessione.',
      );
    }

    Map<String, dynamic>? corpo;
    try {
      corpo = jsonDecode(risposta.body) as Map<String, dynamic>;
    } catch (_) {
      corpo = null;
    }

    if (risposta.statusCode >= 200 && risposta.statusCode < 300 && corpo != null) {
      return corpo;
    }

    // Il server risponde `{"detail": {"code": ..., "message": ...}}` per gli
    // errori suoi: si mostra la sua frase, che e' gia' quella giusta.
    final dettaglio = corpo?['detail'];
    final messaggio = dettaglio is Map<String, dynamic>
        ? dettaglio['message'] as String?
        : null;
    throw TavoloErrore(
      messaggio ?? 'Il torneo ha risposto ${risposta.statusCode}.',
    );
  }
}
