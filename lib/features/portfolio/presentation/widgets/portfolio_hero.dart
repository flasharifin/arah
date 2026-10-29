import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:flutter/material.dart';

/// Total per mata uang; tidak menjumlah IDR dan USD tanpa kurs dari server.
class PortfolioHero extends StatelessWidget {
  const PortfolioHero({super.key, required this.portfolio});

  final Portfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nilai portofolio', style: caption),
          for (final currency in portfolio.currencies) ...[
            const SizedBox(height: AppSpacing.sm),
            AmountText(
              portfolio.marketValue(currency),
              style: AppTypography.amountLarge.copyWith(color: Colors.white),
            ),
            Wrap(
              children: [
                Text('Unrealized ', style: caption),
                PnlText(
                  amount: portfolio.unrealizedPnl(currency),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Harga terakhir · ${Fmt.dateTime(portfolio.priceAsOf)}', style: caption),
        ],
      ),
    );
  }
}
