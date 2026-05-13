# Écluse — Le sas entre vos prompts et les LLM

Chaque jour, des milliers de développeurs européens envoient leurs données les plus sensibles à OpenAI, Anthropic et Google. Ils savent que c'est un problème. Ils n'ont pas le temps de le résoudre proprement. Le RGPD attendra demain. L'AI Act attendra le contrôle.

Nous construisons Écluse pour que « demain » arrive avant le contrôle.

## Le problème n'est pas la détection. C'est l'orchestration.

Microsoft Presidio détecte les PII. C'est utile, mais c'est l'équivalent d'un détecteur de fumée vendu sans le reste de l'installation électrique. Ce qui manque : décider quoi router en local versus en cloud, signer l'audit que votre DPO exigera, gérer la ré-identification côté client sans jamais exposer la map, fonctionner aussi sur mobile, prouver la conformité quand la CNIL frappera à la porte.

C'est ce qu'on construit.

## Écluse est un sas.

Vos prompts entrent. Les portes se ferment derrière. Les entités sensibles — noms, NIR, RPPS, IBAN, adresses, identifiants — sont retenues dans la chambre. Le reste passe au LLM. La réponse revient, les entités sont réinjectées localement, et seulement là les portes de sortie s'ouvrent. Rien de sensible n'a quitté votre infrastructure. Le journal d'audit est signé, horodaté, prêt pour votre AIPD.

Un canal, deux portes, un niveau d'eau maîtrisé. C'est toute la métaphore, et c'est tout le produit.

## Principes non négociables

Open source au cœur, licence Apache 2.0, pas d'open-core piégé. Hébergement EU pour le cloud managé, sans exception. Neutralité totale entre les providers — OpenAI, Anthropic, Mistral, Gemini, ou votre Llama auto-hébergé. Mobile-first, parce que la confidentialité ne s'arrête pas au backend. Audit-first, parce que prouver est aussi important que protéger.

## Le pari

Les LLM sont trop utiles pour qu'on s'en passe. Le RGPD est trop réel pour qu'on l'ignore. L'AI Act est trop précis pour qu'on improvise. Il faut une couche entre les deux. Quelqu'un va la construire. On préfère que ce soit fait depuis la France, avec une obsession métier née dans la santé — là où une fuite ne se mesure pas en amende mais en vies.

## Ce qui vient ensuite

SDK Dart et Python d'abord, JS/TS dans la foulée. Détecteur français complet : NIR, RPPS, FINESS, IBAN, plaques, adresses, identifiants hospitaliers. Modèle NER local embarquable. Dashboard d'audit AIPD. Routage on-device/cloud automatique. Tout en construction publique sur GitHub.

Si vous construisez avec un LLM en Europe et savez que votre situation actuelle ne tiendra pas un audit : suivez le projet. Si vous êtes en santé, finance, juridique ou RH et voulez être design partner : écrivez-nous.

**Le sas est ouvert.**

— L'équipe Écluse
