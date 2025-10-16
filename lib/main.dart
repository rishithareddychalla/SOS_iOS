import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contacts_screen.dart';
import 'sos_in_progress_screen.dart';

// --- State Management ---

final contactsProvider =
    StateNotifierProvider<
      ContactsNotifier,
      AsyncValue<List<Map<String, String>>>
    >((ref) {
      final notifier = ContactsNotifier();
      notifier._initialize();
      return notifier;
    });

class ContactsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, String>>>> {
  ContactsNotifier() : super(const AsyncValue.loading());
  Future<void> _initialize() async => await _loadContacts();

  Future<void> _loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('contacts');
      if (contactsJson != null) {
        final decoded = json.decode(contactsJson) as List;
        state = AsyncValue.data(
          decoded.map((item) => Map<String, String>.from(item)).toList(),
        );
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addContact(String name, String phone) async {
    final currentContacts = state.value ?? [];
    state = AsyncValue.data([
      ...currentContacts,
      {'name': name, 'phone': phone},
    ]);
    await _saveContacts();
  }

  Future<void> deleteContact(int index) async {
    final currentContacts = state.value ?? [];
    if (index >= 0 && index < currentContacts.length) {
      final newContacts = List.from(currentContacts)..removeAt(index);
      state = AsyncValue.data(newContacts.cast<Map<String, String>>());
      await _saveContacts();
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contacts', json.encode(state.value ?? []));
  }
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsScreen(),
    ),
    GoRoute(
      path: '/sos_in_progress',
      builder: (context, state) => const SosInProgressScreen(),
    ),
  ],
);

final sosInProgressProvider = StateProvider<bool>((ref) => false);
final sosNotifiedProvider = StateProvider<List<bool>>((ref) => []);

// --- UI and App Setup ---

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SOS',
      theme: const CupertinoThemeData(
        primaryColor: Color(0xFFB51963),
        scaffoldBackgroundColor: Colors.white,
        textTheme: CupertinoTextThemeData(
          navLargeTitleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: CupertinoColors.white,
            fontSize: 34,
          ),
          navTitleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: CupertinoColors.white,
            fontSize: 17,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  Future<bool> _requestPermissions(BuildContext context) async {
    final permissions = [
      Permission.sms,
      Permission.location,
      Permission.phone,
      Permission.contacts,
    ];
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    bool allGranted = true;
    statuses.forEach((permission, status) {
      debugPrint(
        'Permission: ${permission.toString()}, Status: ${status.toString()}',
      );
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    if (!allGranted && context.mounted) {
      _showCupertinoError(context, 'All permissions are required. Please check app settings.');
      await openAppSettings();
    }
    return allGranted;
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever)
      return Future.error('Location permissions are permanently denied.');
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _handleSOS(BuildContext context, WidgetRef ref) async {
    final contactList = ref.read(contactsProvider).value ?? [];
    if (contactList.isEmpty) {
      _showCupertinoError(context, 'No emergency contacts have been added.');
      return;
    }

    final hasPermissions = await _requestPermissions(context);
    if (!hasPermissions) {
      _showCupertinoError(
        context,
        'Location and Contacts permissions are required to use the SOS feature.',
      );
      return;
    }

    ref.read(sosInProgressProvider.notifier).state = true;
    ref.read(sosNotifiedProvider.notifier).state = List<bool>.filled(contactList.length, false);
    context.go('/sos_in_progress');
  }

  void _showCupertinoError(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Image.asset(
          'assets/images/logo_white.png',
          height: 30,
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.person_2_fill, color: CupertinoColors.white),
          onPressed: () => context.go('/contacts'),
        ),
        backgroundColor: const Color(0xFFB51963),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton(
                      onPressed: () => _handleSOS(context, ref),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [
                              Color(0xFFFD92981), // lighter / inner
                              Color(0xFFF9B1955), // darker / outer
                            ],
                            stops: [0.3, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x40FD92981),
                              blurRadius: 10.0,
                              spreadRadius: 5.0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'Tapping SOS will show your emergency contacts to call or message.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Image.asset(
                'assets/images/logo_pink.png',
                height: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}