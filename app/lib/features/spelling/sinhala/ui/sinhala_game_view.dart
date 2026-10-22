import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../game/spelling_game_controller.dart' show WordFeedback;
import '../../ui/game_view.dart' show AnswerLine;
import '../../ui/spelling_style.dart';
import '../../ui/widgets/big_icon_button.dart';
import '../../ui/widgets/effects.dart';
import '../../ui/widgets/letter_tile.dart' show EmptySpot;
import '../../ui/widgets/mascot.dart';
import '../../ui/widgets/progress_stars.dart';
import '../game/sinhala_game_controller.dart';

typedef SinhalaActionHandler = void Function(SinhalaAction type, [Map<String, Object?> data]);

/// Pilla tiles are lavender so children see "letters" and "pillas" as two
/// kinds of tile.
const _markColor = Color(0xFFF0E6FF);
const _markTray = Color(0xFFE9DDFB);

TextStyle sinhalaTileStyle(double size) => TextStyle(
      fontFamily: AppFonts.sinhala,
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: SpellingColors.ink,
      height: 1.25,
    );

/// One Sinhala tile: a letter (ප), a pilla on a dotted circle (◌ූ), or a
/// built akshara on the line (පූ).
class SinhalaTileView extends StatelessWidget {
  const SinhalaTileView({
    super.key,
    required this.label,
    required this.size,
    this.mark = false,
    this.lifted = false,
    this.highlighted = false,
  });

  final String label;
  final double size;
  final bool mark;
  final bool lifted;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: highlighted ? SpellingColors.highlight : (mark ? _markColor : SpellingColors.tile),
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(color: SpellingColors.tileShadow, blurRadius: lifted ? 18 : 6, offset: Offset(0, lifted ? 10 : 4)),
        ],
      ),
      child: FittedBox(child: Text(label, style: sinhalaTileStyle(size * 0.55))),
    );
  }
}

/// One word of the game: picture + 🔊, the answer line, the tray (letters,
/// then pillas) and ✓. Same layout as the English game.
class SinhalaGameView extends StatelessWidget {
  const SinhalaGameView({super.key, required this.state, required this.act});

  final SinhalaGameState state;
  final SinhalaActionHandler act;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight * 1.15;
        final layout = _layout(box, landscape);
        final tile = layout.tile;

        final stage = _Stage(state: state, act: act, tile: tile);
        final answer = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wobble(
              signal: state.wobbleSignal,
              child: SinhalaAnswerLine(state: state, act: act, tile: layout.slot, maxWidth: layout.width),
            ),
            SizedBox(height: tile * 0.4),
            _tray(tile),
            SizedBox(height: tile * 0.35),
            _checkButton(tile),
          ],
        );

        return Column(
          children: [
            _TopBar(state: state, act: act),
            Expanded(
              child: landscape
                  ? Row(
                      children: [
                        Expanded(flex: 4, child: Center(child: stage)),
                        Expanded(flex: 6, child: Center(child: answer)),
                      ],
                    )
                  : Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [stage, answer]),
            ),
          ],
        );
      },
    );
  }

  /// Biggest tile size (96 down to 44) at which everything fits.
  ({double tile, double slot, double width}) _layout(BoxConstraints box, bool landscape) {
    final letters = state.tiles.where((t) => !t.isMark).length;
    final marks = state.tiles.length - letters;
    final onLine = math.max(state.word.aksharas.length, state.line.length) + 1;
    final width = (landscape ? box.maxWidth * 0.55 : box.maxWidth) - 32;
    final height = box.maxHeight - 72;

    ({double tile, double slot, double width}) fit(double tile) {
      final slot = math.min(tile, width / onLine - AnswerLine.gap).clamp(34.0, 100.0);
      return (tile: tile, slot: slot, width: width);
    }

    double needed(double tile, double slot) {
      final perRow = math.max(1, ((width - 2 * _gap) / (tile + _gap)).floor());
      final rows = (letters / perRow).ceil() + (marks == 0 ? 0 : (marks / perRow).ceil());
      final tray = rows * (tile + _gap) + 3 * _gap + (marks == 0 ? 0 : 2 * _gap);
      final line = slot * 1.42 + 4 + 2 * AnswerLine.pad + 8;
      final answer = line + tile * 0.4 + tray + tile * 0.35 + math.max(76, tile * 1.05);
      final stage = tile * 1.5 + tile * 0.8;
      return landscape ? math.max(answer, stage) : answer + stage + 24;
    }

    for (var tile = 96.0; tile > 44; tile -= 4) {
      final l = fit(tile);
      if (needed(l.tile, l.slot) <= height) return l;
    }
    return fit(44);
  }

  Widget _tray(double tile) {
    final letters = [for (final t in state.tiles) if (!t.isMark) t];
    final marks = [for (final t in state.tiles) if (t.isMark) t];

    Widget group(List<SinhalaTile> tiles) => Wrap(
          alignment: WrapAlignment.center,
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final t in tiles)
              _bounceSwitcher(
                state.isPlaced(t.id)
                    ? EmptySpot(key: ValueKey('tray-empty-${t.id}'), size: tile, color: const Color(0x0F2F3A56))
                    : _TrayTile(key: ValueKey('tray-${t.id}'), tile: t, size: tile, state: state, act: act),
              ),
          ],
        );

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => !state.inputLocked && state.isPlaced(d.data),
      onAcceptWithDetails: (d) => act(SinhalaAction.dropOnTray, {'tileId': d.data}),
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
            group(letters),
            if (marks.isNotEmpty) ...[
              const SizedBox(height: _gap),
              Container(
                padding: const EdgeInsets.all(_gap / 2),
                decoration: BoxDecoration(color: _markTray, borderRadius: BorderRadius.circular(20)),
                child: group(marks),
              ),
            ],
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
        size: math.max(76, tile * 1.05),
        enabled: ready,
        semanticLabel: 'Check',
        onTap: () => act(SinhalaAction.checkPressed),
        onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_check'}),
      ),
    );
  }
}

Widget _bounceSwitcher(Widget child) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.elasticOut,
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: child,
    );

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.act});

  final SinhalaGameState state;
  final SinhalaActionHandler act;

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
            onTap: () => act(SinhalaAction.homePressed),
            onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_home'}),
          ),
          const SizedBox(width: 8),
          Expanded(child: ProgressStars(outcomes: state.outcomes, currentIndex: state.wordIndex)),
          const SizedBox(width: 8),
          BigIconButton(
            icon: state.soundEffectsMuted ? Icons.music_off_rounded : Icons.music_note_rounded,
            color: SpellingColors.neutralButton,
            size: 52,
            semanticLabel: 'Sounds',
            onTap: () => act(SinhalaAction.toggleMute),
            onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_mute'}),
          ),
        ],
      ),
    );
  }
}

/// Mascot, the word's picture, 🔊, and (after answering) the written word
/// with the akshara being read highlighted.
class _Stage extends StatelessWidget {
  const _Stage({required this.state, required this.act, required this.tile});

  final SinhalaGameState state;
  final SinhalaActionHandler act;
  final double tile;

  @override
  Widget build(BuildContext context) {
    final picture = tile * 1.5;
    final image = state.word.imageAsset;
    final aksharas = state.word.aksharaTexts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(
                size: tile * 1.05,
                mood: state.feedback == WordFeedback.correct ? MascotMood.cheer : MascotMood.idle,
              ),
              SizedBox(width: tile * 0.25),
              if (image != null) ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: Container(
                    key: ValueKey('${state.word.id}-${state.wordIndex}'),
                    width: picture,
                    height: picture,
                    padding: EdgeInsets.all(picture * 0.14),
                    decoration: BoxDecoration(
                      color: SpellingColors.card,
                      borderRadius: BorderRadius.circular(picture * 0.22),
                      boxShadow: const [
                        BoxShadow(color: SpellingColors.tileShadow, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: SvgPicture.asset(image, fit: BoxFit.contain),
                  ),
                ),
                SizedBox(width: tile * 0.25),
              ],
              BigIconButton(
                icon: Icons.volume_up_rounded,
                color: SpellingColors.replay,
                size: math.max(64, tile * 0.95),
                semanticLabel: 'Hear the word',
                onTap: () => act(SinhalaAction.replayWord),
                onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_replay'}),
              ),
            ],
          ),
        ),
        SizedBox(
          height: tile * 0.8,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: state.showWord ? 1 : 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < aksharas.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: state.spokenIndex == i ? SpellingColors.highlight : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(aksharas[i], style: sinhalaTileStyle(tile * 0.5)),
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

/// The answer line. Letters are dropped onto the line (between aksharas
/// too); pillas are dropped onto a letter. Each akshara shows its pillas as
/// small chips underneath, which can be dragged off again.
class SinhalaAnswerLine extends StatefulWidget {
  const SinhalaAnswerLine({
    super.key,
    required this.state,
    required this.act,
    required this.tile,
    required this.maxWidth,
  });

  final SinhalaGameState state;
  final SinhalaActionHandler act;
  final double tile;
  final double maxWidth;

  @override
  State<SinhalaAnswerLine> createState() => _SinhalaAnswerLineState();
}

class _SinhalaAnswerLineState extends State<SinhalaAnswerLine> {
  int? _hover;
  int? _dragging;

  SinhalaGameState get state => widget.state;

  List<LineAkshara> get _resting => [for (final a in state.line) if (a.letterId != _dragging) a];

  double _tileSize(int count) {
    final fits = (widget.maxWidth - 2 * AnswerLine.pad) / math.max(1, count) - AnswerLine.gap;
    return math.min(widget.tile, fits).clamp(30.0, widget.tile);
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
    final chip = size * 0.42;
    final lineColor = state.feedback == WordFeedback.correct ? SpellingColors.correct : SpellingColors.slotBorder;
    final line = state.line;

    final children = <Widget>[
      for (var i = 0; i < line.length; i++)
        Padding(
          key: ValueKey('line-${line[i].letterId}'),
          padding: line[i].letterId == _dragging
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: AnswerLine.gap / 2),
          child: _AksharaOnLine(
            index: i,
            akshara: line[i],
            size: size,
            chip: chip,
            state: state,
            act: widget.act,
            collapsed: line[i].letterId == _dragging,
            onDragChanged: (dragging) => setState(() => _dragging = dragging ? line[i].letterId : null),
          ),
        ),
    ];
    if (_hover != null) {
      final h = _hover!.clamp(0, resting.length);
      final at = h == resting.length ? line.length : line.indexOf(resting[h]);
      children.insert(
        at,
        Padding(
          key: const ValueKey('line-gap'),
          padding: const EdgeInsets.symmetric(horizontal: AnswerLine.gap / 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptySpot(size: size, color: SpellingColors.slotHover, borderColor: SpellingColors.slotBorder),
              SizedBox(height: chip + 4),
            ],
          ),
        ),
      );
    }

    return DragTarget<int>(
      // Letters land on the line; pillas land on a letter (handled there).
      onWillAcceptWithDetails: (d) => !state.inputLocked && !state.tileById(d.data).isMark,
      onMove: (d) {
        if (state.tileById(d.data).isMark) return;
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
        widget.act(SinhalaAction.dropOnLine, {'tileId': d.data, 'index': i});
      },
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.maxWidth,
        constraints: BoxConstraints(minHeight: widget.tile * 1.42 + 4 + 2 * AnswerLine.pad),
        padding: const EdgeInsets.all(AnswerLine.pad),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? SpellingColors.slotHover : SpellingColors.slot,
          borderRadius: BorderRadius.circular(24),
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
            : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

/// An akshara on the line: the built akshara (drop a pilla on it; drag it
/// to move or remove it with its pillas), and its pilla chips below.
class _AksharaOnLine extends StatelessWidget {
  const _AksharaOnLine({
    required this.index,
    required this.akshara,
    required this.size,
    required this.chip,
    required this.state,
    required this.act,
    required this.collapsed,
    required this.onDragChanged,
  });

  final int index;
  final LineAkshara akshara;
  final double size;
  final double chip;
  final SinhalaGameState state;
  final SinhalaActionHandler act;
  final bool collapsed;
  final ValueChanged<bool> onDragChanged;

  @override
  Widget build(BuildContext context) {
    final text = state.aksharaText(akshara);
    final lifted = size * 1.08;
    final letter = DragTarget<int>(
      onWillAcceptWithDetails: (d) => !state.inputLocked && state.tileById(d.data).isMark,
      onAcceptWithDetails: (d) => act(SinhalaAction.dropOnAkshara, {'tileId': d.data, 'lineIndex': index}),
      builder: (context, candidates, _) => Draggable<int>(
        data: akshara.letterId,
        maxSimultaneousDrags: state.inputLocked ? 0 : 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () {
          onDragChanged(true);
          act(SinhalaAction.dragStarted);
        },
        onDragEnd: (_) => onDragChanged(false),
        feedback: Transform.translate(
          offset: Offset(-lifted / 2, -lifted / 2),
          child: Material(color: Colors.transparent, child: SinhalaTileView(label: text, size: lifted, lifted: true)),
        ),
        childWhenDragging: const SizedBox.shrink(),
        child: GestureDetector(
          onTap: () => act(SinhalaAction.tapTile, {'tileId': akshara.letterId}),
          child: SinhalaTileView(
            label: text,
            size: size,
            highlighted: candidates.isNotEmpty || state.spokenIndex == index,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        letter,
        if (!collapsed) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: chip,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final id in akshara.markIds)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: _TrayTile(tile: state.tileById(id), size: chip, state: state, act: act, keepSpace: false),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A draggable tile (tray, or a pilla chip under an akshara). Tap to hear it.
class _TrayTile extends StatelessWidget {
  const _TrayTile({
    super.key,
    required this.tile,
    required this.size,
    required this.state,
    required this.act,
    this.keepSpace = true,
  });

  final SinhalaTile tile;
  final double size;
  final SinhalaGameState state;
  final SinhalaActionHandler act;

  /// Tray tiles leave an empty spot while dragged; chips just disappear.
  final bool keepSpace;

  @override
  Widget build(BuildContext context) {
    final lifted = math.max(size, 56.0) * 1.08;
    return Draggable<int>(
      data: tile.id,
      maxSimultaneousDrags: state.inputLocked ? 0 : 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => act(SinhalaAction.dragStarted),
      feedback: Transform.translate(
        offset: Offset(-lifted / 2, -lifted / 2),
        child: Material(
          color: Colors.transparent,
          child: SinhalaTileView(label: tile.label, size: lifted, mark: tile.isMark, lifted: true),
        ),
      ),
      childWhenDragging: keepSpace ? EmptySpot(size: size, color: const Color(0x0F2F3A56)) : SizedBox(width: size),
      child: GestureDetector(
        onTap: () => act(SinhalaAction.tapTile, {'tileId': tile.id}),
        child: SinhalaTileView(label: tile.label, size: size, mark: tile.isMark),
      ),
    );
  }
}
