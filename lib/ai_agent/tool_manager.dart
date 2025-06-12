import 'ai_tool.dart';

class ToolManager {
  final List<AITool> _tools = [];

  List<AITool> get tools => List.unmodifiable(_tools);

  void registerTool(AITool tool) {
    _tools.add(tool);
  }
}
