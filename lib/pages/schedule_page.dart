import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import library Cupertino
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../models/user_role.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  int _classId = 0;
  String _classRole = UserRole.student.value;

  List<Map<String, dynamic>> _subjectsList = [];
  Map<int, Map<String, dynamic>> _tasksCache = {};

  bool _isDataLoaded = false;

  // Modern Color Palette
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF1E293B);
  final Color _bgColor = const Color(0xFFF8FAFC);

  bool get _canManageSchedule => PermissionPolicy.isClassLeader(_classRole);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);

    final weekday = DateTime.now().weekday;
    if (weekday <= 6) {
      _tabController.index = weekday - 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _classId = args['classId'];
      _classRole = args['role']?.toString() ?? UserRole.student.value;

      _preloadData();
      _isDataLoaded = true;
    }
  }

  Future<void> _preloadData() async {
    try {
      final subjectsData = await Supabase.instance.client
          .from('matakuliah')
          .select()
          .order('nama', ascending: true);

      final now = DateTime.now().toIso8601String();
      final tasksData = await Supabase.instance.client
          .from('tasks')
          .select('id, judul, waktu_reminder, matakuliah_id')
          .eq('kelas_id', _classId)
          .gt('waktu_reminder', now)
          .order('waktu_reminder', ascending: true);

      Map<int, Map<String, dynamic>> tempTaskCache = {};
      for (var t in tasksData) {
        int mkId = t['matakuliah_id'] ?? 0;
        if (!tempTaskCache.containsKey(mkId)) {
          tempTaskCache[mkId] = t;
        }
      }

      if (mounted) {
        setState(() {
          _subjectsList = List<Map<String, dynamic>>.from(subjectsData);
          _tasksCache = tempTaskCache;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _scheduleStream(String day) {
    return Supabase.instance.client
        .from('jadwal_kelas')
        .stream(primaryKey: ['id'])
        .eq('kelas_id', _classId)
        .map((list) {
          final filtered = list.where((item) => item['hari'] == day).toList();
          filtered.sort(
            (a, b) =>
                (a['jam_mulai'] as String).compareTo(b['jam_mulai'] as String),
          );

          return filtered.map((item) {
            final newItem = Map<String, dynamic>.from(item);
            final subject = _subjectsList.firstWhere(
              (s) => s['id'] == item['matakuliah_id'],
              orElse: () => {'nama': 'Matkul Dihapus', 'dosen': '-'},
            );

            newItem['matkul_nama'] = subject['nama'];
            newItem['dosen'] = subject['dosen'];

            if (_tasksCache.containsKey(item['matakuliah_id'])) {
              final task = _tasksCache[item['matakuliah_id']];
              newItem['task_title'] = task!['judul'];
              newItem['task_deadline'] = task['waktu_reminder'];
            }
            return newItem;
          }).toList();
        });
  }

  String _formatDeadlineWithLabel(String deadline) {
    final dt = DateTime.parse(deadline);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);
    final time = DateFormat('HH:mm').format(dt);

    if (target == today) return "Hari ini, $time";
    if (target == tomorrow) return "Besok, $time";

    final date = DateFormat('d MMM', 'id_ID').format(dt);
    return "$date • $time";
  }

  Color _deadlineColor(String deadline) {
    final dt = DateTime.parse(deadline);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return Colors.red[700]!;
    if (target == tomorrow) return Colors.orange[800]!;
    return _secondaryColor;
  }

  Future<void> _deleteSchedule(int id) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Hapus Jadwal?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Batal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      await Supabase.instance.client.from('jadwal_kelas').delete().match({
        'id': id,
      });
    }
  }

  // --- FUNGSI PICKER CUPERTINO ---
  Future<void> _pickCupertinoTime({
    required BuildContext context,
    required TimeOfDay initialTime,
    required Function(TimeOfDay) onTimePicked,
  }) async {
    final now = DateTime.now();
    DateTime tempDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    await showModalBottomSheet(
      context: context,
      enableDrag: false, // Mencegah modal tertutup saat scroll jam
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Batal",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const Text(
                      "Pilih Jam",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onTimePicked(
                          TimeOfDay(
                            hour: tempDateTime.hour,
                            minute: tempDateTime.minute,
                          ),
                        );
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Selesai",
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: tempDateTime,
                  onDateTimeChanged: (DateTime newDate) =>
                      tempDateTime = newDate,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showScheduleForm({Map<String, dynamic>? data}) async {
    final isEdit = data != null;
    int? selectedSubjectId = isEdit ? data['matakuliah_id'] : null;
    String selectedDay = isEdit ? data['hari'] : _days[_tabController.index];

    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    TimeOfDay startTime = isEdit
        ? parseTime(data['jam_mulai'].toString())
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = isEdit
        ? parseTime(data['jam_selesai'].toString())
        : const TimeOfDay(hour: 10, minute: 0);
    final roomController = TextEditingController(
      text: isEdit ? data['ruangan'] : '',
    );
    var isSubmitting = false;
    String? validationMessage;

    int minutesOfDay(TimeOfDay time) => (time.hour * 60) + time.minute;

    TimeOfDay suggestedEndTime(TimeOfDay start) {
      final suggestedMinutes = minutesOfDay(start) + 60;
      if (suggestedMinutes >= 24 * 60) {
        return const TimeOfDay(hour: 23, minute: 59);
      }
      return TimeOfDay(
        hour: suggestedMinutes ~/ 60,
        minute: suggestedMinutes % 60,
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isEdit ? "Edit Jadwal" : "Tambah Jadwal",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _secondaryColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Hari',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _days
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedDay = val!),
                  ),
                  const SizedBox(height: 16),
                  if (_subjectsList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Belum ada mata kuliah. Hubungi Dosen untuk menambah katalog.",
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      value: selectedSubjectId,
                      decoration: InputDecoration(
                        labelText: 'Mata Kuliah',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _subjectsList
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text(
                                s['nama'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedSubjectId = v),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickCupertinoTime(
                            context: context,
                            initialTime: startTime,
                            onTimePicked: (time) {
                              setDialogState(() {
                                startTime = time;
                                if (minutesOfDay(endTime) <=
                                    minutesOfDay(startTime)) {
                                  endTime = suggestedEndTime(startTime);
                                }
                                validationMessage = null;
                              });
                            },
                          ),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Mulai',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              startTime.format(context),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickCupertinoTime(
                            context: context,
                            initialTime: endTime,
                            onTimePicked: (time) {
                              setDialogState(() {
                                endTime = time;
                                validationMessage = null;
                              });
                            },
                          ),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Selesai',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              endTime.format(context),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roomController,
                    decoration: InputDecoration(
                      labelText: 'Ruangan',
                      hintText: 'Contoh: R. 304',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (validationMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text(
                  "Batal",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final room = roomController.text.trim();
                        if (selectedSubjectId == null || room.isEmpty) {
                          setDialogState(
                            () => validationMessage =
                                'Mata kuliah dan ruangan wajib diisi.',
                          );
                          return;
                        }
                        if (minutesOfDay(endTime) <= minutesOfDay(startTime)) {
                          setDialogState(
                            () => validationMessage =
                                'Jam selesai harus setelah jam mulai.',
                          );
                          return;
                        }

                        setDialogState(() {
                          validationMessage = null;
                          isSubmitting = true;
                        });
                        try {
                          final startStr =
                              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                          final endStr =
                              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
                          final payload = {
                            'kelas_id': _classId,
                            'matakuliah_id': selectedSubjectId,
                            'hari': selectedDay,
                            'jam_mulai': startStr,
                            'jam_selesai': endStr,
                            'ruangan': room,
                          };

                          if (isEdit) {
                            await Supabase.instance.client
                                .from('jadwal_kelas')
                                .update(payload)
                                .eq('id', data['id']);
                          } else {
                            await Supabase.instance.client
                                .from('jadwal_kelas')
                                .insert(payload);
                          }
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (error) {
                          if (!context.mounted) return;
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error.toString().contains(
                                      'schedule_exact_duplicate_idx',
                                    )
                                    ? 'Jadwal yang sama sudah tersimpan.'
                                    : error.toString().contains(
                                        'jadwal_kelas_check',
                                      )
                                    ? 'Jam selesai harus setelah jam mulai.'
                                    : 'Gagal menyimpan jadwal: $error',
                              ),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? "Simpan" : "Tambah"),
              ),
            ],
          );
        },
      ),
    );
    roomController.dispose();
    if (saved == true) {
      await _preloadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "Jadwal Kuliah",
          style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _secondaryColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _primaryColor,
              unselectedLabelColor: Colors.grey[400],
              indicatorColor: _primaryColor,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              tabs: _days.map((d) => Tab(text: d)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _scheduleStream(day),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _subjectsList.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(day);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  final jamMulai = item['jam_mulai'].toString().substring(0, 5);
                  final jamSelesai = item['jam_selesai'].toString().substring(
                    0,
                    5,
                  );

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Text(
                              jamMulai,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: _secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              jamSelesai,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.2),
                                border: Border.all(
                                  color: _primaryColor,
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.grey[200],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF64748B,
                                  ).withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['matkul_nama'] ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: _secondaryColor,
                                            ),
                                          ),
                                        ),
                                        if (_canManageSchedule)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showScheduleForm(
                                                  data: item,
                                                ),
                                                child: Icon(
                                                  Icons.edit_rounded,
                                                  size: 18,
                                                  color: Colors.grey[400],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () =>
                                                    _deleteSchedule(item['id']),
                                                child: Icon(
                                                  Icons.delete_rounded,
                                                  size: 18,
                                                  color: Colors.red[300],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      Icons.person_outline_rounded,
                                      item['dosen'] ?? '-',
                                    ),
                                    const SizedBox(height: 6),
                                    _buildInfoRow(
                                      Icons.location_on_outlined,
                                      item['ruangan'] ?? '-',
                                    ),
                                    if (item['task_title'] != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange[100]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_filled,
                                              color: Colors.orange[700],
                                              size: 16,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "DEADLINE TUGAS",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.orange[800],
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${item['task_title']}",
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _secondaryColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDeadlineWithLabel(
                                                      item['task_deadline'],
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: _deadlineColor(
                                                        item['task_deadline'],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: _canManageSchedule
          ? FloatingActionButton(
              onPressed: () => _showScheduleForm(),
              backgroundColor: _secondaryColor,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String day) {
    return Center(
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
              Icons.event_busy_rounded,
              size: 48,
              color: _primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Tidak ada kelas hari $day",
            style: TextStyle(
              color: _secondaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Nikmati waktu luangmu!",
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
