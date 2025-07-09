import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../ai_agent/modular_ai_agent.dart';
import '../../ai_agent/tool_manager.dart';
import '../../ai_agent/tool_registry.dart';
import '../../ai_agent/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../../ai_agent/chat_agent.dart';

class AssistantChatOverlay extends StatefulWidget {
  const AssistantChatOverlay({super.key});

  @override
  State<AssistantChatOverlay> createState() => _AssistantChatOverlayState();
}

class _AssistantChatOverlayState extends State<AssistantChatOverlay> {
  bool _isOpen = false;
  late ModularAIAgent agent;
  bool _loading = false;
  final TextEditingController controller = TextEditingController();
  final List<ChatMessage> messages = [];
  final ScrollController _scrollController = ScrollController();
  late final ChatAgent _chatAgent;

  @override
  void initState() {
    super.initState();
    _chatAgent = ChatAgent();
    _loadTools();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    messages.add(ChatMessage(
      content:
          'Bonjour, je suis votre assistant virtuel. Je peux vous aider à :\n'
          '- Obtenir des informations sur vos produits et stocks\n'
          '- Analyser vos ventes\n'
          '- Générer des rapports\n'
          'N\'hésitez pas à me poser des questions !',
      isUser: false,
    ));
  }

  Future<void> _loadTools() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList('enabled_tools') ??
        ToolRegistry.tools.keys.toList();
    final manager = ToolManager();
    for (final name in enabled) {
      final ctor = ToolRegistry.tools[name];
      if (ctor != null) {
        manager.registerTool(ctor());
      }
    }
    final gemini =
        GeminiService(apiKey: 'AIzaSyA6oLyqvIj9mnFtPM83iuNPAg6Nrlu2G38');
    agent = ModularAIAgent(manager, gemini);
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final query = controller.text.trim();
    if (query.isEmpty || _loading) return;

    setState(() {
      messages.add(ChatMessage(content: query, isUser: true));
      _loading = true;
    });
    controller.clear();

    try {
      final response = await _chatAgent.processMessage(query);
      setState(() {
        messages.add(ChatMessage(content: response, isUser: false));
      });
    } catch (e) {
      setState(() {
        messages.add(ChatMessage(
          content: 'Désolé, une erreur est survenue: $e',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton(
          onPressed: () => setState(() => _isOpen = true),
          child: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Assistant virtuel',
        ),
      );
    }

    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 400,
          height: 600,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : _buildMessageList(),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.assistant, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Assistant CaissePro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isOpen = false),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageBubble(message: message);
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Posez votre question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: _submit,
            icon: Icon(Icons.send),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String content;
  final bool isUser;

  ChatMessage({required this.content, required this.isUser});
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).primaryColor
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: MarkdownBody(
          data: message.content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: message.isUser ? Colors.white : Colors.black,
            ),
            tableBody: TextStyle(
              color: message.isUser ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
