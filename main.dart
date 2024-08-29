import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gra Statek',
      home: MainMenu(),
    );
  }
}

// Menu główne
class MainMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Gra Statek',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GameScreen()),
                );
              },
              child: Text('Graj'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Jak grać'),
                    content: Text(
                      'Steruj statkiem za pomocą przycisków.\n'
                      'Użyj strzałek góra/dół, aby kontrolować prędkość.\n'
                      'Użyj strzałek lewo/prawo, aby skręcać.\n'
                      'Przytrzymaj przycisk, aby kontynuować ruch.\n'
                      'Unikaj skał - kolizja uszkodzi statek.\n'
                      'Zbieraj paliwo na wyspach.\n'
                      'Znajdź skarb na wyspach (szansa 0.1%).\n'
                      'Uważaj na sztormy!\n'
                      'Przetrwaj jak najdłużej i zdobądź jak najwięcej punktów!\n'
                      '1 chunk = 20 sekund przy maksymalnej prędkości.\n'
                      'Powodzenia!',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Jak grać'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Dodaj logikę dla przycisku "Wyjście"
                // np. Navigator.pop(context) aby wrócić do poprzedniego ekranu
                // lub SystemNavigator.pop() aby zamknąć aplikację
              },
              child: Text('Wyjście'),
            ),
          ],
        ),
      ),
    );
  }
}

// Ekran gry
class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  double shipX = 0;
  double shipY = 0;
  double shipAngle = 0;
  double shipSpeed = 0;
  bool isMoving = false;
  int lastTurnTime = 0;

  double maxSpeed = 15;
  double fuel = 55;
  double chunkTime = 20; // Czas w sekundach na przepłynięcie jednego chunka
  double chunkSize =
      20 * 15; // Rozmiar chunka w pikselach (20 sekund * 15 mil/h)
  List<Island> islands = [];
  List<Rock> rocks = [];
  Random random = Random();

  bool isStorm = false;
  int stormStartTime = 0;

  bool isShipDamaged = false;
  int shipRepairStartTime = 0;

  int currentChunkX = 0;
  int currentChunkY = 0;

  List<Offset> seaWaves = [];
  List<Offset> shipWaves = [];

  Timer? gameTimer;

  @override
  void initState() {
    super.initState();
    // Przenieś initializeGame do didChangeDependencies
    startGameLoop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initializeGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void startGameLoop() {
    gameTimer = Timer.periodic(Duration(milliseconds: 10), (timer) {
      setState(() {
        updateGame();
      });
    });
  }

  void initializeGame() {
    shipX = MediaQuery.of(context).size.width / 2;
    shipY = MediaQuery.of(context).size.height / 2;
    generateSeaWaves();
    generateWorld();
  }

  void generateWorld() {
    generateIslandsInChunk(currentChunkX, currentChunkY);
    generateRocksInChunk(currentChunkX, currentChunkY);
  }

  void generateIslandsInChunk(int chunkX, int chunkY) {
    if (random.nextDouble() < 0.2) {
      double islandX = (chunkX * chunkSize) +
          (random.nextDouble() - 0.5) * chunkSize;
      double islandY = (chunkY * chunkSize) +
          (random.nextDouble() - 0.5) * chunkSize;
      int islandSize = random.nextInt(30) + 20;
      islands.add(Island(islandX, islandY, islandSize));
    }
  }

  void generateRocksInChunk(int chunkX, int chunkY) {
    if (random.nextDouble() < 0.75) {
      double rockX = (chunkX * chunkSize) +
          (random.nextDouble() - 0.5) * chunkSize;
      double rockY = (chunkY * chunkSize) +
          (random.nextDouble() - 0.5) * chunkSize;
      int rockSize = random.nextInt(20) + 10;
      rocks.add(Rock(rockX, rockY, rockSize));
    }
  }

  void updateGame() {
    if (isShipDamaged) {
      if (DateTime.now().millisecondsSinceEpoch - shipRepairStartTime > 90000) {
        isShipDamaged = false;
        shipRepairStartTime = 0;
      }
      return;
    }

    if (isMoving && fuel > 0) {
      shipSpeed = shipSpeed.clamp(-maxSpeed / 2, maxSpeed);

      // Oblicz przemieszczenie w pikselach na podstawie prędkości i czasu
      double displacement =
          shipSpeed * (gameTimer!.tick / 1000) * (chunkSize / chunkTime);

      shipX += displacement * cos(shipAngle);
      shipY += displacement * sin(shipAngle);

      fuel -= shipSpeed.abs() * (gameTimer!.tick / 1000) / chunkTime;

      generateShipWaves();

      int newChunkX = (shipX / chunkSize).floor();
      int newChunkY = (shipY / chunkSize).floor();
      if (newChunkX != currentChunkX || newChunkY != currentChunkY) {
        currentChunkX = newChunkX;
        currentChunkY = newChunkY;
        generateWorld();

        if (random.nextDouble() < 0.01) {
          isStorm = true;
          stormStartTime = DateTime.now().millisecondsSinceEpoch;
        }
      }
    } else if (isMoving && fuel <= 0) {
      shipSpeed = 0;
      isMoving = false;
    }

    if (isStorm &&
        DateTime.now().millisecondsSinceEpoch - stormStartTime > 5000) {
      isStorm = false;
    }

    for (Rock rock in rocks) {
      if (rock.collidesWith(shipX, shipY)) {
        damageShip();
        break;
      }
    }

    if (!isShipDamaged) {
      for (Island island in islands) {
        if (island.collidesWith(shipX, shipY) && shipSpeed == 0) {
          if (random.nextDouble() < 0.001) {
            findTreasure();
          }
          if (random.nextDouble() < 0.5) {
            fuel += 10;
          }
        }
      }
    }

    moveSeaWaves();
    moveShipWaves();
  }

  void damageShip() {
    isShipDamaged = true;
    shipRepairStartTime = DateTime.now().millisecondsSinceEpoch;
    shipSpeed = 0;
    isMoving = false;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Statek uszkodzony!'),
        content: Text('Naprawa potrwa 1 minutę 30 sekund.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void findTreasure() {
    print('Znalazłeś skarb!');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Skarb!'),
        content: Text('Znalazłeś skarb na wyspie!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void generateSeaWaves() {
    seaWaves = []; // Wyczyść listę fal
    for (int i = 0; i < 50; i++) {
      seaWaves.add(Offset(
        random.nextDouble() * MediaQuery.of(context).size.width,
        random.nextDouble() * MediaQuery.of(context).size.height,
      ));
    }
  }

  void moveSeaWaves() {
    for (int i = 0; i < seaWaves.length; i++) {
      seaWaves[i] = Offset(
        seaWaves[i].dx + shipSpeed * cos(shipAngle + pi),
        seaWaves[i].dy + shipSpeed * sin(shipAngle + pi),
      );

      // Sprawdź, czy fale wyszły poza ekran i przenieś je na drugą stronę
      if (seaWaves[i].dx < 0) {
        seaWaves[i] = Offset(
          MediaQuery.of(context).size.width,
          seaWaves[i].dy,
        );
      } else if (seaWaves[i].dx > MediaQuery.of(context).size.width) {
        seaWaves[i] = Offset(
          0,
          seaWaves[i].dy,
        );
      }

      if (seaWaves[i].dy < 0) {
        seaWaves[i] = Offset(
          seaWaves[i].dx,
          MediaQuery.of(context).size.height,
        );
      } else if (seaWaves[i].dy > MediaQuery.of(context).size.height) {
        seaWaves[i] = Offset(
          seaWaves[i].dx,
          0,
        );
      }
    }
  }

  void generateShipWaves() {
    if (shipSpeed > 2) {
      // Generuj fale tylko przy prędkości powyżej 2 mil/h
      shipWaves.add(Offset(
        shipX - 30 * cos(shipAngle + pi / 2),
        shipY - 30 * sin(shipAngle + pi / 2),
      ));
      shipWaves.add(Offset(
        shipX + 30 * cos(shipAngle + pi / 2),
        shipY + 30 * sin(shipAngle + pi / 2),
      ));
    }
  }

  void moveShipWaves() {
    for (int i = 0; i < shipWaves.length; i++) {
      shipWaves[i] = Offset(
        shipWaves[i].dx - 1 * cos(shipAngle), // Prędkość fal statku
        shipWaves[i].dy - 1 * sin(shipAngle),
      );

      if (shipWaves[i].distance - shipX.abs() > 100 ||
          shipWaves[i].dy > MediaQuery.of(context).size.height ||
          shipWaves[i].dy < 0) {
        shipWaves.removeAt(i);
        i--;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Tło (morze)
          Container(
            color: Colors.lightBlue,
            child: CustomPaint(
              size: Size.infinite,
              painter: SeaWavesPainter(seaWaves),
            ),
          ),

          // Wyspy
          ...islands.map((island) => island.toWidget()),

          // Skały
          ...rocks.map((rock) => rock.toWidget()),

          // Statek
          Positioned(
            left: shipX - 20,
            top: shipY - 30,
            child: Transform.rotate(
              angle: shipAngle,
              child: CustomPaint(
                size: Size(40, 60),
                painter: ShipPainter(),
              ),
            ),
          ),

          // Sztorm
          if (isStorm)
            ...List.generate(10, (index) {
              double stormX =
                  random.nextDouble() * MediaQuery.of(context).size.width;
              double stormY =
                  random.nextDouble() * MediaQuery.of(context).size.height;
              double stormSize = random.nextDouble() * 20 + 10;
              return Positioned(
                left: stormX,
                top: stormY,
                child: Container(
                  width: stormSize,
                  height: stormSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade900.withOpacity(0.5),
                  ),
                ),
              );
            }),

          // Fale od statku
          CustomPaint(
            size: Size.infinite,
            painter: ShipWavesPainter(shipWaves),
          ),

          // Prędkościomierz
          Positioned(
            top: 10,
            left: 10,
            child: Text(
              'Prędkość: ${shipSpeed.toInt()} mil/h',
              style: TextStyle(color: Colors.black),
            ),
          ),

          // Licznik paliwa
          Positioned(
            top: 40,
            left: 10,
            child: Text(
              'Paliwo: ${fuel.toInt()} chunków',
              style: TextStyle(color: Colors.black),
            ),
          ),

          // Przyciski sterowania
          Positioned(
            bottom: 20,
            left: 20,
            child: GestureDetector(
              onLongPress: () {
                setState(() {
                  shipSpeed = maxSpeed;
                  isMoving = true;
                });
              },
              onLongPressUp: () {
                setState(() {
                  isMoving = false;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: Icon(Icons.arrow_upward),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: GestureDetector(
              onLongPress: () {
                setState(() {
                  shipSpeed = -maxSpeed / 2;
                  isMoving = true;
                });
              },
              onLongPressUp: () {
                setState(() {
                  isMoving = false;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: Icon(Icons.arrow_downward),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 20,
            child: GestureDetector(
              onLongPress: () {
                setState(() {
                  shipAngle -= 0.1;
                  lastTurnTime = DateTime.now().millisecondsSinceEpoch;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: Icon(Icons.arrow_back),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 20,
            child: GestureDetector(
              onLongPress: () {
                setState(() {
                  shipAngle += 0.1;
                  lastTurnTime = DateTime.now().millisecondsSinceEpoch;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: Icon(Icons.arrow_forward),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: (MediaQuery.of(context).size.width / 2) - 30,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  shipSpeed = 0; // Wyłącz silnik
                });
              },
              child: Text('Stop'),
            ),
          ),
        ],
      ),
    );
  }
}

// Klasa rysująca statek (czarny kolor)
class ShipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.moveTo(-10, 10);
    path.lineTo(10, 10);
    path.lineTo(0, -20);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Klasa reprezentująca wyspę
class Island {
  double x;
  double y;
  int size;

  Island(this.x, this.y, this.size);

  Widget toWidget() {
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: CustomPaint(
        size: Size(size.toDouble(), size.toDouble()),
        painter: IslandPainter(),
      ),
    );
  }

  bool collidesWith(double shipX, double shipY) {
    double distance = sqrt(pow(shipX - x, 2) + pow(shipY - y, 2));
    return distance < size / 2;
  }
}

// Klasa rysująca wyspę
class IslandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Random random = Random();

    // Wyspa
    Paint islandPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), islandPaint);

    // Kaktusy
    Paint cactusPaint = Paint()
      ..color = Colors.green.shade900
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      double cactusX = random.nextDouble() * size.width;
      double cactusY = random.nextDouble() * size.height;
      double cactusHeight = random.nextDouble() * size.width / 3 + size.width / 6;
      canvas.drawRect(
          Rect.fromLTWH(cactusX, cactusY, 5, cactusHeight), cactusPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Klasa reprezentująca skałę
class Rock {
  double x;
  double y;
  int size;

  Rock(this.x, this.y, this.size);

  Widget toWidget() {
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: CustomPaint(
        size: Size(size.toDouble(), size.toDouble()),
        painter: RockPainter(),
      ),
    );
  }

  bool collidesWith(double shipX, double shipY) {
    double distance = sqrt(pow(shipX - x, 2) + pow(shipY - y, 2));
    return distance < size / 2;
  }
}

// Klasa rysująca skałę
class RockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint rockPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), rockPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Klasa rysująca fale na morzu
class SeaWavesPainter extends CustomPainter {
  final List<Offset> seaWaves;

  SeaWavesPainter(this.seaWaves);

  @override
  void paint(Canvas canvas, Size size) {
    Paint wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (Offset wave in seaWaves) {
      canvas.drawOval(
        Rect.fromLTWH(wave.dx, wave.dy, 5, 5), // Małe fale (5x5 pikseli)
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Odrysowuj fale za każdym razem
  }
}

// Klasa rysująca fale od statku
class ShipWavesPainter extends CustomPainter {
  final List<Offset> shipWaves;

  ShipWavesPainter(this.shipWaves);

  @override
  void paint(Canvas canvas, Size size) {
    Paint wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (Offset wave in shipWaves) {
      double waveSize = 3; // Małe fale od statku (3x3 piksele)
      canvas.drawOval(
        Rect.fromLTWH(wave.dx, wave.dy, waveSize, waveSize),
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Odrysowuj fale za każdym razem
  }
}
