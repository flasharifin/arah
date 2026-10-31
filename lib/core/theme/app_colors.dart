import 'package:flutter/material.dart';

/// Token warna "Arah segar" (artifact redesign 31 Okt 2026): latar hijau sangat muda, kartu putih,
/// hijau hutan untuk aksi & hero, lime sebagai aksen. Semua teks lolos kontras 4.5:1 pada latarnya.
abstract final class AppColors {
  static const background = Color(0xFFF3F6F1);
  static const surface = Color(0xFFFFFFFF);

  /// Isi kartu sekunder di atas kartu putih (tile statistik, baris ringkasan).
  static const surfaceMuted = Color(0xFFF3F6F1);
  static const primary = Color(0xFF173F35);
  static const primarySoft = Color(0xFFE4F0E6);
  static const accent = Color(0xFFDDEFB0);
  static const onAccent = Color(0xFF3B4F12);
  static const text = Color(0xFF12241D);
  static const textSecondary = Color(0xFF52625A);
  static const border = Color(0xFFE2E8DF);
  static const divider = Color(0xFFEEF2EC);

  /// Wadah segmen (Posisi/Kinerja/Riwayat).
  static const segment = Color(0xFFE4EAE1);
  static const positive = Color(0xFF1C7A4C);
  static const negative = Color(0xFFB03A30);
  static const negativeSoft = Color(0xFFFBE7E4);
  static const onNegativeSoft = Color(0xFF8A2C24);
  static const warning = Color(0xFF7A5410);
  static const warningSoft = Color(0xFFFFF4DD);

  /// Teks & kotak di atas hero hijau.
  static const heroMuted = Color(0xFFCFE3D6);
  static const heroTile = Color(0xFF21493E);
  static const heroChip = Color(0xFF2A5246);

  /// Kategori grafik, urutan tetap (palet dataviz tervalidasi): portofolio, pembanding 1–3.
  static const series = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100)];
}
