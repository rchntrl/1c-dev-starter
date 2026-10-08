---
description: Project-specific locations for 1C configuration, extension, and external processing sources.
applyTo: '**'
---

# 1C source folder locations

Use these repository-root paths for local 1C source dumps:

- `conf/` — main configuration XML dump. The root dump file is `conf/Configuration.xml`; `.build/build-cf.bat` reads this folder.
- `extensions/<extension-name>/` — XML dump for a configuration extension. For example, extension `GS` is stored in `extensions/GS/`; `.build/build-cfe.bat` reads this folder.
- `external/<processing-name>.xml` — root XML file for an external data processor. Keep associated dump files and folders alongside it; `.build/build-ep.bat` reads this XML file.

These source dumps are local working files and are ignored by Git; do not add them to commits unless explicitly requested. The README files in these directories are tracked and explain their purpose. Build scripts and local build resources are under `.build/`.
