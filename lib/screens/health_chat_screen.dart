import 'package:flutter/material.dart';

import '../services/health_chat_service.dart';

class HealthChatScreen extends StatefulWidget {
  const HealthChatScreen({super.key});

  @override
  State<HealthChatScreen> createState() => _HealthChatScreenState();
}

class _ChatMessage {
  const _ChatMessage(this.text, this.isUser);
  final String text;
  final bool isUser;
}

class _HealthChatScreenState extends State<HealthChatScreen> {
  static const _violet = Color(0xFF6E3FB5);
  final _service = HealthChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _waiting = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _waiting) return;
    setState(() {
      _messages.add(_ChatMessage(question, true));
      _input.clear();
      _waiting = true;
    });
    _scrollDown();
    try {
      final answer = await _service.ask(question);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(answer, false)));
    } catch (e, stackTrace) {
      debugPrint('CHATBOT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _messages.add(const _ChatMessage(
          'Sorry, I could not connect right now. Please try again. / تعذّر الاتصال حالياً، حاولي مرة ثانية.', false)));
    } finally {
      if (mounted) setState(() => _waiting = false);
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3FF),
      appBar: AppBar(
        title: const Text('AI Health Chat'),
        backgroundColor: const Color(0xFFF8F3FF),
        foregroundColor: _violet,
      ),
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'General health information only — not a diagnosis or a substitute for medical care. No Apple Watch data is shared with this chat.',
              style: TextStyle(fontSize: 12, color: Color(0xFF392550)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_waiting ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(alignment: Alignment.centerLeft,
                        child: CircularProgressIndicator(color: _violet)),
                  );
                }
                final m = _messages[index];
                return Align(
                  alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: m.isUser ? _violet : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SelectableText(m.text,
                      style: TextStyle(color: m.isUser ? Colors.white : const Color(0xFF392550))),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _input,
                enabled: !_waiting,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ask a health question… / اسأل سؤال صحي',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                ),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _waiting ? null : _send,
                style: IconButton.styleFrom(backgroundColor: _violet),
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
