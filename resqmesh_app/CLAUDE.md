# 烽傳 IgniRelay — resqmesh_app

Flutter app for the IgniRelay disaster-mesh project.

Governance rules — the 6 architecture layer rules, facade access pattern,
facade locations, and the no-singleton / no-rawEvents / 500-line rules — live
in the canonical repo-root **`../CLAUDE.md`**. They are kept in one place to
avoid divergent copies.

This directory is the subject of those rules: every path they reference
(`lib/ui/**`, `lib/app/**`, `lib/platform/**`, `tool/check_layers.dart`, the
`ui/screens/map/map_screen_controller.dart` reference pattern) is relative to
here.
