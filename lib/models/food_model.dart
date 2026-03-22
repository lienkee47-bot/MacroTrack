/// Simple data class for passing food data between screens and services.
class FoodModel {
  final String name;
  final num servingSize;
  final String servingUnit;
  final num kcal;
  final num protein;
  final num carbs;
  final num fat;

  const FoodModel({
    this.name = '',
    this.servingSize = 100,
    this.servingUnit = 'g',
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  /// Create from a generic map (Firestore doc, API response, etc.)
  factory FoodModel.fromMap(Map<String, dynamic> m) {
    return FoodModel(
      name: m['name']?.toString() ?? '',
      servingSize: _num(m['servingSize'] ?? m['serving_size']),
      servingUnit: m['servingUnit']?.toString() ?? m['serving_unit']?.toString() ?? 'g',
      kcal: _num(m['kcal'] ?? m['calories']),
      protein: _num(m['protein']),
      carbs: _num(m['carbs'] ?? m['carbohydrates']),
      fat: _num(m['fat']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'servingSize': servingSize,
        'servingUnit': servingUnit,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  static num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }
}
