import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import 'racing_exit_dialog.dart';
import 'racing_game_engine.dart';
import 'racing_geometry.dart';
import 'racing_hud.dart';
import 'racing_model.dart';
import 'racing_painter.dart';
import 'racing_status_overlay.dart';

/// 竖屏公路闪避游戏页。
class RacingPage extends ConsumerStatefulWidget {
  const RacingPage({super.key, this.engine});

  final RacingGameEngine? engine;

  @override
  ConsumerState<RacingPage> createState() => _RacingPageState();
}

class _RacingPageState extends ConsumerState<RacingPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const RacingGeometry _geometry = RacingGeometry();

  late final RacingGameEngine _engine;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _dragStartX = 0;
  double _dragStartPlayerX = 0.5;
  double _stageBannerRemaining = 0;
  int _lastStage = 1;
  int _sessionBest = 0;
  bool _newRecord = false;
  bool _scoreHandled = false;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? RacingGameEngine();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pause();
    }
  }

  void _startTicker() {
    _lastTick = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _stopTicker() {
    if (_ticker.isActive) _ticker.stop();
    _lastTick = Duration.zero;
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.066) return;

    final previousStatus = _engine.status;
    final previousStage = _engine.stage;
    _engine.update(dt);
    if (_stageBannerRemaining > 0) {
      _stageBannerRemaining = max(0, _stageBannerRemaining - dt);
    }
    if (_engine.stage > previousStage) {
      _lastStage = _engine.stage;
      _stageBannerRemaining = 1.2;
    }
    if (previousStatus != RacingStatus.crashed &&
        _engine.status == RacingStatus.crashed) {
      HapticFeedback.mediumImpact();
    }
    if (previousStatus != RacingStatus.gameOver &&
        _engine.status == RacingStatus.gameOver) {
      _stopTicker();
      _saveResult(_runId);
    }
    setState(() {});
  }

  void _start() {
    _runId++;
    _scoreHandled = false;
    _newRecord = false;
    _lastStage = 1;
    _stageBannerRemaining = 0;
    _engine.start();
    _startTicker();
    setState(() {});
  }

  void _restart() {
    _runId++;
    _scoreHandled = false;
    _newRecord = false;
    _lastStage = 1;
    _stageBannerRemaining = 0;
    _engine.restart();
    _startTicker();
    setState(() {});
  }

  void _pause() {
    if (_engine.status != RacingStatus.playing &&
        _engine.status != RacingStatus.countdown) {
      return;
    }
    _engine.pause();
    _stopTicker();
    if (mounted) setState(() {});
  }

  void _resume() {
    _engine.resume();
    _startTicker();
    setState(() {});
  }

  Future<void> _saveResult(int completedRunId) async {
    if (_scoreHandled) return;
    _scoreHandled = true;
    final result = _engine.distanceFloor;
    try {
      final isNew =
          await ref.read(racingScoreRepositoryProvider).saveIfHigher(result);
      if (!mounted) return;
      if (isNew) {
        _sessionBest = max(_sessionBest, result);
        if (completedRunId == _runId &&
            _engine.status == RacingStatus.gameOver) {
          _newRecord = true;
        }
        ref.invalidate(racingBestDistanceProvider);
      }
      setState(() {});
    } catch (error) {
      debugPrint('Save racing best distance error: $error');
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!_acceptsDrag) return;
    _dragStartX = details.localPosition.dx;
    _dragStartPlayerX = _engine.playerX;
  }

  void _onPanUpdate(DragUpdateDetails details, double width) {
    if (!_acceptsDrag) return;
    final roadWidth = _geometry.roadWidthAt(kRacingPlayerY) * width;
    final deltaRoad = (details.localPosition.dx - _dragStartX) / roadWidth;
    _engine.setPlayerTarget(_dragStartPlayerX + deltaRoad);
    setState(() {});
  }

  bool get _acceptsDrag =>
      _engine.status == RacingStatus.playing ||
      _engine.status == RacingStatus.countdown;

  bool get _requiresExitConfirmation =>
      _engine.status == RacingStatus.playing ||
      _engine.status == RacingStatus.countdown ||
      _engine.status == RacingStatus.paused;

  Future<void> _requestExit() async {
    if (!_requiresExitConfirmation) {
      _exitNow();
      return;
    }
    _pause();
    final confirmed = await showRacingExitDialog(context);
    if (!mounted || !confirmed) return;
    _exitNow();
  }

  void _exitNow() {
    _stopTicker();
    Navigator.of(context).pop();
  }

  int _bestDistance(AsyncValue<int> bestAsync) =>
      max(_sessionBest, bestAsync.valueOrNull ?? 0);

  @override
  Widget build(BuildContext context) {
    final bestAsync = ref.watch(racingBestDistanceProvider);
    final bestDistance = _bestDistance(bestAsync);
    final canPop = !_requiresExitConfirmation;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.racingGrass,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const ValueKey('racing_canvas'),
                  painter: RacingPainter(engine: _engine),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: constraints.maxHeight * 0.45,
                  child: GestureDetector(
                    key: const ValueKey('racing_drag_area'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _onPanStart,
                    onPanUpdate: (details) =>
                        _onPanUpdate(details, constraints.maxWidth),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: RacingHud(
                    distance: _engine.distanceFloor,
                    bestDistance: bestDistance,
                    stage: _engine.stage,
                    onBack: _requestExit,
                    onPause: _pause,
                    canPause: _acceptsDrag,
                  ),
                ),
                if (_stageBannerRemaining > 0)
                  Positioned(
                    top: 88,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard.withValues(alpha: 0.88),
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusPill),
                          ),
                          child: Text(
                            '阶段 $_lastStage · 加速中',
                            style: AppTextStyles.titleXs
                                .copyWith(color: AppColors.accentRose),
                          ),
                        ),
                      ),
                    ),
                  ),
                RacingStatusOverlay(
                  status: _engine.status,
                  countdown: _engine.countdownValue,
                  distance: _engine.distanceFloor,
                  bestDistance: bestDistance,
                  newRecord: _newRecord,
                  onStart: _start,
                  onResume: _resume,
                  onRestart: _restart,
                  onExit: _exitNow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
