import 'package:arah/core/domain/money.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S18 — Ubah target kekayaan (disimpan di pengaturan akun, sama dengan target di web).
void showGoalForm(BuildContext context, WealthGoal? goal) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BlocProvider.value(
    value: context.read<NetWorthCubit>(),
    child: _GoalForm(goal: goal),
  ),
);

class _GoalForm extends StatefulWidget {
  const _GoalForm({this.goal});
  final WealthGoal? goal;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.goal?.name ?? 'Target kekayaan');
  late final _target = TextEditingController(text: _plain(widget.goal?.target.amount));
  late final _monthly = TextEditingController(text: _plain(widget.goal?.monthlyContribution?.amount));
  late final _return = TextEditingController(text: _plain(widget.goal?.expectedReturnPercent));
  late DateTime? _deadline = widget.goal?.deadline;
  bool _busy = false;
  String? _error;

  static String _plain(double? v) => switch (v) {
    null => '',
    final v when v == v.roundToDouble() => v.toInt().toString(),
    final v => v.toString(),
  };

  static double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_name, _target, _monthly, _return]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year + 5, 12, 31),
      firstDate: now,
      lastDate: DateTime(now.year + 60),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final monthly = _parse(_monthly.text);
    final goal = WealthGoal(
      name: _name.text.trim(),
      target: Money.idr(_parse(_target.text)!),
      deadline: _deadline,
      monthlyContribution: monthly == null ? null : Money.idr(monthly),
      expectedReturnPercent: _parse(_return.text),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    final Result<void> result = await context.read<NetWorthCubit>().saveGoal(goal);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _busy = false;
        _error = f.message;
      }),
      (_) => Navigator.pop(context),
    );
  }

  /// Kosong boleh (opsional); kalau diisi harus angka dalam batas.
  static FormFieldValidator<String> _optional(double min, double max, String message) => (v) {
    if ((v ?? '').trim().isEmpty) return null;
    final n = _parse(v!);
    return n == null || n < min || n > max ? message : null;
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
              Text('Ubah target', style: text.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Nama target',
                controller: _name,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Nominal target (Rp)',
                helper: 'Tanpa titik ribuan',
                controller: _target,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = _parse(v ?? '');
                  return n == null || n <= 0 ? 'Target harus lebih dari 0' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_deadline == null ? 'Tenggat: belum ditentukan' : 'Tenggat: ${Fmt.date(_deadline)}'),
                    ),
                  ),
                  if (_deadline != null)
                    IconButton(
                      tooltip: 'Kosongkan tenggat',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Setoran bulanan (Rp, opsional)',
                controller: _monthly,
                keyboardType: TextInputType.number,
                validator: _optional(0, double.infinity, 'Isi angka 0 atau lebih'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Asumsi return per tahun (%, opsional)',
                controller: _return,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: _optional(-100, 100, 'Return −100 sampai 100%'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
