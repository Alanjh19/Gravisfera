import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravisfera/game/campaign.dart';
import 'package:gravisfera/game/maze.dart';
import 'package:gravisfera/game/physics.dart';
import 'package:vector_math/vector_math_64.dart';

typedef State = (int, int, bool, int, bool, int);
List<State>? solve(MazeData m) {
  State normalize(State s) {
    int keys = s.$2;
    for (int i = 0; i < m.keys.length; i++) {
      if (m.keys[i] == s.$1) keys |= 1 << i;
    }
    return (
      s.$1,
      keys,
      s.$3 || s.$1 == m.plate,
      s.$4,
      s.$5 || s.$1 == m.orbital,
      s.$6,
    );
  }

  bool allowed(int c, State s) => m.doors
      .where((d) => d.cell == c)
      .every(
        (d) => d.open(
          keyMask: s.$2,
          plate: s.$3,
          sequence: s.$4,
          orbital: s.$5,
          switches: s.$6,
        ),
      );
  final initial = normalize((m.start, 0, false, 0, false, 0));
  final queue = Queue<State>()..add(initial),
      parents = <State, State?>{initial: null};
  while (queue.isNotEmpty) {
    final s = queue.removeFirst();
    if (s.$1 == m.goal &&
        s.$2 == (1 << m.keys.length) - 1 &&
        (m.plate < 0 || s.$3) &&
        (m.sequencePads.isEmpty || s.$4 == 3) &&
        (m.orbital < 0 || s.$5) &&
        (m.toggles.isEmpty || s.$6 == m.targetMask)) {
      final path = <State>[];
      for (State? v = s; v != null; v = parents[v]) {
        path.add(v);
      }
      return path.reversed.toList();
    }
    final next = <State>[];
    for (final n in m.graph[s.$1]) {
      if (allowed(n, s)) next.add(normalize((n, s.$2, s.$3, s.$4, s.$5, s.$6)));
    }
    if (m.sequencePads.containsKey(s.$1) && s.$4 < 3) {
      final pad = m.sequencePads[s.$1]!;
      final progress = m.sequenceOrder.take(s.$4).contains(pad)
          ? s.$4
          : m.sequenceOrder[s.$4] == pad
          ? s.$4 + 1
          : 0;
      next.add((s.$1, s.$2, s.$3, progress, s.$5, s.$6));
    }
    if (m.toggles.containsKey(s.$1)) {
      final toggled = (
        s.$1,
        s.$2,
        s.$3,
        s.$4,
        s.$5,
        s.$6 ^ (1 << m.toggles[s.$1]!),
      );
      if (m.graph[s.$1].any((c) => allowed(c, toggled))) next.add(toggled);
    }
    for (final n in next) {
      if (!parents.containsKey(n)) {
        parents[n] = s;
        queue.add(n);
      }
    }
  }
  return null;
}

void main() {
  test('Fifteen authored logic boards have valid stateful solutions, not just open paths', () {
    final campaign = buildCampaign();
    expect(campaign.length, 16);
    for (final l in campaign.take(15)) {
      final m = l.maze!, path = solve(m);
      expect(path, isNotNull, reason: 'Level ${l.id}: unsolvable logic');
      expect(path!.length, greaterThan(20), reason: 'Level ${l.id}');
      expect(m.distanceMap(m.start).length, m.openCells.length);
    }
  });
  test(
    'Airlock requires four switch operations and an actual return route',
    () {
      final m = buildCampaign()[12].maze!, path = solve(m)!;
      int toggles = 0;
      for (int i = 1; i < path.length; i++) {
        if (path[i].$6 != path[i - 1].$6) toggles++;
      }
      expect(toggles, greaterThanOrEqualTo(4));
    },
  );
  test('Flat boards do not progress automatically under neutral gravity', () {
    for (final l in buildCampaign().take(15)) {
      final s = Simulation(l);
      for (int i = 0; i < 240 * 4; i++) {
        s.step();
      }
      expect(s.won, false);
      expect(s.tokens, 0);
      expect(s.activeLevel.maze!.cellAt(s.position), s.activeLevel.maze!.start);
    }
  });
  test(
    'Fog conceals most of the 441-cell maze and reveals the traversed region',
    () {
      final s = Simulation(buildCampaign().last), m = s.activeLevel.maze!;
      expect(m.graph.length, 441);
      expect(s.visible.length, lessThan(20));
      expect(s.explored.contains(m.goal), false);
      final next = m.graph[m.start].first;
      s.position = m.center(next) + Vector3(0, Simulation.radius, 0);
      s.step();
      expect(s.explored.contains(m.start), true);
      expect(s.visible.contains(next), true);
    },
  );
}
