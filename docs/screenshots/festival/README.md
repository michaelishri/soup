# Festival theme review

SOUP-93 extends the approved onboarding identity into the default authenticated
app theme. New devices select Fruity / Festival / Light. The existing Soup,
Ocean, Grove and Mono choices and all saved version-1 preferences still work.
Settings → Use default selects a draft; Apply appearance saves it.

Festival combines a paper canvas, cobalt title panels, acid-yellow highlights,
Barlow Condensed headings and crisp navigation/cards. The dark option uses an
ink canvas and yellow focus accents. Video controls always use a dark theme so
text, timeline and actions stay readable over video in either app mode.

The featured panel sizes itself around the text. On TV the artwork sits beside
it; on phones it stacks above it. Copy is independent of artwork contrast.
The Blockbuster layout retains its billboard and rail arrangement, with the
same Festival colours and typography.

These are production widget captures with bundled fonts and original geometric
sample artwork drawn by the test fixture. Titles, account and library data are
fictional. No real library images or account details are committed.

| Screen | Light TV | Dark TV | Light phone | Dark phone |
| --- | --- | --- | --- | --- |
| Home | [View](home-light-tv.png) | [View](home-dark-tv.png) | [View](home-light-phone.png) | [View](home-dark-phone.png) |
| Details | [View](details-light-tv.png) | [View](details-dark-tv.png) | [View](details-light-phone.png) | [View](details-dark-phone.png) |
| Settings | [View](settings-light-tv.png) | [View](settings-dark-tv.png) | [View](settings-light-phone.png) | [View](settings-dark-phone.png) |

TV captures are 960×540 logical pixels; phone captures are 412×915. Settings is
shown at its initial scroll position. Interaction tests also exercise 320×640
with 130% text scaling, including applying changes without leaving Settings.

Regenerate from `apps/android`:

```sh
flutter test --no-pub --dart-define=UPDATE_FESTIVAL_SCREENSHOTS=true test/festival_theme_test.dart
```

Ordinary QA never rewrites screenshots.
