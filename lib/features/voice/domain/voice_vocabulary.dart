/// Multilingual voice-command vocabulary. Central, maintainable synonym
/// tables for Hindi, Marathi, and Hinglish (Roman Hindi) command words.
///
/// Product names are NEVER listed here and are never translated — the
/// parser removes these command tokens from the raw transcript and keeps
/// everything else as the product query. Do not add product names.
class VoiceVocabulary {
  const VoiceVocabulary._();

  // ---------------------------------------------------------------------
  // Intent markers
  // ---------------------------------------------------------------------

  /// ADD: Hindi (Devanagari), Marathi (Devanagari), Roman/Hinglish.
  static const List<String> addHindi = [
    'डालो',
    'डाल',
    'जोड़ो',
    'जोड़',
    'ऐड',
    'एड',
  ];

  static const List<String> addMarathi = [
    'टाका',
    'टाक',
    'जोडा',
    'जोड',
    'अॅड',
    'अँड',
  ];

  static const List<String> addHinglish = [
    'add',
    'daalo',
    'dalo',
    'jodo',
    'add karo',
    'daal do',
  ];

  /// REMOVE: partial/whole-line removal, quantity optional.
  static const List<String> removeHindi = [
    'हटाओ',
    'हटाना',
    'हटा',
    'निकालो',
    'निकाल',
    'कम करो',
  ];

  static const List<String> removeMarathi = [
    'काढा',
    'काढ',
    'हटवा',
    'कमी करा',
  ];

  static const List<String> removeHinglish = [
    'remove',
    'hatao',
    'hata do',
    'hata',
    'nikaalo',
    'nikal do',
  ];

  /// CLEAR: cart only, always confirmed.
  static const List<String> clearHindi = ['कार्ट खाली', 'कार्ट साफ', 'सब हटा'];

  static const List<String> clearMarathi = ['कार्ट रिकामी', 'कार्ट साफ', 'सगळं काढा'];

  static const List<String> clearHinglish = [
    'cart clear',
    'cart khaali',
    'cart saaf',
    'sab remove',
    'sab hata',
  ];

  /// SET_QUANTITY.
  static const List<String> setHindi = ['मात्रा', 'करो'];

  static const List<String> setMarathi = ['संख्या', 'करा'];

  static const List<String> setHinglish = ['quantity', 'qty'];

  // ---------------------------------------------------------------------
  // Query markers
  // ---------------------------------------------------------------------

  /// PRICE.
  static const List<String> priceHindi = ['कीमत', 'भाव', 'दाम', 'कितने का', 'कितने की'];

  static const List<String> priceMarathi = ['किंमत', 'भाव', 'दर', 'कितीला'];

  static const List<String> priceHinglish = [
    'price',
    'rate',
    'daam',
  ];

  /// STOCK.
  static const List<String> stockHindi = ['स्टॉक', 'बचे', 'उपलब्ध'];

  static const List<String> stockMarathi = [
    'स्टॉक',
    'स्टॉकमध्ये',
    'शिल्लक',
    'उपलब्ध',
  ];

  static const List<String> stockHinglish = ['stock'];

  // ---------------------------------------------------------------------
  // Checkout
  // ---------------------------------------------------------------------
  static const List<String> checkoutHindi = ['चेकआउट', 'बिल करो', 'भुगतान'];

  static const List<String> checkoutMarathi = ['चेकआउट', 'बिल करा', 'पेमेंट'];

  static const List<String> checkoutHinglish = ['checkout', 'bill karo', 'payment karo'];

  // ---------------------------------------------------------------------
  // Quantity words
  // ---------------------------------------------------------------------

  /// Hindi (Devanagari) numbers 1–20.
  static const Map<String, int> hindiNumbers = {
    'एक': 1,
    'दो': 2,
    'तीन': 3,
    'चार': 4,
    'पाँच': 5,
    'पांच': 5,
    'छह': 6,
    'सात': 7,
    'आठ': 8,
    'नौ': 9,
    'दस': 10,
    'ग्यारह': 11,
    'बारह': 12,
    'तेरह': 13,
    'चौदह': 14,
    'पंद्रह': 15,
    'सोलह': 16,
    'सत्रह': 17,
    'अठारह': 18,
    'उन्नीस': 19,
    'बीस': 20,
  };

  /// Marathi (Devanagari) numbers 1–20.
  static const Map<String, int> marathiNumbers = {
    'एक': 1,
    'दोन': 2,
    'तीन': 3,
    'चार': 4,
    'पाच': 5,
    'सहा': 6,
    'सात': 7,
    'आठ': 8,
    'नऊ': 9,
    'दहा': 10,
    'अकरा': 11,
    'बारा': 12,
    'तेरा': 13,
    'चौदा': 14,
    'पंधरा': 15,
    'सोळा': 16,
    'सतरा': 17,
    'अठरा': 18,
    'एकोणीस': 19,
    'वीस': 20,
  };

  /// Roman/Hinglish numbers (letters) 1–20.
  static const Map<String, int> romHindiNumbers = {
    'ek': 1,
    'do': 2,
    'teen': 3,
    'char': 4,
    'chaar': 4,
    'paanch': 5,
    'panch': 5,
    'che': 6,
    'saat': 7,
    'aath': 8,
    'nau': 9,
    'das': 10,
    'gyarah': 11,
    'barah': 12,
    'terah': 13,
    'chaudah': 14,
    'pandrah': 15,
    'solah': 16,
    'satrah': 17,
    'atharah': 18,
    'unnees': 19,
  };

  /// Roman/Marathi-Hinglish numbers.
  static const Map<String, int> romMarathiNumbers = {
    'don': 2,
    'tin': 3,
    'pach': 5,
    'paach': 5,
    'saha': 6,
    'daha': 10,
    'akra': 11,
    'bara': 12,
    'tera': 13,
    'chauda': 14,
    'pandhara': 15,
    'sola': 16,
    'satra': 17,
    'athara': 18,
    'ekonis': 19,
    'bees': 20,
  };

  /// All Roman number maps merged (ambivalence: "ek"/"char"/etc. shared).
  static const Map<String, int> romanNumbers = {
    ...romHindiNumbers,
    ...romMarathiNumbers,
  };
}
