import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/meta_password_service.dart';
import '../../services/theme_manager.dart';
import '../about/how_this_app_works.dart';
import 'package:flutter/services.dart';
import '../../services/purchase_service.dart'
if (dart.library.io) '../../private/purchase_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isPro = false;

  @override
  void initState() {
    super.initState();
    _loadPro();
    _loadMetaPassword();
  }

  final _secure = const FlutterSecureStorage();
  String? _metaPassword;

  Future<void> _loadMetaPassword() async {
    _metaPassword = await MetaPasswordService.getMeta();
    setState(() {});
  }

  Future<void> _saveMetaPassword(String meta) async {
    await MetaPasswordService.setMeta(meta);
    setState(() => _metaPassword = meta);
  }

  Future<void> _clearMetaPassword() async {
    await MetaPasswordService.clearMeta();
    setState(() => _metaPassword = null);
  }

  Future<void> _showUpgradeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Upgrade to Pro'),
          content: const Text(
            'Pro is cosmetic only. You get Emerald and Grey themes, icon switching, and visual tweaks. Scans and protection are the same for everyone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await PurchaseService.buyPro();
      await Future.delayed(const Duration(seconds: 5));
      await PurchaseService.restore();

      final hasPro = await PurchaseService.hasPro();

      if (hasPro) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isPro', true);
        setState(() => isPro = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pro unlocked')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase not confirmed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  Future<void> _loadPro() async {
    final prefs = await SharedPreferences.getInstance();
    bool localPro = prefs.getBool('isPro') ?? false;
    bool playPro = await PurchaseService.hasPro();
    final status = localPro || playPro;
    await prefs.setBool('isPro', status);
    setState(() => isPro = status);
  }

  Future<void> _toggleProFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final newStatus = !isPro;
    await prefs.setBool('isPro', newStatus);
    setState(() => isPro = newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(newStatus ? 'Pro features enabled' : 'Pro features disabled')),
    );
  }

  void _showProInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('About Pro'),
          content: const Text(
            'Pro unlocks purely cosmetic features:\n\n'
                '• Emerald and Grey themes\n'
                '• Custom app icons\n'
                '• Gold header toggle\n\n'
                'Scanning and protection strength remain identical for all users. '
                'This upgrade supports future updates and development.'
                ' Pro also lasts for all future cosmetic addons.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _showProOptions(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool hideGoldHeader = prefs.getBool('hideGoldHeader') ?? true;
    String selectedIcon = prefs.getString('selectedIcon') ?? 'default';
    final iconChannel = MethodChannel('colourswift/icon_switch');

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                Future<void> _changeIcon(String icon) async {
                  await iconChannel.invokeMethod('setIcon', {'icon': icon});
                  await prefs.setString('selectedIcon', icon);
                  setModalState(() => selectedIcon = icon);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Icon changed to ${icon == 'bird' ? 'Bird' : 'Default'}')),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pro Customization',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: hideGoldHeader,
                        onChanged: (val) async {
                          setModalState(() => hideGoldHeader = val ?? false);
                          await prefs.setBool('hideGoldHeader', hideGoldHeader);
                        },
                        title: const Text('Hide gold header on Home Screen'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'App Icon',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _iconPreview(
                            context,
                            'default',
                            selectedIcon,
                            'Default',
                                () => _changeIcon('default'),
                          ),
                          const SizedBox(width: 16),
                          _iconPreview(
                            context,
                            'bird',
                            selectedIcon,
                            'Bird',
                                () => _changeIcon('bird'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB8860B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _iconPreview(BuildContext context, String name, String selected, String label, VoidCallback onTap) {
    final isSelected = name == selected;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? const Color(0xFFB8860B) : Colors.grey.shade400,
                width: isSelected ? 2.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/icons/ic_launcher${name == 'bird' ? '_bird' : '_default'}.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? const Color(0xFFB8860B) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _openThemePicker(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final current = themeManager.themeName;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose Theme', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _themeOption(context, 'Black', 'black', Colors.black, current),
                _themeOption(context, 'White', 'white', Colors.white, current),
                _themeOption(context, 'Grey', 'grey', Colors.grey.shade700, current),
                _themeOption(context, 'Emerald', 'emerald', const Color(0xFF009E73), current),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeOption(BuildContext context, String label, String value, Color color, String current) {
    final isSelected = current == value;
    final themeManager = Provider.of<ThemeManager>(context, listen: false);

    return ListTile(
      onTap: () {
        Navigator.pop(context);
        if ((value == 'emerald' || value == 'grey') && !isPro) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That theme requires Pro access')),
          );
        } else {
          themeManager.setTheme(value);
        }
      },
      leading: CircleAvatar(backgroundColor: color, radius: 14),
      title: Text(
        (value == 'emerald' || value == 'grey') ? '$label  (Pro)' : label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: (value == 'emerald' || value == 'grey')
              ? (isPro ? null : Colors.grey)
              : null,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: text.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Appearance',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: text.bodyLarge?.color?.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingTile(
                context,
                icon: Icons.color_lens_rounded,
                title: 'Theme',
                subtitle:
                'Current: ${themeManager.themeName[0].toUpperCase()}${themeManager.themeName.substring(1)}',
                onTap: () => _openThemePicker(context),
              ),
              const SizedBox(height: 25),
              Text(
                'Join the community!',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: text.bodyLarge?.color?.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingTile(
                context,
                icon: Icons.chat_rounded, // or another Material icon
                title: 'Discord',
                subtitle: 'Chat, updates and feedback',
                onTap: () async {
                  final uri = Uri.parse('https://discord.gg/VYubQJfcYM');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to open Discord link')),
                    );
                  }
                },
              ),
              const SizedBox(height: 25),
              Text(
                'Pro Features',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: text.bodyLarge?.color?.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 10),
              if (isPro)
                GestureDetector(
                  onTap: () => _showProOptions(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8860B),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB8860B).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB8860B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _showUpgradeDialog,
                        child: const Text(
                          'Upgrade to Pro (£2.99)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB8860B), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.info_outline, color: Color(0xFFB8860B)),
                        onPressed: _showProInfo,
                        tooltip: 'About Pro',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 25),
              Text(
                'General',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: text.bodyLarge?.color?.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingTile(
                context,
                icon: Icons.security_rounded,
                title: 'Privacy Policy',
                subtitle: 'View how your data is handled',
                onTap: () async {
                  final uri = Uri.parse('https://colourswift.com/Policies/Private-Policy');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to open link')),
                    );
                  }
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.info_outline_rounded,
                title: 'About ColourSwift Security',
                subtitle: 'Version 2.0.0',
              ),
              _buildSettingTile(
                context,
                icon: Icons.help_outline_rounded,
                title: 'How This App Works',
                subtitle: 'Learn about how ColourSwift Antivirus protects your device',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HowThisAppWorksScreen()),
                  );
                },
              ),
              _buildSettingTile(
                context,
                icon: Icons.lock_outline_rounded,
                title: 'Meta Password',
                subtitle: _metaPassword == null
                    ? 'Required for password vault'
                    : 'Stored securely (tap to change)',
                onTap: () async {
                  final controller = TextEditingController(
                    text: await _secure.read(key: 'meta_password') ?? '',
                  );

                  showDialog(
                    context: context,
                    builder: (context) {
                      bool obscure = true;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            scrollable: true,
                            title: const Text('Set Meta Password'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: controller,
                                    obscureText: obscure,
                                    decoration: InputDecoration(
                                      labelText: 'Meta password',
                                      prefixIcon: const Icon(Icons.key_rounded),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscure ? Icons.visibility_off : Icons.visibility,
                                        ),
                                        onPressed: () => setState(() => obscure = !obscure),
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '⚠️ Changing this will alter every generated password.\n\n'
                                          'However, entering the same meta password again will restore them, '
                                          'due to the apps algorithms.\n\n'
                                          'PLEASE REMEMBER OR WRITE DOWN YOUR META PASSWORD.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final value = controller.text.trim();
                                  if (value.isEmpty) return;
                                  await _secure.write(key: 'meta_password', value: value);
                                  setState(() => _metaPassword = value);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Meta password updated securely'),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },

              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        Widget? trailing,
        VoidCallback? onTap,
      }) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: text.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: text.bodySmall?.copyWith(
            color: text.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
