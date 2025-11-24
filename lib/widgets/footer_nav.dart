import 'package:flutter/material.dart';

class FooterNav extends StatelessWidget {
  final String active;
  final Function(String) onTabChange;

  const FooterNav({
    super.key,
    required this.active,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor = theme.colorScheme.surfaceVariant.withOpacity(0.95);
    if (theme.brightness == Brightness.dark) {
      bgColor = theme.colorScheme.surface.withOpacity(0.95);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildItem(context, Icons.home_rounded, 'Home', 'home'),
            _buildItem(context, Icons.star_outline_rounded, 'Features', 'features'),
            _buildItem(context, Icons.shield_outlined, 'Quarantine', 'quarantine'),
            _buildItem(context, Icons.settings_outlined, 'Settings', 'settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
      BuildContext context,
      IconData icon,
      String title,
      String tag,
      ) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    final bool isActive = (active == tag);
    final color = isActive ? theme.colorScheme.primary : Colors.grey;
    final bg = isActive
        ? theme.colorScheme.primary.withOpacity(0.12)
        : Colors.transparent;

    return GestureDetector(
      onTap: () => onTabChange(tag),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: text.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
