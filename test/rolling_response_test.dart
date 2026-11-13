import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/levels.dart';
import 'package:gravisfera/game/maze.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:vector_math/vector_math_64.dart';

Simulation board({double tilt = 0}) {
  final maze = MazeData.authoredMap('S...................G');
  final level = Level(
    1,
    'Physics bench',
    '',
    [Track(Vector3(-3, 0, 0), Vector3(3, 0, 0), 6, rails: false)],
    maze: maze,
    radius: 5,
    startOverride: Vector3(0, Simulation.radius, 0),
    exitOverride: Vector3(2.7, 0, 0),
  );
  final s = Simulation(level);
  s.orientation = Quaternion.axisAngle(Vector3(0, 0, 1), tilt);
  s.position = s.orientation.rotated(Vector3(0, Simulation.radius, 0));
  return s;
}

void main() {
  test('Slope follows solid-sphere rolling acceleration, not a speed ramp', () {
    const angle = .3, duration = .2;
    final s = board(tilt: angle);
    for (int i = 0; i < 48; i++) {
      s.step();
    }
    final local = s.orientation.conjugated().rotated(s.velocity);
    final expected =
        (5 / 7 * Simulation.gravity * math.sin(angle) -
            .025 * Simulation.gravity * math.cos(angle)) *
        duration;
    expect(local.x.abs(), closeTo(expected, .004));
    expect(s.falls, 0);
  });
  test('Uphill momentum decelerates and reverses naturally', () {
    final s = board(tilt: .4);
    final probe = board(tilt: .4)..step();
    final downhill = probe.velocity.normalized();
    s.velocity = downhill * -.15;
    for (int i = 0; i < 72; i++) {
      s.step();
    }
    expect(s.velocity.dot(downhill), greaterThan(.05));
  });
  test('A fast marble coasts instead of being truncated to 1.2', () {
    final s = board()..velocity = Vector3(2, 0, 0);
    for (int i = 0; i < 48; i++) {
      s.step();
    }
    expect(s.velocity.x, closeTo(2 - .025 * Simulation.gravity * .2, .001));
  });
  test('10 and 120 FPS advance the same elapsed physics time', () {
    final slow = board(tilt: .25), fast = board(tilt: .25);
    for (int i = 0; i < 10; i++) {
      slow.advance(.1);
    }
    for (int i = 0; i < 120; i++) {
      fast.advance(1 / 120);
    }
    expect(slow.time, closeTo(1, Simulation.dt));
    expect(slow.position.distanceTo(fast.position), lessThan(1e-7));
    expect(slow.velocity.distanceTo(fast.velocity), lessThan(1e-7));
  });
  test('Free fall uses unchanged gravity and impact does not snap early', () {
    final s = Simulation(
      Level(1, 'Fall', '', [Track(Vector3(-3, 0, 0), Vector3(3, 0, 0), 6)]),
    );
    s.position = Vector3(0, 1, 0);
    s.velocity.setZero();
    for (int i = 0; i < 24; i++) {
      s.step();
    }
    expect(s.velocity.y, closeTo(-Simulation.gravity * .1, 1e-7));
    expect(s.position.y, closeTo(1 - .5 * Simulation.gravity * .1 * .1, .001));
  });
}
