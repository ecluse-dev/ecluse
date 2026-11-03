import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Dates de naissance écrites avec des blancs autour des séparateurs ou avec
/// des blancs pour tout séparateur (P2-34) : « 12 / 03 / 1950 », « 12 03 1950 ».
/// Le contexte (« né le », « DDN ») reste obligatoire ; la date entière est masquée.
const _positifs = <String, String>{
  'né le 12 / 03 / 1950': '12 / 03 / 1950',
  'née le 12 03 1950': '12 03 1950',
  'DDN : 12 - 03 - 1950': '12 - 03 - 1950',
  'Date de naissance : 12 /03/ 1950': '12 /03/ 1950',
  'né le 5 3 1950': '5 3 1950',
  'né le 12 / 03 / 1950': '12 / 03 / 1950',
};

const _negatifs = <String>[
  'le 12 03 1950', // pas de contexte de naissance
  'né le 12 03 19500', // année sur 5 chiffres
  'né le 12 03',
  'né le 12 / 03',
  'DDN : 123 03 1950', // jour sur 3 chiffres
];

void main() {
  for (final MapEntry(key: texte, value: date) in _positifs.entries) {
    test('détectée : $texte', () async {
      final t = 'Patient $texte fin.';
      final es = await Ecluse.detect(t);
      final e = es.where((x) => x.type == EntityType.dateNaissance).toList();
      expect(e, hasLength(1), reason: 'non détectée : "$t"');
      expect(e.single.value, date);
      final r = await Ecluse.redact(t);
      expect(r.maskedText, contains('[DATE_NAISSANCE_1]'));
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });
  }

  for (final texte in _negatifs) {
    test('non détectée : $texte', () async {
      final es = await Ecluse.detect('Patient $texte fin.');
      expect(es.where((x) => x.type == EntityType.dateNaissance), isEmpty);
    });
  }
}
