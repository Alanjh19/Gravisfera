import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'levels.dart';
import 'maze.dart';
import 'logic_maps.dart';

const roomRules = [
  'momentum',
  'pressure',
  'keys',
  'timing',
  'magnet',
  'gimbal',
  'sequence',
  'brake',
];
const roomNames = [
  'Entrada y control',
  'El interruptor',
  'Dos llaves',
  'Ventanas de paso',
  'Polaridad',
  'Cerradura orbital',
  'El orden importa',
  'Aterrizaje preciso',
];
List<Level> buildExtendedPrototype() {
  final levels = <Level>[];
  final pool = buildLevels();
  for (int n = 0; n < 15; n++) {
    final rooms = <Level>[];
    final middle = roomRules.sublist(1, 7);
    if (n > 0) middle.shuffle(math.Random(37 * (n + 1)));
    final rules = ['momentum', ...middle, 'brake'];
    const codes = [
      [1, 0, 2],
      [2, 0, 1],
      [1, 2, 0],
      [2, 1, 0],
    ];
    for (int room = 0; room < 8; room++) {
      final base = pool[(n + room * 4) % 15], rule = rules[room];
      final tracks = <Track>[];
      for (int i = 0; i < base.tracks.length; i++) {
        final t = base.tracks[i], f = i / (base.tracks.length - 1);
        String mechanism = '';
        bool at(double fraction) =>
            i == (base.tracks.length * fraction).floor();
        if (rule == 'pressure' && at(.48)) mechanism = 'plate';
        if (rule == 'keys' && (at(.28) || at(.68))) mechanism = 'token';
        if (rule == 'timing' && (at(.28) || at(.5) || at(.73))) {
          mechanism = 'gate';
        }
        if (rule == 'magnet' && at(.3)) mechanism = 'attract';
        if (rule == 'magnet' && at(.7)) mechanism = 'repel';
        if (rule == 'sequence') {
          for (int pad = 0; pad < 3; pad++) {
            if (at(.23 + pad * .22)) mechanism = 'sequence$pad';
          }
        }
        if (rule == 'momentum' && n > 3 && at(.6)) {
          mechanism = n.isEven ? 'pendulum' : 'gear';
        }
        final width = f > .88
            ? .55
            : (n < 3
                  ? .42
                  : n == 3
                  ? .23
                  : .34 - (n - 3) * .007);
        tracks.add(
          Track(
            t.a.clone(),
            t.b.clone(),
            width,
            rails: n != 3 || room != 0,
            material:
                (rule == 'magnet' || rule == 'timing') && f > .35 && f < .65
                ? 'ice'
                : rule == 'brake' && f > .8
                ? 'rubber'
                : 'metal',
            mechanism: mechanism,
          ),
        );
      }
      rooms.add(
        Level(
          n + 1,
          names[n],
          hints[n],
          tracks,
          rule: rule,
          roomTitle: roomNames[roomRules.indexOf(rule)],
          mechanismRate: 1 + n * .035,
          sequenceOrder: codes[n % codes.length],
        ),
      );
    }
    levels.add(
      Level(n + 1, names[n], hints[n], rooms.first.tracks, rooms: rooms),
    );
  }
  final maze = MazeData(160619);
  levels.add(
    Level(
      16,
      'El dédalo infinito',
      'Busca dos llaves y activa la placa. Cuatro puertas temporizadas, hielo y cintas complican la exploración.',
      [
        Track(
          Vector3(-MazeData.span / 2, 0, 0),
          Vector3(MazeData.span / 2, 0, 0),
          MazeData.span,
          rails: false,
        ),
      ],
      maze: maze,
      radius: 3.05,
      startOverride: maze.center(0) + Vector3(0, .14, 0),
      exitOverride: maze.center(maze.goal),
    ),
  );
  return levels;
}

List<Level> buildCampaign() {
  final result = <Level>[];
  for (int i = 0; i < logicMaps.length; i++) {
    final board = MazeData.authoredMap(
      logicMaps[i],
      fog: i >= 9,
      brake: i == 6,
      mask: i == 12 || i == 14 ? 5 : 0,
      code: const [
        [1, 0, 2],
        [2, 0, 1],
        [1, 2, 0],
        [2, 1, 0],
      ][i % 4],
    );
    final extent = board.extent;
    result.add(
      Level(
        i + 1,
        logicNames[i],
        logicHints[i],
        [
          Track(
            Vector3(-extent / 2, 0, 0),
            Vector3(extent / 2, 0, 0),
            extent,
            rails: false,
          ),
        ],
        maze: board,
        radius: math.max(2, extent * .76),
        startOverride: board.center(board.start) + Vector3(0, .14, 0),
        exitOverride: board.center(board.goal),
      ),
    );
  }
  final maze = MazeData(160619), extent = MazeData.span;
  result.add(
    Level(
      16,
      'El dédalo ciego',
      'Explora. Azul: hielo; naranja: cintas. Busca dos llaves y activa la placa.',
      [
        Track(
          Vector3(-extent / 2, 0, 0),
          Vector3(extent / 2, 0, 0),
          extent,
          rails: false,
        ),
      ],
      maze: maze,
      radius: extent * .76,
      startOverride: maze.center(maze.start) + Vector3(0, .14, 0),
      exitOverride: maze.center(maze.goal),
    ),
  );
  return result;
}
