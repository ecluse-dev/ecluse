import 'audit_entry.dart';
import 'audit_verifier.dart';

/// Un moteur rencontré dans le journal, dans l'ordre de sa première
/// apparition (P2-202, recommandations de `agent/specs/P2-198.md`).
///
/// Ni compte ni rang d'entrée : ils donneraient le nombre d'entrées de chaque
/// version, que le masquage de faible effectif (P2-26) retrouverait par
/// soustraction. [rang] est l'ordre de première apparition (1, 2, …) ; [depuis]
/// est le **jour** (`AAAA-MM-JJ`) de la première entrée, jamais la minute.
final class MoteurExport {
  const MoteurExport({
    required this.rang,
    required this.moteur,
    required this.depuis,
  });

  /// Ordre de première apparition, à partir de 1.
  final int rang;

  /// Valeur de `engine` : version du moteur et noms des détecteurs actifs.
  final String moteur;

  /// Jour de la première entrée portant ce moteur.
  final String depuis;

  Map<String, Object> toJson() =>
      {'rang': rang, 'moteur': moteur, 'depuis': depuis};
}

/// Agrégat factuel d'un journal d'audit, à reprendre dans un registre des
/// activités de traitement ou une analyse d'impact (P2-15, spec P2-09).
///
/// C'est une **matière première**, pas un registre : le journal ne sait ni qui
/// est concerné, ni la finalité, ni le destinataire (le fournisseur du LLM), ni
/// la durée de conservation. Voir [mentions], toujours présentes.
///
/// Les comptes inférieurs au [seuil] sont remplacés par « moins de N » (un
/// agrégat de très faible effectif se confond avec une entrée : comptes et
/// horodatage rapproché peuvent relier une entrée à une personne,
/// `LIMITES.md` § 8). Un compte nul reste `0`. Le seuil est **provisoire**.
///
/// **Recoupement** (P2-26) : un compte masqué ne doit pas se retrouver par
/// soustraction. Le total des opérations (et le nombre d'entrées de la chaîne,
/// qui est la même quantité) n'est donc communiqué que si aucune opération n'est
/// masquée ; et si un seul code de refus est masqué alors que le nombre de
/// refus est exact, le plus petit autre code est masqué aussi, sous la mention
/// [nonCommunique] (« moins de N » serait faux : il peut valoir N ou plus).
final class AuditExport {
  const AuditExport._({
    required this.seuil,
    required this.operations,
    required this.parOperation,
    required this.entites,
    required this.refus,
    required this.moteurs,
    required this.changementsDeMoteur,
    required this.premiere,
    required this.derniere,
    required this.periodeAuJour,
    required this.verification,
  });

  /// Seuil de faible effectif utilisé.
  final int seuil;

  /// Nombre d'entrées : entier, ou « moins de N ».
  final Object operations;

  /// Entrées par opération (`redact`, `ingest_refused`).
  final Map<String, Object> parOperation;

  /// Entités détectées par type (`EntityType.name`).
  final Map<String, Object> entites;

  /// Refus par code de motif.
  final Map<String, Object> refus;

  /// Valeurs distinctes de `engine` rencontrées, **dans l'ordre de première
  /// apparition** (pas alphabétique : `0.10.0` suit `0.2.0`), avec rang et jour.
  final List<MoteurExport> moteurs;

  /// Nombre de fois où `engine` diffère de celui de l'entrée précédente. La
  /// comparaison porte sur la chaîne entière (version et détecteurs) : un
  /// retour à une version antérieure compte pour un changement de plus.
  final int changementsDeMoteur;

  /// Première et dernière entrée : à la minute, ou au jour quand le nombre
  /// d'opérations est inférieur au seuil. `null` pour un journal vide.
  final String? premiere;
  final String? derniere;
  final bool periodeAuJour;

  /// Résultat de [AuditVerifier.verify] sur les entrées fournies.
  final AuditVerification verification;

  /// Mentions d'honnêteté : présentes dans toute sortie, y compris pour un
  /// journal vide.
  List<String> get mentions => mentionsAudit;

  Map<String, Object?> toJson() => {
        'version': 2,
        'seuil': seuil,
        'operations': operations,
        'par_operation': parOperation,
        'entites': entites,
        'refus': refus,
        'moteurs': [for (final m in moteurs) m.toJson()],
        'changements_de_moteur': changementsDeMoteur,
        'periode': {
          'debut': premiere,
          'fin': derniere,
          'au_jour': periodeAuJour,
        },
        'chaine': switch (verification) {
          AuditIntact() => {'etat': 'intacte', 'entrees': operations},
          AuditBroken(:final index, :final kind) => {
              'etat': 'rompue',
              'rang': index,
              'nature': kind.name,
            },
        },
        'mentions': mentions,
      };

  /// Rendu lisible, mentions d'honnêteté en tête.
  String toTexte() {
    final b = StringBuffer()
      ..writeln('Export du journal d\'audit Écluse (matière première, '
          'pas un registre)')
      ..writeln();
    for (final m in mentions) {
      b.writeln('- $m');
    }
    b
      ..writeln()
      ..writeln('Entrées : $operations')
      ..writeln('Période : ${premiere ?? 'aucune entrée'}'
          '${derniere != null && derniere != premiere ? ' à $derniere' : ''}'
          '${periodeAuJour ? ' (au jour : faible effectif)' : ''}');
    _liste(b, 'Opérations', parOperation);
    _liste(b, 'Entités détectées par type', entites);
    _liste(b, 'Refus par code de motif', refus);
    if (moteurs.isEmpty) {
      b.writeln('Moteurs : aucun');
    } else {
      b.writeln('Moteurs (ordre de première apparition) :');
      for (final m in moteurs) {
        b.writeln('  ${m.rang}. ${m.moteur} (depuis le ${m.depuis})');
      }
    }
    if (changementsDeMoteur >= 1) {
      b.writeln('Le moteur a changé $changementsDeMoteur fois pendant la '
          'période.');
    }
    switch (verification) {
      case AuditIntact():
        b.writeln('Chaîne : intacte sur $operations entrée(s) ; la troncature '
            'en fin de journal n\'est pas détectée.');
      case AuditBroken(:final index, :final kind):
        b.writeln('Chaîne : rompue à l\'entrée $index (${kind.name}).');
    }
    return b.toString();
  }

  static void _liste(StringBuffer b, String titre, Map<String, Object> m) {
    b.writeln('$titre :');
    if (m.isEmpty) {
      b.writeln('  (aucun)');
      return;
    }
    for (final k in m.keys.toList()..sort()) {
      b.writeln('  $k : ${m[k]}');
    }
  }
}

/// Valeur d'un compte exact retenu pour empêcher de retrouver, par différence
/// avec un total, un compte voisin masqué.
const String nonCommunique = 'non communiqué (recoupement)';

/// Mentions d'honnêteté de l'export (spec P2-09 § 6).
const List<String> mentionsAudit = [
  'Cet export n\'atteste pas la conformité au RGPD et ne remplace ni un '
      'registre des activités de traitement ni une analyse d\'impact.',
  'Les comptes sont ceux des entités détectées, pas des données présentes : un '
      'type jamais détecté n\'apparaît pas, ce qui ne signifie pas qu\'il n\'a '
      'pas été traité.',
  'Il ne dit rien du traitement après Écluse (fournisseur du LLM, '
      'conservation chez lui).',
  'La vérification de chaîne ne détecte ni la troncature en fin de journal ni '
      'une réécriture complète ; l\'horodatage vient de l\'horloge de '
      'l\'appareil.',
  'Un changement de version du moteur ne change pas les garanties du journal, '
      'mais les détections avant et après ne sont pas comparables.',
  'La nature juridique de ce journal n\'est pas établie (avis d\'un DPO '
      'attendu) : ne pas le publier comme une preuve.',
];

/// Construit un [AuditExport].
abstract final class AuditExporter {
  /// Agrège [entries]. Lève [ArgumentError] si [seuil] est inférieur à 1.
  /// Ne modifie rien et n'écrit nulle part.
  static AuditExport agrege(Iterable<AuditEntry> entries, {int seuil = 5}) {
    if (seuil < 1) throw ArgumentError.value(seuil, 'seuil', 'au moins 1');
    final liste = entries.toList();
    final verification = AuditVerifier.verify(liste);

    final parOperation = <String, int>{};
    final entites = <String, int>{};
    final refus = <String, int>{};
    final moteurs = <String, String>{}; // moteur -> jour de première entrée
    var changements = 0;
    String? precedent;
    for (final e in liste) {
      parOperation[e.op.wire] = (parOperation[e.op.wire] ?? 0) + 1;
      for (final c in e.counts.entries) {
        entites[c.key] = (entites[c.key] ?? 0) + c.value;
      }
      final r = e.reason;
      if (r != null) refus[r.wire] = (refus[r.wire] ?? 0) + 1;
      moteurs.putIfAbsent(e.engine, () => e.ts.substring(0, 10));
      if (precedent != null && precedent != e.engine) changements++;
      precedent = e.engine;
    }

    final auJour = liste.isNotEmpty && liste.length < seuil;
    String? jour(String ts) => auJour ? ts.substring(0, 10) : ts;
    final opsMasquees = _masqueTout(parOperation, seuil);
    // Le total des opérations n'est exact que si aucune opération n'est
    // masquée : sinon `total - autres` redonnerait le compte masqué.
    final Object operations = liste.isNotEmpty && liste.length < seuil
        ? 'moins de $seuil'
        : opsMasquees.values.any((v) => v is String)
            ? nonCommunique
            : liste.length;
    final refusMasques = _masqueTout(refus, seuil);
    if (opsMasquees['ingest_refused'] is int &&
        refusMasques.values.whereType<String>().length == 1) {
      final exacts = refusMasques.entries.where((e) => e.value is int).toList()
        ..sort((a, b) {
          final c = (a.value as int).compareTo(b.value as int);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      if (exacts.isNotEmpty) refusMasques[exacts.first.key] = nonCommunique;
    }
    return AuditExport._(
      seuil: seuil,
      operations: operations,
      parOperation: opsMasquees,
      entites: _masqueTout(entites, seuil),
      refus: refusMasques,
      moteurs: [
        for (final (i, m) in moteurs.entries.indexed)
          MoteurExport(rang: i + 1, moteur: m.key, depuis: m.value),
      ],
      changementsDeMoteur: changements,
      premiere: liste.isEmpty ? null : jour(liste.first.ts),
      derniere: liste.isEmpty ? null : jour(liste.last.ts),
      periodeAuJour: auJour,
      verification: verification,
    );
  }

  static Object _masque(int n, int seuil) =>
      n > 0 && n < seuil ? 'moins de $seuil' : n;

  static Map<String, Object> _masqueTout(Map<String, int> m, int seuil) => {
        for (final e in m.entries)
          if (e.value > 0) e.key: _masque(e.value, seuil),
      };
}
