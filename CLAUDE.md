# Working notes

- Do NOT drive the watch simulator UI with synthetic mouse/CGEvent automation
  (face placement, gallery navigation, complication pickers). It is too slow and
  clunky. Dan handles all watch-face navigation himself — ask him to do the
  steps and tell you what he sees. Taking a `simctl io screenshot` of a state
  Dan has already set up is fine.

- Before committing, run `just check` (tests, SwiftLint in strict mode, and a build); `just install-hooks` makes that a pre-commit hook. Lint rules live in `.swiftlint.yml` (`brew install swiftlint`). Fix new violations rather than adding `swiftlint:disable` comments.
