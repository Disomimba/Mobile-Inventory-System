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

class SettingsPage extends StatelessWidget {
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

  // RESPONSIVE ROUTING: Opens full screen on Mobile, floating Modal on Desktop
  void _openResponsivePage(BuildContext context, Widget page) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 800, // Capped width for Desktop Modal
            height: 750,
            child: page,
          ),
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 10),

          _buildSectionHeader("WAREHOUSE CONFIGURATION"),
          _buildSettingTile(
            icon: LucideIcons.map,
            color: Colors.blue,
            title: "Store Layout Designer",
            subtitle: "Manage racks, shelves, and pathways",
            onTap: () => _openResponsivePage(
              context,
              MapEditorPage(controller: controller),
            ),
          ),
          _buildSettingTile(
            icon: LucideIcons.printer,
            color: Colors.orange,
            title: "Generate QR Labels",
            subtitle: "Export printable PDF of item QR codes",
            onTap: () => _generateAndPrintQRLabels(context),
          ),
          if (controller.isAdmin) ...[
            _buildSectionHeader("ORGANIZATION"),
            const SizedBox(height: 20),

            _buildSettingTile(
              icon: LucideIcons.users,
              color: Colors.purple,
              title: "Staff Management",
              subtitle: "Create and manage staff accounts",
              onTap: () => _openResponsivePage(
                context,
                StaffManagementPage(controller: controller),
              ),
            ),
            _buildSettingTile(
              icon: LucideIcons.trendingUp,
              color: Colors.green,
              title: "Inventory Reports",
              subtitle: "Export stock levels to CSV/PDF",
              onTap: () {},
            ),
            _buildSettingTile(
              icon: LucideIcons.history,
              color: Colors.teal,
              title: "Transaction History",
              subtitle: "View all inventory transactions",
              onTap: () => _openResponsivePage(
                context,
                TransactionHistoryPage(controller: controller),
              ),
            ),
          ],

          const SizedBox(height: 20),
          _buildSectionHeader("ACCOUNT"),
          _buildSettingTile(
            icon: LucideIcons.lock,
            color: Colors.grey,
            title: "Change Password",
            onTap: () => _showChangePasswordDialog(context),
          ),
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

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      color: Colors.white,
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
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userId,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
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

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureText = true;
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text("Change Password"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureText,
                      decoration: const InputDecoration(
                        labelText: "Current Password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureText,
                      decoration: const InputDecoration(
                        labelText: "New Password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText ? LucideIcons.eye : LucideIcons.eyeOff,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (currentPasswordController.text.isEmpty ||
                              newPasswordController.text.isEmpty ||
                              confirmPasswordController.text.isEmpty) {
                            setState(
                              () => errorMessage = "Please fill in all fields.",
                            );
                            return;
                          }
                          if (newPasswordController.text.trim().length <= 6) {
                            setState(
                              () => errorMessage =
                                  "Password must be more than 6 characters.",
                            );
                            return;
                          }
                          if (newPasswordController.text !=
                              confirmPasswordController.text) {
                            setState(
                              () =>
                                  errorMessage = "New passwords do not match.",
                            );
                            return;
                          }

                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          final error = await controller.changePassword(
                            currentPasswordController.text,
                            newPasswordController.text,
                          );

                          if (error != null) {
                            setState(() {
                              errorMessage = error;
                              isSaving = false;
                            });
                          } else {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Password changed successfully!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndPrintQRLabels(BuildContext context) async {
    final items = controller.allItems;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No inventory items found to generate labels."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = pw.Document();
      const int itemsPerPage = 6;

      // Group items into chunks of 6 per page
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
                    width: 240, // Keeps it to exactly 2 columns wide on A4
                    height: 240, // Keeps it to exactly 3 rows high on A4
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
                            data: item
                                .sku, // Generates QR Code based on item's SKU
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

      // Close the loading dialog
      if (context.mounted) Navigator.pop(context);

      // Open the print / share preview layout
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Inventory_QR_Labels.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(
          context,
        ); // Make sure to hide the loading dialog if an error occurs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating PDF: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
