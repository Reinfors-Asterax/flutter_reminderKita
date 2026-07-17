import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../models/reminder.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class ClassBoardPage extends StatefulWidget {
  const ClassBoardPage({super.key});

  @override
  State<ClassBoardPage> createState() => _ClassBoardPageState();
}

class _ClassBoardPageState extends State<ClassBoardPage> {
  final _currentUserEmail = Supabase.instance.client.auth.currentUser?.email;

  String _userRole = 'Mahasiswa';
  int _classId = 0;
  String _className = '';
  bool _isDataLoaded = false;

  List<Map<String, dynamic>> _tasks = [];
  bool _isLoadingTasks = true;

  // Modern Color Palette
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF1E293B);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;

  bool get _isLocalClassLeader => PermissionPolicy.isClassLeader(_userRole);

  bool get _isGlobalAdmin => AuthService.instance.currentRole == UserRole.admin;

  bool get _canManageReminders =>
      AuthService.instance.hasPermission(AppPermission.manageReminders) ||
      _isLocalClassLeader;

  bool get _canViewMembers =>
      AuthService.instance.hasPermission(AppPermission.viewMembers) ||
      _isLocalClassLeader;

  bool get _canEditMembers => _isGlobalAdmin || _isLocalClassLeader;

  bool get _canManageClass => _isLocalClassLeader;

  bool get _canDeleteClass => _isGlobalAdmin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _classId = args['id'];
        _className = args['nama'];
        if (args['role'] != null) {
          _userRole = args['role'].toString();
        }
      }

      _fetchTasks();
      _isDataLoaded = true;
    }
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() => _isLoadingTasks = true);

    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('kelas_id', _classId)
          .order('created_at', ascending: false);

      for (final item in response) {
        try {
          await NotificationService.scheduleReminder(
            Reminder.fromMap(Map<String, dynamic>.from(item)),
          );
        } catch (error) {
          debugPrint('Gagal sinkronisasi notifikasi reminder: $error');
        }
      }

      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(response);
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _deleteTask(int taskId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              "Hapus Pengingat",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text("Tindakan ini tidak dapat dibatalkan."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Batal",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      EasyLoading.show(maskType: EasyLoadingMaskType.black);
      await Supabase.instance.client.from('tasks').delete().match({
        'id': taskId,
      });
      await NotificationService.cancelTaskNotifications(taskId);
      EasyLoading.dismiss();

      _fetchTasks();
    }
  }

  // --- LOGIKA KELUAR KELAS ---
  Future<void> _handleExitClass() async {
    if (!_canDeleteClass) {
      bool confirm =
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text("Keluar Kelas?"),
              content: const Text(
                "Anda tidak akan bisa mengakses tugas dan materi lagi.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Batal"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    "Keluar",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;

      EasyLoading.show(status: 'Keluar...');
      try {
        await Supabase.instance.client.from('anggota_kelas').delete().match({
          'kelas_id': _classId,
          'user_email': _currentUserEmail!,
        });

        EasyLoading.showSuccess("Berhasil keluar!");
        if (mounted) {
          Navigator.popUntil(context, ModalRoute.withName('/home'));
        }
      } catch (e) {
        EasyLoading.showError("Gagal keluar: $e");
      }
      return;
    }

    // Admin is the only role allowed to delete a class.
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text("Hapus Kelas?"),
            content: const Text(
              "Kelas dan seluruh data di dalamnya akan dihapus permanen.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Batal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Hapus Permanen",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmDelete) {
      _deleteClassPermanently();
    }
  }

  Future<void> _deleteClassPermanently() async {
    try {
      await Supabase.instance.client.from('kelas').delete().eq('id', _classId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      EasyLoading.showError("Gagal: $e");
    }
  }

  // --- LOGIKA ANGGOTA ---
  Future<void> _kickMember(int memberId, String name) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text("Keluarkan $name?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Batal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text(
                  "Keluarkan",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      EasyLoading.show();
      await Supabase.instance.client
          .from('anggota_kelas')
          .delete()
          .eq('id', memberId);
      EasyLoading.dismiss();
      if (mounted) {
        Navigator.pop(context);
        _showMemberList();
      }
    }
  }

  Future<void> _regenerateCode(String column) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String newCode = String.fromCharCodes(
      Iterable.generate(
        5,
        (_) => chars.codeUnitAt(Random().nextInt(chars.length)),
      ),
    );

    await Supabase.instance.client
        .from('kelas')
        .update({column: newCode})
        .eq('id', _classId);
    setState(() {});
    if (mounted) {
      Navigator.pop(context);
      _showMemberList();
    }
  }

  // --- UI MODALS ---
  void _showTaskDetail(Map task) {
    String formattedDate = '-';
    if (task['waktu_reminder'] != null) {
      formattedDate = DateFormat(
        'EEEE, d MMMM yyyy • HH:mm',
        'id_ID',
      ).format(DateTime.parse(task['waktu_reminder']));
    }

    final canEditDelete = _canManageReminders;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.only(top: 8),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              task['mata_kuliah'] ?? 'Umum',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (canEditDelete)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await Navigator.pushNamed(
                                      context,
                                      '/task-form',
                                      arguments: {
                                        'classId': _classId,
                                        'taskData': task,
                                      },
                                    );
                                    _fetchTasks();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteTask(task['id']);
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        task['judul'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: _secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date Row
                      Row(
                        children: [
                          Icon(
                            Icons.event_note_rounded,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Image
                      if (task['gambar_url'] != null &&
                          task['gambar_url'] != '')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            task['gambar_url'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey[100],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        ),
                      if (task['gambar_url'] != null &&
                          task['gambar_url'] != '')
                        const SizedBox(height: 24),

                      // Description
                      const Text(
                        "Deskripsi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task['deskripsi'] ?? 'Tidak ada deskripsi tambahan.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Footer: Author
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: task['author_avatar_url'] != null
                                  ? NetworkImage(task['author_avatar_url'])
                                  : null, // Use network image if available
                              child: task['author_avatar_url'] == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['author_name'] ?? 'Pengguna',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _secondaryColor,
                                  ),
                                ),
                                const Text(
                                  "Memposting pengingat ini",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberList() {
    final isMainAdmin = _canManageClass;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    Text(
                      _isGlobalAdmin
                          ? "Administrasi Kelas"
                          : "Pengaturan Kelas",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _secondaryColor,
                      ),
                    ),
                    if (_isGlobalAdmin) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Mode Admin: lihat data kelas, kelola anggota, atau "
                        "hapus kelas. Reminder dan jadwal tetap dikelola "
                        "anggota kelas.",
                        style: TextStyle(color: Colors.grey[600], height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 20),

                    FutureBuilder(
                      future: Supabase.instance.client
                          .from('kelas')
                          .select()
                          .eq('id', _classId)
                          .single(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final kelasData = snapshot.data as Map;
                        final isOpen = kelasData['is_open'] ?? true;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Kode Akses",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (isMainAdmin)
                                    Switch.adaptive(
                                      value: isOpen,
                                      activeColor: _primaryColor,
                                      onChanged: (val) async {
                                        await Supabase.instance.client
                                            .from('kelas')
                                            .update({'is_open': val})
                                            .eq('id', _classId);
                                        setState(() {});
                                        if (mounted) {
                                          Navigator.pop(context);
                                          _showMemberList();
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const Divider(height: 24),
                              if (isOpen) ...[
                                _buildCodeRow(
                                  "Kode Mahasiswa",
                                  kelasData['kode_kelas'] ?? '-',
                                  isMainAdmin,
                                  'kode_kelas',
                                ),
                                const SizedBox(height: 16),
                                _buildCodeRow(
                                  "Kode Wakil",
                                  kelasData['kode_wakil'] ?? '-',
                                  isMainAdmin,
                                  'kode_wakil',
                                ),
                              ] else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_rounded,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Kelas dikunci",
                                        style: TextStyle(
                                          color: Colors.red[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    Text(
                      "Daftar Anggota",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // MEMBER LIST
                    FutureBuilder(
                      future: Supabase.instance.client
                          .from('anggota_kelas')
                          .select()
                          .eq('kelas_id', _classId)
                          .order('role'),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final members = snapshot.data as List;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: members.length,
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1, indent: 60),
                            itemBuilder: (context, index) {
                              final m = members[index];
                              bool isTargetAdmin =
                                  m['role'] == 'admin' ||
                                  m['role'] == 'Ketua Kelas';
                              bool isSelf =
                                  m['user_email'] == _currentUserEmail;
                              bool isVice = m['role'] == 'vice_admin';

                              final String? liveAvatar = Supabase
                                  .instance
                                  .client
                                  .auth
                                  .currentUser
                                  ?.userMetadata?['avatar_url'];
                              final String? avatarUrl = isSelf
                                  ? (liveAvatar ?? m['avatar_url'])
                                  : m['avatar_url'];

                              // Pastikan string tidak kosong
                              final bool hasImage =
                                  avatarUrl != null &&
                                  avatarUrl.toString().isNotEmpty;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isTargetAdmin
                                      ? Colors.orange[100]
                                      : (isVice
                                            ? Colors.purple[100]
                                            : Colors.blue[100]),
                                  backgroundImage: hasImage
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: !hasImage
                                      ? Text(
                                          (m['user_name']?[0] ?? 'U')
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isTargetAdmin
                                                ? Colors.orange[800]
                                                : (isVice
                                                      ? Colors.purple[800]
                                                      : Colors.blue[800]),
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  m['user_name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  isTargetAdmin
                                      ? 'Ketua Kelas • ${m['nim'] ?? "-"}'
                                      : (isVice
                                            ? 'Wakil Ketua • ${m['nim'] ?? "-"}'
                                            : m['nim'] ?? '-'),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                                trailing:
                                    (_canEditMembers &&
                                        !isTargetAdmin &&
                                        !isSelf)
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red[300],
                                        ),
                                        onPressed: () => _kickMember(
                                          m['id'],
                                          m['user_name'] ?? 'User',
                                        ),
                                      )
                                    : (isTargetAdmin
                                          ? const Icon(
                                              Icons.shield_rounded,
                                              color: Colors.orange,
                                              size: 18,
                                            )
                                          : null),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleExitClass();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _canDeleteClass
                              ? "Hapus Kelas Permanen"
                              : "Keluar dari Kelas",
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeRow(
    String label,
    String code,
    bool canEdit,
    String dbColumn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _secondaryColor,
                    letterSpacing: 2,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  EasyLoading.showToast("Disalin");
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.copy_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _regenerateCode(dbColumn),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _className,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _secondaryColor,
              ),
            ),
            if (_isGlobalAdmin)
              const Text(
                "MODE ADMIN - BACA & HAPUS",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _secondaryColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
        actions: [
          IconButton(
            tooltip: "Pengumuman",
            icon: const Icon(Icons.campaign_outlined, color: Colors.black87),
            onPressed: () => Navigator.pushNamed(context, '/announcements'),
          ),
          IconButton(
            tooltip: "Jadwal",
            icon: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pushNamed(
              context,
              '/schedule',
              arguments: {'classId': _classId, 'role': _userRole},
            ),
          ),
          if (_canViewMembers || _canDeleteClass)
            IconButton(
              tooltip: "Pengaturan dan Anggota",
              icon: const Icon(Icons.group_outlined, color: Colors.black87),
              onPressed: _showMemberList,
            ),
          if (_canDeleteClass)
            IconButton(
              tooltip: "Hapus Kelas",
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _handleExitClass,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingTasks
          ? const Center(child: CircularProgressIndicator())
          : (_tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.task_alt_rounded,
                            size: 64,
                            color: _primaryColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Tidak ada tugas",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Istirahatlah dengan tenang!",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchTasks,
                    color: _primaryColor,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        top: 24,
                        left: 20,
                        right: 20,
                        bottom: 100 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) =>
                          _buildTaskCard(_tasks[index]),
                    ),
                  )),
      floatingActionButton: _canManageReminders
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  '/task-form',
                  arguments: {'classId': _classId},
                );
                _fetchTasks();
              },
              backgroundColor: _secondaryColor,
              elevation: 4,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                "Reminder Baru",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTaskCard(Map task) {
    bool isOverdue = false;
    String reminderText = '-';
    Color timeColor = Colors.grey;
    final priority = ReminderPriority.fromValue(task['priority']);
    final status = ReminderStatus.fromValue(task['status']);
    final priorityColor = switch (priority) {
      ReminderPriority.low => Colors.green,
      ReminderPriority.medium => Colors.blue,
      ReminderPriority.high => Colors.orange,
      ReminderPriority.urgent => Colors.red,
    };

    if (task['waktu_reminder'] != null) {
      final date = DateTime.parse(task['waktu_reminder']);
      reminderText = DateFormat('EEE, d MMM • HH:mm', 'id_ID').format(date);

      final now = DateTime.now();

      if (date.isBefore(now)) {
        timeColor = Colors.red[700]!;
        reminderText = "Terlewat • $reminderText";
        isOverdue = true;
      } else if (date.difference(now).inDays < 2) {
        timeColor = Colors.orange[800]!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showTaskDetail(task),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task['gambar_url'] != null && task['gambar_url'] != '')
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Image.network(
                        task['gambar_url'],
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(height: 0),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (task['mata_kuliah'] ?? 'Umum').toUpperCase(),
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                priority.label.toUpperCase(),
                                style: TextStyle(
                                  color: priorityColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (status == ReminderStatus.completed) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 20,
                              ),
                            ] else if (isOverdue) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red[300],
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      task['judul'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: _secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: timeColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reminderText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: timeColor,
                            ),
                          ),
                        ),
                        // Avatar mini
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            backgroundImage: task['author_avatar_url'] != null
                                ? NetworkImage(task['author_avatar_url'])
                                : null,
                            child: task['author_avatar_url'] == null
                                ? const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey,
                                  )
                                : null,
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
      ),
    );
  }
}
