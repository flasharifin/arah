import 'package:arah/app/di.dart';
import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/utils/uuid.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';
import 'package:arah/features/portfolio/domain/usecases/record_purchase.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S17 — Catat pembelian. Dibuka dari detail posisi & watchlist dengan isian awal.
/// Sukses → Portofolio & Beranda dimuat ulang (keduanya hidup di shell, tersedia dari semua tab).
Future<void> showPurchaseForm(
  BuildContext context, {
  String? symbol,
  Exchange? exchange,
  String? broker,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PurchaseForm(
      record: sl<RecordPurchase>(),
      symbol: symbol,
      exchange: exchange ?? Exchange.idx,
      broker: broker,
    ),
  );
  if (saved != true || !context.mounted) return;
  context.read<PortfolioBloc>().add(const PortfolioRequested());
  context.read<DashboardCubit>().load();
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembelian tercatat')));
}

class _PurchaseForm extends StatefulWidget {
  const _PurchaseForm({required this.record, required this.exchange, this.symbol, this.broker});
  final RecordPurchase record;
  final Exchange exchange;
  final String? symbol;
  final String? broker;

  @override
  State<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<_PurchaseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _symbol = TextEditingController(text: widget.symbol);
  late final _broker = TextEditingController(text: widget.broker);
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _sector = TextEditingController();
  final _note = TextEditingController();
  late Exchange _exchange = widget.exchange;
  DateTime _date = DateTime.now();
  final _requestId = uuidV4();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_quantity, _price]) {
      c.addListener(() => setState(() {})); // pratinjau nilai pembelian
    }
  }

  @override
  void dispose() {
    for (final c in [_symbol, _broker, _quantity, _price, _sector, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
  static String? _positive(String? v) {
    final n = _parse(v ?? '');
    return n == null || n <= 0 ? 'Masukkan angka lebih dari 0' : null;
  }

  String? _optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  PositionPurchase? _draft() {
    final quantity = _parse(_quantity.text);
    final price = _parse(_price.text);
    if (quantity == null || quantity <= 0 || price == null || price <= 0) return null;
    return PositionPurchase(
      symbol: _symbol.text,
      exchange: _exchange,
      broker: _broker.text,
      quantity: quantity,
      price: price,
      date: _date,
      requestId: _requestId,
      sector: _optional(_sector),
      note: _optional(_note),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.record(_draft()!);
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
    final draft = _draft();
    final currency = _exchange == Exchange.idx ? Currency.idr : Currency.usd;
    final quantityLabel = _exchange == Exchange.idx ? 'Lot (100 lembar)' : 'Unit';
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
              Text('Catat pembelian', style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Mencatat pembelian yang sudah kamu lakukan. Kalau kode & broker sudah ada, '
                'lot ditambahkan dan harga rata-rata dihitung ulang.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              ChoiceChipBar<Exchange>(
                options: Exchange.values,
                selected: _exchange,
                labelOf: (e) => e.label,
                onSelected: _busy ? (_) {} : (e) => setState(() => _exchange = e),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Kode',
                controller: _symbol,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Kode wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Broker (opsional)', controller: _broker),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: quantityLabel,
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positive,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Harga beli per ${_exchange == Exchange.idx ? 'lembar' : 'unit'}',
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positive,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('Tanggal beli: ${Fmt.date(_date)}'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Sektor (opsional)', controller: _sector),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Catatan (opsional)', controller: _note),
              const SizedBox(height: AppSpacing.lg),
              InfoRow(
                label: 'Nilai pembelian',
                value: AmountText(draft == null ? null : Money(draft.total, currency)),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan pencatatan', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
