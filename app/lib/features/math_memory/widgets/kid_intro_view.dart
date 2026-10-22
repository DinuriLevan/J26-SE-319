import 'package:flutter/material.dart';

import 'math_illustrations.dart';
import 'math_palette.dart';

/// One picture step on the child-mode intro. [label] is never shown, but
/// screen readers read it aloud.
class KidStep {
  const KidStep({required this.label, required this.visual});

  final String label;
  final Widget visual;
}

/// Picture-first intro for children: a big illustration, three numbered
/// picture steps that bounce when tapped, a big Play button and a "?" for
/// the tutorial. Almost no words to read.
class KidIntroView extends StatelessWidget {
  const KidIntroView({
    super.key,
    required this.title,
    required this.description,
    required this.art,
    required this.colors,
    required this.steps,
    required this.onStart,
    required this.onHowToPlay,
    required this.startKey,
    required this.howToPlayKey,
  });

  final String title;

  /// Read aloud for the illustration.
  final String description;
  final MathArt art;
  final MathGameColors colors;
  final List<KidStep> steps;
  final VoidCallback onStart;
  final VoidCallback onHowToPlay;
  final Key startKey;
  final Key howToPlayKey;

  @override
  Widget build(BuildContext context) {
    // Grow the pictures on taller phones; small phones (640 dp) still fit
    // everything without scrolling.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.22).clamp(140.0, 220.0);
    final stepHeight = (screenHeight * 0.12).clamp(84.0, 112.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Semantics(
                label: description,
                image: true,
                child: BounceOnTap(
                  child: Container(
                    height: heroHeight,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.light, colors.mid],
                      ),
                    ),
                    child: MathIllustration(art),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final (i, step) in steps.indexed) ...[
                if (i > 0) _NextStepArrow(color: colors.accent),
                _KidStepTile(number: i + 1, step: step, colors: colors, height: stepHeight),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Start Game',
                      excludeSemantics: true,
                      child: FilledButton.icon(
                        key: startKey,
                        onPressed: onStart,
                        icon: const Icon(Icons.play_arrow_rounded, size: 44),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(76),
                          shape: const StadiumBorder(),
                          elevation: 3,
                          textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 76,
                    child: IconButton.outlined(
                      key: howToPlayKey,
                      onPressed: onHowToPlay,
                      tooltip: 'How to play',
                      icon: Icon(Icons.question_mark_rounded, size: 38, color: colors.accent),
                      style: IconButton.styleFrom(
                        side: BorderSide(color: colors.accent, width: 3),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KidStepTile extends StatelessWidget {
  const _KidStepTile({
    required this.number,
    required this.step,
    required this.colors,
    required this.height,
  });

  final int number;
  final KidStep step;
  final MathGameColors colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $number: ${step.label}',
      excludeSemantics: true,
      child: BounceOnTap(
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.light,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.accent.withValues(alpha: 0.25), width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.accent,
                child: Text(
                  '$number',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              // Shrinks the picture on narrow phones instead of overflowing.
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: step.visual)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Down arrow between steps, so the order reads without words.
class _NextStepArrow extends StatelessWidget {
  const _NextStepArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 26,
        child: Center(child: Icon(Icons.arrow_downward_rounded, size: 26, color: color)),
      ),
    );
  }
}

/// A maths sign (+ − × ÷) in a small coloured circle.
class MathSignBadge extends StatelessWidget {
  const MathSignBadge(this.sign, {super.key, required this.color, this.size = 26});

  final String sign;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        sign,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.62,
          height: 1,
        ),
      ),
    );
  }
}

/// Gives a quick, gentle "boing" when tapped — playful feedback without
/// flashing. Skipped when the device asks for reduced motion.
class BounceOnTap extends StatefulWidget {
  const BounceOnTap({super.key, required this.child});

  final Widget child;

  @override
  State<BounceOnTap> createState() => _BounceOnTapState();
}

class _BounceOnTapState extends State<BounceOnTap> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 0.97), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
        _controller.forward(from: 0);
      },
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// A small rounded card for step pictures.
class MiniCard extends StatelessWidget {
  const MiniCard({super.key, required this.child, this.color = Colors.white, this.border});

  final Widget child;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 56,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? MathPalette.grape.withValues(alpha: 0.3), width: 2),
      ),
      child: child,
    );
  }
}
