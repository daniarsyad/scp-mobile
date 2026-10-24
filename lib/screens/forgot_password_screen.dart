import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiService();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  int _step = 1; // 1=email, 2=otp, 3=password
  bool _loading = false;
  String? _error;
  String? _info;

  Future<void> _requestOtp() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Email wajib diisi');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await _api.post(ApiConfig.forgotRequest, {
      'email': _email.text.trim(),
    });

    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() {
        _step = 2;
        _info = result['message'] ?? 'OTP telah dikirim ke email.';
      });
    } else {
      setState(() => _error = result['message'] ?? 'Gagal mengirim OTP');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _error = 'OTP harus 6 digit');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final result = await _api.post(ApiConfig.forgotVerify, {
      'email': _email.text.trim(),
      'otp': _otp.text.trim(),
    });

    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() {
        _step = 3;
        _info = result['message'] ?? 'OTP benar. Buat password baru.';
      });
    } else {
      setState(() => _error = result['message'] ?? 'OTP salah atau kedaluwarsa');
    }
  }

  Future<void> _resetPassword() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter');
      return;
    }
    if (_password.text != _password2.text) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.post(ApiConfig.forgotReset, {
      'email': _email.text.trim(),
      'otp': _otp.text.trim(),
      'password': _password.text,
      'password_confirmation': _password2.text,
    });

    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah. Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => _error = result['message'] ?? 'Gagal mengubah password');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lupa Password'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Lupa Kata Sandi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? 'Masukkan email terdaftar. OTP akan dikirim ke email tersebut.'
                  : _step == 2
                      ? 'Masukkan kode OTP yang dikirim ke email.'
                      : 'OTP benar. Buat password baru.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            if (_info != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_info!, style: TextStyle(color: Colors.green.shade700)),
              ),
            ],

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ),
            ],

            // Step 1: Email
            if (_step == 1) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Kirim OTP'),
                ),
              ),
            ],

            // Step 2: OTP
            if (_step == 2) ...[
              TextField(
                controller: TextEditingController(text: _email.text),
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Kode OTP (6 digit)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verifikasi OTP'),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _requestOtp,
                child: const Text('Kirim ulang OTP'),
              ),
            ],

            // Step 3: Password baru
            if (_step == 3) ...[
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password Baru',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password2,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ubah Password'),
                ),
              ),
            ],

            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('← Kembali ke Login'),
            ),
          ],
        ),
      ),
    );
  }
}