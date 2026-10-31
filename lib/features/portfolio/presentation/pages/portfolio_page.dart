import 'package:arah/app/di.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/currency_totals.dart';
import 'package:arah/features/portfolio/presentation/widgets/performance_tab.dart';
import 'package:arah/features/portfolio/presentation/widgets/position_card.dart';
import 'package:arah/features/portfolio/presentation/widgets/purchase_form.dart';
import 'package:arah/features/portfolio/presentation/widgets/sales_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S03 — Portofolio: Posisi / Kinerja / Riwayat. [initialTab] dari `?tab=` (mis. aksi cepat Beranda).
class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key, this.initialTab});

  final String? initialTab;

  static const _tabs = ['Posisi', 'Kinerja', 'Riwayat'];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => t.toLowerCase() == initialTab);
    return DefaultTabController(
      // key: `?tab=` baru dari luar membuka tab itu walau halaman sudah hidup di shell.
      key: ValueKey(initialTab),
      length: _tabs.length,
      initialIndex: index < 0 ? 0 : index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Portofolio'),
          actions: [
            FilledButton.icon(
              onPressed: () => showPurchaseForm(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Catat'),
            ),
            const SizedBox(width: AppSpacing.sm),
            const AskAiButton(compact: true),
            const SizedBox(width: AppSpacing.lg),
          ],
          bottom: const SegmentedTabBar(tabs: _tabs),
        ),
        // Kinerja & Riwayat dimuat saat tab pertama dibuka, lalu bertahan selama halaman hidup.
        body: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<PerformanceCubit>()..load()),
            BlocProvider(create: (_) => sl<SalesCubit>()..load()),
          ],
          child: const TabBarView(children: [_PositionsTab(), PerformanceTab(), SalesTab()]),
        ),
      ),
    );
  }
}

class _PositionsTab extends StatelessWidget {
  const _PositionsTab();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PortfolioBloc>();
    return BlocBuilder<PortfolioBloc, PortfolioState>(
      builder: (context, state) => ViewStateBuilder<Portfolio>(
        state: state.data,
        onRetry: () => bloc.add(const PortfolioRequested()),
        isEmpty: (p) => p.positions.isEmpty,
        empty: EmptyView(
          title: 'Belum ada investasi tercatat',
          message: 'Catat pembelian pertamamu untuk mulai memantau portofolio.',
          actionLabel: 'Catat pembelian',
          onAction: () => showPurchaseForm(context),
        ),
        builder: (context, portfolio) {
          final positions = state.visiblePositions;
          int count(Exchange? e) => portfolio.positions.where((p) => e == null || p.exchange == e).length;
          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const PortfolioRequested());
              await bloc.stream.firstWhere((s) => !s.data.isLoading);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                PageBody(child: CurrencyTotals(portfolio: portfolio, tiles: true)),
                const SizedBox(height: AppSpacing.md),
                PageBody(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Cari ticker', prefixIcon: Icon(Icons.search)),
                    onChanged: (q) => bloc.add(PortfolioQueryChanged(q)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PageBody(
                  child: ChoiceChipBar<Exchange?>(
                    options: const [null, ...Exchange.values],
                    selected: state.filter,
                    labelOf: (e) => '${e?.label ?? 'Semua'} ${count(e)}',
                    onSelected: (e) => bloc.add(PortfolioFilterChanged(e)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (positions.isEmpty)
                  EmptyView(
                    title: 'Tidak ada aset cocok',
                    actionLabel: 'Reset filter',
                    onAction: () => bloc
                      ..add(const PortfolioFilterChanged(null))
                      ..add(const PortfolioQueryChanged('')),
                  )
                else
                  for (final p in positions)
                    PageBody(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: PositionCard(position: p, onTap: () => context.go('/portfolio/${p.id}')),
                      ),
                    ),
                PageBody(
                  child: Text(
                    'Harga per ${Fmt.dateTime(portfolio.priceAsOf)} · bisa dari cache server.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
