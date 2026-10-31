import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Bagian `/api/settings` yang diubah di layar Pengaturan. Target kekayaan diubah di Kekayaan → Target.
class AccountSettings extends Equatable {
  const AccountSettings({required this.wealthTarget, required this.drawdownThreshold, this.telegramChatId});

  final Money wealthTarget;

  /// Alert drawdown dikirim bila porto turun melewati persen ini (1–100).
  final double drawdownThreshold;

  /// `null` = notifikasi Telegram tidak aktif.
  final String? telegramChatId;

  @override
  List<Object?> get props => [wealthTarget, drawdownThreshold, telegramChatId];
}
