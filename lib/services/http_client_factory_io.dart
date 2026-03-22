import 'dart:io' show HttpClient;

import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

http.Client createHttpClient() {
  final hc = HttpClient();
  hc.connectionTimeout = const Duration(seconds: 25);
  hc.idleTimeout = const Duration(seconds: 60);
  return IOClient(hc);
}
