# Revisión actual del proyecto

- La campaña activa contiene 16 laberintos: 15 mapas de lógica diseñados para el juego y uno generado de 21 × 21 celdas.
- El nivel 10, Memoria mecánica, incorpora exploración con niebla y una secuencia de placas 3 → 1 → 2.
- La interfaz incluye menú con el nombre del alumno, selector de niveles, ajustes, cronómetro, pausa, reinicio y navegación de victoria.
- El jugador inclina el tablero mediante gestos; las paredes y puertas tienen colisiones.
- Hay seguimiento de cámara, zoom, música ambiente, efectos, vibración y guardado local de preferencias y récords.
- La versión web optimizada usa WebAssembly cuando el navegador lo admite y conserva una ruta alternativa.

Las pruebas dirigidas y sus límites están resumidos en VALIDATION.md. No se ha validado el funcionamiento en un teléfono Android real.
