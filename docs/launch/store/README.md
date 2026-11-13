# Play Store graphics

- `feature_graphic_1024x500.png` — official Play feature graphic, 1024×500, using the 3D house icon.
- `01_*.png` … `08_*.png` — 1080×1920 marketing frames with a short English caption and the full app UI (no chrome cropped).
- `raw/` — the same screens, uncaptioned, from the Flutter widget harness. Use these if Play Console prefers a plain device screenshot.

Captions:

1. Explore a UK neighbourhood
2. Practise everyday conversations
3. English for UK nursery work
4. Walk in and open a book
5. Walk the library and open a book
6. Practise for Life in the UK — not the official test
7. Grammar from beginner to advanced
8. Practice forms, with official site links

Regenerate from `app/` with `STORE_SHOTS=1 flutter test test/store_screenshots_test.dart` (after a local-only SDK floor if the box Dart is 3.13.5; never commit a lowered `sdk` pin), then `python3 app/tool/make_launch_kit.py --repo .`. The MaterialIcons font is loaded in the test so toolbar icons are not squares. The test is skipped unless `STORE_SHOTS=1`.
