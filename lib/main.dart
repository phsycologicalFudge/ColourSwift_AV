import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/theme_manager.dart';
import 'screens/boot_screen.dart';
import 'screens/quarantine/quarantine_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:colourswift_av/services/purchase_service.dart'
if (dart.library.io) 'package:colourswift_av/private/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize theme and purchases
  final themeManager = ThemeManager();
  await themeManager.init();
  await PurchaseService.init();

  // Check if app was opened from a notification
  const channel = MethodChannel('colourswift/foreground_service');
  bool openQuarantine = false;
  try {
    final result = await channel.invokeMethod<Map>('getLaunchExtras');
    openQuarantine = result?['open_quarantine'] == true;
  } catch (_) {}

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeManager,
      child: MyApp(openQuarantine: openQuarantine),
    ),
  );
}

Future<void> _ensureNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}



class MyApp extends StatelessWidget {
  final bool openQuarantine;
  const MyApp({super.key, required this.openQuarantine});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ColourSwift AV+',
      theme: themeManager.themeData,
      themeMode: themeManager.themeMode,
      home: openQuarantine ? const QuarantineScreen() : const BootScreen(),
    );
  }
}
