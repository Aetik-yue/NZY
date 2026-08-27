import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/music/models/music_filename_policy.dart';

void main() {
  group('MusicFilenamePolicy.matches', () {
    test('匹配文件名开头的 yyzm，且不区分大小写', () {
      expect(MusicFilenamePolicy.matches('yyzm_小幸运.m4a'), isTrue);
      expect(MusicFilenamePolicy.matches('YYZM-生日快乐.MP3'), isTrue);
      expect(MusicFilenamePolicy.matches('YyZm晴天.flac'), isTrue);
    });

    test('中间或结尾出现 yyzm 时不匹配', () {
      expect(MusicFilenamePolicy.matches('我的录音_yyzm.m4a'), isFalse);
      expect(MusicFilenamePolicy.matches('普通yyzm歌曲.mp3'), isFalse);
      expect(MusicFilenamePolicy.matches('普通歌曲.mp3'), isFalse);
    });
  });

  group('MusicFilenamePolicy.displayTitle', () {
    test('隐藏前缀以及连续的空格、下划线和短横线', () {
      expect(MusicFilenamePolicy.displayTitle('yyzm_小幸运.m4a'), '小幸运');
      expect(MusicFilenamePolicy.displayTitle('YYZM-第一次录给你.mp3'), '第一次录给你');
      expect(MusicFilenamePolicy.displayTitle('yyzm 生日快乐.wav'), '生日快乐');
      expect(MusicFilenamePolicy.displayTitle('yyzm晴天.flac'), '晴天');
      expect(MusicFilenamePolicy.displayTitle('yyzm___晚安.m4a'), '晚安');
    });

    test('清理全角下划线、全角短横线和混合分隔符', () {
      expect(MusicFilenamePolicy.displayTitle('yyzm＿－ _-晚安.m4a'), '晚安');
    });

    test('仅有前缀或前缀加分隔符时回退为未命名录音', () {
      expect(MusicFilenamePolicy.displayTitle('yyzm.m4a'), '未命名录音');
      expect(MusicFilenamePolicy.displayTitle('YYZM___---.MP3'), '未命名录音');
    });

    test('只去掉最后一个扩展名', () {
      expect(
        MusicFilenamePolicy.displayTitle('yyzm_我们的.第一首歌.final.M4A'),
        '我们的.第一首歌.final',
      );
    });
  });
}
