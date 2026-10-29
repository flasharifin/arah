import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Nominal uang yang menghormati mode privasi. Satu-satunya cara menampilkan uang di UI.
class AmountText extends StatelessWidget {
  const AmountText(this.value, {super.key, this.style, this.compact = false});

  final Money? value;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final text = hidden
        ? Fmt.hidden
        : compact
        ? Fmt.moneyCompact(value)
        : Fmt.money(value);
    return Text(
      text,
      style: AppTypography.amount.merge(style),
      semanticsLabel: hidden ? 'Nominal disembunyikan' : null,
    );
  }
}

/// Perubahan nilai (PnL): selalu bertanda +/− selain berwarna, agar tidak bergantung warna.
class PnlText extends StatelessWidget {
  const PnlText({super.key, this.amount, this.percent, this.style});

  final Money? amount;
  final double? percent;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final sign = amount?.amount ?? percent;
    final color = sign == null || sign == 0
        ? AppColors.textSecondary
        : sign > 0
        ? AppColors.positive
        : AppColors.negative;
    final parts = [
      if (amount != null) hidden ? Fmt.hidden : Fmt.money(amount, signed: true),
      if (percent != null) '(${Fmt.percent(percent)})',
    ];
    return Text(
      parts.isEmpty ? Fmt.missing : parts.join(' '),
      style: AppTypography.amount.copyWith(color: color).merge(style),
    );
  }
}
