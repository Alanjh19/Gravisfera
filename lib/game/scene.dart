import 'dart:math' as math;

import 'package:flutter/material.dart' hide Simulation;
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'physics.dart';
import 'maze.dart';

class Face {
  final List<Vector3> vertices;
  final Color color;
  List<int>? fogCells;
  late final Paint dim = Paint()
    ..color = Color.lerp(
      const Color(0xff0b1620),
      color,
      .20,
    )!.withValues(alpha: .97);
  late final Paint solid = Paint()..color = color.withValues(alpha: .95);
  late final Paint faded = Paint()..color = color.withValues(alpha: .19);
  Face(this.vertices, this.color);
}

class _DrawFace {
  final Face source;
  final Path path;
  final Rect bounds;
  final double depth;
  final bool dim;
  _DrawFace(
    this.source,
    this.path,
    this.bounds,
    this.depth, {
    this.dim = false,
  });
}

final _mazeMeshes = Expando<List<Face>>('maze static geometry');
final _labels = <String, TextPainter>{};
final _trackMeshes = Expando<List<Face>>('unchanged track geometry');
final _equators = <(bool, double), List<Face>>{};
final _engravings = List.generate(96, (i) {
  final band = i ~/ 48, j = i % 48;
  final a = j / 48 * math.pi * 2, b = (j + .55) / 48 * math.pi * 2;
  return [
    band == 0
        ? Vector3(2 * math.cos(a), 2 * math.sin(a), 0)
        : Vector3(0, 2 * math.cos(a), 2 * math.sin(a)),
    band == 0
        ? Vector3(2 * math.cos(b), 2 * math.sin(b), 0)
        : Vector3(0, 2 * math.cos(b), 2 * math.sin(b)),
  ];
});

class ToyPainter extends CustomPainter {
  final Simulation sim;
  final double zoom, cinema, animationTime;
  final bool reduced, victory, floating;
  final bool low, followMarble;
  final Vector3? cameraTarget;
  ToyPainter(
    this.sim, {
    this.zoom = 1,
    this.followMarble = false,
    this.cameraTarget,
    this.cinema = 0,
    this.low = false,
    this.animationTime = 0,
    this.reduced = false,
    this.victory = false,
    this.floating = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    var center = Offset(
      size.width / 2,
      size.height / 2 +
          (floating && !reduced ? math.sin(animationTime * .9) * 5 : 0),
    );
    final toyRadius = sim.activeLevel.radius,
        distance = sim.activeLevel.radius * 3;
    final scale =
        math.min(size.width, size.height) * .235 * zoom * 2 / toyRadius;
    final viewMatrix = sim.activeLevel.maze != null
        ? Matrix3.rotationX(math.pi / 3)
        : Matrix3.identity();
    if (followMarble ||
        (sim.activeLevel.maze != null && zoom > 1 && !reduced)) {
      final bp = viewMatrix.transformed(
            followMarble ? (cameraTarget ?? sim.position) : sim.position,
          ),
          f = scale * distance / (distance - bp.z);
      final strength = followMarble ? 1.0 : ((zoom - 1) / .8).clamp(0.0, 1.0);
      center -= Offset(bp.x, -bp.y) * f * strength;
    }
    Offset project(Vector3 point) {
      final v = sim.activeLevel.maze != null
          ? viewMatrix.transformed(point)
          : point;
      final f = distance / (distance - v.z);
      final cameraShift = reduced
          ? Offset.zero
          : Offset(cinema * 9, cinema * 5);
      return center + cameraShift + Offset(v.x, -v.y) * scale * f;
    }

    // Quaternion.rotated uses the inverse convention of asRotationMatrix.
    final worldMatrix = sim.orientation.asRotationMatrix()..transpose();
    final matrix = viewMatrix * worldMatrix;
    final transformed = Map<Vector3, Vector3>.identity();
    Vector3 world(Vector3 v) =>
        transformed.putIfAbsent(v, () => worldMatrix.transformed(v));
    final faces = <Face>[];
    void quad(List<Vector3> v, Color c) {
      faces.add(Face(v, c));
    }

    void box(Vector3 a, Vector3 b, double width, Color color) {
      final along = (b - a).normalized();
      final side = Vector3(along.z, 0, -along.x).normalized() * width / 2;
      final up = Vector3(0, .045, 0);
      final v = [a - side, a + side, b + side, b - side];
      quad(v, color);
      quad([v[0], v[1], v[1] - up, v[0] - up], const Color(0xff526f77));
      quad([v[1], v[2], v[2] - up, v[1] - up], const Color(0xff31505d));
      quad([v[2], v[3], v[3] - up, v[2] - up], const Color(0xff7f9c9e));
    }

    final shadow = Rect.fromCenter(
      center: center + Offset(0, scale * toyRadius * 1.06),
      width: scale * toyRadius * 1.5,
      height: scale * toyRadius * .115,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..color = const Color(0xff52636b).withValues(alpha: .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    final sphereRadius = scale * toyRadius * 1.04;
    canvas.drawCircle(
      center,
      sphereRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff698e9a).withValues(alpha: .02),
            const Color(0xff84c9db).withValues(alpha: .06),
            const Color(0xffb2c7cf).withValues(alpha: .20),
          ],
          stops: const [0, .88, 1],
        ).createShader(Rect.fromCircle(center: center, radius: sphereRadius)),
    );
    for (final t in sim.activeLevel.tracks) {
      final i = t.index;
      final cached = _trackMeshes[t];
      final off = Vector3.zero();
      if (cached != null) {
        faces.addAll(cached);
      } else {
        final start = faces.length;

        final color = sim.activeLevel.maze != null
            ? (sim.activeLevel.maze!.darkness
                  ? const Color(0xff101c24)
                  : const Color(0xffe5e9df))
            : t.material == 'ice'
            ? const Color(0xffa5efff)
            : t.material == 'rubber'
            ? const Color(0xffdd8b59)
            : [
                const Color(0xff46a89b),
                const Color(0xffdb9866),
                const Color(0xff759ac3),
                const Color(0xffa49cce),
                const Color(0xffd3ad58),
              ][(sim.level.id - 1) % 5];
        final down = Vector3(0, .045, 0);
        quad([
          t.leftA + off,
          t.leftB + off,
          t.rightB + off,
          t.rightA + off,
        ], color);
        quad([
          t.leftA + off,
          t.leftA + off - down,
          t.leftB + off - down,
          t.leftB + off,
        ], const Color(0xff526f77));
        quad([
          t.rightA + off,
          t.rightB + off,
          t.rightB + off - down,
          t.rightA + off - down,
        ], const Color(0xff31505d));
        if (t.rails) {
          final up = Vector3(0, .09, 0);
          for (final edge in [
            [t.leftA, t.leftB],
            [t.rightA, t.rightB],
          ]) {
            quad([
              edge[0] + off,
              edge[1] + off,
              edge[1] + off + up,
              edge[0] + off + up,
            ], const Color(0xff9fc2c5));
            final inset = t.side * .012;
            quad([
              edge[0] + off + up - inset,
              edge[1] + off + up - inset,
              edge[1] + off + up + inset,
              edge[0] + off + up + inset,
            ], const Color(0xffd0e0dc));
          }
        }

        if (i % 5 == 0) {
          box(
            t.center + Vector3(0, -.35, 0),
            t.center,
            .035,
            const Color(0xff405965),
          );
        }

        _trackMeshes[t] = List.unmodifiable(faces.sublist(start));
      }
      if (t.mechanism.isNotEmpty &&
          !(t.mechanism == 'token' && sim.collected.contains(t.index))) {
        final c = t.center + off;
        final phase = sim.phase(t);
        if (t.mechanism == 'gear') {
          final angle = sim.time * 1.8 * sim.activeLevel.mechanismRate + i * .4;
          for (int tooth = 0; tooth < 14; tooth++) {
            final a = angle + tooth * math.pi * 2 / 14, b = a + .32;
            quad([
              c + Vector3(.24 * math.cos(a), .08, .24 * math.sin(a)),
              c + Vector3(.32 * math.cos(a), .08, .32 * math.sin(a)),
              c + Vector3(.32 * math.cos(b), .08, .32 * math.sin(b)),
              c + Vector3(.24 * math.cos(b), .08, .24 * math.sin(b)),
            ], const Color(0xffc7a166));
          }
        } else if (t.mechanism == 'gate') {
          box(
            c + Vector3(-t.width / 2, .02 + phase * .32, 0),
            c + Vector3(t.width / 2, .02 + phase * .32, 0),
            .07,
            phase > .57 ? const Color(0xffb5f494) : const Color(0xffed947b),
          );
        } else if (t.mechanism == 'pendulum') {
          box(
            c + Vector3(0, .35, 0),
            c + Vector3(math.sin(sim.time * 2) * .3, .03, 0),
            .06,
            const Color(0xffed947b),
          );
        } else {
          box(
            c + Vector3(-.09, .015, 0),
            c + Vector3(.09, .015, 0),
            .15,
            t.mechanism == 'repel'
                ? const Color(0xffed9ec2)
                : t.mechanism == 'plate' && sim.pressureActive
                ? const Color(0xff6fc69a)
                : const Color(0xffe5cb7e),
          );
        }
      }
    }
    // Surface cues move from mechanism time, which freezes in pause.
    for (final t in sim.activeLevel.tracks.where(
      (t) => t.mechanism.isNotEmpty,
    )) {
      final c = t.center;
      if (t.mechanism == 'attract' || t.mechanism == 'repel') {
        for (int ring = 0; ring < 3; ring++) {
          final radius = .13 + ((sim.time * .18 + ring / 3) % 1) * .35;
          final path = Path();
          for (int j = 0; j <= 32; j++) {
            final a = j / 32 * math.pi * 2;
            final pt = project(
              world(
                c + Vector3(radius * math.cos(a), .02, radius * math.sin(a)),
              ),
            );
            if (j == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..color =
                  (t.mechanism == 'repel'
                          ? const Color(0xffbd608b)
                          : const Color(0xff258d81))
                      .withValues(alpha: .22)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
      if (t.mechanism == 'belt') {
        final tangent = (t.b - t.a).normalized(),
            side = Vector3(tangent.z, 0, -tangent.x).normalized();
        final point =
            t.a + (t.b - t.a) * ((sim.time * .7) % 1) + Vector3(0, .07, 0);
        final path = Path()
          ..moveTo(
            project(world(point - side * .07 - tangent * .04)).dx,
            project(world(point - side * .07 - tangent * .04)).dy,
          )
          ..lineTo(
            project(world(point + tangent * .04)).dx,
            project(world(point + tangent * .04)).dy,
          )
          ..lineTo(
            project(world(point + side * .07 - tangent * .04)).dx,
            project(world(point + side * .07 - tangent * .04)).dy,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xff394d53)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (t.mechanism == 'spring') {
        for (int j = 0; j < 6; j++) {
          final y = .04 + j * .025 * (1 - sim.charge.clamp(0, .4));
          box(
            c + Vector3(-.1, y, 0),
            c + Vector3(.1, y + .012, 0),
            .035,
            const Color(0xffb48e55),
          );
        }
      }
    }
    final maze = sim.activeLevel.maze;
    void solid(
      MazeWall wall, {
      double lift = 0,
      Color color = const Color(0xff9aafaa),
    }) {
      final firstFace = faces.length;
      final x0 = wall.min.x,
          x1 = wall.max.x,
          z0 = wall.min.z,
          z1 = wall.max.z,
          y0 = wall.min.y + lift,
          y1 = wall.max.y + lift;
      final a = Vector3(x0, y1, z0),
          b = Vector3(x1, y1, z0),
          c = Vector3(x1, y1, z1),
          d = Vector3(x0, y1, z1);
      quad([a, b, c, d], color);
      quad([
        a,
        Vector3(x0, y0, z0),
        Vector3(x1, y0, z0),
        b,
      ], const Color(0xff698783));
      quad([
        b,
        Vector3(x1, y0, z0),
        Vector3(x1, y0, z1),
        c,
      ], const Color(0xff728b8b));
      quad([
        c,
        Vector3(x1, y0, z1),
        Vector3(x0, y0, z1),
        d,
      ], const Color(0xff698783));
      quad([
        d,
        Vector3(x0, y0, z1),
        Vector3(x0, y0, z0),
        a,
      ], const Color(0xff728b8b));
      if (maze != null) {
        final c = (wall.min + wall.max) * .5;
        final cells = [
          for (final dx in [-.03, .03])
            for (final dz in [-.03, .03]) maze.cellAt(c + Vector3(dx, 0, dz)),
        ];
        for (int i = firstFace; i < faces.length; i++) {
          faces[i].fogCells = cells;
        }
      }
    }

    if (maze != null) {
      final cached = _mazeMeshes[maze];
      if (cached != null) {
        faces.addAll(cached);
      } else {
        final start = faces.length;
        for (final wall in maze.walls) {
          solid(wall);
        }
        for (final cell in maze.ice) {
          final c = maze.center(cell), h = MazeData.cell * .48;
          quad([
            c + Vector3(-h, .003, -h),
            c + Vector3(h, .003, -h),
            c + Vector3(h, .003, h),
            c + Vector3(-h, .003, h),
          ], const Color(0xff9edeea));
          faces.last.fogCells = [cell];
        }
        for (final cell in maze.belts) {
          final c = maze.center(cell);
          box(
            c + Vector3(-.08, .007, 0),
            c + Vector3(.08, .007, 0),
            .14,
            const Color(0xffdaa577),
          );
          for (final f in faces.skip(faces.length - 4)) {
            f.fogCells = [cell];
          }
        }
        _mazeMeshes[maze] = List.unmodifiable(faces.sublist(start));
      }
      if (maze.darkness) {
        for (final cell in sim.explored) {
          final c = maze.center(cell), h = MazeData.cell * .501;
          quad(
            [
              c + Vector3(-h, .002, -h),
              c + Vector3(h, .002, -h),
              c + Vector3(h, .002, h),
              c + Vector3(-h, .002, h),
            ],
            sim.visible.contains(cell)
                ? const Color(0xff547b7a)
                : const Color(0xff1c333b),
          );
        }
      }
      for (final gate in maze.gates) {
        solid(
          gate.wall,
          lift: gate.isClosed(sim.time) ? 0 : .28,
          color: gate.isClosed(sim.time)
              ? const Color(0xffd59b7b)
              : const Color(0xff8bc8ac),
        );
      }
      for (int i = 0; i < maze.keys.length; i++) {
        if (!sim.collected.contains(1000 + i) &&
            (!maze.darkness || sim.explored.contains(maze.keys[i]))) {
          final c = maze.center(maze.keys[i]) + Vector3(0, .05, 0);
          box(
            c + Vector3(-.05, 0, 0),
            c + Vector3(.05, 0, 0),
            .10,
            const Color(0xffedc46c),
          );
        }
      }
      if (maze.plate >= 0 &&
          (!maze.darkness || sim.explored.contains(maze.plate))) {
        final p = maze.center(maze.plate) + Vector3(0, .006, 0);
        box(
          p + Vector3(-.08, 0, 0),
          p + Vector3(.08, 0, 0),
          .16,
          sim.pressureActive
              ? const Color(0xff6fc69a)
              : const Color(0xffd3a5c9),
        );
      }
      for (final door in maze.doors) {
        solid(
          door.wall,
          lift: sim.doorOpen(door) ? .28 : 0,
          color: sim.doorOpen(door)
              ? const Color(0xff74ba9b)
              : const Color(0xffcc826a),
        );
      }
      for (final entry in maze.sequencePads.entries) {
        if (maze.darkness && !sim.explored.contains(entry.key)) continue;
        final c = maze.center(entry.key) + Vector3(0, .008, 0),
            active = maze.sequenceOrder
                .take(sim.sequenceProgress)
                .contains(entry.value);
        box(
          c + Vector3(-.07, 0, 0),
          c + Vector3(.07, 0, 0),
          .14,
          active ? const Color(0xff6fc69a) : const Color(0xffebc16f),
        );
      }
      for (final entry in maze.toggles.entries) {
        if (maze.darkness && !sim.explored.contains(entry.key)) continue;
        final c = maze.center(entry.key) + Vector3(0, .008, 0);
        box(
          c + Vector3(-.07, 0, 0),
          c + Vector3(.07, 0, 0),
          .14,
          sim.switchMask & (1 << entry.value) != 0
              ? const Color(0xff6fc69a)
              : const Color(0xffc7a1cd),
        );
      }
      if (maze.orbital >= 0 &&
          (!maze.darkness || sim.explored.contains(maze.orbital))) {
        final c = maze.center(maze.orbital) + Vector3(0, .01, 0);
        box(
          c + Vector3(-.08, 0, 0),
          c + Vector3(.08, 0, 0),
          .16,
          sim.orbitalUnlocked
              ? const Color(0xff6fc69a)
              : const Color(0xff7dbccc),
        );
      }
      for (final cell in maze.belts) {
        if (maze.darkness && !sim.explored.contains(cell)) continue;
        final d = maze.beltDirections[cell]! * (sim.pressureActive ? -1 : 1),
            side = Vector3(d.z, 0, -d.x);
        final c =
            maze.center(cell) +
            Vector3(0, .018, 0) +
            d *
                ((sim.time * .45 / MazeData.cell) % 1 - .5) *
                MazeData.cell *
                .6;
        quad([
          c + d * .05,
          c - d * .04 + side * .04,
          c - d * .04 - side * .04,
        ], const Color(0xff5d452d));
        faces.last.fogCells = [cell];
      }
    }
    final ringKey = (low, toyRadius);
    final ringCache = _equators[ringKey];
    if (ringCache != null) {
      faces.addAll(ringCache);
    } else {
      final start = faces.length;
      final count = low ? 48 : 96;
      for (int i = 0; i < count; i++) {
        final a = i / count * math.pi * 2, b = (i + 1) / count * math.pi * 2;
        quad([
          Vector3(toyRadius * math.cos(a), -.018, toyRadius * math.sin(a)),
          Vector3(toyRadius * math.cos(b), -.018, toyRadius * math.sin(b)),
          Vector3(toyRadius * math.cos(b), .018, toyRadius * math.sin(b)),
          Vector3(toyRadius * math.cos(a), .018, toyRadius * math.sin(a)),
        ], const Color(0xffa0c7ce));
      }

      _equators[ringKey] = List.unmodifiable(faces.sublist(start));
    }
    final engravingPaint = Paint()
      ..color = const Color(0xff4c7e89).withValues(alpha: .22)
      ..strokeWidth = 1;
    for (final line in _engravings) {
      canvas.drawLine(
        project(world(line[0] * (toyRadius / 2))),
        project(world(line[1] * (toyRadius / 2))),
        engravingPaint,
      );
    }
    final ballDepth = viewMatrix.transformed(sim.position).z;
    final ball = project(sim.position);
    final ballRadius =
        scale * Simulation.radius * distance / (distance - ballDepth);
    final m = matrix.storage;
    final offsetX = center.dx + (reduced ? 0 : cinema * 9),
        offsetY = center.dy + (reduced ? 0 : cinema * 5);
    final drawFaces =
        faces
            .where(
              (face) =>
                  maze == null ||
                  !maze.darkness ||
                  face.fogCells == null ||
                  face.fogCells!.any(sim.explored.contains),
            )
            .map((face) {
              double depth = 0,
                  minX = double.infinity,
                  minY = double.infinity,
                  maxX = double.negativeInfinity,
                  maxY = double.negativeInfinity;
              final path = Path();
              for (int i = 0; i < face.vertices.length; i++) {
                final v = face.vertices[i];
                final x = m[0] * v.x + m[3] * v.y + m[6] * v.z;
                final y = m[1] * v.x + m[4] * v.y + m[7] * v.z;
                final z = m[2] * v.x + m[5] * v.y + m[8] * v.z;
                final f = scale * distance / (distance - z);
                final px = offsetX + x * f, py = offsetY - y * f;
                depth += z;
                if (i == 0) {
                  path.moveTo(px, py);
                } else {
                  path.lineTo(px, py);
                }
                minX = math.min(minX, px);
                minY = math.min(minY, py);
                maxX = math.max(maxX, px);
                maxY = math.max(maxY, py);
              }
              path.close();
              return _DrawFace(
                face,
                path,
                Rect.fromLTRB(minX, minY, maxX, maxY),
                depth / face.vertices.length,
                dim:
                    maze != null &&
                    maze.darkness &&
                    face.fogCells != null &&
                    !face.fogCells!.any(sim.visible.contains),
              );
            })
            .toList()
          ..sort((a, b) => a.depth.compareTo(b.depth));
    bool drawn = false;
    void marble() {
      canvas.drawCircle(
        ball,
        ballRadius + 2,
        Paint()..color = const Color(0xfff8e8bf).withValues(alpha: .7),
      );
      canvas.drawCircle(
        ball,
        ballRadius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.5),
            colors: [Colors.white, Color(0xffa9bac3), Color(0xff34434e)],
            stops: [0, .38, 1],
          ).createShader(Rect.fromCircle(center: ball, radius: ballRadius)),
      );
      final stripe = sim.roll.rotated(Vector3(1, 0, 0));
      canvas.save();
      canvas.translate(ball.dx, ball.dy);
      canvas.rotate(math.atan2(stripe.y, stripe.x));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: ballRadius * 1.8,
          height: ballRadius * .45,
        ),
        Paint()..color = const Color(0xffffad78),
      );
      canvas.restore();
    }

    for (final face in drawFaces) {
      if (!drawn && face.depth > ballDepth) {
        marble();
        drawn = true;
      }
      final occludes =
          face.depth > ballDepth &&
          face.bounds.contains(ball) &&
          face.path.contains(ball);
      canvas.drawPath(
        face.path,
        occludes
            ? face.source.faded
            : face.dim
            ? face.source.dim
            : face.source.solid,
      );
    }
    if (maze != null && maze.darkness) {
      final r = scale * MazeData.cell * 2.3;
      canvas.drawCircle(
        ball,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xffb1e3d5).withValues(alpha: .10),
              const Color(0xffb1e3d5).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: ball, radius: r)),
      );
    }
    if (!drawn) marble();
    canvas.drawCircle(
      ball,
      ballRadius + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xffffd3a2).withValues(alpha: .6),
    );
    canvas.drawCircle(
      center,
      sphereRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xff6e939f).withValues(alpha: .35),
    );
    final reflection = Rect.fromCircle(
      center: center,
      radius: sphereRadius * .97,
    );
    canvas.drawArc(
      reflection,
      3.6,
      .65,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: .3),
    );
    canvas.drawArc(
      reflection,
      .15,
      .28,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .22),
    );
    final exit = project(world(sim.activeLevel.exit));
    if (maze == null || !maze.darkness || sim.explored.contains(maze.goal)) {
      canvas.drawCircle(
        exit,
        scale * .12,
        Paint()
          ..color = !sim.portalReady
              ? const Color(0xffca7a69)
              : sim.finalRoom
              ? const Color(0xffedbc7c)
              : const Color(0xff59a8bd)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (victory) {
      final count = reduced
          ? 6
          : low
          ? 12
          : 28;
      for (int i = 0; i < count; i++) {
        final t = (-cinema).clamp(0.0, 1.0), angle = i * 2.399;
        final point =
            exit +
            Offset(math.cos(angle), math.sin(angle)) *
                (8 + t * 48) *
                (reduced ? .2 : 1);
        canvas.drawCircle(
          point,
          (1 - t) * 2.5 + .4,
          Paint()
            ..color = const Color(0xffbc985a).withValues(alpha: (1 - t) * .8),
        );
      }
      canvas.drawCircle(
        center,
        sphereRadius,
        Paint()
          ..color = const Color(0xffbb985f).withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (final t in sim.activeLevel.tracks) {
      if (t.mechanism.startsWith('sequence')) {
        final label = t.mechanism.substring(8),
            p = project(world(t.center + Vector3(0, .16, 0)));
        final text = _labels.putIfAbsent(
          label,
          () => TextPainter(
            text: TextSpan(
              text: '${int.parse(label) + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xff244f4b),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        );
        text.paint(canvas, p - Offset(text.width / 2, text.height / 2));
      }
    }
    if (maze != null) {
      final labels = <int, String>{
        ...maze.sequencePads.map((c, n) => MapEntry(c, '${n + 1}')),
        ...maze.toggles.map((c, n) => MapEntry(c, ['X', 'Y', 'Z'][n])),
        if (maze.orbital >= 0) maze.orbital: 'O',
        for (final d in maze.doors) d.cell: d.kind,
      };
      for (final e in labels.entries) {
        if (maze.darkness && !sim.visible.contains(e.key)) continue;
        final p = project(world(maze.center(e.key) + Vector3(0, .24, 0)));
        final text = _labels.putIfAbsent(
          'board${e.value}',
          () => TextPainter(
            text: TextSpan(
              text: e.value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xff54a997),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        );
        text.paint(canvas, p - Offset(text.width / 2, text.height / 2));
      }
    }
    final start = project(world(sim.activeLevel.start));
    canvas.drawCircle(
      start,
      scale * .13,
      Paint()
        ..color = const Color(0xff28786c).withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Gravity points down in world space regardless of toy rotation.
    canvas.drawLine(
      center + Offset(sphereRadius + 9, -15),
      center + Offset(sphereRadius + 9, 15),
      Paint()
        ..color = const Color(0xff738a8c)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant ToyPainter oldDelegate) => true;
}

class RouteThumbnail extends CustomPainter {
  final Simulation sim;
  RouteThumbnail(this.sim);
  @override
  void paint(Canvas c, Size size) {
    final scale = math.min(size.width, size.height) * .22;
    Offset p(Vector3 v) => Offset(
      size.width / 2 + v.x * scale,
      size.height / 2 + (v.z * .45 - v.y) * scale,
    );
    c.drawCircle(
      Offset(size.width / 2, size.height / 2),
      scale * 1.9,
      Paint()
        ..color = const Color(0xff698d91).withValues(alpha: .12)
        ..style = PaintingStyle.stroke,
    );
    if (sim.level.maze != null) {
      if (sim.level.maze!.darkness) {
        c.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.height * .35,
          Paint()..color = const Color(0xff11232a),
        );
        c.drawCircle(
          Offset(size.width / 2, size.height / 2),
          3,
          Paint()..color = const Color(0xffb7dec9),
        );
        return;
      }
      final maze = sim.level.maze!,
          factor =
              math.min(size.width, size.height) * .88 / sim.level.maze!.extent;
      Offset point(Vector3 v) =>
          Offset(size.width / 2 + v.x * factor, size.height / 2 + v.z * factor);
      final pen = Paint()
        ..color = const Color(0xff6a8980)
        ..strokeWidth = .8;
      for (final wall in maze.walls) {
        c.drawLine(point(wall.min), point(wall.max), pen);
      }
      c.drawCircle(
        point(maze.center(0)),
        2,
        Paint()..color = const Color(0xff294f4b),
      );
      c.drawCircle(
        point(maze.center(maze.goal)),
        2,
        Paint()..color = const Color(0xffc68d45),
      );
      return;
    }
    for (final t in sim.activeLevel.tracks) {
      c.drawLine(
        p(t.a),
        p(t.b),
        Paint()
          ..color = t.material == 'ice'
              ? const Color(0xff82b7d3)
              : const Color(0xff398c7f)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    c.drawCircle(
      p(sim.activeLevel.start),
      2.5,
      Paint()..color = const Color(0xff294f4b),
    );
    c.drawCircle(
      p(sim.activeLevel.exit),
      3,
      Paint()..color = const Color(0xffc68d45),
    );
  }

  @override
  bool shouldRepaint(covariant RouteThumbnail old) =>
      old.sim.level.id != sim.level.id;
}
