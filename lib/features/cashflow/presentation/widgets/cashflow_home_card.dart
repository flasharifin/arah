import 'package:arah/core/domain/money.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/presentation/bloc/cashflow_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Beranda · "Bulan ini": ditabung & diinvestasikan, tingkat tabungan, pengeluaran, dana darurat.
/// Tekan → Kekayaan › Arus kas. Tidak tampil sampai data siap (Beranda tidak ikut menunggu).
class CashflowHomeCard extends StatelessWidget {
  const CashflowHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.select<CashflowCubit?, CashflowOverview?>((c) => c?.state.data);
    if (data == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final s = data.summary;
    // Persen ekstrem (pemasukan sangat kecil) tidak bermakna: tidak ditampilkan.
    final rate = switch (s.savingsRatePercent) {
      final r? when r >= -100 && r <= 100 => r,
      _ => null,
    };
    final e = data.emergency;
    void open() => context.go('/wealth?tab=arus-kas');
    // Aksi di bawah, bukan di baris judul: teks diperbesar membuat judul + tombol meluber.
    return ModuleCard(
      title: 'Bulan ini · ${DateFormat('MMMM', 'id').format(data.month)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          data.dataSince == null
              ? Text(
                  'Pantau sisa uang tiap bulan tanpa mencatat pengeluaran: atur gaji tetap & pilih Sumber dana saat mencatat transaksi.',
                  style: text.bodySmall,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Ditabung & diinvestasikan', style: text.bodySmall),
                    AmountText(Money.idr(s.saved), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (rate != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: Text('Tingkat tabungan', style: text.bodySmall)),
                          Text('${rate.round()}%', style: text.labelLarge),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (rate / 100).clamp(0, 1),
                          minHeight: 8,
                          color: AppColors.primary,
                          backgroundColor: AppColors.divider,
                          semanticsLabel: 'Tingkat tabungan',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Pengeluaran*',
                            value: AmountText(Money.idr(s.expense), compact: true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            label: 'Dana darurat',
                            value: Text(
                              e.coveredMonths == null
                                  ? '—'
                                  : '${e.coveredMonths!.toStringAsFixed(1).replaceAll('.', ',')} / ${e.targetMonths} bln',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: open,
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Lihat arus kas'),
            ),
          ),
        ],
      ),
    );
  }
}
