# native/

Emplacement des binaires ONNX Runtime natifs (non versionnés).

## Layout attendu

```
native/
├── windows-x64/
│   └── onnxruntime.dll
├── linux-x64/
│   └── libonnxruntime.so
└── macos-arm64/
    └── libonnxruntime.dylib
```

## Bootstrap

Voir `tool/download_onnxruntime.dart` (à créer) — script qui télécharge
la release ORT au bon endroit, cohérent avec le bootstrap Melos.

Version cible : ORT ≥ 1.18 (support Phi-3, Gemma, Qwen via
`Microsoft.ML.OnnxRuntime.GenAI` extension).
