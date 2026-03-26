import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AsociarEntrenadorDialog extends StatefulWidget {
  const AsociarEntrenadorDialog({super.key});

  @override
  State<AsociarEntrenadorDialog> createState() => _AsociarEntrenadorDialogState();
}

class _AsociarEntrenadorDialogState extends State<AsociarEntrenadorDialog> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;

  Future<void> _asociarEntrenadorConToken() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Debes iniciar sesión primero';

      final token = _tokenController.text.trim();
      if (token.isEmpty) throw 'Ingresa el token del entrenador';

      final tokenDoc = await FirebaseFirestore.instance
          .collection('tokens')
          .doc(token)
          .get();

      if (!tokenDoc.exists) {
        throw 'El token no es válido o ya fue usado';
      }

      final data = tokenDoc.data()!;
      final trainerId = data['trainerId'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        throw 'El token ha expirado';
      }

      await FirebaseFirestore.instance
          .collection('clientes')
          .doc(user.uid)
          .update({
        'entrenador_ID': trainerId,
        'fechaAsociacion': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('tokens')
          .doc(token)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asociación exitosa')),
      );
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asociar con Entrenador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ingresa el token del entrenador:'),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Token',
              hintText: 'Ej: 7gk3m2a9',
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _asociarEntrenadorConToken,
          child: const Text('Asociar'),
        ),
      ],
    );
  }
}
