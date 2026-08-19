import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../log.dart';

/// Asks a simple arithmetic question before letting anyone into the editor.
///
/// Not a password: a password is something a child watches you type and then
/// reproduces. An arithmetic challenge changes every time and cannot be learned
/// by observation, while costing an adult about two seconds.
///
/// This is a barrier against wandering, not a security control. It protects a
/// vocabulary from being deleted by accident, and nothing more, which is exactly
/// what is needed.
Future<bool> showParentGate(BuildContext context) async {
  Log.enter('showParentGate');

  final math.Random random = math.Random();
  final int a = 3 + random.nextInt(7);
  final int b = 2 + random.nextInt(8);
  final int answer = a + b;

  // Three plausible wrong answers, so a random tap is unlikely to succeed.
  final Set<int> options = <int>{answer};

  while (options.length < 4) {
    final int candidate = answer + random.nextInt(9) - 4;

    if (candidate > 0 && candidate != answer) {
      options.add(candidate);
    }
  }

  final List<int> shuffled = options.toList()..shuffle(random);

  final bool? passed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1C2228),
        title: const Text(
          'For a grown-up',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What is $a + $b?',
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: shuffled
                  .map(
                    (int option) => FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(option == answer),
                      child: Text(
                        '$option',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );

  Log.exit('showParentGate', 'passed=${passed == true}');
  return passed == true;
}
