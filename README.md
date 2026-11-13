# GRAVISFERA
### Proyecto de laberinto 3D · Parcial 2

**Alumno:** Alan Emir Jauregui Herrera
**Tecnologías:** Flutter, Dart y Material 3

GRAVISFERA es un videojuego móvil en el que se inclina una esfera para guiar una canica por laberintos tridimensionales. La campaña tiene 16 niveles: 15 mapas de lógica diseñados para el proyecto y un laberinto generado de 21 × 21 celdas.

## Características

- Inicio, salida, paredes y rutas transitables con colisiones.
- 16 niveles con llaves, puertas, placas de presión, compuertas, hielo, cintas y secuencias.
- Nivel 10, **Memoria mecánica**, con exploración bajo niebla y orden de placas 3 → 1 → 2.
- Cronómetro, récord por nivel y preferencias guardadas localmente.
- Música ambiental, efectos de sonido, vibración y ajustes de accesibilidad.
- Pausa, reinicio, selector de niveles y regreso al menú principal.

## Controles

| Acción | Control |
| --- | --- |
| Inclinar el laberinto | Arrastrar con un dedo |
| Girar sobre el eje de visión | Gesto con dos dedos |
| Inclinar desde teclado | Flechas |
| Girar desde teclado | Q / E |
| Reiniciar | R |
| Pausar | Esc o botón de pausa |
| Acercar y seguir la canica | Deslizador y botón de enfoque |

## Requisitos

- Flutter con Dart 3.13.2 o posterior, de acuerdo con la restricción de `pubspec.yaml`.
- Android SDK configurado para compilar o ejecutar en Android.
- Para la versión web se requiere un navegador compatible con Flutter Web.

## Ejecutar

Desde la raíz del proyecto:

    flutter pub get
    flutter run -d android

Compilar Android:

    flutter build apk --release

Compilar la versión web optimizada:

    flutter build web --release --wasm --no-web-resources-cdn
    python3 tools/serve_web.py --port 8080

## Estructura

- lib/main.dart: menú, partida, controles, ajustes y navegación.
- lib/game/campaign.dart y logic_maps.dart: niveles y mapas de lógica.
- lib/game/maze.dart: celdas, paredes, llaves, puertas, placas y estados de exploración.
- lib/game/physics.dart: gravedad, movimiento y colisiones.
- lib/game/scene.dart: dibujo tridimensional y cámara.
- lib/game/storage.dart: récords y preferencias.
- assets/audio/: música y efectos de sonido.
- test/: pruebas de física, niveles, interacción, retención y renderizado.
- entrega/: informe PDF y capturas seleccionadas.

## Validación y alcance

Los informes técnicos registran conjuntos de pruebas dirigidas y un análisis sin incidencias. La suite completa todavía requiere adaptar test/maze_playthrough_test.dart a la campaña actual. Tampoco se ha validado el funcionamiento en un teléfono Android real. El APK histórico de entrega, si está presente localmente, no corresponde a la versión actual; compilar uno nuevo antes de distribuirlo.

Consulta VALIDATION.md, RESPUESTA_Y_CAMARA.md y RENDIMIENTO.md para los resultados y sus límites. Las licencias y recursos están en CREDITS.md.
