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
  List<Map<String, dynamic>> _rutinas = [];
  String? _rutinaExpandidaId;
  final Map<String, TextEditingController> _observacionesControllers = {};

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
    _cargarRutinas();
  }

  @override
  void dispose() {
    _observacionesControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _cargarRutinas() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No hay usuario conectado';
        });
        return;
      }

      final userDoc = await _firestore.collection('clientes').doc(userId).get();
      final entrenadorId = userDoc.data()?['entrenador_ID'] as String?;

      if (entrenadorId == null || entrenadorId.isEmpty) {
        setState(() {
          _isLoading = false;
          _rutinas = []; 
        });
        return;
      }

      final rutinasSnapshot = await _firestore
          .collection('rutinas')
          .where('cliente_ID', isEqualTo: userId)
          .where('entrenador_ID', isEqualTo: entrenadorId) 
          .where('activo', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> rutinas = [];

      for (var doc in rutinasSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        rutinas.add(data);
      }

      setState(() {
        _rutinas = rutinas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar rutinas: $e';
      });
    }
  }

  Future<void> _actualizarEjercicio(
    String rutinaId,
    String diaId,
    String ejercicioId,
    bool completado,
    String observaciones,
  ) async {
    try {
      await _firestore.collection('rutinas').doc(rutinaId).update({
        'dias.$diaId.ej.$ejercicioId.completado': completado,
        'dias.$diaId.ej.$ejercicioId.observaciones': observaciones,
      });

      setState(() {
        final rutinaIndex = _rutinas.indexWhere((r) => r['id'] == rutinaId);
        if (rutinaIndex != -1) {
          _rutinas[rutinaIndex]['dias'][diaId]['ej'][ejercicioId]['completado'] = completado;
          _rutinas[rutinaIndex]['dias'][diaId]['ej'][ejercicioId]['observaciones'] = observaciones;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar ejercicio: $e'),
          backgroundColor: accent1,
        ),
      );
    }
  }

  final List<String> _ordenDias = [
    'lunes', 'martes', 'miercoles',
    'jueves', 'viernes', 'sabado', 'domingo'
  ];

  String _normalizarDia(String dia) {
    return dia.toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('á', 'a')
        .replaceAll('ó', 'o')
        .replaceAll('í', 'i')
        .replaceAll('ú', 'u');
  }

  int _obtenerOrdenDia(String diaId) {
    final normalizedDia = _normalizarDia(diaId);
    for (int i = 0; i < _ordenDias.length; i++) {
      if (normalizedDia.contains(_ordenDias[i])) {
        return i;
      }
    }
    return _ordenDias.length;
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
              onPressed: _cargarRutinas,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent1,
                foregroundColor: Colors.black,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_rutinas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: primaryLight),
            const SizedBox(height: 16),
            Text(
              'No tienes rutinas asignadas',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu entrenador te asignará una pronto',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarRutinas,
      backgroundColor: accent1,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rutinas.length,
        itemBuilder: (context, index) {
          final rutina = _rutinas[index];
          final dias = rutina['dias'] as Map<String, dynamic>? ?? {};
          final isExpanded = _rutinaExpandidaId == rutina['id'];

          final diasOrdenados = dias.entries.toList()
            ..sort((a, b) => _obtenerOrdenDia(a.key).compareTo(_obtenerOrdenDia(b.key)));

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
                  _rutinaExpandidaId = isExpanded ? null : rutina['id'];
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
                          'Rutina #${index + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${dias.length} días',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (rutina['fechaCreacion'] != null)
                      Text(
                        'Creada: ${_formatDate(rutina['fechaCreacion'].toDate())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    if (isExpanded) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Días de entrenamiento:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: diasOrdenados.map<Widget>((entry) {
                          final diaId = entry.key;
                          final diaData = entry.value as Map<String, dynamic>;
                          final ejercicios = diaData['ej'] as Map<String, dynamic>? ?? {};
                          
                          String diaNombre = _getDiaNombre(diaId);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryLight,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _mostrarDetallesDia(rutina['id'], diaId, diaData);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(diaNombre),
                                  Text('${ejercicios.length} ejercicios'),
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

  String _getDiaNombre(String diaId) {
    if (diaId.toLowerCase().contains('lunes')) return 'Lunes';
    if (diaId.toLowerCase().contains('martes')) return 'Martes';
    if (diaId.toLowerCase().contains('miercoles') || diaId.toLowerCase().contains('miércoles')) return 'Miércoles';
    if (diaId.toLowerCase().contains('jueves')) return 'Jueves';
    if (diaId.toLowerCase().contains('viernes')) return 'Viernes';
    if (diaId.toLowerCase().contains('sabado') || diaId.toLowerCase().contains('sábado')) return 'Sábado';
    if (diaId.toLowerCase().contains('domingo')) return 'Domingo';
    return diaId;
  }

  void _mostrarDetallesDia(String rutinaId, String diaId, Map<String, dynamic> diaData) {
    final ejercicios = diaData['ej'] as Map<String, dynamic>? ?? {};
    final horaEntrenamiento = diaData['horaEntrenamiento'] as Timestamp?;
    
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
                        _getDiaNombre(diaId),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (horaEntrenamiento != null)
                        Text(
                          'Hora: ${_formatTime(horaEntrenamiento.toDate())}',
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
                    'Ejercicios (${ejercicios.length}):',
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
                      itemCount: ejercicios.length,
                      separatorBuilder: (context, index) => Divider(color: primaryLight),
                      itemBuilder: (context, index) {
                        final ejercicioEntry = ejercicios.entries.elementAt(index);
                        final ejercicioId = ejercicioEntry.key;
                        final ejercicioData = ejercicioEntry.value as Map<String, dynamic>;
                        
                        final controllerKey = '$rutinaId-$diaId-$ejercicioId';
                        if (!_observacionesControllers.containsKey(controllerKey)) {
                          _observacionesControllers[controllerKey] = TextEditingController(
                            text: ejercicioData['observaciones'] ?? '',
                          );
                        }

                        return _buildEjercicioItem(
                          rutinaId,
                          diaId,
                          ejercicioId,
                          ejercicioData,
                          _observacionesControllers[controllerKey]!,
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

  Widget _buildEjercicioItem(
    String rutinaId,
    String diaId,
    String ejercicioId,
    Map<String, dynamic> ejercicioData,
    TextEditingController observacionesController,
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
                    ejercicioData['nombre'] ?? 'Sin nombre',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Switch(
                  value: ejercicioData['completado'] ?? false,
                  onChanged: (value) {
                    _actualizarEjercicio(
                      rutinaId,
                      diaId,
                      ejercicioId,
                      value,
                      observacionesController.text,
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
                _buildDatoEjercicio('Peso', '${ejercicioData['pesoE']} kg'),
                _buildDatoEjercicio('Reps', ejercicioData['repsE'].toString()),
                _buildDatoEjercicio('RIR', ejercicioData['RIRE'].toString()),
              ],
            ),
            if (ejercicioData['series'] != null && ejercicioData['series'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDatoEjercicio('Series', ejercicioData['series']),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: observacionesController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Observaciones',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              maxLines: 2,
              onChanged: (value) {
                _actualizarEjercicio(
                  rutinaId,
                  diaId,
                  ejercicioId,
                  ejercicioData['completado'] ?? false,
                  value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatoEjercicio(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 13,
          ),
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