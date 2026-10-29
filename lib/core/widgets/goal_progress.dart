import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/amount_text.dart';
import 'package:flutter/material.dart';

/// Progres menuju target: `Rp 128,45 jt / Rp 1 M · 12,85%`.
class GoalProgress extends StatelessWidget {
  const GoalProgress({super.key, required this.current, required this.target});

  final Money current;
  final Money target;

  double get percent => target.amount <= 0 ? 0 : current.amount / target.amount * 100;

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0, 1),
            minHeight: 10,
            color: AppColors.primary,
            backgroundColor: AppColors.accent,
            semanticsLabel: 'Progres target',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                children: [
                  AmountText(current, compact: true, style: caption),
                  Text(' / ', style: caption),
                  AmountText(target, compact: true, style: caption),
                ],
              ),
            ),
            Text(Fmt.percent(percent, signed: false), style: caption),
          ],
        ),
      ],
    );
  }
}
