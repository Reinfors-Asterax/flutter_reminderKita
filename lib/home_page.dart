import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'models/user_role.dart';
import 'services/auth_service.dart';
import 'services/class_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _currentUser = Supabase.instance.client.auth.currentUser;
  final _classService = ClassService();
  List myClasses = [];
  bool _isLoading = true;
  int? _deletingClassId;

  final Color _primaryColor = const Color(0xFF3B82F6);
  final Color _secondaryColor = const Color(0xFF0F172A);
  final Color _bgColor = const Color(0xFFF1F5F9);
  final Color _surfaceColor = Colors.white;

  bool get _isAdmin => AuthService.instance.currentRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _fetchMyClasses();
    }
  }

  Future<void> _fetchMyClasses() async {
    try {
      final response = await _classService.fetchClassCards(
        role: AuthService.instance.currentRole,
      );

      if (mounted) {
        setState(() {
          myClasses = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClass(Map classData) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Kelas'),
            content: Text(
              'Hapus kelas "${classData['nama_kelas']}" beserta seluruh '
              'jadwal, reminder, anggota, dan pengumumannya?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Hapus Permanen',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      if (!mounted) return;
      setState(() => _deletingClassId = classData['id'] as int);
      await Supabase.instance.client
          .from('kelas')
          .delete()
          .eq('id', classData['id']);
      await _fetchMyClasses();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Kelas berhasil dihapus')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Gagal menghapus kelas: $error')),
        );
    } finally {
      if (mounted) {
        setState(() => _deletingClassId = null);
      }
    }
  }

  Future<void> _joinClass(String code) async {
    if (code.isEmpty) return;

    if (mounted) Navigator.pop(context);

    EasyLoading.show(
      status: 'Verifikasi...',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      await _classService.joinByCode(code);
      await AuthService.instance.refreshSession();
      EasyLoading.showSuccess('Berhasil bergabung!');
      _fetchMyClasses();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      EasyLoading.showError('Gagal bergabung: $message');
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _showJoinSheet() {
    final codeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Icon(
                Icons.vpn_key_rounded,
                size: 48,
                color: _primaryColor.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              Text(
                'Masukkan Kode Kelas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _secondaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Dapatkan kode 6 digit dari dosen pengampu",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: _secondaryColor,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XYZ-123',
                    hintStyle: TextStyle(
                      color: Colors.grey[300],
                      letterSpacing: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 24),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _joinClass(codeController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: _primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Gabung Kelas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Keluar Aplikasi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Anda harus login kembali untuk mengakses kelas.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            child: Text("Batal", style: TextStyle(color: Colors.grey[600])),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[50],
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text(
              "Keluar",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    return '${days[now.weekday == 7 ? 0 : now.weekday]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final profileName = AuthService.instance.currentUser?.displayName.trim();
    final userName = profileName != null && profileName.isNotEmpty
        ? profileName.split(' ').first
        : (_currentUser?.userMetadata?['name']?.split(' ')[0] ?? 'User');
    final userEmail = _currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _bgColor,
      body: RefreshIndicator(
        onRefresh: _fetchMyClasses,
        color: _primaryColor,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildAestheticAppBar(userName, userEmail),
            if (_isAdmin) _buildAdminManagementInfo(),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                ),
              )
            else if (myClasses.isEmpty)
              _buildEmptyState()
            else
              _buildClassList(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
      floatingActionButton:
          AuthService.instance.currentRole == UserRole.admin ||
              AuthService.instance.currentRole == UserRole.lecturer
          ? null
          : Container(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                onPressed: _showActionSheet,
                backgroundColor: _secondaryColor,
                elevation: 8,
                highlightElevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  AuthService.instance.hasPermission(
                        AppPermission.manageClasses,
                      )
                      ? "Buat / Gabung"
                      : "Gabung Kelas",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (AuthService.instance.hasPermission(
                AppPermission.manageClasses,
              )) ...[
                _buildActionTile(
                  icon: Icons.add_box_rounded,
                  color: Colors.orange[600]!,
                  title: 'Buat Kelas Baru',
                  subtitle: 'Untuk Mahasiswa atau Ketua Kelas',
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.pushNamed(context, '/create-class');
                    _fetchMyClasses();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.grey[100], height: 1),
                ),
              ],
              _buildActionTile(
                icon: Icons.login_rounded,
                color: _primaryColor,
                title: 'Gabung Kelas',
                subtitle: 'Menggunakan Kode Kelas',
                onTap: () {
                  Navigator.pop(context);
                  _showJoinSheet();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildAestheticAppBar(String name, String email) {
    final avatarUrl =
        Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'];
    final displayName = AuthService.instance.currentUser?.displayName ?? name;

    return SliverAppBar(
      expandedHeight: 130.0,
      floating: false,
      pinned: true,
      backgroundColor: _bgColor,
      elevation: 0,
      surfaceTintColor: _bgColor,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        centerTitle: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDateString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isAdmin ? "Kelola Kelas" : "Halo, $displayName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _secondaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        background: Container(color: _bgColor),
      ),
      actions: [
        IconButton(
          tooltip: 'Pengumuman',
          onPressed: () => Navigator.pushNamed(context, '/announcements'),
          icon: Icon(Icons.campaign_outlined, color: _secondaryColor),
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, '/profile');
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[100],
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, color: Colors.grey[400])
                  : null,
            ),
          ),
        ),
      ],
      leading: IconButton(
        icon: Icon(Icons.dashboard_rounded, color: _secondaryColor),
        tooltip: 'Dashboard',
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AuthService.instance.dashboardRoute(),
          (route) => false,
        ),
      ),
    );
  }

  Widget _buildAdminManagementInfo() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFFEA580C),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${myClasses.length} kelas terdaftar. Admin dapat membuka '
                  'detail atau menghapus kelas secara permanen.',
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 24,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isAdmin ? "Belum Ada Kelas Terdaftar" : "Tidak Ada Kelas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? "Kelas yang dibuat mahasiswa akan tampil di sini."
                  : "Mulai dengan membuat atau bergabung\nke kelas baru.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = myClasses[index];
          return _FadeInUp(
            delay: Duration(milliseconds: 50 * index),
            child: _ClassCard(
              item: item,
              primaryColor: _primaryColor,
              onChanged: _fetchMyClasses,
              onDelete: _isAdmin ? () => _deleteClass(item['kelas']) : null,
              isDeleting: _deletingClassId == item['kelas']['id'],
            ),
          );
        }, childCount: myClasses.length),
      ),
    );
  }
}

class _FadeInUp extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeInUp({required this.child, required this.delay});

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _translate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _translate = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _translate, child: widget.child),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Map item;
  final Color primaryColor;
  final Future<void> Function() onChanged;
  final Future<void> Function()? onDelete;
  final bool isDeleting;

  const _ClassCard({
    required this.item,
    required this.primaryColor,
    required this.onChanged,
    this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final kelas = item['kelas'];
    final role = item['role'];
    final parsedRole = UserRole.fromValue(role);
    final bool isAdmin =
        parsedRole == UserRole.admin ||
        parsedRole == UserRole.lecturer ||
        PermissionPolicy.isClassLeader(role);
    final String className = kelas['nama_kelas'] ?? 'Tanpa Nama';
    final String firstChar = className.isNotEmpty
        ? className[0].toUpperCase()
        : '#';

    final isDarker = isAdmin;
    final iconBgColor = isDarker
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEFF6FF);
    final iconColor = isDarker ? Colors.orange[700] : primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          highlightColor: primaryColor.withOpacity(0.02),
          splashColor: primaryColor.withOpacity(0.05),
          onTap: () async {
            final changed = await Navigator.pushNamed(
              context,
              '/class-board',
              arguments: {
                'id': kelas['id'],
                'nama': kelas['nama_kelas'],
                'role': role,
              },
            );
            if (changed == true) {
              await onChanged();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      firstChar,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildAestheticBadge(
                            label: parsedRole.label,
                            color: isAdmin ? Colors.orange : primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (onDelete != null)
                  isDeleting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Hapus kelas',
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                        )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey[300],
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAestheticBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
