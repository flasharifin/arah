import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/portfolio_hero.dart';
import 'package:arah/features/portfolio/presentation/widgets/position_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S03 — Portofolio: Posisi / Kinerja / Riwayat.
class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Portofolio'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Posisi'),
              Tab(text: 'Kinerja'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PositionsTab(),
            EmptyView(
              icon: Icons.show_chart,
              title: 'Kinerja belum tersedia',
              message: 'Grafik return dan benchmark menyusul di tahap berikutnya.',
            ),
            EmptyView(
              icon: Icons.history,
              title: 'Riwayat belum tersedia',
              message: 'Riwayat penjualan menyusul di tahap berikutnya.',
            ),
          ],
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
        empty: const EmptyView(
          title: 'Belum ada investasi tercatat',
          message: 'Catat pembelian pertamamu untuk mulai memantau portofolio.',
        ),
        builder: (context, portfolio) {
          final positions = state.visiblePositions;
          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const PortfolioRequested());
              await bloc.stream.firstWhere((s) => !s.data.isLoading);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                PageBody(child: PortfolioHero(portfolio: portfolio)),
                const SizedBox(height: AppSpacing.lg),
                PageBody(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Cari ticker',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (q) => bloc.add(PortfolioQueryChanged(q)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PageBody(
                  child: ChoiceChipBar<Exchange?>(
                    options: const [null, ...Exchange.values],
                    selected: state.filter,
                    labelOf: (e) => e?.label ?? 'Semua',
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
              ],
            ),
          );
        },
      ),
    );
  }
}
