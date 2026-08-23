/// 腾讯云 SCF + COS 同步后端配置
///
/// 双人同步后端为自建云函数（腾讯云 Serverless，函数 URL 触发），数据存 COS：
/// - [apiBaseUrl]：函数 URL（部署后获取）
/// - [syncSecret]：与云函数环境变量 `SYNC_SECRET` 一致（防陌生人访问）
///
/// 运行/打包时注入（覆盖默认值）：
/// ```bash
/// flutter run --dart-define=SYNC_API_URL=你的函数URL --dart-define=SYNC_SECRET=你的密钥
/// ```
class SyncConfig {
  SyncConfig._();

  /// 云函数 URL（--dart-define=SYNC_API_URL=xxx 可覆盖）
  static const String apiBaseUrl = String.fromEnvironment(
    'SYNC_API_URL',
    defaultValue: 'https://1365481605-44cqwo44vt.ap-guangzhou.tencentscf.com',
  );

  /// 同步密钥（必须通过 --dart-define=SYNC_SECRET=xxx 注入，不写入仓库）
  static const String syncSecret = String.fromEnvironment(
    'SYNC_SECRET',
    defaultValue: '',
  );

  /// 是否已配置（未配置时同步功能自动禁用，App 保持纯本地可用）
  static bool get isConfigured =>
      apiBaseUrl.isNotEmpty && syncSecret.isNotEmpty;

  /// 轮询间隔（双端低频互动场景 60s 足够；免费额度内可放宽）
  static const Duration syncInterval = Duration(seconds: 60);

  /// 房间码长度（6 位大写字母数字）
  static const int roomCodeLength = 6;
}
