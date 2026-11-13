import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'maze.dart';

class Track {
  final Vector3 a, b;
  int index = -1;
  final double width;
  final String material, mechanism;
  final bool rails;
  Track(
    this.a,
    this.b,
    this.width, {
    this.material = 'metal',
    this.mechanism = '',
    this.rails = true,
  });
  late final Vector3 tangent = (b - a).normalized();
  late final Vector3 side = Vector3(tangent.z, 0, -tangent.x).normalized();
  late final Vector3 normal = tangent.cross(side).normalized();
  late final double length = a.distanceTo(b);
  late Vector3 leftA = a - side * width / 2, rightA = a + side * width / 2;
  late Vector3 leftB = b - side * width / 2, rightB = b + side * width / 2;
  late List<SurfaceTriangle> triangles;
  late List<RailWall> walls;
  late Vector3 boundsMin, boundsMax;
  void seal() {
    walls = [RailWall(leftA, leftB, center), RailWall(rightB, rightA, center)];
    triangles = [
      SurfaceTriangle(leftA, leftB, rightB),
      SurfaceTriangle(leftA, rightB, rightA),
    ];
    boundsMin = Vector3(double.infinity, double.infinity, double.infinity);
    boundsMax = Vector3(
      double.negativeInfinity,
      double.negativeInfinity,
      double.negativeInfinity,
    );
    for (final v in [leftA, rightA, rightB, leftB]) {
      Vector3.min(boundsMin, v, boundsMin);
      Vector3.max(boundsMax, v, boundsMax);
    }
  }

  Vector3 get center => (a + b) * .5;
}

class Level {
  final int id;
  final String name, hint;
  final List<Track> tracks;
  final List<Level> rooms;
  final String rule, roomTitle;
  final MazeData? maze;
  final Vector3? startOverride, exitOverride;
  final double radius, mechanismRate;
  final List<int> sequenceOrder;
  Level(
    this.id,
    this.name,
    this.hint,
    this.tracks, {
    this.rooms = const [],
    this.rule = '',
    this.roomTitle = '',
    this.maze,
    this.startOverride,
    this.exitOverride,
    this.radius = 2,
    this.mechanismRate = 1,
    this.sequenceOrder = const [1, 0, 2],
  }) {
    for (int i = 1; i < tracks.length; i++) {
      final prev = tracks[i - 1], next = tracks[i];
      if (prev.b.distanceTo(next.a) > 1e-7) continue;
      final bisector = (prev.side + next.side).normalized();
      final projection = bisector.dot(next.side).abs().clamp(.65, 1.0);
      final half = (prev.width + next.width) / 4 / projection;
      final edge = bisector * half;
      prev.leftB = next.a - edge;
      prev.rightB = next.a + edge;
      next.leftA = prev.leftB;
      next.rightA = prev.rightB;
    }
    for (int i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      t.index = i;
      t.seal();
      // Inflate by the exact contact margin used by the sphere solver.
      const margin = .085 + .025;
      for (
        int x = ((t.boundsMin.x - margin) / _cellSize).floor();
        x <= ((t.boundsMax.x + margin) / _cellSize).floor();
        x++
      ) {
        for (
          int y = ((t.boundsMin.y - margin) / _cellSize).floor();
          y <= ((t.boundsMax.y + margin) / _cellSize).floor();
          y++
        ) {
          for (
            int z = ((t.boundsMin.z - margin) / _cellSize).floor();
            z <= ((t.boundsMax.z + margin) / _cellSize).floor();
            z++
          ) {
            final bucket = _collisionGrid.putIfAbsent(_key(x, y, z), () => []);
            if (bucket.isEmpty || bucket.last != i) bucket.add(i);
          }
        }
      }
    }
  }
  static const _cellSize = .4;
  final Map<int, List<int>> _collisionGrid = {};
  static int _key(int x, int y, int z) =>
      (x * 73856093) ^ (y * 19349663) ^ (z * 83492791);
  List<int> collisionCandidates(Vector3 p) =>
      _collisionGrid[_key(
        (p.x / _cellSize).floor(),
        (p.y / _cellSize).floor(),
        (p.z / _cellSize).floor(),
      )] ??
      const [];
  Vector3 get start => startOverride ?? tracks.first.a + Vector3(0, .14, 0);
  Vector3 get exit => exitOverride ?? tracks.last.b;
}

const names = [
  'La primera vuelta',
  'Segundo piso',
  'La espiral',
  'Canto fino',
  'A contratiempo',
  'El péndulo',
  'Pista helada',
  'Campo magnético',
  'Ascensor de cristal',
  'Engranajes',
  'Resortera',
  'Cerradura',
  'Contrapeso',
  'Doble sincronía',
  'El corazón de la esfera',
];
const hints = [
  'Arrastra para inclinar. Inclina al lado contrario para frenar.',
  'Sigue la curva descendente hasta el segundo piso.',
  'Sigue la hélice y controla el impulso.',
  'Corrige con movimientos pequeños en los puentes.',
  'Espera la señal verde antes de cruzar.',
  'Esquiva los brazos. Descansa sobre la placa.',
  'El hielo desliza; la goma frena.',
  'Los campos turquesa atraen; los rosados repelen.',
  'Espera al ascensor en el descansillo.',
  'Cruza cuando las ranuras estén alineadas.',
  'Carga el resorte y dirige el salto.',
  'Recoge las dos fichas para abrir la salida.',
  'Carga el contrapeso y cruza la banda.',
  'Encadena las tres ventanas de paso.',
  'Cruza las tres cámaras y apunta al conducto.',
];

// Each route is authored independently in toy-space metres.
// Subdivision preserves corners and leaves collider dimensions identical to meshes.
const layouts = <List<List<double>>>[
  [
    [-1.3, .65, .3],
    [-.6, .55, .3],
    [.3, .4, .3],
    [1, .25, .1],
    [1, .1, -.6],
    [.4, -.1, -1],
    [-.4, -.35, -.8],
    [-1, -.55, -.3],
    [-1.75, -.75, -.1],
  ],
  [
    [-1.2, .95, -.6],
    [-.4, .8, -.6],
    [.7, .65, -.6],
    [1.1, .55, -.1],
    [1.1, -.1, .1],
    [.3, -.25, .4],
    [-.8, -.45, .7],
    [-1.7, -.7, .5],
  ],
  [],
  [
    [-1.1, .7, -.8],
    [.1, .55, -.8],
    [1, .4, -.6],
    [.9, .2, .6],
    [.1, 0, 1],
    [-.8, -.2, .65],
    [-1, -.4, -.2],
    [-.2, -.6, -.8],
    [.8, -.75, -1.5],
  ],
  [
    [-1.2, .65, .4],
    [-.5, .55, .4],
    [-.5, .45, -.65],
    [.35, .3, -.65],
    [.35, .15, .65],
    [1.1, -.1, .65],
    [1.1, -.3, -.55],
    [.4, -.5, -1],
    [-.6, -.75, -1.6],
  ],
  [
    [-1, .8, -.7],
    [-.7, .65, .6],
    [0, .4, .8],
    [.7, .2, .55],
    [1, .05, -.65],
    [.2, -.15, -.9],
    [-.6, -.45, -.6],
    [-1.65, -.7, -.4],
  ],
  [
    [-1.2, .65, -.6],
    [1, .4, -.6],
    [1, .25, .2],
    [-.9, 0, .2],
    [-.9, -.2, .8],
    [.8, -.4, .8],
    [1.6, -.7, .5],
  ],
  [
    [-1, .8, 0],
    [-.6, .65, -.8],
    [.3, .4, -1],
    [1, .15, -.4],
    [.65, -.05, .55],
    [-.25, -.3, 1],
    [-1, -.45, .5],
    [-1.7, -.7, .1],
  ],
  [
    [-1.1, .8, .7],
    [-1.1, .65, -.2],
    [-.3, .45, -.8],
    [.4, .25, -.65],
    [.5, -.05, .1],
    [.9, -.25, .8],
    [1.6, -.7, .65],
  ],
  [
    [-1.25, .7, 0],
    [-.9, .6, -.65],
    [-.2, .45, -.7],
    [.15, .3, -.1],
    [-.3, .2, .5],
    [.2, .05, .9],
    [.95, -.15, .65],
    [1.1, -.35, -.1],
    [.75, -.5, -.9],
    [1.1, -.7, -1.4],
  ],
  [
    [-1.1, .65, -.6],
    [-.5, .4, -.6],
    [.25, .1, -.6],
    [.8, .35, -.4],
    [1, .25, .3],
    [.4, 0, .8],
    [-.5, -.3, .9],
    [-1.6, -.7, .7],
  ],
  [
    [-.8, .8, 0],
    [-1, .65, -.7],
    [-.2, .45, -1],
    [.5, .3, -.55],
    [0, .1, 0],
    [-.65, -.05, .65],
    [0, -.3, 1],
    [.8, -.5, .55],
    [1.7, -.7, .1],
  ],
  [
    [-1.2, .8, -.5],
    [-.8, .6, .4],
    [0, .4, .55],
    [.8, .25, .3],
    [1, .05, -.6],
    [.2, -.2, -.8],
    [-.65, -.45, -.5],
    [-1.65, -.7, -.2],
  ],
  [
    [-1.2, .9, .3],
    [-.8, .7, -.7],
    [0, .5, -1],
    [.8, .3, -.65],
    [.65, .05, .3],
    [0, -.15, .8],
    [-.6, -.35, .3],
    [-.2, -.55, -.5],
    [.8, -.75, -1.5],
  ],
  [
    [-1, .95, -.4],
    [-.65, .8, -.9],
    [0, .65, -.65],
    [.2, .5, 0],
    [-.5, .35, .45],
    [-1, .15, .2],
    [-.4, -.05, -.2],
    [.4, -.2, .3],
    [.8, -.4, .9],
    [1.2, -.65, .5],
    [1.75, -.8, .1],
  ],
];
List<Vector3> smoothRoute(List<Vector3> anchors) {
  const spacing = .055, sigma = .34;
  final lengths = <double>[0];
  for (int i = 1; i < anchors.length; i++) {
    lengths.add(lengths.last + anchors[i - 1].distanceTo(anchors[i]));
  }
  final total = lengths.last, count = (total / spacing).ceil();
  final raw = <Vector3>[];
  int segment = 0;
  for (int i = 0; i <= count; i++) {
    final distance = total * i / count;
    while (segment < anchors.length - 2 && lengths[segment + 1] < distance) {
      segment++;
    }
    final f =
        (distance - lengths[segment]) /
        (lengths[segment + 1] - lengths[segment]);
    raw.add(anchors[segment] + (anchors[segment + 1] - anchors[segment]) * f);
  }
  final step = total / count, window = (sigma * 3 / step).ceil();
  final first = (raw[1] - raw[0]).normalized(),
      last = (raw.last - raw[raw.length - 2]).normalized();
  Vector3 at(int i) => i < 0
      ? raw.first + first * (step * i)
      : i >= raw.length
      ? raw.last + last * (step * (i - raw.length + 1))
      : raw[i];
  final result = <Vector3>[];
  for (int i = 0; i < raw.length; i++) {
    final p = Vector3.zero();
    double weight = 0;
    for (int k = -window; k <= window; k++) {
      final w = math.exp(-k * k * step * step / (2 * sigma * sigma));
      p.add(at(i + k) * w);
      weight += w;
    }
    result.add(p / weight);
  }
  final startError = anchors.first - result.first,
      endError = anchors.last - result.last;
  for (int i = 0; i < result.length; i++) {
    final t = i / (result.length - 1);
    result[i] +=
        startError * math.pow(1 - t, 5).toDouble() +
        endError * math.pow(t, 5).toDouble();
  }
  return result;
}

List<Level> buildLevels() => List.generate(15, (n) {
  final id = n + 1;
  final anchors = id == 3
      ? List.generate(65, (i) {
          final t = i / 64;
          return Vector3(
            .95 * math.cos(t * math.pi * 3),
            .95 - t * 1.7,
            .95 * math.sin(t * math.pi * 3),
          );
        })
      : layouts[n].map((p) => Vector3(p[0], p[1], p[2])).toList();
  final points = smoothRoute(anchors), tracks = <Track>[];
  for (int i = 0; i < points.length - 1; i++) {
    final f = i / (points.length - 2);
    bool at(double target) => i == ((points.length - 1) * target).floor();
    String m = '';
    if ((id == 5 || id == 14) && at(.5)) m = 'gate';
    if (id == 6 && (at(.3) || at(.65))) m = 'pendulum';
    if (id == 6 && at(.8)) m = 'plate';
    if ((id == 8 || id == 15) && at(.3)) m = 'attract';
    if ((id == 8 || id == 15) && at(.7)) m = 'repel';
    if ((id == 9 || id == 14) && at(.6)) m = 'lift';
    if ((id == 10 || id == 14) && (at(.3) || at(.7))) m = 'gear';
    if (id == 11 && at(.4)) m = 'spring';
    if (id == 12 && (at(.3) || at(.7))) m = 'token';
    if ((id == 13 || id == 15) && at(.4)) m = 'counterweight';
    if (id == 13 && f > .6 && f < .72) m = 'belt';
    tracks.add(
      Track(
        points[i],
        points[i + 1],
        id < 3
            ? .48
            : id == 4
            ? .23
            : .34,
        rails: id != 4,
        material: (id == 7 || id == 15) && f < .45
            ? 'ice'
            : id == 7
            ? 'rubber'
            : 'metal',
        mechanism: m,
      ),
    );
  }
  return Level(id, names[n], hints[n], tracks);
});

// Triangle contact uses precisely the vertices rendered by the ribbon mesh.
class SurfaceTriangle {
  final Vector3 a, b, c;
  late final Vector3 ab = b - a, ac = c - a;
  late final Vector3 normal = _upNormal();
  Vector3 _upNormal() {
    final n = ab.cross(ac).normalized();
    return n.y < 0 ? -n : n;
  }

  SurfaceTriangle(this.a, this.b, this.c);
  Vector3 closest(Vector3 p) {
    final ap = p - a;
    final d1 = ab.dot(ap), d2 = ac.dot(ap);
    if (d1 <= 0 && d2 <= 0) return a;
    final bp = p - b;
    final d3 = ab.dot(bp), d4 = ac.dot(bp);
    if (d3 >= 0 && d4 <= d3) return b;
    final vc = d1 * d4 - d3 * d2;
    if (vc <= 0 && d1 >= 0 && d3 <= 0) return a + ab * (d1 / (d1 - d3));
    final cp = p - c;
    final d5 = ab.dot(cp), d6 = ac.dot(cp);
    if (d6 >= 0 && d5 <= d6) return c;
    final vb = d5 * d2 - d1 * d6;
    if (vb <= 0 && d2 >= 0 && d6 <= 0) return a + ac * (d2 / (d2 - d6));
    final va = d3 * d6 - d5 * d4;
    if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
      return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)));
    }
    final denom = 1 / (va + vb + vc);
    return a + ab * (vb * denom) + ac * (vc * denom);
  }
}

class RailWall {
  final Vector3 a, b, interior;
  late final Vector3 direction = (b - a).normalized();
  late final double length = a.distanceTo(b);
  late final Vector3 inward = _inward();
  Vector3 _inward() {
    final n = Vector3(direction.z, 0, -direction.x).normalized();
    return n.dot(interior - (a + b) * .5) < 0 ? -n : n;
  }

  RailWall(this.a, this.b, this.interior);
}
