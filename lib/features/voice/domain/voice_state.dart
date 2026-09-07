import '../../products/domain/product.dart';
import 'voice_command.dart';

/// Interaction phases for one push-to-talk command.
enum VoiceStatus {
  /// Waiting for the next tap.
  idle,

  /// Microphone open, user speaking.
  listening,

  /// Transcript received; parsing/matching/executing.
  processing,

  /// Command executed; message holds the short confirmation.
  success,

  /// Something failed; message holds the concise reason.
  error,

  /// Several products matched; candidates must be shown for picking.
  clarificationRequired,

  /// Destructive command (clear cart) awaits explicit confirmation.
  confirmationRequired,
}

/// Immutable voice interaction state. No redundant mutable fields — the UI
/// renders button labels, transcripts, messages, and candidate chips from
/// this alone (plus a one-shot [checkoutRequestId] the router listens to).
class VoiceState {
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.message = '',
    this.candidates = const [],
    this.pending,
    this.checkoutRequestId = 0,
  });

  final VoiceStatus status;
  final String transcript;
  final String message;

  /// Disambiguation options for [VoiceStatus.clarificationRequired].
  final List<Product> candidates;

  /// The unresolved command awaiting clarification/confirmation.
  final VoiceCommand? pending;

  /// Increments each time voice requests checkout navigation; the UI
  /// listens for increases and pushes `/checkout`. Never reset to zero
  /// mid-session so no request is missed or repeated.
  final int checkoutRequestId;

  VoiceState copyWith({
    VoiceStatus? status,
    String? transcript,
    String? message,
    List<Product>? candidates,
    VoiceCommand? pending,
    bool clearPending = false,
    int? checkoutRequestId,
  }) {
    return VoiceState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      message: message ?? this.message,
      candidates: candidates ?? this.candidates,
      pending: clearPending ? null : (pending ?? this.pending),
      checkoutRequestId: checkoutRequestId ?? this.checkoutRequestId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceState &&
          status == other.status &&
          transcript == other.transcript &&
          message == other.message &&
          checkoutRequestId == other.checkoutRequestId &&
          _sameCandidates(candidates, other.candidates);

  @override
  int get hashCode => Object.hash(
        status,
        transcript,
        message,
        checkoutRequestId,
        Object.hashAll(candidates.map((e) => e.id)),
      );
}

bool _sameCandidates(List<Product> a, List<Product> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}
