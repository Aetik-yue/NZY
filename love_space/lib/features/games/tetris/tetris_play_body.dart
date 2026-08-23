import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'tetris_control_pad.dart';
import 'tetris_model.dart';
import 'tetris_widgets.dart';

/// 游戏整屏：PopScope + Scaffold + AppBar + 主区
///
/// 从 [TetrisPage] 抽出，承载 HUD / 左右栏 / 游戏场的自适应布局，
/// 并负责返回时停止 Ticker（[onPop]）。
class TetrisPlayBody extends StatelessWidget {
  final int score;
  final int level;
  final int lines;
  final TetrominoType? hold;
  final List<TetrominoType> nextQueue;
  final TetrisBoard board;
  final Piece? current;
  final Set<int> clearingRows;
  final double clearProgress;
  final TetrisStatus status;

  /// 水平拖动回调（左右移动，cellW 由内部按屏宽计算后传入）
  final void Function(DragUpdateDetails d, double cellW) onHorizontalDrag;

  /// 垂直拖动回调（软降，cellW 由内部按屏宽计算后传入）
  final void Function(DragUpdateDetails d, double cellW) onVerticalDrag;

  /// 控制区按钮回调（街机式操作，与拖动并存）
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onRotate;
  final VoidCallback onSoftDrop;
  final VoidCallback onHardDrop;

  /// 控制区是否可用（非游戏中置灰）
  final bool enabled;

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onRestart;
  final VoidCallback onHoldSwap;

  /// 返回转场期间停止动画循环
  final VoidCallback onPop;

  const TetrisPlayBody({
    super.key,
    required this.score,
    required this.level,
    required this.lines,
    required this.hold,
    required this.nextQueue,
    required this.board,
    required this.current,
    required this.clearingRows,
    required this.clearProgress,
    required this.status,
    required this.onHorizontalDrag,
    required this.onVerticalDrag,
    required this.onLeft,
    required this.onRight,
    required this.onRotate,
    required this.onSoftDrop,
    required this.onHardDrop,
    required this.enabled,
    required this.onStart,
    required this.onPause,
    required this.onRestart,
    required this.onHoldSwap,
    required this.onPop,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) onPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: TetrisAppBar(
          status: status,
          onStart: onStart,
          onPause: onPause,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final fieldW = c.maxWidth * 0.62;
              final cellW = fieldW / kTetrisCols;
              final fieldH = cellW * kTetrisRows;
              return Column(
                children: [
                  // HUD
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TetrisHud(label: '分数', value: '$score'),
                        TetrisHud(label: '级别', value: '$level'),
                        TetrisHud(label: '行数', value: '$lines'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左：Hold + 按钮
                        TetrisSideColumn(
                          width: c.maxWidth * 0.19,
                          children: [
                            TetrisHoldPanel(title: 'HOLD', type: hold),
                            const SizedBox(height: 12),
                            TetrisActionButton(
                              label: 'HOLD',
                              background: AppColors.bgBlush,
                              onTap: onHoldSwap,
                            ),
                          ],
                        ),
                        // 中：游戏场（RepaintBoundary 隔离每帧重绘，修复 #11）
                        RepaintBoundary(
                          child: TetrisGameField(
                            fieldW: fieldW,
                            fieldH: fieldH,
                            cellW: cellW,
                            board: board,
                            current: current,
                            ghostRow: ghostRow(board, current),
                            clearingRows: clearingRows,
                            clearProgress: clearProgress,
                            status: status,
                            score: score,
                            level: level,
                            lines: lines,
                            onHorizontalDragUpdate: (d) =>
                                onHorizontalDrag(d, cellW),
                            onVerticalDragUpdate: (d) =>
                                onVerticalDrag(d, cellW),
                            onStart: onStart,
                            onRestart: onRestart,
                          ),
                        ),
                        // 右：Next 队列 + Hard Drop
                        TetrisSideColumn(
                          width: c.maxWidth * 0.19,
                          children: [
                            TetrisNextPanel(queue: nextQueue),
                            const SizedBox(height: 12),
                            TetrisActionButton(
                              label: 'DROP',
                              background: AppColors.accentRose,
                              onTap: onHardDrop,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 底部：街机控制区（← / ↻ / → / ↓ / DROP）
                  TetrisControlPad(
                    onLeft: onLeft,
                    onRight: onRight,
                    onRotate: onRotate,
                    onSoftDrop: onSoftDrop,
                    onHardDrop: onHardDrop,
                    enabled: enabled,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
