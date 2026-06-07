import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const NgebutinApp(),
    ),
  );
}

class NgebutinApp extends StatelessWidget {
  const NgebutinApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ngebut.in Mobile',
      theme: ThemeData(
        primaryColor: const Color(0xFFCC0000),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCC0000)),
        fontFamily: 'Inter', // Custom font usage if added later
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))),
            );
          }
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
