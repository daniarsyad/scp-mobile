import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _loadingController;
  late final Animation<double> _loadingFade;
  late final Animation<Offset> _loadingSlide;
  late final AnimationController _loadingRotationController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
    final loadingCurve = CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    );
    _loadingFade = Tween<double>(begin: 0.55, end: 1).animate(loadingCurve);
    _loadingSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.035, 0),
    ).animate(loadingCurve);
    _loadingRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _navigationTimer = Timer(const Duration(milliseconds: 1200), _openLogin);
  }

  Future<void> _openLogin() async {
    if (!mounted) return;

    Widget destination = const LoginScreen();
    try {
      final auth = AuthService();
      final token = await auth.getToken().timeout(
        const Duration(milliseconds: 250),
      );
      if (token != null && token.isNotEmpty) {
        final savedUser = await auth.getSavedUser().timeout(
          const Duration(milliseconds: 250),
        );
        if (savedUser != null && !savedUser.isWaka) {
          destination = HomeScreen(user: savedUser);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _loadingRotationController.dispose();
    _loadingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF102A43);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF102A43), Color(0xFF123C62), Color(0xFF1D4ED8)],
              stops: [0, 0.56, 1],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned(
                top: -105,
                right: -85,
                child: _GlowCircle(size: 270),
              ),
              const Positioned(
                bottom: -135,
                left: -100,
                child: _GlowCircle(size: 300),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final compact = constraints.maxHeight < 580;
                    final horizontalPadding = width < 360 ? 20.0 : 28.0;
                    final logoSize = math.min(
                      width * 0.36,
                      compact ? 106.0 : 132.0,
                    );

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: compact ? 16 : 24,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: FadeTransition(
                                opacity: _fade,
                                child: SlideTransition(
                                  position: _slide,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(height: compact ? 8 : 16),
                                      _SplashEmblem(size: logoSize),
                                      SizedBox(height: compact ? 22 : 30),
                                      Text(
                                        'SCP School',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: width < 360 ? 28 : 32,
                                          height: 1.15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Sistem Informasi & Presensi Digital',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                          fontSize: width < 360 ? 13 : 14,
                                          height: 1.45,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: compact ? 18 : 24),
                                      const _SchoolBadge(),
                                      SizedBox(height: compact ? 24 : 34),
                                      _LoadingIndicator(
                                        fade: _loadingFade,
                                        slide: _loadingSlide,
                                        rotation: _loadingRotationController,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashEmblem extends StatelessWidget {
  final double size;

  const _SplashEmblem({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.17),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo-smkn1.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/Logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SchoolBadge extends StatelessWidget {
  const _SchoolBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, size: 16, color: Color(0xFFFBBF24)),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'SMK NEGERI 1 BANTUL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Animation<double> rotation;

  const _LoadingIndicator({
    required this.fade,
    required this.slide,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: rotation,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF5EEAD4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FadeTransition(
          key: const ValueKey('loading-text-pulse'),
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: Text(
              'Memuat aplikasi...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;

  const _GlowCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.055),
      ),
    );
  }
}
