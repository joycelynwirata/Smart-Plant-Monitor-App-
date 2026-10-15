import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/plant_advice_service.dart';

class PlantChat extends StatefulWidget {
  const PlantChat({super.key, required this.sensorSummary});
  final String Function() sensorSummary;

  @override
  State<PlantChat> createState() => _PlantChatState();
}

class _PlantChatState extends State<PlantChat> {
  bool isChatOpen = false;
  bool isThinking = false;
  bool greeted = false;
  final quickAiController = TextEditingController();
  final quickScroll = ScrollController();
  final List<Map<String, String>> quickMessages = [];

  @override
  void dispose() {
    quickAiController.dispose();
    quickScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.bottomRight,
      child: Container(
        width: isChatOpen ? 380 : 65,
        height: isChatOpen ? 560 : 65,
        decoration: BoxDecoration(
          color: isChatOpen ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(isChatOpen ? 20 : 50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: isChatOpen ? _chatWindow() : _chatIcon(),
      ),
    );
  }

  Widget _chatIcon() {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        setState(() {
          isChatOpen = true;

          if (!greeted) {
            quickMessages.add({
              "role": "bot",
              "text": "Hi! 🌱 I'm Sprout. How can I help you today?",
            });
            greeted = true;
          }
        });
      },
      child: Container(
        width: 65,
        height: 65,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipOval(
            child: Image.asset("assets/sproutlogo.png", fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _chatWindow() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              const Text(
                "Sprout Quick AI",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    isChatOpen = false;
                  });
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: quickScroll,
            padding: const EdgeInsets.all(10),
            itemCount: quickMessages.length,
            itemBuilder: (context, index) {
              final msg = quickMessages[index];
              final isUser = msg["role"] == "user";

              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.green : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: MarkdownBody(
                    data: msg["text"] ?? "",
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                        fontSize: 15,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUser ? Colors.white : Colors.green.shade900,
                      ),
                      listBullet: TextStyle(
                        color: isUser ? Colors.white : Colors.green,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (isThinking)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: CircularProgressIndicator(),
          ),

        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: quickAiController,
            onSubmitted: (_) => askQuickAI(),
            decoration: InputDecoration(
              hintText: "Ask Sprout...",
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: askQuickAI,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> askQuickAI() async {
    if (isThinking) return;
    final userText = quickAiController.text.trim();

    final input = userText.isNotEmpty ? userText : widget.sensorSummary();

    if (input.isEmpty) return;

    setState(() {
      isThinking = true;

      quickMessages.add({"role": "user", "text": input});

      quickAiController.clear();
    });

    try {
      final reply = await PlantAdviceService().getAdvice(
        messages: quickMessages,
      );
      if (!mounted) return;
      setState(() {
        quickMessages.add({'role': 'bot', 'text': reply});
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        quickMessages.add({'role': 'bot', 'text': error.toString()});
      });
    } finally {
      if (mounted) setState(() => isThinking = false);
    }
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && quickScroll.hasClients) {
        quickScroll.animateTo(
          quickScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
