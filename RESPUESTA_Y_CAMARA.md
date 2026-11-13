# Rodadura y cámara de seguimiento — 12 noviembre 2026

La gravedad permanece en 3.2 unidades del mundo/s². Se corrigieron los frenos artificiales que hacían que la canica respondiera con lentitud; no se ha calibrado una escala de metros para este juguete.

- En los tableros con agarre, la aceleración tangencial se reparte como una esfera maciza (5/7 de la componente de gravedad), con resistencia a rodadura proporcional a la carga. El hielo permite deslizamiento y tiene menor resistencia. Las bandas conservan su velocidad superficial y transmiten movimiento por contacto.
- Se retiró el límite cotidiano de 1.2 unidades/s y el amortiguamiento viscoso del suelo normal. Solo queda un límite de emergencia de 4.5 unidades/s respecto al tablero. Las paredes, puertas y tapa invisible siguen siendo colisionadores.
- Piso y tapa resuelven contacto al alcanzar sus límites; no eliminan continuamente la velocidad normal dentro de la holgura. Las superficies no atraen la canica antes del impacto.
- Renderizado y física mantienen paso fijo de 1/240 s. Los cuadros de hasta 250 ms se simulan completos, evitando la cámara lenta artificial de los límites anteriores de 50/100 ms. Una interrupción mayor se limita para evitar recuperar segundos de trabajo en un cuadro; al ocultar la aplicación se pausa.

## Cámara

En la fila inferior, el botón de mira **Enfocar y seguir canica** activa seguimiento con acercamiento inicial 2.8×. El deslizador permite 0.8–4.5×. El seguimiento tiene suavizado breve y una distancia de retraso acotada. El horizonte se mantiene estable. Con movimiento reducido, el centro sigue directamente a la canica. Pulsa **Ver esfera completa** para regresar a 1×. Entrar a un nivel desde el menú o selector restablece la vista general. Reintentar conserva el modo de cámara elegido.

## Validación

`flutter analyze --no-pub`: sin incidencias.

39 pruebas específicas pasaron:

```sh
flutter test --no-pub test/rolling_response_test.dart test/retention_test.dart test/extended_campaign_test.dart test/physics_test.dart test/ui_test.dart test/spatial_index_test.dart test/curve_regression_test.dart test/logic_boards_test.dart
```

Incluyen aceleración sobre pendiente, inversión del movimiento al subir, inercia sin límite artificial a 1.2, caída libre, coherencia a 10/120 FPS, retención bajo giros rápidos en los 16 niveles, puertas, hielo/bandas, objetivos lógicos, cámara de seguimiento y UI a 320×640 y 1280×800. No equivalen a completar los 16 niveles con control humano ni a verificar un Android real. No se ejecutó la suite completa: el controlador experimental de recorrido de `maze_playthrough_test.dart` sigue pendiente de adaptar a los mapas actuales. Las referencias gráficas históricas tampoco se regeneraron en esta revisión.

Salida web: `build/web`, release/WASM con recursos locales. Servidor: `python3 tools/serve_web.py --port 8080`.
