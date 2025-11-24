import 'dart:async';
import 'package:colourswift_av/screens/permissions_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/av_engine.dart';
import 'main_shell.dart';
import '../utils/defs_manager.dart';
import '../services/update_service.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeOutController;
  late Timer _textTimer;
  int _currentIndex = 0;
  bool _finished = false;

  final List<String> _messages = [
    'Preparing protection...',
    'Loading definitions...',
    'Initializing engine...',
    'Optimizing memory...',
    'Starting services...',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentIndex = (_currentIndex + 1) % _messages.length);
    });

    _initEngine();
  }


  Future<void> _initEngine() async {
    await Future.delayed(const Duration(seconds: 2)); // show boot sequence
    await AvEngine.ensureInitialized();

    if (!mounted) return;
    await _fadeOutController.forward();

    if (!mounted) return;
    await _fadeOutController.forward();

    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool('firstLaunch') ?? true;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) =>
          firstLaunch ? const PermissionsIntroScreen() : const MainShell(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }


  @override
  void dispose() {
    _pulseController.dispose();
    _fadeOutController.dispose();
    _textTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(_fadeOutController),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo pulse
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 35),

              // App name
              Text(
                'ColourSwift Security',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 20),

              // Cycling text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                  _messages[_currentIndex],
                  key: ValueKey(_messages[_currentIndex]),
                  style: text.titleMedium?.copyWith(
                    color: text.bodyLarge?.color?.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Copyright
              Text(
                '© ColourSwift Technologies',
                style: text.bodySmall?.copyWith(
                  color: text.bodySmall?.color?.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
