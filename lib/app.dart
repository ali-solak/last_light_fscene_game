import 'package:material_ui/material_ui.dart';

import 'ui/app_shell.dart';
import 'ui/theme.dart';

class LastLightApp extends StatelessWidget {
  const LastLightApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Last Light',
    debugShowCheckedModeBanner: false,
    theme: lastLightTheme(),
    home: const Scaffold(body: AppShell()),
  );
}

/// Shown while the models, materials and shaders load.
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: lastLightTheme(),
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LAST LIGHT', style: titleStyle(56)),
            const SizedBox(height: 20),
            if (error == null)
              const SizedBox(
                width: 160,
                height: 2,
                child: LinearProgressIndicator(color: Palette.bone, backgroundColor: Palette.faint),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$error', style: uiStyle(13, color: Palette.danger)),
              ),
          ],
        ),
      ),
    ),
  );
}
