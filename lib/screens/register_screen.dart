import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();
  final _fullname = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _subject = TextEditingController();

  List<dynamic> _roles = [];
  List<dynamic> _classes = []; // Menyimpan daftar kelas

  int? _roleId;
  String? _selectedRoleName;
  int? _classId; // Menyimpan ID kelas yang dipilih

  bool _loading = false;
  String? _error;

  // Menentukan apakah field Mata Pelajaran perlu ditampilkan
  bool get _needSubject {
    final name = _selectedRoleName?.toLowerCase() ?? '';
    // Guru dan Wali Kelas butuh mapel. Guru BK tidak.
    return (name == 'guru' || name == 'wali kelas');
  }

  // Menentukan apakah field Kelas perlu ditampilkan
  bool get _needClass {
    final name = _selectedRoleName?.toLowerCase() ?? '';
    return name == 'siswa';
  }

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadClasses(); // Memuat data kelas saat inisialisasi
  }

  Future<void> _loadRoles() async {
    final result = await _api.get(ApiConfig.roles);
    if (result['success'] == true) {
      final data = result['data'];
      setState(() {
        _roles = data is List ? data : [];
      });
    }
  }

  // Fungsi untuk memuat daftar kelas dari API
  Future<void> _loadClasses() async {
    // Pastikan ApiConfig.classes sudah didefinisikan (misal: 'api/classes')
    final result = await _api.get(ApiConfig.classes); 
    if (result['success'] == true) {
      final data = result['data'];
      setState(() {
        _classes = data is List ? data : [];
      });
    }
  }

  Future<void> _submit() async {
    if (_fullname.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = 'Semua field wajib diisi');
      return;
    }
    if (_password.text != _password2.text) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }
    if (_roleId == null) {
      setState(() => _error = 'Pilih role');
      return;
    }
    
    // Validasi Mata Pelajaran
    if (_needSubject && _subject.text.trim().isEmpty) {
      setState(() => _error = 'Mata pelajaran wajib diisi untuk role ini');
      return;
    }
    
    // Validasi Kelas
    if (_needClass && _classId == null) {
      setState(() => _error = 'Kelas wajib dipilih untuk Siswa');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final body = {
      'fullname': _fullname.text.trim(),
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'password_confirmation': _password2.text,
      'role_id': _roleId,
    };

    // Tambahkan subject jika diperlukan
    if (_needSubject) {
      body['subject'] = _subject.text.trim();
    }
    
    // Tambahkan class_id jika diperlukan
    if (_needClass) {
      body['class_id'] = _classId;
    }

    final result = await _api.post(ApiConfig.register, body);

    setState(() => _loading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun berhasil dibuat. Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => _error = result['message'] ?? 'Gagal mendaftar');
    }
  }

  @override
  void dispose() {
    _fullname.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Daftar Akun'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fullname,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _roleId,
              decoration: const InputDecoration(
                labelText: 'Daftar sebagai',
                border: OutlineInputBorder(),
              ),
              items: _roles.map<DropdownMenuItem<int>>((r) {
                return DropdownMenuItem<int>(
                  value: r['id'],
                  child: Text(r['role_name'] ?? '-'),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _roleId = v;
                  final selected = _roles.firstWhere(
                    (r) => r['id'] == v,
                    orElse: () => {},
                  );
                  _selectedRoleName = selected['role_name']?.toString();
                  
                  // Reset field tambahan jika role berubah
                  if (!_needSubject) _subject.clear();
                  if (!_needClass) _classId = null;
                });
              },
            ),
            
            // Dropdown Kelas (Hanya untuk Siswa)
            if (_needClass) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _classId,
                decoration: const InputDecoration(
                  labelText: 'Pilih Kelas',
                  border: OutlineInputBorder(),
                ),
                items: _classes.map<DropdownMenuItem<int>>((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'],
                    // Sesuaikan 'class_name' dengan field di database Anda
                    child: Text(c['class_name'] ?? '-'), 
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _classId = v;
                  });
                },
              ),
            ],

            // TextField Mata Pelajaran (Hanya untuk Guru / Wali Kelas)
            if (_needSubject) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _subject,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran',
                  hintText: 'Contoh: Pemrograman Web, Matematika',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
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
                    : const Text('Daftar', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}