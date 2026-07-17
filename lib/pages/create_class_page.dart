import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../models/user_role.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  // Design Colors
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF1E293B);
  final Color _bgColor = const Color(0xFFF8FAFC);

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  @override
  void initState() {
    super.initState();
    _codeController.text = _generateRandomCode();
  }

  Future<void> _createClass() async {
    if (_nameController.text.trim().isEmpty) {
      EasyLoading.showError("Nama kelas wajib diisi");
      return;
    }

    EasyLoading.show(status: 'Membuat ruang kelas...');
    final user = Supabase.instance.client.auth.currentUser;

    final userName = user!.userMetadata?['name'] ?? 'Mahasiswa';
    final userNim = user.userMetadata?['nim'] ?? '-';

    try {
      final classData = await Supabase.instance.client
          .from('kelas')
          .insert({
            'nama_kelas': _nameController.text.trim(),
            'kode_kelas': _codeController.text,
            'kode_wakil': 'W-${_generateRandomCode()}',
            'created_by': user.id,
            'is_open': true,
          })
          .select()
          .single();

      await Supabase.instance.client.from('anggota_kelas').insert({
        'kelas_id': classData['id'],
        'user_email': user.email,
        'role': UserRole.classLeader.value,
        'user_name': userName,
        'nim': userNim,
      });

      EasyLoading.showSuccess('Kelas Berhasil Dibuat!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      EasyLoading.showError('Gagal membuat kelas: $e');
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _codeController.text));
    EasyLoading.showToast(
      "Kode disalin!",
      toastPosition: EasyLoadingToastPosition.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "Buat Kelas Baru",
          style: TextStyle(
            color: _secondaryColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: _bgColor,
        surfaceTintColor: _bgColor,
        iconTheme: IconThemeData(color: _secondaryColor),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.domain_add_rounded,
                  size: 36,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 2. Class Name Input
            Text(
              "Nama Kelas",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _nameController,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: _secondaryColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Misal: Pemrograman Mobile A',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.class_outlined,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 3. Code Generation Section (Ticket Style)
            Text(
              "Kode Unik Kelas",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _copyToClipboard,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative Circle 1
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Decorative Circle 2
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "STUDENT CODE",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.copy_rounded,
                                color: Colors.white.withOpacity(0.5),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _codeController.text,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 6,
                              fontFamily: 'Courier', // Monospaced feel
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            width: double.infinity,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => setState(
                              () =>
                                  _codeController.text = _generateRandomCode(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Acak Ulang Kode",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                "Ketuk kartu di atas untuk menyalin kode.",
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),

            // Spacer to push button to bottom if screen is tall,
            // or just spacing if scrolling
            const SizedBox(height: 48),

            // 4. Action Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _createClass,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondaryColor,
                  elevation: 0,
                  shadowColor: _secondaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Buat Kelas Sekarang",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
