import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/inventory_controller.dart';

class ProfileInfoPage extends StatefulWidget {
  final InventoryController controller;
  final String currentName;
  final String? currentEmail;
  final String userId;
  final String role;

  const ProfileInfoPage({
    super.key,
    required this.controller,
    required this.currentName,
    this.currentEmail,
    required this.userId,
    required this.role,
  });

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _isFetching = true;
  
  // ADD STATE VARIABLE FOR EDIT MODE
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail ?? "");
    
    // Fetch latest data from database immediately on load
    _loadLatestDataFromDatabase();
  }

  Future<void> _loadLatestDataFromDatabase() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('email, name')
          .eq('id', widget.userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _emailController.text = data['email'] ?? "";
          _nameController.text = data['name'] ?? widget.currentName;
          _isFetching = false;
        });
      } else if (mounted) {
         setState(() {
            _isFetching = false;
         });
      }
    } catch (e) {
      debugPrint("Error fetching latest profile data: $e");
      if (mounted) {
         setState(() {
            _isFetching = false;
         });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();

      if (newName.isEmpty) {
        throw Exception("Name cannot be empty.");
      }

      await widget.controller.updateProfile(
        userId: widget.userId,
        name: newName,
        email: newEmail,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, newName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating profile: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                            setState(() => errorMessage = "Please fill in all fields.");
                            return;
                          }
                          if (newPasswordController.text.trim().length <= 6) {
                            setState(() => errorMessage = "Password must be more than 6 characters.");
                            return;
                          }
                          if (newPasswordController.text != confirmPasswordController.text) {
                            setState(() => errorMessage = "New passwords do not match.");
                            return;
                          }

                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          final error = await widget.controller.changePassword(
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
                                  content: Text("Password changed successfully!"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Profile Info",
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // TOGGLE BETWEEN EDIT AND SAVE BUTTONS
          if (!_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: const Text("Edit", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            )
          else
            TextButton(
              onPressed: (_isLoading || _isFetching) ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Save", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isFetching 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // JUST A STATIC AVATAR NOW
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: const Icon(LucideIcons.user, color: Colors.orange, size: 40),
              ),
            ),
            const SizedBox(height: 32),

            const Text("Role", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.role.toUpperCase(),
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 24),
            const Text("Full Name", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              readOnly: !_isEditing, // MAKE READ-ONLY IF NOT EDITING
              decoration: InputDecoration(
                filled: true,
                fillColor: _isEditing ? Colors.white : Colors.transparent, // Remove background when viewing
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: _isEditing ? BorderSide.none : const BorderSide(color: Colors.black12),
                ),
                prefixIcon: const Icon(LucideIcons.user, color: Colors.grey, size: 18),
              ),
            ),

            const SizedBox(height: 24),
            const Text("Email Address", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              readOnly: !_isEditing, // MAKE READ-ONLY IF NOT EDITING
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: _isEditing ? "Enter your email" : "No email set",
                filled: true,
                fillColor: _isEditing ? Colors.white : Colors.transparent, // Remove background when viewing
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: _isEditing ? BorderSide.none : const BorderSide(color: Colors.black12),
                ),
                prefixIcon: const Icon(LucideIcons.mail, color: Colors.grey, size: 18),
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showChangePasswordDialog(context),
                icon: const Icon(LucideIcons.lock, size: 18),
                label: const Text("Change Password"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}