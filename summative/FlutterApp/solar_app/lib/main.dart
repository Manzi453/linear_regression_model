import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const defaultPredictApiUrl =
    'https://linearregressionmodel-production-31a6.up.railway.app/predict';

Uri resolvePredictApiUri(String rawEndpoint) {
  final trimmed = rawEndpoint.trim();
  if (trimmed.isEmpty) {
    return Uri.parse(defaultPredictApiUrl);
  }

  final parsed = Uri.parse(trimmed);
  final normalizedPath = switch (parsed.path) {
    '' || '/' => '/predict',
    '/docs' || '/docs/' => '/predict',
    _ when parsed.path.endsWith('/docs') =>
      '${parsed.path.substring(0, parsed.path.length - '/docs'.length)}/predict',
    _ => parsed.path,
  };

  return Uri(
    scheme: parsed.scheme,
    userInfo: parsed.userInfo,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: normalizedPath,
  );
}

void main() {
  runApp(const SolarPredictorApp());
}

class SolarPredictorApp extends StatelessWidget {
  const SolarPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0A8F7A);

    return MaterialApp(
      title: 'Solar Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F4EC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: const Color(0xFF17352E).withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: seedColor, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFC25E43), width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFC25E43), width: 1.4),
          ),
        ),
      ),
      home: const SolarPredictionScreen(),
    );
  }
}

class SolarPredictionScreen extends StatefulWidget {
  const SolarPredictionScreen({super.key});

  @override
  State<SolarPredictionScreen> createState() => _SolarPredictionScreenState();
}

class _SolarPredictionScreenState extends State<SolarPredictionScreen> {
  static const _predictEndpoint = String.fromEnvironment(
    'PREDICT_API_URL',
    defaultValue: defaultPredictApiUrl,
  );

  final _formKey = GlobalKey<FormState>();
  final _dcPowerController = TextEditingController();
  final _dailyYieldController = TextEditingController();
  final _totalYieldController = TextEditingController();

  bool _isLoading = false;
  double? _predictedAcPower;
  String? _errorMessage;

  Uri get _predictUri => resolvePredictApiUri(_predictEndpoint);

  @override
  void dispose() {
    _dcPowerController.dispose();
    _dailyYieldController.dispose();
    _totalYieldController.dispose();
    super.dispose();
  }

  Future<void> _submitPrediction() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _predictedAcPower = null;
        _errorMessage = 'Enter valid values for all required inputs.';
      });
      return;
    }

    final payload = <String, double>{
      'DC_POWER': double.parse(_dcPowerController.text.trim()),
      'DAILY_YIELD': double.parse(_dailyYieldController.text.trim()),
      'TOTAL_YIELD': double.parse(_totalYieldController.text.trim()),
    };

    setState(() {
      _isLoading = true;
      _predictedAcPower = null;
      _errorMessage = null;
    });

    try {
      final result = await _requestPrediction(payload);
      if (!mounted) {
        return;
      }

      setState(() {
        _predictedAcPower = result.predictedAcPower;
      });
    } on SocketException {
      setState(() {
        _errorMessage =
            'Could not reach the prediction API at ${_predictUri.origin}.';
      });
    } on TimeoutException {
      setState(() {
        _errorMessage = 'The API took too long to respond. Please try again.';
      });
    } on HttpException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } on FormatException {
      setState(() {
        _errorMessage = 'The API response did not include a valid prediction.';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Something went wrong while requesting the prediction.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<PredictionResult> _requestPrediction(
    Map<String, double> payload,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.postUrl(_predictUri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      final decoded = _decodeApiPayload(body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PredictionResult.fromJson(decoded as Map<String, dynamic>);
      }

      throw HttpException(_extractApiMessage(decoded, response.statusCode));
    } finally {
      client.close(force: true);
    }
  }

  dynamic _decodeApiPayload(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  String _extractApiMessage(dynamic payload, int statusCode) {
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];

      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }

      if (detail is List) {
        final messages = detail
            .map(
              (item) => switch (item) {
                {'msg': final String message} => message,
                _ => item.toString(),
              },
            )
            .where((message) => message.trim().isNotEmpty)
            .join('\n');

        if (messages.isNotEmpty) {
          return messages;
        }
      }
    }

    if (payload is String && payload.trim().isNotEmpty) {
      if (statusCode == HttpStatus.methodNotAllowed) {
        return 'The API rejected the request method. Make sure the app is calling POST /predict.';
      }

      return 'Prediction failed with status code $statusCode.';
    }

    return 'Prediction failed with status code $statusCode.';
  }

  String? _validateNumber({
    required String? value,
    required double min,
    required double max,
    required bool allowZero,
    required String label,
  }) {
    final trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return '$label is required.';
    }

    final number = double.tryParse(trimmed);
    if (number == null) {
      return '$label must be a valid number.';
    }

    if (!allowZero && number <= min) {
      return '$label must be greater than ${_formatRangeValue(min)}.';
    }

    if (allowZero && number < min) {
      return '$label must be at least ${_formatRangeValue(min)}.';
    }

    if (number > max) {
      return '$label must not exceed ${_formatRangeValue(max)}.';
    }

    return null;
  }

  String _formatRangeValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F1E8), Color(0xFFE7F4EF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17352E).withValues(alpha: 0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solar AC Power Prediction',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF17352E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the three values required by the API and get the predicted AC power.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4E655E),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _PredictionField(
                              controller: _dcPowerController,
                              label: 'DC_POWER',
                              hintText: 'e.g. 1000',
                              helperText:
                                  'Required. Greater than 0 and up to 15000.',
                              validator: (value) {
                                return _validateNumber(
                                  value: value,
                                  min: 0,
                                  max: 15000,
                                  allowZero: false,
                                  label: 'DC_POWER',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _PredictionField(
                              controller: _dailyYieldController,
                              label: 'DAILY_YIELD',
                              hintText: 'e.g. 5000',
                              helperText: 'Required. Between 0 and 10000.',
                              validator: (value) {
                                return _validateNumber(
                                  value: value,
                                  min: 0,
                                  max: 10000,
                                  allowZero: true,
                                  label: 'DAILY_YIELD',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _PredictionField(
                              controller: _totalYieldController,
                              label: 'TOTAL_YIELD',
                              hintText: 'e.g. 7000000',
                              helperText:
                                  'Required. Between 6000000 and 8000000, and greater than DAILY_YIELD.',
                              validator: (value) {
                                final baseValidation = _validateNumber(
                                  value: value,
                                  min: 6000000,
                                  max: 8000000,
                                  allowZero: false,
                                  label: 'TOTAL_YIELD',
                                );

                                if (baseValidation != null) {
                                  return baseValidation;
                                }

                                final totalYield = double.tryParse(
                                  value!.trim(),
                                );
                                final dailyYield = double.tryParse(
                                  _dailyYieldController.text.trim(),
                                );

                                if (totalYield != null &&
                                    dailyYield != null &&
                                    totalYield <= dailyYield) {
                                  return 'TOTAL_YIELD must be greater than DAILY_YIELD.';
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submitPrediction,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0A8F7A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Predict'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _PredictionResultPanel(
                        isLoading: _isLoading,
                        errorMessage: _errorMessage,
                        predictedAcPower: _predictedAcPower,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PredictionField extends StatelessWidget {
  const _PredictionField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.helperText,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String helperText;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF17352E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _PredictionResultPanel extends StatelessWidget {
  const _PredictionResultPanel({
    required this.isLoading,
    required this.errorMessage,
    required this.predictedAcPower,
  });

  final bool isLoading;
  final String? errorMessage;
  final double? predictedAcPower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E9E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prediction',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF17352E),
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading) ...[
            const LinearProgressIndicator(
              minHeight: 8,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 16),
            Text(
              'Requesting prediction from the API...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4E655E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (errorMessage != null &&
              errorMessage!.trim().isNotEmpty) ...[
            Text(
              errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8F321C),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ] else if (predictedAcPower != null) ...[
            Text(
              predictedAcPower!.toStringAsFixed(4),
              style: theme.textTheme.displaySmall?.copyWith(
                color: const Color(0xFF0A8F7A),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Predicted AC_POWER',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF17352E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Text(
              'The API prediction will appear here after you submit the form.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4E655E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PredictionResult {
  const PredictionResult({required this.predictedAcPower});

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictedAcPower: (json['predicted_AC_POWER'] as num).toDouble(),
    );
  }

  final double predictedAcPower;
}
