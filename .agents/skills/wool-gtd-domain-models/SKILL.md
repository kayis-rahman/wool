---
name: wool-gtd-domain-models
description: >
  Load before adding or changing Wool persisted models, SwiftData schema,
  relationships, model invariants, or schema migration.
user-invocable: true
---

# wool-gtd-domain-models

Trigger: load before adding or changing Wool persisted models, SwiftData schema,
relationships, model invariants, or schema migration.

In scope: Domain/Models layouts, @Model defaults, raw-value enum state, typed
computeds, validation helpers, VersionedSchema/migration changes, and
WoolModelContainer test cases.

Out of scope: backend client DTOs, SwiftUI view structure, and unrelated app
integrations.

## Core rules

1. Put persisted concepts under `Domain/Models` and keep schema ownership in
   `WoolSchema.swift`.
2. Store enum state through a `*RawValue: String` property plus computed typed
   accessor.
3. Prefer strong, defaulted `@Model final class` initializers and explicit
   relationships.
4. Validate and normalize before persistence.
