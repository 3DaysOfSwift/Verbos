# Verbos: Learn Spanish validation

Checked 22 October 2026 with Xcode 26.2 / Swift 6.2.3.

Branding update: both build configurations now display “Verbos: Learn Spanish”; compact headings display “Verbos”. The project file passes plist validation, the new icon is an opaque 1024 × 1024 PNG referenced by AppIcon, and all application Swift files compile again for the arm64 iOS simulator target. The existing linker sysroot warning remains. No simulator visual check is claimed. Bundle identifiers, storage paths and gameplay are unchanged; the fifteen-test result below precedes this presentation-only update.

## Passed

- All application Swift files compiled together for the arm64 iOS 18 simulator target using the iPhoneSimulator 26.2 SDK. This is a source compilation check, not a completed Xcode app build. The compiler driver emitted a sysroot warning during linking.
- All test files typechecked against that iOS module and SDK.
- Fifteen Swift Testing tests in nine suites passed using a macOS build of the same Features, ViewModels and persistence sources. No Swift package or alternate production implementation was introduced.
- Tests cover twenty scored answers, one extra session, wrong/revealed answers, duplicate answer handling, failed-save retry, persisted decks, midnight rollover, different-verb selection, question-two focus locking, conjugation choices, catalogue update failure, day streaks, settings, book reader and the two-second transition.
- A real SwiftData test created its nested store directory, saved a session and deck, reopened the store and verified identical progress. Core Data logged an inability to register a store-change notification in this execution environment; the write/read assertions passed. This does not establish simulator notification behaviour.
- The production content repository downloaded and checksum-verified all four Cuentiva release packs: 52 books. The saved cache reloaded successfully. The bundled conjugation source contains 29 verbs; the three currently supported matching verb books are ser, estar and querer.
- Xcode lists the SpanishTwenty app/test targets and shared scheme. Both configurations use the requested bundle-ID prefix. No old maths branding or question types remain in Swift/project/scheme files.

## Not yet verified

Daily stamp update (22 October): the shared StreakStrip now renders DailyCompletionStamp for completed days in both tabs. All application Swift files compiled again for arm64 iOS Simulator, and the unchanged model/ViewModel/storage test executable passed all fifteen tests again on macOS. The new 256 × 256 image has an alpha channel and original-colour asset configuration. A circular SwiftUI mask keeps its displayed edge clean. This is not a simulator screenshot or visual-runtime verification.

The full simulator Xcode build was attempted but failed in storyboard/asset compilation because this session could not connect to CoreSimulator or discover its runtimes. The reported errors were “iOS 26.2 Platform Not Installed” and “No available simulator runtimes for platform iphonesimulator.” Consequently, no installed-app run, simulator screenshot review, UI automation or Xcode-hosted test run is claimed.

Open SpanishTwenty.xcodeproj, select an installed simulator and run Command-R, then Command-U. Review the answer cloud at large text sizes, question-one verb/mode changes, hidden tabs during play, feedback timing, book reader and all themes. Check offline relaunch with a partly completed session and repeat on a physical device before release.

The Spanish source retains its editorial-review notices. Have a native speaker review the teaching glosses and context, especially preterite versus imperfect, before public distribution. The present-tense books and separate past/future conjugation drills are explicitly distinguished in the app and README.

Todays Twenty and Cuentiva were not modified. This project is tracked in its own local Git repository; it has not been pushed or published.
