import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/networth/presentation/widgets/wealth_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S07 — Kekayaan: Aset / Utang / Target.
class NetWorthPage extends StatelessWidget {
  const NetWorthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NetWorthCubit>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kekayaan')),
        body: BlocBuilder<NetWorthCubit, ViewState<NetWorth>>(
          builder: (context, state) => ViewStateBuilder<NetWorth>(
            state: state,
            onRetry: cubit.load,
            builder: (context, data) => NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: PageBody(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: _NetWorthHero(data: data),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Aset'),
                      Tab(text: 'Utang'),
                      Tab(text: 'Target'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _ItemList(items: data.assets, emptyTitle: 'Belum ada aset'),
                  _ItemList(items: data.liabilities, emptyTitle: 'Tidak ada utang tercatat'),
                  _GoalTab(goal: data.goal, current: data.netWorth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.data});

  final NetWorth data;

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kekayaan bersih', style: caption),
          AmountText(data.netWorth, style: AppTypography.amountLarge.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            children: [
              Text('Aset ', style: caption),
              AmountText(data.totalAssets, compact: true, style: caption),
              Text(' · Utang ', style: caption),
              AmountText(data.totalLiabilities, compact: true, style: caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Data terakhir · ${Fmt.dateTime(data.asOf)}', style: caption),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.emptyTitle});

  final List<WealthItem> items;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return EmptyView(title: emptyTitle);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => PageBody(child: WealthItemTile(item: items[i])),
    );
  }
}

class _GoalTab extends StatelessWidget {
  const _GoalTab({required this.goal, required this.current});

  final WealthGoal? goal;
  final Money current;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    if (goal == null) {
      return const EmptyView(title: 'Belum ada target', message: 'Tetapkan target kekayaanmu.');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        PageBody(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                GoalProgress(current: current, target: goal.target),
                const SizedBox(height: AppSpacing.md),
                InfoRow(label: 'Tenggat', value: Text(Fmt.date(goal.deadline))),
                InfoRow(label: 'Setoran bulanan', value: AmountText(goal.monthlyContribution)),
                InfoRow(
                  label: 'Asumsi return/tahun',
                  value: Text(Fmt.percent(goal.expectedReturnPercent, signed: false)),
                ),
                Text(
                  'Proyeksi adalah estimasi berdasarkan asumsi, bukan hasil yang dijamin.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
