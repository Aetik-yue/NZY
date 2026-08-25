/// 恋爱测试中的一道偏好题。
class LoveQuizQuestion {
  const LoveQuizQuestion({
    required this.prompt,
    required this.options,
  });

  final String prompt;
  final List<String> options;
}

/// 双方轮流作答的固定题库；答案没有对错，只比较偏好是否一致。
const loveQuizQuestions = <LoveQuizQuestion>[
  LoveQuizQuestion(
    prompt: '难得有一整天空闲，你最想怎么约会？',
    options: ['窝在家里看电影', '散步聊天看日落', '去吃收藏很久的店', '临时出发去小旅行'],
  ),
  LoveQuizQuestion(
    prompt: '发生小摩擦时，你更希望对方怎么做？',
    options: ['马上说开', '先各自冷静一下', '先抱抱再慢慢聊', '用一点幽默打破僵局'],
  ),
  LoveQuizQuestion(
    prompt: '纪念日收到哪种心意最让你开心？',
    options: ['一封认真写的信', '一起吃顿特别的饭', '惦记很久的实用礼物', '完全保密的惊喜安排'],
  ),
  LoveQuizQuestion(
    prompt: '理想周末的早晨是什么样？',
    options: ['一起睡到自然醒', '早起做一顿早餐', '出门逛逛晒太阳', '各做各的，晚点会合'],
  ),
  LoveQuizQuestion(
    prompt: '你最容易感受到爱的一刻是？',
    options: ['听到真诚的表达', '被主动拥抱和牵手', '对方默默帮我做好小事', '有一段不被打扰的相处时间'],
  ),
  LoveQuizQuestion(
    prompt: '一起规划一笔额外预算，你会优先用于？',
    options: ['旅行体验', '改善共同的小家', '存起来给未来', '各自买喜欢的东西'],
  ),
  LoveQuizQuestion(
    prompt: '如果对方情绪低落，你通常会？',
    options: ['认真听对方说完', '给出具体解决办法', '陪在身边但不追问', '带对方做点开心的事'],
  ),
  LoveQuizQuestion(
    prompt: '你最期待两个人共同养成哪个习惯？',
    options: ['每天分享一件小事', '定期一起运动', '每月安排一次约会', '一起为长期目标存钱'],
  ),
];

/// 一次恋爱测试的计算结果。
class LoveQuizResult {
  const LoveQuizResult({
    required this.matches,
    required this.total,
  });

  final int matches;
  final int total;

  int get percentage => total == 0 ? 0 : (matches * 100 / total).round();

  String get title {
    if (percentage >= 88) return '心有灵犀';
    if (percentage >= 63) return '天生拍档';
    if (percentage >= 38) return '默契养成中';
    return '不同频也浪漫';
  }

  String get message {
    if (percentage >= 88) return '很多小偏好都不谋而合，难怪你们总能接住彼此。';
    if (percentage >= 63) return '大方向很合拍，也保留了刚刚好的新鲜感。';
    if (percentage >= 38) return '有相似也有不同，多聊一次，就多懂彼此一点。';
    return '差异不是扣分项，它让你们一直有新的世界可以交换。';
  }
}

/// 比较双方答案；未完整作答时抛出参数错误，避免展示失真的结果。
LoveQuizResult scoreLoveQuiz(List<int> first, List<int> second) {
  if (first.length != second.length || first.isEmpty) {
    throw ArgumentError('双方必须完成相同数量的题目');
  }
  int matches = 0;
  for (int index = 0; index < first.length; index++) {
    if (first[index] == second[index]) matches++;
  }
  return LoveQuizResult(matches: matches, total: first.length);
}
