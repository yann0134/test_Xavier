import 'ai_tool.dart';
import 'tool_manager.dart';

class ModularAIAgent {
  final ToolManager toolManager;

  ModularAIAgent(this.toolManager);

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

    for (final tool in toolManager.tools) {
      if (tool.canHandle(query)) {
        return await tool.handle(query);
      }
    }

    return _availableToolsMessage();
  }
}
