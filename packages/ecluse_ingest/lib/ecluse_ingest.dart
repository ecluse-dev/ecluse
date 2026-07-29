/// Ingestion de fichiers texte natifs pour Écluse — fichier -> texte brut
/// fiable (offsets stables), avec refus explicite hors périmètre.
///
/// Formats v1 : `.txt`, `.md`, `.docx`. Le PDF (même texte) est hors
/// périmètre v1 et refusé explicitement, comme tout autre format.
///
/// Aucune détection ni pseudonymisation ici : le texte de [IngestedText]
/// est destiné à être transmis tel quel, sans transformation
/// intermédiaire, à `Ecluse.redact` (package `ecluse_redact`).
library;

export 'src/ingest_file.dart' show ingestFile, supportedExtensions;
export 'src/ingest_result.dart'
    show IngestFormat, IngestResult, IngestedText, IngestRefused;
