import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietasPage extends StatefulWidget {
  const DietasPage({super.key});

  @override
  State<DietasPage> createState() => _DietasPageState();
}

class _DietasPageState extends State<DietasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _diets = [];
  String? _expandedDietId;

  final Color primaryDark = const Color(0xFF344E41);
  final Color primaryMedium = const Color(0xFF3A5A40);
  final Color primaryLight = const Color(0xFF588157);
  final Color accent1 = const Color(0xFFD65A31);
  final Color accent2 = const Color(0xFFD9A600);
  final Color background = const Color(0xFF1A1A1A);
  final Color cardColor = const Color(0xFF2D2D2D);
  final Color textColor = const Color(0xFFDAD7CD);

  @override
  void initState() {
    super.initState();
    _loadDiets();
  }

  Future<void> _loadDiets() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No user logged in';
        });
        return;
      }

      final userDoc =
          await _firestore.collection('clientes').doc(userId).get();
      final trainerId = userDoc.data()?['entrenador_ID'] as String?;

      if (trainerId == null || trainerId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _diets = [];
        });
        return;
      }

      final snapshot = await _firestore
          .collection('dietas')
          .where('cliente_ID', isEqualTo: userId)
          .where('entrenador_ID', isEqualTo: trainerId)
          .where('activo', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> diets = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        diets.add(data);
      }

      if (!mounted) return;
      setState(() {
        _diets = diets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading diets: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/gym2.jpg'),
            fit: BoxFit.cover,
            opacity: 0.15,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accent1));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!,
                style: TextStyle(color: accent1, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDiets,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent1,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_diets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: primaryLight),
            const SizedBox(height: 16),
            Text(
              'No diet plans assigned',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Your trainer will assign one soon',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDiets,
      backgroundColor: accent1,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _diets.length,
        itemBuilder: (context, index) {
          final diet = _diets[index];
          final meals = diet['comidas'] as Map<String, dynamic>? ?? {};
          final isExpanded = _expandedDietId == diet['id'];

          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _expandedDietId = isExpanded ? null : diet['id'];
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Diet Plan #${index + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${diet['caloriasTotales']} kcal',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isExpanded) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Daily meals:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: meals.entries.map<Widget>((entry) {
                          final mealId = entry.key;
                          final mealData =
                              entry.value as Map<String, dynamic>;
                          final calories = mealData['calorias'] ?? 0;
                          final mealName = _getMealName(mealId);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent1,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _showMealDetails(
                                    diet['id'], mealId, mealData);
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(mealName),
                                  Text('$calories kcal'),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getMealName(String mealId) {
    if (mealId.toLowerCase().contains('desayuno')) return 'Breakfast';
    if (mealId.toLowerCase().contains('comida')) return 'Lunch';
    if (mealId.toLowerCase().contains('cena')) return 'Dinner';
    if (mealId.toLowerCase().contains('snack') ||
        mealId.toLowerCase().contains('merienda')) return 'Snack';
    return mealId;
  }

  void _showMealDetails(
      String dietId, String mealId, Map<String, dynamic> mealData) {
    final options = mealData['opciones'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getMealName(mealId),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${mealData['calorias']} kcal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Divider(color: primaryLight),
                  const SizedBox(height: 10),
                  Text(
                    'Available options (${options.length}):',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: options.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: primaryLight),
                      itemBuilder: (context, index) {
                        final optionEntry = options.entries.elementAt(index);
                        final optionId = optionEntry.key;
                        final optionData =
                            optionEntry.value as Map<String, dynamic>;
                        return _buildOptionItem(optionId, optionData);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionItem(String optionId, Map<String, dynamic> optionData) {
    return Card(
      color: background,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: primaryLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Option ${optionId.replaceAll('opcion', '')}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              optionData['descripcion'] ?? 'No description',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientItem('Protein', optionData['proteina'] ?? 0, 'g'),
                _buildNutrientItem('Carbs', optionData['hidratos'] ?? 0, 'g'),
                _buildNutrientItem('Fats', optionData['grasas'] ?? 0, 'g'),
              ],
            ),
            if (optionData['otros'] != null &&
                optionData['otros'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: primaryLight),
              const SizedBox(height: 5),
              Text(
                'Additional notes:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                optionData['otros'],
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientItem(String label, num value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '$value $unit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
