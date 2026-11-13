import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Spatial lookup includes every reachable support without scanning the whole level', () {
    for (final l in buildLevels()) {
      int visited = 0;
      for (final t in l.tracks) {
        final p = t.center + t.normal * Simulation.radius;
        final candidates = l.collisionCandidates(p);
        expect(candidates, contains(t.index));
        visited += candidates.length;
      }
      expect(visited / l.tracks.length, lessThan(l.tracks.length * .5));
    }
  });
  test(
    'Spatial broad phase preserves full-scan physics across fifteen levels',
    () {
      for (final l in buildLevels()) {
        final fast = Simulation(l),
            reference = Simulation(l, useSpatialIndex: false);
        for (int tick = 0; tick < 240 * 6; tick++) {
          final input = Vector3(
            math.sin(tick * .005) * .2,
            0,
            math.cos(tick * .004) * .15,
          );
          fast.spinInput = input;
          reference.spinInput = input.clone();
          fast.step();
          reference.step();
          if (tick % 24 == 0) {
            expect(
              fast.position.distanceTo(reference.position),
              lessThan(1e-10),
              reason: 'Level ${l.id}, step $tick',
            );
            expect(fast.trackIndex, reference.trackIndex);
            expect(fast.falls, reference.falls);
          }
        }
      }
    },
  );
}
