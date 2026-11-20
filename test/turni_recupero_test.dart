// La pillola dei turni di recupero: sta nella zona di ogni giocatore, e' della
// stessa famiglia di quella del veleno, e cambia faccia secondo il momento.
//
// Il test guarda la pillola, non il timer: che il tempo che scade la faccia
// comparire e' una riga in `_proponiTurniRecupero`, e provarla da qui vorrebbe
// dire far scorrere un minuto vero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_lifecounter/main.dart';

Widget _cornice(Widget figlio) =>
    MaterialApp(home: Scaffold(body: Center(child: figlio)));

RecuperoTurnoPill _pillola({
  String lato = 'a',
  String? attivo,
  int turno = -1,
  VoidCallback? onSonoDiTurno,
  VoidCallback? onFineTurno,
  VoidCallback? onPareggio,
  VoidCallback? onNascondi,
}) => RecuperoTurnoPill(
  lato: lato,
  nome: 'Anna',
  avversario: 'Bruno',
  attivo: attivo,
  turno: turno,
  onSonoDiTurno: onSonoDiTurno ?? () {},
  onFineTurno: onFineTurno ?? () {},
  onPareggio: onPareggio ?? () {},
  onNascondi: onNascondi ?? () {},
);

void main() {
  testWidgets('prima del turno le due pillole invitano, e ognuna dichiara', (
    tester,
  ) async {
    var dichiarato = false;
    await tester.pumpWidget(
      _cornice(_pillola(onSonoDiTurno: () => dichiarato = true)),
    );

    expect(find.text('TURNO'), findsOneWidget);
    await tester.tap(find.text('TURNO'));
    await tester.pump();
    expect(dichiarato, isTrue);
  });

  testWidgets('chi ha il turno conta, chi aspetta legge solo il numero', (
    tester,
  ) async {
    var fini = 0;
    await tester.pumpWidget(
      _cornice(_pillola(attivo: 'a', turno: 2, onFineTurno: () => fini++)),
    );
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byType(RecuperoTurnoPill));
    await tester.pump();
    expect(fini, 1);

    // Lo stesso turno, ma visto dall'altro lato: la pillola non risponde.
    var finiAvversario = 0;
    await tester.pumpWidget(
      _cornice(
        _pillola(
          lato: 'b',
          attivo: 'a',
          turno: 2,
          onFineTurno: () => finiAvversario++,
        ),
      ),
    );
    await tester.tap(find.byType(RecuperoTurnoPill));
    await tester.pump();
    expect(finiAvversario, 0);
  });

  testWidgets('con i turni finiti la pillola referta il pareggio', (
    tester,
  ) async {
    var pareggio = false;
    await tester.pumpWidget(
      _cornice(
        _pillola(
          attivo: 'a',
          turno: kTurniRecupero,
          onPareggio: () => pareggio = true,
        ),
      ),
    );

    await tester.tap(find.byType(RecuperoTurnoPill));
    await tester.pump();
    expect(pareggio, isTrue);
  });

  testWidgets('tenerla premuta la toglie: la partita era gia decisa', (
    tester,
  ) async {
    var nascosta = false;
    await tester.pumpWidget(
      _cornice(_pillola(onNascondi: () => nascosta = true)),
    );

    await tester.longPress(find.byType(RecuperoTurnoPill));
    await tester.pump();
    expect(nascosta, isTrue);
  });
}
