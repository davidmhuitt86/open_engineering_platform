# Signatures

Ed25519 signature block (PKG-005). `package.sig` is produced by `oep-package sign` (`@oep-exchange/signing`, WP-REP-004) and covers every file in this package outside `signatures/` itself. This package is signed by the demo publisher (`demo-publisher`); installing it into a Foundation Repository that has not explicitly trusted that publisher's certificate installs it as `UnknownPublisher`, not `Trusted` — see `oep_foundation`'s `oep trust` command.
