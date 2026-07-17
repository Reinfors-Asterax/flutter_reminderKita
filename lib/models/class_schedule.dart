class ClassSchedule {
  const ClassSchedule({
    required this.id,
    required this.classId,
    required this.courseId,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  final int id;
  final int classId;
  final int courseId;
  final String day;
  final String startTime;
  final String endTime;
  final String room;

  factory ClassSchedule.fromMap(Map<String, dynamic> map) {
    return ClassSchedule(
      id: map['id'] as int,
      classId: map['kelas_id'] as int,
      courseId: map['matakuliah_id'] as int,
      day: map['hari']?.toString() ?? '',
      startTime: map['jam_mulai']?.toString() ?? '',
      endTime: map['jam_selesai']?.toString() ?? '',
      room: map['ruangan']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'kelas_id': classId,
    'matakuliah_id': courseId,
    'hari': day,
    'jam_mulai': startTime,
    'jam_selesai': endTime,
    'ruangan': room,
  };
}
