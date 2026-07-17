import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/class_model.dart';
import '../models/user_role.dart';

class ClassService {
  ClassService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchClassCards({
    required UserRole role,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    if (role == UserRole.admin) {
      final rows = await _client
          .from('kelas')
          .select()
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
            (item) => {
              'role': UserRole.admin.value,
              'kelas': Map<String, dynamic>.from(item),
            },
          )
          .toList();
    }

    if (role == UserRole.lecturer) {
      final courses = await _client
          .from('matakuliah')
          .select('kelas(*)')
          .eq('lecturer_id', user.id);
      final unique = <int, Map<String, dynamic>>{};
      for (final item in courses as List) {
        final classData = item['kelas'];
        if (classData is Map && classData['id'] is int) {
          unique[classData['id'] as int] = Map<String, dynamic>.from(classData);
        }
      }
      if (user.email != null) {
        final memberships = await _client
            .from('anggota_kelas')
            .select('kelas(*)')
            .eq('user_email', user.email!);
        for (final item in memberships as List) {
          final classData = item['kelas'];
          if (classData is Map && classData['id'] is int) {
            unique[classData['id'] as int] = Map<String, dynamic>.from(
              classData,
            );
          }
        }
      }
      return unique.values
          .map((item) => {'role': UserRole.lecturer.value, 'kelas': item})
          .toList();
    }

    final rows = await _client
        .from('anggota_kelas')
        .select('role, kelas(*)')
        .eq('user_email', user.email!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<ClassModel>> fetchAccessibleClasses(UserRole role) async {
    final cards = await fetchClassCards(role: role);
    return cards
        .map((item) => item['kelas'])
        .whereType<Map>()
        .map((item) => ClassModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ClassModel>> fetchRegisteredClasses() async {
    final rows = await _client
        .from('kelas')
        .select()
        .order('nama_kelas', ascending: true);
    return (rows as List)
        .map((item) => ClassModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Set<int>> fetchLedClassIds() async {
    final email = _client.auth.currentUser?.email;
    if (email == null) return {};

    final rows = await _client
        .from('anggota_kelas')
        .select('kelas_id, role')
        .eq('user_email', email);
    return (rows as List)
        .where((item) => PermissionPolicy.isClassLeader(item['role']))
        .map((item) => item['kelas_id'])
        .whereType<int>()
        .toSet();
  }

  Future<void> joinByCode(String code) async {
    await _client.rpc('join_class', params: {'access_code': code.trim()});
  }
}
