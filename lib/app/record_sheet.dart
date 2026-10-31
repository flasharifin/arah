import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/widgets/wealth_entry_form.dart';
import 'package:arah/features/portfolio/presentation/widgets/purchase_form.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Sheet tombol Catat (navigasi tengah): semua pencatatan dari satu tempat.
/// [context] = konteks shell, yang punya bloc sesi (Portofolio, Beranda, Kekayaan) untuk form.
Future<void> showRecordSheet(BuildContext context) async {
  final action = await showModalBottomSheet<void Function()>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _RecordSheet(context: context),
  );
  // Form dibuka setelah sheet tertutup, dengan konteks shell.
  if (action != null && context.mounted) action();
}

class _RecordSheet extends StatelessWidget {
  const _RecordSheet({required this.context});

  /// Konteks shell (bukan konteks sheet).
  final BuildContext context;

  @override
  Widget build(BuildContext sheet) {
    final text = Theme.of(sheet).textTheme;
    final shell = context;
    void pick(void Function() action) => Navigator.pop(sheet, action);
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: text.labelMedium?.copyWith(color: AppColors.textSecondary, letterSpacing: 0.7),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Catat', style: text.titleLarge),
            Text('Semua pencatatan dari satu tempat', style: text.bodySmall),
            heading('Investasi'),
            // Tinggi mengikuti isi & ukuran teks (FeatureMenu), bukan rasio tetap.
            FeatureMenu(
              children: [
                _Tile(
                  icon: Icons.north,
                  title: 'Pembelian',
                  subtitle: 'Saham, US, kripto',
                  primary: true,
                  onTap: () => pick(() => showPurchaseForm(shell)),
                ),
                // Form penjualan belum ada di HP: tampil nonaktif, tidak mengklaim fitur aktif.
                const _Tile(icon: Icons.south, title: 'Penjualan', subtitle: 'Segera tersedia'),
                _Tile(
                  icon: Icons.event_repeat_outlined,
                  title: 'Pelaksanaan DCA',
                  subtitle: 'Sesuai rencana',
                  onTap: () => pick(() => shell.go('/more/dca')),
                ),
                _Tile(
                  icon: Icons.payments_outlined,
                  title: 'Dividen',
                  subtitle: 'DPS, pajak, tanggal',
                  onTap: () => pick(() => shell.go('/more/dividends')),
                ),
              ],
            ),
            heading('Kekayaan & catatan'),
            _Row(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Aset',
              subtitle: 'Kas, emas (gram), properti, reksa dana',
              onTap: () => pick(() => showWealthEntryForm(shell, WealthKind.asset)),
            ),
            _Row(
              icon: Icons.credit_card_outlined,
              title: 'Utang',
              subtitle: 'KPR, KTA, kartu kredit, kendaraan',
              onTap: () => pick(() => showWealthEntryForm(shell, WealthKind.liability)),
            ),
            _Row(
              icon: Icons.edit_note_outlined,
              title: 'Jurnal hari ini',
              subtitle: 'Catatan dan PnL harian',
              onTap: () => pick(() => shell.go('/more/journal')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, this.onTap, this.primary = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final fg = primary ? Colors.white : AppColors.text;
    return Material(
      color: primary ? AppColors.primary : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: text.titleSmall?.copyWith(color: fg)),
                Text(subtitle, style: text.bodySmall?.copyWith(color: primary ? AppColors.heroMuted : null)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      child: ListTile(
        minTileHeight: 60,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    ),
  );
}
