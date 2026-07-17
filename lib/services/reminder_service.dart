import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reminder.dart';

class ReminderService {
  ReminderService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Reminder>> fetchByClass(int classId) async {
    final rows = await _client
        .from('tasks')
        .select()
        .eq('kelas_id', classId)
        .order('waktu_reminder');
    return (rows as List)
        .map((item) => Reminder.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Reminder> create(Reminder reminder) async {
    final row = await _client
        .from('tasks')
        .insert(reminder.toMap())
        .select()
        .single();
    return Reminder.fromMap(row);
  }

  Future<void> update(Reminder reminder) async {
    await _client.from('tasks').update(reminder.toMap()).eq('id', reminder.id);
  }

  Future<void> updateStatus(int id, ReminderStatus status) async {
    await _client.from('tasks').update({'status': status.name}).eq('id', id);
  }

  Future<void> delete(int id) async {
    await _client.from('tasks').delete().eq('id', id);
  }
}
