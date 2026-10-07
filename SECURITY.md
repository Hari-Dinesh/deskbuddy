# Security and privacy reports

Please do not include tokens, private photographs or chat content in public issues. Report non-sensitive reproduction steps through a GitHub issue; use GitHub private vulnerability reporting if the repository maintainer has enabled it.

Current releases are ad-hoc signed and not notarized. The installer verifies release checksums and bundle integrity, does not disable macOS security controls, and does not require sudo. Checksums downloaded from the same release do not provide independent publisher authentication.

The current runtime is local-only. Future integrations must be opt-in, keep tokens in Keychain, use least-required access and support disconnect. No provider is connected in v2.0.0.
