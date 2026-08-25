import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:love_space/data/models/memo.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/features/memo/presentation/memo_page.dart';

void main() {
  Memo todo(String content, {required bool done}) => Memo()
    ..id = content.hashCode
    ..content = content
    ..author = 1
    ..isPinned = false
    ..colorValue = 0xFFFF8FB1
    ..createdAt = DateTime(2026, 8, 26)
    ..done = done
    ..priority = TodoPriority.none;

  testWidgets('待办页默认聚焦待完成并可回看已完成', (tester) async {
    final items = [
      todo('买牛奶', done: false),
      todo('订好酒店', done: true),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memosProvider.overrideWith((ref) => Stream.value(items)),
        ],
        child: const MaterialApp(home: MemoPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还有 1 件事等你完成'), findsOneWidget);
    expect(find.text('买牛奶', findRichText: true), findsOneWidget);
    expect(find.text('订好酒店', findRichText: true), findsNothing);
    expect(find.text('待完成 1'), findsOneWidget);
    expect(find.text('已完成 1'), findsOneWidget);

    await tester.tap(find.text('已完成 1'));
    await tester.pumpAndSettle();

    expect(find.text('买牛奶', findRichText: true), findsNothing);
    expect(find.text('订好酒店', findRichText: true), findsOneWidget);
  });

  testWidgets('待办页默认只展示一个快速输入和两种状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memosProvider.overrideWith((ref) => Stream.value(<Memo>[])),
        ],
        child: const MaterialApp(home: MemoPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_todo_input')), findsOneWidget);
    expect(find.byKey(const Key('quick_todo_add')), findsOneWidget);
    expect(find.textContaining('全部'), findsNothing);
    expect(find.textContaining('作者'), findsNothing);
  });
}
