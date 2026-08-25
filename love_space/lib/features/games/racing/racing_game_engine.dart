import 'racing_geometry.dart';
import 'racing_model.dart';
import 'racing_obstacle_generator.dart';

/// 纯逻辑游戏引擎；页面只负责把真实帧时间和手势输入传入。
class RacingGameEngine {
  RacingGameEngine({
    RacingObstacleSource? obstacleSource,
    RacingGeometry geometry = const RacingGeometry(),
  })  : _obstacleSource = obstacleSource ?? RacingObstacleGenerator(),
        _geometry = geometry {
    _obstacleSource.reset(_playerX);
  }

  final RacingObstacleSource _obstacleSource;
  final RacingGeometry _geometry;
  final List<RacingObstacle> _obstacles = [];

  RacingStatus _status = RacingStatus.ready;
  RacingStatus _pausedFrom = RacingStatus.playing;
  double _elapsedSeconds = 0;
  double _distanceMeters = 0;
  double _playerX = 0.5;
  double _playerTargetX = 0.5;
  double _countdownRemaining = 3;
  double _crashRemaining = 0;
  double _spawnIn = 0.2;
  double _roadOffset = 0;

  RacingStatus get status => _status;
  double get elapsedSeconds => _elapsedSeconds;
  double get distanceMeters => _distanceMeters;
  int get distanceFloor => _distanceMeters.floor();
  double get playerX => _playerX;
  double get roadOffset => _roadOffset;
  int get stage => racingStageAt(_elapsedSeconds);
  double get roadSpeed => racingRoadSpeedAt(_elapsedSeconds);
  List<RacingObstacle> get obstacles => _obstacles;
  int get countdownValue => _countdownRemaining.ceil().clamp(1, 3).toInt();
  double get crashProgress =>
      (1 - _crashRemaining / kRacingCrashDuration).clamp(0.0, 1.0);

  void start() {
    if (_status != RacingStatus.ready) return;
    _beginRun();
  }

  void restart() => _beginRun();

  void _beginRun() {
    _status = RacingStatus.countdown;
    _elapsedSeconds = 0;
    _distanceMeters = 0;
    _playerX = 0.5;
    _playerTargetX = 0.5;
    _countdownRemaining = 3;
    _crashRemaining = 0;
    _spawnIn = 0.2;
    _roadOffset = 0;
    _obstacles.clear();
    _obstacleSource.reset(_playerX);
  }

  void pause() {
    if (_status != RacingStatus.playing && _status != RacingStatus.countdown) {
      return;
    }
    _pausedFrom = _status;
    _status = RacingStatus.paused;
  }

  void resume() {
    if (_status != RacingStatus.paused) return;
    _status = _pausedFrom;
  }

  void setPlayerTarget(double value) {
    const halfWidth = kRacingPlayerWidthRoad / 2;
    _playerTargetX = value.clamp(halfWidth, 1 - halfWidth).toDouble();
  }

  void update(double dtSeconds) {
    if (dtSeconds <= 0 || dtSeconds > 0.066) return;
    if (_status == RacingStatus.countdown) {
      _movePlayer(dtSeconds);
      _countdownRemaining -= dtSeconds;
      if (_countdownRemaining <= 0) _status = RacingStatus.playing;
      return;
    }
    if (_status == RacingStatus.playing) {
      _updatePlaying(dtSeconds);
      return;
    }
    if (_status == RacingStatus.crashed) {
      _crashRemaining -= dtSeconds;
      if (_crashRemaining <= 0) _status = RacingStatus.gameOver;
    }
  }

  void _updatePlaying(double dtSeconds) {
    _movePlayer(dtSeconds);
    _elapsedSeconds += dtSeconds;
    _distanceMeters += racingDistanceSpeedAt(_elapsedSeconds) * dtSeconds;
    _roadOffset = (_roadOffset + roadSpeed * dtSeconds) % 1;

    for (final obstacle in _obstacles) {
      obstacle.age += dtSeconds;
      obstacle.y += roadSpeed * dtSeconds;
      _updateLaneChange(obstacle);
    }
    _obstacles.removeWhere((obstacle) => obstacle.y > 1.16);

    _spawnIn -= dtSeconds;
    if (_spawnIn <= 0) {
      final reactionTime = (kRacingPlayerY - kRacingSpawnY) / roadSpeed;
      final batch = _obstacleSource.generate(
        stage: stage,
        passTime: _elapsedSeconds + reactionTime,
        playerX: _playerX,
      );
      _obstacles.addAll(batch.obstacles);
      _spawnIn += _obstacleSource.nextSpawnDelay(stage);
    }

    if (_obstacles.any((item) => _geometry.playerCollides(_playerX, item))) {
      _status = RacingStatus.crashed;
      _crashRemaining = kRacingCrashDuration;
    }
  }

  void _movePlayer(double dtSeconds) {
    final delta = _playerTargetX - _playerX;
    final maxStep = kRacingPlayerMaxSpeed * dtSeconds;
    if (delta.abs() <= maxStep) {
      _playerX = _playerTargetX;
    } else {
      _playerX += delta.sign * maxStep;
    }
  }

  void _updateLaneChange(RacingObstacle obstacle) {
    if (obstacle.kind != RacingObstacleKind.laneChangingCar ||
        obstacle.age <= obstacle.warningDuration) {
      return;
    }
    final raw = ((obstacle.age - obstacle.warningDuration) /
            obstacle.laneChangeDuration)
        .clamp(0.0, 1.0);
    final eased = raw * raw * (3 - 2 * raw);
    obstacle.x = obstacle.startX + (obstacle.targetX - obstacle.startX) * eased;
  }
}
