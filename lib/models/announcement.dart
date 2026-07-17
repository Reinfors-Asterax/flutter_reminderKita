import 'user_role.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdBy,
    required this.createdAt,
    this.targetClass,
    this.targetRole,
    this.courseId,
    this.courseName,
    this.authorName,
  });

  final int id;
  final String title;
  final String content;
  final String createdBy;
  final DateTime createdAt;
  final int? targetClass;
  final UserRole? targetRole;
  final int? courseId;
  final String? courseName;
  final String? authorName;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    final rawRole = map['target_role'];
    final profile = map['profiles'];
    final course = map['matakuliah'];
    return Announcement(
      id: map['id'] as int,
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      targetClass: map['target_class'] as int?,
      targetRole: rawRole == null ? null : UserRole.fromValue(rawRole),
      courseId: map['course_id'] as int?,
      courseName: course is Map
          ? course['nama']?.toString()
          : map['course_name']?.toString(),
      authorName: profile is Map
          ? profile['display_name']?.toString()
          : map['author_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'created_by': createdBy,
    'target_class': targetClass,
    'target_role': targetRole?.value,
    'course_id': courseId,
  };
}
