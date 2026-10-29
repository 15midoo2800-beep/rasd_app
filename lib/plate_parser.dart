import 'dart:convert';

class PlateParser {
  // تقييد القاموس الصوتي للكلمات المسموحة فقط لضمان السرعة الفورية
  static List<String> getGrammarWords() {
    return [
      "ألف", "با", "باء", "تا", "تاء", "ثا", "ثاء", "جيم", "حا", "حاء", "خا", "خاء",
      "دال", "ذال", "را", "راء", "زين", "سين", "شين", "صاد", "ضاد", "طا", "طاء",
      "ظا", "ظاء", "عين", "غين", "فا", "فاء", "قاف", "كاف", "لام", "ميم", "نون",
      "ها", "هاء", "واو", "يا", "ياء",
      "صفر", "واحد", "اتنين", "اثنين", "تلاتة", "ثلاثة", "اربعة", "أربعة",
      "خمسة", "ستة", "سبعة", "تمانية", "ثمانية", "تسعة",
      "نقل", "فان", "نقل عام", "ثلاجة كبيرة", "هاي اس", "جراند ماكس", "جامبو",
      "برحة", "يمين", "يسار", "فندق"
    ];
  }

  // جدول التحويل المباشر من الكلمة المنطوقة إلى الرمز
  static final Map<String, String> _wordsMap = {
    "ألف": "أ", "با": "ب", "باء": "ب", "تا": "ت", "تاء": "ت",
    "ثا": "ث", "ثاء": "ث", "جيم": "ج", "حا": "ح", "حاء": "ح",
    "خا": "خ", "خاء": "خ", "دال": "د", "ذال": "ذ", "را": "ر",
    "راء": "ر", "زين": "ز", "سين": "س", "شين": "ش", "صاد": "ص",
    "ضاد": "ض", "طا": "ط", "طاء": "ط", "ظا": "ظ", "ظاء": "ظ",
    "عين": "ع", "غين": "غ", "فا": "ف", "فاء": "ف", "قاف": "ق",
    "كاف": "ك", "لام": "ل", "ميم": "م", "نون": "ن", "ها": "هـ",
    "هاء": "هـ", "واو": "و", "يا": "ي", "ياء": "ي",
    "صفر": "0", "واحد": "1", "اتنين": "2", "اثنين": "2",
    "تلاتة": "3", "ثلاثة": "3", "اربعة": "4", "أربعة": "4",
    "خمسة": "5", "ستة": "6", "سبعة": "7", "تمانية": "8",
    "ثمانية": "8", "تسعة": "9"
  };

  static final List<String> vehicleTypes = [
    "نقل", "فان", "نقل عام", "ثلاجة كبيرة", "هاي اس", "جراند ماكس", "جامبو"
  ];

  static Map<String, dynamic>? parseStream(String rawText) {
    if (rawText.trim().isEmpty) return null;

    List<String> tokens = rawText.trim().split(RegExp(r'\s+'));
    List<String> letters = [];
    List<String> digits = [];
    String vehicleType = "";

    for (int i = 0; i < tokens.length; i++) {
      String token = tokens[i];

      // فحص أنواع المركبات المكونة من كلمتين
      if (i + 1 < tokens.length) {
        String twoWords = "$token ${tokens[i + 1]}";
        if (vehicleTypes.contains(twoWords)) {
          vehicleType = twoWords;
          i++;
          continue;
        }
      }
      if (vehicleTypes.contains(token)) {
        vehicleType = token;
        continue;
      }

      // تحويل الحروف والأرقام
      if (_wordsMap.containsKey(token)) {
        String char = _wordsMap[token]!;
        if (RegExp(r'^[0-9]$').hasMatch(char)) {
          digits.add(char);
        } else {
          letters.add(char);
        }
      }
    }

    // مطابقة هيكل اللوحة (2 إلى 3 حروف و 3 إلى 4 أرقام)
    if (letters.length >= 2 && letters.length <= 3 && digits.length >= 3 && digits.length <= 4) {
      String plateLetters = letters.join(' ');
      String plateNumbers = digits.join('');
      String fullPlate = "$plateLetters $plateNumbers";
      bool requiresType = letters.first == 'أ' || letters.first == 'ب';

      return {
        "plate": fullPlate,
        "letters": plateLetters,
        "numbers": plateNumbers,
        "type": vehicleType,
        "requiresType": requiresType,
        "isComplete": requiresType ? vehicleType.isNotEmpty : true,
      };
    }

    return null;
  }
}
