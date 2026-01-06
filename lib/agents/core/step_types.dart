/// Canonical action types for all agents.
/// Every agent action must be one of these types.
/// This ensures consistency and prevents hallucinated step types.
enum StepType {
  /// Checking local cache, state, or conditions
  check,

  /// Making a decision about next action
  decide,

  /// Fetching data from network/web
  fetch,

  /// Downloading content (video, file, etc.)
  download,

  /// Extracting data (audio, frames, text)
  extract,

  /// Transcribing audio to text
  transcribe,

  /// Running AI model analysis
  analyze,

  /// Modifying/editing files
  modify,

  /// Validating results
  validate,

  /// Saving output to storage
  store,

  /// Task completed successfully
  complete,

  /// Error occurred during execution
  error,

  /// Waiting for external input or resource
  waiting,

  /// Cancelled by user or system
  cancelled,
}

/// Extension to get human-readable descriptions
extension StepTypeExtension on StepType {
  String get displayName {
    switch (this) {
      case StepType.check:
        return 'Checking';
      case StepType.decide:
        return 'Deciding';
      case StepType.fetch:
        return 'Fetching';
      case StepType.download:
        return 'Downloading';
      case StepType.extract:
        return 'Extracting';
      case StepType.transcribe:
        return 'Transcribing';
      case StepType.analyze:
        return 'Analyzing';
      case StepType.modify:
        return 'Modifying';
      case StepType.validate:
        return 'Validating';
      case StepType.store:
        return 'Storing';
      case StepType.complete:
        return 'Completed';
      case StepType.error:
        return 'Error';
      case StepType.waiting:
        return 'Waiting';
      case StepType.cancelled:
        return 'Cancelled';
    }
  }

  /// Icon for UI representation
  String get icon {
    switch (this) {
      case StepType.check:
        return '🔍';
      case StepType.decide:
        return '🧠';
      case StepType.fetch:
        return '🌐';
      case StepType.download:
        return '⬇️';
      case StepType.extract:
        return '📤';
      case StepType.transcribe:
        return '🎤';
      case StepType.analyze:
        return '🤖';
      case StepType.modify:
        return '✏️';
      case StepType.validate:
        return '✅';
      case StepType.store:
        return '💾';
      case StepType.complete:
        return '🎉';
      case StepType.error:
        return '❌';
      case StepType.waiting:
        return '⏳';
      case StepType.cancelled:
        return '🚫';
    }
  }
}
