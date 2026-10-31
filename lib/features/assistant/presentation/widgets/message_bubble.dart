import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onRetry, this.onEdit});

  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final caption = Theme.of(context).textTheme.bodySmall;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                border: isUser ? null : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: SelectableText(message.content, style: TextStyle(color: isUser ? Colors.white : AppColors.text)),
            ),
            const SizedBox(height: AppSpacing.xs),
            switch (message.status) {
              MessageStatus.sending => Text('Mengirim…', style: caption),
              MessageStatus.failed => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    message.failure?.message ?? 'Gagal terkirim',
                    style: caption?.copyWith(color: AppColors.negative),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                ],
              ),
              MessageStatus.sent => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Fmt.dateTime(message.createdAt), style: caption),
                  if (!isUser)
                    IconButton(
                      tooltip: 'Salin jawaban',
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: () => Clipboard.setData(ClipboardData(text: message.content)),
                    ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}
