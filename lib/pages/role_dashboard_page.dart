import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';

class RoleDashboardPage extends StatefulWidget {
  const RoleDashboardPage({super.key, required this.role});

  final UserRole role;

  @override
  State<RoleDashboardPage> createState() => _RoleDashboardPageState();
}

class _RoleDashboardPageState extends State<RoleDashboardPage> {
  static const _primaryColor = Color(0xFF2563EB);
  static const _secondaryColor = Color(0xFF1E293B);

  Future<Map<String, int>>? _statistics;

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.admin) {
      _statistics = _loadStatistics();
    }
  }

  Future<Map<String, int>> _loadStatistics() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client.from('profiles').select('id'),
      client.from('kelas').select('id'),
      client.from('matakuliah').select('id'),
      client.from('tasks').select('id'),
    ]);
    return {
      'User': (results[0] as List).length,
      'Kelas': (results[1] as List).length,
      'Mata Kuliah': (results[2] as List).length,
      'Reminder': (results[3] as List).length,
    };
  }

  List<_DashboardAction> get _actions {
    return switch (widget.role) {
      UserRole.admin => const [
        _DashboardAction(
          'Buat Akun Dosen',
          'Tambahkan akun pengajar baru',
          Icons.person_add_alt_1_rounded,
          '/users/create-lecturer',
        ),
        _DashboardAction(
          'Kelola User',
          'Atur profil dan role pengguna',
          Icons.manage_accounts_rounded,
          '/users',
        ),
        _DashboardAction(
          'Kelola Kelas',
          'Lihat dan hapus kelas',
          Icons.groups_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Kelola Mata Kuliah',
          'Lihat dan hapus mata kuliah',
          Icons.menu_book_rounded,
          '/manage-subjects',
        ),
        _DashboardAction(
          'Pengumuman',
          'Lihat informasi aplikasi',
          Icons.campaign_outlined,
          '/announcements',
        ),
      ],
      UserRole.lecturer => const [
        _DashboardAction(
          'Kelola Mata Kuliah',
          'Tambah dan edit katalog mata kuliah',
          Icons.menu_book_rounded,
          '/manage-subjects',
        ),
        _DashboardAction(
          'Kelola Pengumuman',
          'Informasi untuk kelas dan mahasiswa',
          Icons.campaign_rounded,
          '/announcements',
        ),
      ],
      UserRole.classLeader => const [
        _DashboardAction(
          'Kelas',
          'Buat, gabung, dan kelola kelas',
          Icons.groups_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Reminder Kelas',
          'Kelola reminder kelas',
          Icons.notifications_active_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Jadwal Kelas',
          'Kelola jadwal dari katalog mata kuliah',
          Icons.calendar_today_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Pengumuman Kelas',
          'Buat dan lihat informasi kelas',
          Icons.campaign_rounded,
          '/announcements',
        ),
        _DashboardAction(
          'Anggota Kelas',
          'Pilih kelas untuk melihat anggota',
          Icons.people_alt_rounded,
          '/classes',
        ),
      ],
      UserRole.student => const [
        _DashboardAction(
          'Kelas',
          'Buat atau gabung kelas',
          Icons.groups_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Reminder',
          'Buat dan lihat reminder kelas',
          Icons.notifications_active_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Jadwal',
          'Lihat jadwal kelas',
          Icons.calendar_today_rounded,
          '/classes',
        ),
        _DashboardAction(
          'Pengumuman',
          'Lihat informasi terbaru',
          Icons.campaign_outlined,
          '/announcements',
        ),
      ],
    };
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('ReminderKita'),
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await AuthService.instance.refreshSession();
          if (widget.role == UserRole.admin) {
            setState(() => _statistics = _loadStatistics());
            await _statistics;
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Halo, ${user?.displayName ?? 'Pengguna'}',
              style: const TextStyle(
                color: _secondaryColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dashboard ${widget.role.label}',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            if (_statistics != null) ...[
              const SizedBox(height: 24),
              _StatisticsPanel(statistics: _statistics!),
            ],
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _actions.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 170,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final action = _actions[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.pushNamed(context, action.route),
                  child: Ink(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(action.icon, color: _primaryColor),
                        ),
                        const Spacer(),
                        Text(
                          action.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          action.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsPanel extends StatelessWidget {
  const _StatisticsPanel({required this.statistics});

  final Future<Map<String, int>> statistics;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: statistics,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Text('Statistik belum dapat dimuat.');
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: (snapshot.data ?? const {}).entries.map((entry) {
            return Container(
              width: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(entry.key, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DashboardAction {
  const _DashboardAction(this.title, this.subtitle, this.icon, this.route);

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
