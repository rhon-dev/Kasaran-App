// Kasaran custom analysis-server plugin.
//
// Registers the NoFloatMoneyRule lint, which bans double and num
// variable/parameter declarations in domain/ and data/ source paths.
//
// Registered as a lint rule (not a warning) so it must be explicitly
// enabled in analysis_options.yaml under the plugin's diagnostics section.
// This allows the application package to opt in and the rule to be
// suppressed per-file with '// ignore:' if genuinely necessary.

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:kasaran_lint/src/no_float_money_rule.dart';

/// Entry point called by the analysis server to instantiate the plugin.
Plugin createPlugin() => _KasaranPlugin();

class _KasaranPlugin extends Plugin {
  @override
  String get name => 'kasaran_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(NoFloatMoneyRule());
  }
}
