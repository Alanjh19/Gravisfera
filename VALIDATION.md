# Estado de validación

## Registros disponibles

- La revisión de respuesta y cámara documenta 39 pruebas dirigidas y un análisis estático sin incidencias. Incluye física, puertas, hielo, bandas, objetivos de lógica, seguimiento y tamaños de interfaz.
- La revisión de rendimiento documenta 17 pruebas adicionales y comparaciones del renderizado.
- Los resultados proceden de ejecuciones registradas en noviembre de 2026; no se volvieron a ejecutar al preparar esta entrega.
- La suite completa no está cerrada: test/maze_playthrough_test.dart requiere adaptarse a los mapas actuales.

## Pendiente

- Validar controles táctiles, sonido, legibilidad y rendimiento en un dispositivo Android real.
- Completar una partida reproducible de cada uno de los 16 niveles.
- Generar un APK nuevo desde el código actual antes de distribuir un instalador.

Las pruebas dirigidas no equivalen a completar toda la campaña con control humano. La salida web se ha comprobado en navegador; eso no sustituye las pruebas en Android.
