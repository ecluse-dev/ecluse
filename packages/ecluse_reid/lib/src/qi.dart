/// Types de quasi-identifiants pris en charge ce jalon (spec §1) : pas de
/// pathologie, pas de sexe — périmètre strict.
enum QiType { profession, lieu, age }

/// Un quasi-identifiant structuré (spec §2).
///
/// [value] encode soit une valeur brute (code commune INSEE, code
/// spécialité DREES, âge en années), soit — après une ou plusieurs
/// généralisations — une des valeurs sentinelles ci-dessous ([qiRetraitValue],
/// [professionToutesSpecialites], [professionnelDeSante], [lieuFrance]) ou
/// une plage `"lo-hi"` (pour un QI `age` généralisé en tranche).
///
/// [level] vaut 0 pour la valeur la plus précise et augmente à chaque
/// généralisation (échelle propre à chaque [QiType], voir `generalizer.dart`).
class Qi {
  const Qi(this.type, this.value, {this.level = 0});

  final QiType type;
  final String value;
  final int level;

  @override
  bool operator ==(Object other) =>
      other is Qi &&
      other.type == type &&
      other.value == value &&
      other.level == level;

  @override
  int get hashCode => Object.hash(type, value, level);

  /// Type, niveau et longueur de la valeur, jamais [value] : c'est une
  /// commune, un âge ou une profession tirés du texte, et un `toString` finit
  /// dans un journal ou une trace d'erreur de l'application (P2-170, voie F1
  /// de `agent/specs/P2-169.md`). Qui a besoin de la valeur lit [value].
  @override
  String toString() => 'Qi(${type.name}, niveau $level, ${value.length} car.)';
}

/// Valeur sentinelle : retrait complet d'un QI de la combinaison (dernier
/// palier des échelles âge et profession, spec §4).
const String qiRetraitValue = '';

/// Valeur sentinelle : « médecin, toute spécialité confondue » (palier 1 de
/// l'échelle profession — somme de `RaritySource.medecinsCount` sur les 14
/// codes du département).
const String professionToutesSpecialites = 'TOUTE_SPECIALITE';

/// Valeur sentinelle : « professionnel de santé, toute profession confondue »
/// (palier 2 de l'échelle profession — la somme ci-dessus + somme de
/// `RaritySource.professionCount` sur les 4 professions du département).
const String professionnelDeSante = 'PROFESSIONNEL_DE_SANTE';

/// Valeur sentinelle : « France entière » (dernier palier calculable de
/// l'échelle lieu ce jalon — région et grande zone ne sont pas agrégeables,
/// voir `lieu_population.dart`).
const String lieuFrance = 'FR';
