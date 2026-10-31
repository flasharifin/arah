import 'package:arah/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({required super.id, required super.name, required super.email});

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      UserModel(id: json['id'] as String, name: json['name'] as String? ?? '', email: json['email'] as String);
}

class AuthSession {
  const AuthSession({required this.user, required this.accessToken, required this.refreshToken});

  final UserModel user;
  final String accessToken;
  final String refreshToken;
}
