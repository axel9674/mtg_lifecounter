// Il conteggio dei turni di recupero: si dichiara chi ha il turno, si avanza a
// ogni fine turno, e dopo il quinto si arriva al pareggio.
//
// Il test guarda il pannello, non il timer: che il tempo che scade apra questo
// pannello e' una riga in `_tickTimer`, e provarla da qui vorrebbe dire far
// scorrere un minuto vero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_lifecounter/main.dart';

Widget _cornice(Widget figlio) {
  return MaterialApp(home: Scaffold(body: Builder(builder: (_) => figlio)));
}

void main() {
  testWidgets('chi ha il turno lo dichiara e si parte dal turno 0', (
    tester,
  ) async {
    String? attivo;
    var turno = -1;
    await tester.pumpWidget(
      _cornice(
        TurniRecuperoDialog(
          nomeA: 'Anna',
          nomeB: 'Bruno',
          attivo: null,
          turno: -1,
          onScegliAttivo: (lato) => attivo = lato,
          onFineTurno: () => turno++,
          onPareggio: () {},
        ),
      ),
    );

    expect(find.text('Tempo scaduto'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);

    await tester.tap(find.text('Bruno'));
    await tester.pump();

    expect(attivo, 'b');
    expect(find.text('Turno 0'), findsOneWidget);
    expect(find.textContaining('Ha il turno Bruno'), findsOneWidget);
  });

  testWidgets('ogni fine turno avanza, e al sesto passo si referta il pareggio', (
    tester,
  ) async {
    var fini = 0;
    var pareggio = false;
    await tester.pumpWidget(
      _cornice(
        TurniRecuperoDialog(
          nomeA: 'Anna',
          nomeB: 'Bruno',
          attivo: 'a',
          turno: 0,
          onScegliAttivo: (_) {},
          onFineTurno: () => fini++,
          onPareggio: () => pareggio = true,
        ),
      ),
    );

    for (var i = 0; i < kTurniRecupero; i++) {
      expect(find.text('Fine turno'), findsOneWidget);
      await tester.tap(find.text('Fine turno'));
      await tester.pump();
    }

    expect(fini, kTurniRecupero);
    expect(find.text('Turni di recupero finiti'), findsOneWidget);
    expect(find.text('Referta pareggio'), findsOneWidget);

    await tester.tap(find.text('Referta pareggio'));
    await tester.pump();
    expect(pareggio, isTrue);
  });
}
