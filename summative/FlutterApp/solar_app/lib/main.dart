import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SolarPredictorApp());
}

class SolarPredictorApp extends StatelessWidget {
  const SolarPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0A8F7A);

    return MaterialApp(
      title: 'Solar AC Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F2EA),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF18302B),
          displayColor: const Color(0xFF18302B),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.86),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(
              color: const Color(0xFF18302B).withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFF0A8F7A), width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFFC25E43), width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
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
  static const _swaggerDocsUrl =
      'https://linearregressionmodel-production-31a6.up.railway.app/docs';

  final _formKey = GlobalKey<FormState>();
  final _dcPowerController = TextEditingController();
  final _dailyYieldController = TextEditingController();
  final _totalYieldController = TextEditingController();

  bool _isLoading = false;
  PredictionResult? _prediction;
  String? _errorMessage;

  Uri get _predictUri {
    final docsUri = Uri.parse(_swaggerDocsUrl);
    final pathSegments = List<String>.from(docsUri.pathSegments);

    if (pathSegments.isNotEmpty && pathSegments.last == 'docs') {
      pathSegments.removeLast();
    }

    return docsUri.replace(
      pathSegments: [...pathSegments, 'predict'],
      query: null,
      fragment: null,
    );
  }

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
        _prediction = null;
        _errorMessage =
            'Enter all three values within range so the model can make a prediction.';
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
      _prediction = null;
      _errorMessage = null;
    });

    try {
      final result = await _requestPrediction(payload);
      if (!mounted) {
        return;
      }

      setState(() {
        _prediction = result;
      });
    } on SocketException {
      setState(() {
        _errorMessage =
            'Unable to reach the Railway API. Check your internet connection and confirm the deployed service is online.';
      });
    } on TimeoutException {
      setState(() {
        _errorMessage =
            'The server took too long to respond. Please try again in a moment.';
      });
    } on HttpException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } on FormatException {
      setState(() {
        _errorMessage =
            'The API returned an unexpected response. Verify the endpoint is still using the current prediction schema.';
      });
    } catch (_) {
      setState(() {
        _errorMessage =
            'Something went wrong while requesting the prediction. Please try again.';
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
      final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PredictionResult.fromJson(decoded as Map<String, dynamic>);
      }

      throw HttpException(_extractApiMessage(decoded, response.statusCode));
    } finally {
      client.close(force: true);
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

    return 'Prediction failed with status code $statusCode.';
  }

  void _loadExampleValues() {
    setState(() {
      _dcPowerController.text = '1000';
      _dailyYieldController.text = '5000';
      _totalYieldController.text = '7000000';
      _errorMessage = null;
      _prediction = null;
    });
  }

  void _clearForm() {
    setState(() {
      _dcPowerController.clear();
      _dailyYieldController.clear();
      _totalYieldController.clear();
      _prediction = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6F2E9), Color(0xFFF0E6D5), Color(0xFFE2F4EE)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 920;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildInputSection(theme)),
                              const SizedBox(width: 24),
                              Expanded(child: _buildOutputSection(theme)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputSection(theme),
                              const SizedBox(height: 24),
                              _buildOutputSection(theme),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderSection(
          docsUrl: _swaggerDocsUrl,
          predictUrl: _predictUri.toString(),
        ),
        const SizedBox(height: 22),
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plant input form',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the three variables required by your FastAPI endpoint. The app validates the same ranges enforced by Pydantic before sending the request.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF48625B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _PredictionField(
                      controller: _dcPowerController,
                      label: 'DC_POWER',
                      helper:
                          'Required. Must be greater than 0 and no more than 15,000.',
                      icon: Icons.bolt_rounded,
                      hintText: 'e.g. 1000',
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
                      helper: 'Required. Accepts values from 0 up to 10,000.',
                      icon: Icons.stacked_line_chart_rounded,
                      hintText: 'e.g. 5000',
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
                      helper:
                          'Required. Must be between 6,000,000 and 8,000,000, and larger than DAILY_YIELD.',
                      icon: Icons.wb_sunny_rounded,
                      hintText: 'e.g. 7000000',
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

                        final totalYield = double.tryParse(value!.trim());
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
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _submitPrediction,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_graph_rounded),
                    label: Text(_isLoading ? 'Predicting...' : 'Predict'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A8F7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadExampleValues,
                    icon: const Icon(Icons.tips_and_updates),
                    label: const Text('Use sample values'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF18302B),
                      side: BorderSide(
                        color: const Color(0xFF18302B).withValues(alpha: 0.14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _clearForm,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutputSection(ThemeData theme) {
    return Column(
      children: [
        _ResultCard(
          prediction: _prediction,
          errorMessage: _errorMessage,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 22),
        _InfoCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4B5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.rule_folder_rounded,
                      color: Color(0xFF8A4E0F),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'API rules mirrored in the UI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _RuleTile(
                title: 'Data types',
                description:
                    'All three text fields accept numeric values only because the FastAPI endpoint expects floats.',
              ),
              const _RuleTile(
                title: 'Range checks',
                description:
                    'DC_POWER: 0 to 15,000, DAILY_YIELD: 0 to 10,000, TOTAL_YIELD: 6,000,000 to 8,000,000.',
              ),
              const _RuleTile(
                title: 'Relational check',
                description:
                    'TOTAL_YIELD must be greater than DAILY_YIELD before the form can be submitted.',
              ),
            ],
          ),
        ),
      ],
    );
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
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.docsUrl, required this.predictUrl});

  final String docsUrl;
  final String predictUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123D36), Color(0xFF0A8F7A), Color(0xFFFFB44D)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123D36).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Task 3 • Flutter Mobile UI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Predict solar AC power with a clean one-screen experience.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This mobile page collects DC power, daily yield, and total yield, then sends them to your deployed Railway API for live predictions.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HighlightChip(label: '3 validated inputs'),
              _HighlightChip(label: 'POST /predict'),
              _HighlightChip(label: 'Swagger-ready demo'),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live API routes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  docsUrl,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  predictUrl,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFF2D8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionField extends StatelessWidget {
  const _PredictionField({
    required this.controller,
    required this.label,
    required this.helper,
    required this.icon,
    required this.hintText,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String helper;
  final IconData icon;
  final String hintText;
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
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF0A8F7A)),
            hintText: hintText,
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF617A73),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.prediction,
    required this.errorMessage,
    required this.isLoading,
  });

  final PredictionResult? prediction;
  final String? errorMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorMessage != null && errorMessage!.trim().isNotEmpty;
    final hasPrediction = prediction != null;

    final accentColor = hasError
        ? const Color(0xFFC25E43)
        : hasPrediction
        ? const Color(0xFF0A8F7A)
        : const Color(0xFF123D36);

    return _InfoCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  hasError
                      ? Icons.priority_high_rounded
                      : hasPrediction
                      ? Icons.check_circle_rounded
                      : Icons.query_stats_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Prediction output',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentColor.withValues(alpha: 0.14)),
            ),
            child: _ResultBody(
              prediction: prediction,
              errorMessage: errorMessage,
              isLoading: isLoading,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'The returned result appears here after a successful POST request, or an error message is shown if the input is missing, out of range, or the API cannot be reached.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5D746D),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.prediction,
    required this.errorMessage,
    required this.isLoading,
  });

  final PredictionResult? prediction;
  final String? errorMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(
            minHeight: 8,
            borderRadius: BorderRadius.all(Radius.circular(999)),
            color: Color(0xFF0A8F7A),
            backgroundColor: Color(0xFFE1EFEA),
          ),
          const SizedBox(height: 18),
          Text(
            'Requesting live prediction from the Railway API...',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      return Text(
        errorMessage!,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF8F321C),
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (prediction != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prediction!.formattedPrediction,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0A8F7A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Predicted AC_POWER',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(label: 'Best model: ${prediction!.bestModelName}'),
              _StatusPill(
                label: 'Feature order: ${prediction!.featureOrder.join(', ')}',
              ),
            ],
          ),
        ],
      );
    }

    return Text(
      'Tap "Predict" to display the model output here.',
      style: theme.textTheme.bodyLarge?.copyWith(
        color: const Color(0xFF48625B),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17352E).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF17352E).withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F4EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0E5A4A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF0A8F7A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF49635C),
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF18302B),
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PredictionResult {
  const PredictionResult({
    required this.predictedAcPower,
    required this.bestModelName,
    required this.featureOrder,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictedAcPower: (json['predicted_AC_POWER'] as num).toDouble(),
      bestModelName: json['best_model_name'] as String,
      featureOrder: (json['feature_order'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(),
    );
  }

  final double predictedAcPower;
  final String bestModelName;
  final List<String> featureOrder;

  String get formattedPrediction => predictedAcPower.toStringAsFixed(4);
}
