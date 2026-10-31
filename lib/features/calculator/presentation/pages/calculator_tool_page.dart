import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/calculator/domain/entities/calculators.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';
import 'package:arah/features/calculator/presentation/bloc/insights_cubits.dart';
import 'package:arah/features/calculator/presentation/pages/calculator_page.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/purchase_form.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Layar fokus satu alat: input di atas, asumsi, hasil, penjelasan.
class CalculatorToolPage extends StatelessWidget {
  const CalculatorToolPage({super.key, required this.tool});
  final CalculatorTool tool;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: switch (tool) {
        CalculatorTool.lot => const _LotTool(),
        CalculatorTool.sizing => const _PortfolioTool(builder: _sizing),
        CalculatorTool.bep => const _PortfolioTool(builder: _bep),
        CalculatorTool.rebalance => const _PortfolioTool(builder: _rebalance),
        CalculatorTool.fi => const _PortfolioTool(builder: _fi),
        CalculatorTool.invisible => const _InvisibleCostTool(),
        CalculatorTool.timeline => const _TimelineTool(),
      },
    );
  }

  static Widget _sizing(Portfolio p) => _SizingTool(portfolio: p);
  static Widget _bep(Portfolio p) => _BepTool(portfolio: p);
  static Widget _rebalance(Portfolio p) => _RebalanceTool(portfolio: p);
  static Widget _fi(Portfolio p) => _FiTool(portfolio: p);
}

double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
String _plain(double v) => v == v.roundToDouble() ? Fmt.number(v) : Fmt.number(double.parse(v.toStringAsFixed(4)));

/// Kolom angka yang membangun ulang hasil saat diketik.
class _Num extends StatelessWidget {
  const _Num(this.label, this.controller, {this.helper, this.signed = false});
  final String label;
  final TextEditingController controller;
  final String? helper;
  final bool signed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: AppTextField(
      label: label,
      helper: helper,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
    ),
  );
}

/// Basis alat berisi form: controller dibuat sekali dan setiap ketikan membangun ulang hasil.
abstract class _FormState<T extends StatefulWidget> extends State<T> {
  final _controllers = <TextEditingController>[];

  TextEditingController field([String text = '']) {
    final c = TextEditingController(text: text)..addListener(() => setState(() {}));
    _controllers.add(c);
    return c;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

Widget _body(List<Widget> children) => ListView(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
  children: [for (final c in children) PageBody(child: c)],
);

Widget _result(BuildContext context, String title, List<Widget> rows) => AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      ...rows,
    ],
  ),
);

Widget _hint(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
  child: Text(text, style: Theme.of(context).textTheme.bodySmall),
);

/// S13: hanya mengisi draft form pencatatan, tidak menyimpan transaksi.
Widget _useInForm(
  BuildContext context, {
  required Exchange exchange,
  required double quantity,
  required double price,
  String? symbol,
  String? broker,
}) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.md),
  child: OutlinedButton.icon(
    onPressed: () =>
        showPurchaseForm(context, symbol: symbol, exchange: exchange, broker: broker, quantity: quantity, price: price),
    icon: const Icon(Icons.edit_note),
    label: const Text('Gunakan pada form pencatatan'),
  ),
);

Money _money(double v, Exchange e) => Money(v, e == Exchange.idx ? Currency.idr : Currency.usd);

Widget _exchangeChips(Exchange selected, ValueChanged<Exchange> onSelected) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: ChoiceChipBar<Exchange>(
    options: Exchange.values,
    selected: selected,
    labelOf: (e) => e.label,
    onSelected: onSelected,
  ),
);

/// Alat yang butuh posisi & kurs dari Portofolio (bloc sesi yang sudah dimuat).
class _PortfolioTool extends StatelessWidget {
  const _PortfolioTool({required this.builder});
  final Widget Function(Portfolio portfolio) builder;

  @override
  Widget build(BuildContext context) => BlocBuilder<PortfolioBloc, PortfolioState>(
    builder: (context, state) => ViewStateBuilder<Portfolio>(
      state: state.data,
      onRetry: () => context.read<PortfolioBloc>().add(const PortfolioRequested()),
      builder: (context, p) => builder(p),
    ),
  );
}

// ── Lot ──────────────────────────────────────────────────────────────────────

class _LotTool extends StatefulWidget {
  const _LotTool();

  @override
  State<_LotTool> createState() => _LotToolState();
}

class _LotToolState extends _FormState<_LotTool> {
  var _exchange = Exchange.idx;
  late final _budget = field();
  late final _price = field();
  late final _fee = field('0.15');

  @override
  Widget build(BuildContext context) {
    final cur = _exchange == Exchange.idx ? 'Rp' : r'US$';
    final r = lotCalc(
      exchange: _exchange,
      budget: _parse(_budget.text) ?? 0,
      price: _parse(_price.text) ?? 0,
      feePercent: _parse(_fee.text) ?? 0,
    );
    return _body([
      _exchangeChips(_exchange, (e) => setState(() => _exchange = e)),
      _Num('Dana ($cur)', _budget),
      _Num('Harga per ${_exchange == Exchange.idx ? 'lembar' : 'unit'} ($cur)', _price),
      if (_exchange != Exchange.idx) _Num('Biaya transaksi (%)', _fee),
      _hint(
        context,
        _exchange == Exchange.idx
            ? 'Asumsi biaya IDX: beli 0,15%, jual 0,25%. 1 lot = 100 lembar.'
            : 'Pecahan unit sampai 4 desimal.',
      ),
      if (r == null)
        _hint(context, 'Isi dana dan harga. Dana harus cukup untuk minimal 1 ${_exchange.quantityLabel}.')
      else
        _result(context, 'Hasil', [
          InfoRow(label: 'Bisa dibeli', value: Text('${_plain(r.quantity)} ${_exchange.quantityLabel}')),
          if (_exchange == Exchange.idx) InfoRow(label: 'Lembar', value: Text(Fmt.number(r.units))),
          InfoRow(label: 'Nilai beli', value: AmountText(_money(r.cost, _exchange))),
          InfoRow(label: 'Biaya', value: AmountText(_money(r.fee, _exchange))),
          InfoRow(label: 'Total keluar', value: AmountText(_money(r.total, _exchange))),
          InfoRow(label: 'Sisa dana', value: AmountText(_money(r.left, _exchange))),
          InfoRow(label: 'Harga impas (BEP)', value: AmountText(_money(r.bep, _exchange))),
        ]),
      if (r != null) _useInForm(context, exchange: _exchange, quantity: r.quantity, price: _parse(_price.text)!),
    ]);
  }
}

// ── Position sizing ──────────────────────────────────────────────────────────

class _SizingTool extends StatefulWidget {
  const _SizingTool({required this.portfolio});
  final Portfolio portfolio;

  @override
  State<_SizingTool> createState() => _SizingToolState();
}

class _SizingToolState extends _FormState<_SizingTool> {
  var _exchange = Exchange.idx;
  late final _entry = field();
  late final _stop = field();
  late final _risk = field('1');

  @override
  Widget build(BuildContext context) {
    final total = widget.portfolio.totalValueIdr;
    final cur = _exchange == Exchange.idx ? 'Rp' : r'US$';
    final risk = _parse(_risk.text) ?? 0;
    final r = positionSizing(
      exchange: _exchange,
      portfolioIdr: total,
      entry: _parse(_entry.text) ?? 0,
      stopLoss: _parse(_stop.text) ?? 0,
      riskPercent: risk,
      usdToIdr: widget.portfolio.usdToIdr ?? 0,
    );
    return _body([
      _hint(context, 'Total portofolio ${Fmt.money(Money.idr(total))} (nilai pasar, atau modal bila harga belum ada).'),
      _exchangeChips(_exchange, (e) => setState(() => _exchange = e)),
      _Num('Harga entry ($cur)', _entry),
      _Num('Stop loss ($cur)', _stop),
      _Num('Risiko maksimal (% porto)', _risk, helper: 'Umumnya 1–2%'),
      if (risk > 100)
        _hint(context, 'Risiko maksimal 100%.')
      else if (r == null)
        _hint(context, 'Isi harga entry dan stop loss; stop loss harus di bawah entry.')
      else if (r.quantity == 0)
        _hint(
          context,
          'Risiko terlalu kecil untuk 1 ${_exchange.quantityLabel}. Naikkan risiko % atau perlebar jarak ke stop loss.',
        )
      else
        _result(context, 'Hasil', [
          InfoRow(label: 'Jumlah ideal', value: Text('${Fmt.number(r.quantity)} ${_exchange.quantityLabel}')),
          InfoRow(label: 'Modal dibutuhkan', value: AmountText(Money.idr(r.capitalIdr))),
          InfoRow(label: 'Rugi bila kena stop loss', value: AmountText(Money.idr(r.maxLossIdr))),
          InfoRow(label: 'Risiko aktual', value: Text(Fmt.percent(r.riskPercent, signed: false))),
        ]),
      if (risk <= 100 && r != null && r.quantity > 0)
        _useInForm(context, exchange: _exchange, quantity: r.quantity, price: _parse(_entry.text)!),
    ]);
  }
}

// ── BEP & averaging ──────────────────────────────────────────────────────────

class _BepTool extends StatefulWidget {
  const _BepTool({required this.portfolio});
  final Portfolio portfolio;

  @override
  State<_BepTool> createState() => _BepToolState();
}

class _BepToolState extends _FormState<_BepTool> {
  late Position? _position = widget.portfolio.positions.firstOrNull;
  late final _extra = field();
  late final _price = field(_lastPriceText(_position));

  static String _lastPriceText(Position? p) => switch (p?.lastPrice?.amount) {
    null => '',
    final v => v == v.roundToDouble() ? v.toInt().toString() : v.toString(),
  };

  @override
  Widget build(BuildContext context) {
    final p = _position;
    if (p == null) {
      return const EmptyView(title: 'Belum ada posisi', message: 'Catat pembelian dulu di Portofolio.');
    }
    final bep = breakEvenPrice(p.avgPrice.amount, p.exchange);
    final last = p.lastPrice?.amount;
    final extra = _parse(_extra.text) ?? 0;
    final price = _parse(_price.text) ?? 0;
    final sim = extra > 0 && price > 0 ? averaging(p, extraQuantity: extra, price: price) : null;
    Money m(double v) => Money(v, p.currency);
    return _body([
      DropdownButtonFormField<Position>(
        isExpanded: true,
        initialValue: p,
        decoration: const InputDecoration(labelText: 'Posisi'),
        items: [
          for (final x in widget.portfolio.positions)
            DropdownMenuItem(
              value: x,
              child: Text(x.broker.isEmpty ? x.symbol : '${x.symbol} · ${x.broker}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (x) => setState(() {
          _position = x;
          _price.text = _lastPriceText(x);
        }),
      ),
      const SizedBox(height: AppSpacing.md),
      _result(context, 'Sekarang', [
        InfoRow(label: 'Harga rata-rata', value: AmountText(p.avgPrice)),
        InfoRow(label: 'Harga impas (BEP)', value: AmountText(m(bep))),
        InfoRow(label: 'Harga terakhir', value: AmountText(p.lastPrice)),
        if (last != null && last > 0)
          InfoRow(
            label: 'Jarak ke BEP',
            value: Text(
              last >= bep ? 'Sudah di atas BEP' : 'Perlu naik ${Fmt.percent((bep - last) / last * 100, signed: false)}',
            ),
          ),
      ]),
      _hint(
        context,
        p.exchange == Exchange.idx ? 'BEP memasukkan biaya beli 0,15% dan jual 0,25%.' : 'BEP tanpa biaya transaksi.',
      ),
      _Num('Beli tambahan (${p.exchange.quantityLabel})', _extra),
      _Num('Di harga', _price, helper: 'Terisi harga terakhir; ubah untuk skenario lain'),
      if (sim != null)
        _result(context, 'Skenario tambahan', [
          InfoRow(label: 'Harga rata-rata baru', value: AmountText(m(sim.newAvg))),
          InfoRow(label: 'BEP baru', value: AmountText(m(sim.newBep))),
          InfoRow(
            label: 'Jarak harga ke BEP baru',
            value: Text(
              sim.percentToBep <= 0
                  ? 'Sudah di atas BEP'
                  : 'Perlu naik ${Fmt.percent(sim.percentToBep, signed: false)}',
            ),
          ),
          InfoRow(label: 'Dana tambahan', value: AmountText(m(sim.extraCost))),
        ]),
      if (sim != null)
        _useInForm(context, exchange: p.exchange, quantity: extra, price: price, symbol: p.symbol, broker: p.broker),
    ]);
  }
}

// ── Rebalancing ──────────────────────────────────────────────────────────────

class _RebalanceTool extends StatefulWidget {
  const _RebalanceTool({required this.portfolio});
  final Portfolio portfolio;

  @override
  State<_RebalanceTool> createState() => _RebalanceToolState();
}

class _RebalanceToolState extends _FormState<_RebalanceTool> {
  // Default target sama dengan web.
  late final _targets = {Exchange.idx: field('70'), Exchange.us: field('20'), Exchange.crypto: field('10')};
  late final _newFunds = field();

  @override
  Widget build(BuildContext context) {
    final values = {
      for (final e in Exchange.values)
        e: widget.portfolio.positions
            .where((p) => p.exchange == e)
            .fold(0.0, (s, p) => s + widget.portfolio.valueIdr(p)),
    };
    final targets = {for (final e in _targets.entries) e.key: _parse(e.value.text) ?? 0.0};
    final sum = targets.values.fold(0.0, (s, v) => s + v);
    final rows = rebalance(values, targets, newFundsIdr: _parse(_newFunds.text) ?? 0);
    return _body([
      Text('Target alokasi (%)', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          for (final (i, e) in _targets.entries.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _Num(e.key.label, e.value)),
          ],
        ],
      ),
      _Num('Dana baru (Rp, opsional)', _newFunds, helper: 'Kosongkan untuk rebalancing dengan nilai saat ini'),
      if (rows == null)
        _hint(context, 'Jumlah target ${Fmt.number(sum)}% — harus tepat 100%.')
      else
        _result(context, 'Aktual vs target', [
          for (final r in rows) ...[
            InfoRow(
              label: r.exchange.label,
              value: Text(
                '${Fmt.percent(r.actualPercent, signed: false)} → ${Fmt.percent(r.targetPercent, signed: false)}',
              ),
            ),
            InfoRow(
              label: r.actionIdr.abs() < 100000 ? '  sudah sesuai' : (r.actionIdr > 0 ? '  tambah' : '  kurangi'),
              value: AmountText(Money.idr(r.actionIdr.abs())),
            ),
          ],
        ]),
      _hint(context, 'Nilai per bursa dalam rupiah dengan kurs server. Selisih < Rp100.000 dianggap sesuai.'),
    ]);
  }
}

// ── Financial independence ───────────────────────────────────────────────────

class _FiTool extends StatefulWidget {
  const _FiTool({required this.portfolio});
  final Portfolio portfolio;

  @override
  State<_FiTool> createState() => _FiToolState();
}

class _FiToolState extends _FormState<_FiTool> {
  // Default sama dengan web.
  late final _expense = field('10000000');
  late final _saving = field('2000000');
  late final _return = field('15');

  @override
  Widget build(BuildContext context) {
    final current = widget.portfolio.totalValueIdr;
    final r = fiCalc(
      currentIdr: current,
      monthlyExpense: _parse(_expense.text) ?? 0,
      monthlySaving: _parse(_saving.text) ?? 0,
      annualReturnPercent: _parse(_return.text) ?? 0,
    );
    return _body([
      _Num('Pengeluaran bulanan (Rp)', _expense),
      _Num('Tabungan investasi bulanan (Rp)', _saving),
      _Num('Asumsi return per tahun (%)', _return, signed: true),
      _hint(
        context,
        'FI number = pengeluaran setahun ÷ 4% (aturan penarikan aman). Mulai dari nilai portofolio '
        '${Fmt.money(Money.idr(current))}.',
      ),
      _result(context, 'Hasil', [
        InfoRow(label: 'FI number', value: AmountText(Money.idr(r.fiNumber))),
        InfoRow(
          label: 'Estimasi waktu',
          value: Text(switch (r.years) {
            null => 'Lebih dari 60 tahun',
            0 => 'Sudah tercapai',
            final y => '${y.toStringAsFixed(1).replaceAll('.', ',')} tahun',
          }),
        ),
        const Divider(),
        for (final p in r.projections) InfoRow(label: 'Tahun ke-${p.year}', value: AmountText(Money.idr(p.value))),
      ]),
      _hint(context, 'Proyeksi adalah estimasi berdasarkan asumsi, bukan hasil yang dijamin.'),
    ]);
  }
}

// ── Biaya tersembunyi ────────────────────────────────────────────────────────

class _InvisibleCostTool extends StatelessWidget {
  const _InvisibleCostTool();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InvisibleCostCubit>();
    return BlocBuilder<InvisibleCostCubit, ViewState<List<InvisibleCost>>>(
      builder: (context, state) => ViewStateBuilder<List<InvisibleCost>>(
        state: state,
        onRetry: cubit.load,
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          title: 'Belum ada data',
          message: 'Butuh posisi dengan tanggal beli dan harga terakhir.',
        ),
        builder: (context, items) {
          final text = Theme.of(context).textTheme;
          return _body([
            _hint(
              context,
              'Biaya yang tidak muncul di PnL: selisih tertinggal dari IHSG sejak tanggal beli × modal, ditambah '
              'erosi inflasi 3,5%/tahun. "Zombie" = bergerak < ±7% selama > 60 hari.',
            ),
            _result(context, 'Total per mata uang', [
              for (final c in Currency.values)
                if (items.any((i) => i.costBasis.currency == c))
                  InfoRow(
                    label: c == Currency.idr ? 'Rupiah' : 'Dolar AS',
                    value: AmountText(
                      Money(items.where((i) => i.costBasis.currency == c).fold(0.0, (s, i) => s + i.total.amount), c),
                    ),
                  ),
            ]),
            const SizedBox(height: AppSpacing.md),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${i.symbol} · ${i.exchange}', style: text.titleSmall)),
                          if (i.isZombie) Text('Zombie', style: text.labelMedium?.copyWith(color: AppColors.warning)),
                        ],
                      ),
                      Text('${Fmt.number(i.holdDays)} hari dipegang', style: text.bodySmall),
                      const SizedBox(height: AppSpacing.sm),
                      InfoRow(
                        label: 'Return posisi',
                        value: PnlText(percent: i.returnPercent),
                      ),
                      InfoRow(
                        label: 'IHSG sejak beli',
                        value: PnlText(percent: i.ihsgPercent),
                      ),
                      InfoRow(label: 'Tertinggal dari IHSG', value: AmountText(i.opportunityCost)),
                      InfoRow(label: 'Erosi inflasi', value: AmountText(i.inflation)),
                      InfoRow(label: 'Total biaya tersembunyi', value: AmountText(i.total)),
                    ],
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

// ── Wealth timeline ──────────────────────────────────────────────────────────

class _TimelineTool extends StatefulWidget {
  const _TimelineTool();

  @override
  State<_TimelineTool> createState() => _TimelineToolState();
}

class _TimelineToolState extends State<_TimelineTool> {
  TimelineKind? _kind; // null = semua

  static const _labels = {TimelineKind.buy: 'Beli', TimelineKind.sell: 'Jual', TimelineKind.dividend: 'Dividen'};

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WealthTimelineCubit>();
    return BlocBuilder<WealthTimelineCubit, ViewState<WealthTimeline>>(
      builder: (context, state) => ViewStateBuilder<WealthTimeline>(
        state: state,
        onRetry: cubit.load,
        isEmpty: (t) => t.points.isEmpty && t.events.isEmpty,
        empty: const EmptyView(title: 'Belum ada data', message: 'Nilai porto dicatat setiap malam.'),
        builder: (context, t) {
          final text = Theme.of(context).textTheme;
          final events = _kind == null ? t.events : t.events.where((e) => e.kind == _kind).toList();
          final first = t.points.firstOrNull;
          final last = t.points.lastOrNull;
          final high = t.points.isEmpty ? null : t.points.reduce((a, b) => a.value.amount >= b.value.amount ? a : b);
          return _body([
            if (first != null && last != null)
              _result(context, 'Nilai portofolio', [
                InfoRow(label: 'Sekarang', value: AmountText(last.value)),
                InfoRow(label: 'Awal · ${Fmt.date(first.date)}', value: AmountText(first.value)),
                InfoRow(
                  label: 'Perubahan nilai',
                  value: PnlText(
                    amount: Money.idr(last.value.amount - first.value.amount),
                    percent: first.value.amount > 0 ? (last.value.amount / first.value.amount - 1) * 100 : null,
                  ),
                ),
                InfoRow(label: 'Tertinggi · ${Fmt.date(high!.date)}', value: AmountText(high.value)),
                if (t.points.length >= 2) ...[
                  const SizedBox(height: AppSpacing.md),
                  ExcludeSemantics(
                    child: SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (final (i, p) in t.points.indexed) FlSpot(i.toDouble(), p.value.amount / 1e6),
                              ],
                              color: const Color(0xFF2A78D6),
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                          titlesData: const FlTitlesData(show: false),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                        ),
                      ),
                    ),
                  ),
                ],
                Text(
                  'Perubahan nilai termasuk setoran & penarikan modal, jadi bukan return investasi.',
                  style: text.bodySmall,
                ),
              ]),
            const SizedBox(height: AppSpacing.md),
            ChoiceChipBar<TimelineKind?>(
              options: const [null, ...TimelineKind.values],
              selected: _kind,
              labelOf: (k) => k == null ? 'Semua' : _labels[k]!,
              onSelected: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: AppSpacing.md),
            if (events.isEmpty) _hint(context, 'Tidak ada kejadian.'),
            for (final e in events)
              InfoRow(
                label: '${Fmt.date(e.date)} · ${e.label}',
                value: e.kind == TimelineKind.sell ? PnlText(amount: e.amount) : AmountText(e.amount),
              ),
            _hint(
              context,
              'Beli = modal posisi saat ini (jumlah × harga rata-rata) pada tanggal beli pertama; jual = realized PnL; dividen = jumlah diterima.',
            ),
          ]);
        },
      ),
    );
  }
}
