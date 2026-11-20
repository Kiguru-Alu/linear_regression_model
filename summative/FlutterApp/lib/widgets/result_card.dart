import 'package:flutter/material.dart';

import '../risk_api.dart';
import '../theme.dart';

sealed class Outcome {
  const Outcome();
}

class Waiting extends Outcome {
  const Waiting();
}

class Loading extends Outcome {
  const Loading();
}

class Success extends Outcome {
  const Success(this.prediction);

  final Prediction prediction;
}

class Failure extends Outcome {
  const Failure(this.title, this.messages);

  final String title;
  final List<String> messages;
}

const _meterMax = 6000.0;

Color bandColor(String band) => switch (band) {
  'low' => Palette.fieldGreen,
  'medium' => Palette.harvestAmber,
  _ => Palette.droughtRed,
};

String bandLabel(String band) => switch (band) {
  'low' => 'Low risk',
  'medium' => 'Medium risk',
  _ => 'High risk',
};

String groupThousands(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.outcome});

  final Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final outcome = this.outcome;
    return Container(
      key: const Key('result-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0F2731), blurRadius: 28, spreadRadius: -6, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x0A0F2731), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: switch (outcome) {
          Failure() => _FailureView(outcome),
          _ => _YieldView(outcome),
        },
      ),
    );
  }
}

class _YieldView extends StatelessWidget {
  const _YieldView(this.outcome);

  final Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final prediction = outcome is Success ? (outcome as Success).prediction : null;
    final color = prediction == null ? Palette.ink : bandColor(prediction.riskBand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Expected maize yield', style: TextStyle(color: Palette.muted, fontSize: 14.5)),
            ),
            if (prediction != null) _BandPill(prediction.riskBand),
          ],
        ),
        const SizedBox(height: 6),
        _YieldFigure(prediction: prediction, loading: outcome is Loading),
        const SizedBox(height: 18),
        _YieldMeter(value: prediction?.yieldKgHa ?? 0, color: color),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: TextStyle(color: Palette.muted, fontSize: 12)),
            Text('6,000 kg/ha', style: TextStyle(color: Palette.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 14),
        Text(switch (outcome) {
          Loading() => 'Asking the model. The first request can take up to a minute while the service wakes up.',
          Success() => 'Predicted from what is known at sign-up. Read it alongside the other farms in the same area.',
          _ => 'Fill in the 11 fields below and tap Predict.',
        }, style: const TextStyle(color: Palette.muted, fontSize: 13.5, height: 1.4)),
      ],
    );
  }
}

class _YieldFigure extends StatelessWidget {
  const _YieldFigure({required this.prediction, required this.loading});

  final Prediction? prediction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const figure = TextStyle(fontSize: 50, fontWeight: FontWeight.w600, letterSpacing: -2, height: 1.1);
    const faded = Color(0xFFB5C0C3);

    if (loading) {
      return const SizedBox(
        height: 55,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.ink),
          ),
        ),
      );
    }
    if (prediction == null) return const Text('—', style: TextStyle(fontSize: 50, color: faded, height: 1.1));

    final tenths = (prediction!.yieldKgHa * 10).round();
    return Text.rich(
      TextSpan(
        style: figure,
        children: [
          TextSpan(text: groupThousands(tenths ~/ 10)),
          TextSpan(
            text: '.${tenths % 10}',
            style: const TextStyle(color: faded),
          ),
          const TextSpan(
            text: '  kg/ha',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, letterSpacing: 0, color: Palette.muted),
          ),
        ],
      ),
      key: const Key('yield-figure'),
    );
  }
}

class _BandPill extends StatelessWidget {
  const _BandPill(this.band);

  final String band;

  @override
  Widget build(BuildContext context) {
    final color = bandColor(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            bandLabel(band),
            style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Rising bars, filled up to the predicted yield on a 0 to 6,000 kg/ha scale
class _YieldMeter extends StatelessWidget {
  const _YieldMeter({required this.value, required this.color});

  final double value;
  final Color color;

  static const _bars = 26;

  @override
  Widget build(BuildContext context) {
    final target = (value / _meterMax).clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, fraction, _) {
        final filled = (fraction * _bars).round();
        return SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _bars; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 14 + 42 * i / (_bars - 1),
                    decoration: BoxDecoration(
                      color: i < filled ? color : Palette.emptyBar,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView(this.failure);

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Palette.droughtRed, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                failure.title,
                style: const TextStyle(color: Palette.droughtRed, fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final message in failure.messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 10),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: Palette.droughtRed, shape: BoxShape.circle),
                ),
                Expanded(child: Text(message, style: const TextStyle(fontSize: 14.5, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}
