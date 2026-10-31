import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/presentation/widgets/currency_totals.dart';
import 'package:arah/features/portfolio/presentation/widgets/position_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  // Angka panjang (pecahan kripto, ratusan juta, PnL turun) di layar 360 px.
  const crypto = Position(
    id: 'x',
    symbol: 'FLOQQ',
    exchange: Exchange.crypto,
    broker: 'Indodax',
    quantity: 0.01784512,
    avgPrice: Money.usd(1234567.89),
    lastPrice: Money.usd(987654.32),
  );
  const big = Position(
    id: 'y',
    symbol: 'BBCA',
    exchange: Exchange.idx,
    broker: 'Stockbit',
    sector: 'Keuangan',
    quantity: 12345,
    avgPrice: Money.idr(9875),
    lastPrice: Money.idr(8150),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => PrivacyCubit(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [child]),
          ),
        ),
      ),
    );
  }

  testWidgets('kartu posisi: jumlah pecahan & nominal besar tampil utuh, PnL bertumpuk tanpa overflow', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          PositionCard(position: crypto),
          PositionCard(position: big),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('0,01784512 unit'), findsOneWidget); // 8 desimal, tidak terpotong "…"
    expect(find.text(Fmt.money(big.unrealizedPnl, signed: true)), findsOneWidget); // nominal di baris sendiri
    expect(find.text(Fmt.percent(big.unrealizedPercent)), findsOneWidget); // persen di baris kedua
  });

  testWidgets('total per mata uang: dua kotak sama tinggi', (tester) async {
    await pump(tester, const CurrencyTotals(portfolio: Portfolio(positions: [crypto, big]), tiles: true));
    expect(tester.takeException(), isNull);
    final boxes = find.descendant(of: find.byType(IntrinsicHeight), matching: find.byType(Container));
    final heights = {for (final e in boxes.evaluate().take(2)) (e.renderObject! as RenderBox).size.height};
    expect(heights, hasLength(1));
  });
}
