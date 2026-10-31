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

/// Kontribusi satu posisi pada perubahan porto hari ini (harga terakhir vs penutupan sebelumnya).
class StockContribution extends Equatable {
  const StockContribution({required this.symbol, required this.change, required this.contributionPercent});
  final String symbol;

  /// Perubahan nilai posisi hari ini, dalam rupiah.
  final Money change;

  /// Terhadap nilai porto sebelum perubahan hari ini (rumus sama dengan halaman Jurnal web).
  final double contributionPercent;

  @override
  List<Object?> get props => [symbol, change, contributionPercent];
}

/// Catatan & PnL ±30 hari terakhir, per [dayKey], plus rincian per saham untuk hari ini saja
/// (riwayat per saham tidak disimpan server).
class JournalData extends Equatable {
  const JournalData({required this.notes, required this.pnl, this.today = const []});
  final Map<String, String> notes;
  final Map<String, DailyPnl> pnl;
  final List<StockContribution> today;

  /// Catatan kosong = dihapus (sama seperti server).
  JournalData withNote(String day, String note) => JournalData(
    notes: note.isEmpty ? ({...notes}..remove(day)) : {...notes, day: note},
    pnl: pnl,
    today: today,
  );

  @override
  List<Object?> get props => [notes, pnl, today];
}
