import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement.dart';

class AnnouncementService {
  AnnouncementService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Announcement>> fetchVisible() async {
    final rows = await _client
        .from('announcements')
        .select(
          '*, profiles!announcements_created_by_fkey(display_name), '
          'matakuliah!announcements_course_id_fkey(nama)',
        )
        .order('created_at', ascending: false);
    return (rows as List)
        .map((item) => Announcement.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Announcement> create(Announcement announcement) async {
    final row = await _client
        .from('announcements')
        .insert(announcement.toMap())
        .select()
        .single();
    return Announcement.fromMap(row);
  }

  Future<void> update(Announcement announcement) async {
    await _client
        .from('announcements')
        .update(announcement.toMap()..remove('created_by'))
        .eq('id', announcement.id);
  }

  Future<void> delete(int id) async {
    await _client.from('announcements').delete().eq('id', id);
  }
}
