import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import 'ai_nanny_nav_button.dart';

/// Barra inferior com IA Babá central (5 destinos).
class ShellBottomNavigation extends StatelessWidget {
  const ShellBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.hideHomeActiveState,
    required this.navBarBackground,
    this.aiLocked = false,
    this.onAiTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool hideHomeActiveState;
  final Color navBarBackground;
  final bool aiLocked;
  final VoidCallback? onAiTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Material(
      color: navBarBackground,
      elevation: 8,
      shadowColor: Colors.black26,
      clipBehavior: Clip.none,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              _NavSlot(
                selected: selectedIndex == 0,
                hideIndicator: hideHomeActiveState && selectedIndex == 0,
                icon: Icons.home_outlined,
                selectedIcon: hideHomeActiveState ? Icons.home_outlined : Icons.home,
                label: s.home,
                onTap: () => onSelected(0),
              ),
              _NavSlot(
                selected: selectedIndex == 1,
                icon: Icons.edit_note_outlined,
                selectedIcon: Icons.edit_note,
                label: s.records,
                onTap: () => onSelected(1),
              ),
              Expanded(
                flex: 14,
                child: GestureDetector(
                  onTap: onAiTap ?? () => onSelected(2),
                  behavior: HitTestBehavior.opaque,
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: AiNannyNavButton(
                      selected: !aiLocked && selectedIndex == 2,
                      locked: aiLocked,
                      label: s.aiNannyNavLabel,
                    ),
                  ),
                ),
              ),
              _NavSlot(
                selected: selectedIndex == 3,
                icon: Icons.favorite_border,
                selectedIcon: Icons.favorite,
                label: s.memories,
                onTap: () => onSelected(3),
              ),
              _NavSlot(
                selected: selectedIndex == 4,
                icon: Icons.menu,
                selectedIcon: Icons.menu,
                label: s.more,
                onTap: () => onSelected(4),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.hideIndicator = false,
  });

  final bool selected;
  final bool hideIndicator;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected && !hideIndicator
        ? AppTheme.primaryPink
        : Colors.black.withAlpha(140);
    return Expanded(
      flex: 10,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
