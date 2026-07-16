# Working notes

- Do NOT drive the watch simulator UI with synthetic mouse/CGEvent automation
  (face placement, gallery navigation, complication pickers). It is too slow and
  clunky. Dan handles all watch-face navigation himself — ask him to do the
  steps and tell you what he sees. Taking a `simctl io screenshot` of a state
  Dan has already set up is fine.
