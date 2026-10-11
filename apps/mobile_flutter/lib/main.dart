import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'core/api.dart';
import 'design/theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
