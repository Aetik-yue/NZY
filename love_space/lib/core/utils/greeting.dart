/// 根据当前时间返回问候语
class Greeting {
  static String now() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，亲爱的';
    if (hour < 12) return '早上好，亲爱的';
    if (hour < 14) return '中午好，亲爱的';
    if (hour < 18) return '下午好，亲爱的';
    return '晚上好，亲爱的';
  }
}
