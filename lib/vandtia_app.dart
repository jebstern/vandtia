import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "main_menu.dart";

class VandtiaApp extends ConsumerWidget {
  const VandtiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: "Vändtia",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainMenu(),
    );
  }
}
