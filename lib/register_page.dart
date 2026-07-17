import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_role.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _nimController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State visibility password
  bool _isPasswordVisible = false;

  // Warna Tema (Sesuaikan dengan brand aplikasi Anda)
  final Color _primaryColor = const Color(0xFF2563EB); // Modern Blue

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Section
                Text(
                  "Buat Akun Baru",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Lengkapi data diri Anda sebagai mahasiswa.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Form Section
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: "Nama Lengkap",
                        hint: "Contoh: Ananda Rizky Mahesli",
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _nimController,
                        label: "NIM",
                        hint: "Nomor Induk Mahasiswa",
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _emailController,
                        label: "Email",
                        hint: "nama@univ.ac.id",
                        icon: Icons.alternate_email_rounded,
                        inputType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Password Field Custom (dengan Show/Hide)
                      _buildPasswordField(),

                      const SizedBox(height: 32),

                      // 3. Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _handleRegister,
                          child: const Text(
                            "Daftar Sekarang",
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

                const SizedBox(height: 24),

                // 4. Footer Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Sudah punya akun? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context), // Kembali ke Login
                      child: Text(
                        "Masuk",
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS (Agar kode lebih rapi) ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
            filled: true,
            fillColor: const Color(0xFFF8FAFC), // Very light gray
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade200),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return '$label wajib diisi';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Password",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: "••••••••",
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: Colors.grey[500],
              size: 22,
            ),
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
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password wajib diisi';
            if (value.length < 6) return 'Minimal 6 karakter';
            return null;
          },
        ),
      ],
    );
  }

  // --- LOGIC ---

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      EasyLoading.show(status: 'Mendaftar...');
      try {
        final client = Supabase.instance.client;
        await client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'name': _nameController.text.trim(),
            'nim': _nimController.text.trim(),
            'role': UserRole.student.value,
          },
        );

        if (client.auth.currentSession != null) {
          await client.auth.signOut();
        }

        EasyLoading.showSuccess('Registrasi berhasil. Silakan login.');

        // Delay sedikit agar user sempat membaca pesan sukses
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pop(context); // Kembali ke halaman Login
        }
      } catch (e) {
        EasyLoading.dismiss();
        EasyLoading.showError('Gagal: ${e.toString()}');
      }
    }
  }
}
