import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../pages/access_denied_page.dart';
import '../services/auth_service.dart';
import 'auth_guard.dart';

abstract final class RoleGuard {
  static Route<dynamic> protect({
    required RouteSettings settings,
    required Set<UserRole> allowedRoles,
    required WidgetBuilder builder,
  }) {
    return AuthGuard.protect(
      settings: settings,
      builder: (context) {
        final role = AuthService.instance.currentRole;
        if (!allowedRoles.contains(role)) {
          return const AccessDeniedPage();
        }
        return builder(context);
      },
    );
  }
}
