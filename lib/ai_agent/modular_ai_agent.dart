import 'ai_tool.dart';
import 'tool_manager.dart';
import 'gemini_service.dart';

class ModularAIAgent {
  final ToolManager toolManager;
  final GeminiService gemini;

  ModularAIAgent(this.toolManager, this.gemini);

  /// Build a help message listing all available tools.
  String _availableToolsMessage() {
    final buffer = StringBuffer('Available tools:\n');
    for (final tool in toolManager.tools) {
      buffer.writeln('- ${tool.name}: ${tool.description}');
    }
    return buffer.toString().trim();
  }

  Future<String> process(String query) async {
    final normalized = query.trim().toLowerCase();

    if (normalized == 'help') {
      return _availableToolsMessage();
    }

    try {
      final decision = await gemini.decideTool(
          query, toolManager.tools.map((t) => t.name).toList());

      if (decision.containsKey('answer')) {
        return decision['answer'] as String;
      }

      if (decision.containsKey('tool')) {
        final toolName = decision['tool'] as String;
        final toolQuery = (decision['toolQuery'] ?? query) as String;
        AITool? selected;
        for (final t in toolManager.tools) {
          if (t.name == toolName) {
            selected = t;
            break;
          }
        }
        if (selected != null) {
          return await selected.handle(toolQuery);
        }
      }
    } catch (_) {
      // Ignore Gemini errors and fall back to local tool matching
    }

    for (final tool in toolManager.tools) {
      if (tool.canHandle(query)) {
        return await tool.handle(query);
      }
    }

    return _availableToolsMessage();
  }
}
