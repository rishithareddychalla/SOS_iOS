import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart'; // Import for contactsProvider

// State provider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return contacts.when(
      data: (contactList) {
        final filteredContacts = contactList.where((contact) {
          final name = contact['name']!.toLowerCase();
          final query = searchQuery.toLowerCase();
          return name.contains(query);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/'),
            ),
            title: const Text(
              'Manage Emergency Contacts',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFB51963),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        filteredContacts[index]['name']!,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        filteredContacts[index]['phone']!,
                        style: TextStyle(color: Colors.grey[900]),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.grey[800]),
                        onPressed: () {
                          // Find the original index to delete
                          final originalIndex = contactList.indexOf(filteredContacts[index]);
                          ref
                              .read(contactsProvider.notifier)
                              .deleteContact(originalIndex);
                        }
                      ),
                    );
                  },
                ),
              ),
              const Spacer(), // <-- pushes logo to bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  'assets/images/logo_pink.png', // place your logo file here
                  height: 60, // adjust size
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFFFB51963),
            onPressed: () => _pickContact(context, ref),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _pickContact(BuildContext context, WidgetRef ref) async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contact permission is required to select contacts.',
              ),
            ),
          );
          await openAppSettings();
        }
        return;
      }
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        if (contact.phones.isNotEmpty) {
          final phone = contact.phones.first.number;
          ref
              .read(contactsProvider.notifier)
              .addContact(contact.displayName, phone);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Selected contact does not have a phone number.')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking contact: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick contact. Error: $e')),
        );
      }
    }
  }
}
