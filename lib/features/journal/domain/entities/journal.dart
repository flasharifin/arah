import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Kunci hari `YYYY-MM-DD` — sama dengan format tanggal yang dikirim & disimpan backend.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// PnL portofolio satu hari (dicatat cron setiap malam), dalam rupiah.
class DailyPnl extends Equatable {
  const DailyPnl({required this.portfolioValue, required this.pnl, required this.pnlPercent});
  final Money portfolioValue;
  final Money pnl;
  final double pnlPercent;

  @override
  List<Object?> get props => [portfolioValue, pnl, pnlPercent];
}

/// Catatan & PnL ±30 hari terakhir, per [dayKey].
class JournalData extends Equatable {
  const JournalData({required this.notes, required this.pnl});
  final Map<String, String> notes;
  final Map<String, DailyPnl> pnl;

  JournalData withNote(String day, String note) => JournalData(notes: {...notes, day: note}, pnl: pnl);

  @override
  List<Object?> get props => [notes, pnl];
}
