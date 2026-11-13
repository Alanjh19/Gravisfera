// Authored maps. S=start, G=goal; a/b/c=keys, A/B/C=key doors;
// P/D=plate/door; 1/2/3/Q=sequence/door; O/N=orbital lock/door;
// x/y/z and X/Y/Z=toggle switches and Boolean gates; I=ice, arrows=belts.
const logicMaps = <String>[
  '''
#############
#S....#....a#
#.###.#.##..#
#...#...#...#
###.#####.#A#
#...#...#.#.#
#.###.#.#.#.#
#.....#P..#.#
#.#######.#.#
#...#.....#.#
###.#.#####D#
#..........G#
#############
''',
  '''
#############
#S....#a....#
#####.#.##.#
#.....#..#.#
#.#####A.#.#
#.#b....#..#
#.#.#####.##
#...#...#..#
###.#.#.##B#
#P..#.#....#
#.###.####D#
#.........G#
#############
''',
  '''
#############
#S....#....1#
#.###.#.##.#
#.#...#....#
#.#.#####.##
#2#.....#..#
#.#####.##.#
#.....#....#
###.#.####.#
#3..#......#
#.########Q#
#.........G#
#############
''',
  '''
#############
#S..>>>>..a#
#.#######.##
#...#......#
###.#.####A#
#...#...#..#
#.#####.#.##
#P....#.#..#
#####.#.##.#
#...<<<....#
#.########D#
#.........G#
#############
''',
  '''
#############
#S....T....a#
#.#######.##
#...#......#
###.#.###T##
#...#...#..#
#.###.#.#A##
#.....#.#..#
#####T#.##.#
#P....#....#
#.########D#
#.........G#
#############
''',
  '''
#############
#S....#....a#
#.###.#.##.#
#...#......#
###.#####A##
#...#...#..#
#.###O#.#.##
#.....#....#
#####.####.#
#P....#....#
#.########N#
#.........G#
#############
''',
  '''
#############
#S..IIIIIIa#
#.########.#
#...#......#
###.#.####A#
#...#..III.#
#.#####I##.#
#P..III...I#
###I#####II#
#...#..IIII#
#.########D#
#.......IIG#
#############
''',
  '''
#############
#S....M....a#
#.#######.##
#...#...#..#
###.#.#.#A##
#...#M#....#
#.###.###.##
#P....#...M#
#####.#.##.#
#...#......#
#.########D#
#.........G#
#############
''',
  '''
###############
#S....#a......#
#.###.#####.#.#
#...#.....#.#.#
###.#####A#.#.#
#...#b....#...#
#.###.#######.#
#.....#c....#.#
#.#####B###.#.#
#P....#...#...#
#####.#.#.###C#
#.....#.#.....#
#.###########D#
#............G#
###############
''',
  '''
#############
#S..1.#....2#
#.###.#.##.#
#...#......#
###.#####.##
#...#3..#..#
#.###.#.#.##
#.....#....#
#####.####.#
#P....#....Q#
#.########D#
#.........G#
#############
''',
  '''
#############
#S....#a...b#
#.###.#.##.#
#...#...#..#
###.###A##.#
#...#...#..#
#.###.#.#B##
#.....#....#
#####.####.#
#P..T.#....#
#.########D#
#.........G#
#############
''',
  '''
###############
#S....#......P#
#.###.#.#####.#
#...#...#.....#
###.#####.###.#
#...#.....#a..#
#.###.#####.###
#.....#...#...#
#.#####.#.###.#
#.....#.#.....#
#####.#.#####A#
#.....#.......#
#.###########D#
#............G#
###############
''',
  '''
#########
###y#####
###.#####
#x.S.X.G#
#.#.#####
#Z#Y#####
#.#.#####
#..z#####
#########
''',
  '''
###############
#S..1.#a....T2#
#.###.#.###.#.#
#...#...#...#.#
###.#####A###.#
#...#..III#...#
#.###.#.###.#T#
#.....#3....#.#
#.#####.#####.#
#P....#...#...#
#####.#.#.###Q#
#.....#.#.....#
#.###########D#
#............G#
###############
''',
  '''
###############
#S.x..#a....T1#
#.###.#.###.#.#
#...#...#...#.#
###.#####A###.#
#y..#O..II#..2#
#.###.#.###.#T#
#.....#3..z.#.#
#.#####.#####X#
#P....#M..#...#
#####.#.#.###N#
#.....#.#.....Q#
#.###########Z#
#............G#
###############
''',
];
const logicNames = [
  'La primera vuelta',
  'Retorno obligado',
  'Orden cruzado',
  'Contracorriente',
  'La ventana',
  'Giro completo',
  'Frenada sobre hielo',
  'Polaridad',
  'Tres cerraduras',
  'Memoria mecánica',
  'El rodeo',
  'El interruptor lejano',
  'La esclusa',
  'Doble sincronía',
  'La máquina imposible',
];
const logicHints = [
  'La llave abre un atajo; la placa abre la salida. Necesitas ambas.',
  'Encuentra A antes de buscar B. La vuelta al interruptor cambia la ruta de salida.',
  'Las placas se activan en el orden indicado. Algunas obligan a regresar.',
  'Las cintas empujan en la dirección de las flechas. Activa la placa para invertirlas.',
  'Las puertas verdes permiten pasar. Usa los descansillos para esperar y luego cruza.',
  'Entra en la cápsula O: invierte la esfera y vuelve a dejarla boca arriba para abrir N.',
  'En azul se conserva el impulso. Usa suelo normal para frenar antes de salir.',
  'La placa cambia la polaridad de los imanes y abre D. Prueba ambas rutas.',
  'Tres llaves y tres cerraduras. Planea el orden para evitar vueltas innecesarias.',
  'La secuencia importa. Las placas ya encendidas permanecen activas.',
  'Dos llaves, un atajo y una puerta temporal. La ruta directa no siempre sirve.',
  'El interruptor está lejos de la salida. Usa el atajo abierto por la llave.',
  'X se abre con X ≠ Y; Y con Y ≠ Z; Z con X y Z activos. Objetivo: X y Z encendidos, Y apagado.',
  'Combina la secuencia con las ventanas de paso y la frenada sobre hielo.',
  'Combina llave, secuencia, giro orbital e interruptores. Objetivo: X y Z activos, Y apagado.',
];
