import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'main_shell.dart';

class PermissionsIntroScreen extends StatefulWidget {
  const PermissionsIntroScreen({super.key});

  @override
  State<PermissionsIntroScreen> createState() => _PermissionsIntroScreenState();
}

class _PermissionsIntroScreenState extends State<PermissionsIntroScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool storageGranted = false;
  bool notifGranted = false;

  Future<void> _requestStorage() async {
    bool granted = false;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final sdk = info.version.sdkInt;

      if (sdk >= 30) {
        try {
          var status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            const platform = MethodChannel('colourswift/storage_permission');
            await platform.invokeMethod('openManageStorage');
            await Future.delayed(const Duration(seconds: 2));
            status = await Permission.manageExternalStorage.status;
          }
          granted = status.isGranted;
        } catch (e) {
          debugPrint('⚠️ Storage permission check failed: $e');
          await openAppSettings();
        }
      } else {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          granted = await Permission.storage.request().isGranted;
        } else {
          granted = true;
        }
      }
    } else {
      granted = true;
    }

    setState(() => storageGranted = granted);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required for scanning.')),
      );
    }
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    setState(() => notifGranted = status.isGranted);
  }

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstLaunch', false);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_rounded,
                    size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('CS Security',
                    style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: text.bodyLarge?.color)),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildSlide(
                    context,
                    icon: Icons.folder_rounded,
                    title: 'Storage Access',
                    desc:
                    'To scan your device for threats, CS Security needs access to your storage. '
                        'You can grant it now or later, but scanning will require it.',
                    granted: storageGranted,
                    buttonLabel: 'Grant Access',
                    onPressed: _requestStorage,
                  ),
                  _buildSlide(
                    context,
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications',
                    desc:
                    'Used for realtime alerts and updates when threats are detected or quarantined.',
                    granted: notifGranted,
                    buttonLabel: 'Allow Notifications',
                    onPressed: _requestNotifications,
                  ),
                  _buildSlide(
                    context,
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Setup Complete',
                    desc:
                    'Everything’s ready! You can now start protecting your device with CS Security.',
                    granted: true,
                    buttonLabel: 'Finish Setup',
                    onPressed: _finishSetup,
                  ),
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () {
                        _controller.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 70),
                  Row(
                    children: List.generate(
                      3,
                          (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _page == i
                              ? theme.colorScheme.primary
                              : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_page < 2) {
                        _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      } else {
                        _finishSetup();
                      }
                    },
                    child: Text(_page == 2 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String desc,
        required String buttonLabel,
        required VoidCallback onPressed,
        required bool granted,
      }) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 90,
              color:
              granted ? Colors.greenAccent : theme.colorScheme.primary),
          const SizedBox(height: 25),
          Text(title,
              style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: text.bodyLarge?.color)),
          const SizedBox(height: 12),
          Text(
            desc,
            style: text.bodyMedium
                ?.copyWith(color: text.bodyMedium?.color?.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(
                granted
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white),
            label: Text(
              granted ? 'Granted' : buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: granted
                  ? Colors.greenAccent
                  : theme.colorScheme.primary,
              foregroundColor:
              isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
