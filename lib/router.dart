import 'package:go_router/go_router.dart';



import 'package:sos_ios/main.dart';

import 'contacts_screen.dart';
import 'calling_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    // GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/', builder: (context, state) => MainScreen()),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: '/calling',
      builder: (context, state) => const CallingScreen(),
    ),
  ],
);
