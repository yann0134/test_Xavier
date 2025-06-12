import 'ai_tool.dart';
import 'tool_manager.dart';

class ModularAIAgent {
  final ToolManager toolManager;

  ModularAIAgent(this.toolManager);

  Future<String> process(String query) async {
    for (final tool in toolManager.tools) {
      if (tool.canHandle(query)) {
        return await tool.handle(query);
      }
    }
    return 'No tool available for this request.';
  }
}
