import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Fixed step is consistent at 30 and 120 FPS', () {
    final a = Simulation(buildLevels()[0]), b = Simulation(buildLevels()[0]);
    for (int i = 0; i < 60; i++) {
      a.advance(1 / 30);
    }
    for (int i = 0; i < 240; i++) {
      b.advance(1 / 120);
    }
    expect(a.position.distanceTo(b.position), lessThan(.00001));
  });
  test('Gravity, landing and rolling on a ramp', () {
    final l = Level(1, 'test', '', [
      Track(Vector3(-1, .3, 0), Vector3(1, -.3, 0), .7),
    ]);
    final s = Simulation(l);
    s.position = Vector3(-.5, .6, 0);
    for (int i = 0; i < 240; i++) {
      s.step();
    }
    expect(s.falls, 0);
    expect(s.position.x, greaterThan(-.5));
    expect(s.position.y, greaterThan(-.4));
  });
  test('Recovery restores exact snapshot', () {
    final s = Simulation(buildLevels()[3]);
    s.save();
    final pos = s.position.clone();
    s.position = Vector3(9, 9, 9);
    s.recover();
    expect(s.position.distanceTo(pos), 0);
    expect(s.velocity.length, 0);
  });
  test('An edge allows a fall and landing on a lower platform', () {
    final l = Level(1, 'drop', '', [
      Track(Vector3(-1, .4, 0), Vector3(0, .4, 0), .6, rails: false),
      Track(Vector3(-1, -.4, 0), Vector3(1.8, -.4, 0), .9),
    ]);
    final sim = Simulation(l);
    sim.position = Vector3(-.2, .485, 0);
    sim.velocity = Vector3(.7, 0, 0);
    for (int i = 0; i < 480; i++) {
      sim.step();
    }
    expect(sim.falls, 0);
    expect(sim.position.y, closeTo(-.315, .03));
    expect(sim.trackIndex, 1);
  });
  test('15 unique paths and real outlets', () {
    final levels = buildLevels();
    expect(levels.length, 15);
    for (final l in levels) {
      expect(l.tracks.length, greaterThan(15));
      expect(l.start.distanceTo(l.exit), greaterThan(1));
    }
  });
  test('Track silhouettes and topology differ across all fifteen levels', () {
    final levels = buildLevels();
    final signatures = levels
        .map(
          (l) => l.tracks
              .map(
                (t) =>
                    '${t.a.x.toStringAsFixed(2)},${t.a.y.toStringAsFixed(2)},${t.a.z.toStringAsFixed(2)}',
              )
              .join(';'),
        )
        .toSet();
    expect(signatures.length, 15);
    for (final l in levels) {
      for (int i = 1; i < l.tracks.length; i++) {
        final prev = l.tracks[i - 1], next = l.tracks[i];
        expect(prev.b.distanceTo(next.a), lessThan(1e-9));
        expect(prev.leftB.distanceTo(next.leftA), lessThan(1e-9));
        expect(prev.rightB.distanceTo(next.rightA), lessThan(1e-9));
        expect(prev.tangent.dot(next.tangent), greaterThan(.75));
      }
      for (final t in l.tracks) {
        for (final triangle in t.triangles) {
          expect(triangle.normal.y, greaterThan(0));
        }
      }
    }
    expect(levels[3].tracks.every((t) => !t.rails), true);
    expect(
      levels[6].tracks.map((t) => t.material).toSet(),
      containsAll(['ice', 'rubber']),
    );
    for (final l in levels) {
      for (final t in l.tracks) {
        expect(t.a.length, lessThan(2.3));
        expect(t.a.distanceTo(t.b), greaterThan(.001));
      }
    }
  });
  test(
    'Dragging accumulates rotation and produces equal response across FPS',
    () {
      final l = Level(1, 'controls', '', [
        Track(Vector3(-1, 0, 0), Vector3(1, 0, 0), .6),
      ]);
      final a = Simulation(l), b = Simulation(l);
      for (int i = 0; i < 30; i++) {
        a.rotateBy(Vector3(.01, 0, .015));
        a.advance(1 / 30);
      }
      for (int i = 0; i < 120; i++) {
        b.rotateBy(Vector3(.0025, 0, .00375));
        b.advance(1 / 120);
      }
      for (int i = 0; i < 60; i++) {
        a.advance(1 / 60);
        b.advance(1 / 60);
      }
      final av = a.orientation.rotated(Vector3(0, 1, 0)),
          bv = b.orientation.rotated(Vector3(0, 1, 0));
      expect(av.distanceTo(Vector3(0, 1, 0)), greaterThan(.3));
      expect(av.distanceTo(bv), lessThan(.03));
      expect(a.angular.length, lessThan(.01));
    },
  );
  test(
    'Marble crosses ribbon seams on a descending curve without recovery',
    () {
      final l = buildLevels().first;
      final sim = Simulation(l);
      for (int i = 0; i < 240 * 35 && !sim.won; i++) {
        sim.step();
      }
      expect(sim.falls, 0);
      expect(sim.trackIndex, greaterThan(16));
    },
  );
  test('Winning persists time and unlock across reload', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress(await SharedPreferences.getInstance());
    await p.win(1, 12.5);
    final q = Progress(await SharedPreferences.getInstance());
    expect(q.unlocked, 2);
    expect(q.best(1), 12.5);
    await q.win(1, 20);
    expect(q.best(1), 12.5);
  });
}
