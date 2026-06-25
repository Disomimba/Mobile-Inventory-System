import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/inventory_controller.dart';
import 'map_editor_page.dart';
import 'transaction_history_page.dart';
import 'staff_management_page.dart';
import 'profile_info_page.dart'; 

class SettingsPage extends StatefulWidget {
  final InventoryController controller;
  final String userName;
  final String userId;
  final String userRole;

  const SettingsPage({
    super.key,
    required this.controller,
    required this.userName,
    required this.userId,
    required this.userRole,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currentUserName;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
  }

  Future<dynamic> _openResponsivePage(BuildContext context, Widget page) async {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    if (isDesktop) {
      return await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 800,
            height: 750,
            child: page,
          ),
        ),
      );
    } else {
      return await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 10),
          
          _buildSectionHeader("WAREHOUSE CONFIGURATION"),
          
          _buildSettingTile(
            icon: LucideIcons.map,
            color: Colors.blue,
            title: "Store Layout Designer",
            subtitle: "Manage racks, shelves, and pathways",
            onTap: () => _openResponsivePage(
              context,
              MapEditorPage(controller: widget.controller),
            ),
          ),
          _buildSettingTile(
            icon: LucideIcons.printer,
            color: Colors.orange,
            title: "Generate QR Labels",
            subtitle: "Export printable PDF of item QR codes",
            onTap: () => _generateAndPrintQRLabels(context),
          ),
          if (widget.controller.isAdmin) ...[
            _buildSectionHeader("ORGANIZATION"),
            const SizedBox(height: 20),

            _buildSettingTile(
              icon: LucideIcons.users,
              color: Colors.purple,
              title: "Staff Management",
              subtitle: "Create and manage staff accounts",
              onTap: () => _openResponsivePage(
                context,
                StaffManagementPage(controller: widget.controller),
              ),
            ),
            _buildSettingTile(
              icon: LucideIcons.trendingUp,
              color: Colors.green,
              title: "Inventory Reports",
              subtitle: "Export stock levels to CSV/PDF",
              onTap: () => _showReportDialog(context),
            ),
            _buildSettingTile(
              icon: LucideIcons.history,
              color: Colors.teal,
              title: "Transaction History",
              subtitle: "View all inventory transactions",
              onTap: () => _openResponsivePage(
                context,
                TransactionHistoryPage(controller: widget.controller),
              ),
            ),
          ],

          const SizedBox(height: 20),
          _buildSectionHeader("ACCOUNT"),
          _buildSettingTile(
            icon: LucideIcons.logOut,
            color: Colors.redAccent,
            title: "Logout",
            textColor: Colors.redAccent,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                "Version 1.0.4",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(
          LucideIcons.chevronRight,
          size: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String selectedPeriod = 'Daily';
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text('Generate Inventory Report'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select the report type/period:'),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: selectedPeriod,
                    isExpanded: true,
                    items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedPeriod = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(stateContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(stateContext);
                    _generateAndPrintInventoryReport(context, selectedPeriod);
                  },
                  child: const Text('Generate PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndPrintInventoryReport(
      BuildContext context, String period) async {
    final items = widget.controller.allItems;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No inventory items found to generate report."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      DateTime now = DateTime.now();
      DateTime cutoffDate;
      if (period == 'Daily') {
        cutoffDate = DateTime(now.year, now.month, now.day); 
      } else if (period == 'Weekly') {
        cutoffDate = now.subtract(const Duration(days: 7));
      } else {
        cutoffDate = now.subtract(const Duration(days: 30)); 
      }

      final allTransactions = await widget.controller.fetchAllTransactionHistory();
      final periodTransactions = allTransactions.where((tx) {
        final txDate = DateTime.parse(tx['created_at']).toLocal();
        return txDate.isAfter(cutoffDate);
      }).toList();

      Map<String, int> issuedDetails = {};
      Map<String, int> receivedDetails = {};

      for (var tx in periodTransactions) {
        final qty = tx['quantity_change'] as int;
        final productId = tx['product_id'] as String; 

        if (tx['transaction_type'] == 'checkout') {
          issuedDetails[productId] = (issuedDetails[productId] ?? 0) + qty.abs();
        } else if (tx['transaction_type'] == 'stock_in' || tx['transaction_type'] == 'add') {
          receivedDetails[productId] = (receivedDetails[productId] ?? 0) + qty;
        }
      }

      double grandTotalValue = 0;
      double grandTotalItems = 0.0;
      
      final tableRows = <pw.TableRow>[];

      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            'Item Code', 'Item Name', 'Beginning Qty', 'Received', 
            'Issued', 'Ending Qty', 'Unit Cost', 'Total Value'
          ].map((text) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              )).toList(),
        ),
      );

      for (var item in items) {
        final issued = issuedDetails[item.id] ?? 0;
        final received = receivedDetails[item.id] ?? 0;
        final endingQty = item.quantity;
        
        final beginningQty = endingQty - received + issued; 
        
        final totalValue = endingQty * item.price;

        grandTotalValue += totalValue;
        grandTotalItems += endingQty;

        tableRows.add(
          pw.TableRow(
            children: [
              item.sku,
              item.name,
              beginningQty.toString(),
              received.toString(),
              issued.toString(),
              endingQty.toString(),
              '\$${item.price.toStringAsFixed(2)}',
              '\$${totalValue.toStringAsFixed(2)}'
            ].map((text) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
                )).toList(),
          ),
        );
      }

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Inventory Summary Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Report Type: $period', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date Generated: ${now.toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    )
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), 
                  1: const pw.FlexColumnWidth(4), 
                  2: const pw.FlexColumnWidth(1.5), 
                  3: const pw.FlexColumnWidth(1.5), 
                  4: const pw.FlexColumnWidth(1.5), 
                  5: const pw.FlexColumnWidth(1.5), 
                  6: const pw.FlexColumnWidth(1.5), 
                  7: const pw.FlexColumnWidth(2), 
                },
                children: tableRows,
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Items in Stock (Ending): ${grandTotalItems.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Total Inventory Value: \$${grandTotalValue.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();

      if (context.mounted) Navigator.pop(context);

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Inventory_Report_${period}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating PDF: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _generateAndPrintQRLabels(BuildContext context) async {
    final items = widget.controller.allItems;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No inventory items found to generate labels."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = pw.Document();
      const int itemsPerPage = 6;

      for (var i = 0; i < items.length; i += itemsPerPage) {
        final chunk = items.skip(i).take(itemsPerPage).toList();

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: chunk.map((item) {
                  return pw.Container(
                    width: 240, 
                    height: 240, 
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey, width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          item.name,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "SKU: ${item.sku}",
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Expanded(
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: item.sku, 
                            drawText: false,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          "Price: \$${item.price.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }

      final bytes = await doc.save();

      if (context.mounted) Navigator.pop(context);

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Inventory_QR_Labels.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating PDF: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
  
  Widget _buildProfileHeader(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          final updatedName = await _openResponsivePage(
            context,
            ProfileInfoPage(
              controller: widget.controller,
              currentName: _currentUserName, 
              currentEmail: widget.controller.loggedInUserEmail,
              userId: widget.userId,
              role: widget.userRole,
            ),
          );

          if (updatedName != null && updatedName is String && mounted) {
            setState(() {
              _currentUserName = updatedName;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: const Icon(LucideIcons.user, color: Colors.orange, size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUserName, 
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.userId,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 