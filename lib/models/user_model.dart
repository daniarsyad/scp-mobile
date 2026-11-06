class UserModel {
  final int id;
  final String username;
  final String fullname;
  final int roleId;
  final String? roleName;
  final List<String> additionalRoles;
  final int? classId;
  final String? className;
  final List<Map<String, dynamic>> children;
  final List<Map<String, dynamic>> bkClasses;

  UserModel({
    required this.id,
    required this.username,
    required this.fullname,
    required this.roleId,
    this.roleName,
    this.additionalRoles = const [],
    this.classId,
    this.className,
    this.children = const [],
    this.bkClasses = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleName = _roleName(json['role']) ?? json['role_name']?.toString();
    final additionalRolesJson = json['additional_roles'];
    String? className;
    if (json['class'] is String) {
      className = json['class'];
    } else if (json['class'] is Map) {
      className = json['class']['class_name']?.toString();
    }

    final childrenJson = json['children'];
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      username:
          json['username']?.toString() ??
          json['nis']?.toString() ??
          json['nip']?.toString() ??
          '',
      fullname: json['fullname']?.toString() ?? '',
      roleId: json['role_id'] is int
          ? json['role_id']
          : int.tryParse('${json['role_id'] ?? 0}') ?? 0,
      roleName: roleName,
      additionalRoles: additionalRolesJson is List
          ? additionalRolesJson
                .map(_roleName)
                .whereType<String>()
                .toList()
          : const [],
      classId: json['class_id'] is int
          ? json['class_id']
          : int.tryParse('${json['class_id'] ?? ''}'),
      className: className,
      children: childrenJson is List
          ? childrenJson
                .whereType<Map>()
                .map((child) => Map<String, dynamic>.from(child))
                .toList()
          : const [],
      bkClasses: json['bk_classes'] is List
          ? (json['bk_classes'] as List)
                .whereType<Map>()
                .map((schoolClass) => Map<String, dynamic>.from(schoolClass))
                .toList()
          : const [],
    );
  }

  static String? _roleName(dynamic role) {
    if (role is String) return role;
    if (role is Map) {
      return role['role_name']?.toString() ?? role['name']?.toString();
    }
    return null;
  }

  String get _roleKey =>
      (roleName ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  String _normalizeRole(String role) =>
      role.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool hasAdditionalRole(String role) =>
      additionalRoles.any((value) => _normalizeRole(value) == _normalizeRole(role));

  bool get isGuruBK => _roleKey == 'gurubk';
  bool get isWaliKelas => _roleKey == 'walikelas';
  bool get isOrangTua => _roleKey == 'orangtua' || _roleKey == 'ortu';
  bool get isSiswa => _roleKey == 'siswa';
  bool get isGuru => _roleKey == 'guru' || _roleKey == 'wakakurikulum';
  bool get isWaka => _roleKey == 'wakakurikulum';
  bool get isKepalaSekolah => _roleKey == 'kepalasekolah';
  bool get canMonitorJournals => isKepalaSekolah;
}
