import 'package:arah/app/di.dart';
import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/utils/uuid.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/entities/sale.dart';
import 'package:arah/features/portfolio/domain/usecases/record_sale.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/purchase_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Toleransi pembulatan yang sama dengan backend saat membandingkan jumlah jual dengan lot.
const _epsilon = 0.000001;

/// Catat penjualan satu posisi. `true` bila posisi terjual habis (hilang dari daftar), supaya
/// pemanggil di layar detail bisa kembali sebelum data baru masuk.
Future<bool> showSaleForm(BuildContext context, Position position) async {
  ScaffoldMessenger.of(context).removeCurrentSnackBar(); // snackbar shell tampil di atas sheet, bisa menutupi Simpan
  final sold = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaleForm(position: position, record: sl<RecordSale>()),
  );
  if (sold == null || !context.mounted) return false;
  context.read<PortfolioBloc>().add(const PortfolioRequested());
  context.read<DashboardCubit>().load();
  context.read<NetWorthCubit>().load();
  context.read<SalesCubit>().load();
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penjualan tercatat')));
  return position.quantity - sold < _epsilon;
}

/// Dari tombol Catat: belum ada posisi terpilih, jadi pilih dulu.
Future<void> showSalePicker(BuildContext context) async {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  final positions = [...?context.read<PortfolioBloc>().state.data.data?.positions]
    ..sort((a, b) => a.symbol.compareTo(b.symbol));
  final picked = await showModalBottomSheet<Position>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          children: [
            Text('Pilih posisi yang dijual', style: text.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (positions.isEmpty) Text('Belum ada posisi yang bisa dijual.', style: text.bodyMedium),
            for (final p in positions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.symbol),
                subtitle: Text(
                  [
                    if (p.broker.isNotEmpty) p.broker,
                    '${Fmt.quantity(p.quantity)} ${p.exchange.quantityLabel}',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheet, p),
              ),
          ],
        ),
      );
    },
  );
  if (picked != null && context.mounted) await showSaleForm(context, picked);
}

class _SaleForm extends StatefulWidget {
  const _SaleForm({required this.position, required this.record});
  final Position position;
  final RecordSale record;

  @override
  State<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<_SaleForm> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  late final _price = TextEditingController(text: plainNumber(widget.position.lastPrice?.amount));
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  final _requestId = uuidV4();
  bool _busy = false;
  String? _error;

  Position get _position => widget.position;

  @override
  void initState() {
    super.initState();
    for (final c in [_quantity, _price]) {
      c.addListener(() => setState(() {})); // pratinjau hasil penjualan
    }
  }

  @override
  void dispose() {
    for (final c in [_quantity, _price, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateQuantity(String? v) {
    final n = parseNumberInput(v ?? '');
    if (n == null || n <= 0) return 'Masukkan angka lebih dari 0';
    if (n > _position.quantity + _epsilon) {
      return 'Maksimal ${Fmt.quantity(_position.quantity)} ${_position.exchange.quantityLabel}';
    }
    return null;
  }

  static String? _validatePrice(String? v) {
    final n = parseNumberInput(v ?? '');
    return n == null || n <= 0 ? 'Masukkan angka lebih dari 0' : null;
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

  /// Jual semua menghilangkan posisi dari daftar dan tidak bisa dibatalkan dari aplikasi.
  Future<bool> _confirmSellAll() async {
    final p = _position;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Jual semua ${p.symbol}?'),
        content: Text(
          'Seluruh ${Fmt.quantity(p.quantity)} ${p.exchange.quantityLabel}'
          '${p.broker.isEmpty ? '' : ' di ${p.broker}'} dicatat terjual dan posisi ini hilang dari daftar. '
          'Catatan ini tidak bisa dibatalkan dari aplikasi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Ya, jual semua')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = parseNumberInput(_quantity.text)!;
    if (_position.quantity - quantity < _epsilon && !await _confirmSellAll()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final note = _note.text.trim();
    final result = await widget.record(
      PositionSale(
        positionId: _position.id,
        quantity: quantity,
        price: parseNumberInput(_price.text)!,
        date: _date,
        requestId: _requestId,
        note: note.isEmpty ? null : note,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _busy = false;
        _error = f.message;
      }),
      (_) => Navigator.pop(context, quantity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _position;
    final label = p.exchange.quantityLabel;
    final quantity = parseNumberInput(_quantity.text);
    final price = parseNumberInput(_price.text);
    final valid = quantity != null && quantity > 0 && price != null && price > 0;
    final units = valid ? quantity * p.exchange.unitsPerQuantity : 0.0;
    final avg = p.avgPrice.amount;
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
              Text('Catat penjualan ${p.symbol}', style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Mencatat penjualan yang sudah kamu lakukan di broker. '
                'Jumlah posisi berkurang, harga rata-rata sisanya tidak berubah.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              InfoRow(label: 'Broker', value: Text(p.broker.isEmpty ? Fmt.missing : p.broker)),
              InfoRow(label: 'Dimiliki', value: Text('${Fmt.quantity(p.quantity)} $label')),
              InfoRow(label: 'Harga rata-rata', value: AmountText(p.avgPrice)),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: p.exchange == Exchange.idx ? 'Lot dijual (100 lembar)' : 'Unit dijual',
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validateQuantity,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : () => _quantity.text = plainNumber(p.quantity),
                  // Tema memberi lebar minimum tak hingga; tombol ini cukup selebar isinya.
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('Jual semua'),
                ),
              ),
              AppTextField(
                label: 'Harga jual per ${p.exchange == Exchange.idx ? 'lembar' : 'unit'}',
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePrice,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('Tanggal jual: ${Fmt.date(_date)}'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Catatan (opsional)', controller: _note),
              const SizedBox(height: AppSpacing.lg),
              InfoRow(label: 'Nilai penjualan', value: AmountText(valid ? Money(units * price, p.currency) : null)),
              InfoRow(
                label: 'Perkiraan realized PnL',
                value: valid
                    ? PnlText(
                        amount: Money(units * (price - avg), p.currency),
                        percent: avg > 0 ? (price - avg) / avg * 100 : null,
                        stacked: true,
                      )
                    : const Text(Fmt.missing),
              ),
              Text('Belum termasuk biaya broker.', style: text.bodySmall),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan penjualan', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
