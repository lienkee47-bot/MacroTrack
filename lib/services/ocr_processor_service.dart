import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/food_model.dart';

/// Processes a photo of a nutrition label and extracts macro data.
class OcrProcessorService {
  /// Run OCR on [imagePath] and return a [FoodModel] with extracted values.
  static Future<FoodModel> extractFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      return _parseNutritionText(fullText);
    } finally {
      textRecognizer.close();
    }
  }

  /// Parse raw OCR text and pull out numeric values for each macro.
  static FoodModel _parseNutritionText(String text) {
    // Normalise: collapse whitespace, lowercase
    final normalised = text.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    final kcal = _extractNumber(normalised, [
      r'(?:energy|calories|kalori|kcal|cal)\s*[:\-]?\s*([\d.]+)',
      r'([\d.]+)\s*(?:kcal|cal)',
    ]);

    final protein = _extractNumber(normalised, [
      r'(?:protein|protin|protien)\s*[:\-]?\s*([\d.]+)',
      r'([\d.]+)\s*(?:g)\s*(?:protein)',
    ]);

    final carbs = _extractNumber(normalised, [
      r'(?:carbohydrate|karbohidrat|carbs?|total carb)\s*[:\-]?\s*([\d.]+)',
      r'([\d.]+)\s*(?:g)\s*(?:carb)',
    ]);

    final fat = _extractNumber(normalised, [
      r'(?:fat|lemak|lipid|total fat)\s*[:\-]?\s*([\d.]+)',
      r'([\d.]+)\s*(?:g)\s*(?:fat)',
    ]);

    final servingSize = _extractNumber(normalised, [
      r'(?:serving size|per serving|per|sajian)\s*[:\-]?\s*([\d.]+)',
      r'([\d.]+)\s*(?:g|ml)\s*(?:per|serving|sajian)',
    ]);

    final servingUnit = _extractServingUnit(normalised);

    return FoodModel(
      name: '', // user will fill this in
      servingSize: servingSize > 0 ? servingSize : 100,
      servingUnit: servingUnit,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  /// Try each [patterns] in order and return the first numeric match.
  static num _extractNumber(String text, List<String> patterns) {
    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(text);
      if (match != null) {
        final value = num.tryParse(match.group(1) ?? '');
        if (value != null && value > 0) return value;
      }
    }
    return 0;
  }

  /// Guess the serving unit from the OCR text.
  static String _extractServingUnit(String text) {
    // Look near "serving size" or "per" for a unit
    final match = RegExp(
      r'(?:serving size|per serving|per|sajian)\s*[:\-]?\s*[\d.]+\s*(g|ml|pcs|pieces|keping)',
    ).firstMatch(text);
    if (match != null) {
      final unit = match.group(1) ?? 'g';
      if (unit.contains('ml')) return 'ml';
      if (unit.contains('pcs') || unit.contains('piece') || unit.contains('keping')) return 'pcs';
    }
    return 'g';
  }
}
