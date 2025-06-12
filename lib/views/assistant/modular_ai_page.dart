import 'package:flutter/material.dart';
import '../../ai_agent/modular_ai_agent.dart';
import '../../ai_agent/tool_manager.dart';
import '../../ai_agent/tools/translator_tool.dart';
import '../../ai_agent/tools/weather_tool.dart';
import '../../ai_agent/tools/calculator_tool.dart';

class ModularAIPage extends StatefulWidget {
  const ModularAIPage({Key? key}) : super(key: key);

  @override
  State<ModularAIPage> createState() => _ModularAIPageState();
}

class _ModularAIPageState extends State<ModularAIPage> {
  late final ModularAIAgent agent;
  final TextEditingController controller = TextEditingController();
  String response = '';

  @override
  void initState() {
    super.initState();
    final manager = ToolManager();
    manager.registerTool(TranslatorTool());
    manager.registerTool(WeatherTool());
    manager.registerTool(CalculatorTool());
    agent = ModularAIAgent(manager);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Modular AI Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Ask something...'
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Send'),
            ),
            const SizedBox(height: 24),
            Text(response),
          ],
        ),
      ),
    );
  }
}
