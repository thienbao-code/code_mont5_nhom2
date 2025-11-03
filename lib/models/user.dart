class User {
  final int? id;
  final String email;
  final String password;
  final String role;

  User({
    this.id,
    required this.email,
    required this.password,
    this.role = 'user',
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'email': email, 'password': password, 'role': role};
  }

  static User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      password: map['password'],
      role: map['role'],
    );
  }

  // Thêm method copyWith
  User copyWith({int? id, String? email, String? password, String? role}) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }

  // Thêm method toString để dễ debug
  @override
  String toString() {
    return 'User(id: $id, email: $email, role: $role)';
  }
}
