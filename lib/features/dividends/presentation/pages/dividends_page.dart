import 'package:arah/core/domain/money.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
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
          bottom: const SegmentedTabBar(tabs: ['Mendatang', 'Diterima']),
        ),
        body: BlocBuilder<DividendsCubit, ViewState<List<Dividend>>>(
          builder: (context, state) => ViewStateBuilder<List<Dividend>>(
            state: state,
            onRetry: cubit.load,
            builder: (context, items) {
              final now = DateTime.now();
              final paid = items.where((d) => d.isPaid(now)).toList();
              final upcoming = items.where((d) => !d.isPaid(now)).toList();
              final thisYear = paid.where((d) => d.paymentDate!.year == now.year).toList();
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
                      header: _ReceivedSummary(year: now.year, items: thisYear),
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
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[header!, const SizedBox(height: AppSpacing.md)],
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(empty, textAlign: TextAlign.center),
                ),
              for (final d in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _DividendCard(dividend: d, onTap: () => DividendsPage._openForm(context, d)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Total diterima tahun ini: rupiah dan dolar dirinci, lalu gabungan dalam rupiah dengan kurs server.
class _ReceivedSummary extends StatelessWidget {
  const _ReceivedSummary({required this.year, required this.items});
  final int year;
  final List<Dividend> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final usdToIdr = context.select<PortfolioBloc, double?>((b) => b.state.data.data?.usdToIdr);
    final t = dividendTotals(items, usdToIdr);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diterima tahun $year', style: text.bodySmall?.copyWith(color: AppColors.heroMuted)),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: t.combinedIdr == null
                ? Text('—', style: AppTypography.amountLarge.copyWith(color: Colors.white))
                : AmountText(Money.idr(t.combinedIdr!), style: AppTypography.amountLarge.copyWith(color: Colors.white)),
          ),
          if (t.usd != 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Rupiah', value: AmountText(Money.idr(t.idr)), onHero: true)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: StatTile(label: 'Dolar AS', value: AmountText(Money.usd(t.usd)), onHero: true)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              usdToIdr == null
                  ? 'Kurs belum tersedia, total gabungan menunggu data portofolio'
                  : 'Dolar dihitung dengan kurs sekarang ${Fmt.money(Money.idr(usdToIdr))} per USD',
              style: text.bodySmall?.copyWith(color: AppColors.heroMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status dividen dari tanggal bayar: tanpa tanggal = belum dijadwalkan, bukan "mendatang".
enum _Status {
  paid('Diterima', AppColors.primarySoft, AppColors.primary),
  upcoming('Mendatang', AppColors.accent, AppColors.onAccent),
  unscheduled('Belum dijadwalkan', AppColors.warningSoft, AppColors.warning);

  const _Status(this.label, this.background, this.foreground);
  final String label;
  final Color background;
  final Color foreground;
}

/// "hari ini", "besok", "4 hari lagi"; tanggal yang sudah lewat tidak diberi keterangan.
String? _countdown(DateTime date, DateTime now) {
  final days = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return switch (days) {
    < 0 => null,
    0 => 'hari ini',
    1 => 'besok',
    _ => '$days hari lagi',
  };
}

class _DividendCard extends StatelessWidget {
  const _DividendCard({required this.dividend, required this.onTap});
  final Dividend dividend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = dividend;
    final now = DateTime.now();
    final currency = d.received?.currency ?? Currency.idr;
    final status = d.paymentDate == null ? _Status.unscheduled : (d.isPaid(now) ? _Status.paid : _Status.upcoming);
    String dateLine(DateTime? date) {
      if (date == null) return 'Belum ditentukan';
      final left = status == _Status.paid ? null : _countdown(date, now);
      return left == null ? Fmt.date(date) : '${Fmt.date(date)} · $left';
    }

    return AppCard(
      onTap: onTap,
      semanticLabel: 'Ubah dividen ${d.symbol}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(d.symbol, style: text.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(color: status.background, borderRadius: BorderRadius.circular(999)),
                child: Text(status.label, style: text.labelSmall?.copyWith(color: status.foreground)),
              ),
            ],
          ),
          // Wrap: teks besar / layar sempit turun baris, tidak meluber.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('DPS ', style: text.bodySmall),
              AmountText(Money(d.dps, currency), style: text.bodySmall),
              Text(' per saham · pajak ${Fmt.number(d.taxPercent)}%', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(label: 'Ex-date', value: Text(dateLine(d.exDate))),
          InfoRow(label: 'Tanggal bayar', value: Text(dateLine(d.paymentDate))),
          InfoRow(
            label: status == _Status.paid ? 'Diterima bersih' : 'Perkiraan bersih',
            value: AmountText(d.received, style: text.titleSmall),
          ),
          if (d.note case final note? when note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: text.bodySmall),
          ],
        ],
      ),
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
