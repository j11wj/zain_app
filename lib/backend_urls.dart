/// بناء عنوان WebSocket من عنوان REST (لا يعتمد على منصة التشغيل).
class BackendUrls {
  BackendUrls._();

  /// يحوّل `http://host:port` أو `https://...` إلى `ws://host:port/ws` أو `wss://.../ws`.
  /// [baseUrl] مثل `http://10.0.2.2:3000` أو `http://192.168.1.10:3000`.
  static String webSocketFromHttpBase(String baseUrl) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final u = Uri.parse(trimmed);
    if (!u.hasScheme || (u.scheme != 'http' && u.scheme != 'https')) {
      throw ArgumentError('Invalid HTTP(S) base URL: $baseUrl');
    }
    final port = u.hasPort
        ? u.port
        : (u.scheme == 'https' ? 443 : 80);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${u.host}:$port/ws';
  }
}
