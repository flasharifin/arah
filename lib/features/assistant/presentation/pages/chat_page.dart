import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:arah/features/assistant/presentation/widgets/chat_composer.dart';
import 'package:arah/features/assistant/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S05/S06 — AI Chat. [initialContext] datang dari detail posisi via query parameter.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.initialContext});

  final AssetContext? initialContext;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  void initState() {
    super.initState();
    _attachContext();
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContext != widget.initialContext) _attachContext();
  }

  void _attachContext() {
    final ctx = widget.initialContext;
    if (ctx == null) return;
    context.read<ChatBloc>().add(ChatContextAttached(ctx, prefill: 'Review posisi ${ctx.symbol}'));
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ChatBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            tooltip: 'Chat baru',
            icon: const Icon(Icons.add),
            onPressed: () => bloc.add(const ChatResetRequested()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state.messages.isEmpty) return const _StarterView();
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: state.messages.length + (state.isAwaitingReply ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    if (state.isAwaitingReply && i == 0) {
                      return Text('Menyiapkan jawaban…', style: Theme.of(context).textTheme.bodySmall);
                    }
                    final offset = state.isAwaitingReply ? 1 : 0;
                    final message = state.messages[state.messages.length - 1 - (i - offset)];
                    return MessageBubble(
                      message: message,
                      onRetry: () => bloc.add(ChatRetryRequested(message.id)),
                      onEdit: () => bloc.add(ChatFailedMessageEdited(message.id)),
                    );
                  },
                );
              },
            ),
          ),
          const ChatComposer(),
        ],
      ),
    );
  }
}

class _StarterView extends StatelessWidget {
  const _StarterView();

  static const _prompts = [
    (Icons.pie_chart_outline, 'Review portofolio', 'Review portofolioku saat ini'),
    (Icons.favorite_outline, 'Cek kesehatan', 'Bagaimana skor kesehatan investasiku?'),
    (Icons.bar_chart, 'Rekap PnL', 'Rekap PnL bulan ini'),
    (Icons.event_outlined, 'Jadwal dividen', 'Dividen apa saja yang akan kuterima?'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Arah', style: text.titleMedium),
                          Text('Membaca data akunmu', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Apa yang ingin kamu pahami hari ini?', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              // Pilihan hanya mengisi composer; mengirim tetap aksi pengguna.
              for (final (icon, title, prompt) in _prompts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    onTap: () => context.read<ChatBloc>().add(ChatPrefillRequested(prompt)),
                    child: Row(
                      children: [
                        Icon(icon, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Text(title, style: text.labelLarge),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
