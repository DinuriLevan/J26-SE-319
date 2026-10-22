import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/spelling_game_controller.dart';
import 'spelling_style.dart';
import 'widgets/big_icon_button.dart';
import 'widgets/effects.dart';
import 'widgets/letter_tile.dart';
import 'widgets/mascot.dart';
import 'widgets/progress_stars.dart';

typedef ActionHandler = void Function(SpellingAction type, [Map<String, Object?> data]);

/// One word of the game: picture + replay, the answer line, letter tray
/// and ✓. The layout is identical for every word so the line is always in
/// one place.
class GameView extends StatelessWidget {
  const GameView({super.key, required this.state, required this.act});

  final SpellingGameState state;
  final ActionHandler act;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight * 1.15;
        final layout = _layout(box, landscape);
        final tile = layout.tile;

        final topBar = _TopBar(state: state, act: act);
        final stage = _Stage(state: state, act: act, tile: tile);
        final answer = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wobble(
              signal: state.wobbleSignal,
              child: AnswerLine(state: state, act: act, tile: layout.slot, maxWidth: layout.lineWidth),
            ),
            SizedBox(height: tile * 0.45),
            _tray(tile, layout.perRow),
            SizedBox(height: tile * 0.4),
            _checkButton(tile),
          ],
        );

        return Column(
          children: [
            topBar,
            Expanded(
              child: landscape
                  ? Row(
                      children: [
                        Expanded(flex: 4, child: Center(child: stage)),
                        Expanded(flex: 6, child: Center(child: answer)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [stage, answer],
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Picks the biggest tile size (104 down to 52) at which the picture,
  /// answer line, tray and ✓ all fit. The tray wraps into balanced rows.
  /// [slot] is the largest tile size the answer line may use; the line
  /// shrinks its tiles further when the child adds many letters.
  ({double tile, double slot, int perRow, double lineWidth}) _layout(BoxConstraints box, bool landscape) {
    final count = math.max(1, state.tiles.length);
    // Room for the word plus one extra letter without shrinking.
    final letters = math.max(state.word.letters.length, state.line.length) + 1;
    final width = (landscape ? box.maxWidth * 0.55 : box.maxWidth) - 32;
    final height = box.maxHeight - 72; // top bar

    ({double tile, double slot, int perRow, double lineWidth}) fit(double tile) {
      final maxPerRow = math.max(1, (width / (tile + _gap)).floor());
      final rows = (count / math.min(count, maxPerRow)).ceil();
      final perRow = (count / rows).ceil();
      final slot = math.min(tile, width / letters - _gap).clamp(34.0, 104.0);
      return (tile: tile, slot: slot, perRow: perRow, lineWidth: width);
    }

    double needed(({double tile, double slot, int perRow, double lineWidth}) l) {
      final rows = (count / l.perRow).ceil();
      final answer = (l.slot + 8) + l.tile * 0.45 + rows * (l.tile + _gap) + 2 * _gap + l.tile * 0.4 +
          math.max(80, l.tile * 1.1);
      final stage = l.tile * 1.5 + l.tile * 0.85;
      return landscape ? math.max(answer, stage) : answer + stage + 24;
    }

    for (var tile = 104.0; tile > 52; tile -= 4) {
      final l = fit(tile);
      if (needed(l) <= height) return l;
    }
    return fit(52);
  }

  Widget _tray(double tile, int perRow) {
    final rows = <List<LetterTile>>[];
    for (var i = 0; i < state.tiles.length; i += perRow) {
      rows.add(state.tiles.sublist(i, math.min(i + perRow, state.tiles.length)));
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => !state.inputLocked && state.lineIndexOf(d.data) != null,
      onAcceptWithDetails: (d) => act(SpellingAction.dropOnTray, {'tileId': d.data}),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(_gap),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? const Color(0xFFFFEBC8) : const Color(0xFFFFF0D6),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: _gap / 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in row)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                        child: _bounceSwitcher(
                          state.lineIndexOf(t.id) == null
                              ? DraggableTile(
                                  key: ValueKey('tray-${t.id}'),
                                  tile: t,
                                  size: tile,
                                  state: state,
                                  act: act,
                                )
                              : EmptySpot(
                                  key: ValueKey('tray-empty-${t.id}'),
                                  size: tile,
                                  color: const Color(0x0F2F3A56),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _checkButton(double tile) {
    final ready = state.canCheck && !state.inputLocked;
    return Pulse(
      active: ready,
      child: BigIconButton(
        icon: Icons.check_rounded,
        color: SpellingColors.correct,
        size: math.max(80, tile * 1.1),
        enabled: ready,
        semanticLabel: 'Check',
        onTap: () => act(SpellingAction.checkPressed),
        onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.check}),
      ),
    );
  }
}

/// Tiles pop back in with a soft bounce when they return to the tray/slot.
Widget _bounceSwitcher(Widget child) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.elasticOut,
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: child,
    );

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.act});

  final SpellingGameState state;
  final ActionHandler act;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          BigIconButton(
            icon: Icons.home_rounded,
            color: SpellingColors.neutralButton,
            size: 52,
            semanticLabel: 'Home',
            onTap: () => act(SpellingAction.homePressed),
            onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.home}),
          ),
          const SizedBox(width: 8),
          Expanded(child: ProgressStars(outcomes: state.outcomes, currentIndex: state.wordIndex)),
          const SizedBox(width: 8),
          BigIconButton(
            icon: state.soundEffectsMuted ? Icons.music_off_rounded : Icons.music_note_rounded,
            color: SpellingColors.neutralButton,
            size: 52,
            semanticLabel: 'Sounds',
            onTap: () => act(SpellingAction.toggleMute),
            onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.mute}),
          ),
        ],
      ),
    );
  }
}

/// Mascot, the word's picture, the 🔊 button and (after answering) the
/// written word with the letter being read highlighted.
class _Stage extends StatelessWidget {
  const _Stage({required this.state, required this.act, required this.tile});

  final SpellingGameState state;
  final ActionHandler act;
  final double tile;

  @override
  Widget build(BuildContext context) {
    final picture = tile * 1.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(
              size: tile * 1.05,
              mood: state.feedback == WordFeedback.correct ? MascotMood.cheer : MascotMood.idle,
            ),
            SizedBox(width: tile * 0.25),
            // No picture card at all when the word has no matching emoji.
            if (state.word.picture case final emoji?) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Container(
                  key: ValueKey(state.wordIndex),
                  width: picture,
                  height: picture,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SpellingColors.card,
                    borderRadius: BorderRadius.circular(picture * 0.22),
                    boxShadow: const [
                      BoxShadow(color: SpellingColors.tileShadow, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  padding: EdgeInsets.all(picture * 0.14),
                  child: FittedBox(
                    child: Text(emoji, style: TextStyle(fontSize: picture * 0.62)),
                  ),
                ),
              ),
              SizedBox(width: tile * 0.25),
            ],
            BigIconButton(
              icon: Icons.volume_up_rounded,
              color: SpellingColors.replay,
              size: math.max(64, tile * 0.95),
              semanticLabel: 'Hear the word',
              onTap: () => act(SpellingAction.replayWord),
              onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.replay}),
            ),
          ],
        )),
        SizedBox(
          height: tile * 0.85,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: state.showWord ? 1 : 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < state.word.letters.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: state.spokenLetterIndex == i ? SpellingColors.highlight : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(state.word.letters[i], style: letterStyle(tile * 0.55)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The answer line. It has no boxes and no fixed length: it grows when a
/// letter is added and shrinks when one is taken away. The whole line is one
/// big drop area; where the finger is decides where the letter goes, and a
/// gap opens there while dragging.
class AnswerLine extends StatefulWidget {
  const AnswerLine({
    super.key,
    required this.state,
    required this.act,
    required this.tile,
    required this.maxWidth,
  });

  final SpellingGameState state;
  final ActionHandler act;

  /// Largest tile size; tiles shrink when many letters are on the line.
  final double tile;
  final double maxWidth;

  static const double gap = 10;
  static const double pad = 14;

  /// Insert position for a finger at [x] (local), on a centred row of [count]
  /// tiles of [size] inside [width]. Left of a tile's middle = before it.
  static int insertIndex({required double x, required int count, required double size, required double width}) {
    final step = size + gap;
    final start = (width - count * step) / 2;
    return ((x - start) / step).round().clamp(0, count);
  }

  @override
  State<AnswerLine> createState() => _AnswerLineState();
}

class _AnswerLineState extends State<AnswerLine> {
  /// Where the dragged letter would land, while one hovers over the line.
  int? _hover;
  int? _dragging;

  SpellingGameState get state => widget.state;

  /// Line tiles other than the one being dragged. The dragged tile stays in
  /// the tree (so its drag callbacks still fire) but shrinks to nothing, so
  /// the line closes up; positions are counted without it.
  List<int> get _resting => [for (final id in state.line) if (id != _dragging) id];

  double _tileSize(int count) {
    final fits = (widget.maxWidth - 2 * AnswerLine.pad) / math.max(1, count) - AnswerLine.gap;
    return math.min(widget.tile, fits).clamp(28.0, widget.tile);
  }

  int _indexAt(Offset global, double size) {
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    return AnswerLine.insertIndex(x: local.dx, count: _resting.length, size: size, width: box.size.width);
  }

  @override
  Widget build(BuildContext context) {
    final resting = _resting;
    final size = _tileSize(resting.length + 1);
    final lineColor = state.feedback == WordFeedback.correct ? SpellingColors.correct : SpellingColors.slotBorder;

    final line = state.line;
    final children = <Widget>[
      for (var i = 0; i < line.length; i++)
        Padding(
          key: ValueKey('line-${line[i]}'),
          padding: line[i] == _dragging ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: AnswerLine.gap / 2),
          child: DraggableTile(
            tile: state.tileById(line[i]),
            size: size,
            state: state,
            act: widget.act,
            highlighted: state.spokenLetterIndex == i,
            onLine: true,
            onDragChanged: (dragging) => setState(() => _dragging = dragging ? line[i] : null),
          ),
        ),
    ];
    if (_hover != null) {
      // The hover index counts resting tiles; find that spot in the full row.
      final h = _hover!.clamp(0, resting.length);
      final at = h == resting.length ? line.length : line.indexOf(resting[h]);
      children.insert(
        at,
        Padding(
          key: const ValueKey('line-gap'),
          padding: const EdgeInsets.symmetric(horizontal: AnswerLine.gap / 2),
          child: EmptySpot(size: size, color: SpellingColors.slotHover, borderColor: SpellingColors.slotBorder),
        ),
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => !state.inputLocked,
      onMove: (d) {
        final i = _indexAt(d.offset, size);
        if (i != _hover) setState(() => _hover = i);
      },
      onLeave: (_) => setState(() => _hover = null),
      onAcceptWithDetails: (d) {
        final i = _indexAt(d.offset, size);
        setState(() {
          _hover = null;
          _dragging = null;
        });
        widget.act(SpellingAction.dropOnLine, {'tileId': d.data, 'index': i});
      },
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.maxWidth,
        constraints: BoxConstraints(minHeight: widget.tile + 2 * AnswerLine.pad),
        padding: const EdgeInsets.symmetric(horizontal: AnswerLine.pad, vertical: AnswerLine.pad),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? SpellingColors.slotHover : SpellingColors.slot,
          borderRadius: BorderRadius.circular(24),
          // Same colour on every side (needed for rounded corners); the
          // thick bottom edge is the "line" the letters sit on.
          border: Border(
            left: BorderSide(color: lineColor, width: 2),
            top: BorderSide(color: lineColor, width: 2),
            right: BorderSide(color: lineColor, width: 2),
            bottom: BorderSide(color: lineColor, width: 6),
          ),
        ),
        alignment: Alignment.center,
        child: children.isEmpty
            ? Icon(Icons.south_rounded, size: widget.tile * 0.6, color: SpellingColors.slotBorder)
            : Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// A tile that can be dragged (touch or mouse) and tapped to hear its sound.
/// While dragged it sits centred under the finger, so the drop position is
/// where the finger is.
class DraggableTile extends StatelessWidget {
  const DraggableTile({
    super.key,
    required this.tile,
    required this.size,
    required this.state,
    required this.act,
    this.highlighted = false,
    this.onLine = false,
    this.onDragChanged,
  });

  final LetterTile tile;
  final double size;
  final SpellingGameState state;
  final ActionHandler act;
  final bool highlighted;

  /// Line tiles leave no hole while dragged (the line closes up).
  final bool onLine;
  final ValueChanged<bool>? onDragChanged;

  @override
  Widget build(BuildContext context) {
    final lifted = size * 1.08;
    return Draggable<int>(
      data: tile.id,
      maxSimultaneousDrags: state.inputLocked ? 0 : 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        onDragChanged?.call(true);
        act(SpellingAction.dragStarted, {'tileId': tile.id});
      },
      onDragEnd: (_) => onDragChanged?.call(false),
      feedback: Transform.translate(
        offset: Offset(-lifted / 2, -lifted / 2),
        child: Material(
          color: Colors.transparent,
          child: LetterTileView(letter: tile.letter, size: lifted, lifted: true),
        ),
      ),
      childWhenDragging: onLine ? const SizedBox.shrink() : EmptySpot(size: size, color: const Color(0x0F2F3A56)),
      child: GestureDetector(
        onTap: () => act(SpellingAction.tapTile, {'tileId': tile.id}),
        child: LetterTileView(letter: tile.letter, size: size, highlighted: highlighted),
      ),
    );
  }
}
