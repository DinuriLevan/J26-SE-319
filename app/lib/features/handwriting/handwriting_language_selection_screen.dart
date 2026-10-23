import 'package:flutter/material.dart';

import '../../shared/widgets/app_drawer.dart';
import 'english_handwriting_screen.dart';
import 'sinhala_handwriting_screen.dart';

/// Entry screen for the handwriting learning flow.
class HandwritingLanguageSelectionScreen extends StatelessWidget {
  const HandwritingLanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Handwriting'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 72,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose a Language',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Which language would you like to practice?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildLanguageCards(context, color: colors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCards(
    BuildContext context, {
    required Color color,
  }) {
    final englishCard = _LanguageCard(
      label: 'English',
      symbol: Icon(Icons.abc_rounded, size: 64, color: color),
      color: color,
      onTap: () => _open(context, const EnglishHandwritingScreen()),
    );
    final sinhalaCard = _LanguageCard(
      label: 'සිංහල',
      symbol: Text(
        "'අ'",
        style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
      color: color,
      onTap: () => _open(context, const SinhalaHandwritingScreen()),
    );

    return Column(
      children: [
        englishCard,
        const SizedBox(height: 20),
        sinhalaCard,
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.symbol,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Widget symbol;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$label handwriting',
      child: Card(
        color: color.withValues(alpha: 0.12),
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 168),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 64, child: Center(child: symbol)),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
