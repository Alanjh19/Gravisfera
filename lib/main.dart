import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:audioplayers/audioplayers.dart';

import 'game/campaign.dart';
import 'game/physics.dart';
import 'game/scene.dart';
import 'game/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = Progress(await SharedPreferences.getInstance());
  runApp(Gravisfera(progress: p));
}

class Gravisfera extends StatelessWidget {
  final Progress progress;
  const Gravisfera({super.key, required this.progress});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GRAVISFERA',
    theme: ThemeData(
      brightness: Brightness.light,
      fontFamily: 'sans',
      scaffoldBackgroundColor: const Color(0xfff5f5f2),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff207a70),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
    home: GameScreen(progress: progress),
  );
}

class GameScreen extends StatefulWidget {
  final Progress progress;
  const GameScreen({super.key, required this.progress});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final levels = buildCampaign();
  late Simulation sim;
  late Ticker ticker;
  final audio = AudioPlayer();
  final music = AudioPlayer();
  late final Future<void> musicSetup;
  bool appIsActive = true, musicReady = false;
  String view = 'menu', stage = '';
  double last = 0, sequence = 0, zoom = 1, rotation = 0, visualTime = 0;
  bool saving = false, followMarble = false;
  final cameraFocus = Vector3.zero();
  String tutorial = 'Inclina la esfera';
  bool tilted = false, rolled = false;
  int lastSound = -1;
  final sceneFrames = ValueNotifier<int>(0);
  double uiElapsed = 0;
  String previousView = '', previousStage = '', previousTutorial = '';
  Progress get p => widget.progress;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sim = Simulation(levels.first);
    musicSetup = prepareMusic();
    ticker = createTicker(tick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    sceneFrames.dispose();
    audio.dispose();
    unawaited(music.dispose());
    focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appIsActive = state == AppLifecycleState.resumed;
    if (!appIsActive) {
      unawaited(pauseMusic());
      if (view == 'game') setState(() => view = 'pause');
    } else if (p.flag('music')) {
      unawaited(resumeMusic());
    }
  }

  Future<void> prepareMusic() async {
    try {
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(.16);
      await music.setSource(AssetSource('audio/ambient.wav'));
      musicReady = true;
      if (appIsActive && p.flag('music')) await music.resume();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    await musicSetup;
    if (musicReady && appIsActive && p.flag('music')) {
      try {
        await music.resume();
      } catch (_) {}
    }
  }

  Future<void> pauseMusic() async {
    try {
      await music.pause();
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool enabled) async {
    if (enabled) {
      await resumeMusic();
    } else {
      await pauseMusic();
    }
  }

  void sound(String name) {
    if (p.flag('effects')) {
      unawaited(audio.play(AssetSource('audio/$name.wav')));
    }
    if (p.flag('haptics')) HapticFeedback.lightImpact();
  }

  void tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - last).clamp(0.0, .25);
    last = now;
    if (!mounted) return;
    if (view == 'menu' || view == 'game') visualTime += dt;
    if (view == 'menu') {
      if (!p.flag('reduced', false)) {
        sim.spinInput = Vector3(.05, .09, .02);
        sim.advance(dt);
        if (sim.won) sim.reset();
      }
    }
    if (view == 'game') {
      if (stage.isNotEmpty) {
        sequence += dt;
        if (sequence >
            (p.flag('reduced', false)
                ? 0.2
                : stage == 'victory'
                ? 2
                : 1.5)) {
          if (stage == 'victory') {
            view = 'result';
          }
          stage = '';
          sequence = 0;
        }
      } else {
        sim.advance(dt);
        if (sim.velocity.length > .15) {
          rolled = true;
        }
        if (rolled && sim.velocity.length < .08) {
          tutorial = 'Busca el aro dorado de salida';
        } else if (rolled) {
          tutorial = 'Inclina al lado contrario para frenar';
        } else if (tilted) {
          tutorial = 'Deja que ruede';
        }
        if (sim.event == 'room') {
          stage = 'intro';
          sequence = 0;
        }
        if (sim.event.isNotEmpty) {
          sound(
            sim.event == 'win'
                ? 'win'
                : sim.event == 'fall'
                ? 'fall'
                : 'click',
          );
          sim.event = '';
        }
        if (sim.won && !saving) {
          saving = true;
          stage = 'victory';
          sequence = 0;
          unawaited(
            p.win(sim.level.id, sim.elapsedTime).then((_) {
              if (mounted) setState(() {});
            }),
          );
        }
      }
    }
    if (followMarble) {
      final delta = sim.position - cameraFocus;
      cameraFocus.add(delta * (1 - math.exp(-dt / .035)));
      final lag = sim.position - cameraFocus;
      if (p.flag('reduced', false)) {
        cameraFocus.setFrom(sim.position);
      } else if (lag.length > .18) {
        cameraFocus.setFrom(sim.position - lag.normalized() * .18);
      }
    }
    if (view == 'menu' || view == 'game') {
      sceneFrames.value++;
    }
    uiElapsed += dt;
    if (view != previousView ||
        stage != previousStage ||
        tutorial != previousTutorial ||
        (view == 'game' && uiElapsed >= .1)) {
      previousView = view;
      previousStage = stage;
      previousTutorial = tutorial;
      uiElapsed = 0;
      setState(() {});
    }
  }

  void start(int n) {
    sim = Simulation(levels[n - 1]);
    zoom = 1;
    followMarble = false;
    cameraFocus.setFrom(sim.position);
    saving = false;
    view = 'game';
    stage = 'intro';
    sequence = 0;
    tilted = false;
    rolled = false;
    tutorial = 'Inclina la esfera';
  }

  Widget button(
    String label,
    VoidCallback action, {
    bool primary = false,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: FilledButton.tonal(
      onPressed: () {
        action();
        setState(() {});
      },
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: primary
            ? const Color(0xffb5dbca)
            : const Color(0xffe8ece7),
        foregroundColor: primary
            ? const Color(0xff172b28)
            : const Color(0xff253c40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 10),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
  Widget panel(String title, List<Widget> children) => Center(
    child: _PanelReveal(
      key: ValueKey(title),
      reduced: p.flag('reduced', false),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xfffcfcf9).withValues(alpha: .97),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
  void key(KeyEvent e) {
    if (e is KeyUpEvent) {
      sim.spinInput.setZero();
      return;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape && view == 'game') {
      view = 'pause';
    }
    if (e.logicalKey == LogicalKeyboardKey.keyR) sim.reset();
    if (view != 'game' || stage.isNotEmpty) return;
    final k = e.logicalKey;
    sim.spinInput = Vector3(
      k == LogicalKeyboardKey.arrowUp
          ? -4.2
          : k == LogicalKeyboardKey.arrowDown
          ? 4.2
          : 0,
      0,
      k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyQ
          ? 4.2
          : k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyE
          ? -4.2
          : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = view == 'game';
    final dark = playing && (sim.activeLevel.maze?.darkness ?? false);
    return KeyboardListener(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: key,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.15),
              radius: 1,
              colors: dark
                  ? const [
                      Color(0xff13242e),
                      Color(0xff081119),
                      Color(0xff04090e),
                    ]
                  : const [
                      Color(0xffffffff),
                      Color(0xfff7f7f3),
                      Color(0xffe7e9e5),
                    ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      SizedBox(height: playing ? 105 : 85),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (playing && stage.isNotEmpty) {
                              if (stage == 'victory') view = 'result';
                              stage = '';
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: (d) {
                            rotation = 0;
                            if (view == 'game' && stage == 'intro') {
                              stage = '';
                              sequence = 0;
                            }
                          },
                          onScaleUpdate: (d) {
                            if (view != 'menu' &&
                                (!playing || stage.isNotEmpty)) {
                              return;
                            }
                            tilted = true;
                            if (d.pointerCount > 1) {
                              sim.rotateBy(
                                Vector3(
                                  0,
                                  0,
                                  (d.rotation - rotation) *
                                      (p.sensitivity / 3.5),
                                ),
                              );
                              rotation = d.rotation;
                            } else {
                              sim.rotateBy(
                                Vector3(
                                  d.focalPointDelta.dy * .018 * p.sensitivity,
                                  0,
                                  -d.focalPointDelta.dx * .018 * p.sensitivity,
                                ),
                              );
                            }
                          },
                          onScaleEnd: (_) {},
                          child: AnimatedBuilder(
                            animation: sceneFrames,
                            builder: (context, child) => RepaintBoundary(
                              child: CustomPaint(
                                painter: ToyPainter(
                                  sim,
                                  animationTime: visualTime,
                                  followMarble: followMarble,
                                  cameraTarget: cameraFocus.clone(),
                                  reduced: p.flag('reduced', false),
                                  cinema: stage == 'intro'
                                      ? (1 - sequence / 1.5).clamp(0.0, 1.0)
                                      : stage == 'victory'
                                      ? -sequence / 2
                                      : 0,
                                  victory: stage == 'victory',
                                  floating: view == 'menu',
                                  zoom:
                                      zoom +
                                      (stage == 'intro' &&
                                              !p.flag('reduced', false)
                                          ? 0.05 * (1 - sequence / 1.5)
                                          : 0),
                                  low: p.flag('low', false),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
                if (view == 'menu') ...[
                  const Positioned(
                    top: 22,
                    left: 24,
                    child: Text(
                      'OBJETOS IMPOSIBLES / 001',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: Color(0xff506368),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 64,
                    left: 24,
                    right: 24,
                    child: Column(
                      children: [
                        const FittedBox(
                          child: Text(
                            'GRAVISFERA',
                            style: TextStyle(
                              fontSize: 46,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Un pequeño mundo. Toda la gravedad.',
                          style: TextStyle(color: Color(0xff586d70)),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Proyecto de Alan Emir Jauregui Herrera',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: .3,
                            color: Color(0xff718184),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 24,
                    right: 24,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            button(
                              p.unlocked > 1
                                  ? 'Continuar · ${p.unlocked.toString().padLeft(2, '0')}'
                                  : 'Jugar',
                              () => start(p.unlocked),
                              primary: true,
                              icon: Icons.play_arrow_rounded,
                            ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => view = 'levels'),
                                  child: const Text('Seleccionar nivel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => view = 'settings'),
                                  child: const Text('Ajustes'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => view = 'credits'),
                                  child: const Text('Créditos'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (playing) ...[
                  Positioned(
                    top: 14,
                    left: 20,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NIVEL ${sim.level.id.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: Color(0xff276f66),
                                ),
                              ),
                              Text(
                                sim.level.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: dark ? Colors.white : null,
                                ),
                              ),
                              Text(
                                sim.roomLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: dark
                                      ? const Color(0xffa0ccc2)
                                      : const Color(0xff507777),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${sim.elapsedTime.toStringAsFixed(1)} s',
                          style: TextStyle(
                            color: dark ? Colors.white : null,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reiniciar',
                          onPressed: () => sim.reset(),
                          icon: Icon(
                            Icons.restart_alt,
                            color: dark ? Colors.white : null,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Pausa',
                          onPressed: () => setState(() => view = 'pause'),
                          icon: Icon(
                            Icons.pause,
                            color: dark ? Colors.white : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          stage == 'intro'
                              ? '${sim.instruction}\nToca la esfera para comenzar'
                              : stage == 'victory'
                              ? 'Una órbita perfecta · toca para saltar'
                              : sim.activeLevel.maze == null &&
                                    sim.level.id == 1
                              ? tutorial
                              : sim.instruction,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: dark
                                ? const Color(0xffc9e5df)
                                : const Color(0xff506368),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Girar Q',
                              onPressed: () => sim.rotateBy(Vector3(0, 0, .85)),
                              icon: const Icon(Icons.rotate_left),
                            ),
                            Expanded(
                              child: Slider(
                                value: zoom,
                                min: .8,
                                max: 4.5,
                                label: '${zoom.toStringAsFixed(1)}×',
                                onChanged: (v) => setState(() => zoom = v),
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: followMarble
                                  ? 'Ver esfera completa'
                                  : 'Enfocar y seguir canica',
                              isSelected: followMarble,
                              onPressed: () => setState(() {
                                followMarble = !followMarble;
                                cameraFocus.setFrom(sim.position);
                                zoom = followMarble ? 2.8 : 1;
                              }),
                              icon: const Icon(Icons.my_location),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Girar E',
                              onPressed: () =>
                                  sim.rotateBy(Vector3(0, 0, -.85)),
                              icon: const Icon(Icons.rotate_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (view == 'pause')
                  panel('Un respiro', [
                    button('Reanudar', () => view = 'game', primary: true),
                    button('Reglas y objetivo', () => view = 'rules'),
                    button('Reintentar cámara', () {
                      sim.restartRoom();
                      view = 'game';
                      stage = 'intro';
                      sequence = 0;
                    }),
                    button('Reiniciar nivel', () {
                      sim.reset();
                      view = 'game';
                      stage = '';
                    }),
                    button('Volver al selector', () => view = 'levels'),
                    button('Menú principal', () => view = 'menu'),
                  ]),
                if (view == 'rules')
                  panel('Reglas y objetivo', [
                    Text(sim.instruction),
                    const SizedBox(height: 16),
                    const Text(
                      'Azul: hielo, conserva el impulso. Naranja: cinta que empuja en el sentido de las flechas; la placa invierte su dirección. Las llaves abren puertas con su letra. Detente sobre placas y botones para activarlos. Las puertas temporizadas se abren en verde.',
                    ),
                    button('Volver a pausa', () => view = 'pause'),
                  ]),
                if (view == 'result')
                  panel(
                    sim.level.id == 16
                        ? 'El corazón es tuyo'
                        : 'Órbita completada',
                    [
                      Text(
                        '${sim.elapsedTime.toStringAsFixed(2)} segundos',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Medalla: ${sim.elapsedTime < sim.goldSeconds
                            ? 'oro'
                            : sim.elapsedTime < sim.goldSeconds * 2
                            ? 'plata'
                            : 'bronce'} · Récord: ${(p.best(sim.level.id) ?? sim.elapsedTime).toStringAsFixed(2)} s',
                      ),
                      const SizedBox(height: 16),
                      button(
                        sim.level.id < 16
                            ? 'Siguiente nivel'
                            : 'Volver al selector',
                        () {
                          if (sim.level.id < 16) {
                            start(sim.level.id + 1);
                          } else {
                            view = 'levels';
                          }
                        },
                        primary: true,
                      ),
                      button('Repetir nivel', () => start(sim.level.id)),
                      button('Selector', () => view = 'levels'),
                      button('Menú principal', () => view = 'menu'),
                    ],
                  ),
                if (view == 'levels')
                  panel('Niveles · acceso libre', [
                    const Text(
                      'Los 16 niveles están disponibles. Cada mapa tiene reglas distintas. El 16 es un laberinto de 441 celdas a oscuras.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ...levels.map(
                      (l) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 64,
                          height: 48,
                          child: CustomPaint(
                            painter: RouteThumbnail(Simulation(l)),
                          ),
                        ),
                        title: Text(
                          '${l.id.toString().padLeft(2, '0')} · ${l.name}',
                        ),
                        subtitle: Text(
                          p.best(l.id) == null
                              ? (l.maze != null
                                    ? (l.id == 16
                                          ? '441 celdas · exploración a oscuras'
                                          : 'Lógica · interruptores y rutas')
                                    : 'Reto de lógica · sin récord')
                              : '${p.best(l.id)!.toStringAsFixed(2)} s',
                        ),
                        trailing: Icon(
                          p.canPlay(l.id)
                              ? Icons.arrow_forward
                              : Icons.lock_outline,
                        ),
                        enabled: p.canPlay(l.id),
                        onTap: () => start(l.id),
                      ),
                    ),
                    button('Menú', () => view = 'menu'),
                  ]),
                if (view == 'settings')
                  panel('A tu ritmo', [
                    for (final setting in [
                      ('music', 'Música', true),
                      ('effects', 'Efectos', true),
                      ('haptics', 'Vibración', true),
                      ('reduced', 'Movimiento reducido', false),
                      ('low', 'Calidad gráfica baja', false),
                    ])
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(setting.$2),
                        value: p.flag(setting.$1, setting.$3),
                        onChanged: (v) async {
                          await p.toggle(setting.$1, v);
                          if (setting.$1 == 'music') {
                            await setMusicEnabled(v);
                          }
                          setState(() {});
                        },
                      ),
                    const Text('Sensibilidad'),
                    Slider(
                      value: p.sensitivity,
                      min: .3,
                      max: 14,
                      onChanged: (v) async {
                        await p.prefs.setDouble('sensitivityV4', v);
                        setState(() {});
                      },
                    ),
                    button('Volver', () => view = 'menu'),
                  ]),
                if (view == 'credits')
                  panel('Hecho de gravedad', [
                    const Text(
                      'GRAVISFERA\nProyecto de Alan Emir Jauregui Herrera.\nGeometría, simulación, música y efectos generados localmente.\nFlutter · Dart · Material Icons\n\nArrastra para inclinar. Dos dedos o Q/E para girar. R reinicia. Esc pausa. Flechas para inclinar con teclado.',
                    ),
                    button('Volver', () => view = 'menu'),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final FocusNode focus = FocusNode();
}

class _PanelReveal extends StatelessWidget {
  final Widget child;
  final bool reduced;
  const _PanelReveal({super.key, required this.child, required this.reduced});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: reduced ? 150 : 240),
    curve: Curves.easeOutCubic,
    builder: (context, value, _) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, reduced ? 0 : 8 * (1 - value)),
        child: child,
      ),
    ),
  );
}
