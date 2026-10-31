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
/// Tidak pernah patah baris otomatis: satu baris yang mengecil bila sempit, atau [stacked] =
/// nominal di baris pertama dan persen di baris kedua (dipakai di daftar & kartu).
class PnlText extends StatelessWidget {
  const PnlText({
    super.key,
    this.amount,
    this.percent,
    this.style,
    this.onDark = false,
    this.stacked = false,
    this.align = CrossAxisAlignment.end,
  });

  final Money? amount;
  final double? percent;
  final TextStyle? style;

  /// Di atas latar hijau gelap (hero): hijau/merah versi terang supaya tetap kontras.
  final bool onDark;
  final bool stacked;

  /// Perataan baris saat [stacked].
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final sign = amount?.amount ?? percent;
    final color = sign == null || sign == 0
        ? (onDark ? AppColors.heroMuted : AppColors.textSecondary)
        : sign > 0
        ? (onDark ? AppColors.accent : AppColors.positive)
        : (onDark ? const Color(0xFFFFD9D5) : AppColors.negative);
    // Warna dipasang terakhir: gaya dari tema (mis. labelMedium) membawa warna teks yang akan menimpa hijau/merah.
    final textStyle = AppTypography.amount.merge(style).copyWith(color: color);
    final money = amount == null ? null : (hidden ? Fmt.hidden : Fmt.money(amount, signed: true));
    final pct = percent == null ? null : Fmt.percent(percent);
    final alignment = switch (align) {
      CrossAxisAlignment.start => Alignment.centerLeft,
      CrossAxisAlignment.center => Alignment.center,
      _ => Alignment.centerRight,
    };
    Widget line(String value, TextStyle st) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(value, maxLines: 1, softWrap: false, style: st),
    );
    if (stacked && money != null && pct != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          line(money, textStyle),
          line(pct, textStyle.copyWith(fontSize: (textStyle.fontSize ?? 14) - 2, fontWeight: FontWeight.w600)),
        ],
      );
    }
    final parts = [?money, if (pct != null) (money == null ? pct : '($pct)')];
    return line(parts.isEmpty ? Fmt.missing : parts.join(' '), textStyle);
  }
}
