import 'package:flutter/material.dart';

class LetterDemonstrationScreen extends StatefulWidget {
  const LetterDemonstrationScreen({
    super.key,
    required this.character,
    this.emoji,
    this.exampleWord,
  });

  final String character;
  final String? emoji;
  final String? exampleWord;

  @override
  State<LetterDemonstrationScreen> createState() =>
      _LetterDemonstrationScreenState();
}

class _LetterDemonstrationScreenState extends State<LetterDemonstrationScreen>
    with SingleTickerProviderStateMixin {
  static const _accentColor = Color(0xFFFF686B);

  late final AnimationController _controller;
  late final Animation<double> _formationProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _formationProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replay() {
    _controller
      ..reset()
      ..forward();
  }

  void _showPracticeComingNext() {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Handwriting practice will be added in the next step.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Letter Time!')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _LetterHeaderCard(
              character: widget.character,
              emoji: widget.emoji,
              exampleWord: widget.exampleWord,
            ),
            const SizedBox(height: 20),
            Text(
              'Watch how to write it',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 0.9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _formationProgress,
                  builder: (context, _) => _AnimatedLetterFormation(
                    character: widget.character,
                    progress: _formationProgress.value,
                    color: _accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _replay,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Replay'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _showPracticeComingNext,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('My Turn!'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterHeaderCard extends StatelessWidget {
  const _LetterHeaderCard({
    required this.character,
    this.emoji,
    this.exampleWord,
  });

  final String character;
  final String? emoji;
  final String? exampleWord;

  @override
  Widget build(BuildContext context) {
    final description = exampleWord == null
        ? 'Let’s write $character'
        : '${emoji ?? ''}  $exampleWord';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: _LetterDemonstrationScreenState._accentColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _LetterDemonstrationScreenState._accentColor.withValues(
              alpha: 0.25,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            character,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 88,
                  height: 1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnimatedLetterFormation extends StatelessWidget {
  const _AnimatedLetterFormation({
    required this.character,
    required this.progress,
    required this.color,
  });

  final String character;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = constraints.biggest.shortestSide * 0.65;
        final outlineStyle = TextStyle(
          fontFamily: Theme.of(context).textTheme.displayLarge?.fontFamily,
          fontFamilyFallback:
              Theme.of(context).textTheme.displayLarge?.fontFamilyFallback,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: 0.18),
        );
        final formationStyle = outlineStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 7
            ..color = color,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            Text(character, style: outlineStyle),
            ClipRect(
              clipper: _FormationClipper(progress),
              child: Text(character, style: formationStyle),
            ),
            Positioned(
              right: 16,
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FormationClipper extends CustomClipper<Rect> {
  const _FormationClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * progress);

  @override
  bool shouldReclip(_FormationClipper oldClipper) =>
      oldClipper.progress != progress;
}
