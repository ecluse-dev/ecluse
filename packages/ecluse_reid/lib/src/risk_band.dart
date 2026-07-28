/// Bande de risque de ré-identification (spec §3).
enum RiskBand { eleve, moyen, faible }

/// Seuils de la table des bandes de risque (spec §3) — **fixes**, distincts
/// du seuil d'acceptabilité configurable de `ReidLoop.threshold` (même s'ils
/// coïncident numériquement par défaut : 10).
const int bandeEleveMax = 10; // F < 10  -> ÉLEVÉ
const int bandeFaibleMin = 50; // F >= 50 -> FAIBLE

/// Seuils nommés (spec §3) — seul [thresholdStandard] est utilisé par
/// défaut ce jalon (pas d'UI de réglage, cf. §10).
const int thresholdStandard = 10;
const int thresholdRenforce = 20;
const int thresholdStrict = 50;

/// Bande de risque correspondant à une taille de classe d'équivalence [f]
/// (spec §3, table fixe — indépendante du seuil d'acceptabilité appelant).
RiskBand bandForF(double f) {
  if (f < bandeEleveMax) return RiskBand.eleve;
  if (f < bandeFaibleMin) return RiskBand.moyen;
  return RiskBand.faible;
}
