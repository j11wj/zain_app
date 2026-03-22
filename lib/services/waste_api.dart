import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

import '../backend_urls.dart';
import '../config.dart';
import 'http_client_factory.dart';

/// REST + WebSocket URLs للباك اند.
class WasteApi {
  WasteApi({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.fallbackApiBase;

  String baseUrl;

  static final http.Client _httpClient = createHttpClient();

  /// مهلة الطلب الكامل (بالثواني).
  static const Duration _timeout = Duration(seconds: 45);

  Uri _u(String path) {
    final b = baseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$b$path');
  }

  void updateBaseUrl(String url) {
    baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
  }

  /// يطبع في الـ console (Debug) ويعيد نصاً للواجهة.
  static String buildDiagnostic({
    required String operation,
    required Uri uri,
    required String apiBase,
    required String webSocketUrl,
    required Object error,
    StackTrace? stack,
  }) {
    final lines = <String>[
      '─── تشخيص اتصال الباك اند ───',
      'العملية: $operation',
      'الرابط الذي طُلب: $uri',
      'baseUrl المحفوظ: $apiBase',
      'WebSocket: $webSocketUrl',
      'نوع الخطأ: ${error.runtimeType}',
      'الرسالة: $error',
    ];
    if (error is http.ClientException) {
      lines.add('ClientException (شبكة/SSL): ${error.message}');
    }
    final errLower = error.toString().toLowerCase();
    final refused = errLower.contains('connection refused');
    final androidLocalhost = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (apiBase.contains('127.0.0.1') || uri.host == '127.0.0.1');
    if (refused && androidLocalhost) {
      lines.add('');
      lines.add('═══ Connection refused + 127.0.0.1 (محاكي أندرويد) ═══');
      lines.add(
        'داخل المحاكي، 127.0.0.1 = الجهاز الافتراضي نفسه وليس الكمبيوتر، '
        'ما لم تُفعّل توجيه المنفذ.',
      );
      lines.add('1) على الكمبيوتر: cd server ثم npm start (الباك اند على المنفذ 3000).');
      lines.add('2) مع المحاكي يعمل: adb reverse tcp:3000 tcp:3000');
      lines.add('3) أعد تشغيل الطلب (أو Hot restart للتطبيق).');
      lines.add(
        'بدون adb reverse: غيّر العنوان في التطبيق إلى http://10.0.2.2:3000 '
        'و HOST=0.0.0.0 في server/.env.',
      );
    }
    if (error is TimeoutException) {
      lines.add('انتهت مهلة ${_timeout.inSeconds} ثانية.');
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        lines.add('');
        lines.add('═══ حلول مقترحة (محاكي أندرويد + Windows) ═══');
        lines.add('أ) نفّذ على الكمبيوتر (المحاكي يعمل):');
        lines.add('   adb reverse tcp:3000 tcp:3000');
        lines.add('   ثم اترك العنوان: http://127.0.0.1:3000 (الافتراضي الحالي)');
        lines.add('ب) أو بدون adb reverse:');
        lines.add('   - في server/.env: HOST=0.0.0.0');
        lines.add('   - في التطبيق: http://10.0.2.2:3000');
        lines.add('   - جدار حماية Windows: اسمح بالوارد على المنفذ 3000');
        lines.add('ج) تأكد أن الباك اند يعمل: cd server && npm start');
      }
    }
    if (kDebugMode && stack != null) {
      final short = stack.toString().split('\n').take(6).join('\n');
      lines.add('Stack (أول أسطر):\n$short');
    }
    lines.add('─── نهاية التشخيص ───');
    final text = lines.join('\n');
    if (kDebugMode) {
      debugPrint(text);
    }
    return text;
  }

  Future<http.Response> _request(
    Future<http.Response> Function() send,
    String operation,
    Uri uri,
  ) async {
    try {
      final r = await send().timeout(_timeout);
      if (r.statusCode != 200) {
        final bodyPreview = r.body.length > 200
            ? '${r.body.substring(0, 200)}...'
            : r.body;
        final msg = [
          'HTTP ${r.statusCode} لـ $operation',
          'الرابط: $uri',
          'جسم الاستجابة: $bodyPreview',
        ].join('\n');
        if (kDebugMode) {
          debugPrint('═══ $msg');
        }
        throw Exception(msg);
      }
      return r;
    } on TimeoutException catch (e, st) {
      throw Exception(buildDiagnostic(
        operation: '$operation (Timeout)',
        uri: uri,
        apiBase: baseUrl,
        webSocketUrl: wsUrl,
        error: e,
        stack: st,
      ));
    } catch (e, st) {
      final t = e.toString();
      if (t.contains('─── تشخيص')) rethrow;
      if (t.contains('الرابط:') &&
          (t.contains('HTTP ') || t.contains('جسم الاستجابة'))) {
        rethrow;
      }
      if (t.contains('JSON غير صالح') || t.contains('استجابة /health')) {
        rethrow;
      }
      throw Exception(buildDiagnostic(
        operation: operation,
        uri: uri,
        apiBase: baseUrl,
        webSocketUrl: wsUrl,
        error: e,
        stack: st,
      ));
    }
  }

  /// اختبار سريع: GET /health
  Future<Map<String, dynamic>> getHealth() async {
    final uri = _u('/health');
    final r = await _request(
      () => _httpClient.get(uri, headers: {'Accept': 'application/json'}),
      'GET /health',
      uri,
    );
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        'استجابة /health ليست JSON صالحاً\n$e\nالنص: ${r.body}',
      );
    }
  }

  Future<Map<String, dynamic>> getBins() async {
    final uri = _u('/bins');
    final r = await _request(
      () => _httpClient.get(uri, headers: {'Accept': 'application/json'}),
      'GET /bins',
      uri,
    );
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('JSON غير صالح من /bins: $e');
    }
  }

  Future<Map<String, dynamic>> getRoute() async {
    final uri = _u('/route');
    final r = await _request(
      () => _httpClient.get(uri, headers: {'Accept': 'application/json'}),
      'GET /route',
      uri,
    );
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('JSON غير صالح من /route: $e');
    }
  }

  Future<Map<String, dynamic>> getSimulation() async {
    final uri = _u('/simulation');
    final r = await _request(
      () => _httpClient.get(uri, headers: {'Accept': 'application/json'}),
      'GET /simulation',
      uri,
    );
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('JSON غير صالح من /simulation: $e');
    }
  }

  Future<Map<String, dynamic>> postSimulationAction(String action) async {
    final uri = _u('/simulation');
    final r = await _request(
      () => _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'action': action}),
      ),
      'POST /simulation',
      uri,
    );
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('JSON غير صالح: $e');
    }
  }

  String get wsUrl => BackendUrls.webSocketFromHttpBase(baseUrl);
}
