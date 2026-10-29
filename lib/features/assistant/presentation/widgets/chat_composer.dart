import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Composer sticky: chip konteks, input multiline, tombol Kirim.
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key});

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final _controller = TextEditingController(text: context.read<ChatBloc>().state.prefill);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    context.read<ChatBloc>().add(ChatMessageSent(_controller.text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (a, b) => a.prefill != b.prefill && b.prefill != null,
      listener: (_, state) => _controller.text = state.prefill!,
      builder: (context, state) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.context != null)
                InputChip(
                  label: Text('Konteks: ${state.context!.label}'),
                  onDeleted: () => context.read<ChatBloc>().add(const ChatContextCleared()),
                  deleteButtonTooltipMessage: 'Hapus konteks',
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(hintText: 'Tulis pertanyaan…'),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Kirim',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: state.isAwaitingReply ? null : _send,
                  ),
                ],
              ),
              Text('Periksa kembali informasi penting.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
