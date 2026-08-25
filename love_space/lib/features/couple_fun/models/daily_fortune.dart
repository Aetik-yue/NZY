/// 每日缘分签的固定文案。
class DailyFortune {
  const DailyFortune({
    required this.title,
    required this.verse,
    required this.tip,
    required this.action,
  });

  final String title;
  final String verse;
  final String tip;
  final String action;
}

/// 当天抽签的完整结果。
class DailyFortuneDraw {
  const DailyFortuneDraw({
    required this.fortune,
    required this.temperature,
    required this.luckyMoment,
  });

  final DailyFortune fortune;
  final int temperature;
  final String luckyMoment;
}

const dailyFortunes = <DailyFortune>[
  DailyFortune(
    title: '心照签',
    verse: '一句未说完的话，也有人替你轻轻接住。',
    tip: '今天适合把藏在心里的感谢说出来。',
    action: '认真夸对方一个平时容易忽略的优点',
  ),
  DailyFortune(
    title: '同行签',
    verse: '同看一程风景，寻常日子也会发亮。',
    tip: '并肩做件小事，比精心安排更有温度。',
    action: '一起散步十分钟，不带耳机',
  ),
  DailyFortune(
    title: '回甘签',
    verse: '旧日的小欢喜，会在今天悄悄回甘。',
    tip: '翻翻共同回忆，会发现被爱过的证据。',
    action: '找一张旧照片，说说当时的心情',
  ),
  DailyFortune(
    title: '拥抱签',
    verse: '风有一点急，好在怀抱仍是安稳的岸。',
    tip: '今天少一点分析，多一点陪伴。',
    action: '给对方一个至少十秒的拥抱',
  ),
  DailyFortune(
    title: '新鲜签',
    verse: '换一条回家的路，也能遇见新的浪漫。',
    tip: '轻微打破惯例，会带来意外的好心情。',
    action: '一起尝试一种没吃过的小食',
  ),
  DailyFortune(
    title: '坦白签',
    verse: '真心不必绕远路，温柔说出就有回声。',
    tip: '适合聊聊最近真正需要的是什么。',
    action: '用“我希望”开头说一个小愿望',
  ),
  DailyFortune(
    title: '慢慢签',
    verse: '不赶时间的爱，才看得见沿途花开。',
    tip: '今天不必把行程排满，留一点空白给彼此。',
    action: '把一顿饭吃慢一点，多聊一会儿',
  ),
  DailyFortune(
    title: '惊喜签',
    verse: '小小心意落在日常，便成了闪亮的星。',
    tip: '无需贵重，一个“我想到了你”就很好。',
    action: '悄悄准备对方喜欢的饮料或零食',
  ),
  DailyFortune(
    title: '和解签',
    verse: '先把手交给彼此，再一起解开小小的结。',
    tip: '今天适合放下输赢，确认你们站在同一边。',
    action: '主动说一句“我们一起想办法”',
  ),
  DailyFortune(
    title: '倾听签',
    verse: '被认真听见的心事，会慢慢长出勇气。',
    tip: '先听完，再回应；答案也许就在话语之间。',
    action: '问问对方今天最开心和最累的事',
  ),
  DailyFortune(
    title: '约定签',
    verse: '把未来说给彼此听，远方就有了轮廓。',
    tip: '适合定下一个不必宏大、却值得期待的计划。',
    action: '约定下一次只属于两个人的时间',
  ),
  DailyFortune(
    title: '晴暖签',
    verse: '今日宜靠近，宜分享，宜把喜欢再说一遍。',
    tip: '好情绪会传染，先成为那个微笑的人。',
    action: '发一条没有正事、只是想念的消息',
  ),
];

const _luckyMoments = <String>['早餐后', '午后', '日落时', '晚饭后', '睡前'];

/// 根据日期和情侣标识生成稳定结果：同一对情侣当天始终看到同一签。
DailyFortuneDraw drawDailyFortune(DateTime date, String coupleKey) {
  final day = '${date.year}-${date.month}-${date.day}';
  final seed = _stableHash('$day|$coupleKey');
  return DailyFortuneDraw(
    fortune: dailyFortunes[seed % dailyFortunes.length],
    temperature: 80 + seed % 21,
    luckyMoment:
        _luckyMoments[(seed ~/ dailyFortunes.length) % _luckyMoments.length],
  );
}

int _stableHash(String value) {
  int hash = 0x811c9dc5;
  for (final int codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
