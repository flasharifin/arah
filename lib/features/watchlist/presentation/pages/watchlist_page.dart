import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';
import 'package:arah/features/watchlist/presentation/bloc/watchlist_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S09 — Watchlist: filter status, kartu harga vs target, tambah/ubah/hapus lewat sheet.
class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  WatchStatus? _filter; // null = Semua

  void _openForm([WatchItem? item]) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: context.read<WatchlistCubit>(),
      child: _WatchForm(item: item),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchlistCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [IconButton(tooltip: 'Tambah', icon: const Icon(Icons.add), onPressed: _openForm)],
      ),
      body: BlocBuilder<WatchlistCubit, ViewState<List<WatchItem>>>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: cubit.load,
          child: ViewStateBuilder<List<WatchItem>>(
            state: state,
            onRetry: cubit.load,
            isEmpty: (items) => items.isEmpty,
            empty: EmptyView(
              icon: Icons.visibility_outlined,
              title: 'Belum ada saham yang diamati',
              message: 'Catat saham incaran beserta harga targetnya.',
              actionLabel: 'Tambah',
              onAction: _openForm,
            ),
            builder: (context, items) {
              final shown = _filter == null ? items : items.where((i) => i.status == _filter).toList();
              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        ChoiceChipBar<WatchStatus?>(
                          options: const [null, ...WatchStatus.values],
                          selected: _filter,
                          labelOf: (s) => s?.label ?? 'Semua',
                          onSelected: (s) => setState(() => _filter = s),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (shown.isEmpty)
                          Text(
                            'Tidak ada saham dengan status ini.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        for (final item in shown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _WatchCard(item: item, onTap: () => _openForm(item)),
                          ),
                      ],
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

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.item, required this.onTap});
  final WatchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${item.symbol} · ${item.exchange.label}', style: text.titleMedium)),
              Chip(label: Text(item.status.label), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(label: 'Harga terakhir', value: AmountText(item.lastPrice)),
          InfoRow(label: 'Target', value: AmountText(item.targetPrice)),
          InfoRow(label: 'Jarak ke target', value: Text(Fmt.percent(item.gapPercent))),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(item.note!, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _WatchForm extends StatefulWidget {
  const _WatchForm({this.item});
  final WatchItem? item;

  @override
  State<_WatchForm> createState() => _WatchFormState();
}

class _WatchFormState extends State<_WatchForm> {
  final _formKey = GlobalKey<FormState>();
  late final _symbol = TextEditingController(text: widget.item?.symbol);
  late final _target = TextEditingController(text: widget.item?.targetPrice?.amount.toString());
  late final _note = TextEditingController(text: widget.item?.note);
  late Exchange _exchange = widget.item?.exchange ?? Exchange.idx;
  late WatchStatus _status = widget.item?.status ?? WatchStatus.observe;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_symbol, _target, _note]) {
      c.dispose();
    }
    super.dispose();
  }

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
    final target = _target.text.trim();
    final draft = WatchDraft(
      symbol: _symbol.text,
      exchange: _exchange,
      status: _status,
      targetPrice: target.isEmpty ? null : double.parse(target.replaceAll(',', '.')),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    _run(() => context.read<WatchlistCubit>().save(draft, id: widget.item?.id));
  }

  Future<void> _delete() async {
    final item = widget.item!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${item.symbol} dari watchlist?'),
        content: const Text('Hanya catatan watchlist yang dihapus; tidak mengubah portofolio.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true && mounted) _run(() => context.read<WatchlistCubit>().remove(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
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
              Text(
                editing ? 'Ubah ${widget.item!.symbol}' : 'Tambah ke watchlist',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!editing) ...[
                ChoiceChipBar<Exchange>(
                  options: Exchange.values,
                  selected: _exchange,
                  labelOf: (e) => e.label,
                  onSelected: (e) => setState(() => _exchange = e),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Kode saham',
                  controller: _symbol,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Kode wajib diisi' : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Harga target (opsional)',
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = double.tryParse(t.replaceAll(',', '.'));
                  return n == null || n <= 0 ? 'Masukkan angka lebih dari 0' : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ChoiceChipBar<WatchStatus>(
                options: WatchStatus.values,
                selected: _status,
                labelOf: (s) => s.label,
                onSelected: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Catatan (opsional)', controller: _note),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
              if (editing)
                TextButton(onPressed: _busy ? null : _delete, child: const Text('Hapus dari watchlist')),
            ],
          ),
        ),
      ),
    );
  }
}
