// Test di base del contatore di vite.
//
// Il layout e' ruotato di 90 gradi (RotatedBox), quindi i tocchi vengono
// verificati sui segni visibili e non su coordinate assolute.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtg_lifecounter/main.dart';

/// Vero se il segno a riposo e' visibile: quando c'e' una serie di tocchi in
/// corso il segno viene nascosto e al suo posto compare il saldo.
bool signIsVisible(WidgetTester tester, String sign) {
  final visibility = tester.widget<Visibility>(
    find.ancestor(of: find.text(sign), matching: find.byType(Visibility)).first,
  );
  return visibility.visible;
}

void main() {
  testWidgets('all\'avvio i due giocatori sono a 20 vite', (tester) async {
    await tester.pumpWidget(LifeCounterApp());
    await tester.pumpAndSettle();

    // Ogni giocatore ha una zona con "-", numero e "+".
    expect(find.text('20'), findsNWidgets(2));
    expect(find.text('-'), findsNWidgets(2));
    expect(find.text('+'), findsNWidgets(2));
  });

  testWidgets('il tocco sul + aumenta la vita', (tester) async {
    await tester.pumpWidget(LifeCounterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();

    expect(find.text('21'), findsOneWidget);
    expect(find.text('19'), findsNothing);
  });

  testWidgets('i segni - e + restano fermi al variare della vita', (
    tester,
  ) async {
    Future<void> pumpLife(int life) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: LifeCounterPanelTouch(
                life: life,
                onIncrease: () {},
                onDecrease: () {},
              ),
            ),
          ),
        ),
      );
    }

    Offset? removeRef;
    Offset? addRef;

    // Casi con una, due, tre e quattro cifre, piu' i valori negativi.
    for (final life in <int>[5, 20, 35, 100, 999, -3, -100]) {
      await pumpLife(life);

      final remove = tester.getCenter(find.text('-'));
      final add = tester.getCenter(find.text('+'));
      removeRef ??= remove;
      addRef ??= add;

      expect(
        remove.dx,
        closeTo(removeRef.dx, 0.01),
        reason: 'il "-" si e\' spostato con vita=$life',
      );
      expect(
        add.dx,
        closeTo(addRef.dx, 0.01),
        reason: 'il "+" si e\' spostato con vita=$life',
      );
    }
  });

  testWidgets('il lato toccato si scurisce per un attimo', (tester) async {
    var increases = 0;
    var decreases = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LifeCounterPanelTouch(
            life: 20,
            onIncrease: () => increases++,
            onDecrease: () => decreases++,
          ),
        ),
      ),
    );

    // Il pannello ha un solo velo per lato: il primo e' quello di sinistra.
    List<double> shades() => tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .map((shade) => shade.opacity)
        .toList();

    expect(shades(), <double>[0, 0], reason: 'a riposo nessun velo');

    // Meta' sinistra: toglie una vita e si scurisce.
    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    expect(decreases, 1);
    expect(shades(), <double>[1, 0]);

    // Il velo si spegne da solo poco dopo.
    await tester.pump(const Duration(milliseconds: 250));
    expect(shades(), <double>[0, 0]);

    // Meta' destra: aggiunge una vita e si scurisce.
    await tester.tapAt(const Offset(700, 300));
    await tester.pump();
    expect(increases, 1);
    expect(shades(), <double>[0, 1]);

    await tester.pump(const Duration(milliseconds: 250));
    expect(shades(), <double>[0, 0]);

    await tester.pumpAndSettle();
  });

  testWidgets('i tocchi ravvicinati formano una serie di vite', (tester) async {
    var increases = 0;
    var decreases = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LifeCounterPanelTouch(
            life: 20,
            onIncrease: () => increases++,
            onDecrease: () => decreases++,
          ),
        ),
      ),
    );

    // Nessuna serie in corso: non c'e' nessun saldo da mostrare.
    expect(find.text('-1'), findsNothing);
    expect(find.text('+1'), findsNothing);

    // Nel test i font dell'app non sono caricati: ogni glifo e' un quadrato
    // largo quanto il fontSize, quindi per misurare la posizione "vera" dei
    // segni si usano le loro scatole, non il rettangolo del testo.
    final leftBoxBefore = tester.getCenter(find.byType(FixedWidthSign).first);
    final rightBoxBefore = tester.getCenter(find.byType(FixedWidthSign).last);
    final lifeBoxBefore = tester.getCenter(find.byType(FixedWidthNumber));

    // Il segno a riposo e' visibile finche' non c'e' una serie.
    expect(signIsVisible(tester, '-'), isTrue);

    // Tre tocchi ravvicinati sullo stesso lato: la serie vale -3 e prende il
    // posto del segno "-".
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(decreases, 3);
    expect(find.text('-3'), findsOneWidget);

    // Il saldo sta al posto del segno: stessa posizione, segno nascosto.
    final combo = tester.getCenter(find.text('-3'));
    expect(combo.dx, closeTo(leftBoxBefore.dx, 1));
    expect(combo.dy, closeTo(leftBoxBefore.dy, 1));
    expect(signIsVisible(tester, '-'), isFalse);

    // L'altro segno resta quello a riposo, e nulla si e' spostato.
    expect(signIsVisible(tester, '+'), isTrue);
    expect(tester.getCenter(find.byType(FixedWidthSign).first), leftBoxBefore);
    expect(tester.getCenter(find.byType(FixedWidthSign).last), rightBoxBefore);
    expect(tester.getCenter(find.byType(FixedWidthNumber)), lifeBoxBefore);

    // Un tocco dal lato opposto continua la serie invece di azzerarla.
    await tester.tapAt(const Offset(700, 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(increases, 1);
    expect(find.text('-2'), findsOneWidget);
    expect(find.text('+1'), findsNothing);

    // Il saldo resta dal lato verso cui va la serie: e' ancora negativo,
    // quindi sta ancora al posto del "-" e il "+" e' tornato a riposo.
    expect(signIsVisible(tester, '-'), isFalse);
    expect(signIsVisible(tester, '+'), isTrue);
    expect(tester.getCenter(find.text('-2')).dx, closeTo(leftBoxBefore.dx, 1));

    // Passato l'intervallo la serie finisce e il saldo sparisce.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('-2'), findsNothing);
    expect(signIsVisible(tester, '-'), isTrue);

    // Il tocco successivo riparte da una serie nuova: saldo positivo, quindi
    // al posto del "+".
    await tester.tapAt(const Offset(700, 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(increases, 2);
    expect(find.text('+1'), findsOneWidget);
    expect(signIsVisible(tester, '+'), isFalse);
    expect(signIsVisible(tester, '-'), isTrue);
    expect(tester.getCenter(find.text('+1')).dx, closeTo(rightBoxBefore.dx, 1));

    // Fine della serie, cosi' il test non lascia timer in sospeso.
    await tester.pump(const Duration(milliseconds: 700));
  });
}
