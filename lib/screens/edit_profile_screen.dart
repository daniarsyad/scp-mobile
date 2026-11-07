import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/scp_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullnameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  bool _loading = false;
  String? _errorMessage;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _fullnameController = TextEditingController(text: widget.user.fullname);
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email ?? '');
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newPass = _newPasswordController.text.trim();
    final currentPass = _currentPasswordController.text;

    if (newPass.isNotEmpty && currentPass.isEmpty) {
      setState(() {
        _errorMessage = 'Password saat ini wajib diisi jika ingin mengubah password.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await _authService.updateProfile(
      fullname: _fullnameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? '' : _emailController.text.trim(),
      currentPassword: currentPass.isEmpty ? null : currentPass,
      newPassword: newPass.isEmpty ? null : newPass,
      newPasswordConfirmation: _confirmPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      final updatedUser = res['user'] as UserModel?;
      if (updatedUser != null) {
        widget.onProfileUpdated?.call(updatedUser);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Profil dan akun berhasil diperbarui!')),
            ],
          ),
          backgroundColor: ScpColors.green,
        ),
      );
      Navigator.pop(context, updatedUser);
    } else {
      setState(() {
        _errorMessage = res['message']?.toString() ?? 'Gagal menyimpan profil.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ScpColors.redCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ScpColors.redBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: ScpColors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: ScpColors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Kartu Informasi Akun
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: colors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Informasi Profil',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Nama Lengkap
                      TextFormField(
                        controller: _fullnameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap *',
                          hintText: 'Nama lengkap Anda',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama lengkap tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username *',
                          hintText: 'Username akun Anda',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Username tidak boleh kosong';
                          }
                          if (val.trim().length < 3) {
                            return 'Username minimal 3 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (opsional)',
                          hintText: 'email@sekolah.sch.id',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                          helperText: 'Digunakan untuk verifikasi OTP saat lupa password',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Kartu Ubah Password
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: ScpColors.amber, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Ubah Password',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kosongkan bagian ini jika Anda tidak ingin mengganti password.',
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Saat Ini
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Password Saat Ini',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.key_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password Baru
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          hintText: 'Minimal 6 karakter',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && val.length < 6) {
                            return 'Password baru minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Konfirmasi Password Baru
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Ulangi Password Baru',
                          hintText: 'Ulangi password baru Anda',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (_newPasswordController.text.isNotEmpty && val != _newPasswordController.text) {
                            return 'Konfirmasi password baru tidak cocok';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScpColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Perubahan',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
