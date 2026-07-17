import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../models/lecturer_account_request.dart';
import '../services/admin_user_service.dart';

class CreateLecturerPage extends StatefulWidget {
  const CreateLecturerPage({super.key});

  @override
  State<CreateLecturerPage> createState() => _CreateLecturerPageState();
}

class _CreateLecturerPageState extends State<CreateLecturerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lecturerNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _service = AdminUserService();

  bool _passwordVisible = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _lecturerNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    EasyLoading.show(status: 'Membuat akun dosen...');
    try {
      final result = await _service.createLecturer(
        LecturerAccountRequest(
          name: _nameController.text,
          lecturerNumber: _lecturerNumberController.text,
          email: _emailController.text,
          password: _passwordController.text,
        ),
      );
      EasyLoading.showSuccess(
        result.emailConfirmationRequired
            ? 'Akun dibuat. Dosen perlu mengonfirmasi email sebelum login.'
            : 'Akun dosen berhasil dibuat.',
      );
      if (mounted) Navigator.pop(context, true);
    } on AdminUserException catch (error) {
      EasyLoading.showError(error.message);
    } catch (error) {
      EasyLoading.showError('Gagal membuat akun dosen: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Buat Akun Dosen')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Dosen',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Akun langsung aktif dan dapat digunakan untuk login.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        _field(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _lecturerNumberController,
                          label: 'NIDN / ID Dosen',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Email wajib diisi';
                            if (!email.contains('@')) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _passwordField(
                          controller: _passwordController,
                          label: 'Password Sementara',
                        ),
                        const SizedBox(height: 16),
                        _passwordField(
                          controller: _confirmPasswordController,
                          label: 'Konfirmasi Password',
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Konfirmasi password tidak sama';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                              _submitting ? 'Memproses...' : 'Buat Akun Dosen',
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
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label wajib diisi';
            }
            return null;
          },
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !_passwordVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _passwordVisible = !_passwordVisible);
          },
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
          ),
        ),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return '$label wajib diisi';
            }
            if (value.length < 8) {
              return 'Password minimal 8 karakter';
            }
            return null;
          },
    );
  }
}
