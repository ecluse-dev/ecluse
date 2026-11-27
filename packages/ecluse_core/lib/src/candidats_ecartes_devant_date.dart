import 'detectors/finess_detector.dart';
import 'detectors/iban_detector.dart';
import 'detectors/nir_detector.dart';
import 'detectors/rpps_detector.dart';
import 'digit_compaction.dart';
import 'entity.dart';

/// Un identifiant que la compaction a écarté parce qu'il finit au milieu d'une
/// date complète en chiffres (P2-309). Positions et type seulement : jamais la
/// valeur, qui ne doit apparaître ni dans un message ni dans un `toString`.
///
/// [finIdentifiant] (P2-312) : fin de la partie du candidat qui précède son
/// dernier groupe, c'est-à-dire des chiffres qui ne sont pas ceux de la date.
/// Un candidat écarté est souvent une lecture voisine d'un autre identifiant
/// (un FINESS de neuf chiffres lu en RPPS avec les deux premiers chiffres de la
/// date) : si une entité masque déjà cette partie, le signaler est un doublon.
final class CandidatEcarteDevantDate {
  const CandidatEcarteDevantDate(this.type, this.start, this.end,
      [int? finIdentifiant])
      : finIdentifiant = finIdentifiant ?? end;

  final EntityType type;
  final int start;
  final int end;
  final int finIdentifiant;
}

/// Candidats **valides** (clé juste) que `DigitCompaction` écarte parce que
/// leurs derniers chiffres ouvrent une date complète (« … 12/03/2024 »).
///
/// Pourquoi : cette garde est commune à tous les détecteurs et ne masque pas
/// ce qu'elle écarte. Un RPPS en deux groupes suivi d'une date part en clair
/// sans que rien ne le dise (principe du 26 novembre, point 0 : une garde ne
/// rend jamais une donnée silencieuse). Cette fonction ne change aucun
/// masquage : elle rend la différence entre la détection sans la garde et la
/// détection avec, pour les quatre identifiants à clé (NIR, RPPS, IBAN FR,
/// FINESS). Un candidat de clé fausse n'est jamais rendu : rien ne le
/// distingue d'un nombre ordinaire.
List<CandidatEcarteDevantDate> candidatsEcartesDevantDate(String text) {
  final sorties = <CandidatEcarteDevantDate>[];
  void compare(List<DetectedEntity> sans, List<DetectedEntity> avec) {
    final gardes = {for (final e in avec) (e.type, e.start, e.end)};
    for (final e in sans) {
      if (!gardes.contains((e.type, e.start, e.end))) {
        var fin = DigitCompaction.debutDernierGroupe(text, e.start, e.end);
        // Sans le blanc qui sépare l'identifiant de son dernier groupe.
        while (fin > e.start && text[fin - 1].trim().isEmpty) {
          fin--;
        }
        sorties.add(CandidatEcarteDevantDate(e.type, e.start, e.end, fin));
      }
    }
  }

  const nir = NirDetector();
  const rpps = RppsDetector();
  const iban = IbanFrDetector();
  compare(nir.detectSansGardeDate(text), nir.detect(text));
  compare(rpps.detectSansGardeDate(text), rpps.detect(text));
  compare(iban.detectSansGardeDate(text), iban.detect(text));
  compare(FinessDetector.detectSansGardeDate(text),
      FinessDetector.detectSansGardeDateReference(text));
  sorties.sort((a, b) => a.start - b.start);
  return sorties;
}
