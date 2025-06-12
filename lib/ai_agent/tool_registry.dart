import 'ai_tool.dart';
import 'tools/translator_tool.dart';
import 'tools/weather_tool.dart';
import 'tools/calculator_tool.dart';
import 'tools/database_tool.dart';

class ToolRegistry {
  static final Map<String, AITool Function()> tools = {
    'translator': () => TranslatorTool(),
    'weather': () => WeatherTool(),
    'calculator': () => CalculatorTool(),
    'database': () => DatabaseTool(),
  };
}
