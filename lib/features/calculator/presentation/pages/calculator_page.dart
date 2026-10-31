import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Alat kalkulator; [slug] = `/more/calculator/<slug>`.
enum CalculatorTool {
  lot('lot', Icons.straighten, 'Kalkulator lot', 'Berapa lot/unit dari dana yang ada'),
  sizing('sizing', Icons.balance, 'Position sizing', 'Jumlah beli dari risiko % dan stop loss'),
  bep('bep', Icons.flag_outlined, 'BEP & averaging', 'Harga impas dan simulasi beli tambahan'),
  rebalance('rebalance', Icons.pie_chart_outline, 'Rebalancing', 'Selisih alokasi aktual vs target per bursa'),
  fi('fi', Icons.beach_access_outlined, 'Financial independence', 'FI number dan estimasi waktu menuju FI'),
  invisible(
    'invisible-cost',
    Icons.visibility_off_outlined,
    'Biaya tersembunyi',
    'Tertinggal dari IHSG & erosi inflasi',
  ),
  timeline('timeline', Icons.timeline, 'Wealth timeline', 'Nilai porto dan kejadian investasi');

  const CalculatorTool(this.slug, this.icon, this.title, this.subtitle);
  final String slug;
  final IconData icon;
  final String title;
  final String subtitle;

  static CalculatorTool? fromSlug(String slug) => values.where((t) => t.slug == slug).firstOrNull;
}

/// S13 — daftar alat; setiap alat membuka layar fokus.
class CalculatorPage extends StatelessWidget {
  const CalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalkulator')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          PageBody(
            child: FeatureMenu(
              children: [
                for (final t in CalculatorTool.values)
                  FeatureTile(
                    icon: t.icon,
                    title: t.title,
                    subtitle: t.subtitle,
                    onTap: () => context.go('/more/calculator/${t.slug}'),
                  ),
              ],
            ),
          ),
          PageBody(
            child: Text(
              'Hasil kalkulator adalah estimasi dan tidak menyimpan transaksi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
