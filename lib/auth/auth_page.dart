import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLoginForm = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  final Color primaryDark = const Color(0xFF344E41);
  final Color primaryMedium = const Color(0xFF3A5A40);
  final Color primaryLight = const Color(0xFF588157);
  final Color accent1 = const Color(0xFFD65A31);
  final Color accent2 = const Color(0xFFD9A600);
  final Color background = const Color(0xFF1A1A1A);
  final Color cardColor = const Color(0xFF2D2D2D);
  final Color textColor = const Color(0xFFDAD7CD);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [background, primaryDark],
            stops: const [0.3, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryDark.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent2, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/logo.png', width: 80),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _showLoginForm ? 'SIGN IN' : 'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: accent1,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Form(
                              key: _formKey,
                              child: _showLoginForm
                                  ? _buildLoginForm()
                                  : _buildRegisterForm(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryMedium,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _showLoginForm ? _signIn : _register,
                                child: Text(
                                  _showLoginForm ? 'LOG IN' : 'SIGN UP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showLoginForm = !_showLoginForm;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: textColor),
                          children: [
                            TextSpan(
                              text: _showLoginForm
                                  ? "Don't have an account? "
                                  : 'Already have an account? ',
                            ),
                            TextSpan(
                              text: _showLoginForm ? 'Sign up here' : 'Sign in here',
                              style: TextStyle(
                                color: accent1,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              Center(child: CircularProgressIndicator(color: accent1)),
        );

        final userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final userDoc = await FirebaseFirestore.instance
            .collection('clientes')
            .doc(userCredential.user?.uid)
            .get();

        if (!mounted) return;
        Navigator.of(context).pop();

        if (!userDoc.exists || userDoc['rol'] != 'cliente') {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Access denied', style: TextStyle(color: textColor)),
              content: Text(
                'You do not have permission to access as a client.',
                style: TextStyle(color: textColor),
              ),
              backgroundColor: cardColor,
            ),
          );
          return;
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();

        final String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email format.';
            break;
          default:
            errorMessage = 'Sign in error: ${e.message}';
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Error', style: TextStyle(color: textColor)),
            content: Text(errorMessage, style: TextStyle(color: textColor)),
            backgroundColor: cardColor,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Error', style: TextStyle(color: textColor)),
            content: Text(
              'An unexpected error occurred: $e',
              style: TextStyle(color: textColor),
            ),
            backgroundColor: cardColor,
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_passwordController.text != _confirmPasswordController.text) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Error', style: TextStyle(color: textColor)),
            content: Text(
              'Passwords do not match.',
              style: TextStyle(color: textColor),
            ),
            backgroundColor: cardColor,
          ),
        );
        return;
      }

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              Center(child: CircularProgressIndicator(color: accent1)),
        );

        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = userCredential.user!.uid;

        await FirebaseFirestore.instance.collection('clientes').doc(uid).set({
          'activo': true,
          'nombre': _nameController.text.trim(),
          'apellido': '',
          'apellido2': '',
          'email': email,
          'entrenador_ID': '',
          'fecha_nacimiento': null,
          'fecha_registro': FieldValue.serverTimestamp(),
          'hasCompletedOnboarding': false,
          'foto_perfil': '',
          'objetivo': 0,
          'rol': 'cliente',
          'peso': 0,
          'altura': 0,
          'telefono': _phoneController.text.trim(),
          'ultimo_accesso': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.of(context).pop();
        Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();

        final String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email is already in use.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address.';
            break;
          case 'weak-password':
            errorMessage = 'Password is too weak.';
            break;
          default:
            errorMessage = 'Account creation error: ${e.message}';
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Registration error', style: TextStyle(color: textColor)),
            content: Text(errorMessage, style: TextStyle(color: textColor)),
            backgroundColor: cardColor,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Error', style: TextStyle(color: textColor)),
            content: Text(
              'An unexpected error occurred: $e',
              style: TextStyle(color: textColor),
            ),
            backgroundColor: cardColor,
          ),
        );
      }
    }
  }

  Widget _buildLoginForm() => Column(
        children: [
          _buildTextField(
              _emailController, 'Email', Icons.email, TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(
              _passwordController, 'Password', Icons.lock, TextInputType.text,
              obscure: true),
        ],
      );

  Widget _buildRegisterForm() => Column(
        children: [
          _buildTextField(
              _nameController, 'Name', Icons.person, TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField(
              _phoneController, 'Phone', Icons.phone, TextInputType.phone),
          const SizedBox(height: 16),
          _buildTextField(
              _emailController, 'Email', Icons.email, TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(
              _passwordController, 'Password', Icons.lock, TextInputType.text,
              obscure: true),
          const SizedBox(height: 16),
          _buildTextField(
              _confirmPasswordController,
              'Confirm password',
              Icons.lock_outline,
              TextInputType.text,
              obscure: true),
        ],
      );

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    TextInputType type, {
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: primaryLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryLight),
        ),
        filled: true,
        fillColor: background.withOpacity(0.8),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        if (label == 'Email' &&
            !RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
                .hasMatch(value)) {
          return 'Enter a valid email';
        }
        if (label == 'Password' && value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
    );
  }
}
