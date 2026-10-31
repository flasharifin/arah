import 'package:arah/core/domain/money.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S11 — Dividen: Mendatang / Diterima + total diterima tahun ini; tambah, ubah, hapus.
class DividendsPage extends StatelessWidget {
  const DividendsPage({super.key});

  static void _openForm(BuildContext context, [Dividend? dividend]) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: context.read<DividendsCubit>(),
      child: _DividendForm(dividend: dividend),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DividendsCubit>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dividen'),
          actions: [
            IconButton(tooltip: 'Tambah dividen', icon: const Icon(Icons.add), onPressed: () => _openForm(context)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mendatang'),
              Tab(text: 'Diterima'),
            ],
          ),
        ),
        body: BlocBuilder<DividendsCubit, ViewState<List<Dividend>>>(
          builder: (context, state) => ViewStateBuilder<List<Dividend>>(
            state: state,
            onRetry: cubit.load,
            builder: (context, items) {
              final now = DateTime.now();
              final paid = items.where((d) => d.isPaid(now)).toList();
              final upcoming = items.where((d) => !d.isPaid(now)).toList();
              final thisYear = paid
                  .where((d) => d.paymentDate!.year == now.year)
                  .fold<double>(0, (sum, d) => sum + (d.received?.amount ?? 0));
              return TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: cubit.load,
                    child: _DividendList(items: upcoming, empty: 'Belum ada jadwal dividen'),
                  ),
                  RefreshIndicator(
                    onRefresh: cubit.load,
                    child: _DividendList(
                      items: paid,
                      empty: 'Belum ada dividen diterima',
                      header: AppCard(
                        child: InfoRow(label: 'Diterima tahun ${now.year}', value: AmountText(Money.idr(thisYear))),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Tanggal kosong ditulis apa adanya, bukan diisi perkiraan.
String _dateOrUnset(DateTime? d) => d == null ? 'Belum ditentukan' : Fmt.date(d);

class _DividendList extends StatelessWidget {
  const _DividendList({required this.items, required this.empty, this.header});
  final List<Dividend> items;
  final String empty;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        if (header != null) PageBody(child: header!),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(empty, textAlign: TextAlign.center),
          ),
        for (final d in items)
          ListTile(
            title: Text('${d.symbol} · ${Fmt.number(d.dps)} per saham'),
            subtitle: Text('Ex-date: ${_dateOrUnset(d.exDate)} · Bayar: ${_dateOrUnset(d.paymentDate)}'),
            trailing: d.received == null ? null : AmountText(d.received),
            onTap: () => DividendsPage._openForm(context, d),
          ),
      ],
    );
  }
}

/// Tanggal opsional: ketuk untuk memilih, ✕ untuk mengosongkan.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.event_outlined),
            label: Text('$label: ${_dateOrUnset(value)}', overflow: TextOverflow.ellipsis),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) onChanged(picked);
            },
          ),
        ),
        if (value != null)
          IconButton(tooltip: 'Kosongkan $label', icon: const Icon(Icons.close), onPressed: () => onChanged(null)),
      ],
    );
  }
}

class _DividendForm extends StatefulWidget {
  const _DividendForm({this.dividend});
  final Dividend? dividend;

  @override
  State<_DividendForm> createState() => _DividendFormState();
}

class _DividendFormState extends State<_DividendForm> {
  final _formKey = GlobalKey<FormState>();
  late final _dps = TextEditingController(text: widget.dividend?.dps.toString());
  late final _tax = TextEditingController(text: (widget.dividend?.taxPercent ?? 10).toString());
  late final _note = TextEditingController(text: widget.dividend?.note);
  late Position? _position = widget.dividend == null ? context.read<DividendsCubit>().positions.firstOrNull : null;
  late DateTime? _cum = widget.dividend?.cumDate;
  late DateTime? _ex = widget.dividend?.exDate;
  late DateTime? _pay = widget.dividend?.paymentDate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_dps, _tax, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

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
    final d = widget.dividend;
    final draft = DividendDraft(
      portfolioId: d?.portfolioId ?? _position!.id,
      symbol: d?.symbol ?? _position!.symbol,
      dps: _parse(_dps.text)!,
      taxPercent: _parse(_tax.text)!,
      cumDate: _cum,
      exDate: _ex,
      paymentDate: _pay,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    _run(() => context.read<DividendsCubit>().save(draft, id: d?.id));
  }

  Future<void> _delete() async {
    final d = widget.dividend!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus dividen ${d.symbol}?'),
        content: Text('Catatan dividen ${Fmt.number(d.dps)} per saham (bayar ${_dateOrUnset(d.paymentDate)}) dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true && mounted) _run(() => context.read<DividendsCubit>().remove(d.id));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.dividend != null;
    final positions = context.read<DividendsCubit>().positions;
    if (!editing && positions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('Dividen dicatat untuk posisi yang dimiliki. Catat pembelian dulu di Portofolio.'),
      );
    }
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
              Text(editing ? 'Ubah dividen ${widget.dividend!.symbol}' : 'Tambah dividen', style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text('Jumlah diterima dihitung otomatis dari lot posisi, DPS, dan pajak.', style: text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              if (!editing) ...[
                DropdownButtonFormField<Position>(
                  isExpanded: true,
                  initialValue: _position,
                  decoration: const InputDecoration(labelText: 'Posisi'),
                  items: [
                    for (final p in positions)
                      DropdownMenuItem(
                        value: p,
                        child: Text(
                          p.broker.isEmpty ? p.symbol : '${p.symbol} · ${p.broker}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (p) => setState(() => _position = p),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Dividen per saham (DPS)',
                controller: _dps,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _parse(v ?? '');
                  return n == null || n <= 0 ? 'DPS harus lebih dari 0' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Pajak (%)',
                controller: _tax,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _parse(v ?? '');
                  return n == null || n < 0 || n > 100 ? 'Pajak 0–100%' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _DateField(label: 'Cum date', value: _cum, onChanged: (d) => setState(() => _cum = d)),
              _DateField(label: 'Ex date', value: _ex, onChanged: (d) => setState(() => _ex = d)),
              _DateField(label: 'Tanggal bayar', value: _pay, onChanged: (d) => setState(() => _pay = d)),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Catatan (opsional)', controller: _note),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
              if (editing) TextButton(onPressed: _busy ? null : _delete, child: const Text('Hapus dividen')),
            ],
          ),
        ),
      ),
    );
  }
}
