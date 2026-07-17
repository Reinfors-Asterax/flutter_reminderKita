import 'package:flutter/material.dart';

import '../home_page.dart';
import '../login_page.dart';
import '../models/user_role.dart';
import '../pages/access_denied_page.dart';
import '../pages/announcement_page.dart';
import '../pages/class_board_page.dart';
import '../pages/create_class_page.dart';
import '../pages/create_lecturer_page.dart';
import '../pages/profile_page.dart';
import '../pages/role_dashboard_page.dart';
import '../pages/schedule_page.dart';
import '../pages/subject_management_page.dart';
import '../pages/task_form_page.dart';
import '../pages/user_management_page.dart';
import '../register_page.dart';
import 'auth_guard.dart';
import 'role_guard.dart';

abstract final class AppRouter {
  static const _allRoles = {
    UserRole.admin,
    UserRole.lecturer,
    UserRole.classLeader,
    UserRole.student,
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
      case '/register':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RegisterPage(),
        );
      case '/dashboard/admin':
        return _dashboard(settings, UserRole.admin);
      case '/dashboard/lecturer':
        return _dashboard(settings, UserRole.lecturer);
      case '/dashboard/class-leader':
        return _dashboard(settings, UserRole.classLeader);
      case '/dashboard/student':
        return _dashboard(settings, UserRole.student);
      case '/home':
      case '/classes':
        return AuthGuard.protect(
          settings: settings,
          builder: (_) => const HomePage(),
        );
      case '/create-class':
        return RoleGuard.protect(
          settings: settings,
          allowedRoles: const {UserRole.classLeader, UserRole.student},
          builder: (_) => const CreateClassPage(),
        );
      case '/users/create-lecturer':
        return RoleGuard.protect(
          settings: settings,
          allowedRoles: const {UserRole.admin},
          builder: (_) => const CreateLecturerPage(),
        );
      case '/class-board':
        return AuthGuard.protect(
          settings: settings,
          builder: (_) => const ClassBoardPage(),
        );
      case '/task-form':
        return RoleGuard.protect(
          settings: settings,
          allowedRoles: const {UserRole.classLeader, UserRole.student},
          builder: (_) => const TaskFormPage(),
        );
      case '/schedule':
        return RoleGuard.protect(
          settings: settings,
          allowedRoles: _allRoles,
          builder: (_) => const SchedulePage(),
        );
      case '/profile':
        return AuthGuard.protect(
          settings: settings,
          builder: (_) => const ProfilePage(),
        );
      case '/manage-subjects':
        return RoleGuard.protect(
          settings: settings,
          allowedRoles: const {UserRole.admin, UserRole.lecturer},
          builder: (_) => const SubjectManagementPage(),
        );
      case '/announcements':
        return AuthGuard.protect(
          settings: settings,
          builder: (_) => const AnnouncementPage(),
        );
      case '/users':
        return RoleGuard.protect(
          settings: settings,
          allowedRoles: const {UserRole.admin},
          builder: (_) => const UserManagementPage(),
        );
      case '/access-denied':
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AccessDeniedPage(),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              const AccessDeniedPage(message: 'Halaman tidak ditemukan.'),
        );
    }
  }

  static Route<dynamic> _dashboard(RouteSettings settings, UserRole role) {
    return RoleGuard.protect(
      settings: settings,
      allowedRoles: {role},
      builder: (_) => RoleDashboardPage(role: role),
    );
  }
}
