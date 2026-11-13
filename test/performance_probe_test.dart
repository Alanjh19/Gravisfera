import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:gravisfera/game/scene.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Record physics and full-detail scene preparation cost', () async {
    final output = <String, Object>{};
    for (final id in [5, 10, 15]) {
      final sim = Simulation(buildLevels()[id - 1]);
      final watch = Stopwatch()..start();
      for (int i = 0; i < 240 * 12; i++) {
        sim.step();
      }
      watch.stop();
      final timings = <int>[];
      for (int frame = 0; frame < 65; frame++) {
        sim.orientation = Quaternion.axisAngle(
          Vector3(.5, .7, .2).normalized(),
          frame * .005,
        );
        final recorder = ui.PictureRecorder();
        // Record a real display list with unchanged full-detail materials/effects.
        final actualCanvas = ui.Canvas(recorder);
        final w = Stopwatch()..start();
        ToyPainter(
          sim,
          animationTime: frame / 60,
        ).paint(actualCanvas, const ui.Size(1000, 800));
        w.stop();
        final picture = recorder.endRecording();
        picture.dispose();
        if (frame >= 5) timings.add(w.elapsedMicroseconds);
      }
      timings.sort();
      output['level$id'] = {
        'physics12s_us': watch.elapsedMicroseconds,
        'paint_median_us': timings[timings.length ~/ 2],
        'paint_p95_us': timings[(timings.length * .95).floor()],
      };
    }
    final path = const String.fromEnvironment(
      'PERF_FILE',
      defaultValue: '.cache/perf-latest.json',
    );
    File(path).parent.createSync(recursive: true);
    File(path)
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
    // ignore: avoid_print
    print(output);
  });
}
