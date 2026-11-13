import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/campaign.dart';
import 'package:gravisfera/game/maze.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:gravisfera/game/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart';

void place(Simulation s, int cell) {
  s.orientation = Quaternion.identity();
  s.position =
      s.activeLevel.maze!.center(cell) + Vector3(0, Simulation.radius, 0);
  s.velocity.setZero();
  s.angular.setZero();
  s.spinInput.setZero();
}

void main() {
  test('Sixteen levels accessible without fabricating victories', () async {
    SharedPreferences.setMockInitialValues({'unlocked': 1});
    final p = Progress(await SharedPreferences.getInstance());
    for (int i = 1; i <= 16; i++) {
      expect(p.canPlay(i), true);
      expect(p.best(i), null);
    }
    expect(p.unlocked, 1);
    expect(p.sensitivity, 7.0);
  });
  test(
    'Every authored board has distinct topology and an individual objective',
    () {
      final c = buildCampaign();
      expect(c.length, 16);
      expect(
        c
            .take(15)
            .map((l) => l.maze!.walls.map((w) => '${w.min}').join())
            .toSet()
            .length,
        15,
      );
      expect(c.take(15).every((l) => l.maze!.authored), true);
    },
  );
  test('Contact surface velocity matches rendered quaternion rotation', () {
    final s = Simulation(buildCampaign()[1]);
    s.orientation = Quaternion.axisAngle(Vector3(.3, .6, .2).normalized(), .4);
    s.angular = Vector3(.4, .2, .3);
    final p = Vector3(.8, .4, -.6), before = s.orientation.rotated(p);
    const h = 1e-6;
    final q =
        Quaternion.axisAngle(s.angular.normalized(), s.angular.length * h) *
        s.orientation;
    expect(
      s.surfaceVelocity(p).distanceTo((q.rotated(p) - before) / h),
      lessThan(1e-5),
    );
  });
  test(
    'Pressure plate changes the real lock state and checkpoint retains it',
    () {
      final s = Simulation(buildCampaign().first), m = s.activeLevel.maze!;
      place(s, m.plate);
      for (int i = 0; i < 300; i++) {
        s.step();
      }
      expect(s.pressureActive, true);
      final door = m.doors.firstWhere((d) => d.kind == 'D');
      expect(s.doorOpen(door), true);
      s.recover();
      expect(s.pressureActive, true);
      expect(s.portalReady, false);
    },
  );
  test('Sequence enforces its authored order and keeps its checkpoint', () {
    final s = Simulation(buildCampaign()[2]), m = s.activeLevel.maze!;
    for (final pad in m.sequenceOrder) {
      final cell = m.sequencePads.entries
          .singleWhere((e) => e.value == pad)
          .key;
      place(s, cell);
      for (int i = 0; i < 120; i++) {
        s.step();
      }
    }
    expect(s.sequenceProgress, 3);
    s.recover();
    expect(s.sequenceProgress, 3);
  });
  test(
    'Orbital lock requires inversion and a stable return, not a free pickup',
    () {
      final s = Simulation(buildCampaign()[5]), m = s.activeLevel.maze!;
      place(s, m.orbital);
      s.step();
      expect(s.gyroLocked, true);
      s.spinInput = Vector3(0, 0, 2.2);
      for (int i = 0; i < 1500 && !s.orbitalUnlocked; i++) {
        if (s.orbitalHalfTurn &&
            s.orientation.rotated(Vector3(0, 1, 0)).dot(s.gyroStartUp) > .99) {
          s.spinInput.setZero();
        }
        s.step();
      }
      expect(s.orbitalUnlocked, true);
      expect(s.gyroLocked, false);
      expect(s.falls, 0);
    },
  );
  test('Larger maze is connected and has reachable objectives', () {
    final m = buildCampaign().last.maze!;
    expect(m.graph.length, 441);
    expect(m.distanceMap(m.start).length, 441);
    expect(m.solution.length, greaterThan(60));
    expect(m.keys.toSet().length, 2);
    expect(m.keys.contains(m.plate), false);
    expect(m.graph.fold(0, (s, n) => s + n.length) ~/ 2, greaterThan(440));
    expect(m.gates.length, 4);
    expect(
      MazeData.cell - MazeData.thickness,
      greaterThan(Simulation.radius * 2),
    );
  });
  test(
    'Blue ice retains momentum; orange belts move the marble without input',
    () {
      final levels = buildCampaign(),
          ice = Simulation(levels[6]),
          normal = Simulation(levels[6]),
          belt = Simulation(levels[3]);
      place(ice, ice.activeLevel.maze!.ice.first);
      place(normal, normal.activeLevel.maze!.start);
      place(belt, belt.activeLevel.maze!.belts.first);
      ice.velocity = Vector3(.3, 0, 0);
      normal.velocity = Vector3(.3, 0, 0);
      for (int i = 0; i < 480; i++) {
        ice.step();
        normal.step();
        belt.step();
      }
      expect(ice.velocity.length, greaterThan(normal.velocity.length * 1.5));
      expect(belt.velocity.x, greaterThan(.2));
    },
  );
}
