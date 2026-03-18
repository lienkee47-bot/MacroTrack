import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  // Target Controllers
  final _kcalTargetCtrl = TextEditingController();
  final _protTargetCtrl = TextEditingController();
  final _carbTargetCtrl = TextEditingController();
  final _fatTargetCtrl = TextEditingController();

  // New Food Controllers
  final _foodNameCtrl = TextEditingController();
  final _servingSizeCtrl = TextEditingController(text: '100');
  String _servingUnit = 'g';
  final _foodKcalCtrl = TextEditingController();
  final _foodProtCtrl = TextEditingController();
  final _foodCarbCtrl = TextEditingController();
  final _foodFatCtrl = TextEditingController();

  String _searchQuery = '';
  bool _targetsInitialized = false;

  @override
  void dispose() {
    _kcalTargetCtrl.dispose();
    _protTargetCtrl.dispose();
    _carbTargetCtrl.dispose();
    _fatTargetCtrl.dispose();
    _foodNameCtrl.dispose();
    _servingSizeCtrl.dispose();
    _foodKcalCtrl.dispose();
    _foodProtCtrl.dispose();
    _foodCarbCtrl.dispose();
    _foodFatCtrl.dispose();
    super.dispose();
  }

  Future<void> _runMigrationOnce(FirestoreService db) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('foods_migrated') == true) return;

    final count = await db.migrateRootFoods();
    await prefs.setBool('foods_migrated', true);

    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migrated $count food(s) to your private library.', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF006666),
        ),
      );
    }
  }

  void _saveTargets(String uid, FirestoreService db) {
    final kcal = num.tryParse(_kcalTargetCtrl.text) ?? 2000;
    final protein = num.tryParse(_protTargetCtrl.text) ?? 150;
    final carbs = num.tryParse(_carbTargetCtrl.text) ?? 200;
    final fat = num.tryParse(_fatTargetCtrl.text) ?? 65;

    db.updateUserTargets(uid, kcal, protein, carbs, fat);
    
    // Instantly reflect fallbacks in the UI
    setState(() {
      _kcalTargetCtrl.text = kcal.toString();
      _protTargetCtrl.text = protein.toString();
      _carbTargetCtrl.text = carbs.toString();
      _fatTargetCtrl.text = fat.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Targets Saved', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF006666)));
  }

  void _saveFood(FirestoreService db, String uid, {String? docId}) {
    if (_foodNameCtrl.text.isEmpty) return;
    
    final name = _foodNameCtrl.text;
    final size = num.tryParse(_servingSizeCtrl.text) ?? 100;
    final kcal = num.tryParse(_foodKcalCtrl.text) ?? 0;
    final prot = num.tryParse(_foodProtCtrl.text) ?? 0;
    final carb = num.tryParse(_foodCarbCtrl.text) ?? 0;
    final fat = num.tryParse(_foodFatCtrl.text) ?? 0;

    if (docId == null) {
      db.addFood(uid, name, size, _servingUnit, kcal, prot, carb, fat);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food Added to Library', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF006666)));
    } else {
      db.updateFood(uid, docId, name, size, _servingUnit, kcal, prot, carb, fat);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food Updated', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF006666)));
    }

    _foodNameCtrl.clear();
    _servingSizeCtrl.text = '100';
    _foodKcalCtrl.clear();
    _foodProtCtrl.clear();
    _foodCarbCtrl.clear();
    _foodFatCtrl.clear();
    Navigator.pop(context);
  }

  void _deleteFood(FirestoreService db, String uid, String docId) {
    db.deleteFood(uid, docId);
    _foodNameCtrl.clear();
    _servingSizeCtrl.text = '100';
    _foodKcalCtrl.clear();
    _foodProtCtrl.clear();
    _foodCarbCtrl.clear();
    _foodFatCtrl.clear();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food Deleted', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
  }

  void _showAddFoodModal(FirestoreService db, String uid, {String? docId, Map<String, dynamic>? existingData}) {
    if (existingData != null) {
      _foodNameCtrl.text = existingData['name']?.toString() ?? '';
      _servingSizeCtrl.text = existingData['servingSize']?.toString() ?? '100';
      _servingUnit = existingData['servingUnit']?.toString() ?? 'g';
      _foodKcalCtrl.text = existingData['kcal']?.toString() ?? '';
      _foodProtCtrl.text = existingData['protein']?.toString() ?? '';
      _foodCarbCtrl.text = existingData['carbs']?.toString() ?? '';
      _foodFatCtrl.text = existingData['fat']?.toString() ?? '';
    } else {
      _foodNameCtrl.clear();
      _servingSizeCtrl.text = '100';
      _servingUnit = 'g';
      _foodKcalCtrl.clear();
      _foodProtCtrl.clear();
      _foodCarbCtrl.clear();
      _foodFatCtrl.clear();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(docId == null ? 'Create New Food' : 'Edit Food', style: const TextStyle(color: Color(0xFFFF6700), fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('FOOD NAME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _foodNameCtrl,
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Almond Butter', hintStyle: TextStyle(color: Colors.grey, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('SERVING SIZE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                            child: TextField(
                              controller: _servingSizeCtrl,
                              decoration: const InputDecoration(border: InputBorder.none, hintText: '100', hintStyle: TextStyle(color: Colors.grey, fontSize: 14)),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _servingUnit,
                                isExpanded: true,
                                items: ['g', 'ml', 'pcs'].map((String value) {
                                  return DropdownMenuItem<String>(value: value, child: Text(value));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      _servingUnit = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildMacroInput('Kcal', _foodKcalCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroInput('Prot (g)', _foodProtCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroInput('Carb (g)', _foodCarbCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMacroInput('Fat (g)', _foodFatCtrl)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (docId == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _saveFood(db, uid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6700),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save to Library', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: () => _deleteFood(db, uid, docId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006666),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Icon(Icons.delete),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed: () => _saveFood(db, uid, docId: docId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6700),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Save to Library', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);

    if (user == null) return const Center(child: Text('Please log in'));

    // One-time migration of root /foods to private sub-collection (persisted)
    _runMigrationOnce(db);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Database', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Daily Targets',
                  style: TextStyle(
                    color: Color(0xFFFF6700),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _saveTargets(user.uid, db),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6700),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Save Targets', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: db.getUserTargets(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var data = snapshot.data!.data() as Map<String, dynamic>?;
                var targets = data?['dailyTargets'] ?? {};

                if (!_targetsInitialized) {
                  _kcalTargetCtrl.text = targets['kcal']?.toString() ?? '2000';
                  _protTargetCtrl.text = targets['protein']?.toString() ?? '150';
                  _carbTargetCtrl.text = targets['carbs']?.toString() ?? '200';
                  _fatTargetCtrl.text = targets['fat']?.toString() ?? '65';
                  _targetsInitialized = true;
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTargetInput('Calories (kcal)', _kcalTargetCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTargetInput('Protein (g)', _protTargetCtrl)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTargetInput('Carbs (g)', _carbTargetCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTargetInput('Fat (g)', _fatTargetCtrl)),
                      ],
                    ),
                  ],
                );
              }
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Food Library',
                  style: TextStyle(
                    color: Color(0xFFFF6700),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddFoodModal(db, user.uid),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('New', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6700),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search custom foods...',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
               stream: db.getFoods(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var docs = snapshot.data!.docs;
                
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();
                }
                
                if (docs.isEmpty) return const Text("No custom foods found.");
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var food = docs[index].data() as Map<String, dynamic>;
                    final size = food['servingSize'] ?? 100;
                    final unit = food['servingUnit'] ?? 'g';
                    final kcal = food['kcal'] ?? 0;
                    
                    return GestureDetector(
                      onLongPress: () => _showAddFoodModal(db, user.uid, docId: docs[index].id, existingData: food),
                      child: _buildFoodLibraryItem(
                        food['name'] ?? 'Unknown',
                        '$kcal kcal per $size$unit',
                        '${food['protein']}p',
                        '${food['carbs']}c',
                        '${food['fat']}f',
                      ),
                    );
                  },
                );
              }
            ),
            const SizedBox(height: 24), // padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildTargetInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodLibraryItem(String name, String calInfo, String p, String c, String f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(calInfo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              _buildMacroChip(p, Colors.grey[200]!),
              const SizedBox(width: 4),
              _buildMacroChip(c, Colors.grey[200]!),
              const SizedBox(width: 4),
              _buildMacroChip(f, Colors.grey[200]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildMacroInput(String label, TextEditingController controller) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(border: InputBorder.none),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
