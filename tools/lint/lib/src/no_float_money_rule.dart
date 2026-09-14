// No-float-money lint rule.
//
// Fires on any double or num variable declaration, parameter declaration,
// or function / method return-type annotation found in source files whose
// path contains /domain/ or /data/.
//
// Enforces REQ-GEN-1: all monetary values are signed 64-bit int centavos.
// A double in a monetary path is a latent precision bug.
//
// The rule fires as a lint (not a warning) so it:
// - Must be enabled explicitly in analysis_options.yaml under the
//   plugin's diagnostics section.
// - Can be suppressed per-site with:
//   // ignore: kasaran_lint/no_float_money
// - Appears in flutter analyze output and fails CI when --fatal-infos
//   is set (analysis_options.yaml marks infos as errors).

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Lint rule: no double or num in domain/ or data/ source paths.
class NoFloatMoneyRule extends AnalysisRule {
  NoFloatMoneyRule()
      : super(
          name: 'no_float_money',
          description:
              "Bans 'double' and 'num' variable/parameter declarations in "
              "domain/ and data/ source paths to enforce integer-centavo "
              'money arithmetic (REQ-GEN-1).',
        );

  // Single static const instance — required by the framework so that
  // ignore comments can correctly match the diagnostic code.
  static const LintCode code = LintCode(
    'no_float_money',
    "Monetary paths must not use 'double' or 'num'; use 'int' centavos.",
    correctionMessage:
        'Replace with \'int\' centavos (REQ-GEN-1). '
        'If this is a non-monetary value, move it outside domain/ or data/.',
  );
  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addVariableDeclarationList(this, visitor);
    registry.addSimpleFormalParameter(this, visitor);
    registry.addFunctionDeclaration(this, visitor);
    registry.addMethodDeclaration(this, visitor);
  }
}

// Returns true when the file path is under a domain/ or data/ subtree.
bool _isMonetaryPath(String path) =>
    path.contains('/domain/') || path.contains('/data/');

// Returns true when the type source text is 'double' or 'num'.
bool _isFloatType(String typeName) =>
    typeName == 'double' || typeName == 'num';

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  // Resolve the file path from the currently-visited compilation unit.
  // Returns an empty string when no unit is being visited (registration phase).
  String get _path => context.currentUnit?.file.path ?? '';

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (!_isMonetaryPath(_path)) return;
    final typeAnnotation = node.type;
    if (typeAnnotation == null) return;
    if (_isFloatType(typeAnnotation.toSource())) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    if (!_isMonetaryPath(_path)) return;
    final typeAnnotation = node.type;
    if (typeAnnotation == null) return;
    if (_isFloatType(typeAnnotation.toSource())) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!_isMonetaryPath(_path)) return;
    final returnType = node.returnType;
    if (returnType == null) return;
    if (_isFloatType(returnType.toSource())) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!_isMonetaryPath(_path)) return;
    final returnType = node.returnType;
    if (returnType == null) return;
    if (_isFloatType(returnType.toSource())) {
      rule.reportAtNode(node);
    }
  }
}
