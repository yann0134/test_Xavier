import 'package:math_expressions/math_expressions.dart';
import '../ai_tool.dart';

class CalculatorTool implements AITool {
  @override
  String get name => 'calculator';

  @override
  String get description => 'Evaluate basic arithmetic expressions.';

  @override
  bool canHandle(String query) {
    final lower = query.toLowerCase();
    return lower.startsWith('calc') || lower.startsWith('calculate');
  }

  @override
  Future<String> handle(String query) async {
    final expression = query.split(' ').sublist(1).join(' ');
    try {
      Parser p = Parser();
      Expression exp = p.parse(expression);
      double result = exp.evaluate(EvaluationType.REAL, ContextModel());
      return result.toString();
    } catch (e) {
      return 'Calculation error: $e';
    }
  }
}
