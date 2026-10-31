import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/journal/domain/entities/journal.dart';

abstract interface class JournalRemoteDataSource {
  Future<JournalData> load();
  Future<void> saveNote(String day, String note);
}

double _num(Object? v) => num.parse('$v').toDouble(); // Decimal Prisma → string

/// `/api/daily-note?days=30` + `/api/pnl/daily` (31 hari terakhir). Tanggal backend = tengah malam UTC
/// dari `YYYY-MM-DD`, jadi 10 karakter pertama ISO = [dayKey].
class JournalApiDataSource implements JournalRemoteDataSource {
  const JournalApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<JournalData> load() async {
    final results = await Future.wait([
      _api.get('/api/daily-note', query: {'days': '30'}),
      _api.get('/api/pnl/daily'),
      // Rincian per saham opsional: gagal dimuat tidak boleh menggagalkan jurnal.
      _api.get('/api/summary').then<Object?>((v) => v, onError: (_) => null),
    ]);
    return JournalData(
      today: _contributions(results[2] as Map<String, dynamic>?),
      notes: {
        for (final n in (results[0] as List<dynamic>).cast<Map<String, dynamic>>())
          (n['date'] as String).substring(0, 10): n['note'] as String,
      },
      pnl: {
        for (final p in (results[1] as List<dynamic>).cast<Map<String, dynamic>>())
          (p['date'] as String).substring(0, 10): DailyPnl(
            portfolioValue: Money.idr(_num(p['portfolioValue'])),
            pnl: Money.idr(_num(p['pnl'])),
            pnlPercent: _num(p['pnlPct']),
          ),
      },
    );
  }

  /// `dailyRows` /api/summary; persen terhadap nilai porto sebelum perubahan hari ini.
  static List<StockContribution> _contributions(Map<String, dynamic>? summary) {
    if (summary == null) return const [];
    final previousValue = _num(summary['portfolioValueIDR']) - _num(summary['totalDailyChangeIDR']);
    return [
      for (final r in (summary['dailyRows'] as List<dynamic>).cast<Map<String, dynamic>>())
        StockContribution(
          symbol: r['stockCode'] as String,
          change: Money.idr(_num(r['dailyChangeIDR'])),
          contributionPercent: previousValue > 0 ? _num(r['dailyChangeIDR']) / previousValue * 100 : 0,
        ),
    ];
  }

  /// Catatan kosong → server menghapus catatan tanggal itu.
  @override
  Future<void> saveNote(String day, String note) =>
      _api.post('/api/daily-note', body: {'date': day, 'note': note});
}

/// Data ilustrasi S14, catatan disimpan di memori.
class JournalFixtureDataSource implements JournalRemoteDataSource {
  final _notes = <String, String>{};

  @override
  Future<JournalData> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    return JournalData(
      notes: Map.of(_notes),
      today: const [
        StockContribution(symbol: 'BBCA', change: Money.idr(-300000), contributionPercent: -0.3),
        StockContribution(symbol: 'TLKM', change: Money.idr(-150000), contributionPercent: -0.15),
      ],
      pnl: {
        yesterday: const DailyPnl(
          portfolioValue: Money.idr(98450000),
          pnl: Money.idr(-450000),
          pnlPercent: -0.45,
        ),
      },
    );
  }

  @override
  Future<void> saveNote(String day, String note) async =>
      note.isEmpty ? _notes.remove(day) : (_notes[day] = note);
}
