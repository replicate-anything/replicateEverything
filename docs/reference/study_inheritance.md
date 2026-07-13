# Study extension / step inheritance helpers

Extension studies declare `paper.extends` and reference upstream steps
with `inherit:`. Inherited steps execute in the base study repository;
extension steps run locally and may read base `outputs/`.
