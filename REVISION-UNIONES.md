# Pistas continuas — corrección de las juntas

Se mantuvo el juego existente. No se sustituyó por un tablero ni se cambió la mecánica de control.

- Curvas Hermite con tangentes compartidas y subdivisión adaptativa donde cambia la dirección.
- Cada tramo comparte exactamente los vértices de ambos bordes con el siguiente. La superficie y las barandas forman una cinta continua. Se eliminaron los cierres laterales de las cajas entre tramos.
- Se cerró la discontinuidad del nivel 2. La bajada ahora es una rampa continua.
- El suelo no se desplaza como una baldosa independiente en el ascensor; así se evita abrir una junta. El mecanismo de ascensor completo sigue pendiente.
- La esfera colisiona con los mismos triángulos que dibujan el suelo. Se elige un único apoyo cercano por paso para evitar correcciones repetidas de piezas adyacentes.
- Bases geométricas, longitudes y límites precalculados. Filtro por límites antes de comprobar triángulos.

Validación real: `flutter test --no-pub`, doce pruebas aprobadas; `flutter analyze --no-pub`, sin incidencias. Las pruebas comprueban continuidad central y lateral de los quince mapas, cambio gradual de dirección y rodadura sobre múltiples juntas sin recuperaciones. Revisión visual real en Chrome del nivel 5: `.cache/joined-live.png`.

Esto no demuestra todavía soluciones completas para todos los mecanismos y niveles. El APK anterior no se reconstruyó. La versión corregida está disponible en http://localhost:8080.
