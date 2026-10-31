import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/letter/domain/entities/investor_letter.dart';
import 'package:arah/features/letter/presentation/bloc/letter_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S15 — Surat investor: ringkasan 7 hari terakhir dengan periode eksplisit.
class InvestorLetterPage extends StatelessWidget {
  const InvestorLetterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LetterCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Surat investor')),
      body: BlocBuilder<LetterCubit, ViewState<InvestorLetter>>(
        builder: (context, state) => ViewStateBuilder<InvestorLetter>(
          state: state,
          onRetry: cubit.load,
          builder: (context, l) {
            final text = Theme.of(context).textTheme;
            Widget section(String title, List<Widget> children) => PageBody(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: text.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      ...children,
                    ],
                  ),
                ),
              ),
            );
            Widget movers(List<Mover> list) => Column(
              children: [
                for (final m in list)
                  InfoRow(
                    label: '${m.symbol} · ${m.exchange}',
                    value: PnlText(percent: m.percent),
                  ),
              ],
            );
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: [
                  PageBody(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Text('Periode ${Fmt.date(l.weekStart)} – ${Fmt.date(l.weekEnd)}', style: text.bodySmall),
                    ),
                  ),
                  section('Portofolio minggu ini', [
                    InfoRow(label: 'Nilai terakhir', value: AmountText(l.portfolioValue)),
                    InfoRow(
                      label: 'Perubahan 7 hari',
                      value: PnlText(amount: l.weeklyChange, percent: l.weeklyChangePercent),
                    ),
                    InfoRow(
                      label: 'IHSG',
                      value: PnlText(percent: l.ihsgPercent),
                    ),
                    InfoRow(
                      label: 'S&P 500',
                      value: PnlText(percent: l.sp500Percent),
                    ),
                    InfoRow(label: 'Tertinggi', value: AmountText(l.weekHigh)),
                    InfoRow(label: 'Terendah', value: AmountText(l.weekLow)),
                    Text('Perubahan nilai termasuk setoran/penarikan modal minggu ini.', style: text.bodySmall),
                  ]),
                  if (l.topGainers.isNotEmpty || l.topLosers.isNotEmpty)
                    section('Posisi vs harga rata-rata beli', [
                      Text(
                        'Selisih harga terakhir dengan harga rata-rata beli, bukan return minggu ini.',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      movers(l.topGainers),
                      if (l.topLosers.isNotEmpty) ...[const Divider(), movers(l.topLosers)],
                    ]),
                  section('Penjualan minggu ini', [
                    if (l.sales.isEmpty) Text('Tidak ada penjualan.', style: text.bodySmall),
                    for (final s in l.sales)
                      InfoRow(
                        label: '${s.symbol} · ${Fmt.date(s.date)}',
                        value: PnlText(amount: s.realizedPnl),
                      ),
                  ]),
                  section('Dividen minggu ini', [
                    if (l.dividends.isEmpty) Text('Tidak ada dividen dibayar.', style: text.bodySmall),
                    for (final d in l.dividends)
                      InfoRow(
                        label: '${d.symbol} · ${d.date == null ? 'tanggal belum ditentukan' : Fmt.date(d.date)}',
                        value: AmountText(d.received),
                      ),
                  ]),
                  PageBody(child: Text('${l.positionCount} posisi aktif.', style: text.bodySmall)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
