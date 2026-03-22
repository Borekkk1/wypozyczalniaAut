import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://upxmpkhzfzvcnodiahul.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVweG1wa2h6Znp2Y25vZGlhaHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxMTI2OTEsImV4cCI6MjA4OTY4ODY5MX0.HzFIwtagFtdaQ6puHcg-UDT89aP7vi1QeJS6pXvQqR0',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wypożyczalnia Aut',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<dynamic> samochody = [];

  @override
  void initState() {
    super.initState();
    _loadSamochody();
  }

  Future<void> _loadSamochody() async {
    final response = await Supabase.instance.client
        .from('samochody')
        .select()
        .limit(5);
    setState(() {
      samochody = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test połączenia z Supabase')),
      body: ListView.builder(
        itemCount: samochody.length,
        itemBuilder: (context, index) {
          final auto = samochody[index];
          return ListTile(
            title: Text(auto['kolor'] ?? ''),
            subtitle: Text('${auto['moc_km']} KM'),
          );
        },
      ),
    );
  }
}