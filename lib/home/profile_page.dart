import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
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

  bool _isEditing = false;
  bool _isLoading = true;
  bool _active = true;
  String? _trainerId;
  String? _currentProfileImageUrl;
  Uint8List? _profileImageBytes;

  late TextEditingController _nameController;
  late TextEditingController _surname1Controller;
  late TextEditingController _surname2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  DateTime? _birthDate;
  int? _goal;

  final Map<int, String> _goals = {
    1: 'Cutting',
    2: 'Bulking',
    3: 'Recomposition',
  };

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
    _nameController = TextEditingController();
    _surname1Controller = TextEditingController();
    _surname2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surname1Controller.dispose();
    _surname2Controller.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null || !mounted) return;

      final doc =
          await _firestore.collection('clientes').doc(user.uid).get();

      if (!doc.exists) {
        await _initializeUserData(user.uid);
        return;
      }

      final data = doc.data() ?? {};

      setState(() {
        _nameController.text = data['nombre']?.toString() ?? '';
        _surname1Controller.text = data['apellido']?.toString() ?? '';
        _surname2Controller.text = data['apellido2']?.toString() ?? '';
        _phoneController.text = data['telefono']?.toString() ?? '';
        _weightController.text = data['peso']?.toString() ?? '0';
        _heightController.text = data['altura']?.toString() ?? '0';
        _birthDate = data['fecha_nacimiento']?.toDate();
        _goal = _goals.containsKey(data['objetivo']) ? data['objetivo'] : null;
        _active = data['activo'] ?? true;
        _trainerId = data['entrenador_ID']?.toString() ?? '';
        _currentProfileImageUrl = data['foto_perfil']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
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
      'entrenador_ID': '',
      'fecha_nacimiento': null,
      'objetivo': null,
      'foto_perfil': null,
    });
    await _loadUserData();
  }

  Future<void> _updateProfile() async {
    final weight = int.tryParse(_weightController.text) ?? 0;
    final height = int.tryParse(_heightController.text) ?? 0;

    if (weight < 30 || weight > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid weight (30-300 kg)')),
      );
      return;
    }

    if (height < 100 || height > 250) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid height (100-250 cm)')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (!mounted) return;
      setState(() => _isLoading = true);

      String? imageUrl = _currentProfileImageUrl;

      if (_profileImageBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images/${user.uid}.jpg');

        await storageRef.putData(_profileImageBytes!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await _firestore.collection('clientes').doc(user.uid).set({
        'nombre': _nameController.text,
        'apellido': _surname1Controller.text,
        'apellido2': _surname2Controller.text,
        'telefono': _phoneController.text,
        'fecha_nacimiento': _birthDate,
        'objetivo': _goal,
        'peso': weight,
        'altura': height,
        'activo': _active,
        if (imageUrl != null) 'foto_perfil': imageUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false;
        _currentProfileImageUrl = imageUrl;
        _profileImageBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update error: $e')),
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
              'Select image',
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
                title: Text('Camera', style: TextStyle(color: textColor)),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ListTile(
              leading: Icon(Icons.photo_library, color: accent1),
              title: Text('Gallery', style: TextStyle(color: textColor)),
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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _showLinkTrainerDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const LinkTrainerDialog(),
    );

    if (result == true && mounted) {
      await _loadUserData();
    }
  }

  Future<void> _showRemoveTrainerDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Remove Trainer', style: TextStyle(color: textColor)),
        content: Text(
          'Are you sure you want to remove the associated trainer?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeTrainer();
    }
  }

  Future<void> _removeTrainer() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (!mounted) return;
      setState(() => _isLoading = true);

      await _firestore
          .collection('clientes')
          .doc(user.uid)
          .update({'entrenador_ID': ''});

      if (!mounted) return;
      setState(() {
        _trainerId = '';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trainer removed successfully')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing trainer: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
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
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Delete Account', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This action is irreversible. Enter your password to confirm:',
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Password',
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
            child: Text('Cancel', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteAccount(passwordController.text);
    }
    passwordController.dispose();
  }

  Future<void> _deleteAccount(String password) async {
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
          SnackBar(content: Text('Error deleting account: $e')),
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
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
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
          Text(label,
              style:
                  TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: _isEditing,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor),
            inputFormatters:
                isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixText: suffixText,
              suffixStyle: TextStyle(color: textColor.withOpacity(0.7)),
            ),
          ),
          Divider(color: primaryMedium, height: 20),
        ],
      ),
    );
  }

  Widget _buildGoalSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Goal',
              style:
                  TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _isEditing
              ? DropdownButtonFormField<int>(
                  initialValue:
                      _goal != null && _goals.containsKey(_goal) ? _goal : null,
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    hintText: 'Select a goal',
                  ),
                  items: _goals.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value,
                          style: TextStyle(color: textColor)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _goal = value);
                  },
                  validator: (value) =>
                      value == null ? 'Select a goal' : null,
                )
              : Text(
                  _goal != null
                      ? _goals[_goal] ?? 'Not specified'
                      : 'Not specified',
                  style: TextStyle(color: textColor),
                ),
          Divider(color: primaryMedium, height: 20),
        ],
      ),
    );
  }

  Widget _buildBirthDateField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date of Birth',
              style:
                  TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _birthDate != null
                                    ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                    : 'Select date',
                                style: TextStyle(color: textColor),
                              ),
                              Icon(Icons.calendar_today, color: textColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_birthDate != null && _isEditing)
                      IconButton(
                        icon: Icon(Icons.clear, color: accent1),
                        onPressed: () {
                          setState(() => _birthDate = null);
                        },
                      ),
                  ],
                )
              : Text(
                  _birthDate != null
                      ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                      : 'Not specified',
                  style: TextStyle(color: textColor),
                ),
          Divider(color: primaryMedium, height: 20),
        ],
      ),
    );
  }

  Widget _buildActiveSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Active',
              style:
                  TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Switch(
            value: _active,
            activeThumbColor: accent1,
            onChanged: _isEditing
                ? (value) {
                    setState(() => _active = value);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _trainerId?.isEmpty ?? true ? accent2 : accent1,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      onPressed: _isEditing
          ? (_trainerId?.isEmpty ?? true
              ? _showLinkTrainerDialog
              : _showRemoveTrainerDialog)
          : null,
      child: Text(
        _trainerId?.isEmpty ?? true
            ? 'LINK TRAINER'
            : 'REMOVE LINKED TRAINER',
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
            onPressed: _signOut,
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
                      child:
                          const Icon(Icons.camera_alt, color: Colors.white),
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
                      _buildEditableField(
                          'Name', _nameController, TextInputType.text),
                      _buildEditableField('First Surname', _surname1Controller,
                          TextInputType.text),
                      _buildEditableField('Second Surname', _surname2Controller,
                          TextInputType.text),
                      _buildEditableField('Phone', _phoneController,
                          TextInputType.phone,
                          isNumber: true),
                      _buildEditableField(
                          'Weight (kg)', _weightController, TextInputType.number,
                          isNumber: true, suffixText: 'kg'),
                      _buildEditableField(
                          'Height (cm)', _heightController, TextInputType.number,
                          isNumber: true, suffixText: 'cm'),
                      _buildBirthDateField(),
                      _buildGoalSelector(),
                      _buildActiveSwitch(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTrainerButton(),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _showDeleteAccountDialog,
                child: const Text(
                  'DELETE ACCOUNT',
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
