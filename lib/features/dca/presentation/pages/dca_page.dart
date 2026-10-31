import 'package:arah/core/domain/money.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/utils/uuid.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';
import 'package:arah/features/dca/presentation/bloc/dca_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S10 — DCA: Rencana (buat/ubah/hapus, catat pelaksanaan), Riwayat, Simulasi.
class DcaPage extends StatelessWidget {
  const DcaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DcaCubit>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DCA'),
          actions: [
            BlocBuilder<DcaCubit, ViewState<DcaOverview>>(
              builder: (context, state) => IconButton(
                tooltip: 'Tambah rencana',
                icon: const Icon(Icons.add),
                onPressed: state.data == null
                    ? null
                    : () => _openSheet(context, _PlanForm(data: state.data!)),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Rencana'),
              Tab(text: 'Riwayat'),
              Tab(text: 'Simulasi'),
            ],
          ),
        ),
        body: BlocBuilder<DcaCubit, ViewState<DcaOverview>>(
          builder: (context, state) => ViewStateBuilder<DcaOverview>(
            state: state,
            onRetry: cubit.load,
            builder: (context, data) => TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: cubit.load,
                  child: _Plans(data: data),
                ),
                RefreshIndicator(
                  onRefresh: cubit.load,
                  child: _Records(records: data.records),
                ),
                _Simulation(positions: data.positions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openSheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BlocProvider.value(value: context.read<DcaCubit>(), child: child),
);

double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

String? _positive(String? v) {
  final n = _parse(v ?? '');
  return n == null || n <= 0 ? 'Masukkan angka lebih dari 0' : null;
}

/// Kerangka sheet form: judul, isi, error, tombol simpan, aksi tambahan.
class _SheetForm extends StatelessWidget {
  const _SheetForm({
    required this.formKey,
    required this.title,
    required this.children,
    required this.busy,
    required this.onSave,
    this.error,
    this.extra,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> children;
  final bool busy;
  final VoidCallback onSave;
  final String? error;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              ...children,
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan', busy: busy, onPressed: onSave),
              ?extra,
            ],
          ),
        ),
      ),
    );
  }
}

/// Status kirim form yang dipakai bersama tiap sheet.
mixin _Submitting<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  Future<void> submit(Future<Result<void>> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    final result = await action();
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        busy = false;
        error = f.message;
      }),
      (_) => Navigator.pop(context),
    );
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.data});
  final DcaOverview data;

  @override
  Widget build(BuildContext context) {
    if (data.plans.isEmpty) {
      return const EmptyView(
        icon: Icons.event_repeat_outlined,
        title: 'Belum ada rencana DCA',
        message: 'Tambah rencana beli berkala dengan tombol + di atas.',
      );
    }
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        for (final p in data.plans)
          () {
            final currency = data.positionOf(p)?.currency;
            // Mata uang dari posisinya; posisi sudah dijual habis → angka biasa.
            Widget amount(double v) =>
                currency == null ? Text(Fmt.number(v)) : AmountText(Money(v, currency));
            return PageBody(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  onTap: () => _openSheet(context, _PlanForm(data: data, plan: p)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(p.symbol, style: text.titleMedium)),
                          Text(p.isActive ? p.frequencyLabel : 'Nonaktif', style: text.bodySmall),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InfoRow(label: 'Budget per periode', value: amount(p.budget)),
                      InfoRow(label: 'Target harga', value: amount(p.targetPrice)),
                      InfoRow(label: 'Jadwal berikutnya', value: Text(Fmt.date(p.nextDate))),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: p.isActive ? () => _openSheet(context, _ExecutionForm(plan: p)) : null,
                        child: const Text('Catat pelaksanaan'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

class _Records extends StatelessWidget {
  const _Records({required this.records});
  final List<DcaRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyView(icon: Icons.history, title: 'Belum ada pelaksanaan DCA');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        for (final r in records)
          ListTile(
            title: Text('${r.symbol} · ${Fmt.number(r.quantity)} @ ${Fmt.number(r.price)}'),
            subtitle: Text(Fmt.date(r.date)),
            trailing: Text(Fmt.number(r.total)),
          ),
      ],
    );
  }
}

const _frequencies = ['weekly', 'monthly', 'custom'];
String _frequencyLabel(String f) => switch (f) {
  'weekly' => 'Mingguan',
  'monthly' => 'Bulanan',
  _ => 'Kustom',
};

class _PlanForm extends StatefulWidget {
  const _PlanForm({required this.data, this.plan});
  final DcaOverview data;
  final DcaPlan? plan;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> with _Submitting {
  final _formKey = GlobalKey<FormState>();
  late final _budget = TextEditingController(text: widget.plan?.budget.toString());
  late final _target = TextEditingController(text: widget.plan?.targetPrice.toString());
  late Position? _position = widget.plan == null ? widget.data.positions.firstOrNull : null;
  late String _frequency = widget.plan?.frequency ?? 'monthly';
  late DateTime? _nextDate = widget.plan?.nextDate;
  late bool _active = widget.plan?.isActive ?? true;

  @override
  void dispose() {
    _budget.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _nextDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final plan = widget.plan;
    final draft = DcaPlanDraft(
      portfolioId: plan?.portfolioId ?? _position!.id,
      symbol: plan?.symbol ?? _position!.symbol,
      targetPrice: _parse(_target.text)!,
      budget: _parse(_budget.text)!,
      frequency: _frequency,
      isActive: _active,
      nextDate: _nextDate,
    );
    submit(() => context.read<DcaCubit>().savePlan(draft, id: plan?.id));
  }

  Future<void> _delete() async {
    final plan = widget.plan!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus rencana DCA ${plan.symbol}?'),
        content: const Text('Riwayat pelaksanaan & posisi tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true && mounted) submit(() => context.read<DcaCubit>().deletePlan(plan.id));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.plan != null;
    if (!editing && widget.data.positions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('Rencana DCA dibuat untuk posisi yang sudah ada. Catat pembelian dulu di Portofolio.'),
      );
    }
    return _SheetForm(
      formKey: _formKey,
      title: editing ? 'Ubah rencana ${widget.plan!.symbol}' : 'Rencana DCA baru',
      busy: busy,
      error: error,
      onSave: _save,
      extra: editing
          ? TextButton(onPressed: busy ? null : _delete, child: const Text('Hapus rencana'))
          : null,
      children: [
        if (!editing) ...[
          DropdownButtonFormField<Position>(
            isExpanded: true, // nama posisi panjang tidak meluap di layar 360 px
            initialValue: _position,
            decoration: const InputDecoration(labelText: 'Posisi'),
            items: [
              for (final p in widget.data.positions)
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
          label: 'Budget per periode',
          controller: _budget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _positive,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Target harga beli',
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _positive,
        ),
        const SizedBox(height: AppSpacing.md),
        ChoiceChipBar<String>(
          options: _frequencies,
          selected: _frequency,
          labelOf: _frequencyLabel,
          onSelected: (f) => setState(() => _frequency = f),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: busy ? null : _pickDate,
          icon: const Icon(Icons.event_outlined),
          label: Text('Jadwal berikutnya: ${_nextDate == null ? 'Belum ditentukan' : Fmt.date(_nextDate)}'),
        ),
        if (editing)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rencana aktif'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
      ],
    );
  }
}

class _ExecutionForm extends StatefulWidget {
  const _ExecutionForm({required this.plan});
  final DcaPlan plan;

  @override
  State<_ExecutionForm> createState() => _ExecutionFormState();
}

class _ExecutionFormState extends State<_ExecutionForm> with _Submitting {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  DateTime _date = DateTime.now();
  // Satu requestId per form: tombol Simpan ditekan ulang setelah gagal jaringan tidak mencatat dua kali.
  final _requestId = uuidV4();

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final execution = DcaExecution(
      plan: widget.plan,
      quantity: _parse(_quantity.text)!,
      price: _parse(_price.text)!,
      date: _date,
      requestId: _requestId,
    );
    submit(() => context.read<DcaCubit>().record(execution));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetForm(
      formKey: _formKey,
      title: 'Catat pelaksanaan ${widget.plan.symbol}',
      busy: busy,
      error: error,
      onSave: _save,
      children: [
        Text(
          'Mencatat pembelian yang sudah kamu lakukan; lot posisi ikut bertambah.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Jumlah (lot untuk IDX, unit untuk US/Crypto)',
          controller: _quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _positive,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Harga beli',
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _positive,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: busy ? null : _pickDate,
          icon: const Icon(Icons.event_outlined),
          label: Text('Tanggal beli: ${Fmt.date(_date)}'),
        ),
      ],
    );
  }
}

/// Simulasi: tidak menyimpan apa pun, hanya menghitung harga rata-rata kalau membeli lagi.
class _Simulation extends StatefulWidget {
  const _Simulation({required this.positions});
  final List<Position> positions;

  @override
  State<_Simulation> createState() => _SimulationState();
}

class _SimulationState extends State<_Simulation> {
  late Position? _position = widget.positions.firstOrNull;
  final _quantity = TextEditingController();
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_quantity, _price]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    if (position == null) {
      return const EmptyView(icon: Icons.calculate_outlined, title: 'Belum ada posisi untuk disimulasikan');
    }
    final quantity = _parse(_quantity.text);
    final price = _parse(_price.text);
    final result = quantity != null && quantity > 0 && price != null && price > 0
        ? simulateDca(position, quantity: quantity, price: price)
        : null;
    Money money(double v) => Money(v, position.currency);
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Position>(
                isExpanded: true, // nama posisi panjang tidak meluap di layar 360 px
                initialValue: position,
                decoration: const InputDecoration(labelText: 'Posisi'),
                items: [
                  for (final p in widget.positions)
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Saat ini ${Fmt.number(position.quantity)} ${position.exchange.quantityLabel} @ ${Fmt.money(position.avgPrice)}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Beli lagi (${position.exchange.quantityLabel})',
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Di harga',
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (result == null)
                Text('Isi jumlah dan harga untuk melihat hasil simulasi.', style: text.bodySmall)
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoRow(label: 'Harga rata-rata baru', value: AmountText(money(result.newAvgPrice))),
                      InfoRow(
                        label: 'Total kepemilikan',
                        value: Text('${Fmt.number(result.totalQuantity)} ${position.exchange.quantityLabel}'),
                      ),
                      InfoRow(label: 'Tambahan modal', value: AmountText(money(result.additionalCost))),
                      InfoRow(label: 'Total modal', value: AmountText(money(result.totalCost))),
                      if (result.marketGap != null)
                        InfoRow(
                          label: result.marketGap! > 0 ? 'Masih rugi per lembar' : 'Sudah profit per lembar',
                          value: AmountText(money(result.marketGap!.abs())),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text('Simulasi saja; tidak mencatat transaksi.', style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
