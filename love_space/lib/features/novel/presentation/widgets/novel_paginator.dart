import 'package:flutter/material.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 翻页模式分页（纯函数，计入段距）
///
/// 用 TextPainter 行度量按行分页；段末行（源串对应位置为 `\n`）之后插入
/// [paragraphSpacing] 额外间距，计入下一行起始高度，保证段距不被截断。
/// 以「行」为分页粒度保证不截断字符；空内容返回单页空串。
List<String> paginateChapter(
  String content,
  double width,
  double availHeight,
  double fontSize,
  double lineHeight,
  double paragraphSpacing,
) {
  if (content.isEmpty) return [''];
  final painter = TextPainter(
    text: TextSpan(
      text: content,
      style: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        fontFamily: AppTextStyles.cjkFontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: null,
  );
  painter.layout(maxWidth: width);
  final metrics = painter.computeLineMetrics();
  if (metrics.isEmpty) return [content];
  final lineHeightPx = metrics.first.height;
  if (lineHeightPx <= 0) return [content];

  // 标记段末行：取下一行起始 offset，若前一字符为 \n 则当前行段末
  final n = metrics.length;
  final endsParagraph = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    final nextStart = (i + 1 < n)
        ? painter
            .getPositionForOffset(
                Offset(0, metrics[i + 1].baseline - lineHeightPx * 0.5))
            .offset
        : content.length;
    if (nextStart > 0 && content.substring(nextStart - 1).startsWith('\n')) {
      endsParagraph[i] = true;
    }
  }

  // 按累计高度分页（首页首行不加段距；非首行且前一行段末才加段距）
  final pages = <String>[];
  var pageStart = 0;
  var used = 0.0;
  for (var i = 0; i < n; i++) {
    final firstOnPage = i == pageStart;
    final gap =
        firstOnPage ? 0.0 : (endsParagraph[i - 1] ? paragraphSpacing : 0.0);
    if (!firstOnPage && used + gap + lineHeightPx > availHeight) {
      pages.add(_slice(content, painter, metrics, pageStart, i));
      pageStart = i;
      used = lineHeightPx;
    } else {
      used += gap + lineHeightPx;
    }
  }
  if (pageStart < n) {
    pages.add(_slice(content, painter, metrics, pageStart, n));
  }
  return pages;
}

/// 取 [start, end) 行的文本切片（复用 offset 计算）
String _slice(
  String content,
  TextPainter painter,
  List<LineMetrics> m,
  int start,
  int end,
) {
  final startOffset = painter
      .getPositionForOffset(Offset(0, m[start].baseline - m.first.height * 0.5))
      .offset;
  final endOffset = end < m.length
      ? painter
          .getPositionForOffset(
              Offset(0, m[end].baseline - m.first.height * 0.5))
          .offset
      : content.length;
  return content.substring(startOffset, endOffset);
}
