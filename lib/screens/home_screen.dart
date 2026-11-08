import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/scp_theme.dart';
import '../widgets/dashboard_kit.dart';
import 'bk/pending_leaves_screen.dart';
import 'dashboard/guru_home_tab.dart';
import 'dashboard/siswa_home_tab.dart';
import 'dashboard/attendance_history_screen.dart';
import 'dashboard/verifikator_home_tab.dart';
import 'attendance_report_screen.dart';
import 'guru/create_journal_screen.dart';
import 'guru/kbm_recap_screen.dart';
import 'guru/my_journals_screen.dart';
import 'guru/journal_monitor_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'edit_profile_screen.dart';
import 'schedules/role_schedule_screen.dart';
import 'siswa/my_leaves_screen.dart';
import '../widgets/school_logo.dart';
import '../utils/format.dart';

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
  late UserModel _currentUser;
  int? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser.isOrangTua) {
      if (_currentUser.children.isNotEmpty) {
        _selectedChildId = int.tryParse('${_currentUser.children.first['id']}');
      }
      _fetchChildrenForParent();
    }
  }

  Future<void> _fetchChildrenForParent() async {
    try {
      final res = await ApiService().get(ApiConfig.children);
      if (res['success'] == true) {
        final list = asList(res['data'])
            .whereType<Map>()
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _currentUser = _currentUser.copyWith(children: list);
            _selectedChildId ??= int.tryParse('${list.first['id']}');
          });
        }
      }
    } catch (_) {}
  }

  Map<String, dynamic>? get _selectedChild {
    if (!_currentUser.isOrangTua) return null;
    if (_currentUser.children.isEmpty) return null;
    if (_selectedChildId != null) {
      for (final child in _currentUser.children) {
        if (int.tryParse('${child['id']}') == _selectedChildId) {
          return child;
        }
      }
    }
    return _currentUser.children.first;
  }

  void _onProfileUpdated(UserModel updated) {
    setState(() {
      _currentUser = updated;
    });
  }

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
    final user = _currentUser;
    if (user.isGuruBK) {
      return [
        VerifikatorHomeTab(
          user: user,
          isBk: true,
          onNavigateTab: _navigateToTab,
          onProfileUpdated: _onProfileUpdated,
        ),
        AttendanceReportScreen(isBk: true, user: user, embedded: true),
        PendingLeavesScreen(isBk: true, embedded: true, user: user),
        GuruHomeTab(
          user: user,
          onNavigateTab: _navigateToTab,
          showRecapAction: false,
          journalTabIndex: 5,
          attendanceTabIndex: 1,
          onProfileUpdated: _onProfileUpdated,
          onNextSchedule: (schedule) {
            if (mounted && _nextSchedule?['id'] != schedule?['id']) {
              setState(() => _nextSchedule = schedule);
            }
          },
        ),
        RoleScheduleScreen(user: user, embedded: true),
        const MyJournalsScreen(),
        ProfileScreen(user: user, embedded: true, onProfileUpdated: _onProfileUpdated),
      ];
    }
    if (user.isWaliKelas) {
      return [
        GuruHomeTab(
          user: user,
          onNavigateTab: _navigateToTab,
          recapTabIndex: 4,
          attendanceTabIndex: 3,
          onProfileUpdated: _onProfileUpdated,
          onNextSchedule: (schedule) {
            if (mounted && _nextSchedule?['id'] != schedule?['id']) {
              setState(() => _nextSchedule = schedule);
            }
          },
        ),
        PendingLeavesScreen(
          targetClass: user.className,
          isBk: false,
          embedded: true,
        ),
        const MyJournalsScreen(),
        AttendanceReportScreen(isBk: false, user: user, embedded: true),
        KbmRecapScreen(embedded: true, ownerId: user.id, user: user),
        RoleScheduleScreen(user: user, embedded: true),
        ProfileScreen(user: user, embedded: true, onProfileUpdated: _onProfileUpdated),
      ];
    }
    if (user.isGuru) {
      return [
        GuruHomeTab(
          user: user,
          onNavigateTab: _navigateToTab,
          onProfileUpdated: _onProfileUpdated,
          onNextSchedule: (schedule) {
            if (mounted && _nextSchedule?['id'] != schedule?['id']) {
              setState(() => _nextSchedule = schedule);
            }
          },
        ),
        KbmRecapScreen(embedded: true, ownerId: user.id, user: user),
        const MyJournalsScreen(),
        RoleScheduleScreen(user: user, embedded: true),
        ProfileScreen(user: user, embedded: true, onProfileUpdated: _onProfileUpdated),
      ];
    }
    if (user.isSiswa || user.isOrangTua) {
      final child = _selectedChild;
      return [
        SiswaHomeTab(
          user: user,
          onNavigateTab: _navigateToTab,
          isParent: user.isOrangTua,
          selectedStudentId: _selectedChildId,
          onProfileUpdated: _onProfileUpdated,
          onSelectStudent: (id) {
            setState(() => _selectedChildId = id);
          },
          onChildrenUpdated: (children) {
            setState(() {
              _currentUser = _currentUser.copyWith(children: children);
              if (_selectedChildId == null && children.isNotEmpty) {
                _selectedChildId = int.tryParse('${children.first['id']}');
              }
            });
          },
        ),
        AttendanceHistoryScreen(
          user: user,
          isParent: user.isOrangTua,
          student: child,
          children: user.children,
          onSelectStudent: (id) {
            setState(() => _selectedChildId = id);
          },
          embedded: true,
        ),
        RoleScheduleScreen(
          user: user,
          child: child,
          children: user.children,
          onSelectStudent: (id) {
            setState(() => _selectedChildId = id);
          },
          embedded: true,
        ),
        MyLeavesScreen(
          user: user,
          selectedChild: child,
        ),
        ProfileScreen(user: user, embedded: true, onProfileUpdated: _onProfileUpdated),
      ];
    }
    if (user.canMonitorJournals) {
      return [
        JournalMonitorScreen(user: user, embedded: true),
        ProfileScreen(user: user, embedded: true, onProfileUpdated: _onProfileUpdated),
      ];
    }
    return [
      Center(
        child: ScpEmpty(message: 'Dashboard untuk role ini belum tersedia'),
      ),
      ProfileScreen(user: user, embedded: true, onProfileUpdated: _onProfileUpdated),
    ];
  }

  List<ScpNavItem> _navigation() {
    final user = _currentUser;
    if (user.isGuruBK) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.assessment_outlined, 'Laporan'),
        ScpNavItem(Icons.fact_check_outlined, 'Monitoring Izin'),
        ScpNavItem(Icons.edit_note_rounded, 'Jurnal (Opsional)'),
        ScpNavItem(Icons.event_note_rounded, 'Jadwal Mengajar'),
        ScpNavItem(Icons.menu_book_rounded, 'Riwayat Jurnal'),
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
    if (user.isGuru) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.calendar_month_rounded, 'Rekap KBM'),
        ScpNavItem(Icons.menu_book_rounded, 'Jurnal'),
        ScpNavItem(Icons.event_note_rounded, 'Jadwal'),
      ];
    }
    if (user.isSiswa || user.isOrangTua) {
      return const [
        ScpNavItem(Icons.home_rounded, 'Home'),
        ScpNavItem(Icons.assessment_outlined, 'Presensi'),
        ScpNavItem(Icons.calendar_month_rounded, 'Jadwal'),
        ScpNavItem(Icons.description_outlined, 'Izin'),
      ];
    }
    if (user.canMonitorJournals) {
      return const [ScpNavItem(Icons.fact_check_outlined, 'Monitoring Jurnal')];
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
    final user = _currentUser;
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
                    Row(
                      children: [
                        Expanded(
                          child: ScpRoleBadge(
                            roleName: user.roleName ?? 'Pengguna',
                            className: user.displayClassName,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final updated = await Navigator.push<UserModel>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProfileScreen(
                                  user: user,
                                  onProfileUpdated: _onProfileUpdated,
                                ),
                              ),
                            );
                            if (updated != null) {
                              _onProfileUpdated(updated);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 14, color: colors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit Profil',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

              Divider(height: 1, color: colors.outline),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'AKUN & PENGATURAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.manage_accounts_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Edit Profil & Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Ubah username, email, dan password',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final updated = await Navigator.push<UserModel>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        user: user,
                        onProfileUpdated: _onProfileUpdated,
                      ),
                    ),
                  );
                  if (updated != null) {
                    _onProfileUpdated(updated);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: selectedIndex == pages.length - 1
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Detail Profil',
                  style: TextStyle(
                    color: selectedIndex == pages.length - 1
                        ? colors.primary
                        : colors.onSurface,
                    fontWeight: selectedIndex == pages.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                selected: selectedIndex == pages.length - 1,
                selectedTileColor: colors.primary.withValues(alpha: 0.12),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SCP School',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'SMKN 1 Bantul • ${user.roleName ?? 'Pengguna'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
                Builder(
                  builder: (_) {
                    final badgeText = user.isOrangTua
                        ? (_selectedChild?['class_name']?.toString() ??
                            asMap(_selectedChild?['class'])['class_name']?.toString() ??
                            user.displayClassName ??
                            '')
                        : (user.displayClassName ?? '');
                    if (badgeText.isEmpty) return const SizedBox();
                    return Padding(
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
                            badgeText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ScpColors.muted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Edit Profil & Password',
                  icon: Icon(
                    Icons.account_circle_outlined,
                    color: colors.primary,
                    size: 24,
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<UserModel>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                          user: user,
                          onProfileUpdated: _onProfileUpdated,
                        ),
                      ),
                    );
                    if (updated != null) {
                      _onProfileUpdated(updated);
                    }
                  },
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
          (user.isGuru ||
                  user.isWaliKelas ||
                  user.isGuruBK) &&
              _nextSchedule != null && !scheduleNotStarted(_nextSchedule!)
          ? FloatingActionButton.extended(
              tooltip: 'Isi Jurnal Mengajar',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateJournalScreen(
                    schedule: _nextSchedule!,
                    ownerId: user.id,
                  ),
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
