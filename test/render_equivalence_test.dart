import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/campaign.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:gravisfera/game/scene.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Full-detail scene pixels remain equivalent to the reference', () async {
    final levels = [...buildLevels(), buildCampaign().last];
    for (final id in [5, 10, 15, 16]) {
      final sim = Simulation(levels[id - 1]);
      sim.time = .8;
      sim.charge = .2;
      sim.orientation = Quaternion.axisAngle(
        Vector3(.3, .7, .2).normalized(),
        id * .05,
      );
      final recorder = ui.PictureRecorder();
      ToyPainter(
        sim,
        animationTime: .8,
      ).paint(ui.Canvas(recorder), const ui.Size(600, 480));
      final picture = recorder.endRecording();
      final image = await picture.toImage(600, 480);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final f = File('test/reference/reference-scene-$id.rgba');
      if (const bool.fromEnvironment('WRITE_REFERENCE')) {
        f.writeAsBytesSync(bytes);
      } else {
        final before = f.readAsBytesSync();
        expect(bytes.length, before.length);
        int changed = 0;
        for (int i = 0; i < bytes.length; i++) {
          if ((bytes[i] - before[i]).abs() > 1) changed++;
        }
        expect(
          changed / bytes.length,
          lessThan(.0001),
          reason: 'Level $id changed pixels',
        );
      }
      image.dispose();
      picture.dispose();
    }
  });
}
