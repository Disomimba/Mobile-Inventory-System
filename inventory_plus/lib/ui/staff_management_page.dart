import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../logic/inventory_controller.dart';

class StaffManagementPage extends StatefulWidget {
  final InventoryController controller;

  const StaffManagementPage({super.key, required this.controller});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  List<Map<String, dynamic>> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final staff = await widget.controller.fetchStaff();
    
    // Filter out the currently logged-in user
    final currentUserId = widget.controller.currentUserId;
    final filteredStaff = staff.where((s) => s['id'].toString() != currentUserId).toList();

    setState(() {
      _staffList = filteredStaff;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Staff Management",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          // Constrained Box to prevent horizontal stretching on Web
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staffList.length,
                  itemBuilder: (context, index) {
                    final staff = _staffList[index];
                    return _buildStaffCard(staff);
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(LucideIcons.userPlus, color: Colors.white),
        label: const Text(
          "Add Staff",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final isAdmin = staff['role'] == 'admin';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isAdmin // Use orange for admins
              ? Colors.orange.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          child: Icon(
            isAdmin ? LucideIcons.shieldCheck : LucideIcons.user, // Orange icon for admins
            color: isAdmin ? Colors.orange : Colors.blue,
          ),
        ),
        title: Text(
          staff['name'] ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          staff['role'].toString().toUpperCase(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(LucideIcons.eye, color: Colors.blue),
          onPressed: () => _showStaffDetailsModal(staff), // New modal
        ),
      ),
    );
  }

  void _showAddStaffDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'staff';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Add New Staff",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400, // Keeps the modal at a nice compact width
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    validator: (val) => val == null || val.trim().length < 2
                        ? 'Name must be at least 2 characters'
                        : null,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(LucideIcons.user),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: userCtrl,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (val.contains(' ')) {
                        return 'Username cannot contain spaces';
                      }
                      if (val.trim().length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(LucideIcons.atSign),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    validator: (val) => val == null || val.trim().length <= 6
                        ? 'Password must be more than 6 characters'
                        : null,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(LucideIcons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: "Role",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.shield),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'helper', child: Text('Helper')),
                    ],
                    onChanged: (val) => setState(() => selectedRole = val!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isSaving = true);
                      final success = await widget.controller.createStaff(
                        name: nameCtrl.text.trim(),
                        username: userCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                        role: selectedRole,
                      );
                      if (success) {
                        Navigator.pop(context);
                        _loadStaff();
                      } else {
                        setState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error creating staff account'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffDetailsModal(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750), // Matches the wide design
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.orange),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Staff Profile Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Body Layout 
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    // Left Side: Profile Details
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Profile Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7F2), 
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.orange,
                                  child: Text(
                                    _getInitials(staff['name']),
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Display Name in ALL CAPS
                                          Text(
                                            (staff['name'] ?? 'Unknown User').toUpperCase(),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              (staff['role'] ?? 'staff').toString().toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10, 
                                                color: Colors.blue, 
                                                fontWeight: FontWeight.bold
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          // Pull Location from Database
                                          Text(
                                            staff['address'] ?? "No adress provided", 
                                            style: const TextStyle(color: Colors.grey, fontSize: 12)
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Details Grid matching the screenshot
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              // Row 1
                              _buildInfoTile("USERNAME", staff['username'] ?? 'N/A', LucideIcons.user),
                              _buildInfoTile("EMAIL ADDRESS", staff['email'] ?? 'Not provided', LucideIcons.mail),
                              
                              // Row 2
                              _buildInfoTile("FULL LEGAL NAME", staff['name'] ?? 'N/A', LucideIcons.clipboardList, fullWidth: true),
                              
                              // Row 3
                              // Note: Assuming 'created_at' is your date column. Update the key if it's named differently.
                              _buildInfoTile("JOINED AT", staff['created_at'] != null ? "Joined ${staff['created_at'].toString().substring(0, 10)}" : 'N/A', LucideIcons.calendar, fullWidth: true),
                              
                              // Row 4
                              _buildInfoTile("PHONE NUMBER", staff['phone'] ?? 'Not provided', LucideIcons.phone),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Right Side: Action Buttons
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(LucideIcons.shieldAlert, size: 16, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  "Account Actions", 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEditStaffDialog(staff);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(LucideIcons.pencil, size: 16),
                                label: const Text("Change Role"),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showResetPasswordDialog(staff);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(LucideIcons.refreshCw, size: 16),
                                label: const Text("Reset Password"),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final success = await widget.controller.deleteStaff(staff['id'].toString());
                                  if (success) _loadStaff();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(LucideIcons.trash2, size: 16),
                                label: const Text("Delete Account"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget to draw the clean info boxes
  Widget _buildInfoTile(String label, String value, IconData icon, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : 217, // Fits two side-by-side in the 450 constraint
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value, 
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper string method to grab initials (e.g., "Yves Carranza" -> "YC")
  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return "??";
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  void _showResetPasswordDialog(Map<String, dynamic> staff) {
    final newPass = _generateDefaultPassword(staff['name'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reset Password"),
        content: Text.rich(
          TextSpan(
            text: "Are you sure you want to reset the password for ",
            children: [
              TextSpan(text: "${staff['name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: "?\n\nIt will be updated to: "),
              TextSpan(
                text: newPass, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)
              ),
            ]
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await widget.controller.adminResetUserPassword(staff['id'].toString(), newPass);
              
              Navigator.pop(context); // Close dialog

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password successfully reset to $newPass')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to reset password. Please try again.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text("Confirm Reset"),
          ),
        ],
      ),
    );
  }

  String _generateDefaultPassword(String name) {
    if (name.trim().isEmpty) return "default123";
    
    List<String> parts = name.trim().toLowerCase().split(RegExp(r'\s+'));
    
    String first = parts.first;
    // Map the remaining parts to just their first letter
    String initials = parts.length > 1 ? parts.sublist(1).map((p) => p[0]).join() : "";
    
    return "$first${initials}123"; 
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    String selectedRole = staff['role'] ?? 'staff';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Edit ${staff['name'] ?? 'Staff'}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Role",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.shield),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'helper', child: Text('Helper')),
                  ],
                  onChanged: (val) => setState(() => selectedRole = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      final success = await widget.controller.updateStaffRole(
                        staff['id'].toString(),
                        selectedRole,
                      );
                      if (success) {
                        Navigator.pop(context);
                        _loadStaff();
                      } else {
                        setState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error updating role')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}