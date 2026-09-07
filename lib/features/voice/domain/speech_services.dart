/// Push-to-talk speech recognition. The UI and controller depend ONLY on
/// this abstraction — never on `speech_to_text` directly — so tests inject
/// a fake and no test needs microphone hardware.
abstract class SpeechToTextService {
  /// Prepares recognition (requests the Android microphone permission on
  /// first use). Returns false when unavailable or permission denied.
  /// Must never throw.
  Future<bool> initialize();

  /// Current microphone permission state. Must never throw.
  Future<bool> get hasPermission;

  /// Opens the mic once and returns the final transcript, or null when
  /// nothing was recognized / recognition failed. Must never throw and
  /// must always complete (implementations guard with their own timeout).
  Future<String?> listenOnce();

  /// Closes the mic early (user cancel). Must never throw.
  Future<void> stop();
}

/// Short spoken confirmations ("Added two Pepsi."). Fire-and-forget from
/// the controller: implementations must never throw and never block —
/// a silent phone is always preferable to a slow or crashed sale.
abstract class VoiceFeedbackService {
  Future<void> speak(String text);
  Future<void> stop();
}
