import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enforce mandatory portrait mode on application start
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: LANGamepadApp()));
}

class LANGamepadApp extends StatelessWidget {
  const LANGamepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAN Gamepad',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          onPrimary: Colors.black,
          surface: Color(0xFF131B2E),
          onSurface: Colors.white,
          secondary: Color(0xFF38BDF8),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
