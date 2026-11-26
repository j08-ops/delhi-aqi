import 'package:flutter/material.dart';

const List<String> userProfiles = [
  'General adult',
  'Asthmatic',
  'Child',
  'Elderly',
  'Outdoor runner',
];

class ProfileSelector extends StatelessWidget {
  final String selectedProfile;
  final ValueChanged<String> onSelected;

  const ProfileSelector({
    super.key,
    required this.selectedProfile,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Your profile', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: userProfiles.map((profile) {
                return ChoiceChip(
                  label: Text(profile),
                  selected: profile == selectedProfile,
                  onSelected: (val) {
                    if (val) onSelected(profile);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
