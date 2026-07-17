class Course {
  const Course({
    required this.id,
    required this.name,
    required this.lecturerName,
    this.classId,
    this.lecturerId,
  });

  final int id;
  final int? classId;
  final String name;
  final String lecturerName;
  final String? lecturerId;

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int,
      classId: map['kelas_id'] as int?,
      name: map['nama']?.toString() ?? '',
      lecturerName: map['dosen']?.toString() ?? '',
      lecturerId: map['lecturer_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'kelas_id': classId,
    'nama': name,
    'dosen': lecturerName,
    'lecturer_id': lecturerId,
  };
}
