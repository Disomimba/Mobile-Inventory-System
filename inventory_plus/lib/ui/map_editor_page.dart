import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/inventory.dart';
import '../../logic/inventory_controller.dart'; 
import 'store_map.dart';

class MapEditorPage extends StatefulWidget {
  final InventoryController controller;

  const MapEditorPage({super.key, required this.controller});

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  MapMode _mode = MapMode.manage;
  String? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Layout Designer"),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            onPressed: () {
              widget.controller.clearMapLayout().then((_) {
                if (mounted) {
                  setState(() {});
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.save),
            onPressed: () async {
              await widget.controller.saveLayout(); 
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Store layout saved successfully!")),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(),
          if (_mode == MapMode.manage) _buildManageToolbar(),
          if (_mode == MapMode.selection) _buildSelectionToolbar(),
          Expanded(
            child: StoreMap(
              controller: widget.controller,
              mode: _mode,
              selectedItemId: _selectedItemId,
              onSelectionAssigned: () {
                setState(() {
                  _selectedItemId = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: const Color(0xFF0F172A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModeButton(MapMode.manage, LucideIcons.pencil, "Manage Layout"),
          const SizedBox(width: 16),
          _buildModeButton(MapMode.selection, LucideIcons.link, "Assign Items"),
        ],
      ),
    );
  }

  Widget _buildModeButton(MapMode mode, IconData icon, String label) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = mode;
          _selectedItemId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text("Drag to map:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 16),
            _buildDraggableTool(ElementType.door, "Door", Colors.green),
            _buildDraggableTool(ElementType.rack, "Rack", Colors.blue),
            _buildDraggableTool(ElementType.shelf, "Shelf", Colors.orange),
            _buildDraggableTool(ElementType.cashier, "Cashier", Colors.purple),
            _buildDraggableTool(ElementType.pathway, "Path", Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableTool(ElementType type, String label, Color color) {
    IconData getIcon(ElementType t) {
      switch (t) {
        case ElementType.door: return LucideIcons.doorOpen;
        case ElementType.rack: return LucideIcons.layers;
        case ElementType.shelf: return LucideIcons.container;
        case ElementType.cashier: return LucideIcons.banknote;
        case ElementType.pathway: return LucideIcons.footprints;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Draggable<ElementType>(
        data: type,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Icon(getIcon(type), color: Colors.white),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color),
          ),
          child: Row(
            children: [
              Icon(getIcon(type), size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    final items = widget.controller.allItems.toList()
      ..sort((a, b) {
        if (a.locationId == null && b.locationId != null) return -1;
        if (a.locationId != null && b.locationId == null) return 1;
        return a.name.compareTo(b.name);
      });
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E293B),
      width: double.infinity,
      child: Row(
        children: [
          const Icon(LucideIcons.link, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: const Color(0xFF1E293B),
                isExpanded: true,
                iconEnabledColor: Colors.orange,
                hint: const Text("Choose item to assign...", style: TextStyle(color: Colors.white70, fontSize: 13)),
                value: _selectedItemId,
                items: items.map((item) {
                  final status = item.locationId == null ? "Unassigned" : "Assigned";
                  return DropdownMenuItem<String>(
                    value: item.id,
                    child: Text("${item.name} ($status)", style: const TextStyle(color: Colors.white, fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedItemId = val;
                  });
                },
              ),
            ),
          ),
          if (_selectedItemId != null)
            const Padding(
              padding: EdgeInsets.only(left: 12.0),
              child: Text("Tap Rack to link", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}