import 'package:flutter/material.dart';
import '../../ai_agent/modular_ai_agent.dart';
import '../../ai_agent/tool_manager.dart';
import '../../ai_agent/tool_registry.dart';
import '../../ai_agent/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

class AssistantChatOverlay extends StatefulWidget {
  const AssistantChatOverlay({super.key});

  @override
  State<AssistantChatOverlay> createState() => _AssistantChatOverlayState();
}

class _AssistantChatOverlayState extends State<AssistantChatOverlay> {
  bool _isOpen = false;
  late ModularAIAgent agent;
  bool _loading = true;
  final TextEditingController controller = TextEditingController();
  final List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getStringList('enabled_tools') ?? ToolRegistry.tools.keys.toList();
    final manager = ToolManager();
    for (final name in enabled) {
      final ctor = ToolRegistry.tools[name];
      if (ctor != null) {
        manager.registerTool(ctor());
      }
    }
    final gemini = GeminiService(apiKey: 'AIzaSyCCVre0MdH35vty9lRbqQ0FglYKPt8KQ9c');
    agent = ModularAIAgent(manager, gemini);
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;
    if (_loading) return;
    setState(() {
      messages.add('> $query');
    });
    controller.clear();
    final result = await agent.process(query);
    setState(() {
      messages.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.small(
          onPressed: () => setState(() => _isOpen = true),
          child: const Icon(Icons.chat_bubble_outline),
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
          width: 300,
          height: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Text('assistant'.tr),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _isOpen = false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(8),
                        children: messages.map((m) => Text(m)).toList(),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'ask_hint'.tr,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submit,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
