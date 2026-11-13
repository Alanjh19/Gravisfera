# Optimización sin reducción visual

Este registro técnico conserva mediciones de la revisión del renderer. La campaña actual contiene 16 laberintos; los resultados de CPU y las pruebas descritas aquí son mediciones de sus escenas de referencia, no FPS medidos en un teléfono Android.

Se mantienen todos los polígonos, subdivisiones, reflejos, sombras, transparencias y partículas de la calidad seleccionada. No se redujo la resolución ni se cambió el paso de física de 1/240 s.

Cambios:

- Mallas estáticas, aro ecuatorial, marcas grabadas y pinturas de materiales reutilizables. Los mecanismos siguen generándose con su estado real.
- Una matriz de orientación por cuadro; proyección numérica sin objetos temporales por vértice.
- Profundidad de cada cara calculada una vez antes de ordenar. Prueba de rectángulo antes de comprobar si una cara tapa la canica.
- Índice espacial de colisión conservador por celdas. Conserva el orden de las piezas candidatas y usa los mismos triángulos/contactos.
- La escena se repinta de manera independiente mediante un Listenable y RepaintBoundary. El HUD se actualiza a 10 Hz y las pantallas estáticas dejan de reconstruirse cada cuadro.
- Compilación web release con WebAssembly, fallback compatible y recursos de renderer locales. El servidor habilita aislamiento de origen para permitir los workers de WASM cuando el navegador lo admite.

Validación: diecisiete pruebas aprobadas, `flutter analyze` sin incidencias. Se compararon imágenes de alta calidad de los niveles 5, 10 y 15 contra referencias anteriores (tolerancia: menos del 0.01% de canales con diferencia mayor a 1/255). La física con índice se comparó con el barrido completo en los quince niveles durante seis segundos con entradas idénticas, sin diferencias de trayectoria, pista o recuperaciones.

Comprobado en Chrome: aplicación cargada, aislamiento de origen activo y carga real de `main.dart.wasm` y `skwasm.wasm` desde localhost. Captura: `.cache/release-performance.png`.

## Medición de CPU

Prueba `performance_probe_test.dart`, ejecutada por separado. Prepara una lista real de dibujo de 1000×800, con la misma geometría/materiales y orientación variable. Descarta cinco cuadros iniciales y toma sesenta muestras por escena. Mide preparación de CPU nativa en flutter_test, no FPS del navegador ni rasterización GPU.

| Nivel | Antes, mediana | Después, mediana |
|---|---:|---:|
| 05 | 12.130 ms | 4.808 ms |
| 10 | 6.627 ms | 3.665 ms |
| 15 | 6.285 ms | 3.265 ms |

Resultados orientativos de este entorno; otras cargas concurrentes alteran los tiempos. Las muestras originales están en `.cache/perf-before.json` y `.cache/perf-after.json`. La mejora de FPS en el teléfono o navegador del usuario requiere medición allí.

## Ejecutar la versión para jugar

```sh
cd '/media/openclawx/Disco 2/bolita'
flutter build web --release --wasm --no-web-resources-cdn
python3 tools/serve_web.py --port 8080
```

Abrir http://localhost:8080 y recargar con Ctrl+Shift+R. `flutter run -d web-server` sigue disponible para depurar, pero incluye trabajo de desarrollo y no representa el rendimiento de la compilación release. El APK anterior todavía no incorpora esta revisión.
