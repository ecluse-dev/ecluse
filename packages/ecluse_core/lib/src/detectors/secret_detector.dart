import '../detection/detector.dart';
import '../detection/detector_tier.dart';
import '../detection/normalized_text.dart';
import '../entity.dart';
import '../resolver.dart';

/// Détecteur de secrets techniques : clés d'API, jetons, clés privées,
/// chaînes de connexion avec mot de passe (spec : `agent/specs/P1-07-secrets.md`).
///
/// Un secret n'est pas une donnée personnelle, mais le risque est le même :
/// un texte collé dans un LLM tiers (code, journal, configuration) contient
/// parfois une clé qui donne accès à un système, et l'envoyer est une fuite
/// irréversible. Tier `pattern` : **aucun de ces formats n'a de clé de
/// contrôle** que nous vérifions ; la confiance est celle d'un motif (préfixe
/// + longueur fixes), comme pour le téléphone et l'email.
///
/// **Sources des formats** (préfixes non revérifiés du jour auprès des
/// fournisseurs : leurs documentations n'étaient pas accessibles à l'auteur,
/// la liste exige un entretien) :
/// - GitHub : préfixes `ghp_`/`gho_`/`ghu_`/`ghs_`/`ghr_` (36 caractères) et
///   `github_pat_` (82) — règles du projet gitleaks, source secondaire ;
/// - AWS : identifiants d'accès `AKIA`/`ASIA`/`ABIA`/`ACCA` + 16 caractères
///   base32 — gitleaks ;
/// - Google : `AIza` + 35 — gitleaks ;
/// - Stripe : `sk_live_`/`rk_live_` — gitleaks ; les clés de test ne sont
///   volontairement pas couvertes ;
/// - Slack : `xox[abprs]-` — gitleaks ;
/// - Anthropic : `sk-ant-api03-…` — gitleaks ;
/// - OpenAI : marqueur `T3BlbkFJ` (« OpenAI » en base64) des clés récentes,
///   et ancien format `sk-` + 48 alphanumériques — gitleaks / usage courant ;
/// - PEM : `-----BEGIN … PRIVATE KEY-----`, RFC 7468.
/// Les expressions ci-dessous sont **réécrites par nous** : la licence de
/// gitleaks n'a pas été lue sur le dépôt, aucun motif n'est recopié.
///
/// **Hors périmètre, volontairement** : détection par entropie (identifiants
/// de commit, hachages et UUID auraient le même aspect), clé secrète AWS nue
/// (40 caractères sans préfixe), mot de passe choisi par un humain.
///
/// Pas de `DigitCompaction` : un secret ne contient pas d'espaces à
/// neutraliser.
final class SecretDetector implements Detector {
  const SecretDetector();

  @override
  DetectorTier get tier => DetectorTier.pattern;

  @override
  String get name => 'secret';

  @override
  Future<List<DetectedEntity>> detect(NormalizedText text) async =>
      _detectSync(text.raw);

  /// Préfixe + longueur exacts.
  static const double _prefixConfidence = 0.95;

  /// Bloc PEM complet, de `BEGIN` à `END`.
  static const double _pemConfidence = 1.0;

  /// Bloc PEM sans ligne `END` (copie coupée) : masqué jusqu'à la fin du
  /// corps base64 plutôt que laissé en clair.
  static const double _pemTruncatedConfidence = 0.8;

  /// `utilisateur:motdepasse` d'une URL : forme moins discriminante.
  static const double _connectionConfidence = 0.7;

  /// Un secret ne commence ni ne finit au milieu d'un mot.
  static const String _before = r'(?<![A-Za-z0-9_])';
  static const String _after = r'(?![A-Za-z0-9_])';

  static final List<RegExp> _prefixed = [
    // GitHub : jetons classiques et à granularité fine.
    RegExp('${_before}gh[pousr]_[A-Za-z0-9]{36}$_after'),
    RegExp('${_before}github_pat_[A-Za-z0-9_]{82}$_after'),
    // AWS : identifiant d'accès (pas la clé secrète, sans préfixe).
    RegExp('$_before(?:AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}$_after'),
    // Google.
    RegExp('${_before}AIza[A-Za-z0-9_\\-]{35}$_after'),
    // Stripe : clés de production uniquement.
    RegExp('$_before(?:sk|rk)_live_[A-Za-z0-9]{10,99}$_after'),
    // Slack.
    RegExp('${_before}xox[abprs]-[0-9]{8,}-[A-Za-z0-9\\-]{8,}$_after'),
    // Anthropic.
    RegExp(
        '${_before}sk-ant-(?:api|admin)[0-9]{2}-[A-Za-z0-9_\\-]{80,}$_after'),
    // OpenAI : format récent (marqueur fixe), puis ancien format.
    RegExp('${_before}sk-(?:(?:proj|svcacct|admin)-)?'
        '[A-Za-z0-9_\\-]{20,}T3BlbkFJ[A-Za-z0-9_\\-]{20,}$_after'),
    RegExp('${_before}sk-[A-Za-z0-9]{48}$_after'),
  ];

  /// Bloc complet : le corps (≥ 64 caractères) peut contenir de vrais sauts
  /// de ligne ou des `\n` littéraux (JSON). Borné pour éviter tout
  /// retour arrière coûteux sur un texte volumineux.
  static final RegExp _pem = RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]{64,16384}?'
    r'-----END [A-Z ]*PRIVATE KEY-----',
  );

  /// Bloc sans `END` : entête + corps base64 (avec espaces, sauts de ligne
  /// et `\` des `\n` littéraux). Le plus long gagne dans `resolveOverlaps`.
  static final RegExp _pemTruncated = RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[A-Za-z0-9+/=\s\\]{64,16384}',
  );

  /// `scheme://utilisateur:motdepasse@hôte` — le groupe 1 est masqué.
  /// Mot de passe obligatoire et non vide.
  static final RegExp _connection = RegExp(
    r'(?:postgres(?:ql)?|mysql|mariadb|mongodb(?:\+srv)?|rediss?|amqps?'
    r'|https?|ftp)://([^\s:/@]+:[^\s/@]+)@',
    caseSensitive: false,
  );

  static List<DetectedEntity> _detectSync(String raw) {
    final results = <DetectedEntity>[];

    void add(int start, int end, double confidence) => results.add(
          DetectedEntity(
            type: EntityType.secret,
            start: start,
            end: end,
            value: raw.substring(start, end),
            confidence: confidence,
          ),
        );

    for (final pattern in _prefixed) {
      for (final m in pattern.allMatches(raw)) {
        add(m.start, m.end, _prefixConfidence);
      }
    }
    for (final m in _pem.allMatches(raw)) {
      add(m.start, m.end, _pemConfidence);
    }
    for (final m in _pemTruncated.allMatches(raw)) {
      add(m.start, m.end, _pemTruncatedConfidence);
    }
    for (final m in _connection.allMatches(raw)) {
      // Le groupe 1 suit immédiatement « :// ».
      final userinfo = m.group(1)!;
      final start = m.start + m.group(0)!.indexOf('://') + 3;
      add(start, start + userinfo.length, _connectionConfidence);
    }

    // Le PEM tronqué recouvre un PEM complet : garder le plus long, comme
    // le fait le moteur, pour qu'un même détecteur ne renvoie pas deux
    // entités qui se chevauchent.
    return resolveOverlaps(results);
  }
}
