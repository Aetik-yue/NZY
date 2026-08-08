/// 阳历节日问候表（月, 日, 文案）
///
/// ✏️ 想改文案 / 加节日，直接编辑此表即可（农历节日请自行换算为阳历近似日期）。
const List<(int, int, String)> festivalGreetings = [
  (1, 1, '元旦快乐，新的一年继续爱你 💖'),
  (2, 14, '情人节快乐，心里只有你 💘'),
  (3, 8, '女神节快乐，你永远是我的宝贝 🌸'),
  (5, 20, '520 快乐，我爱你 💕'),
  (12, 24, '平安夜快乐，愿你岁岁平安 🎄'),
  (12, 25, '圣诞节快乐，和你一起就很温暖 🎅'),
];

/// 周年问候模板（%d 会被替换为周年数）
const String anniversaryGreetingTemplate = '🎉 我们在一起 %d 周年啦！';

/// 根据当前时间返回问候语
class Greeting {
  /// 时段问候（无特殊节点时的默认文案）
  static String now() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，亲爱的';
    if (hour < 12) return '早上好，亲爱的';
    if (hour < 14) return '中午好，亲爱的';
    if (hour < 18) return '下午好，亲爱的';
    return '晚上好，亲爱的';
  }

  /// 特殊节点问候；无节点返回 null（调用方回退到 [now]）
  ///
  /// 优先级：在一起周年 > 阳历节日。
  static String? special(DateTime now, DateTime? togetherSince) {
    final anniversary = _anniversaryGreeting(now, togetherSince);
    if (anniversary != null) return anniversary;
    return _festivalGreeting(now);
  }

  /// 在一起周年：与 togetherSince 同月同日时返回周年文案
  static String? _anniversaryGreeting(DateTime now, DateTime? togetherSince) {
    if (togetherSince == null) return null;
    if (now.month != togetherSince.month || now.day != togetherSince.day) {
      return null;
    }
    final years = now.year - togetherSince.year;
    if (years <= 0) return null; // 起始当天不视为周年
    return anniversaryGreetingTemplate.replaceFirst('%d', '$years');
  }

  /// 阳历节日匹配（遍历配置表）
  static String? _festivalGreeting(DateTime now) {
    for (final (month, day, text) in festivalGreetings) {
      if (now.month == month && now.day == day) {
        return text;
      }
    }
    return null;
  }
}
