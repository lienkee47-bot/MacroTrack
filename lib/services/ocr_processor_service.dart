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
      
      // 1. Group all detected lines into "Global Horizontal Lines" based on Y-coordinates
      final List<String> sortedLines = _reconstructHorizontalLines(recognizedText);
      
      return _parseNutritionLines(sortedLines);
    } finally {
      textRecognizer.close();
    }
  }

  /// Groups text fragments into horizontal lines based on their vertical position.
  /// This handles tables where columns might be in separate ML Kit blocks.
  static List<String> _reconstructHorizontalLines(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    // 1. Sort by the Center-Y coordinate instead of Top
    allLines.sort((a, b) {
      final centerA = a.boundingBox.top + (a.boundingBox.height / 2);
      final centerB = b.boundingBox.top + (b.boundingBox.height / 2);
      return centerA.compareTo(centerB);
    });

    final List<List<TextLine>> grouped = [];

    for (final line in allLines) {
      bool placed = false;
      final lineCenterY = line.boundingBox.top + (line.boundingBox.height / 2);
      // 2. Dynamic tolerance based on the text height (e.g., 80% of line height)
      final dynamicTolerance = line.boundingBox.height * 0.8; 

      for (final group in grouped) {
        final groupCenterY = group[0].boundingBox.top + (group[0].boundingBox.height / 2);
      
        if ((lineCenterY - groupCenterY).abs() < dynamicTolerance) {
          group.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) grouped.add([line]);
    }

    final List<String> finalLines = [];
    for (final group in grouped) {
      group.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final lineText = group.map((l) => l.text).join(' ');
      finalLines.add(lineText.toLowerCase());
    }

    return finalLines;
  }

  /// Parse reconstructed lines to find macro values.
  static FoodModel _parseNutritionLines(List<String> lines) {
    num servingSize = 0;
    String servingUnit = 'g';

    // 1st Pass: Finding serving size and tightly coupling its unit
    for (var line in lines) {
      if (servingSize == 0 && _matches(line, [r'serving size', r'saiz hidangan', r'sajian', r'per serving'])) {
        final match = RegExp(r'(\d+\.?\d*)\s*(g|ml|pcs|piece|pieces|keping|tin)\b').firstMatch(line);
        if (match != null) {
          servingSize = num.tryParse(match.group(1) ?? '') ?? 0;
          final rawUnit = match.group(2) ?? 'g';
          if (rawUnit == 'ml') {
            servingUnit = 'ml';
          } else if (['pcs', 'piece', 'pieces', 'keping', 'tin'].contains(rawUnit)) {
            servingUnit = 'pcs';
          } else {
            servingUnit = 'g';
          }
        } else {
          servingSize = _extractFirstNumberOnLine(line);
        }
      }
    }

    num kcal = 0;
    num protein = 0;
    num carbs = 0;
    num fat = 0;
    
    // State tracker to give the parser "memory" for stacked tables
    bool isInside100gBlock = false;

    // 2nd Pass: Macros
    for (var line in lines) {
      // Toggle ON: Detect if we are entering a "Per 100g" stacked block.
      // We ensure it doesn't contain "serving" or "hidangan" to avoid false positives on side-by-side headers.
      if (_matches(line, [r'per 100g', r'setiap 100g']) && 
          !_matches(line, [r'serving', r'hidangan', r'sajian'])) {
        isInside100gBlock = true;
      }
      
      // Toggle OFF: Detect if we are entering a "Per Serving" block.
      if (_matches(line, [r'per serving', r'setiap hidangan', r'per package', r'jumlah hidangan'])) {
        isInside100gBlock = false;
      }

      // Clean up kJ more aggressively, handling brackets like "(608 kJ)"
      line = line.replaceAll(RegExp(r'\(\s*\d+\.?\d*\s*kj\s*\)'), ''); 
      line = line.replaceAll(RegExp(r'\d+\.?\d*\s*kj'), '');

      // If inside a dedicated 100g block (and serving size != 100), SKIP reading macros.
      if (isInside100gBlock && servingSize != 100) continue;

      // 1. Extract Kcal
      if (kcal == 0 && _matches(line, [r'energy', r'tenaga', r'kcal', r'calories', r'cal'])) {
        kcal = _extractBestMacro(line, servingSize, servingUnit);
      }
      // 2. Extract Protein
      if (protein == 0 && _matches(line, [r'protein', r'protin'])) {
        protein = _extractBestMacro(line, servingSize, servingUnit);
      }
      // 3. Extract Carbs
      if (carbs == 0 && _matches(line, [r'carb', r'karbohidrat'])) {
        carbs = _extractBestMacro(line, servingSize, servingUnit);
      }
      // 4. Extract Fat
      if (fat == 0 && _matches(line, [r'fat', r'lemak', r'lipid', r'jumlah lemak'])) {
        fat = _extractBestMacro(line, servingSize, servingUnit);
      }
    }

    return FoodModel(
      name: '',
      servingSize: servingSize > 0 ? servingSize : 100,
      servingUnit: servingUnit,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  static bool _matches(String line, List<String> keywords) {
    return keywords.any((k) => line.contains(k));
  }

  /// Dynamically extracts the correct macro using a mathematical ratio to identify the 'Per Serving' column.
  static num _extractBestMacro(String line, num servingSize, String servingUnit) {
    final matches = RegExp(r'(\d+\.?\d*)').allMatches(line);
    List<num> numbers = matches
      .map((m) => num.tryParse(m.group(0)!) ?? 0)
      .where((n) => n > 0)
      .toList();
  
    if (numbers.isEmpty) return 0;

    // SANITY CHECK: Remove obvious OCR hallucinations (e.g., 71.8g carb in 40g serving)
    // Only apply this check if the serving unit is grams or ml
    if (servingSize > 0 && (servingUnit == 'g' || servingUnit == 'ml')) {
     // A macro cannot realistically be more than 100% of the serving size weight. 
     // We use a slight buffer (1.1) to account for minor rounding/density anomalies.
     numbers = numbers.where((n) => n <= (servingSize * 1.1)).toList();
    }

    if (numbers.isEmpty) return 0;
    if (numbers.length == 1) return numbers.first;
  
    if (servingSize > 0 && servingSize != 100 && servingUnit != 'pcs' && numbers.length >= 2) {
      final a = numbers[0];
      final b = numbers[1];
      final expectedRatio = 100.0 / servingSize;
    
      final ratioAB = a / b;
      final ratioBA = b / a;
    
      if ((ratioAB - expectedRatio).abs() / expectedRatio < 0.20) {
        return b;
      } else if ((ratioBA - expectedRatio).abs() / expectedRatio < 0.20) {
        return a;
      }
    }
  
    // FIX: Default to the FIRST number. 
    // The 'Per Serving' column is almost always the first column immediately following the nutrient name.
    return numbers.first; 
  }

  /// Extracts the left-most number on the line.
  static num _extractFirstNumberOnLine(String line) {
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(line);
    if (match != null) {
      return num.tryParse(match.group(0) ?? '') ?? 0;
    }
    return 0;
  }
}