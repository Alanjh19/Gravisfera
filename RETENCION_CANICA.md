# Corrección de salida al girar rápido

La canica permanece en la capa de rodadura de los tableros de lógica. Conserva la velocidad tangencial, los efectos del hielo/cintas y la sensibilidad alta, pero se elimina la componente que la lanzaba por encima de las paredes. La velocidad relativa máxima es 1.2 unidades/s y los giros rápidos siguen usando subpasos adaptativos.

Si por una posición inválida la canica queda fuera de los caminos, regresa a una celda segura reciente. Esta recuperación conserva llaves, placas, secuencias e interruptores. No es necesario intentar reintroducirla manualmente.

Validación específica: 15 pruebas aprobadas entre `retention_test.dart`, `extended_campaign_test.dart` y `logic_boards_test.dart`. Incluyen giros bruscos en los 16 niveles, posición en la capa de rodadura, pertenencia a un camino válido, límite de velocidad relativa, conservación del progreso y respuesta del giro.

Esto verifica la corrección de expulsión y los estados de los mecanismos. El controlador automático experimental de recorrido completo del laberinto sigue sin completarlo; no se considera una certificación de toda la campaña.
