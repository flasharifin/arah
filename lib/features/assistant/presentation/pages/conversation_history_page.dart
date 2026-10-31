import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:arah/features/assistant/presentation/bloc/conversation_history_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S06 — Riwayat percakapan: buka, ubah nama, hapus. Dikelompokkan Hari ini / Sebelumnya.
class ConversationHistoryPage extends StatelessWidget {
  const ConversationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConversationHistoryCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat chat')),
      body: BlocBuilder<ConversationHistoryCubit, ViewState<List<ConversationSummary>>>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ViewStateBuilder<List<ConversationSummary>>(
            state: state,
            onRetry: cubit.refresh,
            isEmpty: (items) => items.isEmpty,
            empty: EmptyView(
              icon: Icons.forum_outlined,
              title: 'Belum ada percakapan',
              message: 'Pertanyaanmu ke AI tersimpan di sini.',
              actionLabel: 'Mulai chat',
              onAction: () => context.pop(),
            ),
            builder: (context, items) {
              final now = DateTime.now();
              bool isToday(ConversationSummary c) {
                final d = c.updatedAt.toLocal();
                return d.year == now.year && d.month == now.month && d.day == now.day;
              }

              final today = items.where(isToday).toList();
              final earlier = items.where((c) => !isToday(c)).toList();
              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (today.isNotEmpty)
                          MenuGroup(title: 'Hari ini', children: [for (final c in today) _ConversationTile(c)]),
                        if (earlier.isNotEmpty)
                          MenuGroup(title: 'Sebelumnya', children: [for (final c in earlier) _ConversationTile(c)]),
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

enum _Action { rename, delete }

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(this.conversation);
  final ConversationSummary conversation;

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _open(BuildContext context) async {
    final result = await context.read<ConversationHistoryCubit>().open(conversation.id);
    if (!context.mounted) return;
    result.fold((failure) => _toast(context, failure.message), (messages) {
      context.read<ChatBloc>().add(ChatConversationLoaded(conversation.id, messages));
      context.pop();
    });
  }

  Future<void> _rename(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: conversation.title),
    );
    if (title == null || !context.mounted) return;
    final result = await context.read<ConversationHistoryCubit>().rename(conversation.id, title);
    if (context.mounted) result.fold((failure) => _toast(context, failure.message), (_) {});
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus percakapan?'),
        content: Text('"${conversation.title}" dan semua pesannya dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final chat = context.read<ChatBloc>();
    final result = await context.read<ConversationHistoryCubit>().delete(conversation.id);
    if (!context.mounted) return;
    result.fold((failure) => _toast(context, failure.message), (_) {
      // Percakapan yang sedang terbuka di layar chat ikut dihapus → kosongkan layar chat.
      if (chat.state.conversationId == conversation.id) chat.add(const ChatResetRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(Fmt.dateTime(conversation.updatedAt)),
      onTap: () => _open(context),
      trailing: PopupMenuButton<_Action>(
        tooltip: 'Opsi percakapan',
        onSelected: (action) => action == _Action.rename ? _rename(context) : _delete(context),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _Action.rename, child: Text('Ubah nama')),
          PopupMenuItem(value: _Action.delete, child: Text('Hapus')),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah nama percakapan'),
      content: Form(
        key: _formKey,
        child: AppTextField(
          label: 'Judul',
          controller: _controller,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Judul tidak boleh kosong';
            return t.length > 80 ? 'Judul maksimal 80 karakter' : null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        TextButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
