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
      // On teste d'abord les outils locaux directement
      for (final tool in toolManager.tools) {
        if (tool.canHandle(normalized)) {
          return await tool.handle(normalized);
        }
      }

      // Si aucun outil local ne correspond, on demande à Gemini
      final decision = await gemini.decideTool(
          query, toolManager.tools.map((t) => t.name).toList());
      print("decision gemini $decision");

      if (decision.containsKey('answer')) {
        return decision['answer'] as String;
      }

      if (decision.containsKey('tool')) {
        final toolName = decision['tool'] as String;
        final toolQuery = (decision['toolQuery'] ?? query) as String;

        // Recherche de l'outil correspondant
        AITool? selected;
        for (final t in toolManager.tools) {
          if (t.name.toLowerCase() == toolName.toLowerCase()) {
            selected = t;
            break;
          }
        }

        // Si on trouve l'outil, on l'utilise
        if (selected != null) {
          return await selected.handle(toolQuery);
        }
      }
    } catch (e) {
      print('Erreur lors du traitement: $e');
    }

    // Message par défaut si aucune réponse n'a été trouvée
    return "Je n'ai pas compris votre demande. Pouvez-vous reformuler ou taper 'help' pour voir les commandes disponibles ?";
  }
}
