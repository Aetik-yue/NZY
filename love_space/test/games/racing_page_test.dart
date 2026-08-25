import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/features/games/games_page.dart';
import 'package:love_space/features/games/racing/racing_game_engine.dart';
import 'package:love_space/features/games/racing/racing_model.dart';
import 'package:love_space/features/games/racing/racing_obstacle_generator.dart';
import 'package:love_space/features/games/racing/racing_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('games center opens the racing ready screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          racingBestDistanceProvider.overrideWith((ref) async => 842),
        ],
        child: const MaterialApp(home: GamesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('公路闪避'), findsOneWidget);
    await tester.tap(find.text('公路闪避'));
    await tester.pumpAndSettle();

    expect(find.byType(RacingPage), findsOneWidget);
    expect(find.text('历史最佳 842 m'), findsOneWidget);
    expect(find.byKey(const ValueKey('racing_start')), findsOneWidget);
  });

  testWidgets('large lower drag area moves the car horizontally',
      (tester) async {
    final engine = RacingGameEngine(
      obstacleSource: RacingObstacleGenerator(random: Random(9)),
    );
    await _pumpPage(tester, engine);

    await tester.tap(find.byKey(const ValueKey('racing_start')));
    await tester.pump();
    expect(find.byKey(const ValueKey('racing_countdown')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('racing_drag_area')),
      const Offset(120, 0),
    );
    await _pumpGameTime(tester, 0.4);

    expect(engine.playerX, greaterThan(0.5));
    expect(find.byKey(const ValueKey('racing_canvas')), findsOneWidget);
  });

  testWidgets('pause freezes the active game and exposes resume',
      (tester) async {
    final engine = RacingGameEngine(
      obstacleSource: RacingObstacleGenerator(random: Random(10)),
    );
    await _pumpPage(tester, engine);
    await tester.tap(find.byKey(const ValueKey('racing_start')));
    await _pumpGameTime(tester, 3.2);
    expect(engine.status, RacingStatus.playing);

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();

    expect(engine.status, RacingStatus.paused);
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.byKey(const ValueKey('racing_resume')), findsOneWidget);
  });

  testWidgets('one collision reaches the result overlay', (tester) async {
    final engine = RacingGameEngine(
      obstacleSource: _CollisionObstacleSource(),
    );
    await _pumpPage(tester, engine);
    await tester.tap(find.byKey(const ValueKey('racing_start')));
    await _pumpGameTime(tester, 3.8);
    await tester.pump();

    expect(engine.status, RacingStatus.gameOver);
    expect(find.text('本局结束'), findsOneWidget);
    expect(find.byKey(const ValueKey('racing_result')), findsOneWidget);
    expect(find.byKey(const ValueKey('racing_restart')), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  RacingGameEngine engine,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        racingBestDistanceProvider.overrideWith((ref) async => 0),
      ],
      child: MaterialApp(home: RacingPage(engine: engine)),
    ),
  );
  await tester.pump();
}

Future<void> _pumpGameTime(WidgetTester tester, double seconds) async {
  const step = Duration(milliseconds: 16);
  final frames = (seconds * 1000 / step.inMilliseconds).ceil();
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(step);
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
