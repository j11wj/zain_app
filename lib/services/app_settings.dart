import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// عنوان الخادم: `--dart-define=API_BASE` ثم التخزين المحلي ثم الافتراضي حسب المنصة.
class AppSettings {
  AppSettings._();

  /// تغيير المفتاح يُهمل عناوين قديمة خاطئة بعد ضبط التطوير المحلي.
  static const _keyApiBase = 'api_base_url_v4';

  static String _normalize(String s) =>
      s.trim().replaceAll(RegExp(r'/$'), '');

  static Future<String> loadApiBase() async {
    const fromDefine = String.fromEnvironment('API_BASE', defaultValue: '');
    if (fromDefine.isNotEmpty) {
      return _normalize(fromDefine);
    }

    final p = await SharedPreferences.getInstance();
    var s = p.getString(_keyApiBase);
    if (s != null && s.isNotEmpty) {
      s = _normalize(s);
      if (kIsWeb && s.contains('10.0.2.2')) {
        s = s.replaceAll('10.0.2.2', 'localhost');
        await p.setString(_keyApiBase, s);
      }
      return s;
    }
    return AppConfig.fallbackApiBase;
  }

  static Future<void> saveApiBase(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyApiBase, _normalize(url));
  }
}
