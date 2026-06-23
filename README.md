# Écluse — Utilisez l'IA sans dévoiler qui vous êtes

Aujourd'hui, pour se servir de l'intelligence artificielle, il faut se livrer. Chaque prompt envoyé à OpenAI, Anthropic ou Google est une confession : votre nom, vos clients, vos patients, vos doutes, vos questions les plus intimes partent vers des serveurs que vous ne contrôlez pas, vers des modèles qui apprennent, profilent, recoupent et classent.

L'IA est trop utile pour qu'on s'en passe. Mais elle ne devrait pas exiger qu'on se déshabille pour s'en servir.

Écluse rend à chacun le pouvoir d'utiliser cette puissance sans abandonner son identité. C'est un sas entre vous et les modèles : ce qui vous rend identifiable est retenu, le reste passe. La machine travaille sur un texte qui a perdu son pouvoir de vous désigner — et vous récupérez une réponse intacte, sans que rien de sensible n'ait jamais quitté votre infrastructure.

## Ne pas masquer des mots. Protéger une personne.

Les outils existants détectent des « données personnelles » : un nom ici, un email là. C'est nécessaire mais insuffisant. Car une personne n'est pas trahie seulement par son nom — elle l'est par un faisceau d'indices. « Le chef de service de pneumologie d'un petit hôpital de l'Est, spécialiste d'une pathologie rare » : aucun identifiant direct, et pourtant une seule personne au monde correspond.

Écluse raisonne sur ce pouvoir d'identification, pas seulement sur les entités isolées. Il détecte les identifiants français avec une rigueur que les outils génériques n'ont pas — NIR, RPPS, FINESS, IBAN, validés structurellement. Mais il va plus loin : il généralise un lieu trop précis, signale les combinaisons qui ré-identifient, et mesure à quel point une personne reste reconnaissable une fois le texte nettoyé.

Nous ne prétendons pas rendre la ré-identification impossible — personne ne le peut honnêtement. Nous la rendons difficile, coûteuse, et surtout *mesurable* : vous savez ce que vous exposez avant de l'exposer.

## Le sas, concrètement

Vos prompts entrent. Les portes se ferment. Les entités sensibles sont retenues dans la chambre, les indices trop précis sont généralisés. Le reste passe au modèle. La réponse revient, les éléments réversibles sont réinjectés localement, et seulement là les portes de sortie s'ouvrent. Le journal d'audit est signé, horodaté, prêt pour votre AIPD.

Un canal, deux portes, un niveau d'eau maîtrisé.

## Principes non négociables

Open source au cœur, licence Apache 2.0, pas d'open-core piégé. Hébergement EU pour le cloud managé, sans exception. Neutralité totale entre les providers — OpenAI, Anthropic, Mistral, Gemini, ou votre Llama auto-hébergé. Mobile-first, parce que la confidentialité ne s'arrête pas au backend. Audit-first, parce que prouver est aussi important que protéger.

## Le pari

Les LLM sont trop utiles pour qu'on s'en passe. Le RGPD est trop réel pour qu'on l'ignore. L'AI Act est trop précis pour qu'on improvise. Et le droit de se servir d'une machine sans se faire cataloguer par elle est trop important pour qu'on l'abandonne. Il faut une couche entre les deux. Quelqu'un va la construire. On préfère que ce soit fait depuis la France, avec une obsession métier née dans la santé — là où une fuite ne se mesure pas en amende mais en vies.

## Ce qui vient ensuite

SDK Dart et Python d'abord, JS/TS dans la foulée. Détecteur français complet : NIR, RPPS, FINESS, IBAN, plaques, adresses, identifiants hospitaliers. Modèle NER local embarquable. Généralisation géographique et score de ré-identification. Dashboard d'audit AIPD. Routage on-device/cloud automatique. Tout en construction publique sur GitHub.

Si vous construisez avec un LLM en Europe et savez que votre situation actuelle ne tiendra pas un audit : suivez le projet. Si vous êtes en santé, finance, juridique ou RH et voulez être design partner : écrivez-nous.

**Le sas est ouvert.**

— L'équipe Écluse
