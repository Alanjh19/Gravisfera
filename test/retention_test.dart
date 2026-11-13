import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/campaign.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Invisible cover blocks vertical ejection without a rendered mesh', () {
    final s = Simulation(buildCampaign().first), m = s.activeLevel.maze!;
    s.position = m.center(m.start) + Vector3(0, .8, 0);
    s.velocity = Vector3(0, 50, 0);
    s.step();
    final local = s.orientation.conjugated().rotated(s.position);
    expect(
      local.y + Simulation.radius,
      lessThanOrEqualTo(Simulation.invisibleCoverHeight + 1e-8),
    );
    expect(m.openCells.contains(m.cellAt(local)), true);
  });
  test('Stronger angular response reaches wide angles quickly', () {
    final s = Simulation(buildCampaign().first);
    s.rotateBy(Vector3(0, 0, 2));
    for (int i = 0; i < 36; i++) {
      s.step();
    }
    final up = s.orientation.rotated(Vector3(0, 1, 0));
    expect(up.distanceTo(Vector3(0, 1, 0)), greaterThan(.6));
    expect(
      s.angular.length,
      lessThanOrEqualTo(Simulation.maximumAngularSpeed + 1e-8),
    );
  });
  test('Invisible cover does not bypass a closed keyed door', () {
    final s = Simulation(buildCampaign().first), m = s.activeLevel.maze!;
    final door = m.doors.firstWhere((d) => d.kind == 'A'), wall = door.wall;
    final center = (wall.min + wall.max) * .5
      ..y = Simulation.radius;
    final direction = wall.max.x - wall.min.x < wall.max.z - wall.min.z
        ? Vector3(1, 0, 0)
        : Vector3(0, 0, 1);
    s.position = center - direction * .115;
    s.velocity = direction * .8;
    for (int i = 0; i < 96; i++) {
      s.step();
    }
    expect(s.doorOpen(door), false);
    expect((s.position - center).dot(direction), lessThan(0));
    s.collected.add(1000);
    s.tokens = 1;
    s.velocity = direction * .8;
    for (int i = 0; i < 144; i++) {
      s.step();
    }
    expect(s.doorOpen(door), true);
    expect((s.position - center).dot(direction), greaterThan(.03));
  });
  test(
    'Rapid rotations keep the marble inside the rolling layer and valid paths',
    () {
      for (final level in buildCampaign()) {
        final s = Simulation(level), maze = level.maze!;
        for (int i = 0; i < 240 * 3; i++) {
          if (i % 60 == 0) s.rotateBy(Vector3(6.5, -4.8, 5.2));
          s.step();
          final local = s.orientation.conjugated().rotated(s.position);
          expect(
            local.y,
            inInclusiveRange(
              Simulation.radius - 1e-8,
              Simulation.invisibleCoverHeight - Simulation.radius + 1e-8,
            ),
            reason: 'Level ${level.id}, step $i',
          );
          expect(maze.openCells.contains(maze.cellAt(local)), true);
          final relative = s.orientation.conjugated().rotated(
            s.velocity - s.surfaceVelocity(local),
          )..y = 0;
          expect(
            relative.length,
            lessThanOrEqualTo(Simulation.maximumRelativeSpeed + 1e-8),
          );
        }
      }
    },
  );
  test('Escaped marble returns to a recent safe cell without losing puzzle progress', () {
    final s = Simulation(buildCampaign().first), maze = s.activeLevel.maze!;
    for (int i = 0; i < 10; i++) {
      s.step();
    }
    s.collected.add(1000);
    s.tokens = 1;
    s.pressureActive = true;
    s.position = Vector3(40, 30, 40);
    s.velocity = Vector3(50, 50, 50);
    s.step();
    final local = s.orientation.conjugated().rotated(s.position);
    expect(
      local.distanceTo(
        maze.center(maze.start) + Vector3(0, Simulation.radius, 0),
      ),
      lessThan(.01),
    );
    expect(s.tokens, 1);
    expect(s.pressureActive, true);
    expect(s.falls, 1);
    expect(s.pendingRotation.length, 0);
  });
  test('High sensitivity remains available', () {
    final s = Simulation(buildCampaign().first);
    s.rotateBy(Vector3(0, 0, 3));
    for (int i = 0; i < 120; i++) {
      s.step();
    }
    expect(
      s.orientation.rotated(Vector3(0, 1, 0)).distanceTo(Vector3(0, 1, 0)),
      greaterThan(.8),
    );
  });
}
