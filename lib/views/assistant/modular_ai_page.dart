import 'package:flutter/material.dart';
import '../../ai_agent/modular_ai_agent.dart';
import '../../ai_agent/tool_manager.dart';
import '../../ai_agent/tool_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModularAIPage extends StatefulWidget {
  const ModularAIPage({Key? key}) : super(key: key);

  @override
  State<ModularAIPage> createState() => _ModularAIPageState();
}

class _ModularAIPageState extends State<ModularAIPage> {
  late ModularAIAgent agent;
  bool _loading = true;
  final TextEditingController controller = TextEditingController();
  String response = '';

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
    agent = ModularAIAgent(manager);
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;
    final result = await agent.process(query);
    setState(() {
      response = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('assistant'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('assistant'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'ask_hint'.tr
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: Text('send'.tr),
            ),
            const SizedBox(height: 24),
            Text(response),
          ],
        ),
      ),
    );
  }
}
