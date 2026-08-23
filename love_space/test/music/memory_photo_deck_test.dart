import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/music/models/memory_photo_deck.dart';

void main() {
  test('一轮内展示全部 App 相册照片且不重复', () {
    final deck = MemoryPhotoDeck(random: Random(7));

    deck.updatePaths(['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg']);
    final shown = <String>{deck.current!};
    for (var i = 1; i < 4; i++) {
      shown.add(deck.advance()!);
    }

    expect(shown, {'a.jpg', 'b.jpg', 'c.jpg', 'd.jpg'});
  });

  test('新一轮第一张不会与上一轮最后一张立即重复', () {
    final deck = MemoryPhotoDeck(random: Random(11));
    deck.updatePaths(['a.jpg', 'b.jpg', 'c.jpg']);

    deck.advance();
    final lastOfCycle = deck.advance();
    final firstOfNextCycle = deck.advance();

    expect(firstOfNextCycle, isNot(lastOfCycle));
  });

  test('相册流刷新时保留仍有效的当前照片', () {
    final deck = MemoryPhotoDeck(random: Random(3));
    deck.updatePaths(['a.jpg', 'b.jpg', 'c.jpg']);
    final current = deck.current;

    deck.updatePaths(['new.jpg', 'a.jpg', 'b.jpg', 'c.jpg']);

    expect(deck.current, current);
    expect(deck.length, 4);
  });

  test('当前照片被删除后自动选择剩余照片', () {
    final deck = MemoryPhotoDeck(random: Random(5));
    deck.updatePaths(['a.jpg', 'b.jpg']);
    final removed = deck.current;
    final remaining = removed == 'a.jpg' ? 'b.jpg' : 'a.jpg';

    deck.updatePaths([remaining]);

    expect(deck.current, remaining);
    expect(deck.length, 1);
    expect(deck.advance(), remaining);
  });

  test('空相册返回 null，并对重复路径去重', () {
    final deck = MemoryPhotoDeck(random: Random(1));
    deck.updatePaths(['a.jpg', 'a.jpg']);
    expect(deck.length, 1);
    expect(deck.current, 'a.jpg');

    deck.updatePaths(const []);
    expect(deck.current, isNull);
    expect(deck.advance(), isNull);
  });
}
