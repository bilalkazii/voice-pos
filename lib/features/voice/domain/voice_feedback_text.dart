import 'voice_language.dart';

/// Deterministic, small localized voice feedback strings for the selected
/// [VoiceLanguage]. This is NOT a translation engine — a fixed, tiny set of
/// short confirmations used by the voice controller. Product names are
/// always inserted verbatim (never translated). Falls back to compact
/// English for Hinglish/Auto when no localized variant is preferred.
class VoiceFeedbackText {
  const VoiceFeedbackText(this.language);

  final VoiceLanguage language;

  String added(String product, {int? quantity}) {
    final eng = (quantity == null || quantity == 1)
        ? 'Added $product.'
        : 'Added $quantity $product.';
    return _localize(
      en: eng,
      hi: '$product जोड़ा गया',
      mr: '$product जोडले',
    );
  }

  String removed(String product) => _localize(
        en: 'Removed $product.',
        hi: '$product हटाया गया',
        mr: '$product काढले',
      );

  String quantityNow(String product, int qty) => _localize(
        en: '$product quantity $qty.',
        hi: '$product की मात्रा $qty',
        mr: '$product ची संख्या $qty',
      );

  String cartCleared() => _localize(
        en: 'Cart cleared.',
        hi: 'कार्ट खाली है',
        mr: 'कार्ट रिकामी आहे',
      );

  String cartEmptyWarning() => _localize(
        en: 'The cart is already empty.',
        hi: 'कार्ट पहले से खाली है',
        mr: 'कार्ट आधीच रिकामी आहे',
      );

  String productNotFound(String product) => _localize(
        en: 'Product not found: $product.',
        hi: '$product नहीं मिला',
        mr: '$product सापडले नाही',
      );

  String notInCart(String product) => _localize(
        en: '"$product" is not in the cart.',
        hi: '$product कार्ट में नहीं है',
        mr: '$product कार्टमध्ये नाही',
      );

  String whichProduct(String product) => _localize(
        en: 'Which $product do you mean?',
        hi: 'कृपया उत्पाद चुनें',
        mr: 'कृपया उत्पादन निवडा',
      );

  String price(String product, String formatted) => _localize(
        en: '"$product" costs $formatted.',
        hi: '$product की कीमत $formatted',
        mr: '$product ची किंमत $formatted',
      );

  String stock(String product, int qty) => _localize(
        en: '"$product" has $qty in stock.',
        hi: '$product के पास स्टॉक में $qty है',
        mr: '$product स्टॉकमध्ये $qty आहे',
      );

  String clearConfirmMessage() => _localize(
        en: 'Clear the current bill?',
        hi: 'मौजूदा बिल खाली करें?',
        mr: 'सध्याचे बिल रिकामे करायचे?',
      );

  String checkoutOpening() => _localize(
        en: 'Opening checkout.',
        hi: 'चेकआउट खोल रहे हैं',
        mr: 'चेकआउट उघडत आहे',
      );

  String checkoutEmptyWarning() => _localize(
        en: 'The cart is empty. Add products first.',
        hi: 'कार्ट खाली है। पहले उत्पाद जोड़ें',
        mr: 'कार्ट रिकामी आहे. आधी उत्पादन जोडा',
      );

  String unknown() => _localize(
        en: "Sorry, I didn't understand that.",
        hi: 'माफ कीजिए, समझ नहीं आया',
        mr: 'क्षमस्व, समजले नाही',
      );

  String noSpeech() => _localize(
        en: "Didn't catch that. Try again.",
        hi: 'सुनाई नहीं दिया। दोबारा कोशिश करें',
        mr: 'ऐकू आले नाही. पुन्हा प्रयत्न करा',
      );

  String micPermission() => _localize(
        en: 'Microphone permission is needed for voice input.',
        hi: 'वॉइस इनपुट के लिए माइक्रोफोन अनुमति आवश्यक है',
        mr: 'व्हॉइस इनपुटसाठी मायक्रोफोन परवानगी आवश्यक आहे',
      );

  String sttUnavailable() => _localize(
        en: 'Speech recognition is unavailable on this device.',
        hi: 'इस डिवाइस पर स्पीच रिकग्निशन उपलब्ध नहीं है',
        mr: 'या डिव्हाइसवर स्पीच रिकग्निशन उपलब्ध नाही',
      );

  String productLoadError() => _localize(
        en: 'Could not load products. Try again.',
        hi: 'उत्पाद लोड नहीं हो सके। दोबारा कोशिश करें',
        mr: 'उत्पादने लोड झाली नाहीत. पुन्हा प्रयत्न करा',
      );

  String _localize({required String en, String? hi, String? mr}) {
    // Hinglish / Auto use compact English fallback (reliable, no per-device
    // TTS dependency).
    switch (language) {
      case VoiceLanguage.english:
        return en;
      case VoiceLanguage.hindi:
        return hi ?? en;
      case VoiceLanguage.marathi:
        return mr ?? en;
      case VoiceLanguage.hinglish:
      case VoiceLanguage.auto:
        return en;
    }
  }
}
