import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// إعداد عنوان الـ API الافتراضي (قبل حفظ المستخدم في [AppSettings]).
///
/// ## أولوية التطبيق لعنوان الخادم
/// 1. `--dart-define=API_BASE=http://...` (يُقرأ في [AppSettings.loadApiBase])
/// 2. قيمة محفوظة من التطبيق (تبويب المراجعة)
/// 3. `--dart-define=SERVER_HOST=...` مع `SERVER_PORT` (يُطبّق على كل المنصات)
/// 4. على **Android**: `--dart-define=ANDROID_HOST=...` إذا كان `SERVER_HOST` فارغاً
/// 5. الافتراضيات أدناه
///
/// ## محاكي Android مقابل الجهاز الحقيقي
/// | السيناريو | عنوان نموذجي | ملاحظات |
/// |-----------|----------------|---------|
/// | محاكي → جهاز التطوير | `http://10.0.2.2:3000` | الاسم الخاص بالمحاكي يشير إلى loopback المضيف |
/// | محاكي + `adb reverse` | `http://127.0.0.1:3000` | يجب: `adb reverse tcp:3000 tcp:3000` |
/// | هاتف على نفس Wi‑Fi | `http://192.168.x.x:3000` | استبدل بـ IP الكمبيوتر؛ السيرفر `HOST=0.0.0.0` |
///
/// أمثلة تشغيل:
/// ```bash
/// # محاكي (افتراضي الكود: 10.0.2.2)
/// flutter run
///
/// # محاكي مع 127.0.0.1 + adb reverse
/// adb reverse tcp:3000 tcp:3000
/// flutter run --dart-define=ANDROID_HOST=127.0.0.1
///
/// # جهاز حقيقي (IP الشبكة المحلية للكمبيوتر)
/// flutter run --dart-define=ANDROID_HOST=192.168.1.50
/// ```
class AppConfig {
  AppConfig._();

  static const String _port = String.fromEnvironment(
    'SERVER_PORT',
    defaultValue: '3000',
  );

  /// يغيّر المضيف على **جميع** المنصات عند التعيين (أولوية على ANDROID_HOST).
  static const String _serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: '',
  );

  /// يُستخدم لـ **Android فقط** عندما يكون [_serverHost] فارغاً.
  /// الافتراضي `10.0.2.2` = عنوان المحاكي نحو مضيف التطوير (بدون `adb reverse`).
  static const String _androidHost = String.fromEnvironment(
    'ANDROID_HOST',
    defaultValue: '192.168.1.171',
  );

  static String get fallbackApiBase {
    // if (_serverHost.isNotEmpty) {
    //   return 'http://$_serverHost:$_port';
    // }
    // if (kIsWeb) {
    //   return 'http://localhost:$_port';
    // }
    // if (defaultTargetPlatform == TargetPlatform.android) {
    //   return 'http://$_androidHost:$_port';
    // }
    return 'http://192.168.1.171:$_port';
  }
}
