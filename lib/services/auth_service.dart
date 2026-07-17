import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final ValueNotifier<AppUser?> session = ValueNotifier<AppUser?>(null);

  SupabaseClient get _client => Supabase.instance.client;

  AppUser? get currentUser => session.value;

  UserRole get currentRole =>
      currentUser?.role ??
      UserRole.fromValue(_client.auth.currentUser?.userMetadata?['role']);

  bool hasPermission(AppPermission permission) {
    return PermissionPolicy.allows(currentRole, permission);
  }

  Future<AppUser?> refreshSession() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      session.value = null;
      return null;
    }

    Map<String, dynamic>? profile;
    try {
      profile = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
    } on PostgrestException catch (error) {
      debugPrint('Profiles belum tersedia: ${error.message}');
    }

    var role = UserRole.fromValue(
      profile?['role'] ?? authUser.userMetadata?['role'],
    );

    // Compatibility for installations that have not run the profiles migration.
    if (role == UserRole.student && authUser.email != null) {
      try {
        final memberships = await _client
            .from('anggota_kelas')
            .select('role')
            .eq('user_email', authUser.email!)
            .limit(50);
        if ((memberships as List).any(
          (item) => PermissionPolicy.isClassLeader(item['role']),
        )) {
          role = UserRole.classLeader;
        }
      } on PostgrestException catch (error) {
        debugPrint('Gagal membaca role kelas: ${error.message}');
      }
    }

    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final requestedRole = profile?['requested_role'];
    final appUser = AppUser(
      id: authUser.id,
      email: authUser.email ?? profile?['email']?.toString() ?? '',
      displayName:
          profile?['display_name']?.toString() ??
          metadata['name']?.toString() ??
          'Pengguna',
      studentNumber:
          profile?['student_number']?.toString() ?? metadata['nim']?.toString(),
      avatarUrl:
          profile?['avatar_url']?.toString() ??
          metadata['avatar_url']?.toString(),
      role: role,
      requestedRole: requestedRole == null
          ? null
          : UserRole.fromValue(requestedRole),
      approvalStatus: AccountApprovalStatus.fromValue(
        profile?['approval_status'],
      ),
    );
    session.value = appUser;
    return appUser;
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    await _client
        .from('profiles')
        .update({
          'role': role.value,
          'requested_role': null,
          'approval_status': AccountApprovalStatus.active.name,
        })
        .eq('id', userId);
    if (userId == currentUser?.id) {
      await refreshSession();
    }
  }

  Future<void> deleteUserAccount(String userId) async {
    await _client.rpc(
      'delete_user_account',
      params: {'target_user_id': userId},
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    session.value = null;
  }

  String dashboardRoute([UserRole? role]) {
    return switch (role ?? currentRole) {
      UserRole.admin => '/dashboard/admin',
      UserRole.lecturer => '/dashboard/lecturer',
      UserRole.classLeader => '/dashboard/class-leader',
      UserRole.student => '/dashboard/student',
    };
  }
}
