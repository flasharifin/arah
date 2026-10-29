import 'package:arah/core/error/result.dart';
import 'package:arah/features/auth/domain/entities/user.dart';

abstract interface class AuthRepository {
  /// `null` jika belum ada sesi tersimpan.
  Future<Result<User?>> currentUser();

  Future<Result<User>> signIn({required String email, required String password});

  /// Mencabut token dan membersihkan data akun lokal.
  Future<void> signOut();

  /// Hapus akun + semua data di server (konfirmasi password), lalu bersihkan data lokal.
  Future<Result<void>> deleteAccount({required String password});

  Future<Result<void>> requestPasswordReset({required String email});

  Future<Result<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
