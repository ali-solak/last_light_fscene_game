import 'package:flutter/widgets.dart';

import '../theme.dart';

/// A word that pops over the world ("CRACK", "DAWN 3"), drawn into a
/// `WidgetComponent`.
class WordPop extends StatelessWidget {
  const WordPop(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: titleStyle(50).copyWith(letterSpacing: 10),
    ),
  );
}
