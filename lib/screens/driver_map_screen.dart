import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../services/app_settings.dart';
import '../services/waste_api.dart';

/// خريطة السائق + مراجعة البيانات وتحكم بالمحاكاة على الخادم.
class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key, required this.initialApiBase});

  final String initialApiBase;

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  late WasteApi _api;
  late final TextEditingController _urlController;
  final MapController _mapController = MapController();

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<Map<String, dynamic>> _bins = [];

  bool _loading = false;
  bool _connected = false;
  /// تفاصيل كاملة تُطبع أيضاً في الـ Debug console
  String? _error;
  String? _wsError;

  /// حالة المحاكاة من الخادم.
  Map<String, dynamic>? _sim;

  /// إيقاف تحديث الشاشة محلياً للمراجعة دون قفز الأرقام.
  bool _freezeLocalView = false;

  int _tab = 0;

  WebSocketChannel? _ws;
  Timer? _poll;

  /// مدينة الديوانية (محافظة الديوانية، العراق) عند عدم توفر بيانات من الخادم بعد
  static const LatLng _fallback = LatLng(31.9889, 44.924);
  static const double _mapMinZoom = 3;
  static const double _mapMaxZoom = 19;
  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void _zoomIn() {
    final cam = _mapController.camera;
    final z = (cam.zoom + 1).clamp(_mapMinZoom, _mapMaxZoom);
    if (z != cam.zoom) _mapController.move(cam.center, z);
  }

  void _zoomOut() {
    final cam = _mapController.camera;
    final z = (cam.zoom - 1).clamp(_mapMinZoom, _mapMaxZoom);
    if (z != cam.zoom) _mapController.move(cam.center, z);
  }

  Color _markerColor(double fill) {
    if (fill < 50) return const Color(0xFF2D6A4F);
    if (fill <= 80) return const Color(0xFFE9C46A);
    return const Color(0xFFC1121F);
  }

  Future<void> _refreshSimulation() async {
    try {
      final s = await _api.getSimulation();
      if (!mounted) return;
      setState(() => _sim = s);
    } catch (_) {
      /* optional */
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.getHealth();
      final binsJson = await _api.getBins();
      final routeJson = await _api.getRoute();
      final bins = (binsJson['bins'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final route = (routeJson['route'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final depot = routeJson['depot'] as Map<String, dynamic>?;

      final markers = <Marker>[];
      for (final b in bins) {
        final id = b['id'] as int;
        final lat = (b['lat'] as num).toDouble();
        final lng = (b['lng'] as num).toDouble();
        final fill = (b['fill_level'] as num).toDouble();
        final c = _markerColor(fill);
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 44,
            height: 44,
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: 'حاوية $id — ${fill.toStringAsFixed(1)}٪',
              child: Icon(Icons.location_on, color: c, size: 40),
            ),
          ),
        );
      }

      final points = <LatLng>[];
      if (depot != null) {
        points.add(
          LatLng(
            (depot['lat'] as num).toDouble(),
            (depot['lng'] as num).toDouble(),
          ),
        );
      }
      for (final r in route) {
        points.add(
          LatLng(
            (r['lat'] as num).toDouble(),
            (r['lng'] as num).toDouble(),
          ),
        );
      }

      final polylines = <Polyline>[];
      if (points.length >= 2) {
        polylines.add(
          Polyline(
            points: points,
            color: const Color(0xFF1D3557),
            strokeWidth: 5,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _markers = markers;
        _polylines = polylines;
        _bins = bins;
        _loading = false;
        _connected = true;
        _error = null;
        _wsError = null;
      });

      if (points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _fitBounds(points);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final detail = _extractExceptionMessage(e);
      debugPrint('═══ فشل اتصال الباك اند (DriverMap) ═══\n$detail');
      setState(() {
        _loading = false;
        _connected = false;
        _error = detail;
      });
    }
  }

  String _extractExceptionMessage(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) {
      s = s.substring('Exception: '.length);
    }
    return s;
  }

  String _formatError(Object e) => _extractExceptionMessage(e);

  void _fitBounds(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  void _schedulePolling() {
    _poll?.cancel();
    if (_freezeLocalView) return;
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_freezeLocalView) _load();
    });
  }

  void _connectWs() {
    try {
      _ws?.sink.close();
      final wsUri = Uri.parse(_api.wsUrl);
      _ws = WebSocketChannel.connect(wsUri);
      _ws!.stream.listen(
        (dynamic raw) {
          if (_freezeLocalView) return;
          try {
            final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
            final t = msg['type'];
            if (t == 'tick') {
              _load();
            } else if (t == 'simulation') {
              setState(() => _sim = {
                    'running': msg['running'],
                    'paused': msg['paused'],
                    'intervalMs': msg['intervalMs'],
                  });
            }
          } catch (_) {
            _load();
          }
        },
        onError: (Object e, StackTrace st) {
          final diag = WasteApi.buildDiagnostic(
            operation: 'WebSocket',
            uri: wsUri,
            apiBase: _api.baseUrl,
            webSocketUrl: _api.wsUrl,
            error: e,
            stack: st,
          );
          if (!mounted) return;
          setState(() => _wsError = diag);
        },
      );
    } catch (e, st) {
      final diag = WasteApi.buildDiagnostic(
        operation: 'WebSocket (بدء الاتصال)',
        uri: Uri.parse(_api.wsUrl),
        apiBase: _api.baseUrl,
        webSocketUrl: _api.wsUrl,
        error: e,
        stack: st,
      );
      if (mounted) {
        setState(() => _wsError = diag);
      }
    }
  }

  Future<void> _saveServerUrl() async {
    final t = _urlController.text.trim();
    if (t.isEmpty) return;
    await AppSettings.saveApiBase(t);
    if (!mounted) return;
    setState(() {
      _api.updateBaseUrl(t);
    });
    _connectWs();
    await _load();
    await _refreshSimulation();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ عنوان الخادم')),
    );
  }

  Future<void> _simAction(String action) async {
    try {
      final r = await _api.postSimulationAction(action);
      if (!mounted) return;
      setState(() {
        _sim = {
          'running': r['running'],
          'paused': r['paused'],
          'intervalMs': r['intervalMs'],
        };
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم: $action')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatError(e))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _api = WasteApi(baseUrl: widget.initialApiBase);
    _urlController = TextEditingController(text: _api.baseUrl);
    _load();
    _refreshSimulation();
    _connectWs();
    _schedulePolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ws?.sink.close();
    _mapController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = _sim;
    final running = sim?['running'] == true;
    final paused = sim?['paused'] == true;
    final intervalMs = sim?['intervalMs'] as int? ?? 5000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سائق النفايات الذكية'),
        backgroundColor: const Color(0xFF1B4332),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _tab == 0 ? _buildMap(running, paused, intervalMs) : _buildReview(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _refreshSimulation();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'الخريطة',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'المراجعة والمحاكاة',
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool running, bool paused, int intervalMs) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _fallback,
            initialZoom: 13,
            minZoom: _mapMinZoom,
            maxZoom: _mapMaxZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: _osmTileUrl,
              userAgentPackageName: 'com.example.user_app1',
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
              alignment: Alignment.bottomRight,
              backgroundColor: Color(0xE6FFFFFF),
            ),
            PolylineLayer(polylines: _polylines),
            MarkerLayer(markers: _markers),
          ],
        ),
        if (_loading)
          const LinearProgressIndicator(
            minHeight: 3,
            color: Color(0xFF2D6A4F),
          ),
        Positioned(
          left: 8,
          right: 8,
          top: 8,
          child: _statusChips(running, paused, intervalMs),
        ),
        Positioned(
          right: 8,
          bottom: 100,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تكبير',
                  onPressed: _zoomIn,
                  icon: const Icon(Icons.add),
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                ),
                Divider(height: 1, color: Colors.grey.shade300),
                IconButton(
                  tooltip: 'تصغير',
                  onPressed: _zoomOut,
                  icon: const Icon(Icons.remove),
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 88,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              color: Colors.red.shade50,
              child: SizedBox(
                height: 220,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'خطأ الاتصال بالباك اند (انظر أيضاً Debug console)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_wsError != null && _error == null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 88,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.orange.shade50,
              child: SizedBox(
                height: 120,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _wsError!,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'ألوان: أخضر <50٪ · أصفر 50–80٪ · أحمر >80٪\n'
                'الخط: مسار التجميع (A*) من المستودع للحاويات ≥80٪',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChips(bool running, bool paused, int intervalMs) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Chip(
          avatar: Icon(
            _connected ? Icons.cloud_done : Icons.cloud_off,
            size: 18,
            color: _connected ? Colors.green : Colors.red,
          ),
          label: Text(_connected ? 'متصل' : 'غير متصل'),
        ),
        if (_freezeLocalView)
          const Chip(
            avatar: Icon(Icons.pause_circle_outline, size: 18),
            label: Text('تجميد العرض'),
          ),
        Chip(
          label: Text(
            running
                ? (paused ? 'المحاكاة: متوقفة مؤقتاً (بيانات ثابتة)' : 'المحاكاة: تعمل')
                : 'المحاكاة: متوقفة',
          ),
        ),
        Chip(label: Text('كل ${intervalMs ~/ 1000} ث')),
      ],
    );
  }

  Widget _buildReview() {
    final sim = _sim;
    final running = sim?['running'] == true;
    final paused = sim?['paused'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          Text(
            'تشخيص آخر خطأ (قابل للنسخ)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          SelectableText(
            _error!,
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: 11,
            ),
          ),
          const Divider(height: 24),
        ],
        if (_wsError != null && _error == null) ...[
          Text('تنبيه WebSocket', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          SelectableText(
            _wsError!,
            style: TextStyle(color: Colors.orange.shade900, fontSize: 11),
          ),
          const Divider(height: 24),
        ],
        Text(
          'عنوان الخادم',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: AppConfig.fallbackApiBase,
            isDense: true,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saveServerUrl,
          icon: const Icon(Icons.save),
          label: const Text('حفظ وإعادة الاتصال'),
        ),
        const SizedBox(height: 20),
        Text(
          'التحديث في التطبيق',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('إيقاف التحديث التلقائي (لمراجعة الأرقام)'),
          subtitle: const Text(
            'عند التفعيل: تتوقف طلبات الشبكة التلقائية؛ اضغط «تحديث» في الأعلى يدوياً.',
          ),
          value: _freezeLocalView,
          onChanged: (v) {
            setState(() => _freezeLocalView = v);
            _schedulePolling();
            _connectWs();
          },
        ),
        const Divider(),
        Text(
          'المحاكاة على الخادم',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '«إيقاف مؤقت» يجمد أرقام الحاويات للجميع حتى تتمكن من التحقق. «إيقاف» يوقف المؤقت بالكامل.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: running && !paused ? null : () => _simAction('start'),
              child: const Text('تشغيل'),
            ),
            FilledButton.tonal(
              onPressed: !running ? null : () => _simAction('pause'),
              child: const Text('إيقاف مؤقت'),
            ),
            FilledButton.tonal(
              onPressed: !running || !paused ? null : () => _simAction('resume'),
              child: const Text('استئناف'),
            ),
            OutlinedButton(
              onPressed: !running ? null : () => _simAction('stop'),
              child: const Text('إيقاف كامل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            running ? Icons.play_circle : Icons.stop_circle,
            color: running ? Colors.green : Colors.grey,
          ),
          title: Text(
            running
                ? (paused ? 'الحالة: متوقف مؤقتاً (بيانات ثابتة)' : 'الحالة: يعمل')
                : 'الحالة: متوقف',
          ),
        ),
        const Divider(),
        Row(
          children: [
            Text(
              'الحاويات (${_bins.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تحديث القائمة'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._bins.map(_binTile),
      ],
    );
  }

  Widget _binTile(Map<String, dynamic> b) {
    final id = b['id'];
    final fill = (b['fill_level'] as num).toDouble();
    final gas = (b['gas_level'] as num).toDouble();
    final fire = b['fire_status'] == true;
    final c = _markerColor(fill);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.25),
          child: Text('$id', style: TextStyle(color: c, fontWeight: FontWeight.bold)),
        ),
        title: Text('الملء ${fill.toStringAsFixed(1)}٪ · الغاز ${gas.toStringAsFixed(1)}'),
        subtitle: Text(
          fire ? 'تحذير: حريق' : 'لا حريق',
          style: TextStyle(color: fire ? Colors.red : null),
        ),
        trailing: Text(
          fill < 50 ? 'منخفض' : (fill <= 80 ? 'متوسط' : 'مرتفع'),
          style: TextStyle(color: c, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
