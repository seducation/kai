import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../ai/ai_provider.dart';

/// Agent for debugging code.
/// Analyzes code, finds issues, and suggests fixes.
class CodeDebuggerAgent extends AgentBase {
  /// AI provider for analysis
  final AIProvider? aiProvider;

  CodeDebuggerAgent({
    this.aiProvider,
    super.logger,
  }) : super(name: 'CodeDebugger');

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is DebugRequest) {
      return await debug(input) as R;
    } else if (input is String) {
      return await debug(DebugRequest(code: input)) as R;
    }
    throw ArgumentError('Expected DebugRequest or String');
  }

  /// Debug code and return analysis
  Future<DebugResult> debug(DebugRequest request) async {
    // Step 1: Parse the code
    final parseResult = await execute<ParseResult>(
      action: StepType.analyze,
      target: 'parsing ${request.code.length} characters of code',
      task: () async => _parseCode(request.code),
    );

    // Step 2: Identify issues
    final issues = await execute<List<CodeIssue>>(
      action: StepType.analyze,
      target: 'scanning for issues',
      task: () async {
        if (aiProvider != null && request.errorMessage != null) {
          return await _analyzeWithAI(request);
        }
        return _staticAnalysis(parseResult);
      },
    );

    // Step 3: Generate fixes if issues found
    List<CodeFix> fixes = [];
    if (issues.isNotEmpty) {
      fixes = await execute<List<CodeFix>>(
        action: StepType.decide,
        target: 'generating ${issues.length} fixes',
        task: () async => _generateFixes(issues, request.code),
      );
    }

    // Step 4: Validate the result
    final result = await execute<DebugResult>(
      action: StepType.validate,
      target: 'debug result',
      task: () async => DebugResult(
        success: true,
        issues: issues,
        fixes: fixes,
        summary: _summarize(issues, fixes),
      ),
    );

    return result;
  }

  /// Parse code structure
  ParseResult _parseCode(String code) {
    final lines = code.split('\n');
    return ParseResult(
      lineCount: lines.length,
      hasErrors: code.contains('//TODO') || code.contains('FIXME'),
      functions: _countFunctions(code),
    );
  }

  /// Count function definitions (simple heuristic)
  int _countFunctions(String code) {
    final pattern = RegExp(r'(void|Future|String|int|bool|dynamic)\s+\w+\s*\(');
    return pattern.allMatches(code).length;
  }

  /// Analyze code using AI
  Future<List<CodeIssue>> _analyzeWithAI(DebugRequest request) async {
    final prompt = '''
Analyze this code for bugs and issues:

```
${request.code}
```

${request.errorMessage != null ? 'Error message: ${request.errorMessage}' : ''}

List each issue found.
''';

    final response = await aiProvider!.complete(prompt);

    // Parse AI response into issues (simplified)
    return [
      CodeIssue(
        line: 0,
        message: response,
        severity: IssueSeverity.info,
      ),
    ];
  }

  /// Static analysis without AI
  List<CodeIssue> _staticAnalysis(ParseResult parseResult) {
    final issues = <CodeIssue>[];

    if (parseResult.hasErrors) {
      issues.add(CodeIssue(
        line: 0,
        message: 'Code contains TODO/FIXME markers',
        severity: IssueSeverity.warning,
      ));
    }

    return issues;
  }

  /// Generate fixes for issues
  List<CodeFix> _generateFixes(List<CodeIssue> issues, String code) {
    return issues
        .map((issue) => CodeFix(
              issue: issue,
              suggestion: 'Review and address: ${issue.message}',
              confidence: 0.5,
            ))
        .toList();
  }

  /// Summarize the debug result
  String _summarize(List<CodeIssue> issues, List<CodeFix> fixes) {
    if (issues.isEmpty) {
      return 'No issues found.';
    }
    return 'Found ${issues.length} issue(s) with ${fixes.length} suggested fix(es).';
  }
}

/// Request for debugging
class DebugRequest {
  final String code;
  final String? errorMessage;
  final String? language;

  const DebugRequest({
    required this.code,
    this.errorMessage,
    this.language,
  });
}

/// Result of code parsing
class ParseResult {
  final int lineCount;
  final bool hasErrors;
  final int functions;

  const ParseResult({
    required this.lineCount,
    required this.hasErrors,
    required this.functions,
  });
}

/// A code issue found
class CodeIssue {
  final int line;
  final String message;
  final IssueSeverity severity;

  const CodeIssue({
    required this.line,
    required this.message,
    required this.severity,
  });
}

enum IssueSeverity { info, warning, error }

/// A suggested fix
class CodeFix {
  final CodeIssue issue;
  final String suggestion;
  final double confidence;

  const CodeFix({
    required this.issue,
    required this.suggestion,
    required this.confidence,
  });
}

/// Complete debug result
class DebugResult {
  final bool success;
  final List<CodeIssue> issues;
  final List<CodeFix> fixes;
  final String summary;

  const DebugResult({
    required this.success,
    required this.issues,
    required this.fixes,
    required this.summary,
  });
}
