import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';
import 'package:arah/features/analysis/presentation/bloc/technical_rank_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _Scope { all, portfolio, watchlist }

/// Peringkat teknikal: saham milik user (posisi ∪ watchlist) dari sinyal terkuat, beserta alasannya.
class TechnicalRankPage extends StatefulWidget {
  const TechnicalRankPage({super.key});

  @override
  State<TechnicalRankPage> createState() => _TechnicalRankPageState();
}

class _TechnicalRankPageState extends State<TechnicalRankPage> {
  var _scope = _Scope.all;

  static bool _in(RankItem i, _Scope s) => switch (s) {
    _Scope.all => true,
    _Scope.portfolio => i.inPortfolio,
    _Scope.watchlist => i.inWatchlist,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TechnicalRankCubit>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Peringkat teknikal')),
      body: BlocBuilder<TechnicalRankCubit, ViewState<TechnicalRanking>>(
        builder: (context, state) => ViewStateBuilder<TechnicalRanking>(
          state: state,
          onRetry: cubit.load,
          isEmpty: (r) => r.items.isEmpty && r.missing.isEmpty,
          empty: const EmptyView(
            icon: Icons.leaderboard_outlined,
            title: 'Belum ada saham',
            message: 'Catat posisi atau tambahkan watchlist untuk melihat peringkat teknikal.',
          ),
          builder: (context, ranking) {
            final ranked = rankItems(ranking.items);
            final shown = ranked.where((i) => _in(i, _scope)).toList();
            final updated = ranking.items.isEmpty
                ? null
                : ranking.items.map((i) => i.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
            int count(_Scope s) => ranked.where((i) => _in(i, s)).length;
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  PageBody(
                    child: Text(
                      'Diurutkan dari sinyal teknikal terkuat (skor 1–5, lalu tren, MACD, RSI, volume). '
                      '${updated == null ? '' : 'Data harian ${Fmt.dateTime(updated)}. '}'
                      'Informasi, bukan saran beli/jual.',
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PageBody(
                    child: ChoiceChipBar<_Scope>(
                      options: _Scope.values,
                      selected: _scope,
                      labelOf: (s) =>
                          '${switch (s) {
                            _Scope.all => 'Semua',
                            _Scope.portfolio => 'Portofolio',
                            _Scope.watchlist => 'Watchlist',
                          }} ${count(s)}',
                      onSelected: (s) => setState(() => _scope = s),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (shown.isEmpty)
                    PageBody(child: Text('Tidak ada saham dengan sinyal di kelompok ini.', style: text.bodySmall)),
                  for (final item in shown)
                    PageBody(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _RankCard(rank: ranked.indexOf(item) + 1, item: item),
                      ),
                    ),
                  if (ranking.missing.isNotEmpty)
                    PageBody(
                      child: Text(
                        'Belum ada data teknikal: ${ranking.missing.map((k) => k.split(':').first).join(', ')}. '
                        'Sinyal dihitung setiap pagi hari kerja setelah histori harga cukup.',
                        style: text.bodySmall,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank, required this.item});

  /// Peringkat di antara semua saham (tidak berubah saat difilter).
  final int rank;
  final RankItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = item.score >= 4
        ? AppColors.positive
        : item.score <= 2
        ? AppColors.negative
        : AppColors.textSecondary;
    final source = [if (item.inPortfolio) 'Portofolio', if (item.inWatchlist) 'Watchlist'].join(' & ');
    final top = rank <= 3;
    return AppCard(
      semanticLabel: 'Peringkat $rank, ${item.symbol}, ${item.label}',
      onTap: () =>
          item.positionId != null ? context.go('/portfolio/${item.positionId}') : context.go('/more/watchlist'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: top ? AppColors.primary : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$rank',
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: top ? AppColors.accent : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.symbol, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      '${item.exchange} · $source',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.label,
                      textAlign: TextAlign.end,
                      style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: tone),
                    ),
                    Text('Skor ${item.score}/5', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          for (final r in rankReasons(item).take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (r.tone) {
                          ReasonTone.positive => AppColors.positive,
                          ReasonTone.negative => AppColors.negative,
                          ReasonTone.neutral => AppColors.textSecondary,
                        },
                      ),
                    ),
                  ),
                  Expanded(child: Text(r.text, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
