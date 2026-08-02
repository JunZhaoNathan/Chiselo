# Security Policy

Chiselo is an early macOS preview app that opens and renders local HTML files inside WKWebView.

## Supported Versions

Only the latest public release is supported for security reports.

## Reporting A Vulnerability

Please do not open public issues for vulnerabilities involving arbitrary file access, unsafe HTML loading, export data leaks, or malicious document behavior.

Instead, contact the maintainer privately through GitHub profile contact information or a private channel listed in the repository once published.

Include:

- Chiselo version or commit;
- macOS version;
- reproduction steps;
- whether the issue requires a malicious HTML file;
- expected vs actual behavior;
- any crash logs or sample files that are safe to share.

## Current Security Model

- Chiselo is intended for local files chosen by the user.
- Chiselo should not be used as a browser for untrusted websites.
- HTML opens in static safety mode. Source scripts, inline event handlers, JavaScript URLs, refresh redirects, and nested iframe scripts are made inert before rendering; the editing iframe still permits Chiselo's own event-driven editing code.
- Dynamic compatibility is an explicit per-document opt-in for trusted HTML and allows browser-side JavaScript and forms inside the editing iframe.
- Static safety does not block passive CSS, image, font, or other resource loading; do not treat it as a complete untrusted-content sandbox.
- Do not open confidential files from unknown sources.

This security model will be tightened as the project matures.
