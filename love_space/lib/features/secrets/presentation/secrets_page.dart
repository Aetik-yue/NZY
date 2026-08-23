import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/secret_message.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';

/// 悄悄话页（双人私密聊天）
///
/// 消息双向同步（走 SyncEngine 的 message 类型）；进入页面即全部标记已读；
/// 发送后立即触发一次同步，让 TA 尽快收到。
class SecretsPage extends ConsumerStatefulWidget {
  const SecretsPage({super.key});

  @override
  ConsumerState<SecretsPage> createState() => _SecretsPageState();
}

class _SecretsPageState extends ConsumerState<SecretsPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // 进入即已读
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(secretMessageRepositoryProvider).markAllRead();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(secretMessageRepositoryProvider).add(SecretMessage()
        ..content = content
        ..createdAt = DateTime.now());
      // 立即同步，让对方尽快收到
      unawaited(
        ref
            .read(syncEngineProvider)
            .syncOnce()
            .catchError((Object e) => debugPrint('[Secrets] 同步失败: $e')),
      );
      if (!mounted) return;
      _controller.clear();
    } catch (e) {
      debugPrint('[Secrets] 发送失败: $e');
      if (mounted) AppSnackbar.show(context, '发送失败，请重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(secretMessagesProvider);
    final myUid = ref.watch(syncStatusProvider).valueOrNull?.uid;

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
        title: Text('悄悄话', style: AppTextStyles.titleMedium),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.accentRose),
            tooltip: '清空记录',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('清空悄悄话？'),
                  content: const Text('将删除本机记录，云端记录也会同步删除。此操作无法撤销。'),
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
                      child: const Text('清空'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !mounted) return;
              final repo = ref.read(secretMessageRepositoryProvider);
              final items = await repo.getAll();
              for (final m in items) {
                if (m.cloudId != null) {
                  ref.read(syncEngineProvider).markDeleted(m.cloudId!);
                }
                await repo.delete(m.id);
              }
              unawaited(ref
                  .read(syncEngineProvider)
                  .syncOnce()
                  .catchError((Object e) => debugPrint('[Secrets] 同步失败: $e')));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const _EmptyState();
                  }
                  // 倒序显示：最新在底部
                  final reversed = messages.reversed.toList();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: reversed.length,
                    itemBuilder: (_, i) {
                      final m = reversed[i];
                      final isMine = m.ownerId == null || m.ownerId == myUid;
                      return _MessageBubble(message: m, isMine: isMine);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Center(child: Text('加载失败')),
              ),
            ),
            // 底部输入栏
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: AppColors.bgCard,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '说句悄悄话...',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: AppColors.bgPrimary,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusPill),
                          borderSide:
                              const BorderSide(color: AppColors.borderSoft),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusPill),
                          borderSide:
                              const BorderSide(color: AppColors.accentRose),
                        ),
                      ),
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        gradient: AppColors.pinkButtonGradient,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 消息气泡
class _MessageBubble extends StatelessWidget {
  final SecretMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          gradient: isMine ? AppColors.pinkButtonGradient : null,
          color: isMine ? null : AppColors.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppColors.radiusMd),
            topRight: const Radius.circular(AppColors.radiusMd),
            bottomLeft: Radius.circular(isMine ? AppColors.radiusMd : 4),
            bottomRight: Radius.circular(isMine ? 4 : AppColors.radiusMd),
          ),
          border: isMine ? null : Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: (isMine
                  ? AppTextStyles.body.copyWith(color: Colors.white)
                  : AppTextStyles.body),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: AppTextStyles.label.copyWith(
                color: isMine ? Colors.white70 : AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final today = DateUtilsX.today();
    final d = DateTime(t.year, t.month, t.day);
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (d == today) return hm;
    return '${t.month}月${t.day}日 $hm';
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined,
              size: 64, color: AppColors.accentPinkSoft),
          const SizedBox(height: 16),
          Text('还没有悄悄话', style: AppTextStyles.titleSmall),
          const SizedBox(height: 6),
          Text('说一句只属于你们的话吧 💌', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
