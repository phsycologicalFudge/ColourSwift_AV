import 'package:flutter/material.dart';

class HowThisAppWorksScreen extends StatelessWidget {
  const HowThisAppWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'How This App Works',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: text.bodyLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'How CS Security Works',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CS Security is a privacy-first antivirus engine that scans your files locally without tracking or sending data anywhere. '
                  'It uses a custom Rust-based engine and an encrypted malware database, ensuring security and speed while staying completely offline.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'Main Features',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('• Real-time protection for new downloads'),
            const Text('• On-device scanning with zero telemetry'),
            const Text('• Smart cleaning and duplicate detection'),
            const Text('• Lightweight, battery-friendly performance'),
            const SizedBox(height: 20),
            Text(
              'The engine operates through a 3-layer security model: SHA-256 hashing, signature-based detection rules, and a lightweight machine learning layer for intelligent threat analysis.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 30),
            Text(
              'Why is it free?',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'I know a lot of people are sceptic as to why the app is free, with no ads. '
                  'How can I make money with an ad free app some ask. '
                  'The answer is simple, I do not want to. I made this app primarily for my customers, but anyone can use it. '
                  'It is a free world you know, you could walk out of your house naked, who can stop you?\n\nPlease dont do that...',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
