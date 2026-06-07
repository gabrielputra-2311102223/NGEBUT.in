import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/motor_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/owner/owner_home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MotorProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
      title: 'Ngebut.in',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFCC0000),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCC0000),
          primary: const Color(0xFFCC0000),
          secondary: const Color(0xFF1A1A1A),
          background: const Color(0xFFF9FAFB),
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 1,
          shadowColor: Colors.black12,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFFCC0000))),
            );
          }
          if (auth.isAuthenticated) {
            final role = auth.user?['role'] ?? 'user';
            if (role == 'admin') return const AdminHomeScreen();
            if (role == 'owner') return const OwnerHomeScreen();
            return const HomeScreen();
          }
          return const LandingScreen();
        },
      ),
    );
  }
}
