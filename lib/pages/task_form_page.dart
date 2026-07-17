import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';

import '../models/reminder.dart';
import '../services/notification_service.dart';

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  String _uploadedImageUrl = '';
  final ImagePicker _picker = ImagePicker();

  DateTime? _selectedDate;
  int? _classId;
  int? _taskId;

  List<Map<String, dynamic>> _subjectsList = [];
  int? _selectedSubjectId;
  String _selectedSubjectName = '';
  String _selectedLecturerName = '';
  ReminderPriority _priority = ReminderPriority.medium;
  ReminderStatus _status = ReminderStatus.pending;

  bool _isDataLoaded = false;

  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF1E293B);
  final Color _bgColor = const Color(0xFFF8FAFC);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null) {
        _classId = args['classId'] ?? args['id'];

        _fetchSubjects();

        if (args.containsKey('taskData')) {
          final data = args['taskData'];
          _taskId = data['id'];
          _judulController.text = data['judul'] ?? '';
          _deskripsiController.text = data['deskripsi'] ?? '';
          _uploadedImageUrl = data['gambar_url'] ?? '';
          _selectedSubjectName = data['mata_kuliah'] ?? '';
          _selectedLecturerName = data['dosen_pengampu'] ?? '';
          _priority = ReminderPriority.fromValue(data['priority']);
          _status = ReminderStatus.fromValue(data['status']);

          if (data['matakuliah_id'] != null) {
            _selectedSubjectId = data['matakuliah_id'];
          }
          if (data['waktu_reminder'] != null) {
            _selectedDate = DateTime.parse(data['waktu_reminder']);
          }
        }
      }
      _isDataLoaded = true;
    }
  }

  // --- 1. FETCH DATA ---

  Future<void> _fetchSubjects() async {
    if (_classId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('matakuliah')
          .select()
          .order('nama', ascending: true);
      if (mounted) {
        setState(() => _subjectsList = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint("Error fetch subjects: $e");
    }
  }

  // --- 2. IMAGE UPLOAD ---

  Future<void> _pickTaskImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (image == null) return;

      EasyLoading.show(status: 'Mengupload...');

      final fileName =
          'tasks/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await Supabase.instance.client.storage
          .from('files')
          .uploadBinary(
            fileName,
            await File(image.path).readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('files')
          .getPublicUrl(fileName);

      setState(() {
        _uploadedImageUrl = imageUrl;
      });
      EasyLoading.showSuccess('Gambar terupload!');
    } catch (e) {
      EasyLoading.showError('Upload gagal: $e');
    } finally {
      EasyLoading.dismiss();
    }
  }

  // --- 3. DATE & TIME ---

  Future<void> _pickDate() async {
    final now = DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 450, // Sesuaikan tinggi kalender
          child: Column(
            children: [
              // Handle bar kecil di atas
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                "Pilih Tanggal Tenggat",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _secondaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: _primaryColor, // Warna lingkaran tgl terpilih
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate:
                        (_selectedDate != null && _selectedDate!.isAfter(now))
                        ? _selectedDate!
                        : now,
                    firstDate: now,
                    lastDate: DateTime(2030),
                    onDateChanged: (DateTime date) {
                      setState(() {
                        final currentHour = _selectedDate?.hour ?? 9;
                        final currentMinute = _selectedDate?.minute ?? 0;
                        _selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          currentHour,
                          currentMinute,
                        );
                      });
                      Navigator.pop(context); // Tutup setelah pilih
                      _pickTime();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    // Variable sementara agar state tidak langsung berubah sebelum klik 'Simpan'
    DateTime tempDateTime = _selectedDate ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // Agar kita bisa buat floating effect
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(
            16,
          ), // Memberikan jarak agar terlihat melayang
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header & Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Pilih Jam Pengingat",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _secondaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Pastikan waktu tidak lewat dari jam sekarang",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),

              // 2. The Picker (Kita bungkus agar lebih rapi)
              SizedBox(
                height: 200,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _secondaryColor,
                        fontFamily:
                            'sans-serif', // Gunakan font sistem yang bersih
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: tempDateTime,
                    onDateTimeChanged: (DateTime newTime) {
                      tempDateTime = DateTime(
                        _selectedDate?.year ?? now.year,
                        _selectedDate?.month ?? now.month,
                        _selectedDate?.day ?? now.day,
                        newTime.hour,
                        newTime.minute,
                      );
                    },
                  ),
                ),
              ),

              // 3. Action Buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Batal",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () {
                          // Validasi saat klik Simpan
                          if (tempDateTime.isBefore(DateTime.now())) {
                            EasyLoading.showError("Waktu sudah terlewat!");
                            return;
                          }

                          setState(() => _selectedDate = tempDateTime);
                          HapticFeedback.mediumImpact(); // Getaran mantap saat simpan
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Simpan",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 4. NOTIFICATION ---

  Future<void> _scheduleNotification(
    int taskId,
    String taskTitle,
    DateTime dueDate,
    String subjectName,
    String lecturerName,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await NotificationService.scheduleReminder(
        Reminder(
          id: taskId,
          title: taskTitle,
          description: _deskripsiController.text.trim(),
          createdBy: user.id,
          targetClass: _classId!,
          dueDate: dueDate,
          priority: _priority,
          status: _status,
          courseId: _selectedSubjectId,
          courseName: subjectName,
          lecturerName: lecturerName,
        ),
      );
    } catch (e) {
      debugPrint('Error schedule notif: $e');
    }
  }

  // --- 5. SAVE TASK ---

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSubjectName.isEmpty) {
        EasyLoading.showInfo("Pilih Mata Kuliah dulu!");
        return;
      }
      if (_selectedDate == null) {
        EasyLoading.showError("Waktu Reminder wajib diisi!");
        return;
      }

      EasyLoading.show(status: 'Menyimpan...');
      final user = Supabase.instance.client.auth.currentUser;
      final data = {
        'kelas_id': _classId,
        'judul': _judulController.text,
        'deskripsi': _deskripsiController.text,
        'matakuliah_id': _selectedSubjectId,
        'mata_kuliah': _selectedSubjectName,
        'dosen_pengampu': _selectedLecturerName,
        'gambar_url': _uploadedImageUrl,
        'waktu_reminder': _selectedDate?.toIso8601String(),
        'created_by': user!.id,
        'priority': _priority.name,
        'status': _status.name,
        'author_email': user.email,
        'author_name': user.userMetadata?['name'] ?? 'Mahasiswa',
        'author_nim': user.userMetadata?['nim'] ?? '-',
        'author_avatar_url': user.userMetadata?['avatar_url'],
      };

      try {
        if (_taskId == null) {
          final res = await Supabase.instance.client
              .from('tasks')
              .insert(data)
              .select('id')
              .single();

          await _scheduleNotification(
            res['id'],
            _judulController.text,
            _selectedDate!,
            _selectedSubjectName,
            _selectedLecturerName,
          );
        } else {
          data.remove('author_email');
          data.remove('author_name');
          data.remove('author_nim');
          data.remove('created_by');
          await Supabase.instance.client.from('tasks').update(data).match({
            'id': _taskId!,
          });

          await _scheduleNotification(
            _taskId!,
            _judulController.text,
            _selectedDate!,
            _selectedSubjectName,
            _selectedLecturerName,
          );
        }
        EasyLoading.showSuccess('Berhasil!');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        EasyLoading.showError('Gagal: $e');
      }
    }
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _taskId == null ? "Buat Reminder" : "Edit Reminder",
          style: TextStyle(
            color: _secondaryColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _secondaryColor),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SUBJECT CARD
              _buildSectionHeader("MATA KULIAH"),
              Container(
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.class_rounded,
                            color: _primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value:
                                  _subjectsList.any(
                                    (e) => e['id'] == _selectedSubjectId,
                                  )
                                  ? _selectedSubjectId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Mata Kuliah',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _secondaryColor,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              items: _subjectsList
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s['id'] as int,
                                      child: Text(s['nama']),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedSubjectId = v;
                                  final s = _subjectsList.firstWhere(
                                    (e) => e['id'] == v,
                                  );
                                  _selectedSubjectName = s['nama'];
                                  _selectedLecturerName = s['dosen'] ?? '';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedLecturerName.isNotEmpty) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Dosen: $_selectedLecturerName",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 2. TITLE INPUT
              TextFormField(
                controller: _judulController,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: _secondaryColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Judul Tugas...',
                  hintStyle: TextStyle(color: Colors.grey[300]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) => v!.isEmpty ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // 3. DESCRIPTION INPUT
              TextFormField(
                controller: _deskripsiController,
                maxLines: 6,
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Tambahkan detail tugas, catatan, atau link...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),

              const SizedBox(height: 32),

              // 4. DATE & TIME PICKERS
              _buildSectionHeader("DEADLINE"),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildPickerCard(
                      icon: Icons.calendar_month_rounded,
                      label: "Tanggal",
                      value: _selectedDate == null
                          ? "Pilih Tgl"
                          : DateFormat(
                              'd MMM yyyy',
                              'id_ID',
                            ).format(_selectedDate!),
                      onTap: _pickDate,
                      isSet: _selectedDate != null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildPickerCard(
                      icon: Icons.access_time_filled_rounded,
                      label: "Jam",
                      value: _selectedDate == null
                          ? "--:--"
                          : DateFormat('HH:mm').format(_selectedDate!),
                      onTap: _pickTime,
                      isSet: _selectedDate != null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              _buildSectionHeader("AKSES & STATUS"),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ReminderPriority>(
                      value: _priority,
                      decoration: const InputDecoration(labelText: 'Prioritas'),
                      items: ReminderPriority.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ReminderStatus>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ReminderStatus.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 5. IMAGE ATTACHMENT
              _buildSectionHeader("LAMPIRAN"),
              InkWell(
                onTap: _pickTaskImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                    ),
                    image: _uploadedImageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_uploadedImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _uploadedImageUrl.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 28,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Upload Foto Soal / Materi",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 16,
                              child: Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 18,
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _uploadedImageUrl = ''),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),

              // 6. SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shadowColor: _primaryColor.withOpacity(0.4),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saveTask,
                  child: const Text(
                    "Simpan Pengingat",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isSet,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSet ? _primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSet ? _primaryColor : Colors.grey.shade200,
          width: isSet ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isSet)
            BoxShadow(
              color: _primaryColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 1. Berikan efek getar saat ditekan
            HapticFeedback.lightImpact();
            // 2. Jalankan fungsi picker (PENTING: baris ini yang membuat dialog muncul)
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSet
                            ? _primaryColor.withOpacity(0.1)
                            : _bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 14,
                        color: isSet ? _primaryColor : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: isSet ? _primaryColor : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSet ? _secondaryColor : Colors.grey[400],
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
