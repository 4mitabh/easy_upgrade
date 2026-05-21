// Internal — not exported from `package:easy_upgrade/easy_upgrade.dart`.
// ignore_for_file: public_member_api_docs

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'easy_upgrade_messages.dart';
import 'upgrade_info.dart';

bool _isInsideCupertinoApp(BuildContext context) {
  return context.findAncestorWidgetOfExactType<CupertinoApp>() != null;
}

typedef DialogUpdateHandler = void Function(BuildContext dialogContext);

Future<void> showEasyUpgradeDialog({
  required BuildContext context,
  required UpgradeInfo info,
  required bool force,
  required EasyUpgradeMessages messages,
  required DialogUpdateHandler onUpdate,
  VoidCallback? onLater,
}) async {
  final useCupertino = _isInsideCupertinoApp(context);
  final body = force ? messages.bodyMajor : messages.bodyMinor;
  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) {
      final dialogContent = _DialogContent(
        body: body,
        releaseNotesLabel: messages.releaseNotesLabel,
        releaseNotes: info.releaseNotes,
      );
      return PopScope(
        canPop: !force,
        child: useCupertino
            ? CupertinoAlertDialog(
                title: Text(messages.title),
                content: dialogContent,
                actions: [
                  if (!force)
                    CupertinoDialogAction(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onLater?.call();
                      },
                      child: Text(messages.laterButton),
                    ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () => onUpdate(ctx),
                    child: Text(messages.updateButton),
                  ),
                ],
              )
            : AlertDialog(
                title: Text(messages.title),
                content: dialogContent,
                actions: [
                  if (!force)
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onLater?.call();
                      },
                      child: Text(messages.laterButton),
                    ),
                  FilledButton(
                    onPressed: () => onUpdate(ctx),
                    child: Text(messages.updateButton),
                  ),
                ],
              ),
      );
    },
  );
}

class _DialogContent extends StatelessWidget {
  final String body;
  final String releaseNotesLabel;
  final String? releaseNotes;

  const _DialogContent({
    required this.body,
    required this.releaseNotesLabel,
    required this.releaseNotes,
  });

  @override
  Widget build(BuildContext context) {
    final notes = releaseNotes?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            releaseNotesLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(child: Text(notes)),
          ),
        ],
      ],
    );
  }
}
