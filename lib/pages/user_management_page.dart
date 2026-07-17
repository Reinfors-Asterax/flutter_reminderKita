import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _searchController = TextEditingController();
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('display_name');
      if (!mounted) return;
      setState(() {
        _users = (rows as List)
            .map((item) => AppUser.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      EasyLoading.showError('Gagal memuat user: $error');
    }
  }

  Future<void> _changeRole(AppUser user, UserRole role) async {
    if (user.id == AuthService.instance.currentUser?.id &&
        role != UserRole.admin) {
      EasyLoading.showError('Admin tidak dapat menurunkan role akun sendiri.');
      return;
    }
    try {
      EasyLoading.show(status: 'Menyimpan role...');
      await AuthService.instance.updateUserRole(user.id, role);
      await _loadUsers();
      EasyLoading.showSuccess(
        user.approvalStatus == AccountApprovalStatus.pending
            ? 'Permintaan role disetujui'
            : 'Role diperbarui',
      );
    } catch (error) {
      EasyLoading.showError('Gagal memperbarui role: $error');
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.id == AuthService.instance.currentUser?.id) {
      EasyLoading.showError('Admin tidak dapat menghapus akun sendiri.');
      return;
    }
    if (user.role == UserRole.admin) {
      EasyLoading.showError('Akun Admin tidak dapat dihapus dari aplikasi.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text(
          'Hapus akun ${user.displayName} (${user.role.label}) secara permanen?',
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
      EasyLoading.show(status: 'Menghapus akun...');
      await AuthService.instance.deleteUserAccount(user.id);
      await _loadUsers();
      EasyLoading.showSuccess('Akun dihapus');
    } catch (error) {
      EasyLoading.showError('Gagal menghapus akun: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final visible = _users.where((user) {
      return user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola User')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Cari nama atau email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = visible[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                user.displayName.isEmpty
                                    ? '?'
                                    : user.displayName[0].toUpperCase(),
                              ),
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(user.email),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<UserRole>(
                                  value: user.role,
                                  underline: const SizedBox(),
                                  items: UserRole.values
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (role) {
                                    if (role != null && role != user.role) {
                                      _changeRole(user, role);
                                    }
                                  },
                                ),
                                if (user.role != UserRole.admin)
                                  IconButton(
                                    tooltip: 'Hapus akun',
                                    onPressed: () => _deleteUser(user),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
