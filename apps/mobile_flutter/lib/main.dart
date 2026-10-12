import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'core/api.dart';
import 'design/theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Cap decoded image cache; uploaded pictures should not fill the process.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 32 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 80;
  configureSystemChrome();
  runApp(KakaApp(controller:AppController(KakaApi())..initialize()));
}

class KakaApp extends StatelessWidget {
  final AppController controller;
  const KakaApp({super.key,required this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'Kaka',
    debugShowCheckedModeBanner:false,
    theme:kakaTheme(),
    home:AnimatedBuilder(animation:controller,builder:(context,_) {
      switch(controller.state) {
        case StartupState.starting:
          return const Scaffold(body:Center(
            child:CircularProgressIndicator(color:KColors.ink)));
        case StartupState.server:
        case StartupState.login:
          return AuthScreen(app:controller);
        case StartupState.ready:
          return HomeScreen(app:controller);
      }
    }),
  );
}
