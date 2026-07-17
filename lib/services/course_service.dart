import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course.dart';

class CourseService {
  CourseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Course>> fetchByClass(int classId) async {
    final rows = await _client.from('matakuliah').select().order('nama');
    return (rows as List)
        .map((item) => Course.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Course>> fetchOwnedByCurrentLecturer() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('matakuliah')
        .select()
        .eq('lecturer_id', userId)
        .order('nama');
    return (rows as List)
        .map((item) => Course.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Course> create(Course course) async {
    final row = await _client
        .from('matakuliah')
        .insert(course.toMap())
        .select()
        .single();
    return Course.fromMap(row);
  }

  Future<void> update(Course course) async {
    await _client.from('matakuliah').update(course.toMap()).eq('id', course.id);
  }

  Future<void> delete(int id) async {
    await _client.from('matakuliah').delete().eq('id', id);
  }
}
