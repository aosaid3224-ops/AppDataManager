# Spider — Stable Core + Compatibility Engine Policy

## Status

This policy is effective for all future IPA Installer Pro changes. It is a release gate, not an app-specific workaround.

## Non-negotiable rule

The currently working Standard Path is protected. A new compatibility change must never modify, weaken, or reroute the Standard Path merely because one IPA fails.

A failure with no proven cause is classified as `UNKNOWN_PROFILE`. It produces diagnostic evidence and does not change installation, signing, registration, filesystem, or launch behavior.

## Pipeline contract

```text
IPA
  -> structural facts
  -> Application Profile
  -> Compatibility Classifier
  -> Compatibility Decision
  -> selected strategy
  -> install
  -> verify installation
  -> register
  -> verify registration
  -> launch validation
  -> result
```

The classifier is driven by facts, not Bundle ID, application name, or a special-case branch.

## Application Profile facts

The profile may contain only observed facts: Mach-O type and slices, arm64 evidence, minimum iOS, load commands, linked libraries, embedded frameworks, dylibs, extensions, nested bundles, rpaths, source entitlements, signature characteristics, bundle topology, runtime observations, and failure history. Facts are separate from decisions and are reusable across applications.

## Compatibility Profile contract

Each profile must declare:

| Component | Requirement |
|---|---|
| Detection rules | Deterministic predicates over Application Profile facts |
| Installation strategy | A separately owned strategy; no implicit change to Standard Path |
| Verification strategy | Explicit postcondition checks, not merely filesystem presence |
| Launch validation | A defined runtime test and evidence boundary |
| Rollback strategy | A first-class rollback sequence with verification |
| Evidence | OperationLog/crash/runtime facts that justified the profile |
| Scope | A structural class, never a Bundle ID or app name |

## Classification states

`STANDARD_PROFILE` is selected only when no special structural or historical evidence requires another strategy. `SPECIAL_PROFILE` is selected only when detection rules match observed facts. `UNKNOWN_PROFILE` is selected when evidence is incomplete or contradictory; the engine must not guess.

## Regression gates

Before a compatibility profile can affect production:

1. The target failure must be reproducible and its cause must be evidenced.
2. The new profile must make the target pass its installation, registration, and launch tests.
3. Every registered Standard regression case must still pass unchanged.
4. Signing, entitlements, registration ordering, filesystem topology, and rollback must show no unintended differences.
5. A forced pre-registration failure must produce no registration.
6. A post-registration failure must produce verified unregister/rollback evidence.
7. If any baseline case regresses, the profile is rejected and the prior release remains the safe release.

## Current attached evidence: LockedFolder

The attached log proves:

- `spider-bundle-graph` succeeded.
- Post-sign verification succeeded.
- The transaction failed at `verify installation before registration` because six embedded dylibs failed the current readability/executable verification: `FixCrash2.dylib`, `NOADS.dylib`, `FixCrash1.dylib`, `LocalIAPStore14.dylib`, `AhmadDev.dylib`, and `libsubstrate.dylib`.
- No later registration event appears in the log. The transaction guard therefore prevented registration after a failed verification.
- The log does not yet prove a launch attempt or a registration rollback for this transaction.

This is sufficient to classify the IPA as an evidence-backed candidate for a future structural class such as `UNKNOWN_EMBEDDED_DYLIB`, but it is not sufficient to authorize a compatibility fix. The next evidence must capture mode, UID/GID, readability, executable-bit, Mach-O signature facts, and dependency/load-command facts for each failing dylib, then compare them with a working IPA in the same structural class.

## Release rule

No Compatibility Profile is connected to the production path until its detection, strategy, verification, launch, rollback, and regression tests are all present. Until then, the current published release remains the reference behavior, and a new failing IPA is investigated rather than patched by guesswork.
