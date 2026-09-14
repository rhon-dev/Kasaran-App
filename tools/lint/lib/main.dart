// Plugin entry point for the kasaran_lint analysis-server plugin.
// The analysis server loads this file and expects a top-level variable
// named 'plugin' that is an instance of Plugin.

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:kasaran_lint/src/no_float_money_rule.dart';

// Top-level plugin instance — the analysis server reads this variable.
final Plugin plugin = _KasaranPlugin();

class _KasaranPlugin extends Plugin {
  @override
  String get name => 'kasaran_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(NoFloatMoneyRule());
  }
}
