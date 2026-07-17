import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/class_schedule.dart';

class ScheduleService {
  ScheduleService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<ClassSchedule>> watchByClass(int classId) {
    return _client
        .from('jadwal_kelas')
        .stream(primaryKey: ['id'])
        .eq('kelas_id', classId)
        .map(
          (rows) => rows
              .map((item) => ClassSchedule.fromMap(item))
              .toList(growable: false),
        );
  }

  Future<void> save(ClassSchedule schedule) async {
    if (schedule.id == 0) {
      await _client.from('jadwal_kelas').insert(schedule.toMap());
      return;
    }
    await _client
        .from('jadwal_kelas')
        .update(schedule.toMap())
        .eq('id', schedule.id);
  }

  Future<void> delete(int id) async {
    await _client.from('jadwal_kelas').delete().eq('id', id);
  }
}
