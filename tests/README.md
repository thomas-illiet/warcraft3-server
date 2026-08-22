# Tests

`Manage-WarcraftRealms.Tests.ps1` covers parsing, validation, CRUD, selection, reset, malformed values, in-memory rollback, `-WhatIf` and the absence of backup files. `Repository.Tests.ps1` enforces the source-only and Compose hardening policies.

The two shell smoke tests start the portable Linux server and the rootless read-only container. They verify a live port, runtime identity, immutable root filesystem and persistent volume data.
