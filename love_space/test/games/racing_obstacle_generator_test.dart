import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/games/racing/racing_model.dart';
import 'package:love_space/features/games/racing/racing_obstacle_generator.dart';

void main() {
  group('RacingObstacleGenerator stage rules', () {
    test('stage one only creates one straight car', () {
      final generator = RacingObstacleGenerator(random: Random(7));
      generator.reset(0.5);

      for (var i = 0; i < 40; i++) {
        final batch = generator.generate(
          stage: 1,
          passTime: 2 + i * 1.5,
          playerX: 0.5,
        );
        expect(batch.obstacles, hasLength(1));
        expect(
          batch.obstacles.single.kind,
          RacingObstacleKind.straightCar,
        );
      }
    });

    test('lane-changing cars do not appear before stage four', () {
      for (var stage = 1; stage <= 3; stage++) {
        final generator = RacingObstacleGenerator(random: Random(stage));
        generator.reset(0.5);
        for (var i = 0; i < 100; i++) {
          final batch = generator.generate(
            stage: stage,
            passTime: 2 + i * 0.9,
            playerX: 0.5,
          );
          expect(
            batch.obstacles
                .where(
                    (item) => item.kind == RacingObstacleKind.laneChangingCar)
                .isEmpty,
            isTrue,
          );
        }
      }
    });

    test('stage four eventually includes a warned lane-changing car', () {
      final generator = RacingObstacleGenerator(random: Random(11));
      generator.reset(0.5);
      final obstacles = <RacingObstacle>[];
      for (var i = 0; i < 160; i++) {
        obstacles.addAll(generator
            .generate(
              stage: 4,
              passTime: 2 + i * 0.8,
              playerX: 0.5,
            )
            .obstacles);
      }

      final changing = obstacles.where(
        (item) => item.kind == RacingObstacleKind.laneChangingCar,
      );
      expect(changing, isNotEmpty);
      expect(
        changing.every((item) => item.warningDuration == 0.8),
        isTrue,
      );
    });
  });

  group('RacingObstacleGenerator fairness', () {
    test('many deterministic batches always keep a reachable corridor', () {
      for (var stage = 1; stage <= 5; stage++) {
        final generator = RacingObstacleGenerator(random: Random(100 + stage));
        generator.reset(0.5);
        for (var i = 0; i < 600; i++) {
          final batch = generator.generate(
            stage: stage,
            passTime: 2 + i * 0.55,
            playerX: 0.5,
          );
          expect(batch.safeCorridors, isNotEmpty);
          expect(generator.reachableCorridors, isNotEmpty);
          expect(
            batch.safeCorridors.any(
              (corridor) => corridor.width >= kRacingMinimumSafeWidth,
            ),
            isTrue,
          );
        }
      }
    });

    test('same seed produces the same obstacle sequence', () {
      final first = RacingObstacleGenerator(random: Random(42));
      final second = RacingObstacleGenerator(random: Random(42));
      first.reset(0.5);
      second.reset(0.5);

      final firstSignatures = <String>[];
      final secondSignatures = <String>[];
      for (var i = 0; i < 80; i++) {
        firstSignatures.add(_signature(first.generate(
          stage: 5,
          passTime: 2 + i * 0.7,
          playerX: 0.5,
        )));
        secondSignatures.add(_signature(second.generate(
          stage: 5,
          passTime: 2 + i * 0.7,
          playerX: 0.5,
        )));
      }

      expect(firstSignatures, secondSignatures);
    });
  });
}

String _signature(RacingSpawnBatch batch) => batch.obstacles
    .map((item) => '${item.kind.name}:${item.x.toStringAsFixed(3)}:'
        '${item.targetX.toStringAsFixed(3)}')
    .join('|');
