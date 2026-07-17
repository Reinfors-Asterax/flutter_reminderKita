enum UserRole {
  admin,
  lecturer,
  classLeader,
  student;

  static const registrationRoles = [UserRole.student];

  static const loginRoles = [
    UserRole.admin,
    UserRole.student,
    UserRole.lecturer,
  ];

  String get value => switch (this) {
    UserRole.admin => 'admin',
    UserRole.lecturer => 'lecturer',
    UserRole.classLeader => 'class_leader',
    UserRole.student => 'student',
  };

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.lecturer => 'Dosen',
    UserRole.classLeader => 'Ketua Kelas',
    UserRole.student => 'Mahasiswa',
  };

  static UserRole fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'admin' => UserRole.admin,
      'lecturer' || 'dosen' => UserRole.lecturer,
      'class_leader' ||
      'classleader' ||
      'ketua kelas' ||
      'ketua' ||
      'wakil ketua kelas' ||
      'vice_admin' => UserRole.classLeader,
      _ => UserRole.student,
    };
  }

  bool matchesLoginRole(UserRole selectedRole) {
    if (selectedRole == UserRole.student) {
      return this == UserRole.student || this == UserRole.classLeader;
    }
    return this == selectedRole;
  }
}

enum AppPermission {
  manageUsers,
  manageClasses,
  manageCourses,
  manageReminders,
  manageAnnouncements,
  manageSchedules,
  viewClasses,
  viewReminders,
  viewAnnouncements,
  viewSchedules,
  viewMembers,
  viewStatistics,
}

abstract final class PermissionPolicy {
  static final Map<UserRole, Set<AppPermission>> _permissions = {
    UserRole.admin: {
      AppPermission.manageUsers,
      AppPermission.viewClasses,
      AppPermission.viewReminders,
      AppPermission.viewAnnouncements,
      AppPermission.viewSchedules,
      AppPermission.viewMembers,
      AppPermission.viewStatistics,
    },
    UserRole.lecturer: {
      AppPermission.manageCourses,
      AppPermission.manageAnnouncements,
      AppPermission.viewReminders,
      AppPermission.viewAnnouncements,
      AppPermission.viewSchedules,
    },
    UserRole.classLeader: {
      AppPermission.manageClasses,
      AppPermission.manageReminders,
      AppPermission.manageAnnouncements,
      AppPermission.manageSchedules,
      AppPermission.viewClasses,
      AppPermission.viewReminders,
      AppPermission.viewAnnouncements,
      AppPermission.viewSchedules,
      AppPermission.viewMembers,
    },
    UserRole.student: {
      AppPermission.manageClasses,
      AppPermission.manageReminders,
      AppPermission.viewClasses,
      AppPermission.viewReminders,
      AppPermission.viewAnnouncements,
      AppPermission.viewSchedules,
    },
  };

  static bool allows(UserRole role, AppPermission permission) {
    return _permissions[role]?.contains(permission) ?? false;
  }

  static bool isClassLeader(Object? role) {
    final normalized = role?.toString().trim().toLowerCase();
    return normalized == 'class_leader' ||
        normalized == 'classleader' ||
        normalized == 'ketua kelas' ||
        normalized == 'ketua' ||
        normalized == 'wakil ketua kelas' ||
        normalized == 'vice_admin';
  }
}
