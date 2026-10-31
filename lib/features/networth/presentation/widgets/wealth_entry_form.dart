import 'package:arah/core/error/result.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tambah ([item] `null`) atau ubah/hapus aset manual & utang.
void showWealthEntryForm(BuildContext context, WealthKind kind, {WealthItem? item}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BlocProvider.value(
    value: context.read<NetWorthCubit>(),
    child: _WealthEntryForm(kind: kind, id: item?.id, entry: item?.entry),
  ),
);

class _WealthEntryForm extends StatefulWidget {
  const _WealthEntryForm({required this.kind, this.id, this.entry});
  final WealthKind kind;
  final String? id;
  final ManualEntry? entry;

  @override
  State<_WealthEntryForm> createState() => _WealthEntryFormState();
}

class _WealthEntryFormState extends State<_WealthEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.entry?.name);
  late final _note = TextEditingController(text: widget.entry?.note);
  late final _amount = TextEditingController(
    text: switch (widget.entry?.amount) {
      null => '',
      final v when v == v.roundToDouble() => v.toInt().toString(),
      final v => v.toString(),
    },
  );
  late String _category = widget.entry?.category ?? _categories.keys.first;
  late String _currency = widget.entry?.currency ?? 'IDR';
  bool _busy = false;
  String? _error;

  bool get _isAsset => widget.kind == WealthKind.asset;
  Map<String, String> get _categories => _isAsset ? assetCategories : liabilityCategories;
  String get _noun => _isAsset ? 'aset' : 'utang';

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  // Sama dengan form web: kategori emas → satuan gram; keluar dari emas → kembali rupiah.
  void _onCategory(String c) => setState(() {
    _category = c;
    if (c == 'gold') {
      _currency = 'GOLD';
    } else if (_currency == 'GOLD') {
      _currency = 'IDR';
    }
  });

  Future<void> _run(Future<Result<void>> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await action();
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _busy = false;
        _error = f.message;
      }),
      (_) => Navigator.pop(context),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final entry = ManualEntry(
      kind: widget.kind,
      name: _name.text.trim(),
      category: _category,
      amount: _parse(_amount.text)!,
      currency: _isAsset ? _currency : 'IDR',
      note: _note.text.trim(),
    );
    _run(() => context.read<NetWorthCubit>().save(entry, id: widget.id));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${widget.entry!.name}?'),
        content: Text('Data $_noun ini dihapus dari web dan aplikasi. Snapshot lama tidak berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _run(() => context.read<NetWorthCubit>().remove(widget.kind, widget.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;
    final text = Theme.of(context).textTheme;
    // Data lama bisa berkategori stock/crypto yang tidak ditawarkan; tetap tampilkan supaya tidak berubah diam-diam.
    final categories = {..._categories, if (!_categories.containsKey(_category)) _category: _category};
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
              Text(editing ? 'Ubah $_noun' : 'Tambah $_noun', style: text.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: _isAsset ? 'Nama aset' : 'Nama utang',
                controller: _name,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [
                  for (final MapEntry(:key, :value) in categories.entries)
                    DropdownMenuItem(
                      value: key,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (c) => _onCategory(c!),
              ),
              if (_isAsset) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  // key: ganti kategori emas mengubah mata uang dari luar dropdown
                  key: ValueKey(_currency),
                  isExpanded: true,
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Mata uang'),
                  items: [
                    for (final MapEntry(:key, :value) in entryCurrencies.entries)
                      DropdownMenuItem(value: key, child: Text(value)),
                  ],
                  onChanged: (c) => setState(() => _currency = c!),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: switch ((_isAsset, _currency)) {
                  (false, _) => 'Sisa utang (Rp)',
                  (true, 'USD') => 'Nilai (US\$)',
                  (true, 'GOLD') => 'Jumlah (gram)',
                  _ => 'Nilai (Rp)',
                },
                helper: _currency == 'IDR' || !_isAsset
                    ? 'Tanpa titik ribuan'
                    : 'Dikonversi ke rupiah dengan kurs terbaru di server',
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _parse(v ?? '');
                  return n == null || n < 0 ? 'Isi angka 0 atau lebih' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Catatan (opsional)', controller: _note),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
              if (editing) TextButton(onPressed: _busy ? null : _delete, child: Text('Hapus $_noun')),
            ],
          ),
        ),
      ),
    );
  }
}
