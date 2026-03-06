import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _servingUnit = 'g'; // For simplicity, kept static in state
  final _foodKcalCtrl = TextEditingController();
  final _foodProtCtrl = TextEditingController();
  final _foodCarbCtrl = TextEditingController();
  final _foodFatCtrl = TextEditingController();

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

  void _saveTargets(String uid, FirestoreService db) {
    db.updateUserTargets(
      uid,
      num.tryParse(_kcalTargetCtrl.text) ?? 2000,
      num.tryParse(_protTargetCtrl.text) ?? 150,
      num.tryParse(_carbTargetCtrl.text) ?? 200,
      num.tryParse(_fatTargetCtrl.text) ?? 65,
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Targets Saved', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF006666)));
  }

  void _saveNewFood(FirestoreService db) {
    if (_foodNameCtrl.text.isEmpty) return;
    db.addFood(
      _foodNameCtrl.text,
      num.tryParse(_foodKcalCtrl.text) ?? 0,
      num.tryParse(_foodProtCtrl.text) ?? 0,
      num.tryParse(_foodCarbCtrl.text) ?? 0,
      num.tryParse(_foodFatCtrl.text) ?? 0,
    );
    _foodNameCtrl.clear();
    _foodKcalCtrl.clear();
    _foodProtCtrl.clear();
    _foodCarbCtrl.clear();
    _foodFatCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food Added to Library', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF006666)));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);

    if (user == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
        title: const Text('Database', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Daily Targets',
              style: TextStyle(
                color: Color(0xFFFF6700),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _saveTargets(user.uid, db),
                child: const Text('Save Targets', style: TextStyle(color: Color(0xFFFF6700))),
              ),
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
                  onPressed: () {},
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
              child: const TextField(
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
              stream: db.getFoods(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text("No custom foods found.");
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var food = docs[index].data() as Map<String, dynamic>;
                    return _buildFoodLibraryItem(
                      food['name'] ?? 'Unknown',
                      '${food['kcal']} kcal per 100g',
                      '${food['protein']}p',
                      '${food['carbs']}c',
                      '${food['fat']}f',
                    );
                  },
                );
              }
            ),
            const SizedBox(height: 32),
            const Text(
              'Create New Food',
              style: TextStyle(
                color: Color(0xFFFF6700),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FOOD NAME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _servingSizeCtrl,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: '100', hintStyle: TextStyle(color: Colors.grey, fontSize: 14)),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _servingUnit,
                              isExpanded: true,
                              items: ['g', 'ml', 'oz', 'cup'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (_) {},
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveNewFood(db),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6700),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save to Library', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(calInfo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
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
