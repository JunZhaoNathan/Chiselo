# Chiselo 0.1.23

This release strengthens the public open-source project and the safety of its
delivery workflow.

- Changed the source license to Apache-2.0 and documented the separate Chiselo
  trademark boundary for forks and services.
- Added static-safe HTML export protection against scripts, remote resources,
  event handlers, refresh redirects, and unsandboxed nested frames unless the
  user explicitly chooses trusted dynamic compatibility.
- Added export runtime-safety regression coverage.
- Stabilized the deck gesture regression against WebKit startup timing.
- Made all PPTX design checks work on CI runners without `rg`.
- Reorganized the public README, documentation index, contribution rules, and
  GitHub repository collaboration settings.

This Apple Silicon macOS package is signed with Developer ID, notarized, and
stapled. Sparkle update metadata is published to the Chiselo R2 feed.
