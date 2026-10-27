import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../navigation/main_section.dart';

class MobileMainDrawer extends StatelessWidget {
  const MobileMainDrawer({
    super.key,
    required this.sections,
    required this.selectedIndex,
    required this.role,
    required this.onSelectIndex,
  });

  final List<MainSection> sections;
  final int selectedIndex;
  final String role;
  final ValueChanged<int> onSelectIndex;

  static const _blue = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _slate = Color(0xFF64748B);
  static const _font = 'Hellix';

  (String, IconData) _destination(MainSection section) => switch (section) {
    MainSection.dashboard => ('Dashboard', LucideIcons.layoutDashboard),
    MainSection.forecasting => ('Forecasting', LucideIcons.trendingUp),
    MainSection.pos => (
      role == 'admin' ? 'Cash Monitor' : 'POS',
      LucideIcons.shoppingCart,
    ),
    MainSection.queue => (
      role == 'admin' ? 'Queue Monitor' : 'Order queue',
      LucideIcons.fileText,
    ),
    MainSection.inventory => ('Inventory', LucideIcons.box),
    MainSection.approvals => ('Approval Center', LucideIcons.clipboardCheck),
    MainSection.performance => ('Staff Performance', LucideIcons.barChart2),
    MainSection.history => ('History', LucideIcons.history),
    MainSection.transactions => ('Transactions', LucideIcons.history),
    MainSection.storeMap => ('Store Map', LucideIcons.map),
    MainSection.systemSettings => ('System Settings', LucideIcons.settings),
  };

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 22),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.package,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Inventory Plus',
                      style: TextStyle(
                        fontFamily: _font,
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close navigation menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 21, color: _slate),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'MENU',
                style: TextStyle(
                  fontFamily: _font,
                  color: _slate,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  final (label, icon) = _destination(section);
                  final selected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      key: Key('mobile-nav-${section.slug}'),
                      leading: Icon(
                        icon,
                        size: 20,
                        color: selected ? _blue : _slate,
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      selected: selected,
                      selectedColor: _blue,
                      selectedTileColor: const Color(0xFFEFF6FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectIndex(index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
