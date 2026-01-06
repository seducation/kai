import 'dart:async';
import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../ai/ai_provider.dart';

/// Agent for writing code using AI.
/// Logs all code generation actions transparently.
class CodeWriterAgent extends AgentBase {
  /// AI provider for code generation
  final AIProvider? aiProvider;

  CodeWriterAgent({
    this.aiProvider,
    super.logger,
  }) : super(name: 'CodeWriter');

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is CodeWriteRequest) {
      return await writeCode(input) as R;
    } else if (input is String) {
      return await writeCode(CodeWriteRequest(prompt: input)) as R;
    }
    throw ArgumentError('Expected CodeWriteRequest or String');
  }

  /// Write code based on a request
  Future<String> writeCode(CodeWriteRequest request) async {
    // Step 1: Analyze the request
    final analysis = await execute<Map<String, dynamic>>(
      action: StepType.analyze,
      target: 'code request: ${request.prompt}',
      task: () async => _analyzeRequest(request),
    );

    // Step 2: Generate the code
    final code = await execute<String>(
      action: StepType.modify,
      target: 'generating ${request.language ?? 'code'}',
      task: () async {
        if (aiProvider != null) {
          return await _generateWithAI(request, analysis);
        }
        return _generatePlaceholder(request);
      },
    );

    // Step 3: Validate the generated code
    final validated = await execute<String>(
      action: StepType.validate,
      target: 'validating generated code',
      task: () async => _validateCode(code, request.language),
    );

    return validated;
  }

  /// Analyze the code request
  Map<String, dynamic> _analyzeRequest(CodeWriteRequest request) {
    return {
      'prompt_length': request.prompt.length,
      'language': request.language ?? 'dart',
      'has_context': request.context != null,
      'context_length': request.context?.length ?? 0,
    };
  }

  /// Generate code using AI provider
  Future<String> _generateWithAI(
    CodeWriteRequest request,
    Map<String, dynamic> analysis,
  ) async {
    final prompt = '''
Generate ${request.language ?? 'code'} for the following request:

${request.prompt}

${request.context != null ? 'Context:\n${request.context}\n' : ''}
Please provide clean, well-documented code.
''';

    return await aiProvider!.complete(prompt);
  }

  /// Generate placeholder code when no AI provider
  String _generatePlaceholder(CodeWriteRequest request) {
    final lang = request.language ?? 'dart';
    return '''
// TODO: Implement based on request: ${request.prompt}
// Language: $lang
// Generated at: ${DateTime.now().toIso8601String()}

// NOTE: No AI provider configured. 
// Connect an AI provider to generate actual code.
''';
  }

  /// Validate the generated code
  String _validateCode(String code, String? language) {
    // Basic validation - ensure it's not empty
    if (code.trim().isEmpty) {
      throw StateError('Generated code is empty');
    }
    return code;
  }
}

/// Request for code generation
class CodeWriteRequest {
  final String prompt;
  final String? language;
  final String? context;
  final Map<String, dynamic>? options;

  const CodeWriteRequest({
    required this.prompt,
    this.language,
    this.context,
    this.options,
  });
}
