class UserModel {
  final int id;
  final String username;
  final String fullname;
  final int roleId;
  final String? roleName;
  final int? classId;
  final String? className;

  UserModel({
    required this.id,
    required this.username,
    required this.fullname,
    required this.roleId,
    this.roleName,
    this.classId,
    this.className,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // role bisa String ("Guru") atau Map { role_name: "Guru" }
    String? roleName;
    if (json['role'] is String) {
      roleName = json['role'];
    } else if (json['role'] is Map) {
      roleName = json['role']['role_name']?.toString();
    } else {
      roleName = json['role_name']?.toString();
    }

    String? className;
    if (json['class'] is String) {
      className = json['class'];
    } else if (json['class'] is Map) {
      className = json['class']['class_name']?.toString();
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      roleId: json['role_id'] is int
          ? json['role_id']
          : int.tryParse('${json['role_id'] ?? 0}') ?? 0,
      roleName: roleName,
      classId: json['class_id'] is int
          ? json['class_id']
          : int.tryParse('${json['class_id'] ?? ''}'),
      className: className,
    );
  }

  String get _roleKey =>
      (roleName ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool get isGuruBK => _roleKey == 'gurubk';
  bool get isWaliKelas => _roleKey == 'walikelas';
  bool get isOrangTua => _roleKey == 'orangtua' || _roleKey == 'ortu';
  bool get isSiswa => _roleKey == 'siswa';
  bool get isGuru => _roleKey == 'guru';
  bool get isWaka => _roleKey == 'wakakurikulum';
  bool get isKepalaSekolah => _roleKey == 'kepalasekolah';
  bool get canMonitorJournals => isWaka || isKepalaSekolah;
}
