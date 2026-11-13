import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

class MazeWall {
  final Vector3 min, max;
  MazeWall(this.min, this.max);
}

class MazeGate {
  final MazeWall wall;
  final double phase;
  MazeGate(this.wall, this.phase);
  bool isClosed(double time) => .5 + .5 * math.sin(time * 1.15 + phase) < .58;
}

class MazeData {
  static const size = 21, cell = .27, thickness = .024;
  static const span = size * cell;
  final List<Set<int>> graph = List.generate(size * size, (_) => <int>{});
  final List<MazeWall> walls = [];
  final List<MazeGate> gates = [];
  final Set<int> ice = {}, belts = {};
  bool authored = false, darkness = true, brakeGoal = false;
  int start = 0, orbital = -1, targetMask = 0;
  double extent = span;
  final Set<int> openCells = {};
  final Map<int, Vector3> beltDirections = {};
  final Map<int, int> sequencePads = {}, toggles = {};
  final List<int> sequenceOrder = [1, 0, 2], magnets = [];
  final List<PuzzleDoor> doors = [];
  late final List<int> solution;
  late final int goal, plate;
  late final List<int> keys;
  MazeData(int seed) {
    openCells.addAll(List.generate(size * size, (i) => i));
    final random = math.Random(seed), seen = <int>{0}, stack = <int>[0];
    while (stack.isNotEmpty) {
      final c = stack.last, x = c % size, z = c ~/ size;
      final choices = <int>[
        if (x > 0) c - 1,
        if (x < size - 1) c + 1,
        if (z > 0) c - size,
        if (z < size - 1) c + size,
      ]..removeWhere(seen.contains);
      if (choices.isEmpty) {
        stack.removeLast();
        continue;
      }
      final next = choices[random.nextInt(choices.length)];
      graph[c].add(next);
      graph[next].add(c);
      seen.add(next);
      stack.add(next);
    }
    // A few loops allow alternate approaches; the goal remains unique.
    for (int i = 0; i < 9; i++) {
      final c = random.nextInt(size * size - 1),
          next = c % size < size - 1 ? c + 1 : c + size;
      if (next < size * size) {
        graph[c].add(next);
        graph[next].add(c);
      }
    }
    final distances = distanceMap(0);
    goal = List.generate(
      size * size,
      (i) => i,
    ).reduce((a, b) => distances[a]! > distances[b]! ? a : b);
    solution = route(0, goal);
    final deadEnds = List.generate(size * size, (i) => i)
      ..removeWhere((i) => i == 0 || i == goal || graph[i].length != 1);
    deadEnds.sort((a, b) => distances[b]!.compareTo(distances[a]!));
    keys = [deadEnds.first];
    final fromFirst = distanceMap(keys.first);
    keys.add(
      deadEnds.skip(1).reduce((a, b) => fromFirst[a]! > fromFirst[b]! ? a : b),
    );
    plate = deadEnds.firstWhere((i) => !keys.contains(i));
    for (int z = 0; z < size; z++) {
      for (int x = 0; x < size; x++) {
        final c = z * size + x;
        if (x == 0) walls.add(_vertical(x, z));
        if (z == 0) walls.add(_horizontal(x, z));
        if (x == size - 1 || !graph[c].contains(c + 1)) {
          walls.add(_vertical(x + 1, z));
        }
        if (z == size - 1 || !graph[c].contains(c + size)) {
          walls.add(_horizontal(x, z + 1));
        }
      }
    }
    for (int g = 1; g <= 4; g++) {
      final index = (solution.length * g / 5).floor().clamp(
        1,
        solution.length - 1,
      );
      final a = solution[index - 1], b = solution[index];
      final x = math.min(a % size, b % size),
          z = math.min(a ~/ size, b ~/ size);
      gates.add(
        MazeGate(
          a ~/ size == b ~/ size ? _vertical(x + 1, z) : _horizontal(x, z + 1),
          g * 1.7,
        ),
      );
    }
    for (int i = 3; i < solution.length - 3; i++) {
      if (i % 7 == 0) ice.add(solution[i]);
      if (i % 13 == 0) belts.add(solution[i]);
    }
    for (final wall in walls) {
      for (
        int x = ((wall.min.x + span / 2 - .085) / cell).floor();
        x <= ((wall.max.x + span / 2 + .085) / cell).floor();
        x++
      ) {
        for (
          int z = ((wall.min.z + span / 2 - .085) / cell).floor();
          z <= ((wall.max.z + span / 2 + .085) / cell).floor();
          z++
        ) {
          _wallGrid.putIfAbsent(x * 4096 + z, () => []).add(wall);
        }
      }
    }
    for (final cell in belts) {
      beltDirections[cell] = (center(graph[cell].first) - center(cell))
          .normalized();
    }
    ice.removeAll([0, goal, plate, ...keys]);
    belts.removeAll([0, goal, plate, ...keys]);
  }

  MazeData.authoredMap(
    String drawing, {
    bool fog = false,
    bool brake = false,
    int mask = 0,
    List<int> code = const [1, 0, 2],
  }) {
    authored = true;
    darkness = fog;
    brakeGoal = brake;
    targetMask = mask;
    sequenceOrder
      ..clear()
      ..addAll(code);
    final rows = drawing.trim().split('\n'),
        width = rows.map((r) => r.length).reduce(math.max),
        ox = (size - width) ~/ 2,
        oz = (size - rows.length) ~/ 2;
    extent = math.max(width, rows.length) * cell;
    final symbols = <int, String>{};
    for (int z = 0; z < rows.length; z++) {
      for (int x = 0; x < rows[z].length; x++) {
        final ch = rows[z][x], index = (z + oz) * size + x + ox;
        if (ch == '#' || ch == ' ') continue;
        openCells.add(index);
        symbols[index] = ch;
      }
    }
    start = symbols.entries.singleWhere((e) => e.value == 'S').key;
    goal = symbols.entries.singleWhere((e) => e.value == 'G').key;
    final plates = symbols.entries.where((e) => e.value == 'P');
    plate = plates.isEmpty ? -1 : plates.first.key;
    keys = [];
    for (final ch in ['a', 'b', 'c']) {
      final entries = symbols.entries.where((e) => e.value == ch);
      if (entries.isNotEmpty) keys.add(entries.first.key);
    }
    for (final c in openCells) {
      final x = c % size, z = c ~/ size;
      for (final n in [
        if (x > 0) c - 1,
        if (x < size - 1) c + 1,
        if (z > 0) c - size,
        if (z < size - 1) c + size,
      ]) {
        if (openCells.contains(n)) graph[c].add(n);
      }
    }
    for (final c in openCells) {
      final x = c % size, z = c ~/ size;
      if (!graph[c].contains(c - 1)) walls.add(_vertical(x, z));
      if (!graph[c].contains(c + 1)) walls.add(_vertical(x + 1, z));
      if (!graph[c].contains(c - size)) walls.add(_horizontal(x, z));
      if (!graph[c].contains(c + size)) walls.add(_horizontal(x, z + 1));
      final ch = symbols[c]!;
      if (ch == 'I') ice.add(c);
      if ('><^v'.contains(ch)) {
        belts.add(c);
        beltDirections[c] = {
          '>': Vector3(1, 0, 0),
          '<': Vector3(-1, 0, 0),
          '^': Vector3(0, 0, -1),
          'v': Vector3(0, 0, 1),
        }[ch]!;
      }
      if (ch == 'M') magnets.add(c);
      if (ch == 'O') orbital = c;
      if ('123'.contains(ch)) sequencePads[c] = int.parse(ch) - 1;
      if ('xyz'.contains(ch)) toggles[c] = 'xyz'.indexOf(ch);
      if (ch == 'T') gates.add(MazeGate(wallAt(c), gates.length * 1.7));
      if ('ABCDQ NXYZ'.replaceAll(' ', '').contains(ch)) {
        doors.add(PuzzleDoor(c, ch, wallAt(c)));
      }
    }
    solution = route(start, goal);
    for (final wall in walls) {
      for (
        int x = ((wall.min.x + span / 2 - .085) / cell).floor();
        x <= ((wall.max.x + span / 2 + .085) / cell).floor();
        x++
      ) {
        for (
          int z = ((wall.min.z + span / 2 - .085) / cell).floor();
          z <= ((wall.max.z + span / 2 + .085) / cell).floor();
          z++
        ) {
          _wallGrid.putIfAbsent(x * 4096 + z, () => []).add(wall);
        }
      }
    }
  }
  MazeWall wallAt(int c) {
    final p = center(c);
    return graph[c].contains(c - 1) && graph[c].contains(c + 1)
        ? MazeWall(
            p + Vector3(-thickness / 2, 0, -cell / 2),
            p + Vector3(thickness / 2, .17, cell / 2),
          )
        : MazeWall(
            p + Vector3(-cell / 2, 0, -thickness / 2),
            p + Vector3(cell / 2, .17, thickness / 2),
          );
  }

  final Map<int, List<MazeWall>> _wallGrid = {};
  List<MazeWall> wallsNear(Vector3 p) =>
      _wallGrid[((p.x + span / 2) / cell).floor() * 4096 +
          ((p.z + span / 2) / cell).floor()] ??
      const [];
  Vector3 center(int c) => Vector3(
    (c % size + .5) * cell - span / 2,
    0,
    (c ~/ size + .5) * cell - span / 2,
  );
  int cellAt(Vector3 p) =>
      ((p.z + span / 2) / cell).floor().clamp(0, size - 1) * size +
      ((p.x + span / 2) / cell).floor().clamp(0, size - 1);
  MazeWall _vertical(int x, int z) => MazeWall(
    Vector3(
      x * cell - span / 2 - thickness / 2,
      0,
      z * cell - span / 2 - thickness / 2,
    ),
    Vector3(
      x * cell - span / 2 + thickness / 2,
      .17,
      (z + 1) * cell - span / 2 + thickness / 2,
    ),
  );
  MazeWall _horizontal(int x, int z) => MazeWall(
    Vector3(
      x * cell - span / 2 - thickness / 2,
      0,
      z * cell - span / 2 - thickness / 2,
    ),
    Vector3(
      (x + 1) * cell - span / 2 + thickness / 2,
      .17,
      z * cell - span / 2 + thickness / 2,
    ),
  );
  Map<int, int> distanceMap(int start) {
    final distances = <int, int>{start: 0}, queue = <int>[start];
    for (int at = 0; at < queue.length; at++) {
      final c = queue[at];
      for (final n in graph[c]) {
        if (!distances.containsKey(n)) {
          distances[n] = distances[c]! + 1;
          queue.add(n);
        }
      }
    }
    return distances;
  }

  List<int> route(int start, int end) {
    final parents = <int, int>{start: -1}, queue = <int>[start];
    for (int at = 0; at < queue.length && !parents.containsKey(end); at++) {
      for (final n in graph[queue[at]]) {
        if (!parents.containsKey(n)) {
          parents[n] = queue[at];
          queue.add(n);
        }
      }
    }
    final path = <int>[];
    for (int c = end; c != -1; c = parents[c]!) {
      path.add(c);
    }
    return path.reversed.toList();
  }
}

class PuzzleDoor {
  final int cell;
  final String kind;
  final MazeWall wall;
  PuzzleDoor(this.cell, this.kind, this.wall);
  bool open({
    required int keyMask,
    required bool plate,
    required int sequence,
    required bool orbital,
    required int switches,
  }) {
    switch (kind) {
      case 'A':
        return keyMask & 1 != 0;
      case 'B':
        return keyMask & 2 != 0;
      case 'C':
        return keyMask & 4 != 0;
      case 'D':
        return plate;
      case 'Q':
        return sequence >= 3;
      case 'N':
        return orbital;
      case 'X':
        return (switches & 1 != 0) != (switches & 2 != 0);
      case 'Y':
        return (switches & 2 != 0) != (switches & 4 != 0);
      case 'Z':
        return switches & 5 == 5;
      default:
        return true;
    }
  }
}
