import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/campaign.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Maze route is traversed by quaternion input through real sphere physics', () {
    final s = Simulation(buildCampaign().last);
    final m = s.activeLevel.maze!;
    final plan = <int>[0];
    int at = 0;
    for (final destination in [...m.keys, m.plate, m.goal]) {
      plan.addAll(m.route(at, destination).skip(1));
      at = destination;
    }
    int target = 0, lastTarget = -1;
    final integral = Vector3.zero();
    for (int tick = 0; tick < 240 * 6000 && !s.won; tick++) {
      final local = s.orientation.conjugated().rotated(s.position);
      final relative = s.orientation.conjugated().rotated(
        s.velocity - s.surfaceVelocity(local),
      );
      final cell = m.cellAt(local);
      if (tick % 120 == 0 &&
          cell != plan[target] &&
          !m.graph[cell].contains(plan[target])) {
        final detour = m.route(cell, plan[target]);
        if (detour.length > 2) {
          plan.insertAll(target, detour.sublist(1, detour.length - 1));
        }
      }
      final goal = m.center(plan[target]);
      final error = Vector3(goal.x - local.x, 0, goal.z - local.z);
      if (error.length < .045) {
        if (!(plan[target] == m.plate && !s.pressureActive) &&
            target < plan.length - 1) {
          target++;
        }
      }
      if (lastTarget != plan[target]) {
        integral.setZero();
        lastTarget = plan[target];
      }
      integral.add(error * Simulation.dt);
      if (integral.length > .7) integral.scale(.7 / integral.length);
      var accel = error * 4 - relative * 8 + integral * .6;
      if (m.belts.contains(cell)) {
        accel -= m.beltDirections[cell]! * (s.pressureActive ? -1.26 : 1.26);
      }
      final limit = m.belts.contains(cell) ? 1.7 : 1.0;
      if (accel.length > limit) accel.scale(limit / accel.length);
      final gravity = Vector3(accel.x, -3.2, accel.z).normalized(),
          down = Vector3(0, -1, 0),
          rotationAxis = down.cross(gravity);
      final desired = rotationAxis.length < 1e-12
          ? Quaternion.identity()
          : Quaternion.axisAngle(
              rotationAxis.normalized(),
              math.atan2(rotationAxis.length, down.dot(gravity)),
            );
      var delta = desired * s.orientation.conjugated();
      if (delta.w < 0) delta = delta.scaled(-1);
      final axis = Vector3(delta.x, delta.y, delta.z),
          angle = 2 * math.acos(delta.w.clamp(-1.0, 1.0));
      s.spinInput = axis.length < 1e-8
          ? Vector3.zero()
          : axis.normalized() * math.min(.12, angle * 1.6);
      s.step();
    }
    final end = s.orientation.conjugated().rotated(s.position);
    // ignore: avoid_print
    print(
      'cell ${m.cellAt(end)} target ${plan[target]} pos $end destination ${m.center(plan[target])} belt ${m.belts.contains(m.cellAt(end))} velocity ${s.velocity} spin ${s.angular}',
    );
    // ignore: avoid_print
    print(
      'Maze: target $target/${plan.length}, keys ${s.tokens}, plate ${s.pressureActive}, falls ${s.falls}, won ${s.won}',
    );
    expect(s.won, true);
  });
}
