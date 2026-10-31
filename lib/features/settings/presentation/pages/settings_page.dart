import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arah/features/settings/domain/entities/account_settings.dart';
import 'package:arah/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S16 — Pengaturan: profil, target (diubah di Kekayaan), Telegram, ambang drawdown.
/// Privasi nominal, kunci biometrik, keluar & hapus akun ada langsung di menu Lainnya.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: BlocBuilder<SettingsCubit, ViewState<AccountSettings>>(
        // Form diisi sekali dari data pertama; simpan tidak menimpa ketikan.
        buildWhen: (previous, current) => previous.data == null || current.data == null,
        builder: (context, state) => ViewStateBuilder<AccountSettings>(
          state: state,
          onRetry: cubit.load,
          builder: (context, settings) => _SettingsForm(settings: settings),
        ),
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.settings});
  final AccountSettings settings;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _chatId = TextEditingController(text: widget.settings.telegramChatId);
  late final _drawdown = TextEditingController(
    text: widget.settings.drawdownThreshold == widget.settings.drawdownThreshold.roundToDouble()
        ? widget.settings.drawdownThreshold.toInt().toString()
        : widget.settings.drawdownThreshold.toString(),
  );
  bool _busy = false;

  @override
  void dispose() {
    _chatId.dispose();
    _drawdown.dispose();
    super.dispose();
  }

  static double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final chatId = _chatId.text.trim();
    final result = await context.read<SettingsCubit>().save(
      telegramChatId: chatId.isEmpty ? null : chatId,
      drawdownThreshold: _parse(_drawdown.text)!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.fold((f) => f.message, (_) => 'Pengaturan tersimpan'))));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = context.select<AuthBloc, ({String name, String email})?>(
      (b) => switch (b.state.user) {
        final u? => (name: u.name, email: u.email),
        null => null,
      },
    );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          PageBody(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Profil', style: text.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  InfoRow(label: 'Nama', value: Text(user == null || user.name.isEmpty ? '—' : user.name)),
                  InfoRow(label: 'Email', value: Text(user?.email ?? '—')),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PageBody(
            child: AppCard(
              onTap: () => context.go('/wealth'),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target kekayaan', style: text.titleSmall),
                        AmountText(widget.settings.wealthTarget),
                        Text('Ubah di Kekayaan → Target', style: text.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Notifikasi Telegram', style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Opsional. Kirim /start ke bot Telegram aplikasi ini, salin angka Chat ID yang dibalas, '
                  'lalu tempel di sini. Kosongkan untuk berhenti menerima notifikasi Telegram.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Telegram Chat ID',
                  hint: 'contoh: 123456789',
                  controller: _chatId,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  // Sama dengan server: angka, boleh negatif untuk chat grup (-100…).
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.isEmpty || RegExp(r'^-?\d+$').hasMatch(t) ? null : 'Chat ID hanya angka';
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Alert drawdown', style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Kirim peringatan bila nilai portofolio turun dari puncak 90 hari terakhir melewati ambang ini.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Ambang drawdown (%)',
                  controller: _drawdown,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = _parse(v ?? '');
                    return n == null || n <= 0 || n > 100 ? 'Isi 1–100%' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: 'Simpan', busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
