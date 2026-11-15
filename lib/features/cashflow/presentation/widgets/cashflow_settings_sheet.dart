import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/presentation/bloc/cashflow_cubit.dart';
import 'package:arah/features/cashflow/presentation/widgets/cash_widgets.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Atur arus kas: gaji tetap (nominal, tanggal, aset penerima) & target dana darurat.
Future<void> showCashflowSettings(BuildContext context) async {
  final cubit = context.read<CashflowCubit>();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        if (context.read<NetWorthCubit?>() case final nw?) BlocProvider.value(value: nw),
      ],
      child: _CashflowSettingsForm(initial: cubit.state.data?.settings ?? const CashflowSettings()),
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan arus kas tersimpan')));
  }
}

class _CashflowSettingsForm extends StatefulWidget {
  const _CashflowSettingsForm({required this.initial});
  final CashflowSettings initial;

  @override
  State<_CashflowSettingsForm> createState() => _CashflowSettingsFormState();
}

class _CashflowSettingsFormState extends State<_CashflowSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _income = TextEditingController(
    text: widget.initial.monthlyIncome == null ? '' : widget.initial.monthlyIncome!.round().toString(),
  );
  late int _day = widget.initial.incomeDay ?? 25;
  late String? _assetId = widget.initial.incomeAssetId;
  late int _months = widget.initial.emergencyMonths;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _income.dispose();
    super.dispose();
  }

  Future<void> _save({bool clearSalary = false}) async {
    if (!clearSalary && !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final income = double.tryParse(_income.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    final result = await context.read<CashflowCubit>().saveSettings(
      clearSalary || income == null
          ? CashflowSettings(emergencyMonths: _months)
          : CashflowSettings(monthlyIncome: income, incomeDay: _day, incomeAssetId: _assetId, emergencyMonths: _months),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _busy = false;
        _error = f.message;
      }),
      (_) => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final assets = cashAssetsOf(context.watch<NetWorthCubit?>()?.state.data);
    if (_assetId != null && !assets.any((a) => a.id == _assetId)) _assetId = null;
    _assetId ??= assets.firstOrNull?.id;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Atur arus kas', style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gaji tetap dicatat otomatis ke aset kas pada tanggal gajian (tengah malam WIB). '
                'Kalau jumlah yang masuk beda, ubah saldo asetnya di tab Kekayaan.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Gaji per bulan (Rp)',
                controller: _income,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim().replaceAll('.', '').replaceAll(',', '.'));
                  return (v ?? '').trim().isEmpty || (n != null && n > 0) ? null : 'Masukkan angka lebih dari 0';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: const InputDecoration(labelText: 'Tanggal gajian'),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text(d == 31 ? '31 / hari terakhir' : '$d')),
                ],
                onChanged: _busy ? null : (d) => setState(() => _day = d ?? _day),
              ),
              const SizedBox(height: AppSpacing.md),
              if (assets.isEmpty)
                Text(
                  'Tambahkan aset kategori "Kas & tabungan" di Kekayaan dulu untuk menerima gaji.',
                  style: text.bodySmall,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _assetId,
                  decoration: const InputDecoration(labelText: 'Masuk ke'),
                  items: [for (final a in assets) DropdownMenuItem(value: a.id, child: Text(a.name))],
                  validator: (v) => _income.text.trim().isNotEmpty && v == null ? 'Pilih aset kas' : null,
                  onChanged: _busy ? null : (id) => setState(() => _assetId = id),
                ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<int>(
                initialValue: _months,
                decoration: const InputDecoration(
                  labelText: 'Target dana darurat',
                  helperText: 'Umumnya 3–6 bulan; pekerja lepas ±12 bulan.',
                ),
                items: [
                  for (final m in const [3, 6, 9, 12, 18, 24])
                    DropdownMenuItem(value: m, child: Text('$m bulan pengeluaran')),
                ],
                onChanged: _busy ? null : (m) => setState(() => _months = m ?? _months),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
              if (widget.initial.hasSalary) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy ? null : () => _save(clearSalary: true),
                  child: const Text('Hapus gaji tetap'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
