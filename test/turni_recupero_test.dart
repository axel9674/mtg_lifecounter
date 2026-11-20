// I tasti dei turni di recupero: stanno nella zona di ogni giocatore, chi ha il
// turno tocca il suo, e dopo il quinto turno resta il pareggio da refertare.
//
// Il test guarda il tasto, non il timer: che il tempo che scade lo faccia
// comparire e' una riga in `_proponiTurniRecupero`, e provarla da qui vorrebbe
// dire far scorrere un minuto vero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_lifecounter/main.dart';

Widget _cornice(Widget figlio) {
  return MaterialApp(home: Scaffold(body: Center(child: figlio)));
}

void main() {
  testWidgets('senza turno dichiarato ognuno vede il suo tasto', (tester) async {
    var dichiarato = false;
    await tester.pumpWidget(
      _cornice(
        RecuperoAzione(
          lato: 'b',
          nome: 'Bruno',
          avversario: 'Anna',
          attivo: null,
          turno: -1,
          onSonoDiTurno: () => dichiarato = true,
          onFineTurno: () {},
          onPareggio: () {},
          onNascondi: () {},
        ),
      ),
    );

    expect(find.text('Tempo scaduto'), findsOneWidget);
    expect(find.text('Sono di turno'), findsOneWidget);

    await tester.tap(find.text('Sono di turno'));
    await tester.pump();
    expect(dichiarato, isTrue);
  });

  testWidgets('chi non ha il turno non ha tasti, e legge chi gioca', (
    tester,
  ) async {
    await tester.pumpWidget(
      _cornice(
        RecuperoAzione(
          lato: 'b',
          nome: 'Bruno',
          avversario: 'Anna',
          attivo: 'a',
          turno: 2,
          onSonoDiTurno: () {},
          onFineTurno: () {},
          onPareggio: () {},
          onNascondi: () {},
        ),
      ),
    );

    expect(find.text('Sono di turno'), findsNothing);
    expect(find.text('Fine turno'), findsNothing);
    expect(find.text('Turno 2 di 5'), findsOneWidget);
    expect(find.text('Gioca Anna'), findsOneWidget);
  });

  testWidgets('chi ha il turno passa la mano, e alla fine referta il pareggio', (
    tester,
  ) async {
    var fini = 0;
    var pareggio = false;

    Widget tasto({required int turno}) => RecuperoAzione(
      lato: 'a',
      nome: 'Anna',
      avversario: 'Bruno',
      attivo: 'a',
      turno: turno,
      onSonoDiTurno: () {},
      onFineTurno: () => fini++,
      onPareggio: () => pareggio = true,
      onNascondi: () {},
    );

    await tester.pumpWidget(_cornice(tasto(turno: 1)));
    await tester.tap(find.text('Fine turno'));
    await tester.pump();
    expect(fini, 1);

    await tester.pumpWidget(_cornice(tasto(turno: kTurniRecupero)));
    expect(find.text('Turni di recupero finiti'), findsOneWidget);
    await tester.tap(find.text('Referta pareggio'));
    await tester.pump();
    expect(pareggio, isTrue);
  });
}
