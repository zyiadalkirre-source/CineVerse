import 'package:flutter/material.dart';
import 'ai_chat_screen.dart';
import 'ai_mood_screen.dart';
import 'ai_poster_screen.dart';
import 'ai_taste_screen.dart';
import 'turtle_screen.dart';

class AiHubScreen extends StatelessWidget {
  const AiHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, Widget)>[
      ('محادثة AI', Icons.chat, const AiChatScreen()),
      ('حسب مزاجي', Icons.mood, const AiMoodScreen()),
      ('تحليل بوستر', Icons.image, const AiPosterScreen()),
      ('تحليل ذوقي', Icons.psychology, const AiTasteScreen()),
      ('🐢 Turtle محلي', Icons.smart_toy, const TurtleScreen()),
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => item.$3)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.$2, size: 42),
                const SizedBox(height: 12),
                Text(item.$1),
              ],
            ),
          ),
        );
      },
    );
  }
}
