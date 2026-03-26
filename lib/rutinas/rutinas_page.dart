import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RutinasPage extends StatefulWidget {
  const RutinasPage({super.key});

  @override
  State<RutinasPage> createState() => _RutinasPageState();
}

class _RutinasPageState extends State<RutinasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _workouts = [];
  String? _expandedWorkoutId;
  final Map<String, TextEditingController> _notesControllers = {};
  Timer? _debounceTimer;

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
    _loadWorkouts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _notesControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
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
          _workouts = [];
        });
        return;
      }

      final snapshot = await _firestore
          .collection('rutinas')
          .where('cliente_ID', isEqualTo: userId)
          .where('entrenador_ID', isEqualTo: trainerId)
          .where('activo', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> workouts = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        workouts.add(data);
      }

      if (!mounted) return;
      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading workouts: $e';
      });
    }
  }

  Future<void> _updateExercise(
    String workoutId,
    String dayId,
    String exerciseId,
    bool completed,
    String notes,
  ) async {
    try {
      await _firestore.collection('rutinas').doc(workoutId).update({
        'dias.$dayId.ej.$exerciseId.completado': completed,
        'dias.$dayId.ej.$exerciseId.observaciones': notes,
      });

      setState(() {
        final workoutIndex =
            _workouts.indexWhere((w) => w['id'] == workoutId);
        if (workoutIndex != -1) {
          _workouts[workoutIndex]['dias'][dayId]['ej'][exerciseId]
              ['completado'] = completed;
          _workouts[workoutIndex]['dias'][dayId]['ej'][exerciseId]
              ['observaciones'] = notes;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating exercise: $e'),
          backgroundColor: accent1,
        ),
      );
    }
  }

  // Day IDs in Firestore are stored in Spanish (set by the trainer app).
  // These keywords are used to match and sort them; display names are in English.
  final List<String> _dayOrder = [
    'lunes', 'martes', 'miercoles',
    'jueves', 'viernes', 'sabado', 'domingo'
  ];

  String _normalizeDay(String day) {
    return day.toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('á', 'a')
        .replaceAll('ó', 'o')
        .replaceAll('í', 'i')
        .replaceAll('ú', 'u');
  }

  int _getDayOrder(String dayId) {
    final normalized = _normalizeDay(dayId);
    for (int i = 0; i < _dayOrder.length; i++) {
      if (normalized.contains(_dayOrder[i])) return i;
    }
    return _dayOrder.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/gym1.jpg'),
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
              onPressed: _loadWorkouts,
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

    if (_workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: primaryLight),
            const SizedBox(height: 16),
            Text(
              'No workouts assigned',
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
      onRefresh: _loadWorkouts,
      backgroundColor: accent1,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workouts.length,
        itemBuilder: (context, index) {
          final workout = _workouts[index];
          final days = workout['dias'] as Map<String, dynamic>? ?? {};
          final isExpanded = _expandedWorkoutId == workout['id'];

          final sortedDays = days.entries.toList()
            ..sort((a, b) =>
                _getDayOrder(a.key).compareTo(_getDayOrder(b.key)));

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
                  _expandedWorkoutId =
                      isExpanded ? null : workout['id'];
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
                          'Workout #${index + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${days.length} days',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (workout['fechaCreacion'] != null)
                      Text(
                        'Created: ${_formatDate(workout['fechaCreacion'].toDate())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    if (isExpanded) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Training days:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: sortedDays.map<Widget>((entry) {
                          final dayId = entry.key;
                          final dayData =
                              entry.value as Map<String, dynamic>;
                          final exercises =
                              dayData['ej'] as Map<String, dynamic>? ?? {};
                          final dayName = _getDayName(dayId);

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryLight,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _showDayDetails(
                                    workout['id'], dayId, dayData);
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dayName),
                                  Text(
                                      '${exercises.length} exercises'),
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

  String _getDayName(String dayId) {
    if (dayId.toLowerCase().contains('lunes')) return 'Monday';
    if (dayId.toLowerCase().contains('martes')) return 'Tuesday';
    if (dayId.toLowerCase().contains('miercoles') ||
        dayId.toLowerCase().contains('miércoles')) return 'Wednesday';
    if (dayId.toLowerCase().contains('jueves')) return 'Thursday';
    if (dayId.toLowerCase().contains('viernes')) return 'Friday';
    if (dayId.toLowerCase().contains('sabado') ||
        dayId.toLowerCase().contains('sábado')) return 'Saturday';
    if (dayId.toLowerCase().contains('domingo')) return 'Sunday';
    return dayId;
  }

  void _showDayDetails(
      String workoutId, String dayId, Map<String, dynamic> dayData) {
    final exercises = dayData['ej'] as Map<String, dynamic>? ?? {};
    final trainingTime = dayData['horaEntrenamiento'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
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
                        _getDayName(dayId),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (trainingTime != null)
                        Text(
                          'Time: ${_formatTime(trainingTime.toDate())}',
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
                    'Exercises (${exercises.length}):',
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
                      itemCount: exercises.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: primaryLight),
                      itemBuilder: (context, index) {
                        final exerciseEntry =
                            exercises.entries.elementAt(index);
                        final exerciseId = exerciseEntry.key;
                        final exerciseData =
                            exerciseEntry.value as Map<String, dynamic>;

                        final controllerKey =
                            '$workoutId-$dayId-$exerciseId';
                        if (!_notesControllers.containsKey(controllerKey)) {
                          _notesControllers[controllerKey] =
                              TextEditingController(
                            text: exerciseData['observaciones'] ?? '',
                          );
                        }

                        return _buildExerciseItem(
                          workoutId,
                          dayId,
                          exerciseId,
                          exerciseData,
                          _notesControllers[controllerKey]!,
                        );
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

  Widget _buildExerciseItem(
    String workoutId,
    String dayId,
    String exerciseId,
    Map<String, dynamic> exerciseData,
    TextEditingController notesController,
  ) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exerciseData['nombre'] ?? 'No name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Switch(
                  value: exerciseData['completado'] ?? false,
                  onChanged: (value) {
                    _updateExercise(
                      workoutId,
                      dayId,
                      exerciseId,
                      value,
                      notesController.text,
                    );
                  },
                  activeThumbColor: accent1,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildExerciseData('Weight', '${exerciseData['pesoE']} kg'),
                _buildExerciseData(
                    'Reps', exerciseData['repsE'].toString()),
                _buildExerciseData('RIR', exerciseData['RIRE'].toString()),
              ],
            ),
            if (exerciseData['series'] != null &&
                exerciseData['series'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildExerciseData('Sets', exerciseData['series']),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Notes',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryLight),
                ),
                filled: true,
                fillColor: background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              maxLines: 2,
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 700), () {
                  _updateExercise(
                    workoutId,
                    dayId,
                    exerciseId,
                    exerciseData['completado'] ?? false,
                    value,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseData(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
