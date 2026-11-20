import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'farm_fields.dart';

const apiBaseUrl = 'https://kenya-maize-risk-api.onrender.com';

class Prediction {
  const Prediction({required this.yieldKgHa, required this.riskBand});

  final double yieldKgHa;
  final String riskBand;
}

class RiskApiException implements Exception {
  const RiskApiException(this.messages);

  final List<String> messages;
}

class RiskApi {
  RiskApi({http.Client? client, this.baseUrl = apiBaseUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<Prediction> predict(Map<String, Object> farm) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/predict'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(farm),
          )
          // A sleeping Render service can take up to a minute to wake
          .timeout(const Duration(seconds: 75));
    } on TimeoutException {
      throw const RiskApiException(['The risk service took too long to answer. It may be waking up, so try again.']);
    } on http.ClientException {
      throw const RiskApiException([
        "Couldn't reach the risk service. Check the phone's internet connection and try again.",
      ]);
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Prediction(
        yieldKgHa: (body['predicted_yield_kg_ha'] as num).toDouble(),
        riskBand: body['risk_band'] as String,
      );
    }
    if (response.statusCode == 422) throw RiskApiException(_validationMessages(response.body));
    throw RiskApiException(['The risk service returned an error (${response.statusCode}). Try again.']);
  }

  // Turns FastAPI's validation errors into one readable line per field
  List<String> _validationMessages(String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'] as List<dynamic>;
      return [
        for (final issue in detail.cast<Map<String, dynamic>>())
          '${_labelFor(issue['loc'] as List<dynamic>)}: ${issue['msg']}.',
      ];
    } catch (_) {
      return const ['The risk service rejected the values. Check every field and try again.'];
    }
  }

  String _labelFor(List<dynamic> location) {
    final key = location.isEmpty ? '' : location.last.toString();
    for (final field in allFields) {
      if (field.key == key) return field.label;
    }
    return key;
  }
}
