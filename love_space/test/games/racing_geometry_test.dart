import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/games/racing/racing_geometry.dart';
import 'package:love_space/features/games/racing/racing_model.dart';

void main() {
  const geometry = RacingGeometry();

  group('RacingGeometry road projection', () {
    test('two lane dividers split the perspective road into equal thirds', () {
      for (final y in <double>[0, 0.25, 0.78, 1]) {
        final left = geometry.roadLeftAt(y);
        final first = geometry.projectRoadX(1 / 3, y);
        final second = geometry.projectRoadX(2 / 3, y);
        final right = geometry.roadRightAt(y);

        expect(first - left, closeTo(second - first, 1e-9));
        expect(second - first, closeTo(right - second, 1e-9));
      }
    });

    test('road coordinates zero and one map to visible boundaries', () {
      for (final y in <double>[0, 0.5, 1]) {
        expect(
          geometry.projectRoadX(0, y),
          closeTo(geometry.roadLeftAt(y), 1e-9),
        );
        expect(
          geometry.projectRoadX(1, y),
          closeTo(geometry.roadRightAt(y), 1e-9),
        );
      }
    });
  });

  group('RacingGeometry collision', () {
    test('collision rect is 78 percent of the visible car rect', () {
      final obstacle = RacingObstacle(
        id: 1,
        kind: RacingObstacleKind.straightCar,
        x: 0.5,
        y: kRacingPlayerY,
      );
      final visible = geometry.obstacleVisibleRect(obstacle);
      final collision = geometry.obstacleCollisionRect(obstacle);

      expect(collision.width, closeTo(visible.width * 0.78, 1e-9));
      expect(collision.height, closeTo(visible.height * 0.78, 1e-9));
    });

    test('clear overlap collides', () {
      final obstacle = RacingObstacle(
        id: 1,
        kind: RacingObstacleKind.straightCar,
        x: 0.5,
        y: kRacingPlayerY,
      );

      expect(geometry.playerCollides(0.5, obstacle), isTrue);
    });

    test('visual edge touch outside shrunken hitboxes does not collide', () {
      final obstacle = RacingObstacle(
        id: 1,
        kind: RacingObstacleKind.straightCar,
        x: 0.65,
        y: kRacingPlayerY,
      );

      final playerVisible = geometry.playerVisibleRect(0.5);
      final obstacleVisible = geometry.obstacleVisibleRect(obstacle);
      expect(playerVisible.overlaps(obstacleVisible), isTrue);
      expect(geometry.playerCollides(0.5, obstacle), isFalse);
    });
  });
}
