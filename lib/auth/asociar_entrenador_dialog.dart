import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkTrainerDialog extends StatefulWidget {
  const LinkTrainerDialog({super.key});

  @override
  State<LinkTrainerDialog> createState() => _LinkTrainerDialogState();
}

class _LinkTrainerDialogState extends State<LinkTrainerDialog> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;

  Future<void> _linkTrainerWithToken() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'You must be logged in first';

      final token = _tokenController.text.trim();
      if (token.isEmpty) throw 'Enter the trainer token';

      final tokenDoc = await FirebaseFirestore.instance
          .collection('tokens')
          .doc(token)
          .get();

      if (!tokenDoc.exists) {
        throw 'Token is invalid or has already been used';
      }

      final data = tokenDoc.data()!;
      final trainerId = data['trainerId'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        throw 'Token has expired';
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
        const SnackBar(content: Text('Trainer linked successfully')),
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
      title: const Text('Link with Trainer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter the trainer token:'),
          const SizedBox(height: 16),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Token',
              hintText: 'e.g. 7gk3m2a9',
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _linkTrainerWithToken,
          child: const Text('Link'),
        ),
      ],
    );
  }
}
