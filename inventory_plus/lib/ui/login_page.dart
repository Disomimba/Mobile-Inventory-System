import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../login/auth_service.dart';
import '../logic/inventory_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final InventoryController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final userProfile = await _authService.login(username, password);

      if (userProfile != null) {
        final String? assignedLocationId = userProfile['location_id'];
        final String userId = userProfile['id'].toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', userId);

        widget.controller.setLoggedInUser(
          name: userProfile['name'] ?? username,
          id: userId,
          role: userProfile['role'] ?? 'staff',
          email: userProfile['email'],
        );

        if (assignedLocationId != null && assignedLocationId.isNotEmpty) {
          await widget.controller.loadAppData(assignedLocationId);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/main');
          }
        } else {
          _showError("Account Error: No store assigned to this user.");
          await prefs.clear();
        }
      } else {
        _showError("Invalid username or password");
      }
    } catch (e) {
      _showError("An unexpected error occurred during login.");
      debugPrint("Login Page Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }
  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151D2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Row(
          children: [
            Icon(LucideIcons.shieldAlert, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text(
              "Account Recovery", 
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "For security purposes, self-service password resets are disabled for operator accounts.\n\nPlease contact your System Administrator or Manager to have your password reset.",
          style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Understood", 
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1423),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              // Reduced max width from 420 to 380 to make it slightly smaller
              constraints: const BoxConstraints(maxWidth: 380),
              // Reduced padding to keep proportions right on a smaller card
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF151D2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.packageCheck,
                          color: Colors.orange,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Inventory Plus",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        "Hardware Management System",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      "Username",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _usernameController,
                      "Enter your operator ID",
                      LucideIcons.user,
                      false,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Password",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      _passwordController,
                      "••••••••",
                      LucideIcons.lock,
                      true,
                      suffix: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? LucideIcons.eye
                              : LucideIcons.eyeOff,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Forgot Credentials only
                    // Forgot Credentials only
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () => _showForgotPasswordDialog(context), // <-- Update this line
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: const Text(
      "Forgot credentials?",
      style: TextStyle(
        color: Colors.orange,
        fontSize: 12,
      ),
    ),
  ),
),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(LucideIcons.logIn, size: 18),
                                ],
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 24),
                    
                    // Terms and Privacy
                    const Center(
                      child: Text(
                        "Terms of Service   •   Privacy Policy",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    bool isPassword, {
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return isPassword ? 'Password is required' : 'Username is required';
        }
        if (isPassword && text.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (!isPassword && text.length < 3) {
          return 'Username must be at least 3 characters';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0F1423),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.orange, width: 1),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}