/// Supported voice command languages. The STT locale and parser vocabulary
/// are selected based on this setting. Product names are never translated.
enum VoiceLanguage {
  english,
  hindi,
  marathi,
  hinglish,
  auto;

  /// Human-readable label for the settings UI.
  String get label => switch (this) {
        VoiceLanguage.english => 'English',
        VoiceLanguage.hindi => 'Hindi',
        VoiceLanguage.marathi => 'Marathi',
        VoiceLanguage.hinglish => 'Hinglish',
        VoiceLanguage.auto => 'Auto',
      };

  /// Android STT locale identifier. `null` for auto (device default).
  String? get sttLocaleId => switch (this) {
        VoiceLanguage.english => 'en-IN',
        VoiceLanguage.hindi => 'hi-IN',
        VoiceLanguage.marathi => 'mr-IN',
        VoiceLanguage.hinglish => 'hi-IN',
        VoiceLanguage.auto => null,
      };

  /// Android TTS locale identifier. `null` when no best-fit exists.
  String? get ttsLocaleId => switch (this) {
        VoiceLanguage.english => 'en-IN',
        VoiceLanguage.hindi => 'hi-IN',
        VoiceLanguage.marathi => 'mr-IN',
        VoiceLanguage.hinglish => null,
        VoiceLanguage.auto => null,
      };

  /// Persists as a lowercase string key.
  String get storageKey => name;

  /// Restores from a persisted key; falls back to [VoiceLanguage.english].
  static VoiceLanguage fromStorageKey(String? key) {
    if (key == null) return VoiceLanguage.english;
    for (final v in VoiceLanguage.values) {
      if (v.storageKey == key) return v;
    }
    return VoiceLanguage.english;
  }
}
