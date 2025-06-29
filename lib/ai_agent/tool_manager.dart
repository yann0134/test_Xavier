import 'ai_tool.dart';

class ToolManager {
  final List<AITool> _tools = [];

  List<AITool> get tools => List.unmodifiable(_tools);

  void registerTool(AITool tool) {
    _tools.add(tool);
  }

  void unregisterTool(String name) {
    _tools.removeWhere((t) => t.name == name);
  }

  bool isRegistered(String name) {
    return _tools.any((t) => t.name == name);
  }
}
