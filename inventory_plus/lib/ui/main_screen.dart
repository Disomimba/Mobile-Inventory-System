import 'package:flutter/material.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';

// Your UI Pages
import 'scanner_search_page.dart';
import 'inventory_page.dart';
import 'item_detail_page.dart';
import 'settings_page.dart';
import 'dashboard_page.dart';

class MainScreen extends StatefulWidget {
  final InventoryController controller;
  const MainScreen({super.key, required this.controller});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int? _currentIndex;
  bool _isDetailView = false;
  InventoryItem? _selectedItem;

  // --- DESKTOP COLOR PALETTE ---
  static const Color _primaryOrange = Color(0xFFEA580C);
  static const Color _darkSidebarBg = Color(0xFF0F172A);
  static const Color _mainBg = Color(0xFFF1F5F9);

  // --- REUSABLE PAGE FUNCTIONS ---
  void _handleSelectItem(InventoryItem item) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      // DESKTOP: Open details in a clean, floating modal
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 500, // Prevents full-screen stretching on Web
            height: 700,
            child: ItemDetailPage(
              item: item,
              controller: widget.controller,
              onBack: () => Navigator.pop(context),
              onUpdate: (updatedItem) async {
                await widget.controller.updateItem(updatedItem);
                // Synchronously trigger a UI rebuild once the work is done
                if (mounted) {
                  setState(() {});
                }
              },
              onDelete: (id) {
                setState(() => widget.controller.deleteItem(id));
                Navigator.pop(context);
              },
            ),
          ),
        ),
      );
    } else {
      // MOBILE: Slide into the detail view
      setState(() {
        _selectedItem = item;
        _isDetailView = true;
      });
    }
  }

  void _handleBackToMain() {
    setState(() {
      _isDetailView = false;
      _selectedItem = null;
    });
  }

  Future<void> _handleUpdateItem(InventoryItem item) async {
    await widget.controller.updateItem(item);
    if (mounted) {
      setState(() {
        _selectedItem = item;
      });
    }
  }

  void _handleDeleteItem(String id) {
    setState(() {
      widget.controller.deleteItem(id);
      _isDetailView = false;
      _selectedItem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If Mobile is viewing an item, override the main layout
    if (_isDetailView && _selectedItem != null) {
      return ItemDetailPage(
        item: _selectedItem!,
        controller: widget.controller,
        onBack: _handleBackToMain,
        onUpdate: _handleUpdateItem,
        onDelete: _handleDeleteItem,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        // 1. SET LANDING PAGES
        // Desktop defaults to Dashboard (0). Mobile defaults to Scan (1).
        _currentIndex ??= isDesktop ? 0 : 1;

        // 2. THE MASTER PAGE LIST
        final pages = [
          DashboardPage(controller: widget.controller), // Index 0
          ScannerSearchPage(
            controller: widget.controller,
            onSelectItem: _handleSelectItem,
          ), // Index 1
          InventoryPage(
            controller: widget.controller,
            onSelectItem: _handleSelectItem,
          ), // Index 2
          SettingsPage(
            controller: widget.controller,
            userName: widget.controller.currentUserName ?? "Unknown User",
            userId: widget.controller.currentUserId ?? "Unknown ID",
            userRole: widget.controller.currentUserRole ?? "staff",
          ), // Index 3
        ];

        // ==========================================
        // DESKTOP LAYOUT (Sidebar)
        // ==========================================
        if (isDesktop) {
          return Scaffold(
            backgroundColor: _mainBg,
            body: Row(
              children: [
                // Fixed Width Sidebar
                Container(
                  width: 240,
                  color: _darkSidebarBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 30.0,
                          vertical: 40.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              color: _primaryOrange,
                              size: 28,
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Inventory Plus',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSidebarItem(
                        0,
                        Icons.dashboard_outlined,
                        'Dashboard',
                        activeIcon: Icons.dashboard,
                      ),
                      _buildSidebarItem(1, Icons.qr_code_scanner, 'Scan'),
                      _buildSidebarItem(
                        2,
                        Icons.inventory_2_outlined,
                        'Inventory',
                        activeIcon: Icons.inventory_2,
                      ),
                      _buildSidebarItem(
                        3,
                        Icons.settings_outlined,
                        'Settings',
                        activeIcon: Icons.settings,
                      ),
                    ],
                  ),
                ),
                // Main Content Area
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: pages),
                ),
              ],
            ),
          );
        }

        // ==========================================
        // MOBILE LAYOUT (Bottom Navigation)
        // ==========================================

        // Map the overall page index to the Bottom Nav (which only has 3 items)
        int mobileNavIndex = 0;
        if (_currentIndex == 2) mobileNavIndex = 1; // Inventory page
        if (_currentIndex == 3) mobileNavIndex = 2; // Settings page

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.black,
            toolbarHeight: 0,
            elevation: 0,
          ),
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF1E293B),
            currentIndex: mobileNavIndex,
            selectedItemColor: _primaryOrange,
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              setState(() {
                // Map the tapped Nav icon back to the correct Page index
                if (index == 0) _currentIndex = 1; // Go to Scanner
                if (index == 1) _currentIndex = 2; // Go to Inventory
                if (index == 2) _currentIndex = 3; // Go to Settings
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Scanner',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'Inventory',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  // --- SIDEBAR HELPER WIDGET ---
  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label, {
    IconData? activeIcon,
  }) {
    final isSelected = _currentIndex == index;
    final currentColor = isSelected ? _primaryOrange : const Color(0xFF94A3B8);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        color: isSelected
            ? _primaryOrange.withOpacity(0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              isSelected ? (activeIcon ?? icon) : icon,
              color: currentColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: currentColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
