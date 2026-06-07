import 'package:flutter/material.dart';
import '../data/inventory.dart';
import '../logic/inventory_controller.dart';

// Your UI Pages
import 'inventory_page.dart';
import 'item_detail_page.dart';
import 'settings_page.dart';
import 'dashboard_page.dart';
import 'pos_cart_page.dart';
import 'order_queue_page.dart';

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
        final role = widget.controller.currentUserRole?.toLowerCase() ?? 'staff';
        final isAdmin = role == 'admin';
        final isCashier = role == 'staff';
        final isHelper = role == 'helper';

        // 1. SET LANDING PAGES
        _currentIndex ??= 0;

        // 2. DYNAMIC INDICES BASED ON ROLE
        int pageIndex = 0;
        final int dashboardIndex = isAdmin ? pageIndex++ : -1;
        final int posIndex = isCashier ? pageIndex++ : -1;
        final int orderQueueIndex = isHelper ? pageIndex++ : -1;
        final int inventoryIndex = pageIndex++;
        final int settingsIndex = pageIndex++;

        // 3. THE MASTER PAGE LIST
        final pages = <Widget>[];
        
        if (isAdmin) {
          pages.add(DashboardPage(controller: widget.controller));
        }
        if (isCashier) {
          pages.add(PosCartPage(controller: widget.controller));
        }
        if (isHelper) {
          pages.add(OrderQueuePage(controller: widget.controller));
        }
        
        pages.addAll([
          InventoryPage(
            controller: widget.controller,
            onSelectItem: _handleSelectItem,
          ),
          SettingsPage(
            controller: widget.controller,
            userName: widget.controller.currentUserName ?? "Unknown User",
            userId: widget.controller.currentUserId ?? "Unknown ID",
            userRole: widget.controller.currentUserRole ?? "staff",
          ),
        ]);

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
                      if (isAdmin)
                        _buildSidebarItem(
                          dashboardIndex,
                          Icons.dashboard_outlined,
                          'Dashboard',
                          activeIcon: Icons.dashboard,
                        ),
                      if (isCashier)
                        _buildSidebarItem(
                          posIndex,
                          Icons.point_of_sale_outlined,
                          'POS System',
                          activeIcon: Icons.point_of_sale,
                        ),
                      if (isHelper)
                        _buildSidebarItem(
                          orderQueueIndex,
                          Icons.receipt_long_outlined,
                          'Order Queue',
                          activeIcon: Icons.receipt_long,
                        ),
                      _buildSidebarItem(
                        inventoryIndex,
                        Icons.inventory_2_outlined,
                        'Inventory',
                        activeIcon: Icons.inventory_2,
                      ),
                      _buildSidebarItem(
                        settingsIndex,
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

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.black,
            toolbarHeight: 0,
            elevation: 0,
          ),
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: Colors.orange,
              labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
                (Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12);
                  }
                  return const TextStyle(color: Colors.grey, fontSize: 12);
                },
              ),
            ),
            child: NavigationBar(
              backgroundColor: const Color(0xFF1E1E1E), // Dark brown/black theme
              selectedIndex: _currentIndex!,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: [
                if (isAdmin)
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.dashboard, color: Colors.white),
                    label: 'Dashboard',
                  ),
                if (isCashier)
                  const NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.point_of_sale, color: Colors.white),
                    label: 'POS',
                  ),
                if (isHelper)
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined, color: Colors.grey),
                    selectedIcon: Icon(Icons.receipt_long, color: Colors.white),
                    label: 'Queue',
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.assignment_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.assignment, color: Colors.white),
                  label: 'Inventory',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.settings, color: Colors.white),
                  label: 'Settings',
                ),
              ],
            ),
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
