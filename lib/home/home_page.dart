import 'package:flutter/material.dart';
import 'profile_page.dart'; 
import '../rutinas/rutinas_page.dart';
import '../dietas/dieta_page.dart';
import '../notas/notes_page.dart';
import '../gemini/chat_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Paleta de colores
  final Map<String, Color> colors = {
    'primaryDark': const Color(0xFF344E41),
    'primaryMedium': const Color(0xFF3A5A40),
    'primaryLight': const Color(0xFF588157),
    'accent1': const Color(0xFFD65A31),
    'accent2': const Color(0xFFD9A600),
    'background': const Color(0xFF1A1A1A),
    'text': const Color(0xFFECECEC),
  };

  final List<Widget> _pages = const [
    DietasPage(),
    NotesPage(),
    RutinasPage(),
    ChatScreen(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors['background'],
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: colors['primaryDark'],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: colors['primaryDark'],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors['accent1'],
        unselectedItemColor: colors['primaryLight'],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu, size: 26),
            label: 'Dietas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notes_outlined, size: 26),
            label: 'Notas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center, size: 26),
            label: 'Rutinas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline, size: 26),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 26),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
