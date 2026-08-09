import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
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

  /// 拖动回调（cellW 由内部按屏宽计算后传入）
  final void Function(DragUpdateDetails d, double cellW) onPanUpdate;
  final VoidCallback onRotate;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onRestart;
  final VoidCallback onHoldSwap;
  final VoidCallback onHardDrop;

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
    required this.onPanUpdate,
    required this.onRotate,
    required this.onStart,
    required this.onPause,
    required this.onRestart,
    required this.onHoldSwap,
    required this.onHardDrop,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
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
                        // 中：游戏场
                        TetrisGameField(
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
                          onPanUpdate: (d) => onPanUpdate(d, cellW),
                          onTap: onRotate,
                          onStart: onStart,
                          onRestart: onRestart,
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
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
