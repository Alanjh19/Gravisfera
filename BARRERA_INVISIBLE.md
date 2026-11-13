# Cubierta invisible y giro ampliado

El tablero tiene un límite inferior y una cubierta invisible a 0.178 unidades de altura, dejando 0.008 unidades de holgura sobre la canica. El colisionador no añade una malla visible ni elimina las paredes o puertas interiores.

Sensibilidad inicial: 7, ajustable entre 0.3 y 14. El arrastre usa 0.018 radianes por píxel multiplicados por la sensibilidad; aproximadamente tres veces la respuesta de la revisión anterior. Se amplían también Q/E, botones y giro con dos dedos. La orientación no limita el ángulo acumulado: permite vueltas completas. Velocidad angular máxima: 8 rad/s, con hasta ocho subpasos para conservar la detección de contactos.

Se verifican contención con giros bruscos en los 16 niveles, bloqueo vertical por la cubierta, recuperación segura, respuesta angular, bloqueo/apertura de una puerta con llave y controles de interfaz. Esta revisión no certifica el recorrido completo de todas las rutas.
