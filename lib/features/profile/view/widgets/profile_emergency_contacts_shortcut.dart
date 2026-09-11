import 'package:flutter/material.dart';

class ProfileEmergencyContactsShortcut extends StatelessWidget {
  const ProfileEmergencyContactsShortcut({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.contact_emergency_outlined,
          color: colors.onErrorContainer,
        ),
        title: Text(
          'Emergency Contacts',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.onErrorContainer,
          ),
        ),
        subtitle: Text(
          'Call approved contacts without a PIN',
          style: TextStyle(color: colors.onErrorContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: colors.onErrorContainer),
        onTap: onTap,
      ),
    );
  }
}
