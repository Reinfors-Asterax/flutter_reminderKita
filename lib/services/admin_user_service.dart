import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/lecturer_account_request.dart';
import '../models/user_role.dart';
import 'auth_service.dart';

class AdminUserService {
  AdminUserService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LecturerAccountResult> createLecturer(
    LecturerAccountRequest request,
  ) async {
    try {
      await _client.functions.invoke('create-lecturer', body: request.toMap());
      return const LecturerAccountResult();
    } on FunctionException catch (error) {
      if (_isMissingFunction(error)) {
        return _createLecturerWithoutEdgeFunction(request);
      }
      final details = error.details;
      if (details is Map && details['message'] != null) {
        throw AdminUserException(details['message'].toString());
      }
      throw AdminUserException(
        error.reasonPhrase ?? 'Gagal membuat akun dosen.',
      );
    }
  }

  Future<LecturerAccountResult> _createLecturerWithoutEdgeFunction(
    LecturerAccountRequest request,
  ) async {
    if (AuthService.instance.currentRole != UserRole.admin) {
      throw const AdminUserException(
        'Hanya Admin yang dapat membuat akun dosen.',
      );
    }

    final existingProfile = await _client
        .from('profiles')
        .select('id')
        .eq('email', request.email.trim().toLowerCase())
        .maybeSingle();
    if (existingProfile != null) {
      throw const AdminUserException('Email sudah terdaftar.');
    }

    final registrationClient = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

    try {
      final response = await registrationClient.auth.signUp(
        email: request.email.trim().toLowerCase(),
        password: request.password,
        data: {
          'name': request.name.trim(),
          'nim': request.lecturerNumber.trim(),
          'role': UserRole.student.value,
        },
      );
      final createdUser = response.user;
      if (createdUser == null || createdUser.identities?.isEmpty == true) {
        throw const AdminUserException('Email sudah terdaftar.');
      }

      await _client
          .from('profiles')
          .update({
            'display_name': request.name.trim(),
            'student_number': request.lecturerNumber.trim(),
            'role': UserRole.lecturer.value,
            'requested_role': null,
            'approval_status': 'active',
          })
          .eq('id', createdUser.id);

      return LecturerAccountResult(
        emailConfirmationRequired: response.session == null,
      );
    } on AuthException catch (error) {
      final message = error.message.toLowerCase().contains('registered')
          ? 'Email sudah terdaftar.'
          : error.message;
      throw AdminUserException(message);
    } finally {
      await registrationClient.dispose();
    }
  }

  bool _isMissingFunction(FunctionException error) {
    final message = '${error.reasonPhrase} ${error.details}'.toLowerCase();
    return error.status == 404 ||
        message.contains('requested function not found') ||
        message.contains('requested function was not found');
  }
}

class LecturerAccountResult {
  const LecturerAccountResult({this.emailConfirmationRequired = false});

  final bool emailConfirmationRequired;
}

class AdminUserException implements Exception {
  const AdminUserException(this.message);

  final String message;

  @override
  String toString() => message;
}
