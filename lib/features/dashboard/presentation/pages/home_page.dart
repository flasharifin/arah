import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/currency_totals.dart';
import 'package:arah/features/portfolio/presentation/widgets/purchase_form.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S02 — Beranda: kekayaan bersih → aksi cepat → modul target, portofolio, alokasi, briefing.
/// Modul membaca bloc sesi yang sudah dimuat shell (Portofolio, Kekayaan); tidak ada request tambahan.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static String _greeting(DateTime now) => switch (now.hour) {
    < 11 => 'Selamat pagi',
    < 15 => 'Selamat siang',
    < 18 => 'Selamat sore',
    _ => 'Selamat malam',
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(DateTime.now()), style: text.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            // Mengecil bila sempit (tombol header lebar / teks besar), tidak terpotong.
            const FittedBox(fit: BoxFit.scaleDown, child: Text('Ringkasan keuanganmu')),
          ],
        ),
        actions: [
          IconButton.outlined(
            tooltip: hidden ? 'Tampilkan nominal' : 'Sembunyikan nominal',
            onPressed: context.read<PrivacyCubit>().toggle,
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              backgroundColor: AppColors.surface,
              minimumSize: const Size.square(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          const AskAiButton(),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: BlocBuilder<DashboardCubit, ViewState<DashboardSummary>>(
        builder: (context, state) => ViewStateBuilder<DashboardSummary>(
          state: state,
          onRetry: cubit.load,
          builder: (context, data) => RefreshIndicator(
            onRefresh: () async {
              context.read<PortfolioBloc>().add(const PortfolioRequested());
              await Future.wait([cubit.load(), context.read<NetWorthCubit>().load()]);
            },
            child: ListView(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxl),
              children: [PageBody(child: _HomeContent(data: data))],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data});

  final DashboardSummary data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final portfolio = context.select<PortfolioBloc, Portfolio?>((b) => b.state.data.data);
    final netWorth = context.select<NetWorthCubit, NetWorth?>((c) => c.state.data);
    final goal = netWorth?.goal;
    const gap = SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NetWorthHero(data: data),
        gap,
        Row(
          children: [
            for (final (i, a) in [
              (icon: Icons.add, label: 'Catat beli', onTap: () => showPurchaseForm(context), lime: true),
              (
                icon: Icons.leaderboard_outlined,
                label: 'Sinyal',
                onTap: () => context.go('/home/technical-rank'),
                lime: false,
              ),
              (
                icon: Icons.show_chart,
                label: 'Kinerja',
                onTap: () => context.go('/portfolio?tab=kinerja'),
                lime: false,
              ),
              (icon: Icons.edit_note_outlined, label: 'Jurnal', onTap: () => context.go('/more/journal'), lime: false),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickAction(icon: a.icon, label: a.label, onTap: a.onTap, highlight: a.lime),
              ),
            ],
          ],
        ),
        if (data.goalTarget case final target?) ...[
          gap,
          _Goal(name: goal?.name, deadline: goal?.deadline, data: data, target: target),
        ],
        if (portfolio != null && portfolio.positions.isNotEmpty) ...[
          gap,
          ModuleCard(
            title: 'Portofolio',
            action: (label: 'Lihat posisi', onPressed: () => context.go('/portfolio'), icon: null),
            child: CurrencyTotals(portfolio: portfolio),
          ),
        ],
        if (netWorth != null && netWorth.assets.isNotEmpty) ...[gap, _Allocation(assets: netWorth.assets)],
        if (data.briefing case final briefing?) ...[
          gap,
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Briefing pagi · ${Fmt.date(briefing.date)}',
                  style: text.labelMedium?.copyWith(color: AppColors.onAccent),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(briefing.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                TextButton(
                  onPressed: () => _showBriefing(context, briefing),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.primary),
                  child: const Text('Baca briefing lengkap'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.data});

  final DashboardSummary data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final caption = text.bodySmall?.copyWith(color: AppColors.heroMuted);
    final change = data.dailyChange;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Kekayaan bersih', style: caption)),
              Text(Fmt.dateTime(data.asOf), style: caption),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AmountText(data.netWorth, style: AppTypography.amountLarge.copyWith(color: Colors.white)),
          if (change != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              decoration: BoxDecoration(color: AppColors.heroChip, borderRadius: BorderRadius.circular(16)),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Hari ini ', style: text.labelMedium?.copyWith(color: Colors.white)),
                  PnlText(amount: change, percent: data.dailyChangePercent, style: text.labelMedium, onDark: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(label: 'Total aset', value: AmountText(data.totalAssets, compact: true), onHero: true),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Total utang',
                  value: AmountText(data.totalLiabilities, compact: true),
                  onHero: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.highlight = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: highlight ? AppColors.accent : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// Kartu target: nama + persen besar, bar, lalu "… dari …" dan tenggat (tata letak artifact).
class _Goal extends StatelessWidget {
  const _Goal({required this.name, required this.deadline, required this.data, required this.target});

  final String? name;
  final DateTime? deadline;
  final DashboardSummary data;
  final Money target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final percent = target.amount <= 0 ? 0.0 : data.netWorth.amount / target.amount * 100;
    final small = text.bodySmall;
    return AppCard(
      onTap: () => context.go('/wealth'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(name ?? 'Target kekayaan', style: text.titleSmall)),
              Text(Fmt.percent(percent, signed: false), style: text.titleLarge?.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 10,
              color: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
              semanticsLabel: 'Progres target',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  children: [
                    AmountText(data.netWorth, compact: true, style: small),
                    Text(' dari ', style: small),
                    AmountText(target, compact: true, style: small),
                  ],
                ),
              ),
              if (deadline != null) Text('Tenggat ${DateFormat('MMM yyyy', 'id').format(deadline!)}', style: small),
            ],
          ),
        ],
      ),
    );
  }
}

/// Isi briefing lengkap (baris per baris) di sheet; kartu Beranda hanya ringkasan.
void _showBriefing(BuildContext context, BriefingPreview briefing) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) {
    final text = Theme.of(sheet).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
        children: [
          Text('Briefing pagi', style: text.titleLarge),
          Text(Fmt.date(briefing.date), style: text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          for (final line in briefing.fullText.split('\n'))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(line, style: text.bodyMedium),
            ),
        ],
      ),
    );
  },
);

/// Bar alokasi aset per kategori (nilai rupiah dari server) + legenda grid. Kategori ke-4 dst digabung
/// ke "Lainnya" (termasuk kategori Lainnya asli, jadi tidak muncul dua kali) supaya warna tetap 4 slot.
class _Allocation extends StatelessWidget {
  const _Allocation({required this.assets});

  final List<WealthItem> assets;

  static const _other = 'Lainnya';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final byCategory = <String, double>{};
    for (final a in assets) {
      byCategory.update(a.category.label, (v) => v + a.value.amount, ifAbsent: () => a.value.amount);
    }
    final sorted = byCategory.entries.where((e) => e.value > 0 && e.key != _other).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rest = sorted.skip(3).fold(byCategory[_other] ?? 0.0, (s, e) => s + e.value);
    final slices = [...sorted.take(3), if (rest > 0) MapEntry(_other, rest)];
    final total = slices.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();
    String pct(double v) => Fmt.percent(v / total * 100, signed: false);
    return ModuleCard(
      title: 'Alokasi aset',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Alokasi aset: ${slices.map((e) => '${e.key} ${pct(e.value)}').join(', ')}',
            child: SizedBox(
              height: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, e) in slices.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: (e.value / total * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: AppColors.series[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, e) in slices.indexed)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.series[i],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(e.key, style: text.bodySmall, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      Text(pct(e.value), style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
