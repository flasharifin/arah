import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S02 — Beranda.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Image(
          image: AssetImage('assets/images/arah-logo.png'),
          height: 36,
          semanticLabel: 'Arah',
        ),
      ),
      body: BlocBuilder<DashboardCubit, ViewState<DashboardSummary>>(
        builder: (context, state) => ViewStateBuilder<DashboardSummary>(
          state: state,
          onRetry: cubit.load,
          builder: (context, data) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Selamat datang kembali', style: text.bodySmall),
        Text('Ringkasan keuanganmu', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.lg),
        _NetWorthHero(data: data),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppCard(
                onTap: () => context.go('/portfolio'),
                child: _Metric(label: 'Portofolio', value: AmountText(data.portfolioValue, compact: true)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppCard(
                child: _Metric(
                  label: 'Skor kesehatan',
                  value: Text(data.healthScore == null ? Fmt.missing : '${data.healthScore}/100'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.auto_awesome_outlined,
                label: 'Tanya AI',
                onTap: () => context.go('/assistant'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Shortcut(
                icon: Icons.add_circle_outline,
                label: 'Catat investasi',
                onTap: () => context.go('/portfolio'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Shortcut(
                icon: Icons.edit_note_outlined,
                label: 'Jurnal',
                onTap: () => context.go('/more/journal'),
              ),
            ),
          ],
        ),
        if (data.goalTarget != null) ...[
          SectionHeader('Perjalanan ke target', actionLabel: 'Lihat', onAction: () => context.go('/wealth')),
          AppCard(
            child: GoalProgress(current: data.netWorth, target: data.goalTarget!),
          ),
        ],
        if (data.briefing != null) ...[
          const SectionHeader('Briefing terakhir'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.date(data.briefing!.date), style: text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(data.briefing!.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
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
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final caption = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Total kekayaan bersih', style: caption)),
              IconButton(
                tooltip: hidden ? 'Tampilkan nominal' : 'Sembunyikan nominal',
                icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: context.read<PrivacyCubit>().toggle,
              ),
            ],
          ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        DefaultTextStyle.merge(style: Theme.of(context).textTheme.titleMedium, child: value),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
