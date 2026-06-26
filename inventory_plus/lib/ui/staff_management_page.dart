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

    final currentUserId = widget.controller.currentUserId;
    final filteredStaff =
        staff.where((s) => s['id'].toString() != currentUserId).toList();

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
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange))
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isAdmin
              ? Colors.orange.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          child: Icon(
            isAdmin ? LucideIcons.shieldCheck : LucideIcons.user,
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
          onPressed: () => _showStaffDetailsModal(staff),
        ),
      ),
    );
  }

  // ─── REDESIGNED Add Staff Dialog ─────────────────────────────────────────

  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'staff';
    bool isSaving = false;
    String defaultPassword = "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          nameCtrl.addListener(() {
            setModalState(() {
              defaultPassword = _generateDefaultPassword(nameCtrl.text);
            });
          });

          return Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.userPlus,
                              color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Add New Staff",
                                  style: TextStyle(
                                      color: Color(0xFF1A1F36),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text("Fill in the details to create an account",
                                  style: TextStyle(
                                      color: Color(0xFF8892A4), fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Color(0xFFB0B7C3), size: 18),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Fields ───────────────────────────────────────────
                    _buildDarkField(
                      controller: nameCtrl,
                      label: "Full Name",
                      hint: "Enter full name",
                      icon: LucideIcons.user,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkField(
                      controller: userCtrl,
                      label: "Username",
                      hint: "Enter username",
                      icon: LucideIcons.atSign,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkField(
                      controller: emailCtrl,
                      label: "Email Address",
                      hint: "Enter email (optional)",
                      icon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkField(
                      controller: phoneCtrl,
                      label: "Phone Number",
                      hint: "Enter phone (optional)",
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkField(
                      controller: addressCtrl,
                      label: "Address",
                      hint: "Enter address (optional)",
                      icon: LucideIcons.mapPin,
                    ),
                    const SizedBox(height: 16),

                    // ── Role Dropdown ────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Role",
                            style: TextStyle(
                                color: Color(0xFF4A5568),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                              color: Color(0xFF1A1F36), fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.shield,
                                color: Color(0xFF8892A4), size: 16),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Colors.orange, width: 1)),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'staff', child: Text('Staff')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(
                                value: 'helper', child: Text('Helper')),
                          ],
                          onChanged: (val) =>
                              setModalState(() => selectedRole = val!),
                        ),
                      ],
                    ),

                    // ── Default Password Preview ─────────────────────────
                    if (defaultPassword.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.keyRound,
                                color: Color(0xFF16A34A), size: 16),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Default Password",
                                    style: TextStyle(
                                        color: Color(0xFF4A5568), fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(defaultPassword,
                                    style: const TextStyle(
                                        color: Color(0xFF15803D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Buttons ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A5568),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (nameCtrl.text.trim().isEmpty ||
                                        userCtrl.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            "Name and username are required."),
                                        backgroundColor: Colors.redAccent,
                                      ));
                                      return;
                                    }
                                    setModalState(() => isSaving = true);
                                    final success =
                                        await widget.controller.createStaff(
                                      name: nameCtrl.text.trim(),
                                      username: userCtrl.text.trim(),
                                      password: defaultPassword,
                                      email: emailCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim(),
                                      address: addressCtrl.text.trim(),
                                      role: selectedRole,
                                    );
                                    if (success) {
                                      Navigator.pop(context);
                                      _loadStaff();
                                    } else {
                                      setModalState(() => isSaving = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            "Failed to create staff. Username may already exist."),
                                        backgroundColor: Colors.redAccent,
                                      ));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text("Create Account",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDarkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF4A5568),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0B7C3)),
            prefixIcon: Icon(icon, color: const Color(0xFF8892A4), size: 16),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Colors.orange, width: 1)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  // ─── Staff Details Modal (unchanged) ─────────────────────────────────────

  void _showStaffDetailsModal(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine if the screen is small (mobile width)
            bool isMobile = constraints.maxWidth < 650;

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Modal Header ─────────────────────────
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

                      // ─── Dynamic Responsive Layout ──────────────
                      Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Information Section
                          Flexible(
                            flex: isMobile ? 0 : 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Profile Header Card
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
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              children: [
                                                Text(
                                                  (staff['name'] ?? 'Unknown User').toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold),
                                                ),
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
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded( // Expanded prevents long addresses from breaking the row
                                                  child: Text(
                                                    staff['address'] ?? "No address provided",
                                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
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

                                // Info Tiles (Use Column for mobile, Wrap for desktop)
                                if (isMobile)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildInfoTile("USERNAME", staff['username'] ?? 'N/A', LucideIcons.user, fullWidth: true),
                                      const SizedBox(height: 12),
                                      _buildInfoTile("EMAIL ADDRESS", staff['email'] ?? 'Not provided', LucideIcons.mail, fullWidth: true),
                                      const SizedBox(height: 12),
                                      _buildInfoTile("FULL LEGAL NAME", staff['name'] ?? 'N/A', LucideIcons.clipboardList, fullWidth: true),
                                      const SizedBox(height: 12),
                                      _buildInfoTile("JOINED AT", staff['created_at'] != null ? "Joined ${staff['created_at'].toString().substring(0, 10)}" : 'N/A', LucideIcons.calendar, fullWidth: true),
                                      const SizedBox(height: 12),
                                      _buildInfoTile("PHONE NUMBER", staff['phone'] ?? 'Not provided', LucideIcons.phone, fullWidth: true),
                                    ],
                                  )
                                else
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      _buildInfoTile("USERNAME", staff['username'] ?? 'N/A', LucideIcons.user),
                                      _buildInfoTile("EMAIL ADDRESS", staff['email'] ?? 'Not provided', LucideIcons.mail),
                                      _buildInfoTile("FULL LEGAL NAME", staff['name'] ?? 'N/A', LucideIcons.clipboardList, fullWidth: true),
                                      _buildInfoTile("JOINED AT", staff['created_at'] != null ? "Joined ${staff['created_at'].toString().substring(0, 10)}" : 'N/A', LucideIcons.calendar, fullWidth: true),
                                      _buildInfoTile("PHONE NUMBER", staff['phone'] ?? 'Not provided', LucideIcons.phone),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          // Add spacing between the two main columns on Desktop, or vertical spacing on Mobile
                          if (!isMobile) const SizedBox(width: 24),
                          if (isMobile) const SizedBox(height: 24),

                          // Account Actions Section
                          ConstrainedBox(
                            // Make it take full width on mobile, max 220px on desktop
                            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 220),
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
                                      Text("Account Actions",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
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
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
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
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : 217,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reset Password"),
        content: Text.rich(
          TextSpan(
            text: "Are you sure you want to reset the password for ",
            children: [
              TextSpan(
                  text: "${staff['name']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: "?\n\nIt will be updated to: "),
              TextSpan(
                  text: newPass,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await widget.controller.adminResetUserPassword(
                  staff['id'].toString(), newPass);
              Navigator.pop(context);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Password successfully reset to $newPass')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Failed to reset password. Please try again.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
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
    String initials = parts.length > 1
        ? parts.sublist(1).map((p) => p[0]).join()
        : "";
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
          content: SingleChildScrollView(
            child: SizedBox(
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey)),
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
                          const SnackBar(
                              content: Text('Error updating role')),
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
                          color: Colors.white, strokeWidth: 2))
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}