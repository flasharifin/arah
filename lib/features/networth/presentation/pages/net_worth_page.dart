import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/networth/presentation/widgets/goal_form.dart';
import 'package:arah/features/networth/presentation/widgets/wealth_entry_form.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart' show PerformancePeriod;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S07 — Kekayaan sebagai modul bertumpuk (bukan tab): ringkasan → Aset → Utang → Target → Riwayat.
/// Aset manual & utang bisa ditambah, diubah, dihapus; total dihitung server.
class NetWorthPage extends StatelessWidget {
  const NetWorthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NetWorthCubit>();
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kekayaan'),
        actions: const [
          AskAiButton(compact: true),
          SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: BlocBuilder<NetWorthCubit, ViewState<NetWorth>>(
        builder: (context, state) => ViewStateBuilder<NetWorth>(
          state: state,
          onRetry: cubit.load,
          builder: (context, data) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxl),
              children: [
                PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Summary(data: data),
                      gap,
                      _Items(kind: WealthKind.asset, items: data.assets, total: data.totalAssets.amount),
                      gap,
                      _Items(kind: WealthKind.liability, items: data.liabilities, total: data.totalLiabilities.amount),
                      gap,
                      _Goal(goal: data.goal, data: data),
                      gap,
                      _Snapshots(snapshots: data.snapshots),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final NetWorth data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget chip(String label, Widget amount, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: text.labelMedium?.copyWith(color: fg)),
          DefaultTextStyle.merge(
            style: text.labelMedium?.copyWith(color: fg),
            child: amount,
          ),
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kekayaan bersih', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.xs),
          AmountText(data.netWorth, style: AppTypography.amountLarge),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              chip('Aset', AmountText(data.totalAssets, compact: true), AppColors.primarySoft, AppColors.text),
              chip(
                'Utang',
                AmountText(data.totalLiabilities, compact: true),
                AppColors.negativeSoft,
                AppColors.onNegativeSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Dihitung server · ${Fmt.dateTime(data.asOf)}', style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Modul aset atau utang: judul + jumlah, tombol tambah, lalu baris item (tap = ubah/hapus).
class _Items extends StatelessWidget {
  const _Items({required this.kind, required this.items, required this.total});

  final WealthKind kind;
  final List<WealthItem> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final asset = kind == WealthKind.asset;
    return ModuleCard(
      title: '${asset ? 'Aset' : 'Utang'} · ${items.length}',
      action: (
        label: asset ? 'Tambah aset' : 'Tambah utang',
        onPressed: () => showWealthEntryForm(context, kind),
        icon: Icons.add,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(asset ? 'Belum ada aset.' : 'Tidak ada utang tercatat.', style: text.bodySmall),
            ),
          for (final (i, item) in items.indexed)
            _ItemRow(
              item: item,
              // Kekayaan aset: warna kategori tetap per urutan (palet grafik); utang satu warna.
              color: asset ? AppColors.series[i % AppColors.series.length] : AppColors.onNegativeSoft,
              share: asset && total > 0 ? item.value.amount / total * 100 : null,
              // Portofolio otomatis dari posisi saham; diubah lewat tab Portofolio.
              onTap: item.isAutomatic ? null : () => showWealthEntryForm(context, kind, item: item),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.color, this.share, this.onTap});

  /// Ikon per kategori aset; semua utang memakai satu ikon umum.
  static IconData _icon(WealthItem item) => switch (item.category) {
    WealthCategory.portfolio => Icons.show_chart_rounded,
    WealthCategory.cash => Icons.savings_outlined,
    WealthCategory.mutualFund => Icons.pie_chart_outline_rounded,
    WealthCategory.property => Icons.home_work_outlined,
    WealthCategory.gold => Icons.diamond_outlined,
    WealthCategory.defi => Icons.hub_outlined,
    WealthCategory.debt => Icons.receipt_long_outlined,
    WealthCategory.other => Icons.category_outlined,
  };

  final WealthItem item;
  final Color color;
  final double? share;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meta = [
      if (item.entry case final e? when e.kind == WealthKind.liability)
        liabilityCategories[e.category] ?? item.category.label
      else
        item.category.label,
      if (item.isAutomatic) 'otomatis',
      if (item.entry?.currency == 'GOLD') '${Fmt.number(item.entry!.amount)} gram',
      if ((item.entry?.note ?? '').isNotEmpty) item.entry!.note!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              // Ikon dekoratif (nama & kategori tertulis); digelapkan supaya kuning/hijau tetap terlihat.
              child: ExcludeSemantics(child: Icon(_icon(item), size: 22, color: Color.lerp(color, Colors.black, 0.25))),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.titleSmall),
                  Text(meta, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(item.value),
                if (share != null) Text(Fmt.percent(share, signed: false), style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.goal, required this.data});

  final WealthGoal? goal;
  final NetWorth data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final goal = this.goal;
    if (goal == null) {
      return ModuleCard(
        title: 'Target',
        action: (label: 'Buat target', onPressed: () => showGoalForm(context, null), icon: Icons.add),
        child: Text('Tetapkan target kekayaanmu.', style: text.bodySmall),
      );
    }
    final muted = text.bodySmall?.copyWith(color: AppColors.heroMuted);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Target · ${goal.name}', style: text.titleSmall?.copyWith(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => showGoalForm(context, goal),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text('Ubah target'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Tata letak artifact: persen besar + "… dari …" di sampingnya, lalu bar.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(
                Fmt.percent(
                  goal.target.amount <= 0 ? 0 : data.netWorth.amount / goal.target.amount * 100,
                  signed: false,
                ),
                style: AppTypography.amountLarge.copyWith(color: Colors.white, fontSize: 28),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Wrap(
                  children: [
                    AmountText(data.netWorth, compact: true, style: muted),
                    Text(' dari ', style: muted),
                    AmountText(goal.target, compact: true, style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.target.amount <= 0 ? 0 : (data.netWorth.amount / goal.target.amount).clamp(0, 1),
              minHeight: 10,
              color: AppColors.accent,
              backgroundColor: AppColors.heroChip,
              semanticsLabel: 'Progres target',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(label: 'Tenggat', value: Text(Fmt.date(goal.deadline)), onHero: true),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Setoran/bln',
                  value: AmountText(goal.monthlyContribution, compact: true),
                  onHero: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Return/thn',
                  value: Text(Fmt.percent(goal.expectedReturnPercent, signed: false)),
                  onHero: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Proyeksi adalah estimasi berdasarkan asumsi, bukan hasil yang dijamin.', style: muted),
        ],
      ),
    );
  }
}

/// Snapshot = catatan kekayaan bersih saat ini; total dihitung server (sama dengan web).
class _Snapshots extends StatefulWidget {
  const _Snapshots({required this.snapshots});
  final List<NetWorthSnapshot> snapshots;

  @override
  State<_Snapshots> createState() => _SnapshotsState();
}

class _SnapshotsState extends State<_Snapshots> {
  bool _busy = false;

  /// `null` = semua snapshot.
  PerformancePeriod? _period;
  bool _all = false;

  static const _visible = 5;

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
    // Snapshot terbaru dulu (dari data source); periode dihitung mundur dari hari ini.
    final filtered = _period?.filter(widget.snapshots, (s) => s.date, DateTime.now()) ?? widget.snapshots;
    final shown = _all ? filtered : filtered.take(_visible).toList();
    return ModuleCard(
      title: 'Riwayat kekayaan',
      // Simpan di kepala kartu: tidak perlu menggulir melewati daftar.
      action: (
        label: _busy ? 'Menyimpan…' : 'Simpan snapshot',
        onPressed: _busy ? null : () => _run(cubit.createSnapshot, 'Snapshot tersimpan'),
        icon: Icons.add,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.snapshots.isEmpty)
            Text(
              'Belum ada snapshot. Simpan sekarang untuk mulai melihat tren; web juga menyimpan otomatis tiap bulan.',
              style: text.bodySmall,
            )
          else ...[
            ChoiceChipBar<PerformancePeriod?>(
              options: const [null, PerformancePeriod.month, PerformancePeriod.quarter, PerformancePeriod.year],
              selected: _period,
              labelOf: (p) => p?.label ?? 'Semua',
              onSelected: (p) => setState(() {
                _period = p;
                _all = false;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('Tidak ada snapshot di periode ini.', style: text.bodySmall),
              ),
          ],
          for (final s in shown)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  // Kiri: tanggal, lalu aset & utang masing-masing satu baris (tidak turun baris otomatis).
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Fmt.date(s.date), style: text.labelLarge),
                        for (final (label, amount) in [('Aset ', s.totalAssets), ('Utang ', s.totalLiabilities)])
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label, style: text.bodySmall),
                                AmountText(amount, compact: true, style: text.bodySmall),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Kanan: kekayaan bersih rata kanan.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bersih', style: text.bodySmall),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: AmountText(s.netValue, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
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
          if (filtered.length > _visible)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? 'Tampilkan $_visible terbaru' : 'Lihat semua ${filtered.length} snapshot'),
              ),
            ),
        ],
      ),
    );
  }
}
