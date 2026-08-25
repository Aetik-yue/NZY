// 公路闪避的固定逻辑参数与数据模型。

const double kRacingPlayerY = 0.78;
const double kRacingSpawnY = -0.08;
const double kRacingPlayerWidthRoad = 0.16;
const double kRacingPlayerBaseHeight = 0.09;
const double kRacingHitboxScale = 0.78;
const double kRacingPlayerMaxSpeed = 2.4;
const double kRacingMinimumSafeWidth = 0.17;
const double kRacingCrashDuration = 0.42;

/// 一局游戏的状态机。
enum RacingStatus { ready, countdown, playing, paused, crashed, gameOver }

/// 交通障碍类型。
enum RacingObstacleKind { straightCar, laneChangingCar, cones, barrier }

/// 标准化道路横向区间。
class RacingInterval {
  const RacingInterval(this.start, this.end);

  final double start;
  final double end;

  double get width => end - start;

  RacingInterval expand(double amount) => RacingInterval(
        (start - amount).clamp(0.0, 1.0),
        (end + amount).clamp(0.0, 1.0),
      );

  RacingInterval? intersect(RacingInterval other) {
    final nextStart = start > other.start ? start : other.start;
    final nextEnd = end < other.end ? end : other.end;
    if (nextEnd <= nextStart) return null;
    return RacingInterval(nextStart, nextEnd);
  }
}

/// 单个可移动或静态障碍；坐标均使用标准化道路空间。
class RacingObstacle {
  RacingObstacle({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    double? startX,
    double? targetX,
    this.warningDuration = 0.8,
    this.laneChangeDuration = 0.65,
    this.colorIndex = 0,
  })  : startX = startX ?? x,
        targetX = targetX ?? x;

  final int id;
  final RacingObstacleKind kind;
  double x;
  double y;
  final double startX;
  final double targetX;
  final double warningDuration;
  final double laneChangeDuration;
  final int colorIndex;
  double age = 0;

  double get widthRoad => switch (kind) {
        RacingObstacleKind.straightCar => 0.15,
        RacingObstacleKind.laneChangingCar => 0.15,
        RacingObstacleKind.cones => 0.07,
        RacingObstacleKind.barrier => 0.26,
      };

  double get baseHeight => switch (kind) {
        RacingObstacleKind.straightCar => 0.085,
        RacingObstacleKind.laneChangingCar => 0.085,
        RacingObstacleKind.cones => 0.045,
        RacingObstacleKind.barrier => 0.04,
      };

  double get collisionWidthRoad => widthRoad * kRacingHitboxScale;

  bool get isWarning =>
      kind == RacingObstacleKind.laneChangingCar && age < warningDuration;
}

/// 一次生成的障碍与其安全通道。
class RacingSpawnBatch {
  const RacingSpawnBatch({
    required this.obstacles,
    required this.safeCorridors,
  });

  final List<RacingObstacle> obstacles;
  final List<RacingInterval> safeCorridors;
}

/// 纯函数：有效时间对应的难度阶段。
int racingStageAt(double elapsedSeconds) =>
    (elapsedSeconds ~/ 25 + 1).clamp(1, 5).toInt();

/// 纯函数：有效时间对应的速度进度因子。
double racingSpeedFactorAt(double elapsedSeconds) {
  final progress = (elapsedSeconds / 125).clamp(0.0, 1.0);
  return 1 + 1.1 * progress;
}

/// 道路每秒滚动的游戏场高度。
double racingRoadSpeedAt(double elapsedSeconds) =>
    0.42 * racingSpeedFactorAt(elapsedSeconds);

/// 每秒累计的行驶米数。
double racingDistanceSpeedAt(double elapsedSeconds) =>
    16 * racingSpeedFactorAt(elapsedSeconds);
