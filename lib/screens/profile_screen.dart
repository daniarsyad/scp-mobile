import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/app_theme_controller.dart';
import '../theme/scp_theme.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  final bool embedded;

  const ProfileScreen({super.key, required this.user, this.embedded = false});

  Future<void> _setTheme(BuildContext context, ThemeMode mode) async {
    try {
      await AppThemeController.instance.setThemeMode(mode);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pengaturan tema: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    if (embedded) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Profil')),
      body: body,
    );
  }

  Widget _body(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: ScpColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  user.fullname.isEmpty ? '?' : user.fullname[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullname.isEmpty ? 'Pengguna SCP' : user.fullname,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Informasi Akun',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: colors.onSurface),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _infoTile(
                context,
                icon: Icons.badge_outlined,
                label: 'Peran',
                value: user.roleName ?? 'Pengguna',
              ),
              if (user.className != null && user.className!.isNotEmpty) ...[
                Divider(
                  height: 1,
                  color: colors.outline.withValues(alpha: 0.35),
                ),
                _infoTile(
                  context,
                  icon: Icons.groups_outlined,
                  label: 'Kelas',
                  value: user.className!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Tampilan Aplikasi',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: colors.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih tampilan yang nyaman. Pengaturan ini tersimpan di perangkat.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 10),
        for (final option in _themeOptions)
          _themeOption(
            context,
            option.mode,
            option.label,
            option.description,
            option.icon,
          ),
      ],
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(
        label,
        style: TextStyle(color: colors.onSurface.withValues(alpha: 0.65)),
      ),
      subtitle: Text(
        value,
        style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    ThemeMode mode,
    String label,
    String description,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final selected = AppThemeController.instance.themeMode == mode;
        return Card(
          color: selected
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surface,
          child: ListTile(
            onTap: selected ? null : () => _setTheme(context, mode),
            leading: Icon(
              icon,
              color: selected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.65),
            ),
            title: Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              description,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
            ),
            trailing: selected
                ? Icon(Icons.check_circle_rounded, color: colors.primary)
                : Icon(Icons.circle_outlined, color: colors.outline),
          ),
        );
      },
    );
  }

  static const _themeOptions =
      <({ThemeMode mode, String label, String description, IconData icon})>[
        (
          mode: ThemeMode.light,
          label: 'Siang',
          description: 'Gunakan tampilan terang.',
          icon: Icons.light_mode_rounded,
        ),
        (
          mode: ThemeMode.dark,
          label: 'Malam',
          description: 'Gunakan tampilan gelap.',
          icon: Icons.dark_mode_rounded,
        ),
      ];
}
