import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/heuristics/identifiant_ocr_detector.dart';
import 'package:test/test.dart';

/// P2-275 : deux trous de P2-268 (mesurés par `Ecluse.redact`).
///
/// 1. Un NIR corse (« 2A » / « 2B ») lu avec une lettre d'OCR, sans libellé,
///    restait en clair (4 sur 120 au banc d'OCR) : le détecteur n'acceptait que
///    `[0-9OolI]` et écartait la suite à cause du « A » ou du « B ».
/// 2. Derrière un libellé fort, un NIR, un RPPS ou un IBAN lu avec des lettres
///    d'OCR, dont la clé est **fausse** une fois relu, écrit avec des
///    séparateurs multiples (deux espaces, tabulation, espaces insécables),
///    restait en clair : `IdentifiantCleInvalideDetector` n'accepte qu'un
///    séparateur simple, et ce détecteur ne masquait que les clés justes.
///
/// Identifiants **synthétiques**, clés calculées ici.
String cleNir(String corps13) {
  // Corse : 2A → 19, 2B → 18 (soustraction de 1 000 000 / 2 000 000).
  final n = corps13.replaceFirst('2A', '19').replaceFirst('2B', '18');
  final k = 97 - (int.parse(n) % 97);
  return k.toString().padLeft(2, '0');
}

void main() {
  const detecteur = IdentifiantOcrDetector();
  const nbsp = ' ';
  final corpsA = '1771' '02A' '736118'; // 1 77 10 2A 736 118
  final corpsB = '2460' '92B' '696164'; // 2 46 09 2B 696 164
  final nirA = '$corpsA${cleNir(corpsA)}';
  final nirB = '$corpsB${cleNir(corpsB)}';

  String groupes(String nir, String sep) => [
        nir.substring(0, 1),
        nir.substring(1, 3),
        nir.substring(3, 5),
        nir.substring(5, 7),
        nir.substring(7, 10),
        nir.substring(10, 13),
        nir.substring(13),
      ].join(sep);

  Future<RedactResult> masque(String t) => Ecluse.redact(t);

  group('NIR corse lu avec une lettre d\'OCR, sans libellé', () {
    test('compact, « l » pour 1', () async {
      final v = nirA.replaceFirst('1', 'l');
      final t = 'Valeur relevée sur le scan : $v à vérifier.';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
      expect(r.maskedText, isNot(contains(v)));
      expect(r.warnings.any((w) => w.contains("lettres d'OCR")), isTrue);
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('groupes séparés par deux espaces, « O » pour 0, « B »', () async {
      final v = groupes(nirB, '  ').replaceFirst('0', 'O');
      final t = 'Le champ saisi porte $v dans la case de droite.';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
      expect(r.maskedText, isNot(contains('696')));
    });

    test('points et « I » pour 1, confiance 0,3 avec avertissement', () {
      final v = groupes(nirA, '.').replaceFirst('1', 'I');
      final r = detecteur.detect('Valeur : $v à vérifier.');
      expect(r, hasLength(1));
      expect(r.single.type, EntityType.nir);
      expect(r.single.confidence, 0.3);
      expect(r.single.provenance, Provenance.lectureOcr);
    });

    test('sexe 3 sans libellé : rien (règle « sexe 1 ou 2 » gardée)', () {
      final c = '3771' '02A' '736118';
      final v = ('$c${cleNir(c)}').replaceFirst('1', 'l');
      expect(detecteur.detect('Valeur : $v à vérifier.'), isEmpty);
    });

    test('clé fausse une fois relu : rien sans libellé', () {
      final fausse = '${nirA.substring(0, 13)}'
          '${(int.parse(nirA.substring(13)) % 97 + 1).toString().padLeft(2, '0')}';
      final v = fausse.replaceFirst('1', 'l');
      expect(detecteur.detect('Valeur : $v à vérifier.'), isEmpty);
    });

    test('suite plus longue : jamais une sous-suite', () {
      final v = groupes(nirA, ' ').replaceFirst('1', 'l');
      expect(detecteur.detect('Réf. 12 $v 34 notée.'), isEmpty);
    });

    test('un « A » ou un « B » ailleurs que derrière un 2 : rien', () {
      expect(
          detecteur
              .detect('Valeur : l 77 10 3A 736 118 ${cleNir(corpsA)} fin.'),
          isEmpty);
    });
  });

  group('clé fausse derrière un libellé, séparateurs multiples', () {
    test('NIR corse derrière un libellé : masqué aussi', () async {
      final v = groupes(nirA, '$nbsp$nbsp').replaceFirst('1', 'l');
      final r = await masque('NIR : $v noté.');
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
      expect(r.maskedText, isNot(contains('736')));
    });

    String fausseCle(String nir) =>
        '${nir.substring(0, 13)}${(int.parse(nir.substring(13)) % 97 + 1).toString().padLeft(2, '0')}';

    test('NIR : deux espaces insécables, avertissement « clé invalide »',
        () async {
      final n = fausseCle('219078405007588');
      final v = groupes(n, '$nbsp$nbsp').replaceFirst('1', 'l');
      final t = 'NIR : $v noté au dossier.';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
      expect(r.maskedText, isNot(contains('405')));
      expect(r.warnings.any((w) => w.contains('clé invalide')), isTrue);
      expect(r.warnings.any((w) => w.contains(n.substring(0, 5))), isFalse);
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('RPPS : tabulation entre groupes', () async {
      final v = '1139O9\t96O39'; // 11 caractères, clé de Luhn fausse
      final t = 'RPPS : $v enregistré.';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.rpps), hasLength(1));
      expect(r.maskedText, isNot(contains('96O39')));
    });

    test('IBAN : séparateurs doubles, clé fausse', () async {
      const v = 'FRI2  7O23  9I23  3759  O83O  B66I  373';
      final t = 'IBAN : $v à rapprocher.';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.iban), hasLength(1));
      expect(r.maskedText, isNot(contains('3759')));
    });

    test('libellé seul, ou suite de longueur fausse : rien', () {
      expect(detecteur.detect('NIR : non communiqué.'), isEmpty);
      expect(detecteur.detect('NIR : 2  19  O7  84  O5O  O75 notée.'), isEmpty);
      expect(detecteur.detect('RPPS : 1139O9  96O ensuite.'), isEmpty);
    });

    test('sans libellé, une clé fausse n\'est pas masquée par ce détecteur',
        () {
      expect(detecteur.detect('Valeur : 2  19  O7  84  O5O  O75  89 notée.'),
          isEmpty);
    });
  });
}
