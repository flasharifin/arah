import 'dart:math' as math;

import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef _Total = ({Currency currency, ({Money value, Money pnl, double? percent, int count}) t});

/// Nilai & unrealized PnL per mata uang (IDR dan USD tidak dijumlah) + catatan posisi tanpa harga.
/// [tiles] = kotak berdampingan sama tinggi (Portofolio); selain itu baris (Beranda).
class CurrencyTotals extends StatelessWidget {
  const CurrencyTotals({super.key, required this.portfolio, this.tiles = false});

  final Portfolio portfolio;
  final bool tiles;

  static String _label(Currency c) => c == Currency.idr ? 'Rupiah' : 'Dolar AS';

  /// Ukuran huruf terbesar (≤ ukuran [style]) supaya semua [texts] muat satu baris di [width]:
  /// kotak berdampingan memakai ukuran yang sama walau salah satu nominalnya panjang.
  static TextStyle _shared(BuildContext context, Iterable<String> texts, TextStyle style, double width) {
    final base = style.fontSize ?? 14;
    var size = base;
    for (final t in texts) {
      final painter = TextPainter(
        // Gaya yang sama dengan AmountText/PnlText (angka tabular lebih lebar dari angka biasa).
        text: TextSpan(text: t, style: AppTypography.amount.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > width) size = math.min(size, base * width / painter.width);
    }
    return style.copyWith(fontSize: math.max(size, 10));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totals = <_Total>[
      for (final c in Currency.values)
        if (portfolio.pricedTotals(c) case final t?) (currency: c, t: t),
    ];
    final unpriced = portfolio.unpriced;
    final valueStyle = text.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    // Nominal satu baris, mengecil bila panjang (ratusan juta / US$ ribuan) — ukuran huruf sama di semua kotak.
    Widget value(Money m, Alignment a) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: a,
      child: AmountText(m, style: valueStyle),
    );

    Widget tile(_Total e, TextStyle valueStyle, TextStyle pnlStyle) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nilai · ${_label(e.currency)}', style: text.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(e.t.value, style: valueStyle),
          ),
          const SizedBox(height: AppSpacing.xs),
          PnlText(
            amount: e.t.pnl,
            percent: e.t.percent,
            stacked: true,
            align: CrossAxisAlignment.start,
            style: pnlStyle,
          ),
        ],
      ),
    );

    Widget row(_Total e) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_label(e.currency)} · ${e.t.count} posisi', style: text.bodySmall),
                value(e.t.value, Alignment.centerLeft),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: PnlText(amount: e.t.pnl, percent: e.t.percent, stacked: true, style: text.labelLarge),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tiles)
          LayoutBuilder(
            builder: (context, constraints) {
              final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
              final n = math.max(totals.length, 1);
              // Lebar isi kotak: dikurangi jarak antarkotak, padding & border.
              final inner = (constraints.maxWidth - AppSpacing.md * (n - 1)) / n - AppSpacing.md * 2 - 2;
              final vStyle = _shared(
                context,
                [for (final e in totals) hidden ? Fmt.hidden : Fmt.money(e.t.value)],
                valueStyle!,
                inner,
              );
              final pStyle = _shared(
                context,
                [for (final e in totals) hidden ? Fmt.hidden : Fmt.money(e.t.pnl, signed: true)],
                text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
                inner,
              );
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, e) in totals.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.md),
                      Expanded(child: tile(e, vStyle, pStyle)),
                    ],
                  ],
                ),
              );
            },
          )
        else
          for (final e in totals)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: row(e),
            ),
        if (unpriced.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${unpriced.map((p) => p.symbol).join(', ')} belum punya harga terbaru — tidak masuk total di atas.',
              style: text.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ],
    );
  }
}
