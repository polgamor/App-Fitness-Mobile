import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../auth/asociar_entrenador_dialog.dart';
import '../database/image_picker_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePickerService _imagePickerService = ImagePickerService(); 
  
  File? _profileImage;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _activo = true;
  String? _entrenadorId;
  String? _currentProfileImageUrl; 
  Uint8List? _profileImageBytes;
  
  late TextEditingController _nombreController;
  late TextEditingController _apellido1Controller;
  late TextEditingController _apellido2Controller;
  late TextEditingController _telefonoController;
  late TextEditingController _pesoController;
  late TextEditingController _alturaController;
  DateTime? _fechaNacimiento;
  int? _objetivo;
  
  final Map<int, String> _objetivos = {
    1: 'Definición',
    2: 'Volumen',
    3: 'Recomposición'
  };

  // Paleta de colores
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
    _nombreController = TextEditingController();
    _apellido1Controller = TextEditingController();
    _apellido2Controller = TextEditingController();
    _telefonoController = TextEditingController();
    _pesoController = TextEditingController();
    _alturaController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellido1Controller.dispose();
    _apellido2Controller.dispose();
    _telefonoController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null || !mounted) return;

      final doc = await _firestore.collection('clientes').doc(user.uid).get();
      
      if (!doc.exists) {
        await _initializeUserData(user.uid);
        return;
      }

      final data = doc.data() ?? {}; 
      
      setState(() {
        _nombreController.text = data['nombre']?.toString() ?? '';
        _apellido1Controller.text = data['apellido']?.toString() ?? '';
        _apellido2Controller.text = data['apellido2']?.toString() ?? '';
        _telefonoController.text = data['telefono']?.toString() ?? '';
        _pesoController.text = data['peso']?.toString() ?? '0'; 
        _alturaController.text = data['altura']?.toString() ?? '0';
        _fechaNacimiento = data['fecha_nacimiento']?.toDate();
        _objetivo = _objetivos.containsKey(data['objetivo']) ? data['objetivo'] : null;
        _activo = data['activo'] ?? true;
        _entrenadorId = data['entrenador_ID']?.toString() ?? "";
        _currentProfileImageUrl = data['foto_perfil']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeUserData(String uid) async {
    await _firestore.collection('clientes').doc(uid).set({
      'nombre': '',
      'apellido': '',
      'apellido2': '',
      'telefono': '',
      'peso': 0,
      'altura': 0,
      'activo': true,
      'entrenador_ID': "",
      'fecha_nacimiento': null,
      'objetivo': null,
      'foto_perfil': null,
    });
    await _loadUserData(); 
  }

  Future<void> _updateProfile() async {
    final peso = int.tryParse(_pesoController.text) ?? 0;
    final altura = int.tryParse(_alturaController.text) ?? 0;
    
    if (peso < 30 || peso > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un peso válido (30-300 kg)')),
      );
      return;
    }

    if (altura < 100 || altura > 250) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una altura válida (100-250 cm)')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (!mounted) return;
      setState(() => _isLoading = true);

      String? imageUrl = _currentProfileImageUrl; 
      
      if ((_profileImageBytes != null && kIsWeb) || (_profileImage != null && !kIsWeb)) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images/${user.uid}.jpg');
        
        if (kIsWeb) {
          // Subir los bytes directamente en web
          await storageRef.putData(_profileImageBytes!);
        } else {
          // Subir el archivo en móvil
          await storageRef.putFile(_profileImage!);
        }
        
        imageUrl = await storageRef.getDownloadURL();
      }

      await _firestore.collection('clientes').doc(user.uid).set({
        'nombre': _nombreController.text,
        'apellido': _apellido1Controller.text,
        'apellido2': _apellido2Controller.text,
        'telefono': _telefonoController.text,
        'fecha_nacimiento': _fechaNacimiento,
        'objetivo': _objetivo,
        'peso': peso,
        'altura': altura,
        'activo': _activo,
        if (imageUrl != null) 'foto_perfil': imageUrl,
      }, SetOptions(merge: true)); 

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false;
        _currentProfileImageUrl = imageUrl;
        _profileImage = null;
        _profileImageBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seleccionar imagen',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (!kIsWeb) 
              ListTile(
                leading: Icon(Icons.camera_alt, color: accent1),
                title: Text('Cámara', style: TextStyle(color: textColor)),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ListTile(
              leading: Icon(Icons.photo_library, color: accent1),
              title: Text('Galería', style: TextStyle(color: textColor)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (option == null || !mounted) return;

    try {
      Uint8List? imageBytes;
      
      if (kIsWeb && option == 'gallery') {
        final imageResult = await _imagePickerService.pickImageFromGallery();
        if (imageResult != null && mounted) {
          setState(() {
            _profileImageBytes = imageResult.bytes;
          });
        }
        return;
      } else if (option == 'gallery') {
        final imageResult = await _imagePickerService.pickImageFromGallery();
        if (imageResult != null) {
          imageBytes = imageResult.bytes;
        }
      } else if (option == 'camera') {
        final imageResult = await _imagePickerService.pickImageFromCamera();
        if (imageResult != null) {
          imageBytes = imageResult.bytes;
        }
      }

      if (imageBytes != null && mounted) {
        setState(() {
          _profileImageBytes = imageBytes;
          if (!kIsWeb && _profileImageBytes != null) {
            _profileImage = File.fromRawPath(_profileImageBytes!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _mostrarDialogoAsociarEntrenador() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AsociarEntrenadorDialog(),
    );

    if (result == true && mounted) {
      await _loadUserData();
    }
  }

  Future<void> _mostrarDialogoEliminarEntrenador() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Eliminar Entrenador', style: TextStyle(color: textColor)),
        content: Text(
          '¿Estás seguro de que deseas eliminar al entrenador asociado?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _eliminarEntrenador();
    }
  }

  Future<void> _eliminarEntrenador() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (!mounted) return;
      setState(() => _isLoading = true);

      await _firestore.collection('clientes').doc(user.uid).update({
        'entrenador_ID': "",
      });

      if (!mounted) return;
      setState(() {
        _entrenadorId = "";
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrenador eliminado correctamente')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar entrenador: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime.now().subtract(const Duration(days: 365 * 18)), 
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accent1,
              surface: cardColor,
            ), 
            dialogTheme: DialogThemeData(backgroundColor: background),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _cerrarSesion() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  Future<void> _mostrarDialogoEliminarCuenta() async {
    final passwordController = TextEditingController();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Eliminar Cuenta', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esta acción es irreversible. Introduce tu contraseña para confirmar:',
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: accent1),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _eliminarCuenta(passwordController.text);
    }
    passwordController.dispose();
  }

  Future<void> _eliminarCuenta(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      
      await user.reauthenticateWithCredential(cred);
      await _firestore.collection('clientes').doc(user.uid).delete();
      await user.delete();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar cuenta: $e')),
        );
      }
    }
  }

  Widget _buildEditButton() {
    return IconButton(
      icon: Icon(_isEditing ? Icons.save : Icons.edit, color: textColor),
      onPressed: () {
        if (_isEditing) {
          _updateProfile();
        } else {
          setState(() => _isEditing = true);
        }
      },
    );
  }

  Widget _buildProfileImage() {
    ImageProvider? imageProvider;
    
    if (_profileImageBytes != null) {
      imageProvider = MemoryImage(_profileImageBytes!);
    } else if (_profileImage != null) {
      imageProvider = FileImage(_profileImage!);
    } else if (_currentProfileImageUrl != null && _currentProfileImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_currentProfileImageUrl!);
    }
    
    return CircleAvatar(
      radius: 60,
      backgroundColor: primaryMedium,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(Icons.person, size: 50, color: textColor)
          : null,
    );
  }

  Widget _buildEditableField(
    String label, 
    TextEditingController controller,
    TextInputType keyboardType, {
    bool isNumber = false,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: _isEditing,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor),
            inputFormatters: isNumber 
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryLight),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixText: suffixText,
              suffixStyle: TextStyle(color: textColor.withOpacity(0.7)),
            ),
          ),
          Divider(color: primaryMedium, height: 20),
        ],
      ),
    );
  }

  Widget _buildObjetivoSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Objetivo', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _isEditing
              ? DropdownButtonFormField<int>(
                  initialValue: _objetivo != null && _objetivos.containsKey(_objetivo) 
                      ? _objetivo 
                      : null,
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: 'Selecciona un objetivo',
                  ),
                  items: _objetivos.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value, style: TextStyle(color: textColor)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _objetivo = value);
                  },
                  validator: (value) => value == null ? 'Selecciona un objetivo' : null,
                )
              : Text(
                  _objetivo != null ? _objetivos[_objetivo] ?? 'No especificado' : 'No especificado',
                  style: TextStyle(color: textColor),
                ),
          Divider(color: primaryMedium, height: 20),
        ],
      ),
    );
  }

  Widget _buildFechaNacimientoField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fecha de Nacimiento', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _isEditing
              ? Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryLight),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _fechaNacimiento != null
                                    ? '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'
                                    : 'Seleccionar fecha',
                                style: TextStyle(color: textColor),
                              ),
                              Icon(Icons.calendar_today, color: textColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_fechaNacimiento != null && _isEditing)
                      IconButton(
                        icon: Icon(Icons.clear, color: accent1),
                        onPressed: () {
                          setState(() => _fechaNacimiento = null);
                        },
                      ),
                  ],
                )
              : Text(
                  _fechaNacimiento != null
                      ? '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'
                      : 'No especificada',
                  style: TextStyle(color: textColor),
                ),
          Divider(color: primaryMedium, height: 20),
        ],
      ),
    );
  }

  Widget _buildActivoSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Activo', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Switch(
            value: _activo,
            activeThumbColor: accent1,
            onChanged: _isEditing
                ? (value) {
                    setState(() => _activo = value);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEntrenadorButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _entrenadorId?.isEmpty ?? true ? accent2 : accent1,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      onPressed: _isEditing 
          ? (_entrenadorId?.isEmpty ?? true 
              ? _mostrarDialogoAsociarEntrenador 
              : _mostrarDialogoEliminarEntrenador)
          : null,
      child: Text(
        _entrenadorId?.isEmpty ?? true 
            ? 'ASOCIAR ENTRENADOR' 
            : 'ELIMINAR ENTRENADOR ASOCIADO',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: CircularProgressIndicator(color: accent1),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        iconTheme: IconThemeData(color: textColor),
         actions: [
          IconButton(
            icon: Icon(Icons.logout, color: textColor),
            onPressed: _cerrarSesion,
          ),
          _buildEditButton(),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/gym1.jpg'),
            fit: BoxFit.cover,
            opacity: 0.2,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _buildProfileImage(),
                  if (_isEditing)
                    FloatingActionButton(
                      mini: true,
                      backgroundColor: accent1,
                      onPressed: _pickImage,
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildEditableField('Nombre', _nombreController, TextInputType.text),
                      _buildEditableField('Primer Apellido', _apellido1Controller, TextInputType.text),
                      _buildEditableField('Segundo Apellido', _apellido2Controller, TextInputType.text),
                      _buildEditableField('Teléfono', _telefonoController, TextInputType.phone, isNumber: true),
                      _buildEditableField('Peso (kg)', _pesoController, TextInputType.number, isNumber: true, suffixText: 'kg'),
                      _buildEditableField('Altura (cm)', _alturaController, TextInputType.number, isNumber: true, suffixText: 'cm'),
                      _buildFechaNacimientoField(),
                      _buildObjetivoSelector(),
                      _buildActivoSwitch(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildEntrenadorButton(),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _mostrarDialogoEliminarCuenta,
                child: const Text(
                  'ELIMINAR CUENTA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}