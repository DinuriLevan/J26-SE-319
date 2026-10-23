import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// A grown-up check before the parent dashboard: a times-table question (6-9 x 6-9), beyond what
/// Grade 2-3 children know. A speed bump to keep young children out, not security.
/// Returns true when answered correctly.
Future<bool> showParentGate(BuildContext context, {Random? random}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentGateDialog(random: random ?? Random()),
  );
  return ok ?? false;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.random});

  final Random random;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _answer = TextEditingController();
  late int _a, _b;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _newQuestion() {
    _a = 6 + widget.random.nextInt(4);
    _b = 6 + widget.random.nextInt(4);
    _answer.clear();
  }

  void _check() {
    if (int.tryParse(_answer.text.trim()) == _a * _b) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrong = true;
      _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.parentGateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.parentGateQuestion(_a, _b),
              key: const ValueKey('parent_gate_question'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('parent_gate_answer'),
            controller: _answer,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.parentGateAnswer,
              errorText: _wrong ? l10n.parentGateWrong : null,
            ),
            onSubmitted: (_) => _check(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('parent_gate_open'),
          onPressed: _check,
          child: Text(l10n.parentGateOpen),
        ),
      ],
    );
  }
}
