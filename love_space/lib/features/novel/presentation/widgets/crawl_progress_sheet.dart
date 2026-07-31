import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 爬取进度面板
///
/// 显示当前爬取操作的进度（搜索中 / 抓取详情 / 抓取章节 N/M），
/// 完成后自动关闭（带防重守卫，避免与调用方手动关闭叠加造成重复 pop）。
class CrawlProgressSheet extends ConsumerStatefulWidget {
  final String title;

  const CrawlProgressSheet({super.key, this.title = '正在获取小说'});

  /// 弹出进度面板
  ///
  /// 返回 Future，面板关闭时完成；成功关闭返回 true，失败/取消返回 false。
  static Future<bool?> show(BuildContext context, {String title = '正在获取小说'}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CrawlProgressSheet(title: title),
    );
  }

  @override
  ConsumerState<CrawlProgressSheet> createState() => _CrawlProgressSheetState();
}

class _CrawlProgressSheetState extends ConsumerState<CrawlProgressSheet> {
  /// 是否已自动关闭（防止 status 连续为 success/failed 时重复 pop）
  bool _autoClosed = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(crawlStatusProvider);

    // 成功或失败后自动关闭（只触发一次）
    if (!_autoClosed && (status.state == 'success' || status.state == 'failed')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoClosed) return;
        _autoClosed = true;
        Navigator.of(context).pop(status.state == 'success');
      });
    }

    final hasProgress = status.total != null && status.total! > 0;
    final progress = hasProgress
        ? ((status.current ?? 0) / status.total!).clamp(0.0, 1.0)
        : (status.state == 'fetching' || status.state == 'searching')
            ? null
            : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            if (status.state == 'success')
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accentRose, size: 48)
            else if (status.state == 'failed')
              const Icon(Icons.error_rounded,
                  color: AppColors.accentRose, size: 48)
            else
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accentRose,
                ),
              ),

            const SizedBox(height: 16),

            // 标题
            Text(widget.title, style: AppTextStyles.titleMedium),

            const SizedBox(height: 8),

            // 进度描述
            Text(
              status.message ?? _defaultMessage(status.state),
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // 进度条
            if (hasProgress)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.accentPinkSoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accentRose),
                ),
              )
            else if (status.state == 'fetching' || status.state == 'searching')
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppColors.accentPinkSoft,
                  valueColor: AlwaysStoppedAnimation(AppColors.accentRose),
                ),
              ),

            // 进度数字
            if (hasProgress) ...[
              const SizedBox(height: 8),
              Text(
                '${status.current}/${status.total}',
                style: AppTextStyles.label,
              ),
            ],

            const SizedBox(height: 16),

            // 取消按钮
            if (status.state != 'success' && status.state != 'failed')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // 通知仓库取消爬取，然后关闭面板
                    ref.read(crawlRepositoryProvider).cancel();
                    ref.read(crawlStatusProvider.notifier).state =
                        CrawlStatus.failed;
                    Navigator.of(context).pop(false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderSoft),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                  child: Text(
                    '取消',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _defaultMessage(String state) {
    switch (state) {
      case 'searching':
        return '正在搜索...';
      case 'fetching':
        return '正在获取内容...';
      case 'success':
        return '完成';
      case 'failed':
        return '操作失败';
      default:
        return '';
    }
  }
}
