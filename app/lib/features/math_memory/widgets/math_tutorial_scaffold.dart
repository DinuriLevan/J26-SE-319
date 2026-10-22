import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feedback_panel.dart';
import 'math_palette.dart';
import 'parent_support.dart';

/// One tutorial page: a big visual, plus one short instruction. Children see
/// [icon] in place of the words (screen readers still read [instruction]);
/// with Parent support on, the words are shown.
class TutorialStep {
  const TutorialStep({required this.instruction, required this.icon, required this.visual});

  final String instruction;
  final IconData icon;
  final Widget visual;
}

/// Step-by-step "how to play" with Back / Next / Let's Play! and an
/// "x of y" indicator. Practice inside it never counts as a real attempt.
class MathTutorialScaffold extends ConsumerStatefulWidget {
  const MathTutorialScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.steps,
    required this.onFinish,
  });

  /// Width the step visuals are laid out at; they're then scaled to fill
  /// the free space, so pictures are big on large phones and still fit small
  /// ones.
  static const visualDesignWidth = 280.0;

  final String title;
  final MathGameColors colors;
  final List<TutorialStep> steps;

  /// Called by Let's Play! on the last step.
  final VoidCallback onFinish;

  @override
  ConsumerState<MathTutorialScaffold> createState() => _MathTutorialScaffoldState();
}

class _MathTutorialScaffoldState extends ConsumerState<MathTutorialScaffold> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = widget.colors;
    final step = widget.steps[_step];
    final isLast = _step == widget.steps.length - 1;
    final parentSupport = ref.watch(parentSupportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'How to play ${widget.title}',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_rounded, color: colors.accent),
              const SizedBox(width: 8),
              Flexible(child: Text(widget.title, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        actions: [ParentSupportToggle(colors: colors)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _StepDots(count: widget.steps.length, current: _step, colors: colors),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    // Fill the free space so FittedBox scales the visual up (and
                    // down on small phones), keeping it centred.
                    child: SizedBox.expand(
                      child: FittedBox(
                        child: SizedBox(
                          width: MathTutorialScaffold.visualDesignWidth,
                          // Picture and instruction scale together as one
                          // centred group.
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [colors.light, colors.mid],
                                  ),
                                ),
                                // Keyed so each step's practice starts fresh.
                                child: KeyedSubtree(key: ValueKey(_step), child: step.visual),
                              ),
                              const SizedBox(height: 14),
                              Semantics(
                                label: step.instruction,
                                excludeSemantics: true,
                                child: parentSupport
                                    ? Text(
                                        step.instruction,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: MathPalette.ink,
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 28,
                                        backgroundColor: colors.light,
                                        child: Icon(step.icon, size: 34, color: colors.accent),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 60,
                        child: IconButton.outlined(
                          onPressed: _step == 0 ? null : () => setState(() => _step--),
                          tooltip: 'Previous',
                          icon: const Icon(Icons.arrow_back_rounded, size: 30),
                          style: IconButton.styleFrom(
                            foregroundColor: colors.accent,
                            side: BorderSide(
                              color: _step == 0 ? colors.mid : colors.accent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isLast ? widget.onFinish : () => setState(() => _step++),
                          icon: Icon(
                            isLast ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                            size: 30,
                          ),
                          label: Text(isLast ? "Let's Play!" : 'Next'),
                          style: mathPrimaryButtonStyle(context, colors, height: 60),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.current, required this.colors});

  final int count;
  final int current;
  final MathGameColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 28 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: i <= current ? colors.accent : colors.mid,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        const SizedBox(width: 10),
        Text(
          '${current + 1} of $count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: MathPalette.ink,
              ),
        ),
      ],
    );
  }
}
