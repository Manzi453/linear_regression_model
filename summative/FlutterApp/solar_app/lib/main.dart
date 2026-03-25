import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(home: PredictionPage()));
}

class PredictionPage extends StatefulWidget {
  @override
  _PredictionPageState createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final dcController = TextEditingController();
  final yieldController = TextEditingController();
  final hourController = TextEditingController();

  String result = "";

  Future<void> predict() async {
    final url = Uri.parse("https://your-api.onrender.com/predict");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "dc_power": double.parse(dcController.text),
          "daily_yield": double.parse(yieldController.text),
          "hour": int.parse(hourController.text),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          result = "Prediction: ${data['ac_power']}";
        });
      } else {
        setState(() {
          result = "Error: Invalid input";
        });
      }
    } catch (e) {
      setState(() {
        result = "Error connecting to API";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Solar Power Predictor")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: dcController,
              decoration: InputDecoration(labelText: "DC Power"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: yieldController,
              decoration: InputDecoration(labelText: "Daily Yield"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: hourController,
              decoration: InputDecoration(labelText: "Hour (0–23)"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: predict,
              child: Text("Predict"),
            ),
            SizedBox(height: 20),
            Text(result, style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}