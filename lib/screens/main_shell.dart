import 'package:flutter/material.dart';
import '../widgets/footer_nav.dart';
import 'features_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings/settings_screen.dart';
import 'quarantine/quarantine_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String _active = 'home';

  Widget _buildActivePage() {
    switch (_active) {
      case 'features':
        return const FeaturesScreen();
      case 'scan':
        return const ScanScreen();
      case 'quarantine':
        return const QuarantineScreen();
      case 'settings':
        return const SettingsScreen();
      case 'home':
      default:
        return const AvHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildActivePage(),
      bottomNavigationBar: FooterNav(
        active: _active,
        onTabChange: (tab) => setState(() => _active = tab),
      ),
    );
  }
}
