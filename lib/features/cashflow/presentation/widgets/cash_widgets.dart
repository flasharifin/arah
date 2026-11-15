import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/presentation/bloc/cashflow_cubit.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Aset kas IDR/USD di Kekayaan — pilihan "Sumber dana" & penerima gaji (sama dengan syarat server).
typedef CashAssetOption = ({String id, String name, Money value});

List<CashAssetOption> cashAssetsOf(NetWorth? data) => [
  for (final a in data?.assets ?? const <WealthItem>[])
    if (a.entry case final e? when e.category == 'cash' && (e.currency == 'IDR' || e.currency == 'USD'))
      (id: a.id, name: a.name, value: Money(e.amount, e.currency == 'USD' ? Currency.usd : Currency.idr)),
];

/// Setelah transaksi yang memotong/menambah kas: saldo di Kekayaan & Arus kas dimuat ulang.
/// Nullable lookup: form juga dipakai di test/layar tanpa kedua cubit ini.
void refreshCash(BuildContext context) => cashRefresher(context)();

/// Seperti [refreshCash], tapi cubit diambil sekarang — untuk dipanggil setelah `await` (form sudah tertutup).
VoidCallback cashRefresher(BuildContext context) {
  final netWorth = context.read<NetWorthCubit?>();
  final cashflow = context.read<CashflowCubit?>();
  return () {
    netWorth?.load();
    cashflow?.load();
  };
}

/// Isian "Sumber dana": aset kas yang saldonya ikut berubah. Pilihan awal: aset terakhir dipakai untuk
/// mata uang yang sama, lalu aset pertama bermata uang sama, lalu "Tidak memotong kas".
class CashSourceField extends StatefulWidget {
  const CashSourceField({
    super.key,
    required this.currency,
    required this.onChanged,
    this.amount,
    this.incoming = false,
    this.allowAmount = true,
    this.note,
  });

  /// Mata uang transaksi (harga saham / dividen).
  final Currency currency;

  /// Nilai transaksi dalam [currency] untuk pratinjau saldo; `null` = belum diisi.
  final double? amount;

  /// Kas bertambah (jual, dividen) alih-alih berkurang.
  final bool incoming;

  /// Isian "jumlah terpotong/diterima"; dividen tidak memakainya (jumlah dihitung server dari lot & pajak).
  final bool allowAmount;
  final String? note;
  final ValueChanged<CashSource?> onChanged;

  // shortcut: "terakhir dipakai" hanya selama app terbuka; simpan ke storage bila perlu bertahan setelah ditutup.
  static final _lastUsed = <Currency, String?>{};

  @override
  State<CashSourceField> createState() => _CashSourceFieldState();
}

class _CashSourceFieldState extends State<CashSourceField> {
  String? _assetId;
  bool _initialized = false;
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _emit() {
    final typed = double.tryParse(_amount.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    widget.onChanged(_assetId == null ? null : (assetId: _assetId!, amount: typed != null && typed > 0 ? typed : null));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final options = cashAssetsOf(context.watch<NetWorthCubit?>()?.state.data);
    if (options.isEmpty) return const SizedBox.shrink();
    if (!_initialized) {
      _initialized = true;
      final last = CashSourceField._lastUsed[widget.currency];
      _assetId = options.any((o) => o.id == last)
          ? last
          : CashSourceField._lastUsed.containsKey(widget.currency)
          ? null // terakhir kali memilih "Tidak memotong kas"
          : options.where((o) => o.value.currency == widget.currency).firstOrNull?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _emit() : null);
    }
    final selected = options.where((o) => o.id == _assetId).firstOrNull;
    final sameCurrency = selected != null && selected.value.currency == widget.currency;
    final typed = double.tryParse(_amount.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    final delta = typed ?? (sameCurrency ? widget.amount : null);
    void pick(String? id) {
      setState(() => _assetId = id);
      CashSourceField._lastUsed[widget.currency] = id;
      _emit();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.incoming ? 'Masuk ke' : 'Sumber dana', style: text.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        RadioGroup<String?>(
          groupValue: _assetId,
          onChanged: pick,
          child: Column(
            children: [
              for (final o in options)
                _SourceTile(
                  value: o.id,
                  selected: _assetId == o.id,
                  title: o.name,
                  subtitle: o.value.currency == widget.currency ? null : 'Beda mata uang · dikonversi kurs hari ini',
                  trailing: AmountText(o.value),
                ),
              _SourceTile(
                value: null,
                selected: _assetId == null,
                title: widget.incoming ? 'Tidak menambah kas' : 'Tidak memotong kas',
                subtitle: 'Transaksi lama / dana di luar Arah',
              ),
            ],
          ),
        ),
        if (selected != null && widget.note != null && !widget.allowAmount) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.note!, style: text.bodySmall),
        ],
        if (selected != null && widget.allowAmount) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label:
                '${widget.incoming ? 'Jumlah diterima' : 'Jumlah terpotong'} (opsional, ${selected.value.currency.name.toUpperCase()})',
            controller: _amount,
            helper:
                widget.note ??
                (sameCurrency
                    ? 'Kosong = nilai transaksi. Isi kalau broker memotong beda (biaya, pajak).'
                    : 'Kosong = dikonversi kurs hari ini. Isi jumlah yang benar-benar ${widget.incoming ? 'masuk' : 'terpotong'}.'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(_emit),
          ),
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            InfoRow(
              label: 'Saldo ${selected.name} setelah ini',
              value: AmountText(
                Money(selected.value.amount + (widget.incoming ? delta : -delta), selected.value.currency),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.value, required this.selected, required this.title, this.subtitle, this.trailing});
  final String? value;
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: RadioListTile<String?>(
          value: value,
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Expanded(child: Text(title, style: text.titleSmall)),
              if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
            ],
          ),
          subtitle: subtitle == null ? null : Text(subtitle!, style: text.bodySmall),
        ),
      ),
    );
  }
}

/// Satu baris mutasi kas (Arus kas & Mutasi kas).
class CashMovementTile extends StatelessWidget {
  const CashMovementTile({super.key, required this.movement, this.onTap, this.showBalance = false});
  final CashMovement movement;
  final VoidCallback? onTap;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = movement;
    final (bg, fg) = switch (m.kind) {
      CashMovementKind.manual => (AppColors.warningSoft, AppColors.warning),
      _ when m.amount.amount < 0 => (AppColors.negativeSoft, AppColors.onNegativeSoft),
      _ => (AppColors.primarySoft, AppColors.positive),
    };
    final struck = m.reversed ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(_icon(m), size: 20, color: fg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title, style: text.titleSmall?.merge(struck)),
                  Text(
                    '${m.assetName} · ${Fmt.date(m.date)}${m.reversed ? ' · dibatalkan' : ''}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Nominal mengecil (bukan meluber) saat teks diperbesar; judul tetap dapat ruang lebih.
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PnlText(amount: m.amount, style: struck),
                    if (showBalance) AmountText(m.balanceAfter, style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(CashMovement m) => m.reversal
      ? Icons.undo
      : switch (m.kind) {
          CashMovementKind.purchase || CashMovementKind.dca => Icons.shopping_cart_outlined,
          CashMovementKind.sale => Icons.sell_outlined,
          CashMovementKind.dividend => Icons.payments_outlined,
          CashMovementKind.income => Icons.work_outline,
          CashMovementKind.manual => Icons.edit_outlined,
          CashMovementKind.opening => Icons.flag_outlined,
        };
}
