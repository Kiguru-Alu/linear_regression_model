enum FieldKind { decimal, whole, seedType }

const seedTypes = {
  'local_or_opv': 'Local or OPV',
  'hybrid_early': 'Early hybrid',
  'hybrid_medium': 'Medium hybrid',
  'hybrid_late': 'Late hybrid',
  'hybrid_unknown_maturity': 'Hybrid, maturity unknown',
};

class FarmField {
  const FarmField({
    required this.key,
    required this.label,
    required this.range,
    required this.kind,
    required this.example,
    this.note,
    this.min = 0,
    this.max = 0,
  });

  // key is the API's field name; label is what the agent sees
  final String key;
  final String label;
  final String range;
  final String? note;
  final FieldKind kind;
  final String example;
  final num min;
  final num max;

  // Returns a readable error, or null when the text is valid
  String? validate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '$label is missing.';

    if (kind == FieldKind.seedType) {
      if (seedTypes.containsKey(text)) return null;
      return '$label must be one of: ${seedTypes.keys.join(', ')}.';
    }

    final number = num.tryParse(text);
    if (number == null) {
      return kind == FieldKind.whole ? '$label must be a whole number.' : '$label must be a number.';
    }
    if (kind == FieldKind.whole && number is! int) return '$label must be a whole number.';
    if (number < min || number > max) {
      if (key == 'fert_in_hole') return '$label must be 1 (yes) or 0 (no).';
      return '$label must be between ${_format(min)} and ${_format(max)}.';
    }
    return null;
  }

  Object toJsonValue(String raw) {
    final text = raw.trim();
    return switch (kind) {
      FieldKind.seedType => text,
      FieldKind.whole => int.parse(text),
      FieldKind.decimal => double.parse(text),
    };
  }
}

String _format(num value) {
  final whole = value.abs().truncate().toString();
  final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final sign = value < 0 ? '-' : '';
  final decimals = value is double && value != value.truncate() ? value.toString().split('.').last : '';
  return decimals.isEmpty ? '$sign$grouped' : '$sign$grouped.$decimals';
}

class FieldSection {
  const FieldSection(this.title, this.note, this.fields);

  final String title;
  final String note;
  final List<FarmField> fields;
}

const fieldSections = [
  FieldSection('Where the field is', "Elevation from the phone's GPS, aridity from a climate map.", [
    FarmField(
      key: 'elev',
      label: 'Elevation (m)',
      range: '800 to 3,000',
      kind: FieldKind.decimal,
      min: 800,
      max: 3000,
      example: '1339',
    ),
    FarmField(
      key: 'avg_season_ai',
      label: 'Aridity index',
      range: '0.5 to 2.0',
      note: 'Higher means wetter.',
      kind: FieldKind.decimal,
      min: 0.5,
      max: 2.0,
      example: '0.92',
    ),
  ]),
  FieldSection('The soil', "From a soil map such as iSDAsoil, at the field's location.", [
    FarmField(
      key: 'soil_rzpawhc',
      label: 'Root-zone water capacity (mm)',
      range: '0 to 200',
      kind: FieldKind.decimal,
      min: 0,
      max: 200,
      example: '120',
    ),
    FarmField(
      key: 'soil_clay',
      label: 'Clay (%)',
      range: '10 to 70',
      kind: FieldKind.decimal,
      min: 10,
      max: 70,
      example: '32',
    ),
    FarmField(
      key: 'soil_pH',
      label: 'Soil pH',
      range: '4.0 to 8.5',
      kind: FieldKind.decimal,
      min: 4.0,
      max: 8.5,
      example: '6.2',
    ),
    FarmField(
      key: 'soil_orgC',
      label: 'Soil organic carbon (g/kg)',
      range: '0 to 60',
      kind: FieldKind.decimal,
      min: 0,
      max: 60,
      example: '11.2',
    ),
    FarmField(
      key: 'soil_ECEC',
      label: 'Soil ECEC (cmol/kg)',
      range: '0 to 40',
      kind: FieldKind.decimal,
      min: 0,
      max: 40,
      example: '12.5',
    ),
  ]),
  FieldSection('What the farmer plans', 'The plan for this season, as the farmer describes it.', [
    FarmField(
      key: 'N_kg_ha',
      label: 'Nitrogen (kg/ha)',
      range: '0 to 350',
      kind: FieldKind.decimal,
      min: 0,
      max: 350,
      example: '22.2',
    ),
    FarmField(
      key: 'plant_date_dev',
      label: 'Planting date vs usual (days)',
      range: '-120 to 120',
      note: 'Whole days. Negative means earlier than usual.',
      kind: FieldKind.whole,
      min: -120,
      max: 120,
      example: '-16',
    ),
    FarmField(
      key: 'fert_in_hole',
      label: 'Fertilizer in planting hole',
      range: '1 or 0',
      note: '1 means yes, 0 means no.',
      kind: FieldKind.whole,
      min: 0,
      max: 1,
      example: '1',
    ),
    FarmField(
      key: 'seed_type',
      label: 'Seed type',
      range: '5 options',
      note: 'Tap an option below or type its name.',
      kind: FieldKind.seedType,
      example: 'hybrid_late',
    ),
  ]),
];

final allFields = [for (final section in fieldSections) ...section.fields];
