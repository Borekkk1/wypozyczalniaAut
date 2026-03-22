import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://upxmpkhzfzvcnodiahul.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVweG1wa2h6Znp2Y25vZGlhaHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxMTI2OTEsImV4cCI6MjA4OTY4ODY5MX0.HzFIwtagFtdaQ6puHcg-UDT89aP7vi1QeJS6pXvQqR0',
  );
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const AppShell(),
  ));
}