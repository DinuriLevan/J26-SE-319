import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import 'ui/spelling_style.dart';
import 'ui/widgets/big_icon_button.dart';
import 'ui/widgets/mascot.dart';

/// Placeholder for the Sinhala spelling game. The language picker
/// (spelling_stub_screen.dart) already opens this screen, so the Sinhala
/// game only needs to replace this widget.
class SinhalaSpellingScreen extends StatelessWidget {
  const SinhalaSpellingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpellingColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Mascot(size: 120),
                  const SizedBox(height: 28),
                  const Text(
                    'සිංහල',
                    style: TextStyle(
                      fontFamily: AppFonts.sinhala,
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      color: SpellingColors.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.hourglass_top_rounded, size: 72, color: SpellingColors.play),
                  const SizedBox(height: 12),
                  Text('Coming soon', style: letterStyle(26).copyWith(letterSpacing: 1)),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: BigIconButton(
                icon: Icons.arrow_back_rounded,
                color: SpellingColors.neutralButton,
                size: 52,
                semanticLabel: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
                onExplain: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
