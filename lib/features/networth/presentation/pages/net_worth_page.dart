import 'package:arah/core/domain/money.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/networth/presentation/widgets/wealth_entry_form.dart';
import 'package:arah/features/networth/presentation/widgets/wealth_item_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S07 — Kekayaan: Aset / Utang / Target / Riwayat snapshot. Aset manual & utang bisa ditambah, diubah, dihapus.
class NetWorthPage extends StatelessWidget {
  const NetWorthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NetWorthCubit>();
    return DefaultTabController(
      length: 4,
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
                      Tab(text: 'Riwayat'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _ItemList(kind: WealthKind.asset, items: data.assets, emptyTitle: 'Belum ada aset'),
                  _ItemList(
                    kind: WealthKind.liability,
                    items: data.liabilities,
                    emptyTitle: 'Tidak ada utang tercatat',
                  ),
                  _GoalTab(goal: data.goal, current: data.netWorth),
                  _SnapshotTab(snapshots: data.snapshots),
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
  const _ItemList({required this.kind, required this.items, required this.emptyTitle});

  final WealthKind kind;
  final List<WealthItem> items;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    final add = OutlinedButton.icon(
      onPressed: () => showWealthEntryForm(context, kind),
      icon: const Icon(Icons.add),
      label: Text(kind == WealthKind.asset ? 'Tambah aset' : 'Tambah utang'),
    );
    if (items.isEmpty) {
      return EmptyView(
        title: emptyTitle,
        actionLabel: kind == WealthKind.asset ? 'Tambah aset' : 'Tambah utang',
        onAction: () => showWealthEntryForm(context, kind),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        PageBody(child: add),
        for (final item in items)
          PageBody(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: WealthItemTile(
                item: item,
                // Portofolio otomatis dari posisi saham; diubah lewat tab Portofolio.
                onTap: item.isAutomatic ? null : () => showWealthEntryForm(context, kind, item: item),
              ),
            ),
          ),
      ],
    );
  }
}

/// Snapshot = catatan kekayaan bersih saat ini; total dihitung server (sama dengan web).
class _SnapshotTab extends StatefulWidget {
  const _SnapshotTab({required this.snapshots});
  final List<NetWorthSnapshot> snapshots;

  @override
  State<_SnapshotTab> createState() => _SnapshotTabState();
}

class _SnapshotTabState extends State<_SnapshotTab> {
  bool _busy = false;

  Future<void> _run(Future<Result<void>> Function() action, String done) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.fold((f) => f.message, (_) => done))));
  }

  Future<void> _delete(NetWorthSnapshot s) async {
    final cubit = context.read<NetWorthCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus snapshot?'),
        content: Text('Snapshot ${Fmt.date(s.date)} (${Fmt.money(s.netValue)}) dihapus dari web dan aplikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true) await _run(() => cubit.removeSnapshot(s.id), 'Snapshot dihapus');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NetWorthCubit>();
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        PageBody(
          child: PrimaryButton(
            label: 'Simpan snapshot sekarang',
            busy: _busy,
            onPressed: () => _run(cubit.createSnapshot, 'Snapshot tersimpan'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PageBody(
          child: Text(
            'Mencatat kekayaan bersih saat ini dengan harga & kurs terbaru. Web juga menyimpan snapshot otomatis tiap bulan.',
            style: text.bodySmall,
          ),
        ),
        if (widget.snapshots.isEmpty)
          const EmptyView(icon: Icons.timeline, title: 'Belum ada snapshot')
        else
          for (final s in widget.snapshots)
            PageBody(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(Fmt.date(s.date), style: text.labelLarge),
                            AmountText(s.netValue),
                            Wrap(
                              children: [
                                Text('Aset ', style: text.bodySmall),
                                AmountText(s.totalAssets, compact: true, style: text.bodySmall),
                                Text(' · Utang ', style: text.bodySmall),
                                AmountText(s.totalLiabilities, compact: true, style: text.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus snapshot ${Fmt.date(s.date)}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _busy ? null : () => _delete(s),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
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
