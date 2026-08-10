# AGENTS.md — ECOdyssey

Binding rules for any AI agent working in this repository (Claude Code, Antigravity, Cursor, Copilot, or otherwise). Read this before your first edit.

These rules are condensed from two review gates — `clean-code-guard` and `test-guard` — so they apply even where those skills are not installed. Work that violates them gets rejected at review.

---

## 1. What this project is

An iPhone/iPad mounted above a waste station. It watches items approach, tells the person which bin to use, and records what went where so the operator gets real waste-stream analytics.

Three bins today (`organic`, `recyclable`, `residual`), configurable to more without code changes.

**The design document is [`docs/REFACTOR_PLAN.md`](docs/REFACTOR_PLAN.md). It is normative.** If this file and that file disagree, the plan wins for architecture; this file wins for code style.

---

## 2. Architecture invariants

Violating any of these is a defect regardless of whether tests pass.

1. **One physical item produces exactly one count.** `ScanEvent`s are appended once per `TrackID`, guarded by `Set.insert(_:).inserted`. Never append from a per-frame code path. Never reintroduce a time-window deduplication heuristic — that was the original bug.

2. **`SortingKit` imports only `Foundation` and `CoreGraphics`.** No `UIKit`, `SwiftUI`, `Vision`, `AVFoundation`, `SwiftData`. If domain logic needs a framework type, the design is wrong — move the logic, not the import.

3. **Bin identity is `BinID`, a stable opaque string, never a display string.** Display name, colour, emoji and spoken phrase are presentation and may change freely. Persisted records store `BinID` only. An unknown `BinID` resolves to *retired*, never silently to another bin.

4. **The language model reports facts; the ruleset decides bins.** Perception returns materials and properties (`ItemPerception`). `SortingPolicy` maps those to a bin. Never let a model output a `BinID` directly — policy is site-specific and must stay data.

5. **Domain logic is pure and clock-free.** `WasteTracker` and `SortingPolicy` take timestamps and inputs as parameters and return values. No `Date()`, no I/O, no framework calls inside them. This is what makes them testable without mocks.

6. **Frames are never written to disk.** Only derived labels and counts persist. All perception is on-device.

7. **Perception runs once per track, never per frame.** An on-device LLM is a ~1–3 s operation. Presence tracking is the per-frame tier.

---

## 3. Build and test

```bash
# Compile the domain layer and its tests. Works with Command Line Tools alone.
cd Packages/SortingKit && swift build --build-tests \
  -Xswiftc -load-plugin-library \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib

# Run the tests, and everything else. Needs Xcode.
cd Packages/SortingKit && swift test    # or ⌘U in Xcode
xcodegen generate                        # after editing project.yml
swiftlint
```

**Xcode 27 is required, not optional.** Command Line Tools alone can *compile* `SortingKit` with the plugin flag above, but cannot *run* Swift Testing — the CLT `Testing.framework` is missing `lib_TestingInterop.dylib` — and `swiftlint` needs `sourcekitd` from Xcode. Anything touching the app target needs the iOS SDK regardless.

**Requirements:** Swift 6.4+, Xcode 27 (iOS 27 SDK). Deployment target iOS 26. `SWIFT_STRICT_CONCURRENCY: complete` is on — never silence a concurrency diagnostic with `@unchecked Sendable` or `nonisolated(unsafe)`. Those hide exactly the races the setting exists to catch.

---

## 4. Naming and layout

Names are the main thing a new teammate reads. A name that misdescribes its contents costs more than no name at all — this codebase has already shipped a `FoundationModelsMock.swift` containing neither a mock nor Foundation Models, and a `recyclingRatePercentage` that computed a diversion rate.

**Folders group by role, not by type.** Never create `Models/`, `Views/`, `Helpers/`, `Utils/`, `Managers/` or `Extensions/` — those say nothing about what the code does.

```
Packages/SortingKit/Sources/SortingKit/   pure domain, no frameworks
  Bins/         what bins exist and how items map to them (configuration)
  Perception/   what was seen — materials, confidence, keyword matching
  Policy/       seen-facts → bin decision
  Tracking/     item identity across frames; the count-once state machine
  Analytics/    summaries over recorded events
Sources/                                  app target: adapters and UI
  App/          composition root, lifecycle, station identity
  Capture/      camera session, preview, frame budget
  Perception/   Vision and Foundation Models adapters
  Scanning/     the coordinator that joins the tiers together
  Persistence/  SwiftData store, migration, CSV export
  Speech/       spoken output
  UI/           SwiftUI screens and components
```

**Files:** one primary type per file, filename exactly matching that type. Extensions on a foreign type use `Type+Purpose.swift` (`Color+Hex.swift`). A private helper type used only by the file's main type may share the file; two public types may not.

**Types:** nouns. Identifier wrappers are `<Thing>ID` and never carry display text.

**Methods:** commands are verbs (`ingest`, `announce`, `append`); queries are nouns or `is`/`has` predicates (`visibleTracks`, `isLargeEnough`). A method does not both mutate and answer an unrelated question.

**Banned unqualified:** `data`, `result`, `info`, `temp`, `value`, `item`, `obj`, `manager`, `helper`, `utils`, `handle*`, `process*`, `do*`. Qualify them (`rawRulesetData`, `decodedRuleset`) or find a real name.

---

## 5. Swift conventions

- Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- `@Observable` for view models; `@MainActor` on anything touching UI state. `@Observable` and `actor` are mutually exclusive — pick one. `ScanCoordinator` is `@MainActor` and observable; `CameraSession`, `VisionPresenceDetector` and `ScanEventStore` are actors.
- Value types (`struct`, `enum`) for domain. Reference types only where identity or framework interop demands it.
- `async`/`await` throughout. Do not wrap an API in `withCheckedThrowingContinuation` when it already has an async overload.
- **Pick one Vision API style per file.** `Sources/Perception/` uses the completion-handler `VN*` API throughout, because `VNTrackObjectRequest` has no modern equivalent and mixing the two styles in one pipeline reads worse than committing to one.
- Typed errors. No `NSError(domain:code:userInfo:)` with stringly-typed messages.

---

## 6. Code rules

### Never fake work
No hardcoded stand-ins for real computation, no fixture data in production paths, no `return .success` placeholders. The cautionary example: the pre-rebuild code stood a hardcoded array of three rectangles in for object detection for months, and a `DecisionCard` shipped reading "Decision Pending…" from a literal. **If you cannot implement something, fail loudly with an explicit unimplemented error and say what is missing.** Never weaken or skip a test to make a build green.

### Verify every API before calling it
Confirm the symbol exists in the installed SDK — read the generated interface or compile it. Do not write a call from memory or from a blog post. Foundation Models and Vision both changed recently; `docs/REFACTOR_PLAN.md` §12 lists the symbols still requiring verification against the iOS SDK.

### Errors propagate
Catch only the specific error you can recover from. Never `catch { }`, never `try?` to convert a real failure into a silent nil, never return an empty success from a catch block. The pre-rebuild classifier swallowed a failed segmentation into a hardcoded fallback box — do not repeat that shape.

### No speculative anything
No config flag, optional parameter, protocol, factory, or base class without a caller **today**. Data-driven bins are required by the spec, so they are not speculative; a `debugMode` flag would be. **One implementation means inline it.** The only justified seams in this project are `PerceptionEngine` (two real implementations: Foundation Models and Vision fallback) and the ruleset loader.

### Comments explain why, never what
Delete any comment that paraphrases the line below it. Delete `// 1.`, `// 2.`, `// Step 3` scaffolding. Keep comments where the reasoning is non-obvious: why a threshold is 0.3, why grease disqualifies cardboard.

### Size limits
Functions ≤ 20 lines, ≤ 4 parameters (introduce a config struct at 5), cyclomatic complexity ≤ 10, nesting ≤ 5.

### Read before you write
Read the file you are editing and one neighbour. Match its casing, import order, and error-handling style. Do not introduce a second pattern for something the project already does one way.

### Refactor and bug-fix are separate commits
A refactor preserves observable behaviour exactly. If you spot a bug while refactoring, flag it and fix it separately.

### Strip dead code before delivering
Unused imports, uncalled functions, unreachable branches, "just in case" exports. Delete them.

---

## 7. Test rules

**Ask of every test: what bug does this catch that no other test catches?** If there is no clear answer, do not write it.

1. **Test behaviour, not implementation.** Assert return values and observable state changes. Never assert that an internal function was called.
2. **Mock only at system boundaries** — camera, Vision, Foundation Models, SwiftData, clock. Never mock an internal type. In this project the domain is pure, so **the core suite should need essentially zero mocks**. If you are reaching for a mock in `SortingKitTests`, the design drifted — fix the design.
3. **One scenario per test; data-driven for variants.** Tests differing only by input value merge into one parameterized test.
4. **Never mock a value object.** Construct real `Bin`, `ItemPerception`, `Detection` instances. If construction is painful, add a builder — that is design feedback, not a reason to mock.
5. **Name tests for the scenario and outcome**, so the name reads like a requirement: `singleStationaryObjectAcross200FramesCountsOnce`, not `testTracker3`.
6. **Regression tests are sacred.** Tests reproducing a real bug carry a comment naming it and are never deleted. The `WasteTracker` count-once suite is in this category.
7. **Never test framework guarantees.** No tests that SwiftData persists, that `AVCaptureSession` configures, that `Bin.init` assigns its fields, or that SwiftUI renders.
8. **Model quality is not a unit test.** Evaluating whether Foundation Models identifies waste correctly is an offline evaluation against a labelled photo set. Never in CI — it is non-deterministic and will produce flaky failures.

---

## 8. Codebase navigation

If `graphify-out/` exists at the workspace root, a knowledge graph of this codebase has been generated. Query it before doing a broad manual search — it answers structural questions ("what depends on `SortingPolicy`?", "where does counting happen?") faster and more completely than grep. Regenerate it after large structural changes.

If it does not exist, use ordinary search. Do not fabricate graph results.

---

## 9. Scope discipline

Build what is asked. Do not add features, screens, flags, or abstractions that were not requested — over-eagerness is the most common way agent work gets rejected here.

`docs/REFACTOR_PLAN.md` §13 lists the explicit non-goals. Adding any of them counts as a defect: no bin editor UI, no backend or networking, no Core ML training, no gamification, no localization beyond `en-US` speech, no UI snapshot tests.

If the plan is ambiguous or turns out to be wrong, **say so and ask** rather than inventing an interpretation and building on it.

---

## 10. Self-check before you present work

- [ ] Does one item still produce exactly one count? Is there any new per-frame write path?
- [ ] Does `SortingKit` still import only `Foundation` and `CoreGraphics`?
- [ ] Any hardcoded value standing in for real computation?
- [ ] Every new API call verified against the SDK, not recalled?
- [ ] Any `catch { }`, bare `try?`, or swallowed error?
- [ ] Any new protocol, flag, or parameter with fewer than two real users today?
- [ ] Any comment that restates the code below it?
- [ ] Do the tests need mocks that the pure design should have made unnecessary?
- [ ] `swift test` green? `swiftlint` clean? No concurrency warnings?
- [ ] Did a refactor quietly change behaviour?

If any answer is wrong, fix it before presenting.
