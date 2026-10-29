import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/journal/domain/entities/journal.dart';
import 'package:arah/features/journal/presentation/bloc/journal_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _Unsaved { save, discard, cancel }

/// S14 — Jurnal harian: pilih tanggal (30 hari terakhir) → PnL hari itu → catatan → Simpan.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _note = TextEditingController();
  DateTime _day = DateTime.now();
  String _saved = '';
  bool _busy = false;

  String get _key => dayKey(_day);
  bool get _dirty => _note.text.trim() != _saved;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _showDay(JournalData data, DateTime day) {
    _day = day;
    _saved = data.notes[dayKey(day)] ?? '';
    _note.text = _saved;
  }

  /// true = boleh lanjut (tidak ada perubahan, sudah disimpan, atau dibuang).
  Future<bool> _resolveUnsaved() async {
    if (!_dirty) return true;
    final choice = await showDialog<_Unsaved>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catatan belum disimpan'),
        content: const Text('Simpan catatan untuk tanggal ini sebelum lanjut?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _Unsaved.cancel), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, _Unsaved.discard), child: const Text('Buang')),
          TextButton(onPressed: () => Navigator.pop(context, _Unsaved.save), child: const Text('Simpan')),
        ],
      ),
    );
    return switch (choice) {
      _Unsaved.save => _save(),
      _Unsaved.discard => true,
      _Unsaved.cancel || null => false,
    };
  }

  Future<bool> _save() async {
    setState(() => _busy = true);
    final result = await context.read<JournalCubit>().save(_key, _note.text);
    if (!mounted) return false;
    setState(() => _busy = false);
    return result.fold(
      (f) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
        return false;
      },
      (_) {
        setState(() => _saved = _note.text.trim());
        return true;
      },
    );
  }

  Future<void> _pickDay(JournalData data) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today.subtract(const Duration(days: 30)), // API catatan hanya 30 hari terakhir
      lastDate: today,
    );
    if (picked == null || dayKey(picked) == _key || !await _resolveUnsaved()) return;
    setState(() => _showDay(data, picked));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JournalCubit>();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _resolveUnsaved()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Jurnal')),
        body: BlocConsumer<JournalCubit, ViewState<JournalData>>(
          // Data pertama tiba → tampilkan catatan hari ini.
          listenWhen: (previous, current) => previous.data == null && current.data != null,
          listener: (context, state) => setState(() => _showDay(state.data!, _day)),
          builder: (context, state) => ViewStateBuilder<JournalData>(
            state: state,
            onRetry: cubit.load,
            builder: (context, data) {
              final pnl = data.pnl[_key];
              final text = Theme.of(context).textTheme;
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pickDay(data),
                          icon: const Icon(Icons.event_outlined),
                          label: Text(Fmt.date(_day)),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppCard(
                          child: pnl == null
                              ? Text(
                                  'Belum ada data PnL untuk tanggal ini. PnL dicatat setiap malam.',
                                  style: text.bodySmall,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    InfoRow(
                                      label: 'PnL hari itu',
                                      value: PnlText(amount: pnl.pnl, percent: pnl.pnlPercent),
                                    ),
                                    InfoRow(label: 'Nilai portofolio', value: AmountText(pnl.portfolioValue)),
                                  ],
                                ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: _note,
                          minLines: 4,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            labelText: 'Catatan',
                            hintText: 'Apa yang kamu pelajari dari pasar hari ini?',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_dirty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text('Belum disimpan', style: text.bodySmall),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: 'Simpan',
                          busy: _busy,
                          // Backend menolak catatan kosong, jadi catatan tidak bisa dikosongkan dari sini.
                          onPressed: _dirty && _note.text.trim().isNotEmpty ? _save : null,
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
