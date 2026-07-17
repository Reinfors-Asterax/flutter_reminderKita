import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';

class SubjectManagementPage extends StatefulWidget {
  const SubjectManagementPage({super.key});

  @override
  State<SubjectManagementPage> createState() => _SubjectManagementPageState();
}

class _SubjectManagementPageState extends State<SubjectManagementPage> {
  List<Map<String, dynamic>> _subjects = [];
  bool _isLoading = true;

  bool get _isAdmin => AuthService.instance.currentRole == UserRole.admin;
  bool get _isLecturer => AuthService.instance.currentRole == UserRole.lecturer;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client.from('matakuliah').select();
      if (_isLecturer) {
        query = query.eq(
          'lecturer_id',
          Supabase.instance.client.auth.currentUser!.id,
        );
      }
      final rows = await query.order('nama');
      if (!mounted) return;
      setState(() {
        _subjects = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      EasyLoading.showError('Gagal memuat mata kuliah: $error');
    }
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Mata Kuliah'),
        content: Text(
          'Hapus "${subject['nama']}"? Jadwal terkait akan ikut dihapus. '
          'Reminder tetap tersimpan dengan nama mata kuliah yang sudah '
          'tercatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      EasyLoading.show(status: 'Menghapus...');
      await Supabase.instance.client
          .from('matakuliah')
          .delete()
          .eq('id', subject['id']);
      await _fetchSubjects();
      EasyLoading.showSuccess('Mata kuliah dihapus');
    } catch (error) {
      EasyLoading.showError('Gagal menghapus: $error');
    }
  }

  Future<void> _showCourseDialog([Map<String, dynamic>? subject]) async {
    if (!_isLecturer) return;

    final nameController = TextEditingController(text: subject?['nama']);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subject == null ? 'Mata Kuliah Baru' : 'Edit Mata Kuliah'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Mata Kuliah'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                EasyLoading.showError('Nama mata kuliah wajib diisi.');
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved != true) {
      nameController.dispose();
      return;
    }

    final user = AuthService.instance.currentUser!;
    final payload = {
      'kelas_id': null,
      'nama': nameController.text.trim(),
      'dosen': user.displayName,
      'lecturer_id': user.id,
    };

    try {
      EasyLoading.show(status: 'Menyimpan...');
      if (subject == null) {
        await Supabase.instance.client.from('matakuliah').insert(payload);
      } else {
        await Supabase.instance.client
            .from('matakuliah')
            .update({'nama': payload['nama']})
            .eq('id', subject['id']);
      }
      await _fetchSubjects();
      EasyLoading.showSuccess('Mata kuliah disimpan');
    } catch (error) {
      EasyLoading.showError('Gagal menyimpan: $error');
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Hapus Mata Kuliah' : 'Kelola Mata Kuliah'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSubjects,
              child: _subjects.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Icon(Icons.menu_book_outlined, size: 72),
                        SizedBox(height: 16),
                        Center(child: Text('Belum ada mata kuliah')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subjects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.menu_book_rounded),
                            ),
                            title: Text(
                              subject['nama']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text('Dosen: ${subject['dosen'] ?? '-'}'),
                            trailing: _isAdmin
                                ? IconButton(
                                    tooltip: 'Hapus',
                                    onPressed: () => _deleteSubject(subject),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _showCourseDialog(subject),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: _isLecturer
          ? FloatingActionButton.extended(
              onPressed: () => _showCourseDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Mata Kuliah'),
            )
          : null,
    );
  }
}
