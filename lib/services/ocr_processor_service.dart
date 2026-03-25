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
    // Flatten all lines from all blocks
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    // Sort lines by their vertical 'top' coordinate first
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final List<List<TextLine>> grouped = [];
    const int verticalTolerance = 12; // pixels

    for (final line in allLines) {
      bool placed = false;
      for (final group in grouped) {
        // If the line is vertically close to an existing group, add it
        final groupTop = group[0].boundingBox.top;
        if ((line.boundingBox.top - groupTop).abs() < verticalTolerance) {
          group.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) grouped.add([line]);
    }

    // Sort fragments in each group left-to-right (X-axis) and join with spaces
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

    // 2nd Pass: Macros
    for (var line in lines) {
      // Strip 'kj' values to prevent them from overriding kcal (e.g., "145 kcal (608 kJ)")
      line = line.replaceAll(RegExp(r'\d+\.?\d*\s*kj'), '');

      // 1. Extract Kcal (look for energy/tenaga/cal)
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
      if (fat == 0 && _matches(line, [r'fat', r'lemak', r'lipid'])) {
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
    final numbers = matches.map((m) => num.tryParse(m.group(0)!) ?? 0).where((n) => n > 0).toList();
    
    if (numbers.isEmpty) return 0;
    if (numbers.length == 1) return numbers.first;
    
    // Use mathematical ratio to deduce "Per 100" vs "Per Serving" column
    // This only works reliably for weight/volume (g/ml), not arbitrary pieces.
    if (servingSize > 0 && servingSize != 100 && servingUnit != 'pcs' && numbers.length >= 2) {
      final a = numbers[0];
      final b = numbers[1];
      final expectedRatio = 100.0 / servingSize;
      
      final ratioAB = a / b;
      final ratioBA = b / a;
      
      // Allow 20% margin of error due to rounding in nutrition labels
      if ((ratioAB - expectedRatio).abs() / expectedRatio < 0.20) {
        // 'a' is the 100g value, 'b' is the serving value -> we want 'b'
        return b;
      } else if ((ratioBA - expectedRatio).abs() / expectedRatio < 0.20) {
        // 'b' is the 100g value, 'a' is the serving value -> we want 'a'
        return a;
      }
    }
    
    // Fallback: Default to the last number (Per Serving is typically on the far right)
    return numbers.last;
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
