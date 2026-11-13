import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'levels.dart';
import 'maze.dart';

class Simulation {
  static const dt = 1 / 240, radius = .085;
  // Collider only: a transparent lid leaves 8 mm of clearance over the marble.
  static const invisibleCoverHeight = radius * 2 + .008;
  static const maximumAngularSpeed = 8.0;
  // World-unit scale remains unchanged. This cap only catches numerical spikes.
  static const gravity = 3.2, maximumRelativeSpeed = 4.5;
  Level level;
  final bool useSpatialIndex;
  Vector3 position = Vector3.zero(),
      velocity = Vector3.zero(),
      angular = Vector3.zero(),
      spinInput = Vector3.zero();
  Quaternion orientation = Quaternion.identity(), roll = Quaternion.identity();
  final Set<int> explored = {}, visible = {};
  Vector3? _lastSafeBoardPoint;
  int _safeBoardRoom = -1;
  int revealCell = -1, switchMask = 0, savedSwitches = 0;
  bool orbitalUnlocked = false, orbitalHalfTurn = false, savedOrbital = false;
  int get keyMask {
    int mask = 0;
    final m = activeLevel.maze;
    if (m != null) {
      for (int i = 0; i < m.keys.length; i++) {
        if (collected.contains(1000 + i)) mask |= 1 << i;
      }
    }
    return mask;
  }

  bool doorOpen(PuzzleDoor d) => d.open(
    keyMask: keyMask,
    plate: pressureActive,
    sequence: sequenceProgress,
    orbital: orbitalUnlocked,
    switches: switchMask,
  );
  int roomIndex = 0,
      savedRoomIndex = 0,
      sequenceProgress = 0,
      savedSequence = 0;
  bool pressureActive = false, savedPressure = false, gyroLocked = false;
  double savedPadHold = 0, savedCharge = 0;
  int savedHeldPad = -1, savedLastPad = -1;
  double padHold = 0;
  int heldPad = -1, lastPad = -1;
  Vector3 gyroStartUp = Vector3(0, 1, 0);
  Level get activeLevel => level.rooms.isEmpty ? level : level.rooms[roomIndex];
  int get roomCount => level.rooms.isEmpty ? 1 : level.rooms.length;
  bool get finalRoom => roomIndex == roomCount - 1;
  String get roomLabel => activeLevel.maze != null
      ? (activeLevel.maze!.authored ? 'RETO DE LÓGICA' : 'LABERINTO 21 × 21')
      : 'CÁMARA ${roomIndex + 1} / $roomCount · ${activeLevel.roomTitle}';
  int get goldSeconds => activeLevel.maze != null ? 600 : roomCount * 60;
  bool get portalReady {
    if (activeLevel.maze != null) {
      final m = activeLevel.maze!;
      return tokens >= m.keys.length &&
          (m.plate < 0 || pressureActive) &&
          (m.sequencePads.isEmpty || sequenceProgress >= 3) &&
          (m.orbital < 0 || orbitalUnlocked) &&
          (m.toggles.isEmpty || switchMask == m.targetMask) &&
          (!m.brakeGoal ||
              relativeSpeed(orientation.conjugated().rotated(position)) < .25);
    }
    switch (activeLevel.rule) {
      case 'pressure':
        return pressureActive;
      case 'keys':
        return tokens >= 2;
      case 'sequence':
        return sequenceProgress >= 3;
      case 'brake':
        return relativeSpeed(orientation.conjugated().rotated(position)) < .35;
      case 'gimbal':
        return false;
      default:
        return level.rooms.isNotEmpty || level.id != 12 || tokens >= 2;
    }
  }

  String get instruction {
    final m = activeLevel.maze;
    if (m == null) return activeLevel.hint;
    final parts = <String>[];
    if (m.keys.isNotEmpty) parts.add('Llaves $tokens/${m.keys.length}');
    if (m.plate >= 0) {
      parts.add('Placa ${pressureActive ? 'activa' : 'pendiente'}');
    }
    if (m.sequencePads.isNotEmpty) {
      parts.add(
        'Orden ${m.sequenceOrder.map((x) => x + 1).join('→')}: $sequenceProgress/3',
      );
    }
    if (m.orbital >= 0) {
      parts.add(
        orbitalUnlocked
            ? 'Giro completado'
            : gyroLocked
            ? (orbitalHalfTurn
                  ? 'Vuelve a dejarlo boca arriba'
                  : 'Invierte la esfera 180°')
            : 'Busca la cápsula O',
      );
    }
    if (m.toggles.isNotEmpty) {
      parts.add(
        'X${switchMask & 1 != 0 ? '●' : '○'} Y${switchMask & 2 != 0 ? '●' : '○'} Z${switchMask & 4 != 0 ? '●' : '○'} · objetivo X● Y○ Z●',
      );
    }
    return '${parts.join(' · ')}\n${activeLevel.hint}';
  }

  final Vector3 pendingRotation = Vector3.zero();
  double elapsedTime = 0;
  void rotateBy(Vector3 radians) {
    pendingRotation.add(radians);
  }

  double time = 0, accumulator = 0, charge = 0;
  int checkpoint = 0, tokens = 0, falls = 0;
  bool won = false, contact = false;
  final Set<int> collected = {};
  late Vector3 savedPosition;
  late Quaternion savedOrientation;
  double savedTime = 0;
  Set<int> savedTokens = {};
  String event = '';
  int trackIndex = 0, savedTrackIndex = 0;
  Simulation(this.level, {this.useSpatialIndex = true}) {
    reset();
  }
  void reset() {
    _lastSafeBoardPoint = null;
    _safeBoardRoom = -1;
    explored.clear();
    visible.clear();
    revealCell = -1;
    switchMask = 0;
    orbitalUnlocked = false;
    orbitalHalfTurn = false;
    roomIndex = 0;
    pressureActive = false;
    sequenceProgress = 0;
    gyroLocked = false;
    padHold = 0;
    lastPad = -1;
    orientation = Quaternion.identity();
    pendingRotation.setZero();
    time = 0;
    elapsedTime = 0;
    checkpoint = 0;
    tokens = 0;
    collected.clear();
    falls = 0;
    won = false;
    charge = 0;
    position = activeLevel.start;
    if (activeLevel.maze != null) {
      _lastSafeBoardPoint =
          activeLevel.maze!.center(activeLevel.maze!.start) +
          Vector3(0, radius, 0);
      _safeBoardRoom = roomIndex;
    }
    velocity = Vector3.zero();
    angular = Vector3.zero();
    spinInput = Vector3.zero();
    accumulator = 0;
    _reveal(orientation.conjugated().rotated(position));
    save();
  }

  void save() {
    savedSwitches = switchMask;
    savedOrbital = orbitalUnlocked;
    savedTrackIndex = trackIndex;
    savedPadHold = padHold;
    savedCharge = charge;
    savedHeldPad = heldPad;
    savedLastPad = lastPad;
    savedRoomIndex = roomIndex;
    savedPressure = pressureActive;
    savedSequence = sequenceProgress;
    savedPosition = position.clone();
    savedOrientation = orientation.clone();
    savedTime = time;
    savedTokens = Set.of(collected);
  }

  void recover() {
    switchMask = savedSwitches;
    orbitalUnlocked = savedOrbital;
    orbitalHalfTurn = false;
    revealCell = -1;
    trackIndex = savedTrackIndex;
    roomIndex = savedRoomIndex;
    pressureActive = savedPressure;
    sequenceProgress = savedSequence;
    gyroLocked = false;
    padHold = savedPadHold;
    heldPad = savedHeldPad;
    lastPad = savedLastPad;
    position = savedPosition.clone();
    orientation = savedOrientation.clone();
    time = savedTime;
    collected
      ..clear()
      ..addAll(savedTokens);
    tokens = collected.length;
    velocity.setZero();
    angular.setZero();
    spinInput.setZero();
    pendingRotation.setZero();
    charge = savedCharge;
    falls++;
    event = 'fall';
  }

  void advance(double elapsed) {
    accumulator += elapsed.clamp(0, .25);
    while (accumulator >= dt) {
      step();
      accumulator -= dt;
    }
  }

  double phase(Track t) =>
      .5 + .5 * math.sin(time * 1.8 * activeLevel.mechanismRate + t.index * .4);
  // The route remains a continuous bridge. Lift motion is a mechanism cue,
  // rather than translating a single floor tile away from its neighbours.
  Vector3 offset(Track t) => Vector3.zero();
  double relativeSpeed(Vector3 localPoint) =>
      (velocity - surfaceVelocity(localPoint)).length;
  Vector3 surfaceVelocity(Vector3 toyPoint) {
    final actualOmega = orientation.rotated(angular) * -1;
    return actualOmega.cross(orientation.rotated(toyPoint));
  }

  void step() {
    final requested = (spinInput + pendingRotation * 22).length.clamp(
      0.0,
      maximumAngularSpeed,
    );
    final count =
        (math.max(angular.length, requested) *
                activeLevel.radius *
                dt /
                (radius * .35))
            .ceil()
            .clamp(1, 8);
    for (int i = 0; i < count; i++) {
      _step(dt / count);
    }
  }

  void _step(double h) {
    if (won) return;
    time += h;
    elapsedTime += h;
    final requested = spinInput + pendingRotation * 22;
    if (requested.length > maximumAngularSpeed) {
      requested.scale(maximumAngularSpeed / requested.length);
    }
    angular +=
        (requested - angular) *
        (1 - math.pow(.9, h / Simulation.dt).toDouble());
    final consumed = pendingRotation * (22 * h);
    if (consumed.length > maximumAngularSpeed * h) {
      consumed.scale(maximumAngularSpeed * h / consumed.length);
    }
    pendingRotation.sub(consumed);
    final speed = angular.length;
    if (speed > .00001) {
      orientation =
          Quaternion.axisAngle(angular.normalized(), speed * h) * orientation;
      orientation.normalize();
    }
    if (gyroLocked) {
      final m = activeLevel.maze;
      final anchor = m != null
          ? m.center(m.orbital) + Vector3(0, radius, 0)
          : activeLevel.exit + activeLevel.tracks.last.normal * radius;
      position = orientation.rotated(anchor);
      velocity = surfaceVelocity(anchor);
      contact = true;
      final alignment = orientation.rotated(Vector3(0, 1, 0)).dot(gyroStartUp);
      if (m != null) {
        if (alignment < -.82) orbitalHalfTurn = true;
        if (orbitalHalfTurn && alignment > .96 && angular.length < .25) {
          orbitalUnlocked = true;
          gyroLocked = false;
          save();
          event = 'checkpoint';
        }
        _reveal(anchor);
      } else if (alignment < -.82) {
        _nextRoom();
      }
      return;
    }
    _retainMarble(checkRoute: false);
    final old = position.clone();
    velocity.y -= gravity * h;
    position += velocity * h;
    contact = false;
    // Solve sphere versus oriented track plane and its rails in toy coordinates.
    final inverse = orientation.conjugated();
    final local = inverse.rotated(position);
    int support = -1;
    double nearest = double.infinity;
    Vector3? supportPoint, supportNormal;
    const margin = radius + .025;
    final candidates = useSpatialIndex
        ? activeLevel.collisionCandidates(local)
        : List<int>.generate(activeLevel.tracks.length, (i) => i);
    for (final i in candidates) {
      final t = activeLevel.tracks[i];
      if (local.x < t.boundsMin.x - margin ||
          local.x > t.boundsMax.x + margin ||
          local.y < t.boundsMin.y - margin ||
          local.y > t.boundsMax.y + margin ||
          local.z < t.boundsMin.z - margin ||
          local.z > t.boundsMax.z + margin) {
        continue;
      }
      for (final tri in t.triangles) {
        final point = tri.closest(local);
        final distance = point.distanceToSquared(local);
        if (distance < nearest &&
            distance <= margin * margin &&
            (local - point).dot(tri.normal) >= -.015) {
          nearest = distance;
          support = i;
          supportPoint = point;
          supportNormal = tri.normal;
        }
      }
    }
    if (support >= 0) {
      final i = support, t = activeLevel.tracks[i], a = t.a;
      final tangent = t.tangent, side = t.side, normal = supportNormal!;
      final u = (supportPoint! - a).dot(tangent), length = t.length;
      final height = (local - supportPoint).dot(normal);
      final lateral = (local - a).dot(side);
      final n = orientation.rotated(normal);
      final surface = surfaceVelocity(supportPoint);

      if (t.mechanism == 'belt') {
        surface.add(orientation.rotated(tangent * .38));
      }
      final board = activeLevel.maze, cell = board?.cellAt(local);
      if (board != null && board.belts.contains(cell)) {
        surface.add(
          orientation.rotated(
            board.beltDirections[cell]! * (pressureActive ? -.45 : .45),
          ),
        );
      }
      var relative = velocity - surface;
      final vn = relative.dot(n);
      final touching = height <= radius + .00001;
      if (height < radius) position += n * (radius - height);
      if (touching && vn < 0) velocity -= n * (vn * 1.08);
      if (touching && board != null) {
        final ice = board.ice.contains(cell);
        final belt = board.belts.contains(cell);
        final g = Vector3(0, -gravity, 0);
        final load = math.max(0.0, -g.dot(n));
        // A solid sphere shares acceleration between translation and rotation:
        // a = 5/7 g_parallel. Ice permits sliding instead of enforcing rolling.
        if (!ice) velocity -= (g - n * g.dot(n)) * (2 / 7 * h);
        relative = velocity - surface;
        final tangentVelocity = relative - n * relative.dot(n);
        final speed = tangentVelocity.length;
        final resistance = (ice ? .002 : .025) * load * h;
        if (speed > 0) {
          velocity -= tangentVelocity * (math.min(speed, resistance) / speed);
        }
        // Belts exchange momentum with their moving surface, not an idle brake.
        if (belt) velocity -= tangentVelocity * (1 - math.exp(-2.8 * h));
      } else if (touching) {
        final drag = t.material == 'ice'
            ? .035
            : t.material == 'rubber'
            ? 4.0
            : .28;
        relative = velocity - surface;
        velocity -= (relative - n * relative.dot(n)) * drag * h;
      }
      if (t.rails) {
        // Resolve against the same shared edge segments that draw the rails.
        // An infinite centre-line clamp catches the marble on tiny curve pieces.
        for (final wall in t.walls) {
          final lp = inverse.rotated(position);
          final along = (lp - wall.a).dot(wall.direction);
          if (along < -.002 || along > wall.length + .002) continue;
          final distance = (lp - wall.a).dot(wall.inward);
          if (distance < radius && distance > -.10) {
            final inward = orientation.rotated(wall.inward);
            position += inward * (radius - distance);
            final outward = (velocity - surface).dot(inward);
            if (outward < 0) velocity -= inward * outward;
          }
        }
      }
      contact = true;
      trackIndex = i;
      final tangentWorld = orientation.rotated(tangent);
      if ((t.mechanism == 'gate' || t.mechanism == 'gear') &&
          phase(t) < .57 &&
          u > length * .35) {
        position -= tangentWorld * .012;
        final v = velocity.dot(tangentWorld);
        if (v > 0) velocity -= tangentWorld * v;
      }
      if (t.mechanism == 'pendulum' && phase(t) > .8) {
        velocity += orientation.rotated(side) * h * 2;
      }
      if (t.mechanism == 'attract') {
        velocity += orientation.rotated(side) * (-lateral * 8 * h);
      }
      if (t.mechanism == 'repel') velocity += tangentWorld * h * .8;
      if (t.mechanism == 'spring') {
        charge += h;
        if (charge > .4) {
          velocity += n * .8 + tangentWorld * .7;
          charge = 0;
          event = 'spring';
        }
      }
      if (t.mechanism == 'token' && collected.add(i)) {
        tokens = collected.length;
        event = 'token';
      }
      if (level.rooms.isEmpty &&
          (t.mechanism == 'plate' || t.mechanism == 'counterweight')) {
        if (velocity.length < .3) charge = (charge + h).clamp(0, 2);
      }
      if (i > checkpoint + 8 && i < activeLevel.tracks.length - 4) {
        checkpoint = i;
        save();
        event = 'checkpoint';
      }
    }
    for (final t in activeLevel.tracks.where((t) => t.mechanism == 'token')) {
      if (local.distanceTo(t.center + Vector3(0, radius, 0)) < .20 &&
          collected.add(t.index)) {
        tokens = collected.length;
        event = 'token';
      }
    }
    final currentLocal = inverse.rotated(position);
    if (activeLevel.maze != null) {
      _mazeStep(currentLocal, h);
    } else if (level.rooms.isNotEmpty) {
      _roomRules(currentLocal, h);
    }
    final delta = position - old;
    if (delta.length > .000001) {
      roll =
          Quaternion.axisAngle(
            Vector3(0, 1, 0).cross(delta).normalized(),
            delta.length / radius,
          ) *
          roll;
      roll.normalize();
    }
    final exit = orientation.rotated(activeLevel.exit);
    if (position.distanceTo(exit) < (activeLevel.maze != null ? .13 : .24)) {
      if (activeLevel.rule == 'gimbal') {
        gyroLocked = true;
        gyroStartUp = orientation.rotated(Vector3(0, 1, 0));
        save();
        event = 'checkpoint';
      } else if (portalReady) {
        if (!finalRoom) {
          _nextRoom();
        } else {
          won = true;
          event = 'win';
        }
      }
    }
    if (!portalReady &&
        activeLevel.maze == null &&
        activeLevel.rule != 'brake' &&
        !gyroLocked) {
      final end = activeLevel.tracks.last, lp = inverse.rotated(position);
      final beyond = (lp - end.b).dot(end.tangent);
      if (beyond > -radius && lp.distanceTo(end.b) < .5) {
        final forward = orientation.rotated(end.tangent);
        position -= forward * (beyond + radius);
        final v = velocity.dot(forward);
        if (v > 0) velocity -= forward * v;
      }
    }
    if (position.length > activeLevel.radius * 1.325) recover();
  }

  void restartRoom() {
    final index = roomIndex, attempts = falls;
    final elapsed = elapsedTime;
    reset();
    roomIndex = index;
    falls = attempts;
    elapsedTime = elapsed;
    position = activeLevel.start;
    save();
  }

  void _nextRoom() {
    roomIndex++;
    orientation = Quaternion.identity();
    position = activeLevel.start;
    velocity.setZero();
    angular.setZero();
    spinInput.setZero();
    pendingRotation.setZero();
    time = 0;
    charge = 0;
    checkpoint = 0;
    trackIndex = 0;
    collected.clear();
    tokens = 0;
    pressureActive = false;
    sequenceProgress = 0;
    gyroLocked = false;
    padHold = 0;
    heldPad = -1;
    lastPad = -1;
    save();
    event = 'room';
  }

  void _roomRules(Vector3 local, double h) {
    if (activeLevel.rule == 'pressure' && !pressureActive) {
      final pad = activeLevel.tracks.firstWhere((t) => t.mechanism == 'plate');
      if (local.distanceTo(pad.center + Vector3(0, radius, 0)) < .22 &&
          relativeSpeed(local) < .16) {
        charge += h;
        if (charge >= 1) {
          pressureActive = true;
          save();
          event = 'checkpoint';
        }
      }
    }
    if (activeLevel.rule == 'sequence' && sequenceProgress < 3) {
      int pad = -1;
      for (final t in activeLevel.tracks) {
        if (t.mechanism.startsWith('sequence') &&
            local.distanceTo(t.center + Vector3(0, radius, 0)) < .17) {
          pad = int.parse(t.mechanism.substring(8));
          break;
        }
      }
      if (pad != heldPad) {
        heldPad = pad;
        padHold = 0;
      }
      if (pad < 0) {
        lastPad = -1;
      } else if (relativeSpeed(local) < .16) {
        padHold += h;
        if (padHold > .35 && lastPad != pad) {
          lastPad = pad;
          final order = activeLevel.sequenceOrder;
          if (!order.take(sequenceProgress).contains(pad)) {
            sequenceProgress = order[sequenceProgress] == pad
                ? sequenceProgress + 1
                : 0;
          }
          save();
          event = 'checkpoint';
        }
      }
    }
  }

  void _wall(MazeWall wall) {
    final inverse = orientation.conjugated(), p = inverse.rotated(position);
    if (p.y > wall.max.y + radius || p.y < wall.min.y - radius) return;
    final x = p.x.clamp(wall.min.x, wall.max.x),
        z = p.z.clamp(wall.min.z, wall.max.z);
    final dx = p.x - x, dz = p.z - z, d2 = dx * dx + dz * dz;
    if (d2 >= radius * radius) return;
    late Vector3 normal;
    late double penetration;
    if (d2 > 1e-12) {
      final d = math.sqrt(d2);
      normal = Vector3(dx / d, 0, dz / d);
      penetration = radius - d;
    } else {
      final distances = [
        p.x - wall.min.x,
        wall.max.x - p.x,
        p.z - wall.min.z,
        wall.max.z - p.z,
      ];
      int side = 0;
      for (int i = 1; i < 4; i++) {
        if (distances[i] < distances[side]) side = i;
      }
      normal = [
        Vector3(-1, 0, 0),
        Vector3(1, 0, 0),
        Vector3(0, 0, -1),
        Vector3(0, 0, 1),
      ][side];
      penetration = radius + distances[side];
    }
    final worldNormal = orientation.rotated(normal);
    position += worldNormal * penetration;
    final relative = velocity - surfaceVelocity(p),
        v = relative.dot(worldNormal);
    if (v < 0) velocity -= worldNormal * v;
  }

  void _mazeStep(Vector3 local, double h) {
    final maze = activeLevel.maze!;
    for (int iteration = 0; iteration < 3; iteration++) {
      final p = orientation.conjugated().rotated(position);
      for (final wall in maze.wallsNear(p)) {
        _wall(wall);
      }
      for (final gate in maze.gates) {
        if (gate.isClosed(time)) _wall(gate.wall);
      }
      for (final door in maze.doors) {
        if (!doorOpen(door)) _wall(door.wall);
      }
    }
    _retainMarble(checkRoute: true);
    final p = orientation.conjugated().rotated(position), cell = maze.cellAt(p);
    for (int i = 0; i < maze.keys.length; i++) {
      if (p.distanceTo(maze.center(maze.keys[i]) + Vector3(0, radius, 0)) <
              .15 &&
          collected.add(1000 + i)) {
        tokens = collected.length;
        save();
        event = 'token';
      }
    }
    if (maze.plate >= 0 &&
        !pressureActive &&
        p.distanceTo(maze.center(maze.plate) + Vector3(0, radius, 0)) < .14 &&
        relativeSpeed(local) < .16) {
      charge += h;
      if (charge >= 1) {
        pressureActive = true;
        save();
        event = 'checkpoint';
      }
    }
    final pad = maze.sequencePads[cell],
        toggle = maze.toggles[cell],
        padId = pad ?? (toggle != null ? 10 + toggle : -1);
    if (padId != heldPad) {
      heldPad = padId;
      padHold = 0;
    }
    if (padId < 0) {
      lastPad = -1;
    } else if (relativeSpeed(p) < .16) {
      padHold += h;
      if (padHold > .45 && lastPad != padId) {
        lastPad = padId;
        if (toggle != null) {
          switchMask ^= 1 << toggle;
        } else if (sequenceProgress < 3 &&
            !maze.sequenceOrder.take(sequenceProgress).contains(pad)) {
          sequenceProgress = maze.sequenceOrder[sequenceProgress] == pad
              ? sequenceProgress + 1
              : 0;
        }
        save();
        event = 'checkpoint';
      }
    }
    if (maze.orbital >= 0 &&
        !orbitalUnlocked &&
        p.distanceTo(maze.center(maze.orbital) + Vector3(0, radius, 0)) < .13) {
      gyroLocked = true;
      orbitalHalfTurn = false;
      gyroStartUp = orientation.rotated(Vector3(0, 1, 0));
      save();
      event = 'checkpoint';
    }
    for (final cell in maze.magnets) {
      final delta = maze.center(cell) + Vector3(0, radius, 0) - p;
      if (delta.length < .45) {
        velocity += orientation.rotated(delta * (pressureActive ? -2 : 2)) * h;
      }
    }
    _retainMarble(checkRoute: false);
    _reveal(p);
  }

  // Invisible floor/cover colliders retain the marble below the wall tops.
  // They rotate with the toy; no additional visual mesh is drawn.
  void _retainMarble({required bool checkRoute}) {
    final maze = activeLevel.maze;
    if (maze == null || gyroLocked) return;
    final inverse = orientation.conjugated();
    final local = inverse.rotated(position);
    final hitFloor = local.y <= radius,
        hitCover = local.y >= invisibleCoverHeight - radius;
    local.y = local.y.clamp(radius, invisibleCoverHeight - radius);
    if (_lastSafeBoardPoint == null || _safeBoardRoom != roomIndex) {
      _lastSafeBoardPoint = maze.center(maze.start) + Vector3(0, radius, 0);
      _safeBoardRoom = roomIndex;
    }
    if (checkRoute) {
      final cell = maze.cellAt(local);
      final outside =
          local.x.abs() > maze.extent / 2 - radius * .5 ||
          local.z.abs() > maze.extent / 2 - radius * .5;
      if (outside || !maze.openCells.contains(cell)) {
        local.setFrom(_lastSafeBoardPoint!);
        angular.setZero();
        spinInput.setZero();
        pendingRotation.setZero();
        velocity.setZero();
        falls++;
        event = 'fall';
        revealCell = -1;
      } else {
        final center = maze.center(cell) + Vector3(0, radius, 0);
        final isDoor =
            maze.doors.any((d) => d.cell == cell) ||
            maze.gates.any(
              (g) => maze.cellAt((g.wall.min + g.wall.max) * .5) == cell,
            );
        if (!isDoor && local.distanceTo(center) < .04) {
          _lastSafeBoardPoint = center;
        }
      }
    }
    position = orientation.rotated(local);
    final surface = surfaceVelocity(local);
    final relative = inverse.rotated(velocity - surface);
    if ((hitFloor && relative.y < 0) || (hitCover && relative.y > 0)) {
      relative.y = 0;
    }
    final planarSpeed = math.sqrt(
      relative.x * relative.x + relative.z * relative.z,
    );
    if (planarSpeed > maximumRelativeSpeed) {
      final factor = maximumRelativeSpeed / planarSpeed;
      relative.x *= factor;
      relative.z *= factor;
    }
    velocity = surface + orientation.rotated(relative);
  }

  void _reveal(Vector3 p) {
    final m = activeLevel.maze;
    if (m == null) return;
    final cell = m.cellAt(p);
    if (cell == revealCell) return;
    revealCell = cell;
    visible.clear();
    final depth = <int, int>{cell: 0}, queue = <int>[cell];
    for (int at = 0; at < queue.length; at++) {
      final c = queue[at];
      visible.add(c);
      if (depth[c]! >= 3) continue;
      for (final n in m.graph[c]) {
        if (!depth.containsKey(n)) {
          depth[n] = depth[c]! + 1;
          queue.add(n);
        }
      }
    }
    explored.addAll(visible);
  }
}
