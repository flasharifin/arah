import 'package:equatable/equatable.dart';

enum NotificationGroup {
  important('Penting'),
  daily('Harian'),
  report('Laporan');

  const NotificationGroup(this.label);
  final String label;
}

/// Kode sama dengan `NOTIFICATION_TYPES` di backend. [maxPerDay] hanya untuk jenis harian: jumlah push terpisah
/// paling banyak sehari (sinyal = RSI, MACD, dan perubahan skor).
enum NotificationType {
  priceAlert('price_alert', 'Price alert terpenuhi', 'Harga dicek sekali sehari', NotificationGroup.important),
  drawdown('drawdown', 'Drawdown porto', 'Saat melewati ambang di Pengaturan', NotificationGroup.important),
  milestone('milestone', 'Milestone porto', 'Saat nilai porto melewati angka baru', NotificationGroup.important),
  briefing('briefing', 'Briefing pagi', 'Senin–Jumat, sekitar 08.00 WIB', NotificationGroup.daily, maxPerDay: 1),
  dailySummary('daily_summary', 'Ringkasan harian', 'Untung rugi porto, sekitar 00.00 WIB', NotificationGroup.daily, maxPerDay: 1),
  signals('signals', 'Sinyal teknikal', 'RSI, MACD, dan perubahan skor', NotificationGroup.daily, maxPerDay: 3),
  weekly('weekly', 'Laporan mingguan', 'Senin: digest, kinerja posisi, konsentrasi', NotificationGroup.report),
  periodic('periodic', 'Laporan berkala', 'Bulanan, kuartalan, dan tahunan', NotificationGroup.report),
  dca('dca', 'Pengingat DCA', 'Awal bulan', NotificationGroup.report);

  const NotificationType(this.code, this.label, this.hint, this.group, {this.maxPerDay = 0});
  final String code;
  final String label;
  final String hint;
  final NotificationGroup group;
  final int maxPerDay;

  static NotificationType fromCode(String? code) => values.firstWhere((t) => t.code == code, orElse: () => periodic);
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.isRead = false,
  });

  final String id;
  final NotificationType type;
  final String title;

  /// Isi lengkap, baris per baris; push di HP hanya versi terpotong.
  final String body;
  final DateTime createdAt;
  final String? route;
  final bool isRead;

  AppNotification read() =>
      AppNotification(id: id, type: type, title: title, body: body, createdAt: createdAt, route: route, isRead: true);

  @override
  List<Object?> get props => [id, type, title, body, createdAt, route, isRead];
}

enum NotificationMode {
  separate('separate'),
  combined('combined');

  const NotificationMode(this.code);
  final String code;

  static NotificationMode fromCode(String? code) => values.firstWhere((m) => m.code == code, orElse: () => separate);
}

class NotificationPrefs extends Equatable {
  const NotificationPrefs({this.mode = NotificationMode.separate, this.disabled = const {}});

  final NotificationMode mode;
  final Set<NotificationType> disabled;

  bool isEnabled(NotificationType type) => !disabled.contains(type);

  NotificationPrefs withMode(NotificationMode mode) => NotificationPrefs(mode: mode, disabled: disabled);

  NotificationPrefs withType(NotificationType type, {required bool enabled}) => NotificationPrefs(
    mode: mode,
    disabled: enabled ? (disabled.difference({type})) : {...disabled, type},
  );

  /// Push rutin paling banyak di hari biasa, tanpa yang penting. Mode gabung selalu satu push pagi.
  int get maxDailyPushes {
    final daily = NotificationType.values.where((t) => t.group == NotificationGroup.daily && isEnabled(t));
    if (mode == NotificationMode.combined) return daily.isEmpty ? 0 : 1;
    return daily.fold(0, (sum, t) => sum + t.maxPerDay);
  }

  @override
  List<Object?> get props => [mode, disabled];
}
