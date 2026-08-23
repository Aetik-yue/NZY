import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';

/// 双人同步配对页
///
/// 支持：创建房间（生成情侣码）/ 输入码加入 / 解绑。
/// 未配置 SCF URL/同步密钥时显示配置引导。
class SyncPairingPage extends ConsumerStatefulWidget {
  const SyncPairingPage({super.key});

  @override
  ConsumerState<SyncPairingPage> createState() => _SyncPairingPageState();
}

class _SyncPairingPageState extends ConsumerState<SyncPairingPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await ref.read(syncEngineProvider).createRoom();
      if (!mounted) return;
      AppSnackbar.show(context, '房间已创建，告诉 TA 你的情侣码：$code 💕');
    } catch (e) {
      debugPrint('[SyncPairingPage] 创建房间失败: $e');
      if (mounted) AppSnackbar.show(context, '创建失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      AppSnackbar.show(context, '请输入 6 位情侣码');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(syncEngineProvider).joinRoom(code);
      if (!mounted) return;
      AppSnackbar.show(context, '绑定成功，你们的数据开始同步啦 💕');
    } catch (e) {
      debugPrint('[SyncPairingPage] 加入房间失败: $e');
      if (mounted) AppSnackbar.show(context, '加入失败，请检查情侣码或网络');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解绑房间？'),
        content: const Text('解绑后你们将不再自动同步（云端数据会保留，对方仍可见）。确定解绑吗？'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSheet),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
            ),
            child: const Text('解绑'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(syncEngineProvider).leaveRoom();
      if (!mounted) return;
      AppSnackbar.show(context, '已解绑，数据恢复为仅本机可见');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final isConfigured = status?.isConfigured ?? false;
    final isPaired = status?.isPaired ?? false;
    final roomCode = status?.roomCode;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('双人同步', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 状态卡
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isPaired
                  ? AppColors.pinkButtonGradient
                  : AppColors.headerGradient,
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowPinkMedium,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  isPaired ? Icons.favorite_rounded : Icons.sync_rounded,
                  size: 40,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  isPaired
                      ? '已绑定：房间 ${roomCode ?? ''}'
                      : (isConfigured ? '还没有绑定小伙伴' : '双人同步未启用'),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textOnPink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaired
                      ? '你与 TA 的数据将自动同步共享'
                      : (isConfigured
                          ? '创建房间或输入 TA 的情侣码'
                          : '需配置同步服务 URL 与密钥后启用（见项目文档）'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!isConfigured)
            // 未配置引导
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.accentRose, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '请通过启动命令注入同步配置：\nflutter run --dart-define=SYNC_API_URL=函数URL --dart-define=SYNC_SECRET=同步密钥',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else if (!isPaired) ...[
            // 创建房间
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _busy ? null : _createRoom,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(_busy ? '正在创建...' : '创建房间',
                    style: AppTextStyles.body.copyWith(color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.borderSoft)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('或加入 TA 的房间', style: AppTextStyles.label),
                ),
                const Expanded(child: Divider(color: AppColors.borderSoft)),
              ],
            ),
            const SizedBox(height: 16),
            // 输入码加入
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '输入 6 位情侣码',
                      hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide:
                            const BorderSide(color: AppColors.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide:
                            const BorderSide(color: AppColors.accentRose),
                      ),
                    ),
                    style: AppTextStyles.body.copyWith(
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                    onSubmitted: (_) => _joinRoom(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _joinRoom,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentRose,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                    ),
                    child: const Icon(Icons.link_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ] else ...[
            // 已配对：房间码展示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text('你的情侣码', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Text(
                    roomCode ?? '',
                    style: AppTextStyles.heroNumber.copyWith(
                      fontSize: 40,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status?.lastSyncAt == null
                        ? '尚未同步'
                        : '上次同步：${_formatTime(status!.lastSyncAt!)}',
                    style: AppTextStyles.label,
                  ),
                  if (status?.isSyncing ?? false) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('同步中...', style: AppTextStyles.label),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _leaveRoom,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('解绑房间'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accentRose),
                  foregroundColor: AppColors.accentRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '同步范围：愿望清单、备忘录、时光线、打卡、纪念日、悄悄话和相册。\n数据仅在你的房间内可见，未配置云端时 App 保持纯本地可用。',
            style: AppTextStyles.label,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${t.month}月${t.day}日 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
