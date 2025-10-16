import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:phone_state/phone_state.dart';

import 'contacts_screen.dart';
import 'calling_screen.dart';

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

final sequentialCallProvider =
    StateNotifierProvider<SequentialCallNotifier, List<String>>((ref) {
      return SequentialCallNotifier();
    });

class SequentialCallNotifier extends StateNotifier<List<String>> {
  StreamSubscription<PhoneState>? _callStateSubscription;
  int _currentIndex = 0;
  bool _isCalling = false;
  bool _wasInCall = false;
  Timer? _nextCallTimer; // <-- add this

  SequentialCallNotifier() : super([]);

  void startSOS(List<String> numbers) {
    if (numbers.isEmpty) return;
    state = List.from(numbers);
    _currentIndex = 0;
    _listenToCallStates();
    _callCurrentNumber();
  }

  void _callCurrentNumber() async {
    if (_currentIndex >= state.length) {
      stopSOS();
      return;
    }

    final numberToCall = state[_currentIndex];
    debugPrint('📞 Attempting to call number: $numberToCall');
    try {
      _isCalling = true;
      _wasInCall = false;
      await FlutterPhoneDirectCaller.callNumber(numberToCall);
    } catch (e) {
      debugPrint('❌ Error calling $numberToCall: $e');
      _advanceToNext();
    }
  }

  void _advanceToNext() {
    debugPrint('✅ Call finished with ${state[_currentIndex]}');
    _isCalling = false;
    _currentIndex++;

    if (_currentIndex < state.length) {
      debugPrint('➡️ Moving to next number in 2 seconds...');
      _nextCallTimer = Timer(const Duration(seconds: 2), _callCurrentNumber);
    } else {
      debugPrint('🏁 Finished all calls.');
      stopSOS();
    }
  }

  void _listenToCallStates() {
    _callStateSubscription?.cancel();
    _callStateSubscription = PhoneState.stream.listen((phoneState) {
      debugPrint('📲 Received call state: ${phoneState.status}');

      if (!_isCalling) return;

      if (phoneState.status == PhoneStateStatus.CALL_STARTED) {
        _wasInCall = true;
      }

      if (phoneState.status == PhoneStateStatus.CALL_ENDED && _wasInCall) {
        _wasInCall = false;
        _advanceToNext();
      }
    });
  }

  void stopSOS() {
    debugPrint('🛑 Stopping SOS, cancelling call listener.');
    _callStateSubscription?.cancel();
    _nextCallTimer?.cancel(); // <-- cancel future scheduled calls
    state = [];
    _currentIndex = 0;
    _isCalling = false;
    _wasInCall = false;
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _nextCallTimer?.cancel();
    super.dispose();
  }
}

// --- UI and App Setup ---

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SOS',
      theme: ThemeData(
        
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All permissions are required. Please check app settings.',
          ),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contacts added!')),
      );
      return;
    }

    final hasPermissions = await _requestPermissions(context);
    if (!hasPermissions) return;

    try {
      final position = await _determinePosition();
      final locationMessage =
          "Emergency! I need help. My current location is: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      final phoneNumbers = contactList.map((c) => c['phone']!).toList();

      final telephony = Telephony.instance;
      for (var number in phoneNumbers) {
        await telephony.sendSms(to: number, message: locationMessage);
      }

      // Start the sequential caller
      ref.read(sequentialCallProvider.notifier).startSOS(phoneNumbers);

      // NOW that all the work has started, navigate to the calling screen.
      if (context.mounted) {
        context.go('/calling');
      }
    } catch (e) {
      debugPrint('An error occurred during SOS setup: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo_white.png', // your logo path
          height: 30, // adjust as needed
        ),
        backgroundColor: const Color(0xFFFB51963),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts, color: Colors.white),
            onPressed: () => context.go('/contacts'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _handleSOS(context, ref),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle
                  Container(
                    width: 245,
                    height: 245,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFF8A9D9,
                      ).withOpacity(0.3), // faint background
                    ),
                  ),

                  // Middle circle
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFD92981,
                      ).withOpacity(0.6), // darker ring
                    ),
                  ),

                  // Inner circle with gradient
                  Container(
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
                ],
              ),
            ),

            const SizedBox(height: 50),
            const Text(
              'Tapping SOS will call all emergency contacts and send them your location.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 50), // <-- pushes logo to bottom

            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Image.asset(
                'assets/images/logo_pink.png', // place your logo file here
                height: 60, // adjust size
              ),
            ),
          ],
        ),
      ),
    );
  }
}
