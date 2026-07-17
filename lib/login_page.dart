import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_role.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State untuk show/hide password
  bool _isPasswordVisible = false;
  UserRole _selectedRole = UserRole.student;

  // Warna Tema (Bisa diganti sesuai brand)
  final Color _primaryColor = const Color(0xFF2563EB); // Modern Blue

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mendapatkan ukuran layar untuk responsivitas sederhana
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              /// 1. Logo / Ilustrasi Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_person_rounded, // Atau ganti dengan Logo App Anda
                  size: 64,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              /// 2. Title & Subtitle
              Text(
                "Selamat Datang Kembali!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[900],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Masuk untuk mengelola data kelas Anda",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              /// 3. Form Input
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputLabel("Masuk sebagai"),
                    DropdownButtonFormField<UserRole>(
                      initialValue: _selectedRole,
                      decoration: _inputDecoration(
                        hint: 'Pilih role',
                        icon: Icons.manage_accounts_outlined,
                      ),
                      items: UserRole.loginRoles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.label),
                            ),
                          )
                          .toList(),
                      onChanged: (role) {
                        if (role != null) {
                          setState(() => _selectedRole = role);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    /// Email Input
                    _buildInputLabel("Email Address"),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        hint: 'nama@email.com',
                        icon: Icons.alternate_email_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!value.contains('@')) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildInputLabel("Password"),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password wajib diisi';
                        }
                        if (value.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),

                    // Lupa Password (Opsional)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          "Lupa Password?",
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: _primaryColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _handleLogin,
                        child: const Text(
                          "Masuk Sekarang",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Belum punya akun? ",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: Text(
                      "Daftar Disini",
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC), // Warna abu-abu sangat muda
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade200),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      EasyLoading.show(status: 'Sedang memuat...');
      final supabase = Supabase.instance.client;

      try {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final appUser = await AuthService.instance.refreshSession();

        if (appUser == null) {
          throw StateError('Profil pengguna tidak ditemukan.');
        }
        if (!appUser.isActive) {
          await AuthService.instance.signOut();
          EasyLoading.dismiss();
          final message = appUser.approvalStatus.name == 'rejected'
              ? 'Permintaan role Anda ditolak oleh Admin.'
              : 'Akun ${appUser.requestedRole?.label ?? _selectedRole.label} '
                    'masih menunggu persetujuan Admin.';
          EasyLoading.showError(message);
          return;
        }
        if (!appUser.role.matchesLoginRole(_selectedRole)) {
          await AuthService.instance.signOut();
          EasyLoading.dismiss();
          EasyLoading.showError(
            'Akun ini terdaftar sebagai ${appUser.role.label}.',
          );
          return;
        }

        EasyLoading.dismiss();

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AuthService.instance.dashboardRoute(appUser.role),
            (route) => false,
          );
        }
      } catch (e) {
        EasyLoading.dismiss();
        String errorMessage = "Gagal login. Periksa email/password.";
        if (e.toString().contains("Invalid login credentials")) {
          errorMessage = "Email atau password salah.";
        }

        EasyLoading.showError(errorMessage);
      }
    }
  }
}
