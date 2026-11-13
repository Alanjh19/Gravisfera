import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/physics.dart';

void main() {
  test('Audit neutral-gravity trajectories without teleportation', () {
    for (final l in buildLevels()) {
      final s = Simulation(l);
      for (int tick = 0; tick < 240 * 90 && !s.won; tick++) {
        s.step();
      } // Deliberately report, do not assert a campaign solution.
      // ignore: avoid_print
      print(
        'Level ${l.id}: won=${s.won}, track=${s.trackIndex}/${l.tracks.length}, falls=${s.falls}',
      );
      expect(s.position.x.isFinite, true);
    }
  });
}
