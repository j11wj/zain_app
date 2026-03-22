import 'package:flutter/material.dart';

import 'screens/driver_map_screen.dart';
import 'services/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiBase = await AppSettings.loadApiBase();
  runApp(WasteDriverApp(initialApiBase: apiBase));
}

/// Driver mobile app (OpenStreetMap + backend).
class WasteDriverApp extends StatelessWidget {
  const WasteDriverApp({super.key, required this.initialApiBase});

  final String initialApiBase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سائق النفايات الذكية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D6A4F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: DriverMapScreen(initialApiBase: initialApiBase),
    );
  }
}
