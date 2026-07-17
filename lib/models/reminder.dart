import 'user_role.dart';

enum ReminderPriority {
  low,
  medium,
  high,
  urgent;

  String get label => switch (this) {
    ReminderPriority.low => 'Rendah',
    ReminderPriority.medium => 'Sedang',
    ReminderPriority.high => 'Tinggi',
    ReminderPriority.urgent => 'Mendesak',
  };

  static ReminderPriority fromValue(Object? value) {
    return ReminderPriority.values.firstWhere(
      (priority) => priority.name == value?.toString().toLowerCase(),
      orElse: () => ReminderPriority.medium,
    );
  }
}

enum ReminderStatus {
  pending,
  completed,
  expired;

  String get label => switch (this) {
    ReminderStatus.pending => 'Menunggu',
    ReminderStatus.completed => 'Selesai',
    ReminderStatus.expired => 'Kedaluwarsa',
  };

  static ReminderStatus fromValue(Object? value) {
    return ReminderStatus.values.firstWhere(
      (status) => status.name == value?.toString().toLowerCase(),
      orElse: () => ReminderStatus.pending,
    );
  }
}

class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.targetClass,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.targetRole,
    this.courseId,
    this.courseName,
    this.lecturerName,
  });

  final int id;
  final String title;
  final String description;
  final String createdBy;
  final int targetClass;
  final UserRole? targetRole;
  final DateTime dueDate;
  final ReminderPriority priority;
  final ReminderStatus status;
  final int? courseId;
  final String? courseName;
  final String? lecturerName;

  ReminderStatus get effectiveStatus {
    if (status == ReminderStatus.pending && dueDate.isBefore(DateTime.now())) {
      return ReminderStatus.expired;
    }
    return status;
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final rawTargetRole = map['target_role'];
    return Reminder(
      id: map['id'] as int,
      title: map['judul']?.toString() ?? map['title']?.toString() ?? '',
      description:
          map['deskripsi']?.toString() ?? map['description']?.toString() ?? '',
      createdBy:
          map['created_by']?.toString() ??
          map['author_email']?.toString() ??
          '',
      targetClass: (map['kelas_id'] ?? map['target_class']) as int,
      targetRole: rawTargetRole == null
          ? null
          : UserRole.fromValue(rawTargetRole),
      dueDate:
          DateTime.tryParse(
            map['waktu_reminder']?.toString() ??
                map['due_date']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      priority: ReminderPriority.fromValue(map['priority']),
      status: ReminderStatus.fromValue(map['status']),
      courseId: map['matakuliah_id'] as int?,
      courseName: map['mata_kuliah']?.toString(),
      lecturerName: map['dosen_pengampu']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'judul': title,
    'deskripsi': description,
    'created_by': createdBy,
    'kelas_id': targetClass,
    // Reminders always target every member of the selected class.
    'target_role': null,
    'waktu_reminder': dueDate.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    'matakuliah_id': courseId,
    'mata_kuliah': courseName,
    'dosen_pengampu': lecturerName,
  };
}
