import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home/landing_page.dart';
import 'auth/auth_page.dart';
import 'home/home_page.dart';
import 'rutinas/rutinas_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database/firebase_options.dart';
import 'dietas/dieta_page.dart';
import 'notas/notes_page.dart';
import 'gemini/chat_screen.dart';
import 'home/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitnessApp',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/auth': (context) => const AuthPage(),
        '/profile': (context) => const ProfilePage(),
        '/home': (context) => const HomePage(),
        '/workouts': (context) => const RutinasPage(),
        '/diet': (context) => const DietasPage(),
        '/notes': (context) => const NotesPage(),
        '/chat': (context) => const ChatScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const Scaffold(
          body: Center(child: Text('Page not found')),
        ),
      ),
    );
  }
}
