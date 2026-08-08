import 'package:flutter/material.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 翻页模式分页算法（纯函数）
///
/// 用 TextPainter 行度量按行数分页，返回每页的文本切片。
/// 以"行"为分页粒度保证不截断字符；空内容返回单页空串。
List<String> paginateChapter(
  String content,
  double width,
  double availHeight,
  double fontSize,
  double lineHeight,
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
  final linesPerPage = (availHeight / lineHeightPx).floor();
  if (linesPerPage <= 0) return [content];

  final pages = <String>[];
  for (var start = 0; start < metrics.length; start += linesPerPage) {
    final end = (start + linesPerPage) < metrics.length
        ? start + linesPerPage
        : metrics.length;
    final startOffset = painter
        .getPositionForOffset(
            Offset(0, metrics[start].baseline - lineHeightPx * 0.5))
        .offset;
    final endOffset = end < metrics.length
        ? painter
            .getPositionForOffset(
                Offset(0, metrics[end].baseline - lineHeightPx * 0.5))
            .offset
        : content.length;
    pages.add(content.substring(startOffset, endOffset));
  }
  return pages;
}
