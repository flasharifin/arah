import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Kunci app dengan sidik jari/Face ID; PIN/pola perangkat jadi cadangan saat biometrik terkunci.
/// Preferensi di secure storage, jadi ikut terhapus saat logout (`TokenStorage.clear` = deleteAll).
class BiometricLock {
  BiometricLock(this._storage, [LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const _key = 'biometric_lock';

  /// Nama & ikon untuk UI: Face ID di iOS, sidik jari di Android.
  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static String get name => _isIOS ? 'Face ID' : 'sidik jari';
  static IconData get icon => _isIOS ? Icons.face : Icons.fingerprint;

  /// Perangkat punya biometrik yang sudah didaftarkan.
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (e) {
      debugPrint('BiometricLock.isAvailable: $e');
      return false;
    }
  }

  Future<bool> isEnabled() async => await _storage.read(key: _key) == 'true';

  Future<void> setEnabled(bool enabled) =>
      enabled ? _storage.write(key: _key, value: 'true') : _storage.delete(key: _key);

  /// `false` jika dibatalkan atau gagal; pengguna bisa coba lagi atau masuk dengan password.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(localizedReason: 'Buka Arah');
    } on LocalAuthException catch (e) {
      debugPrint('BiometricLock.authenticate: $e');
      return false;
    }
  }
}
