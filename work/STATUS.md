# Validation

The public build runs the complete offline Lua regression suites, syntax checks,
TOC/version checks and runtime package size/file checks via `Build.ps1`.
The runtime is limited to 2 MiB uncompressed. Only explicitly allowed runtime files
are packaged. Public release preparation preserves the accepted gameplay and camera code.

Offline checks do not prove live-client rendering, camera feel, taint behavior or
provider availability. Report those separately when validating a release.
