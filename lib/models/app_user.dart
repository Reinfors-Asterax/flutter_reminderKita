import 'user_role.dart';

enum AccountApprovalStatus {
  active,
  pending,
  rejected;

  static AccountApprovalStatus fromValue(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'pending' => AccountApprovalStatus.pending,
      'rejected' => AccountApprovalStatus.rejected,
      _ => AccountApprovalStatus.active,
    };
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.requestedRole,
    this.approvalStatus = AccountApprovalStatus.active,
    this.studentNumber,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final UserRole? requestedRole;
  final AccountApprovalStatus approvalStatus;
  final String? studentNumber;
  final String? avatarUrl;

  bool get isActive => approvalStatus == AccountApprovalStatus.active;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final requestedRole = map['requested_role'];
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName:
          map['display_name']?.toString() ??
          map['name']?.toString() ??
          'Pengguna',
      role: UserRole.fromValue(map['role']),
      requestedRole: requestedRole == null
          ? null
          : UserRole.fromValue(requestedRole),
      approvalStatus: AccountApprovalStatus.fromValue(map['approval_status']),
      studentNumber:
          map['student_number']?.toString() ?? map['nim']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
    );
  }
}
