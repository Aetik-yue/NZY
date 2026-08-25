import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/games/racing/racing_game_engine.dart';
import 'package:love_space/features/games/racing/racing_model.dart';
import 'package:love_space/features/games/racing/racing_obstacle_generator.dart';

void main() {
  group('racing difficulty functions', () {
    test('speed grows continuously and caps at 125 seconds', () {
      expect(racingRoadSpeedAt(0), 0.42);
      expect(racingDistanceSpeedAt(0), 16);
      expect(racingRoadSpeedAt(62.5), closeTo(0.651, 1e-9));
      expect(racingRoadSpeedAt(125), closeTo(0.882, 1e-9));
      expect(racingRoadSpeedAt(300), closeTo(0.882, 1e-9));
      expect(racingDistanceSpeedAt(125), closeTo(33.6, 1e-9));
    });

    test('stage increases every 25 seconds and caps at five', () {
      expect(racingStageAt(0), 1);
      expect(racingStageAt(24.999), 1);
      expect(racingStageAt(25), 2);
      expect(racingStageAt(75), 4);
      expect(racingStageAt(100), 5);
      expect(racingStageAt(999), 5);
    });
  });

  group('RacingGameEngine state machine', () {
    test('start counts down, then distance follows current speed', () {
      final engine = RacingGameEngine(
        obstacleSource: RacingObstacleGenerator(random: Random(3)),
      );

      engine.start();
      expect(engine.status, RacingStatus.countdown);
      _advance(engine, 3.1);
      expect(engine.status, RacingStatus.playing);
      final before = engine.distanceMeters;
      _advance(engine, 1);
      expect(engine.distanceMeters - before, closeTo(16, 0.3));
    });

    test('pause freezes time, score, and obstacles until explicit resume', () {
      final engine = RacingGameEngine(
        obstacleSource: RacingObstacleGenerator(random: Random(4)),
      );
      engine.start();
      _advance(engine, 3.1);
      _advance(engine, 1);
      final elapsed = engine.elapsedSeconds;
      final distance = engine.distanceMeters;
      final obstacleY = engine.obstacles.firstOrNull?.y;

      engine.pause();
      _advance(engine, 2);
      expect(engine.status, RacingStatus.paused);
      expect(engine.elapsedSeconds, elapsed);
      expect(engine.distanceMeters, distance);
      expect(engine.obstacles.firstOrNull?.y, obstacleY);

      engine.resume();
      _advance(engine, 0.5);
      expect(engine.status, RacingStatus.playing);
      expect(engine.elapsedSeconds, greaterThan(elapsed));
    });

    test('large frame gaps are ignored', () {
      final engine = RacingGameEngine(
        obstacleSource: RacingObstacleGenerator(random: Random(5)),
      );
      engine.start();
      _advance(engine, 3.1);
      final elapsed = engine.elapsedSeconds;
      final distance = engine.distanceMeters;

      engine.update(0.2);
      expect(engine.elapsedSeconds, elapsed);
      expect(engine.distanceMeters, distance);
    });

    test('one collision ends the run after crash feedback', () {
      final engine = RacingGameEngine(
        obstacleSource: _CollisionObstacleSource(),
      );
      engine.start();
      _advance(engine, 3.1);
      _advance(engine, 0.3);

      expect(engine.status, RacingStatus.crashed);
      final distance = engine.distanceMeters;
      _advance(engine, 0.5);
      expect(engine.status, RacingStatus.gameOver);
      expect(engine.distanceMeters, distance);
    });

    test('restart clears score, obstacles, speed, and player position', () {
      final engine = RacingGameEngine(
        obstacleSource: RacingObstacleGenerator(random: Random(6)),
      );
      engine.start();
      _advance(engine, 3.1);
      engine.setPlayerTarget(0.9);
      _advance(engine, 1);
      expect(engine.distanceMeters, greaterThan(0));

      engine.restart();
      expect(engine.status, RacingStatus.countdown);
      expect(engine.distanceMeters, 0);
      expect(engine.elapsedSeconds, 0);
      expect(engine.obstacles, isEmpty);
      expect(engine.playerX, 0.5);
      expect(engine.stage, 1);
    });
  });
}

void _advance(RacingGameEngine engine, double seconds) {
  const step = 1 / 60;
  var remaining = seconds;
  while (remaining > 0) {
    final dt = min(step, remaining);
    engine.update(dt);
    remaining -= dt;
  }
}

class _CollisionObstacleSource implements RacingObstacleSource {
  bool _generated = false;

  @override
  RacingSpawnBatch generate({
    required int stage,
    required double passTime,
    required double playerX,
  }) {
    if (_generated) {
      return const RacingSpawnBatch(obstacles: [], safeCorridors: []);
    }
    _generated = true;
    return RacingSpawnBatch(
      obstacles: [
        RacingObstacle(
          id: 1,
          kind: RacingObstacleKind.straightCar,
          x: playerX,
          y: kRacingPlayerY,
        ),
      ],
      safeCorridors: const [RacingInterval(0, 1)],
    );
  }

  @override
  double nextSpawnDelay(int stage) => 100;

  @override
  void reset(double playerX) => _generated = false;
}
