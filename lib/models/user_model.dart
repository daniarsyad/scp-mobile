class UserModel {
  final int id;
  final String username;
  final String fullname;
  final String? email;
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
    this.email,
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
      email: json['email']?.toString(),
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

  bool get isGuruBK => _roleKey == 'gurubk' || hasAdditionalRole('Guru BK');
  bool get isWaliKelas =>
      _roleKey == 'walikelas' || hasAdditionalRole('Wali Kelas');
  bool get isOrangTua => _roleKey == 'orangtua' || _roleKey == 'ortu';
  bool get isSiswa => _roleKey == 'siswa';
  bool get isGuru => _roleKey == 'guru' || _roleKey == 'wakakurikulum';
  bool get isWaka => _roleKey == 'wakakurikulum';
  bool get isKepalaSekolah => _roleKey == 'kepalasekolah';
  bool get canMonitorJournals => isKepalaSekolah;

  List<String> get bkClassNames => bkClasses
      .map((c) => c['class_name']?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  List<int> get bkClassIds => bkClasses
      .map(
        (c) => c['id'] is int
            ? c['id'] as int
            : int.tryParse('${c['id'] ?? ''}') ?? 0,
      )
      .where((id) => id > 0)
      .toList();

  String? get displayClassName {
    if (className != null && className!.trim().isNotEmpty) {
      return className;
    }
    final names = bkClassNames;
    if (names.isEmpty) return null;
    if (names.length <= 2) return names.join(', ');
    return '${names.length} Kelas Binaan';
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? fullname,
    String? email,
    int? roleId,
    String? roleName,
    List<String>? additionalRoles,
    int? classId,
    String? className,
    List<Map<String, dynamic>>? children,
    List<Map<String, dynamic>>? bkClasses,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      additionalRoles: additionalRoles ?? this.additionalRoles,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      children: children ?? this.children,
      bkClasses: bkClasses ?? this.bkClasses,
    );
  }
}
