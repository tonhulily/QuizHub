import 'package:flutter/material.dart';
import '../../../core/services/chat_realtime.dart';

class ChatConnectionBanner extends StatelessWidget {
  final ChatConnection connection;
  final VoidCallback onRetry;
  const ChatConnectionBanner({
    super.key,
    required this.connection,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => connection == ChatConnection.connected
      ? const SizedBox.shrink()
      : Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    connection == ChatConnection.connecting
                        ? 'Đang kết nối tin nhắn…'
                        : 'Mất kết nối. Đang thử kết nối lại…',
                  ),
                ),
                if (connection == ChatConnection.disconnected)
                  TextButton(onPressed: onRetry, child: const Text('Thử lại')),
              ],
            ),
          ),
        );
}
