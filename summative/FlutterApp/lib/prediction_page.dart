import 'package:flutter/material.dart';

import 'farm_fields.dart';
import 'risk_api.dart';
import 'theme.dart';
import 'widgets/field_horizon.dart';
import 'widgets/result_card.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key, required this.api});

  final RiskApi api;

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _controllers = {for (final field in allFields) field.key: TextEditingController()};
  final _fieldErrors = <String, String>{};
  final _scroll = ScrollController();
  Outcome _outcome = const Waiting();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    final errors = <String, String>{};
    for (final field in allFields) {
      final error = field.validate(_controllers[field.key]!.text);
      if (error != null) errors[field.key] = error;
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _outcome = errors.isEmpty
          ? const Loading()
          : Failure(errors.length == 1 ? 'Check 1 field' : 'Check ${errors.length} fields', errors.values.toList());
    });
    _scrollToResult();
    if (errors.isNotEmpty) return;

    final farm = {for (final field in allFields) field.key: field.toJsonValue(_controllers[field.key]!.text)};
    try {
      final prediction = await widget.api.predict(farm);
      if (mounted) setState(() => _outcome = Success(prediction));
    } on RiskApiException catch (error) {
      if (mounted) setState(() => _outcome = Failure("Couldn't get a prediction", error.messages));
    }
  }

  void _scrollToResult() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  void _fillExample() {
    setState(() {
      for (final field in allFields) {
        _controllers[field.key]!.text = field.example;
      }
      _fieldErrors.clear();
    });
  }

  void _clearAll() {
    setState(() {
      for (final controller in _controllers.values) {
        controller.clear();
      }
      _fieldErrors.clear();
      _outcome = const Waiting();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = _outcome is Loading;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Header(),
              Stack(
                children: [
                  const Positioned(left: 0, right: 0, top: 0, child: FieldHorizon()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
                    child: ResultCard(outcome: _outcome),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: loading ? null : _fillExample,
                        style: _flushButton,
                        child: const Text('Fill in an example field'),
                      ),
                      TextButton(
                        onPressed: loading ? null : _clearAll,
                        style: _flushButton,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              ),
              for (final section in fieldSections) _Section(section: section, builder: _buildField),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _PredictBar(loading: loading, onPressed: _predict),
    );
  }

  Widget _buildField(FarmField field) {
    final controller = _controllers[field.key]!;
    final isLast = field == allFields.last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(field.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              Text(field.range, style: const TextStyle(fontSize: 13, color: Palette.muted)),
            ],
          ),
          if (field.note != null) ...[
            const SizedBox(height: 3),
            Text(field.note!, style: const TextStyle(fontSize: 13, color: Palette.muted, height: 1.35)),
          ],
          const SizedBox(height: 8),
          TextField(
            key: Key('field-${field.key}'),
            controller: controller,
            keyboardType: switch (field.kind) {
              FieldKind.decimal => const TextInputType.numberWithOptions(decimal: true),
              FieldKind.whole => const TextInputType.numberWithOptions(signed: true),
              FieldKind.seedType => TextInputType.text,
            },
            autocorrect: false,
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            onSubmitted: isLast ? (_) => _predict() : null,
            onChanged: (_) {
              if (_fieldErrors.remove(field.key) != null || field.kind == FieldKind.seedType) setState(() {});
            },
            style: const TextStyle(fontSize: 16.5),
            decoration: InputDecoration(hintText: field.example, errorText: _fieldErrors[field.key]),
          ),
          if (field.kind == FieldKind.seedType) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in seedTypes.entries)
                  _SeedOption(
                    label: entry.value,
                    selected: controller.text.trim() == entry.key,
                    onTap: () => setState(() {
                      controller.text = entry.key;
                      _fieldErrors.remove(field.key);
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Text buttons without side padding, so their text lines up with the page edge
final _flushButton = TextButton.styleFrom(
  padding: EdgeInsets.zero,
  minimumSize: const Size(0, 44),
  foregroundColor: Palette.ink,
  textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.w500),
);

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grass_rounded, size: 22, color: Palette.ink),
              SizedBox(width: 8),
              Text('Hectare Africa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            ],
          ),
          SizedBox(height: 30),
          Text(
            'Know the farm\nbefore the season.',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -1.4, height: 1.08),
          ),
          SizedBox(height: 12),
          Text(
            "Enter what you know when a farmer signs up. Get the field's expected maize yield and its risk band.",
            style: TextStyle(fontSize: 15.5, color: Palette.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.builder});

  final FieldSection section;
  final Widget Function(FarmField field) builder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(section.note, style: const TextStyle(fontSize: 14, color: Palette.muted, height: 1.4)),
          const SizedBox(height: 16),
          for (final field in section.fields) builder(field),
        ],
      ),
    );
  }
}

class _SeedOption extends StatelessWidget {
  const _SeedOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Palette.ink : Palette.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? Palette.ink : Palette.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: selected ? Colors.white : Palette.ink, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _PredictBar extends StatelessWidget {
  const _PredictBar({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Palette.canvas,
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 56,
        child: FilledButton(
          key: const Key('predict-button'),
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Palette.ink,
            disabledBackgroundColor: Palette.ink.withValues(alpha: 0.75),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 17, fontWeight: FontWeight.w600),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
              ],
              const Text('Predict'),
            ],
          ),
        ),
      ),
    );
  }
}
