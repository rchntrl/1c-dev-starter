---
description: Project-specific locations for 1C configuration, extension, and external processing sources.
applyTo: '**'
---

# 1C source folder locations

Use these repository-root paths for local 1C source dumps:

- `conf/` — main configuration XML dump. The root dump file is `conf/Configuration.xml`; `.build/build-cf.ps1` and `.build/build-cf.bat` read this folder.
- `extensions/<extension-name>/` — XML dump for a configuration extension. For example, extension `GS` is stored in `extensions/GS/`; `.build/build-cfe.ps1` and `.build/build-cfe.bat` read this folder.
- `external/<processing-name>.xml` — root XML file for an external data processor. Keep associated dump files and folders alongside it; `.build/build-ep.ps1` and `.build/build-ep.bat` read this XML file.

These source dumps are local working files and are ignored by Git; do not add them to commits unless explicitly requested. The README files in these directories are tracked and explain their purpose. Build scripts and local build resources are under `.build/`.

## How to read build commands

The build scripts are simple wrappers around the 1C Designer command line. Their arguments are positional:

- `build-ep.ps1` or `build-ep.bat` `<external-processing-name> [platform-version]`
  - `<external-processing-name>` is the source XML filename without the `.xml` extension, for example `MyProcessor`.
  - The script looks for `external/MyProcessor.xml` in the repository root.
  - If the second argument is omitted, it uses the default platform version `8.3.24.1691`.
  - The generated artifact is saved in the project root as `<name>_YYYY-MM-DD.epf`.

For example:

```powershell
.\.build\build-ep.ps1 MyProcessor
.\.build\build-ep.bat MyProcessor
```

means:

- read the XML file `external\MyProcessor.xml`;
- create or reuse the local infobase under `.build\ib`;
- load it through 1C Designer to build the external processing;
- save the result as `MyProcessor_YYYY-MM-DD.epf` in the repository root.

Use the same pattern for other build scripts:

```powershell
.\.build\build-cf.ps1 1Cv8 8.3.24.1691
.\.build\build-cf.bat 1Cv8 8.3.24.1691
.\.build\build-cfe.ps1 GS 8.3.24.1691
.\.build\build-cfe.bat GS 8.3.24.1691
```

The first parameter is the logical name of the source artifact; the second optional parameter is the 1C platform version. If no version is provided, either script uses its default platform version.
