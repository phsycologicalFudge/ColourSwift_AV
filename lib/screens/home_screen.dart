import 'package:colourswift_av/screens/password%20manager/password_manager_screen.dart';
import 'package:colourswift_av/screens/scan/cleaner_screen.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/realtime_protection_service.dart';
import '../services/update_service.dart';
import '../utils/animated_route.dart';
import 'scan_screen.dart';
import '../services/service_manager.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class AvHomeScreen extends StatefulWidget {
  const AvHomeScreen({super.key});

  @override
  State<AvHomeScreen> createState() => _AvHomeScreenState();
}

class _AvHomeScreenState extends State<AvHomeScreen> with TickerProviderStateMixin {
  bool protectionEnabled = false;
  double protectionPercent = 0.0;
  bool hideGoldHeader = false;
  Timer? _periodicScanTimer;
  bool isPro = false;
  bool hasUpdate = false;
  String? remoteVersion;
  String version = '';

  late AnimationController _popupController;
  late Animation<Offset> _popupAnimation;
  late Animation<double> _popupOpacity;

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => version = info.version);
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isPro = prefs.getBool('isPro') ?? false);
  }

  Future<void> _togglePro() async {
    final prefs = await SharedPreferences.getInstance();
    final newStatus = !isPro;
    await prefs.setBool('isPro', newStatus);
    setState(() => isPro = newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(newStatus ? 'Pro activated' : 'Pro deactivated')),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHeaderPref();
    _loadProtectionState();
    _loadVersion();
    _loadProStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForDatabaseUpdate();
    });

    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _popupAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutCubic,
    ));

    _popupOpacity = CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeIn,
    );
  }

  void _startUpdate(String newRemoteVersion) {
    double progress = 0;
    bool dialogMounted = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future.microtask(() async {
              try {
                double lastShown = 0;
                await UpdateService.downloadDatabase(
                  onProgress: (p) {
                    if ((p - lastShown).abs() >= 0.01) {
                      lastShown = p;
                      if (dialogMounted && mounted) {
                        setState(() => progress = p);
                      }
                    }
                  },
                );
                if (!mounted || !dialogMounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                await UpdateService.setLocalVersion(newRemoteVersion);
                setState(() {
                  hasUpdate = false;
                  remoteVersion = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database updated successfully')),
                );
              } catch (e) {
                if (!mounted || !dialogMounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database update failed')),
                );
              }
            });
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: const Text('Updating Database'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 10),
                    Text('${(progress * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      dialogMounted = false;
    });
  }

  Future<void> _loadHeaderPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => hideGoldHeader = prefs.getBool('hideGoldHeader') ?? true);
  }

  Future<void> _checkForDatabaseUpdate() async {
    final remote = await UpdateService.checkServerVersion();
    if (remote == null) return;

    final remoteVer = remote['version'] ?? '0.0.0';
    final localVer = await UpdateService.getLocalVersion();

    if (remoteVer != localVer) {
      setState(() {
        hasUpdate = true;
        remoteVersion = remoteVer;
      });
    } else {
      setState(() {
        hasUpdate = false;
        remoteVersion = null;
      });
    }
  }

  Future<void> _loadProtectionState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getBool('protectionEnabled') ?? false;
    setState(() {
      protectionEnabled = savedState;
      protectionPercent = savedState ? 1.0 : 0.0;
    });
    if (protectionEnabled) _startBackgroundScan();
  }

  Future<void> _toggleProtection() async {
    final prefs = await SharedPreferences.getInstance();

    if (protectionEnabled) {
      await AvServiceManager.stopProtection();
      _stopBackgroundScan();
    } else {
      if (await Permission.notification.isDenied ||
          await Permission.notification.isRestricted) {
        final status = await Permission.notification.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission is required for realtime protection.')),
          );
          return;
        }
      }

      await AvServiceManager.startProtection();
      _startBackgroundScan();
    }

    setState(() {
      protectionEnabled = !protectionEnabled;
      protectionPercent = protectionEnabled ? 1.0 : 0.0;
    });

    prefs.setBool('protectionEnabled', protectionEnabled);
  }

  void _startBackgroundScan() => RealtimeProtectionService.start();
  void _stopBackgroundScan() => RealtimeProtectionService.stop();

  void _openScan() => Navigator.push(context, animatedRoute(const ScanScreen()));

  @override
  void dispose() {
    _periodicScanTimer?.cancel();
    _popupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final backgroundGradient = (isPro && isDark && !hideGoldHeader)
        ? const LinearGradient(
      colors: [Color(0xFFB8860B), Color(0xFF4B3B08)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : LinearGradient(
      colors: [
        theme.colorScheme.primary.withOpacity(0.25),
        isDark ? Colors.black : theme.scaffoldBackgroundColor,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            expandedHeight: isPro ? 80 : 110,
            backgroundColor: theme.appBarTheme.backgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Row(
                children: [
                  Text('CS Security',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: text.bodyLarge?.color,
                        letterSpacing: 0.5,
                      )),
                  if (isPro)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('PRO',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                ],
              ),
              background: Container(decoration: BoxDecoration(gradient: backgroundGradient)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleProtection,
                    child: Column(
                      children: [
                        CircularPercentIndicator(
                          radius: 130.0,
                          lineWidth: 14.0,
                          animation: true,
                          animateFromLastPercent: true,
                          percent: protectionPercent,
                          circularStrokeCap: CircularStrokeCap.round,
                          progressColor:
                          protectionEnabled ? Colors.greenAccent : Colors.redAccent,
                          backgroundColor: theme.dividerColor.withOpacity(0.1),
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  protectionEnabled
                                      ? Icons.verified_user
                                      : Icons.warning_amber_rounded,
                                  color: protectionEnabled
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 60),
                              const SizedBox(height: 10),
                              Text(
                                protectionEnabled
                                    ? 'Device Protected'
                                    : 'Protection Disabled',
                                style: text.titleMedium?.copyWith(
                                  color: protectionEnabled
                                      ? text.bodyLarge?.color
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Tap to ${protectionEnabled ? "disable" : "enable"} protection',
                                style: text.bodySmall?.copyWith(
                                  color:
                                  text.bodySmall?.color?.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        GestureDetector(
                          onTap: _openScan,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            width: double.infinity,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withOpacity(0.9),
                                  theme.colorScheme.primary.withOpacity(0.7),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text('Scan Now',
                                    style: text.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text('ColourSwift Antivirus v$version',
                            style: text.bodySmall?.copyWith(
                                color: text.bodySmall?.color?.withOpacity(0.6))),
                        if (hasUpdate &&
                            remoteVersion != null &&
                            remoteVersion!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _startUpdate(remoteVersion!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.system_update_rounded, size: 18),
                            label: Text('Update to v${remoteVersion ?? ""}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Features',
                        style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: text.bodyLarge?.color)),
                  ),
                  _buildFeatureCard(
                    context,
                    title: 'MetaPass',
                    description:
                    'Generate secure offline passwords.',
                    icon: Icons.key_rounded,
                    color: Colors.amberAccent,
                    onTap: () =>
                        Navigator.push(context, animatedRoute(const PasswordTestScreen())),
                  ),
                  const SizedBox(height: 15),                  const SizedBox(height: 15),
                  _buildFeatureCard(
                    context,
                    title: 'Cleaner Pro',
                    description:
                    'Find duplicates, old media, and unused apps to reclaim storage automatically.',
                    icon: Icons.cleaning_services_rounded,
                    color: Colors.blueAccent,
                    onTap: () =>
                        Navigator.push(context, animatedRoute(const CleanerScreen())),
                  ),
                  const SizedBox(height: 15),
                  _buildFeatureCard(
                    context,
                    title: 'Wi-Fi Protection',
                    description:
                    'Coming soon: real-time blocking of malicious connections and trackers, using a private on-device VPN. No external servers, and no data collection',
                    icon: Icons.wifi_lock_rounded,
                    color: Colors.tealAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required String title,
        required String description,
        required IconData icon,
        required Color color,
        VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? theme.cardColor
              : theme.colorScheme.surfaceVariant.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: text.bodyLarge?.color)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: text.bodySmall?.copyWith(
                          color:
                          text.bodySmall?.color?.withOpacity(0.7),
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios_rounded,
                color: text.bodySmall?.color?.withOpacity(0.6), size: 18),
          ],
        ),
      ),
    );
  }
}
