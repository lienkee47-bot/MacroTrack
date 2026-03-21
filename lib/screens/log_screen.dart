import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  void _showAddFoodModal(BuildContext context, String mealType, String uid, FirestoreService db) {
    String searchQuery = '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Add to $mealType', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => searchQuery = val),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.grey),
                          hintText: 'Search food database...',
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: db.getFoods(uid),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          
                          var docs = snapshot.data!.docs;
                          
                          if (searchQuery.isNotEmpty) {
                            docs = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              return name.contains(searchQuery.toLowerCase());
                            }).toList();
                          }
                          
                          if (docs.isEmpty) return const Center(child: Text("No custom foods found. Add some in the Database!"));
                          
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var food = docs[index].data() as Map<String, dynamic>;
                              final size = food['servingSize'] ?? 100;
                              final unit = food['servingUnit'] ?? 'g';
                              
                              return ListTile(
                                title: Text(food['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${food['kcal']} kcal per $size$unit'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryOrange),
                                  onPressed: () {
                                    _showQuantityDialog(context, mealType, uid, db, food, size, unit);
                                  },
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  ],
                );
              },
            );
          }
        );
      },
    );
  }

  void _showQuantityDialog(BuildContext parentContext, String mealType, String uid, FirestoreService db, Map<String, dynamic> food, num libSize, String libUnit) {
    final qtyCtrl = TextEditingController();
    
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Add ${food['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Base Serving: $libSize$libUnit'),
              const SizedBox(height: 16),
              const Text('Amount Consumed:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(libUnit),
                ],
              )
            ]
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                final qty = num.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) return;
                
                final multiplier = qty / libSize;
                final kcal = ((food['kcal'] ?? 0) * multiplier);
                final prot = ((food['protein'] ?? 0) * multiplier);
                final carb = ((food['carbs'] ?? 0) * multiplier);
                final fat = ((food['fat'] ?? 0) * multiplier);
                
                final entryData = {
                  'mealType': mealType,
                  'foodName': food['name'],
                  'consumedQuantity': qty,
                  'unit': libUnit,
                  'kcal': kcal,
                  'protein': prot,
                  'carbs': carb,
                  'fat': fat,
                  'timestamp': FieldValue.serverTimestamp(),
                };
                
                db.addFoodToLog(uid, _dateStr, mealType, entryData);
                Navigator.pop(ctx);
                Navigator.pop(parentContext);
                ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text('${food['name']} added to $mealType', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white),
              child: const Text('Save to Log'),
            )
          ]
        );
      }
    );
  }

  void _showEditQuantityDialog(BuildContext parentContext, String uid, FirestoreService db, Map<String, dynamic> loggedFood) {
    final qtyCtrl = TextEditingController(text: loggedFood['consumedQuantity'].toString());
    final oldQty = (loggedFood['consumedQuantity'] as num? ?? 1).toDouble();
    if (oldQty == 0) return;

    showDialog(
      context: parentContext,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit ${loggedFood['foodName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Amount Consumed:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(loggedFood['unit'] ?? ''),
                ],
              )
            ]
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(parentContext).brightness == Brightness.dark ? AppTheme.darkTeal : AppTheme.primaryTeal),
              onPressed: () {
                db.deleteFoodFromLog(uid, _dateStr, loggedFood['docId']);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text('${loggedFood['foodName']} deleted', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal));
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final newQty = num.tryParse(qtyCtrl.text) ?? 0;
                    if (newQty <= 0) return;
                    
                    final multiplier = newQty / oldQty;
                    
                    final entryData = {
                      'consumedQuantity': newQty,
                      'kcal': (loggedFood['kcal'] ?? 0) * multiplier,
                      'protein': (loggedFood['protein'] ?? 0) * multiplier,
                      'carbs': (loggedFood['carbs'] ?? 0) * multiplier,
                      'fat': (loggedFood['fat'] ?? 0) * multiplier,
                    };
                    
                    db.updateFoodInLog(uid, _dateStr, loggedFood['docId'], entryData);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text('${loggedFood['foodName']} updated', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryTeal));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white),
                  child: const Text('Save to Log'),
                ),
              ],
            ),
          ]
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            setState(() {
              _isCalendarExpanded = !_isCalendarExpanded;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Meal Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    DateFormat('EEEE, MMM d').format(_selectedDate),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Icon(_isCalendarExpanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isCalendarExpanded) _buildCalendar(isDark),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.getDailyLogEntries(user.uid, _dateStr),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                Map<String, List<Map<String, dynamic>>> logData = {
                  'Breakfast': [],
                  'Lunch': [],
                  'Dinner': [],
                  'Snacks': [],
                };

                if (snapshot.hasData && snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['docId'] = doc.id;
                    final meal = data['mealType'] as String?;
                    if (meal != null && logData.containsKey(meal)) {
                      logData[meal]!.add(data);
                    }
                  }
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                     _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.wb_sunny_outlined,
                      title: 'Breakfast',
                      foods: logData['Breakfast']!,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.restaurant,
                      title: 'Lunch',
                      foods: logData['Lunch']!,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.nightlight_round,
                      title: 'Dinner',
                      foods: logData['Dinner']!,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.fastfood_outlined,
                      title: 'Snacks',
                      foods: logData['Snacks']!,
                      isDark: isDark,
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDate,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _focusedDate = focusedDay;
            _isCalendarExpanded = false;
          });
        },
        calendarFormat: CalendarFormat.week,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryOrange,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: isDark ? AppTheme.darkTeal : AppTheme.primaryTeal,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildMealCategorySection({
    required BuildContext context,
    required String uid,
    required FirestoreService db,
    required IconData icon,
    required String title,
    required List<Map<String, dynamic>> foods,
    required bool isDark,
    bool isExpanded = false,
  }) {
    int totalKcal = foods.fold(0, (acc, item) => acc + (item['kcal'] as num? ?? 0).toInt());
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    List<Widget> logItems = foods.map((food) {
      double p = (food['protein'] as num? ?? 0).toDouble();
      double c = (food['carbs'] as num? ?? 0).toDouble();
      double f = (food['fat'] as num? ?? 0).toDouble();
      
      return _buildLogItem(
        food['foodName'] ?? 'Unknown',
        '${p.toStringAsFixed(1)}p • ${c.toStringAsFixed(1)}c • ${f.toStringAsFixed(1)}f',
        (food['kcal'] as num? ?? 0).toInt(),
        () => _showEditQuantityDialog(context, uid, db, food),
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          iconColor: Colors.grey,
          collapsedIconColor: Colors.grey,
          title: Row(
            children: [
              Icon(icon, color: AppTheme.primaryOrange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$totalKcal kcal',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  if (logItems.isNotEmpty) ...logItems,
                  if (logItems.isEmpty) const Text("No food logged yet", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddFoodModal(context, title, uid, db),
                      icon: const Icon(Icons.add, color: AppTheme.primaryOrange, size: 18),
                      label: const Text(
                        'Add Food',
                        style: TextStyle(color: AppTheme.primaryOrange),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryOrange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(String name, String details, int macros, VoidCallback onLongPress) {
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(details, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            Text('$macros kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
