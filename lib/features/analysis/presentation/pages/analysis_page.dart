import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';
import 'package:arah/features/analysis/presentation/bloc/analysis_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S12 — Analisis risiko: Ringkasan / Korelasi / Stress test (angka dari `/api/analysis/risk`).
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AnalysisCubit>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analisis risiko'),
          bottom: const SegmentedTabBar(tabs: ['Ringkasan', 'Korelasi', 'Stress test']),
        ),
        body: BlocBuilder<AnalysisCubit, ViewState<RiskAnalysis>>(
          builder: (context, state) => ViewStateBuilder<RiskAnalysis>(
            state: state,
            onRetry: cubit.load,
            isEmpty: (a) => a.positions.isEmpty,
            empty: const EmptyView(
              icon: Icons.shield_outlined,
              title: 'Belum ada posisi',
              message: 'Analisis risiko dihitung dari posisi di Portofolio.',
            ),
            builder: (context, a) => TabBarView(
              children: [
                _SummaryTab(analysis: a),
                _CorrelationTab(analysis: a),
                _StressTab(analysis: a),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _note(BuildContext context, String text) => PageBody(
  child: Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  ),
);

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.analysis});
  final RiskAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = analysis.largest!;
    final positions = [...analysis.positions]..sort((a, b) => b.weight.compareTo(a.weight));
    final withRisk = positions.where((p) => p.volatility != null).toList();
    final noHistory = positions.where((p) => p.volatility == null).map((p) => p.symbol).toList();
    const gap = SizedBox(height: AppSpacing.md);
    Widget levelText(String value, String level) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(
          level,
          style: text.labelSmall?.copyWith(color: level == 'Rendah' ? AppColors.positive : AppColors.warning),
        ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (analysis.portfolio case final risk?) ...[_PortfolioRiskCard(risk: risk), gap],
              ModuleCard(
                title: 'Konsentrasi',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${top.symbol} = ${Fmt.percent(top.weight, signed: false)} dari nilai portofolio'
                      '${top.weight >= 40 ? ' — porsi besar di satu aset.' : '.'}',
                      style: text.labelLarge?.copyWith(color: top.weight >= 40 ? AppColors.warning : null),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final p in positions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            SizedBox(width: 56, child: Text(p.symbol, style: text.labelLarge)),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (p.weight / 100).clamp(0, 1),
                                  minHeight: 10,
                                  color: AppColors.series[0],
                                  backgroundColor: AppColors.divider,
                                  semanticsLabel: 'Bobot ${p.symbol}',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text(
                                Fmt.percent(p.weight, signed: false),
                                textAlign: TextAlign.right,
                                style: text.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text('Bobot = nilai pasar, atau modal bila harga belum ada.', style: text.bodySmall),
                  ],
                ),
              ),
              gap,
              ModuleCard(
                title: 'Risiko per posisi · 1 bulan',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (withRisk.isNotEmpty)
                      Row(
                        children: [
                          Expanded(child: Text('Posisi', style: text.labelSmall)),
                          SizedBox(
                            width: 92,
                            child: Text('Volatilitas', textAlign: TextAlign.right, style: text.labelSmall),
                          ),
                          SizedBox(
                            width: 92,
                            child: Text('Max drawdown', textAlign: TextAlign.right, style: text.labelSmall),
                          ),
                        ],
                      ),
                    for (final p in withRisk)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.symbol, style: text.titleSmall),
                                  Text(p.exchange, style: text.bodySmall),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 92,
                              child: levelText(Fmt.percent(p.volatility, signed: false), volatilityLevel(p.volatility)),
                            ),
                            SizedBox(
                              width: 92,
                              child: levelText(Fmt.percent(p.maxDrawdown, signed: false), drawdownLevel(p.maxDrawdown)),
                            ),
                          ],
                        ),
                      ),
                    if (noHistory.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          '${noHistory.join(', ')}: histori harga belum cukup — dihitung setelah ada data, '
                          'bukan dianggap nol.',
                          style: text.bodySmall,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Volatilitas = simpangan baku return harian × √252 (tahunan). Max drawdown = penurunan '
                      'terdalam dari puncak dalam periode itu.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CorrelationTab extends StatelessWidget {
  const _CorrelationTab({required this.analysis});
  final RiskAnalysis analysis;

  static String _label(double? r) => switch (r) {
    null => 'tidak terhitung',
    > 0.7 => 'sangat searah',
    > 0.4 => 'searah',
    > 0.1 => 'sedikit searah',
    > -0.1 => 'tidak berhubungan',
    > -0.4 => 'sedikit berlawanan',
    _ => 'berlawanan',
  };

  @override
  Widget build(BuildContext context) {
    if (analysis.correlations.isEmpty) {
      return const EmptyView(
        icon: Icons.hub_outlined,
        title: 'Data historis belum cukup',
        message: 'Perlu minimal 2 aset dengan 5 hari perdagangan yang sama.',
      );
    }
    final pairs = [...analysis.correlations]..sort((x, y) => (y.r ?? -2).compareTo(x.r ?? -2));
    String name(String key) => key.split(':').first;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        _note(
          context,
          'Korelasi return harian ${analysis.historyDays} hari perdagangan terakhir yang sama. +1 = selalu searah, '
          '−1 = selalu berlawanan, 0 = tidak berhubungan. Diversifikasi yang baik punya korelasi rendah.',
        ),
        if (_Heatmap.fits(analysis)) ...[
          PageBody(
            child: ExcludeSemantics(child: _Heatmap(analysis: analysis)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else
          _note(
            context,
            'Heatmap ditampilkan untuk maksimal ${_Heatmap.maxAssets} aset; lihat daftar pasangan di bawah.',
          ),
        for (final c in pairs)
          PageBody(
            child: InfoRow(
              label: '${name(c.a)} – ${name(c.b)}',
              value: Text(c.r == null ? '—  · ${_label(null)}' : '${c.r!.toStringAsFixed(2)} · ${_label(c.r)}'),
            ),
          ),
      ],
    );
  }
}

class _StressTab extends StatefulWidget {
  const _StressTab({required this.analysis});
  final RiskAnalysis analysis;

  @override
  State<_StressTab> createState() => _StressTabState();
}

class _StressTabState extends State<_StressTab> {
  late StressScenario _scenario = widget.analysis.scenarios.first;
  final _custom = {
    'IDX': TextEditingController(text: '-10'),
    'US': TextEditingController(text: '-8'),
    'CRYPTO': TextEditingController(text: '-15'),
  };

  @override
  void initState() {
    super.initState();
    for (final c in _custom.values) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Input kustom dibatasi −100..100% supaya nilai tidak negatif.
  double _drop(String key) =>
      (double.tryParse(_custom[key]!.text.trim().replaceAll(',', '.')) ?? 0).clamp(-100, 100).toDouble();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final drops = _scenario.isCustom ? (idx: _drop('IDX'), us: _drop('US'), crypto: _drop('CRYPTO')) : _scenario.drops;
    final r = stressImpact(widget.analysis.positions, drops);
    final delta = Money.idr(r.after.amount - r.before.amount);
    final rows = [...r.rows]..sort((a, b) => a.delta.amount.compareTo(b.delta.amount));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        _note(
          context,
          'Simulasi: semua aset di satu bursa dianggap turun bersamaan. Acuan = nilai pasar saat ini '
          '(atau modal bila harga belum ada). Hasilnya estimasi, bukan ramalan.',
        ),
        PageBody(
          child: ChoiceChipBar<StressScenario>(
            options: widget.analysis.scenarios,
            selected: _scenario,
            labelOf: (s) => s.label,
            onSelected: (s) => setState(() => _scenario = s),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_scenario.isCustom)
          PageBody(
            child: Row(
              children: [
                for (final (i, e) in _custom.entries.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: '${e.key == 'CRYPTO' ? 'Crypto' : e.key} (%)',
                      controller: e.value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          _note(
            context,
            '${_scenario.description}: IDX ${Fmt.percent(drops.idx)}, US ${Fmt.percent(drops.us)}, '
            'Crypto ${Fmt.percent(drops.crypto)}.',
          ),
        const SizedBox(height: AppSpacing.md),
        PageBody(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Simulasi · ${_scenario.label}', style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                InfoRow(label: 'Nilai sekarang', value: AmountText(r.before)),
                InfoRow(label: 'Setelah skenario', value: AmountText(r.after)),
                InfoRow(
                  label: 'Dampak',
                  value: PnlText(
                    amount: delta,
                    percent: r.before.amount == 0 ? 0 : delta.amount / r.before.amount * 100,
                  ),
                ),
                const Divider(height: AppSpacing.xxl),
                for (final row in rows)
                  InfoRow(
                    label: '${row.position.symbol} · ${row.position.exchange}',
                    value: PnlText(amount: row.delta),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sharpe & beta portofolio (S12 "jika cukup data"): kosong → penjelasan, bukan angka nol.
class _PortfolioRiskCard extends StatelessWidget {
  const _PortfolioRiskCard({required this.risk});
  final PortfolioRisk risk;

  static String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2).replaceAll('.', ',');
  static String _meaning(double? beta) => beta == null ? 'Data kurang' : betaMeaning(beta);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enough = risk.sharpe != null || risk.betaIhsg != null || risk.betaSp500 != null || risk.betaBtc != null;
    final betas = [('IHSG', risk.betaIhsg), ('S&P 500', risk.betaSp500), ('BTC', risk.betaBtc)];
    return ModuleCard(
      title: 'Return vs risiko portofolio',
      trailing: Text('${risk.days} hari PnL', style: text.bodySmall),
      child: !enough
          ? Text(
              'Butuh minimal 20 hari catatan PnL harian (sekarang ${risk.days} hari). PnL dicatat setiap malam.',
              style: text.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md + 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sharpe ratio', style: text.labelLarge?.copyWith(color: Colors.white)),
                            // Dua baris disengaja: tidak patah di tengah "> 1".
                            Text(
                              'Asumsi bebas risiko ${Fmt.percent(risk.riskFreePercent, signed: false)}/thn',
                              style: text.bodySmall?.copyWith(color: AppColors.heroMuted),
                            ),
                            Text(
                              'Di atas 1 tergolong baik',
                              style: text.bodySmall?.copyWith(color: AppColors.heroMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _fmt(risk.sharpe),
                        style: AppTypography.amountLarge.copyWith(color: Colors.white, fontSize: 28),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Beta terhadap', style: text.labelMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Tiga kotak butuh ±96 px per kotak dengan teks normal. Teks diperbesar / layar sempit →
                    // daftar baris supaya label, angka & arti tidak terjepit atau meluber.
                    final asList = MediaQuery.textScalerOf(context).scale(16) > 20 || constraints.maxWidth < 300;
                    if (asList) {
                      return Column(
                        key: const ValueKey('beta-list'),
                        children: [
                          for (final (i, (name, beta)) in betas.indexed)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.divider)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: text.labelLarge),
                                        Text(_meaning(beta), style: text.bodySmall),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(_fmt(beta), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                        ],
                      );
                    }
                    // Kotak sama tinggi: label pendek (nama benchmark) satu baris, angka & arti sejajar.
                    return IntrinsicHeight(
                      key: const ValueKey('beta-tiles'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, (name, beta)) in betas.indexed) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: StatTile(label: name, value: Text(_fmt(beta)), caption: _meaning(beta)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Dari ${risk.days} hari catatan PnL terakhir (maks 1 tahun). Beta 1 = bergerak sebesar benchmark, '
                  '< 1 lebih tenang, > 1 lebih liar.',
                  style: text.bodySmall,
                ),
              ],
            ),
    );
  }
}

/// Heatmap korelasi: warna divergen (oranye berlawanan · abu netral · biru searah), angka selalu tertulis.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.analysis});
  final RiskAnalysis analysis;

  static const maxAssets = 8; // ±35 px per sel di layar 360 px
  static const _negative = Color(0xFFEB6834);
  static const _positive = Color(0xFF2A78D6);
  static const _neutral = Color(0xFFEEF1EC);

  static List<String> _keys(RiskAnalysis a) {
    final inPairs = {
      for (final c in a.correlations) ...[c.a, c.b],
    };
    return [
      for (final p in a.positions)
        if (inPairs.contains(p.key)) p.key,
    ];
  }

  static bool fits(RiskAnalysis a) => _keys(a).length <= maxAssets;

  // Intensitas dibatasi 0,7 supaya teks gelap tetap terbaca di semua sel.
  static Color _color(double? r) =>
      r == null ? _neutral : Color.lerp(_neutral, r >= 0 ? _positive : _negative, (r.abs() * 0.7).clamp(0, 0.7))!;

  @override
  Widget build(BuildContext context) {
    final keys = _keys(analysis);
    final r = <String, double?>{
      for (final c in analysis.correlations) ...{'${c.a}|${c.b}': c.r, '${c.b}|${c.a}': c.r},
    };
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.text);
    String name(String k) => k.split(':').first;
    Widget cell(String a, String b) {
      final v = a == b ? 1.0 : r['$a|$b'];
      return Container(
        height: 36,
        margin: const EdgeInsets.all(1),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _color(v), borderRadius: BorderRadius.circular(4)),
        child: Text(v == null ? '—' : (a == b ? '1' : v.toStringAsFixed(2)), style: style),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {0: IntrinsicColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final k in keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(name(k), style: style, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
            for (final a in keys)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text(name(a), style: style),
                  ),
                  for (final b in keys) cell(a, b),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Wrap: legenda turun baris di layar sempit / teks besar.
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (label, color) in [('Berlawanan', _negative), ('Netral', _neutral), ('Searah', _positive)])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
