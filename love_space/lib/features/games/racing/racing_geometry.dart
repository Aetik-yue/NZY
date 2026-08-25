import 'dart:ui';

import 'racing_model.dart';

/// 道路透视、实体矩形和碰撞矩形的唯一几何来源。
class RacingGeometry {
  const RacingGeometry();

  double roadLeftAt(double y) => 0.34 + (0.06 - 0.34) * y;

  double roadRightAt(double y) => 0.66 + (0.94 - 0.66) * y;

  double roadWidthAt(double y) => roadRightAt(y) - roadLeftAt(y);

  double projectRoadX(double roadX, double y) =>
      roadLeftAt(y) + roadWidthAt(y) * roadX;

  double scaleAt(double y) => 0.55 + 0.65 * y.clamp(0.0, 1.0);

  Rect playerVisibleRect(double playerX) => _visibleRect(
        x: playerX,
        y: kRacingPlayerY,
        widthRoad: kRacingPlayerWidthRoad,
        baseHeight: kRacingPlayerBaseHeight,
      );

  Rect playerCollisionRect(double playerX) =>
      _scaledFromCenter(playerVisibleRect(playerX), kRacingHitboxScale);

  Rect obstacleVisibleRect(RacingObstacle obstacle) => _visibleRect(
        x: obstacle.x,
        y: obstacle.y,
        widthRoad: obstacle.widthRoad,
        baseHeight: obstacle.baseHeight,
      );

  Rect obstacleCollisionRect(RacingObstacle obstacle) =>
      _scaledFromCenter(obstacleVisibleRect(obstacle), kRacingHitboxScale);

  bool playerCollides(double playerX, RacingObstacle obstacle) =>
      playerCollisionRect(playerX).overlaps(obstacleCollisionRect(obstacle));

  Rect _visibleRect({
    required double x,
    required double y,
    required double widthRoad,
    required double baseHeight,
  }) {
    final width = roadWidthAt(y) * widthRoad;
    final height = baseHeight * scaleAt(y);
    return Rect.fromCenter(
      center: Offset(projectRoadX(x, y), y),
      width: width,
      height: height,
    );
  }

  Rect _scaledFromCenter(Rect source, double scale) => Rect.fromCenter(
        center: source.center,
        width: source.width * scale,
        height: source.height * scale,
      );
}
