import 'package:flutter/material.dart';
import 'chat_screen.dart';

/// FAB reusable que abre el chat de IA embebido en un modal bottom sheet.
class ChatFab extends StatelessWidget {
  const ChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'chat_fab',
      backgroundColor: const Color(0xFF2ED573),
      child: const Icon(Icons.chat_rounded, color: Colors.black),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E201E),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.9,
          child: ChatScreen(embedded: true),
        ),
      ),
    );
  }
}
