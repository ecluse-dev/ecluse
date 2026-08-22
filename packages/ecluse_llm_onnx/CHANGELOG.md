## 0.1.0 - 2026-08-11

- Scaffold initial.
- Squelette FFI ONNX Runtime (mêmes conventions que ecluse_ner_onnx).
- Sampler pur Dart : greedy + top_k + top_p (testé).
- Stub tokenizer (BPE simple + interface à câbler sur sentencepiece_ffi).
- Session ONNX = stub à implémenter selon la version d'onnxruntime cible.
- Un test d'intégration sans modèle valide le pipeline via `OnnxLlmClient.mock`.
