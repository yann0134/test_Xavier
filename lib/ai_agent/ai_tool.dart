abstract class AITool {
  String get name;
  String get description;

  /// Determine if the tool can handle the provided query.
  bool canHandle(String query);

  /// Execute the tool and return a response string.
  Future<String> handle(String query);
}
