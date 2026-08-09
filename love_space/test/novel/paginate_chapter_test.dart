// 翻页分页纯函数单测：验证段距计入页高
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/novel/presentation/widgets/novel_paginator.dart';

void main() {
  // TextPainter 需要 binding 才能计算行度量
  TestWidgetsFlutterBinding.ensureInitialized();

  // TextStyle(height: 1.5) 会强制行高 = fontSize * 1.5，与字体无关，结果确定。
  const fontSize = 16.0;
  const lineHeight = 1.5;
  // 行高 = 24.0；availHeight = 120 -> 无段距时每页 5 行
  const availHeight = 120.0;
  // 宽度足够大，使每段单行不自动换行
  const width = 600.0;

  test('空内容返回单页空串', () {
    expect(paginateChapter('', width, availHeight, fontSize, lineHeight, 12),
        ['']);
  });

  test('单段（无换行）内容：段距不影响分页', () {
    // 一段长文本，仅自动换行，无段落边界 -> 段距不计入
    final content = 'abcdefghijklmnopqrstuvwxyz' * 20;
    final noSpacing =
        paginateChapter(content, width, availHeight, fontSize, lineHeight, 0);
    final bigSpacing =
        paginateChapter(content, width, availHeight, fontSize, lineHeight, 50);
    expect(noSpacing.length, bigSpacing.length);
  });

  test('多段内容：段距增大时页数增加', () {
    // 6 段，每段单行；无段距时每页 5 行 -> 2 页
    const content = 'a\nb\nc\nd\ne\nf';
    final noSpacing =
        paginateChapter(content, width, availHeight, fontSize, lineHeight, 0);
    final bigSpacing =
        paginateChapter(content, width, availHeight, fontSize, lineHeight, 80);

    // 无段距：6 行 / 5 行每页 = 2 页
    expect(noSpacing.length, 2);
    // 大段距（80 >> 行高 24）使多数段落独占一页 -> 页数明显增多
    expect(bigSpacing.length, greaterThan(noSpacing.length));
    expect(bigSpacing.length, 6);
  });

  test('分页切片拼接还原原内容', () {
    const content = 'a\nb\nc\nd\ne\nf';
    final pages =
        paginateChapter(content, width, availHeight, fontSize, lineHeight, 0);
    expect(pages.join(), content);
  });
}
