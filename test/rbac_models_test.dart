import 'package:flutter_test/flutter_test.dart';
import 'package:reminderkita/models/app_user.dart';
import 'package:reminderkita/models/announcement.dart';
import 'package:reminderkita/models/lecturer_account_request.dart';
import 'package:reminderkita/models/reminder.dart';
import 'package:reminderkita/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('maps canonical and legacy role values', () {
      expect(UserRole.fromValue('admin'), UserRole.admin);
      expect(UserRole.fromValue('Dosen'), UserRole.lecturer);
      expect(UserRole.fromValue('Ketua Kelas'), UserRole.classLeader);
      expect(UserRole.fromValue('Wakil Ketua Kelas'), UserRole.classLeader);
      expect(UserRole.fromValue('Mahasiswa'), UserRole.student);
    });

    test('enforces the expected permission matrix', () {
      expect(
        PermissionPolicy.allows(UserRole.admin, AppPermission.manageUsers),
        isTrue,
      );
      expect(
        PermissionPolicy.allows(UserRole.lecturer, AppPermission.manageCourses),
        isTrue,
      );
      expect(
        PermissionPolicy.allows(
          UserRole.lecturer,
          AppPermission.manageSchedules,
        ),
        isFalse,
      );
      expect(
        PermissionPolicy.allows(
          UserRole.classLeader,
          AppPermission.manageReminders,
        ),
        isTrue,
      );
      expect(
        PermissionPolicy.allows(
          UserRole.classLeader,
          AppPermission.manageAnnouncements,
        ),
        isTrue,
      );
      expect(
        PermissionPolicy.allows(
          UserRole.student,
          AppPermission.manageReminders,
        ),
        isTrue,
      );
      expect(
        PermissionPolicy.allows(
          UserRole.student,
          AppPermission.manageSchedules,
        ),
        isFalse,
      );
      expect(
        PermissionPolicy.allows(UserRole.admin, AppPermission.manageCourses),
        isFalse,
      );
    });

    test('separates public registration and login roles', () {
      expect(UserRole.registrationRoles, [UserRole.student]);
      expect(UserRole.loginRoles, [
        UserRole.admin,
        UserRole.student,
        UserRole.lecturer,
      ]);
      expect(UserRole.classLeader.matchesLoginRole(UserRole.student), isTrue);
      expect(UserRole.lecturer.matchesLoginRole(UserRole.student), isFalse);
    });
  });

  group('AppUser', () {
    test('maps pending privileged role requests', () {
      final user = AppUser.fromMap({
        'id': 'user-id',
        'email': 'dosen@example.com',
        'display_name': 'Dosen',
        'role': 'student',
        'requested_role': 'lecturer',
        'approval_status': 'pending',
      });

      expect(user.role, UserRole.student);
      expect(user.requestedRole, UserRole.lecturer);
      expect(user.approvalStatus, AccountApprovalStatus.pending);
      expect(user.isActive, isFalse);
    });
  });

  test('LecturerAccountRequest normalizes the Edge Function payload', () {
    const request = LecturerAccountRequest(
      name: '  Dosen Satu  ',
      lecturerNumber: ' 012345 ',
      email: ' DOSEN@EXAMPLE.COM ',
      password: 'password123',
    );

    expect(request.toMap(), {
      'name': 'Dosen Satu',
      'lecturerNumber': '012345',
      'email': 'dosen@example.com',
      'password': 'password123',
    });
  });

  group('Reminder', () {
    test('maps the legacy tasks schema to the domain model', () {
      final dueDate = DateTime.now().add(const Duration(days: 10));
      final reminder = Reminder.fromMap({
        'id': 7,
        'judul': 'Ujian akhir',
        'deskripsi': 'Ruang 301',
        'created_by': 'user-id',
        'kelas_id': 3,
        'target_role': 'student',
        'waktu_reminder': dueDate.toIso8601String(),
        'priority': 'urgent',
        'status': 'pending',
      });

      expect(reminder.title, 'Ujian akhir');
      expect(reminder.targetClass, 3);
      expect(reminder.targetRole, UserRole.student);
      expect(reminder.priority, ReminderPriority.urgent);
      expect(reminder.effectiveStatus, ReminderStatus.pending);
      expect(reminder.toMap()['target_role'], isNull);
    });

    test('derives expired status for overdue pending reminders', () {
      final reminder = Reminder(
        id: 1,
        title: 'Terlambat',
        description: '',
        createdBy: 'user-id',
        targetClass: 1,
        dueDate: DateTime.now().subtract(const Duration(minutes: 1)),
        priority: ReminderPriority.high,
        status: ReminderStatus.pending,
      );

      expect(reminder.effectiveStatus, ReminderStatus.expired);
      expect(reminder.toMap()['priority'], 'high');
      expect(reminder.toMap()['status'], 'pending');
    });
  });

  test('Announcement maps its linked course', () {
    final announcement = Announcement.fromMap({
      'id': 9,
      'title': 'Perubahan Ruang',
      'content': 'Kuliah pindah ke ruang 301.',
      'created_by': 'lecturer-id',
      'created_at': DateTime.now().toIso8601String(),
      'course_id': 4,
      'matakuliah': {'nama': 'Manajemen Proyek SI'},
    });

    expect(announcement.courseId, 4);
    expect(announcement.courseName, 'Manajemen Proyek SI');
    expect(announcement.toMap()['course_id'], 4);
  });
}
