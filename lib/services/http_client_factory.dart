import 'package:http/http.dart' as http;

import 'http_client_factory_web.dart'
    if (dart.library.io) 'http_client_factory_io.dart' as impl;

/// عميل HTTP مع مهلة اتصال صريحة على المنصات غير الويب.
http.Client createHttpClient() => impl.createHttpClient();
