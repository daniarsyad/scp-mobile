import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/scp_theme.dart';
import '../widgets/dashboard_kit.dart';
import 'bk/pending_leaves_screen.dart';
import 'dashboard/children_tab.dart';
import 'dashboard/guru_home_tab.dart';
import 'dashboard/ortu_home_tab.dart';
import 'dashboard/siswa_home_tab.dart';
import 'dashboard/verifikator_home_tab.dart';
import 'attendance_report_screen.dart';
import 'guru/create_journal_screen.dart';
import 'guru/kbm_recap_screen.dart';
import 'guru/my_journals_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'schedules/role_schedule_screen.dart';
import 'siswa/my_leaves_screen.dart';
import '../widgets/school_logo.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  Map<String, dynamic>? _nextSchedule;

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Anda harus login kembali untuk mengakses data sekolah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ScpColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _navigateToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  List<Widget> _pages() {
    final user = widget.user;
    if (user.isGuru) {
      return [
        GuruHomeTab(
          user: user,
          onNavigateTab: _navigateToTab,
          onNextSchedule: (schedule) {
            if (mounted && _nextSchedule?['id'] != schedule?['id']) {
              setState(() => _nextSchedule = schedule);
            }
          },
        ),
        const KbmRecapScreen(embedded: true),
        const MyJournalsScreen(),
        RoleScheduleScreen(user: user, embedded: true),
        ProfileScreen(user: user, embedded: true),
      ];
    }
    if (user.isSiswa) {
      return [
        SiswaHomeTab(user: user, onNavigateTab: _navigateToTab),
        RoleScheduleScreen(user: user, embedded: true),
        const MyLeavesScreen(),
        ProfileScreen(user: user, embedded: true),
      ];
    }
    if (user.isOrangTua) {
      return [
        OrtuHomeTab(user: user, onNavigateTab: _navigateToTab),
        ChildrenTab(user: user),
        ProfileScreen(user: user, embedded: true),
      ];
    }
    if (user.isWaliKelas) {
      return [
        VerifikatorHomeTab(
          user: user,
          isBk: false,
          onNavigateTab: _navigateToTab,
        ),
        PendingLeavesScreen(
          targetClass: user.className,
          isBk: false,
          embedded: true,
        ),
        const MyJournalsScreen(),
        AttendanceReportScreen(isBk: false, user: user, embedded: true),
        const KbmRecapScreen(embedded: true),
        RoleScheduleScreen(user: user, embedded: true),
        ProfileScreen(user: user, embedded: true),
      ];
    }
    if (user.isGuruBK) {
      return [
        VerifikatorHomeTab(
          user: user,
          isBk: true,
          onNavigateTab: _navigateToTab,
        ),
        AttendanceReportScreen(isBk: true, user: user, embedded: true),
        const PendingLeavesScreen(isBk: true, embedded: true),
        const MyJournalsScreen(),
        const KbmRecapScreen(embedded: true),
        ProfileScreen(user: user, embedded: true),
      ];
    }
    return [
      Center(
        child: ScpEmpty(message: 'Dashboard untuk role ini belum tersedia'),
      ),
      ProfileScreen(user: user, embedded: true),
    ];
  }

  List<ScpNavItem> _navigation() {
    final user = widget.user;
    if (user.isGuru) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.calendar_month_rounded, 'Rekap KBM'),
        ScpNavItem(Icons.menu_book_rounded, 'Jurnal'),
        ScpNavItem(Icons.event_note_rounded, 'Jadwal'),
      ];
    }
    if (user.isSiswa) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.calendar_month_rounded, 'Jadwal'),
        ScpNavItem(Icons.description_outlined, 'Izin'),
      ];
    }
    if (user.isOrangTua) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.family_restroom_rounded, 'Anak'),
      ];
    }
    if (user.isWaliKelas) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.fact_check_outlined, 'Verifikasi'),
        ScpNavItem(Icons.menu_book_rounded, 'Jurnal'),
        ScpNavItem(Icons.assessment_outlined, 'Presensi'),
        ScpNavItem(Icons.calendar_month_rounded, 'KBM'),
        ScpNavItem(Icons.event_note_rounded, 'Jadwal'),
      ];
    }
    if (user.isGuruBK) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.assessment_outlined, 'Laporan'),
        ScpNavItem(Icons.fact_check_outlined, 'Verifikasi'),
        ScpNavItem(Icons.menu_book_rounded, 'Jurnal'),
        ScpNavItem(Icons.calendar_month_rounded, 'KBM'),
      ];
    }
    return const [ScpNavItem(Icons.home_rounded, 'Home')];
  }

  bool _showShellAppBar(int index) {
    return true;
  }

  String _appBarTitle(int selectedIndex, List<ScpNavItem> navItems) {
    if (selectedIndex == 0) {
      return 'SCP School';
    }
    if (selectedIndex >= navItems.length) return 'Profil';
    return navItems[selectedIndex].label;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    final navItems = _navigation();
    final selectedIndex = _selectedIndex.clamp(0, pages.length - 1);
    final user = widget.user;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: colors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer User Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  border: Border(bottom: BorderSide(color: colors.outline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: ScpColors.blue,
                          child: Text(
                            user.fullname.isEmpty
                                ? '?'
                                : user.fullname[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${user.username}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ScpRoleBadge(
                      roleName: user.roleName ?? 'Pengguna',
                      className: user.className,
                    ),
                  ],
                ),
              ),

              // Navigation Shortcuts
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (var i = 0; i < navItems.length; i++)
                      ListTile(
                        leading: Icon(
                          navItems[i].icon,
                          color: selectedIndex == i
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.65),
                        ),
                        title: Text(
                          navItems[i].label,
                          style: TextStyle(
                            color: selectedIndex == i
                                ? colors.primary
                                : colors.onSurface,
                            fontWeight: selectedIndex == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: selectedIndex == i,
                        selectedTileColor: colors.primary.withValues(
                          alpha: 0.12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _selectedIndex = i);
                        },
                      ),
                  ],
                ),
              ),

              ListTile(
                leading: Icon(
                  Icons.person_outline_rounded,
                  color: selectedIndex == pages.length - 1
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.65),
                ),
                title: Text(
                  'Profil',
                  style: TextStyle(
                    color: selectedIndex == pages.length - 1
                        ? colors.primary
                        : colors.onSurface,
                    fontWeight: selectedIndex == pages.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                selected: selectedIndex == pages.length - 1,
                selectedTileColor: colors.primary.withValues(alpha: 0.12),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = pages.length - 1);
                },
              ),

              Divider(height: 1, color: colors.outline),

              // Logout Tile
              Padding(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: ScpColors.red,
                  ),
                  title: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(
                      color: ScpColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: _showShellAppBar(selectedIndex)
          ? AppBar(
              backgroundColor: colors.surface,
              elevation: 0,
              centerTitle: false,
              title: Row(
                children: [
                  if (selectedIndex == 0) ...[
                    const SchoolLogo(size: 36),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SCP School',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'SMKN 1 Bantul • ${user.roleName ?? 'Pengguna'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SchoolLogo(size: 30),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        _appBarTitle(selectedIndex, navItems),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              leading: IconButton(
                tooltip: 'Menu',
                icon: Icon(Icons.menu_rounded, color: colors.onSurface),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                if (user.className != null && user.className!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ScpColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ScpColors.line),
                        ),
                        child: Text(
                          user.className!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Keluar',
                  icon: Icon(
                    Icons.logout_rounded,
                    color: colors.onSurface.withValues(alpha: 0.65),
                    size: 22,
                  ),
                  onPressed: _logout,
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: colors.outline, height: 1),
              ),
            )
          : null,
      body: IndexedStack(index: selectedIndex, children: pages),
      floatingActionButton:
          (widget.user.isGuru || widget.user.isWaliKelas) &&
              _nextSchedule != null
          ? FloatingActionButton.extended(
              tooltip: 'Isi Jurnal Mengajar',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateJournalScreen(schedule: _nextSchedule!),
                ),
              ),
              backgroundColor: ScpColors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Isi Jurnal'),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: ScpBottomNav(
            index: selectedIndex,
            items: navItems,
            onChanged: (index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }
}
