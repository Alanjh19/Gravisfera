import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/main.dart';
import 'package:gravisfera/game/scene.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:gravisfera/game/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Menu animates its scene without rebuilding the whole Scaffold', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'music': false,
      'effects': false,
      'haptics': false,
    });
    await tester.pumpWidget(
      Gravisfera(progress: Progress(await SharedPreferences.getInstance())),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      identical(scaffold, tester.widget<Scaffold>(find.byType(Scaffold))),
      true,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('All sixteen levels are available and the extra maze starts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'music': false,
      'effects': false,
      'haptics': false,
      'unlocked': 1,
    });
    await tester.pumpWidget(
      Gravisfera(progress: Progress(await SharedPreferences.getInstance())),
    );
    await tester.tap(find.text('Seleccionar nivel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles.length, 16);
    expect(tiles.every((t) => t.enabled), true);
    final last = find.text('16 · El dédalo ciego');
    await tester.ensureVisible(last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(last);
    await tester.pump();
    expect(find.text('LABERINTO 21 × 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(320, 640), const Size(1280, 800)]) {
    testWidgets('Menu, perspective scene, level intro and pause at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'haptics': false,
        'effects': false,
      });
      await tester.pumpWidget(
        Gravisfera(progress: Progress(await SharedPreferences.getInstance())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('GRAVISFERA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Jugar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('La primera vuelta'), findsOneWidget);
      final paintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ToyPainter,
      );
      final painter =
          (tester.widget<CustomPaint>(paintFinder).painter! as ToyPainter);
      final before = painter.sim.orientation.rotated(Vector3(0, 1, 0));
      await tester.drag(paintFinder, const Offset(70, 0));
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final after = painter.sim.orientation.rotated(Vector3(0, 1, 0));
      expect(before.distanceTo(after), greaterThan(.08));
      await tester.tap(find.byTooltip('Enfocar y seguir canica'));
      await tester.pump();
      var focused =
          tester.widget<CustomPaint>(paintFinder).painter! as ToyPainter;
      expect(focused.followMarble, true);
      expect(focused.zoom, greaterThan(2));
      await tester.pump(const Duration(milliseconds: 100));
      focused = tester.widget<CustomPaint>(paintFinder).painter! as ToyPainter;
      expect(
        focused.cameraTarget!.distanceTo(focused.sim.position),
        lessThan(.2),
      );
      await tester.tap(find.byTooltip('Ver esfera completa'));
      await tester.pump();
      expect(
        (tester.widget<CustomPaint>(paintFinder).painter! as ToyPainter)
            .followMarble,
        false,
      );
      await tester.tap(find.byTooltip('Pausa'));
      await tester.pump();
      expect(find.text('Un respiro'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
