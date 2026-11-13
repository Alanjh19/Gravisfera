import 'dart:async';

import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:audioplayers/audioplayers.dart';

import 'game/levels.dart';
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
  final levels = buildLevels();
  late Simulation sim;
  late Ticker ticker;
  final audio = AudioPlayer();
  String view = 'menu', stage = '';
  double last = 0, sequence = 0, zoom = 1, rotation = 0, visualTime = 0;
  bool saving = false;
  String tutorial = 'Inclina la esfera';
  bool tilted = false, rolled = false;
  int lastSound = -1;
  Progress get p => widget.progress;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sim = Simulation(levels.first);
    ticker = createTicker(tick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    audio.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && view == 'game') {
      setState(() => view = 'pause');
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
    final dt = (now - last).clamp(0.0, .05);
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
    setState(() {});
  }

  void start(int n) {
    sim = Simulation(levels[n - 1]);
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
      onPressed: action,
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
          ? -.95
          : k == LogicalKeyboardKey.arrowDown
          ? .95
          : 0,
      0,
      k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyQ
          ? .95
          : k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyE
          ? -.95
          : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = view == 'game';
    return KeyboardListener(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: key,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.15),
              radius: 1,
              colors: [Color(0xffffffff), Color(0xfff7f7f3), Color(0xffe7e9e5)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: 85),
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
                                Vector3(0, 0, d.rotation - rotation),
                              );
                              rotation = d.rotation;
                            } else {
                              sim.rotateBy(
                                Vector3(
                                  d.focalPointDelta.dy * .009 * p.sensitivity,
                                  0,
                                  -d.focalPointDelta.dx * .009 * p.sensitivity,
                                ),
                              );
                            }
                          },
                          onScaleEnd: (_) {},
                          child: CustomPaint(
                            painter: ToyPainter(
                              sim,
                              animationTime: visualTime,
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
                                  (stage == 'intro' && !p.flag('reduced', false)
                                      ? 0.05 * (1 - sequence / 1.5)
                                      : 0),
                              low: p.flag('low', false),
                            ),
                            child: const SizedBox.expand(),
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
                                  child: const Text('15 niveles'),
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
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${sim.elapsedTime.toStringAsFixed(1)} s',
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reiniciar',
                          onPressed: () => sim.reset(),
                          icon: const Icon(Icons.restart_alt),
                        ),
                        IconButton(
                          tooltip: 'Pausa',
                          onPressed: () => setState(() => view = 'pause'),
                          icon: const Icon(Icons.pause),
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
                              ? '${sim.level.hint}\nToca la esfera para comenzar'
                              : stage == 'victory'
                              ? 'Una órbita perfecta · toca para saltar'
                              : sim.level.id == 1
                              ? tutorial
                              : sim.level.hint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff506368),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Girar Q',
                              onPressed: () => sim.rotateBy(Vector3(0, 0, .18)),
                              icon: const Icon(Icons.rotate_left),
                            ),
                            Expanded(
                              child: Slider(
                                value: zoom,
                                min: .8,
                                max: 1.25,
                                label: 'Acercamiento',
                                onChanged: (v) => zoom = v,
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Girar E',
                              onPressed: () =>
                                  sim.rotateBy(Vector3(0, 0, -.18)),
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
                    button('Reiniciar nivel', () {
                      sim.reset();
                      view = 'game';
                      stage = '';
                    }),
                    button('Volver al selector', () => view = 'levels'),
                  ]),
                if (view == 'result')
                  panel(
                    sim.level.id == 15
                        ? 'El corazón es tuyo'
                        : 'Órbita completada',
                    [
                      Text(
                        '${sim.elapsedTime.toStringAsFixed(2)} segundos',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Medalla: ${sim.elapsedTime < 30
                            ? 'oro'
                            : sim.elapsedTime < 60
                            ? 'plata'
                            : 'bronce'} · Récord: ${(p.best(sim.level.id) ?? sim.elapsedTime).toStringAsFixed(2)} s',
                      ),
                      const SizedBox(height: 16),
                      button(
                        sim.level.id < 15
                            ? 'Siguiente nivel'
                            : 'Volver al selector',
                        () {
                          if (sim.level.id < 15) {
                            start(sim.level.id + 1);
                          } else {
                            view = 'levels';
                          }
                        },
                        primary: true,
                      ),
                      button('Repetir nivel', () => start(sim.level.id)),
                      button('Selector', () => view = 'levels'),
                    ],
                  ),
                if (view == 'levels')
                  panel('Quince pequeñas órbitas', [
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
                              ? 'Sin récord'
                              : '${p.best(l.id)!.toStringAsFixed(2)} s',
                        ),
                        trailing: Icon(
                          l.id <= p.unlocked
                              ? Icons.arrow_forward
                              : Icons.lock_outline,
                        ),
                        enabled: l.id <= p.unlocked,
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
                          setState(() {});
                        },
                      ),
                    const Text('Sensibilidad'),
                    Slider(
                      value: p.sensitivity,
                      min: .3,
                      max: 3,
                      onChanged: (v) async {
                        await p.prefs.setDouble('sensitivityV2', v);
                        setState(() {});
                      },
                    ),
                    button('Volver', () => view = 'menu'),
                  ]),
                if (view == 'credits')
                  panel('Hecho de gravedad', [
                    const Text(
                      'GRAVISFERA\nGeometría, simulación y sonido generados localmente.\nFlutter · Dart · Material Icons\n\nArrastra para inclinar. Dos dedos o Q/E para girar. R reinicia. Esc pausa. Flechas para inclinar con teclado.',
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
