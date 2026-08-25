import 'dart:math';

import 'racing_model.dart';

/// 游戏引擎依赖的障碍来源，便于注入固定测试序列。
abstract class RacingObstacleSource {
  void reset(double playerX);

  RacingSpawnBatch generate({
    required int stage,
    required double passTime,
    required double playerX,
  });

  double nextSpawnDelay(int stage);
}

enum _Pattern { single, doubleCars, cones, barrier, mixed, laneChange }

/// 从合法模板中随机选择，并传播下一批仍可达的横向区间。
class RacingObstacleGenerator implements RacingObstacleSource {
  RacingObstacleGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<double> _laneCenters = const [1 / 6, 0.5, 5 / 6];
  List<RacingInterval> _reachable = const [RacingInterval(0.5, 0.5)];
  double _lastPassTime = 0;
  int _nextId = 1;

  List<RacingInterval> get reachableCorridors =>
      List<RacingInterval>.unmodifiable(_reachable);

  @override
  void reset(double playerX) {
    _reachable = [RacingInterval(playerX, playerX)];
    _lastPassTime = 0;
    _nextId = 1;
  }

  @override
  RacingSpawnBatch generate({
    required int stage,
    required double passTime,
    required double playerX,
  }) {
    for (var attempt = 0; attempt < 24; attempt++) {
      final obstacles = _build(_pickPattern(stage));
      final safe = _safeCorridors(obstacles);
      final reachable = _nextReachable(safe, passTime);
      if (safe.isEmpty || reachable.isEmpty) continue;
      _reachable = reachable;
      _lastPassTime = passTime;
      return RacingSpawnBatch(obstacles: obstacles, safeCorridors: safe);
    }

    final fallback = _buildSingle(_random.nextInt(3));
    final safe = _safeCorridors(fallback);
    _reachable = _nextReachable(safe, passTime);
    _lastPassTime = passTime;
    return RacingSpawnBatch(obstacles: fallback, safeCorridors: safe);
  }

  @override
  double nextSpawnDelay(int stage) {
    final range = switch (stage.clamp(1, 5)) {
      1 => (min: 1.40, max: 1.80),
      2 => (min: 1.15, max: 1.55),
      3 => (min: 0.90, max: 1.25),
      4 => (min: 0.70, max: 1.05),
      _ => (min: 0.52, max: 0.85),
    };
    return range.min + _random.nextDouble() * (range.max - range.min);
  }

  _Pattern _pickPattern(int stage) {
    final patterns = switch (stage.clamp(1, 5)) {
      1 => const [_Pattern.single],
      2 => const [
          _Pattern.single,
          _Pattern.doubleCars,
          _Pattern.cones,
          _Pattern.barrier,
        ],
      3 => const [
          _Pattern.single,
          _Pattern.doubleCars,
          _Pattern.cones,
          _Pattern.barrier,
          _Pattern.mixed,
        ],
      4 => const [
          _Pattern.doubleCars,
          _Pattern.cones,
          _Pattern.barrier,
          _Pattern.mixed,
          _Pattern.laneChange,
        ],
      _ => const [
          _Pattern.doubleCars,
          _Pattern.mixed,
          _Pattern.laneChange,
          _Pattern.laneChange,
          _Pattern.cones,
        ],
    };
    return patterns[_random.nextInt(patterns.length)];
  }

  List<RacingObstacle> _build(_Pattern pattern) => switch (pattern) {
        _Pattern.single => _buildSingle(_random.nextInt(3)),
        _Pattern.doubleCars => _buildDoubleCars(),
        _Pattern.cones => _buildCones(),
        _Pattern.barrier => [_obstacle(RacingObstacleKind.barrier, _lane())],
        _Pattern.mixed => _buildMixed(),
        _Pattern.laneChange => _buildLaneChange(),
      };

  List<RacingObstacle> _buildSingle(int lane) => [
        _obstacle(RacingObstacleKind.straightCar, _laneCenters[lane]),
      ];

  List<RacingObstacle> _buildDoubleCars() {
    final safeLane = _random.nextInt(3);
    return [
      for (var lane = 0; lane < 3; lane++)
        if (lane != safeLane)
          _obstacle(RacingObstacleKind.straightCar, _laneCenters[lane]),
    ];
  }

  List<RacingObstacle> _buildCones() {
    final center = _lane();
    return [
      _obstacle(RacingObstacleKind.cones, center - 0.04),
      _obstacle(RacingObstacleKind.cones, center + 0.04),
    ];
  }

  List<RacingObstacle> _buildMixed() {
    final safeLane = _random.nextInt(3);
    final blocked = [
      for (var lane = 0; lane < 3; lane++)
        if (lane != safeLane) lane
    ];
    return [
      _obstacle(RacingObstacleKind.straightCar, _laneCenters[blocked.first]),
      _obstacle(RacingObstacleKind.barrier, _laneCenters[blocked.last]),
    ];
  }

  List<RacingObstacle> _buildLaneChange() {
    final startsLeft = _random.nextBool();
    final start = startsLeft ? _laneCenters.first : _laneCenters.last;
    final target = _laneCenters[1];
    return [
      RacingObstacle(
        id: _nextId++,
        kind: RacingObstacleKind.laneChangingCar,
        x: start,
        y: kRacingSpawnY,
        startX: start,
        targetX: target,
        colorIndex: _random.nextInt(3),
      ),
    ];
  }

  RacingObstacle _obstacle(RacingObstacleKind kind, double x) => RacingObstacle(
        id: _nextId++,
        kind: kind,
        x: x,
        y: kRacingSpawnY,
        colorIndex: _random.nextInt(3),
      );

  double _lane() => _laneCenters[_random.nextInt(3)];

  List<RacingInterval> _safeCorridors(List<RacingObstacle> obstacles) {
    final blocked = <RacingInterval>[];
    for (final obstacle in obstacles) {
      final halfWidth = (obstacle.collisionWidthRoad +
                  kRacingPlayerWidthRoad * kRacingHitboxScale) /
              2 +
          0.01;
      final from = min(obstacle.startX, obstacle.targetX) - halfWidth;
      final to = max(obstacle.startX, obstacle.targetX) + halfWidth;
      blocked.add(RacingInterval(from.clamp(0.0, 1.0), to.clamp(0.0, 1.0)));
    }
    blocked.sort((a, b) => a.start.compareTo(b.start));

    final merged = <RacingInterval>[];
    for (final interval in blocked) {
      if (merged.isEmpty || interval.start > merged.last.end) {
        merged.add(interval);
      } else {
        final last = merged.removeLast();
        merged.add(RacingInterval(last.start, max(last.end, interval.end)));
      }
    }

    final safe = <RacingInterval>[];
    var cursor = 0.0;
    for (final interval in merged) {
      if (interval.start - cursor >= kRacingMinimumSafeWidth) {
        safe.add(RacingInterval(cursor, interval.start));
      }
      cursor = max(cursor, interval.end);
    }
    if (1 - cursor >= kRacingMinimumSafeWidth) {
      safe.add(RacingInterval(cursor, 1));
    }
    return safe;
  }

  List<RacingInterval> _nextReachable(
    List<RacingInterval> safe,
    double passTime,
  ) {
    final travel = kRacingPlayerMaxSpeed * max(0, passTime - _lastPassTime);
    final result = <RacingInterval>[];
    for (final previous in _reachable) {
      final expanded = previous.expand(travel);
      for (final corridor in safe) {
        final overlap = expanded.intersect(corridor);
        if (overlap != null) result.add(overlap);
      }
    }
    return _merge(result);
  }

  List<RacingInterval> _merge(List<RacingInterval> source) {
    if (source.isEmpty) return [];
    source.sort((a, b) => a.start.compareTo(b.start));
    final merged = <RacingInterval>[source.first];
    for (final interval in source.skip(1)) {
      if (interval.start > merged.last.end) {
        merged.add(interval);
      } else {
        final last = merged.removeLast();
        merged.add(RacingInterval(last.start, max(last.end, interval.end)));
      }
    }
    return merged;
  }
}
