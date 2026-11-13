import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Marble passes short curve joints without a centre-line rail clamp', () {
    final levels = buildLevels();
    for (final id in [2, 7, 8]) {
      final l = levels[id - 1];
      for (int index = 4; index < l.tracks.length - 8; index += 4) {
        if (l.tracks
            .sublist(index - 2, index + 3)
            .any((t) => t.mechanism == 'gate' || t.mechanism == 'gear')) {
          continue;
        }
        final t = l.tracks[index], s = Simulation(l);
        final gravity = (t.tangent * .20 - t.normal).normalized();
        s.orientation = Quaternion.fromTwoVectors(Vector3(0, -1, 0), gravity);
        final start = t.center + t.normal * Simulation.radius;
        s.position = s.orientation.rotated(start);
        s.velocity = s.orientation.rotated(t.tangent * .3);
        s.save();
        for (int step = 0; step < 60; step++) {
          s.step();
        }
        final local = s.orientation.conjugated().rotated(s.position);
        expect(s.falls, 0, reason: 'Level $id joint $index');

        expect(
          (local - start).dot(t.tangent),
          greaterThan(.015),
          reason: 'Level $id joint $index',
        );
      }
    }
  });
}
