import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

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

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: CupertinoNavigationBarBackButton(
              color: CupertinoColors.white,
              onPressed: () => context.go('/'),
            ),
            middle: const Text(
              'Emergency Contacts',
              style: TextStyle(color: CupertinoColors.white),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
              onPressed: () => _pickContact(context, ref),
            ),
            backgroundColor: const Color(0xFFB51963),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CupertinoSearchTextField(
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      return CupertinoListTile(
                        title: Text(filteredContacts[index]['name']!),
                        subtitle: Text(filteredContacts[index]['phone']!),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(CupertinoIcons.delete, color: CupertinoColors.systemRed),
                          onPressed: () {
                            final originalIndex = contactList.indexOf(filteredContacts[index]);
                            ref.read(contactsProvider.notifier).deleteContact(originalIndex);
                          },
                        ),
                      );
                    },
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
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
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

  Future<void> _pickContact(BuildContext context, WidgetRef ref) async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (context.mounted) {
          _showCupertinoError(context, 'Contact permission is required to select contacts.');
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
            _showCupertinoError(context, 'Selected contact does not have a phone number.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking contact: $e');
      if (context.mounted) {
        _showCupertinoError(context, 'Failed to pick contact. Error: $e');
      }
    }
  }
}
