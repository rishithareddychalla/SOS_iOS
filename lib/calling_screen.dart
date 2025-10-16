import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'main.dart'; // To access the providers

class CallingScreen extends ConsumerWidget {
  const CallingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingNumbers = ref.watch(sequentialCallProvider);
    final allContacts = ref.watch(contactsProvider).value ?? [];

    String statusText;
    if (remainingNumbers.isNotEmpty) {
      final currentNumber = remainingNumbers.first;
      final contactName = allContacts.firstWhere(
        (c) => c['phone'] == currentNumber,
        orElse: () => {'name': 'Unknown'},
      )['name'];
      statusText = 'Calling $contactName'; //...\n($currentNumber)
    } else {
      statusText = 'Finished calling all emergency contacts.';
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFFB51963),
        ),
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFFFB51963)),
            child: Center(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer circle
                        Container(
                          width: 245,
                          height: 245,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFFF821949,
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
                              0xFFFE7E7E7,
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
                                Color(0xFFFFFFFFF), // lighter / inner
                                Color(0xFFFCCCBCB), // darker / outer
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
                                color: Color(0xFFFB51963),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    const SizedBox(height: 10),
                    (remainingNumbers.isNotEmpty)
                        ? Column(
                            children: const [
                              Text(
                                'SOS is active.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8), // spacing
                              Text(
                                'We are seeking help',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'All emergency contacts have been called.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(sequentialCallProvider.notifier).stopSOS();
                          context.go('/');
                        },
                        // ... (rest of button is the same)
                        child: Text(
                          remainingNumbers.isNotEmpty
                              ? 'Stop SOS'
                              : 'Return to Home',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFFFB51963),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50), // <-- pushes logo to bottom

                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Image.asset(
                        'assets/images/logo_white.png', // place your logo file here
                        height: 60, // adjust size
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
