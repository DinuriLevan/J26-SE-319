import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/avatar_picker.dart';
import 'providers/profile_providers.dart';

const _languages = [('si', 'සිංහල'), ('en', 'English')];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _avatarId;
  String? _language;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null || _avatarId == null || _language == null) return;

    setState(() => _isSaving = true);
    await ref.read(profileControllerProvider).updateProfile(
          id: profile.id,
          name: _nameController.text.trim().isEmpty ? profile.name : _nameController.text.trim(),
          avatarId: _avatarId!,
          preferredLanguage: _language!,
          grade: profile.grade,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    // Seed local editing state from the loaded profile the first time it
    // becomes available.
    if (profile != null && _avatarId == null) {
      _nameController.text = profile.name;
      _avatarId = profile.avatarId;
      _language = profile.preferredLanguage;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                AvatarPicker(
                  selectedAvatarId: _avatarId!,
                  onSelected: (id) => setState(() => _avatarId = id),
                ),
                const SizedBox(height: 28),
                Text('Language', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    for (final (code, label) in _languages)
                      ButtonSegment(value: code, label: Text(label)),
                  ],
                  selected: {_language!},
                  onSelectionChanged: (selection) => setState(() => _language = selection.first),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
    );
  }
}
