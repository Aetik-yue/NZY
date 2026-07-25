// 冒烟测试：验证应用能正常构建并渲染首页
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:love_space/app/app.dart';

void main() {
  testWidgets('App renders home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LoveSpaceApp()),
    );
    await tester.pumpAndSettle();

    // 验证首页问候语存在
    expect(find.text('早上好，亲爱的'), findsOneWidget);
    // 验证底部导航 Tab 标签存在
    expect(find.text('时光'), findsWidgets);
    expect(find.text('相册'), findsWidgets);
  });
}
