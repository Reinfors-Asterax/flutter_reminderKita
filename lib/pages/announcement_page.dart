import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';

import '../models/announcement.dart';
import '../models/class_model.dart';
import '../models/course.dart';
import '../models/user_role.dart';
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/class_service.dart';
import '../services/course_service.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final _service = AnnouncementService();
  final _classService = ClassService();
  final _courseService = CourseService();

  List<Announcement> _announcements = [];
  List<ClassModel> _classes = [];
  List<Course> _courses = [];
  Set<int> _leaderClassIds = {};
  bool _loading = true;

  bool get _canManage =>
      AuthService.instance.hasPermission(AppPermission.manageAnnouncements) ||
      _leaderClassIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final role = AuthService.instance.currentRole;
      final classFuture = role == UserRole.lecturer || role == UserRole.admin
          ? _classService.fetchRegisteredClasses()
          : _classService.fetchAccessibleClasses(role);
      final results = await Future.wait([
        _service.fetchVisible(),
        classFuture,
        _classService.fetchLedClassIds(),
        role == UserRole.lecturer
            ? _courseService.fetchOwnedByCurrentLecturer()
            : Future.value(<Course>[]),
      ]);
      if (!mounted) return;
      final classes = results[1] as List<ClassModel>;
      final classIds = classes.map((item) => item.id).toSet();
      final currentUserId = AuthService.instance.currentUser?.id;
      final visible = (results[0] as List<Announcement>).where((item) {
        final isOwner = item.createdBy == currentUserId;
        if (isOwner || role == UserRole.admin) return true;

        final roleMatches =
            item.targetRole == null ||
            item.targetRole == role ||
            (role == UserRole.classLeader &&
                item.targetRole == UserRole.student);
        final classMatches =
            item.targetClass == null || classIds.contains(item.targetClass);
        return roleMatches && classMatches;
      }).toList();
      setState(() {
        _announcements = visible;
        _classes = classes;
        _leaderClassIds = results[2] as Set<int>;
        _courses = results[3] as List<Course>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      EasyLoading.showError('Gagal memuat pengumuman: $error');
    }
  }

  Future<void> _showForm([Announcement? announcement]) async {
    final titleController = TextEditingController(text: announcement?.title);
    final contentController = TextEditingController(
      text: announcement?.content,
    );
    int? targetClass = announcement?.targetClass;
    UserRole? targetRole = announcement?.targetRole;
    int? courseId = announcement?.courseId;
    final role = AuthService.instance.currentRole;
    final isLecturer = role == UserRole.lecturer;
    final managesAsClassLeader =
        role != UserRole.lecturer && _leaderClassIds.isNotEmpty;
    final targetClasses = managesAsClassLeader
        ? _classes.where((item) => _leaderClassIds.contains(item.id)).toList()
        : _classes;

    if (managesAsClassLeader &&
        (targetClass == null || !_leaderClassIds.contains(targetClass))) {
      targetClass = targetClasses.isEmpty ? null : targetClasses.first.id;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                announcement == null ? 'Pengumuman Baru' : 'Edit Pengumuman',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Judul'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(labelText: 'Isi'),
                      ),
                      const SizedBox(height: 12),
                      if (isLecturer) ...[
                        DropdownButtonFormField<int>(
                          initialValue: courseId,
                          decoration: const InputDecoration(
                            labelText: 'Mata kuliah',
                          ),
                          items: _courses
                              .map(
                                (course) => DropdownMenuItem<int>(
                                  value: course.id,
                                  child: Text(course.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => courseId = value),
                        ),
                        if (_courses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Buat mata kuliah terlebih dahulu.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<int?>(
                        initialValue: targetClass,
                        decoration: const InputDecoration(
                          labelText: 'Target kelas',
                        ),
                        items: [
                          if (!managesAsClassLeader)
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Semua kelas'),
                            ),
                          ...targetClasses.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => targetClass = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UserRole?>(
                        initialValue: targetRole,
                        decoration: const InputDecoration(
                          labelText: 'Target role',
                        ),
                        items: [
                          const DropdownMenuItem<UserRole?>(
                            value: null,
                            child: Text('Semua role'),
                          ),
                          ...UserRole.values.map(
                            (item) => DropdownMenuItem<UserRole?>(
                              value: item,
                              child: Text(item.label),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => targetRole = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty ||
                        contentController.text.trim().isEmpty) {
                      EasyLoading.showError('Judul dan isi wajib diisi.');
                      return;
                    }
                    if (managesAsClassLeader && targetClass == null) {
                      EasyLoading.showError('Pilih target kelas.');
                      return;
                    }
                    if (isLecturer && courseId == null) {
                      EasyLoading.showError('Pilih mata kuliah.');
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      titleController.dispose();
      contentController.dispose();
      return;
    }

    try {
      EasyLoading.show(status: 'Menyimpan...');
      final value = Announcement(
        id: announcement?.id ?? 0,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        createdBy:
            announcement?.createdBy ?? AuthService.instance.currentUser!.id,
        createdAt: announcement?.createdAt ?? DateTime.now(),
        targetClass: targetClass,
        targetRole: targetRole,
        courseId: isLecturer ? courseId : null,
      );
      if (announcement == null) {
        await _service.create(value);
      } else {
        await _service.update(value);
      }
      await _load();
      EasyLoading.showSuccess('Pengumuman disimpan');
    } catch (error) {
      EasyLoading.showError('Gagal menyimpan: $error');
    } finally {
      titleController.dispose();
      contentController.dispose();
    }
  }

  Future<void> _delete(Announcement announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengumuman'),
        content: Text('Hapus "${announcement.title}"?'),
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
      await _service.delete(announcement.id);
      await _load();
    } catch (error) {
      EasyLoading.showError('Gagal menghapus: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _announcements.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Icon(Icons.campaign_outlined, size: 72),
                        SizedBox(height: 16),
                        Center(child: Text('Belum ada pengumuman')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _announcements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _announcements[index];
                        final targetClassName = item.targetClass == null
                            ? 'Semua kelas'
                            : _classes
                                  .where(
                                    (classItem) =>
                                        classItem.id == item.targetClass,
                                  )
                                  .map((classItem) => classItem.name)
                                  .firstOrNull;
                        final canChange =
                            _canManage &&
                            (AuthService.instance.currentRole ==
                                    UserRole.admin ||
                                item.createdBy ==
                                    AuthService.instance.currentUser?.id);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (canChange)
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showForm(item);
                                          } else {
                                            _delete(item);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(item.content),
                                const SizedBox(height: 14),
                                if (item.courseName != null) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.menu_book_outlined,
                                        size: 15,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.courseName!,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Row(
                                  children: [
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 15,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      targetClassName ??
                                          'Kelas tidak lagi tersedia',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.authorName ?? 'Pengguna'} - '
                                  '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(item.createdAt.toLocal())}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _showForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pengumuman'),
            )
          : null,
    );
  }
}
