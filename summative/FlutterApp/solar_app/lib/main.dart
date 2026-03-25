import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SolarPredictorApp());
}

class SolarPredictorApp extends StatelessWidget {
  const SolarPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Power Predictor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ),
      home: const PredictionPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  PredictionPageState createState() => PredictionPageState();
}

class PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  final dcController = TextEditingController();
  final yieldController = TextEditingController();
  final hourController = TextEditingController();

  bool isLoading = false;
  String result = '';
  Color resultColor = Colors.grey;

  static const String apiUrl = 'http://127.0.0.1:8000/docs';  // Change to deployed URL if needed

  Future<void> predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'dc_power': double.parse(dcController.text),
          'daily_yield': double.parse(yieldController.text),
          'hour': int.parse(hourController.text),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          result = 'Predicted AC Power: ${data['predicted_ac_power']} kW';
          resultColor = Colors.green;
        });
      } else {
        setState(() {
          result = 'API Error: ${response.statusCode}';
          resultColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        result = 'Connection Error: $e';
        resultColor = Colors.red;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void clearForm() {
    dcController.clear();
    yieldController.clear();
    hourController.clear();
    setState(() {
      result = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.solar_power, color: Colors.yellow),
            SizedBox(width: 8),
            Text('Solar Predictor'),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade300, Colors.yellow.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.solar_power, size: 80, color: Colors.orange.shade700),
                  SizedBox(height: 16),
                  Text(
                    'Enter plant data to predict AC Power',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: dcController,
                            decoration: InputDecoration(
                              labelText: 'DC Power',
                              prefixIcon: Icon(Icons.flash_on),
                              prefixText: ' ',
                              suffixText: 'kW',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter DC Power';
                              final num = double.tryParse(value);
                              if (num == null || num <= 0) return 'DC Power must be > 0';
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: yieldController,
                            decoration: InputDecoration(
                              labelText: 'Daily Yield',
                              prefixIcon: Icon(Icons.trending_up),
                              prefixText: ' ',
                              suffixText: 'kWh',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter Daily Yield';
                              final num = double.tryParse(value);
                              if (num == null || num <= 0) return 'Daily Yield must be > 0';
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: hourController,
                            decoration: InputDecoration(
                              labelText: 'Hour',
                              prefixIcon: Icon(Icons.schedule),
                              prefixText: ' ',
                              suffixText: 'h',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter Hour';
                              final hr = int.tryParse(value);
                              if (hr == null || hr < 0 || hr > 23) return 'Hour must be 0-23';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : predict,
                    icon: const Icon(Icons.analytics),
                    label: Text(isLoading ? 'Predicting...' : 'Predict AC Power'),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Form'),
                  ),
                  if (result.isNotEmpty) ...[
                    SizedBox(height: 24),
                    Card(
                      elevation: 8,
                      color: resultColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              resultColor == Colors.green ? Icons.check_circle : Icons.error,
                              color: resultColor,
                              size: 32,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                result,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ).copyWith(color: resultColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    dcController.dispose();
    yieldController.dispose();
    hourController.dispose();
    super.dispose();
  }
}
