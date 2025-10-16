import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';

class SosInProgressScreen extends ConsumerWidget {
  const SosInProgressScreen({super.key});

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final locationMessage =
        "Emergency! I need help. My current location is: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{
        'body': locationMessage,
      },
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider).value ?? [];
    final notifiedState = ref.watch(sosNotifiedProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('SOS In Progress', style: TextStyle(color: CupertinoColors.white)),
        backgroundColor: const Color(0xFFB51963),
        automaticallyImplyLeading: false,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Contact your emergency contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return CupertinoListTile(
                    title: Text(contact['name']!),
                    subtitle: Text(contact['phone']!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          onPressed: () => _makeCall(contact['phone']!),
                          child: const Icon(CupertinoIcons.phone_fill),
                        ),
                        CupertinoButton(
                          onPressed: () => _sendSMS(contact['phone']!),
                          child: const Icon(CupertinoIcons.bubble_left_bubble_right_fill),
                        ),
                        CupertinoSwitch(
                          value: notifiedState[index],
                          onChanged: (value) {
                            final newNotifiedState = List<bool>.from(notifiedState);
                            newNotifiedState[index] = value;
                            ref.read(sosNotifiedProvider.notifier).state = newNotifiedState;
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoButton.filled(
                child: const Text('End SOS'),
                onPressed: () {
                  ref.read(sosInProgressProvider.notifier).state = false;
                  context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}