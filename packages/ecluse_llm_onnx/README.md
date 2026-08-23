# ecluse_llm_onnx

Implémentation `LlmClient` (voir `ecluse_llm`) via **ONNX Runtime** en FFI Dart.

## Cible

- Modèles décodeurs autoregressifs de taille 1–4B, exportés en ONNX,
  quantifiés INT4/INT8. Testé (roadmap) sur :
  - Qwen 2.5 3B Instruct (Apache 2.0)
  - Gemma 3 4B Instruct
  - Phi-3.5-mini (ONNX INT4 fourni par Microsoft)
- Exécution CPU (fallback) ou GPU/DirectML (Windows) / CUDA / CoreML.

## Statut

**Scaffold.** Trois composants sont câblés mais non fonctionnels :

- `session.dart` : ouverture d'une session ORT. Les bindings FFI sont
  esquissés — à générer proprement via `ffigen` sur l'en-tête
  `onnxruntime_c_api.h` de la version d'ORT retenue.
- `tokenizer.dart` : interface `Tokenizer` + stub `WhitespaceTokenizer`.
  À remplacer par un binding SentencePiece (partagé avec `ecluse_ner_onnx`)
  ou une implémentation BPE pure Dart selon le modèle.
- `generation.dart` : boucle de génération autoregressive.

Ce qui **fonctionne dès le scaffold** :

- `sampler.dart` : greedy + top_k + top_p, entièrement en Dart, testé.
- `OnnxLlmClient.mock(...)` : implémentation `LlmClient` factice pour
  tests d'intégration sans modèle.

## Convention FFI

Aligné sur `ecluse_ner_onnx` :

- Binaires natifs sous `native/` (à télécharger au bootstrap Melos, non
  versionnés).
- Wrapper ORT dans une classe `OnnxSession` qui gère `OrtEnv`, `OrtSession`,
  `OrtRunOptions` et les `Value` d'entrée/sortie.
- Toute allocation `calloc`/`malloc` est appariée à un `free` dans un
  `try/finally`.

## Prochain jalon

1. Choisir la version ORT (recommandé : 1.18+ pour le support GenAI Extensions).
2. Générer les bindings via `ffigen` (config à ajouter dans
   `ffigen.yaml`).
3. Câbler un premier appel `session.run` avec un modèle Phi-3.5-mini
   ONNX INT4 pour valider le pipeline bout à bout.
4. Ajouter un KV cache pour éviter de recomputer le prompt à chaque token.

## Non-buts

- Pas de streaming côté API — la réponse est retournée d'un bloc, comme
  le NER.
- Pas de fine-tuning intégré. Les modèles sont chargés en lecture seule.
- Pas de gestion multi-modale.
