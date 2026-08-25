import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'racing_game_engine.dart';
import 'racing_geometry.dart';
import 'racing_model.dart';

/// 清新日间三车道画面；绘制与碰撞共用 [RacingGeometry]。
class RacingPainter extends CustomPainter {
  const RacingPainter({
    required this.engine,
    this.geometry = const RacingGeometry(),
  });

  final RacingGameEngine engine;
  final RacingGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawRoad(canvas, size);
    _drawScenery(canvas, size);
    _drawLaneDividers(canvas, size);
    _drawObstacles(canvas, size);
    _drawCar(
      canvas,
      _toPixels(geometry.playerVisibleRect(engine.playerX), size),
      AppColors.racingPlayerCar,
      isPlayer: true,
    );
    if (engine.status == RacingStatus.crashed) {
      final alpha = sin(engine.crashProgress * pi).clamp(0.0, 1.0) * 0.42;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = AppColors.racingCrashFlash.withValues(alpha: alpha),
      );
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.racingSky, AppColors.bgCard],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.16, size.width, size.height * 0.84),
      Paint()..color = AppColors.racingGrass,
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.11),
      size.width * 0.07,
      Paint()..color = AppColors.accentGold,
    );
  }

  void _drawRoad(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(geometry.roadLeftAt(0) * size.width, 0)
      ..lineTo(geometry.roadRightAt(0) * size.width, 0)
      ..lineTo(geometry.roadRightAt(1) * size.width, size.height)
      ..lineTo(geometry.roadLeftAt(1) * size.width, size.height)
      ..close();
    final roadPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.racingRoadFar, AppColors.racingRoad],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, roadPaint);

    final edgePaint = Paint()
      ..color = AppColors.bgCard
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(geometry.roadLeftAt(0) * size.width, 0),
      Offset(geometry.roadLeftAt(1) * size.width, size.height),
      edgePaint,
    );
    canvas.drawLine(
      Offset(geometry.roadRightAt(0) * size.width, 0),
      Offset(geometry.roadRightAt(1) * size.width, size.height),
      edgePaint,
    );
  }

  void _drawLaneDividers(Canvas canvas, Size size) {
    const cycle = 0.16;
    const dashLength = 0.085;
    final offset = engine.roadOffset % cycle;
    for (final roadX in const <double>[1 / 3, 2 / 3]) {
      for (var y = -cycle + offset; y < 1; y += cycle) {
        final fromY = y.clamp(0.0, 1.0);
        final toY = (y + dashLength).clamp(0.0, 1.0);
        if (toY <= fromY) continue;
        final paint = Paint()
          ..color = AppColors.racingLaneYellow
          ..strokeWidth = 2 + 4 * toY
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(geometry.projectRoadX(roadX, fromY) * size.width,
              fromY * size.height),
          Offset(geometry.projectRoadX(roadX, toY) * size.width,
              toY * size.height),
          paint,
        );
      }
    }
  }

  void _drawScenery(Canvas canvas, Size size) {
    for (var index = 0; index < 7; index++) {
      final y = (index * 0.19 + engine.roadOffset * 0.9) % 1.2 - 0.08;
      if (y < 0 || y > 1) continue;
      final onLeft = index.isEven;
      final edge = onLeft ? geometry.roadLeftAt(y) : geometry.roadRightAt(y);
      final x = edge + (onLeft ? -0.075 : 0.075);
      final scale = 0.45 + y * 0.65;
      final center = Offset(x * size.width, y * size.height);
      canvas.drawRect(
        Rect.fromCenter(
          center: center.translate(0, 8 * scale),
          width: 5 * scale,
          height: 18 * scale,
        ),
        Paint()..color = AppColors.racingTreeTrunk,
      );
      canvas.drawCircle(
        center,
        15 * scale,
        Paint()..color = AppColors.racingTree,
      );
    }
  }

  void _drawObstacles(Canvas canvas, Size size) {
    final sorted = List<RacingObstacle>.from(engine.obstacles)
      ..sort((a, b) => a.y.compareTo(b.y));
    for (final obstacle in sorted) {
      final rect = _toPixels(geometry.obstacleVisibleRect(obstacle), size);
      switch (obstacle.kind) {
        case RacingObstacleKind.straightCar:
        case RacingObstacleKind.laneChangingCar:
          final color = AppColors.racingTrafficCars[
              obstacle.colorIndex % AppColors.racingTrafficCars.length];
          _drawCar(canvas, rect, color);
          if (obstacle.isWarning && (obstacle.age * 8).floor().isEven) {
            _drawIndicator(canvas, rect, obstacle.targetX > obstacle.startX);
          }
          break;
        case RacingObstacleKind.cones:
          _drawCone(canvas, rect);
          break;
        case RacingObstacleKind.barrier:
          _drawBarrier(canvas, rect);
          break;
      }
    }
  }

  void _drawCar(
    Canvas canvas,
    Rect rect,
    Color color, {
    bool isPlayer = false,
  }) {
    final wheelPaint = Paint()..color = AppColors.racingTire;
    final wheelWidth = rect.width * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(rect.left - wheelWidth / 2, rect.top + rect.height * 0.2,
            rect.right + wheelWidth / 2, rect.bottom - rect.height * 0.12),
        Radius.circular(rect.width * 0.12),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.22)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            rect.left + rect.width * 0.2,
            rect.top + rect.height * 0.16,
            rect.width * 0.6,
            rect.height * 0.25),
        Radius.circular(rect.width * 0.12),
      ),
      Paint()..color = AppColors.racingWindshield,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            rect.left + rect.width * 0.18,
            rect.bottom - rect.height * 0.13,
            rect.width * 0.64,
            rect.height * 0.06),
        Radius.circular(rect.width * 0.05),
      ),
      Paint()
        ..color = (isPlayer ? AppColors.bgCard : AppColors.accentGold)
            .withValues(alpha: 0.9),
    );
  }

  void _drawIndicator(Canvas canvas, Rect rect, bool pointsRight) {
    final x = pointsRight
        ? rect.right - rect.width * 0.15
        : rect.left + rect.width * 0.15;
    canvas.drawCircle(
      Offset(x, rect.top + rect.height * 0.48),
      max(2, rect.width * 0.1),
      Paint()..color = AppColors.accentGold,
    );
  }

  void _drawCone(Canvas canvas, Rect rect) {
    final path = Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.racingConstruction);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top + rect.height * 0.58, rect.width,
          max(2, rect.height * 0.12)),
      Paint()..color = AppColors.bgCard,
    );
  }

  void _drawBarrier(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height * 0.25)),
      Paint()..color = AppColors.racingConstruction,
    );
    for (var index = 0; index < 3; index++) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + rect.width * (0.12 + index * 0.32),
          rect.top,
          rect.width * 0.12,
          rect.height,
        ),
        Paint()..color = AppColors.bgCard,
      );
    }
  }

  Rect _toPixels(Rect normalized, Size size) => Rect.fromLTRB(
        normalized.left * size.width,
        normalized.top * size.height,
        normalized.right * size.width,
        normalized.bottom * size.height,
      );

  @override
  bool shouldRepaint(covariant RacingPainter oldDelegate) => true;
}
