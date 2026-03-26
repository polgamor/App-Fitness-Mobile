import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _notas = [];

  // Controladores para el formulario
  final TextEditingController _ejercicioController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _repeticionesController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  // Paleta de colores (misma que dietas_page.dart)
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
    _cargarNotas();
  }

  @override
  void dispose() {
    _ejercicioController.dispose();
    _pesoController.dispose();
    _repeticionesController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _cargarNotas() async {
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

      // Modificamos la consulta para evitar el error de índice
      final notasSnapshot = await _firestore
          .collection('notas')
          .where('usuario_ID', isEqualTo: userId)
          .get();
          
      // Ordenamos los resultados manualmente en lugar de en la consulta
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = notasSnapshot.docs;
      docs.sort((a, b) {
        final fechaA = a.data()['fecha'] as Timestamp?;
        final fechaB = b.data()['fecha'] as Timestamp?;
        if (fechaA == null || fechaB == null) return 0;
        return fechaB.compareTo(fechaA);
      });

      final List<Map<String, dynamic>> notas = [];

      for (var doc in docs) {
        final data = doc.data();
        data['id'] = doc.id;
        notas.add(data);
      }

      setState(() {
        _notas = notas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar notas: $e';
      });
    }
  }

  Future<void> _crearNota() async {
    try {
      if (_ejercicioController.text.trim().isEmpty) {
        _mostrarSnackBar('El nombre del ejercicio es obligatorio');
        return;
      }

      double? peso = double.tryParse(_pesoController.text);
      if (_pesoController.text.isNotEmpty && peso == null) {
        _mostrarSnackBar('El peso debe ser un número válido');
        return;
      }

      int? repeticiones = int.tryParse(_repeticionesController.text);
      if (_repeticionesController.text.isNotEmpty && repeticiones == null) {
        _mostrarSnackBar('Las repeticiones deben ser un número entero');
        return;
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _mostrarSnackBar('No hay usuario conectado');
        return;
      }

      await _firestore.collection('notas').add({
        'usuario_ID': userId,
        'ejercicio': _ejercicioController.text.trim(),
        'peso': peso ?? 0,
        'repeticiones': repeticiones ?? 0,
        'notas': _notasController.text.trim(),
        'fecha': Timestamp.now(),
      });

      _limpiarFormulario();

      await _cargarNotas();

      _mostrarSnackBar('Nota creada correctamente');
    } catch (e) {
      _mostrarSnackBar('Error al crear la nota: $e');
    }
  }

  Future<void> _eliminarNota(String notaId) async {
    try {
      await _firestore.collection('notas').doc(notaId).delete();
      await _cargarNotas();
      _mostrarSnackBar('Nota eliminada correctamente');
    } catch (e) {
      _mostrarSnackBar('Error al eliminar la nota: $e');
    }
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: primaryDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _limpiarFormulario() {
    _ejercicioController.clear();
    _pesoController.clear();
    _repeticionesController.clear();
    _notasController.clear();
  }

  void _mostrarDialogoConfirmacion(String notaId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          '¿Eliminar nota?',
          style: TextStyle(color: textColor),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar esta nota? Esta acción no se puede deshacer.',
          style: TextStyle(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: textColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarNota(notaId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent1,
              foregroundColor: Colors.black,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioCrearNota() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nueva nota de ejercicio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: primaryLight),
              const SizedBox(height: 16),
              TextField(
                controller: _ejercicioController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Ejercicio *',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accent1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pesoController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Peso (kg)',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accent1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _repeticionesController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Repeticiones',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accent1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notasController,
                style: TextStyle(color: textColor),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notas adicionales',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accent1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _crearNota();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent1,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Guardar Nota',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: textColor),
            onPressed: _mostrarFormularioCrearNota,
            tooltip: 'Agregar nota',
          ),
        ],
      ),
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
              onPressed: _cargarNotas,
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

    if (_notas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: primaryLight),
            const SizedBox(height: 16),
            Text(
              'No tienes notas guardadas',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Pulsa el botón + para crear una nueva nota',
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _mostrarFormularioCrearNota,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent1,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Crear nota'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarNotas,
      backgroundColor: accent1,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notas.length,
        itemBuilder: (context, index) {
          final nota = _notas[index];
          
          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          nota['ejercicio'] ?? 'Sin nombre',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: accent1),
                        onPressed: () => _mostrarDialogoConfirmacion(nota['id']),
                        tooltip: 'Eliminar nota',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: primaryLight.withOpacity(0.4)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetalleItem(Icons.fitness_center, '${nota['peso']} kg'),
                      _buildDetalleItem(Icons.repeat, '${nota['repeticiones']} reps'),
                      _buildDetalleItem(
                        Icons.calendar_today, 
                        _formatFecha(nota['fecha']),
                      ),
                    ],
                  ),
                  if (nota['notas'] != null && nota['notas'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notas:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nota['notas'],
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetalleItem(IconData icon, String texto) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryLight),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            color: textColor.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatFecha(Timestamp timestamp) {
    final fecha = timestamp.toDate();
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}