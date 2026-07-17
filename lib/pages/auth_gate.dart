import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login_page.dart';
import '../models/user_role.dart';
import 'role_dashboard_page.dart';
import '../services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<UserRole?> _initialRole;

  @override
  void initState() {
    super.initState();
    _initialRole = _resolveSession();
  }

  Future<UserRole?> _resolveSession() async {
    final hasSession = Supabase.instance.client.auth.currentUser != null;
    if (!hasSession) return null;

    try {
      final appUser = await AuthService.instance.refreshSession();
      if (appUser?.isActive ?? false) return appUser!.role;
    } catch (error) {
      debugPrint('Gagal memulihkan sesi: $error');
    }

    await AuthService.instance.signOut();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserRole?>(
      future: _initialRole,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data;
        if (role == null) return const LoginPage();
        return RoleDashboardPage(role: role);
      },
    );
  }
}
