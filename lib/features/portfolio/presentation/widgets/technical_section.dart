import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';
import 'package:arah/features/portfolio/presentation/bloc/technical_cubit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

typedef _Line = ({String label, Color color, List<double?> values, double width});

/// Teknikal posisi (Tahap 1): sinyal, grafik harga + EMA, bacaan 4 indikator, grafik RSI.
/// Data harian dari cron pagi — informasi, bukan saran beli/jual.
class TechnicalSection extends StatefulWidget {
  const TechnicalSection({super.key});

  @override
  State<TechnicalSection> createState() => _TechnicalSectionState();
}

class _TechnicalSectionState extends State<TechnicalSection> {
  static const _periods = [(label: '3B', days: 91), (label: '6B', days: 182), (label: '1T', days: 366)];
  var _days = 182;

  /// Minimal hari bursa supaya grafik & indikator bermakna.
  static const _minPoints = 20;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TechnicalCubit>();
    final text = Theme.of(context).textTheme;
    return BlocBuilder<TechnicalCubit, ViewState<TechnicalAnalysis>>(
      builder: (context, state) => ViewStateBuilder<TechnicalAnalysis>(
        state: state,
        onRetry: cubit.load,
        skeleton: const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        builder: (context, ta) {
          final last = ta.last;
          if (last == null || ta.points.length < _minPoints) {
            return AppCard(
              child: Text(
                'Data teknikal belum cukup. Harga harian dicatat setiap pagi hari kerja; '
                'grafik muncul setelah ±$_minPoints hari bursa.',
                style: text.bodySmall,
              ),
            );
          }
          final from = last.date.subtract(Duration(days: _days));
          final points = ta.points.where((p) => !p.date.isBefore(from)).toList();
          final readings = [
            trendReading(last),
            rsiReading(last),
            macdReading(last, ta.signal),
            volumeReading(last),
          ].whereType<TaReading>().toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ta.signal case final s?) _SignalCard(signal: s),
              const SizedBox(height: AppSpacing.md),
              ChoiceChipBar<int>(
                options: [for (final p in _periods) p.days],
                selected: _days,
                labelOf: (d) => _periods.firstWhere((p) => p.days == d).label,
                onSelected: (d) => setState(() => _days = d),
              ),
              const SizedBox(height: AppSpacing.md),
              ModuleCard(
                title: 'Harga & tren',
                child: _TaChart(
                  dates: [for (final p in points) p.date],
                  lines: [
                    (label: 'Harga', color: AppColors.series[0], values: [for (final p in points) p.close], width: 2.5),
                    (label: 'EMA20', color: AppColors.series[1], values: [for (final p in points) p.ema20], width: 1.5),
                    (label: 'EMA50', color: AppColors.series[2], values: [for (final p in points) p.ema50], width: 1.5),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ModuleCard(
                title: 'Bacaan indikator',
                trailing: Text(Fmt.date(last.date), style: text.bodySmall),
                child: Column(children: [for (final r in readings) _ReadingRow(reading: r)]),
              ),
              const SizedBox(height: AppSpacing.md),
              ModuleCard(
                title: 'RSI (14)',
                child: _TaChart(
                  dates: [for (final p in points) p.date],
                  lines: [
                    (label: 'RSI', color: AppColors.primary, values: [for (final p in points) p.rsi], width: 2),
                  ],
                  minY: 0,
                  maxY: 100,
                  guides: const [30, 70],
                  height: 140,
                  interval: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Indikator dihitung dari harga penutupan harian (bukan real-time). Informasi, bukan saran beli/jual.',
                style: text.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});
  final TaSignal signal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = signal.score >= 4
        ? AppColors.positive
        : signal.score <= 2
        ? AppColors.negative
        : AppColors.textSecondary;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sinyal teknikal', style: text.bodySmall),
                Text(
                  signal.label,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: tone),
                ),
                Text('Diperbarui ${Fmt.dateTime(signal.updatedAt)}', style: text.bodySmall),
                if (signal.fearGreed case final fg?) Text('Fear & Greed kripto: $fg', style: text.bodySmall),
              ],
            ),
          ),
          Semantics(
            label: 'Skor ${signal.score} dari 5',
            child: ExcludeSemantics(
              child: Text(
                '${signal.score}/5',
                style: text.headlineSmall?.copyWith(color: tone, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading});
  final TaReading reading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = switch (reading.tone) {
      TaTone.positive => AppColors.positive,
      TaTone.negative => AppColors.negative,
      TaTone.neutral => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(reading.title, style: text.labelLarge)),
                    const SizedBox(width: AppSpacing.sm),
                    // Nilai rata kanan; fleksibel supaya teks besar turun baris, bukan meluber.
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          reading.value,
                          textAlign: TextAlign.end,
                          style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(reading.meaning, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafik garis harian (fl_chart). `null` = celah (indikator belum terisi).
class _TaChart extends StatelessWidget {
  const _TaChart({
    required this.dates,
    required this.lines,
    this.minY,
    this.maxY,
    this.guides = const [],
    this.height = 200,
    this.interval,
  });

  final List<DateTime> dates;
  final List<_Line> lines;
  final double? minY;
  final double? maxY;

  /// Garis bantu horizontal (mis. RSI 30/70).
  final List<double> guides;
  final double height;

  /// Jarak label sumbu Y (mis. 20 untuk RSI); `null` = otomatis.
  final double? interval;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final axis = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    final label = DateFormat('d MMM', 'id');
    final step = (dates.length / 4).ceilToDouble().clamp(1, double.infinity).toDouble();
    final number = NumberFormat.compact(locale: 'id');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  for (final l in lines)
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < l.values.length; i++)
                          l.values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), l.values[i]!),
                      ],
                      color: l.color,
                      barWidth: l.width,
                      dotData: const FlDotData(show: false),
                    ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    for (final g in guides)
                      HorizontalLine(y: g, color: AppColors.textSecondary, strokeWidth: 1, dashArray: [4, 4]),
                  ],
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: interval,
                      minIncluded: false,
                      maxIncluded: false,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(number.format(v), style: axis),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: step,
                      maxIncluded: false,
                      getTitlesWidget: (v, meta) => v >= dates.length
                          ? const SizedBox.shrink()
                          : SideTitleWidget(
                              meta: meta,
                              child: Text(label.format(dates[v.toInt()]), style: axis),
                            ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.text,
                    fitInsideHorizontally: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${s.barIndex == 0 ? '${label.format(dates[s.x.toInt()])}\n' : ''}'
                          '${lines[s.barIndex].label} ${number.format(s.y)}',
                          const TextStyle(color: AppColors.surface, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (lines.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              for (final l in lines)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 4,
                      decoration: BoxDecoration(color: l.color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(l.label, style: text.bodySmall),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
