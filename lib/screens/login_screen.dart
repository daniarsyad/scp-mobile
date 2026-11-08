import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/scp_theme.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/school_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    final identifierText = _identifier.text.trim();
    final passwordText = _password.text;

    if (identifierText.isEmpty || passwordText.isEmpty) {
      setState(
        () => _error = 'NIS, NIP, atau username dan password wajib diisi',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _auth.login(identifierText, passwordText);

    if (mounted) setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      final UserModel? user = result['user'];
      if (user == null) {
        setState(() => _error = 'Data profil pengguna tidak ditemukan');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } else {
      setState(
        () => _error =
            result['message'] ?? 'Login gagal. Periksa username dan password.',
      );
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showServerConfigDialog() {
    final urlCtrl = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: ScpColors.blue, size: 22),
            SizedBox(width: 8),
            Text(
              'Pengaturan Server API',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan URL backend Anda (misal domain hosting atau IP laptop):',
                style: TextStyle(fontSize: 13, color: ScpColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL API',
                  hintText: 'https://domain-anda.com/api',
                  prefixIcon: Icon(Icons.link_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pilihan Cepat:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ScpColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = 'http://127.0.0.1:8000/api',
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = 'http://10.0.2.2:8000/api',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.setCustomUrl(null);
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reset Default', style: TextStyle(color: ScpColors.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = urlCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiConfig.setCustomUrl(newUrl);
                if (mounted) setState(() {});
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Server API diatur ke: ${ApiConfig.baseUrl}'),
                    backgroundColor: ScpColors.blue,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ScpColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScpColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // School Crest & Header
                  const SchoolLogo(size: 88),
                  const SizedBox(height: 16),
                  const Text(
                    'SCP School',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: ScpColors.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sistem Informasi & Presensi Digital',
                    style: TextStyle(
                      color: ScpColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'SMK Negeri 1 Bantul',
                    style: TextStyle(
                      color: ScpColors.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ScpColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Masuk ke Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Silakan masukkan kredensial akun Anda',
                          style: TextStyle(
                            color: ScpColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Username Field
                        TextField(
                          controller: _identifier,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'NIS Siswa / NIP / Username',
                            hintText: 'Masukkan NIS, NIP, atau username',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Masukkan password',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: ScpColors.muted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: ScpColors.blue,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              'Lupa password?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ScpColors.redCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ScpColors.redBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: ScpColors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
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
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ScpColors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Masuk Sekarang',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _showServerConfigDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ScpColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_outlined, size: 16, color: ScpColors.muted),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Server: ${ApiConfig.baseUrl}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ScpColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 14, color: ScpColors.muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
