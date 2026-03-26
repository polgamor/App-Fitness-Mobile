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
  List<Map<String, dynamic>> _dietas = [];
  String? _dietaExpandidaId;

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
    _cargarDietas();
  }

  Future<void> _cargarDietas() async {
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
            _dietas = []; 
          });
          return;
        }

      final dietasSnapshot = await _firestore
          .collection('dietas')
          .where('cliente_ID', isEqualTo: userId)
          .where('entrenador_ID', isEqualTo: entrenadorId) 
          .where('activo', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> dietas = [];

      for (var doc in dietasSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        dietas.add(data);
      }

      if (!mounted) return;
      setState(() {
        _dietas = dietas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar dietas: $e';
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
              onPressed: _cargarDietas,
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

    if (_dietas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: primaryLight),
            const SizedBox(height: 16),
            Text(
              'No tienes dietas asignadas',
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
      onRefresh: _cargarDietas,
      backgroundColor: accent1,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _dietas.length,
        itemBuilder: (context, index) {
          final dieta = _dietas[index];
          final comidas = dieta['comidas'] as Map<String, dynamic>? ?? {};
          final isExpanded = _dietaExpandidaId == dieta['id'];

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
                  _dietaExpandidaId = isExpanded ? null : dieta['id'];
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
                          'Dieta #${index + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${dieta['caloriasTotales']} kcal',
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
                        'Comidas diarias:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: comidas.entries.map<Widget>((entry) {
                          final comidaId = entry.key;
                          final comidaData = entry.value as Map<String, dynamic>;
                          final calorias = comidaData['calorias'] ?? 0;
                          
                          String comidaNombre = _getComidaNombre(comidaId);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent1,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _mostrarDetallesComida(dieta['id'], comidaId, comidaData);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(comidaNombre),
                                  Text('$calorias kcal'),
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

  String _getComidaNombre(String comidaId) {
    if (comidaId.toLowerCase().contains('desayuno')) return 'Desayuno';
    if (comidaId.toLowerCase().contains('comida')) return 'Comida';
    if (comidaId.toLowerCase().contains('cena')) return 'Cena';
    if (comidaId.toLowerCase().contains('snack') || comidaId.toLowerCase().contains('merienda')) {
      return 'Snack/Merienda';
    }
    return comidaId;
  }

  void _mostrarDetallesComida(String dietaId, String comidaId, Map<String, dynamic> comidaData) {
    final opciones = comidaData['opciones'] as Map<String, dynamic>? ?? {};
    
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
                        _getComidaNombre(comidaId),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${comidaData['calorias']} kcal',
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
                    'Opciones disponibles (${opciones.length}):',
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
                      itemCount: opciones.length,
                      separatorBuilder: (context, index) => Divider(color: primaryLight),
                      itemBuilder: (context, index) {
                        final opcionEntry = opciones.entries.elementAt(index);
                        final opcionId = opcionEntry.key;
                        final opcionData = opcionEntry.value as Map<String, dynamic>;
                        
                        return _buildOpcionItem(opcionId, opcionData);
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

  Widget _buildOpcionItem(String opcionId, Map<String, dynamic> opcionData) {
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
              'Opción ${opcionId.replaceAll('opcion', '')}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              opcionData['descripcion'] ?? 'Sin descripción',
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrienteItem('Proteína', opcionData['proteina'] ?? 0, 'g'),
                _buildNutrienteItem('Hidratos', opcionData['hidratos'] ?? 0, 'g'),
                _buildNutrienteItem('Grasas', opcionData['grasas'] ?? 0, 'g'),
              ],
            ),
            if (opcionData['otros'] != null && opcionData['otros'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: primaryLight),
              const SizedBox(height: 5),
              Text(
                'Notas adicionales:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                opcionData['otros'],
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

  Widget _buildNutrienteItem(String label, num value, String unit) {
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