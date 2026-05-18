import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database.dart';
import 'home_screen.dart';
import 'services/sync_service.dart';
import 'services/weightage_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp();
      FlutterError.onError = (details) {
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } else {
          FlutterError.presentError(details);
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        return true;
      };
    } catch (e) {
      debugPrint("Firebase init failed: $e");
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Question X',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        primaryColor: const Color(0xFF38BDF8),
        cardColor: const Color(0xFF1E293B),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const PremiumSplashScreen(),
    );
  }
}

class PremiumSplashScreen extends ConsumerStatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  ConsumerState<PremiumSplashScreen> createState() =>
      _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends ConsumerState<PremiumSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  String _loadingText = "Initializing...";

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final db = ref.read(databaseProvider);
    final sync = SyncService(db);
    final startTime = DateTime.now();

    try {
      setState(() => _loadingText = "Syncing Question Bank...");
      await sync.initializeData();
      await WeightageService().ensureLoaded();
    } catch (e) {
      debugPrint("Sync Error (Offline Mode): $e");
    }

    final elapsedTime = DateTime.now().difference(startTime);
    final remainingTime = const Duration(milliseconds: 2500) - elapsedTime;

    if (remainingTime > Duration.zero) {
      await Future.delayed(remainingTime);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B1120)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _opacityAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.hub,
                      size: 80,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  children: [
                    Text(
                      "Question X",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Master Your Exam",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      color: Color(0xFF38BDF8),
                      minHeight: 2,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _loadingText,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
