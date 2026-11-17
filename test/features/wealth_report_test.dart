import 'dart:io';

import 'package:arah/core/domain/money.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/widgets/wealth_report.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id'));

  NetWorth netWorth({bool debts = true}) => NetWorth(
    assets: [
      const WealthItem(
        id: 'p',
        name: 'Portofolio investasi',
        category: WealthCategory.portfolio,
        value: Money.idr(52e6),
        isAutomatic: true,
      ),
      const WealthItem(
        id: 'c',
        name: 'Cash USD',
        category: WealthCategory.cash,
        value: Money.idr(1.65e6),
        entry: ManualEntry(kind: WealthKind.asset, name: 'Cash USD', category: 'cash', amount: 100, currency: 'USD'),
      ),
      const WealthItem(
        id: 'g',
        name: 'Emas Antam',
        category: WealthCategory.gold,
        value: Money.idr(15e6),
        entry: ManualEntry(kind: WealthKind.asset, name: 'Emas Antam', category: 'gold', amount: 10, currency: 'GOLD'),
      ),
    ],
    liabilities: [
      if (debts)
        const WealthItem(
          id: 'k',
          name: 'KPR rumah',
          category: WealthCategory.debt,
          value: Money.idr(80e6),
          entry: ManualEntry(kind: WealthKind.liability, name: 'KPR rumah', category: 'mortgage', amount: 80e6),
        ),
    ],
  );

  final portfolio = Portfolio(
    usdToIdr: 16500,
    priceAsOf: DateTime(2026, 11, 17, 16),
    positions: const [
      Position(
        id: '1',
        symbol: 'BBCA',
        exchange: Exchange.idx,
        quantity: 50,
        avgPrice: Money.idr(8000),
        lastPrice: Money.idr(9000),
        broker: 'Stockbit',
      ),
      Position(id: '2', symbol: 'GOTO', exchange: Exchange.idx, quantity: 10, avgPrice: Money.idr(70)),
      Position(
        id: '3',
        symbol: 'AAPL',
        exchange: Exchange.us,
        quantity: 2.5,
        avgPrice: Money.usd(180),
        lastPrice: Money.usd(210),
      ),
    ],
  );

  test('satu PDF: font app, posisi tanpa harga, emas & dolar, tanpa utang/portofolio', () async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));
    final logo = pw.MemoryImage((await rootBundle.load('assets/images/arah-mark.png')).buffer.asUint8List());
    final bytes = await buildWealthReport(
      netWorth: netWorth(),
      portfolio: portfolio,
      now: DateTime(2026, 11, 17, 20),
      font: font,
      bold: bold,
      logo: logo,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // WEALTH_REPORT_OUT=/path/file.pdf untuk melihat hasilnya.
    final out = Platform.environment['WEALTH_REPORT_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);

    final empty = await buildWealthReport(
      netWorth: netWorth(debts: false),
      portfolio: null,
      now: DateTime(2026, 11, 17),
      font: font,
      bold: bold,
    );
    expect(String.fromCharCodes(empty.take(5)), '%PDF-');
  });
}
