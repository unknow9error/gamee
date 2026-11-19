# Legacy v1 Android native manual smoke

Historical evidence from the original 120-exercise build, captured before the November 17 change to twenty authored ImageGen levels. These screenshots and observations do not verify the current v2 app; use the subsequent v2 runtime report for current acceptance.

Tested a real installed Flutter debug APK on the Android API 34 ARM64 Pixel 3a emulator (`emulator-5554`, physical display 1080 × 2220). This is native runtime evidence, distinct from widget and painter fixtures.

Observed successfully:

- Cold APK installation and launch into the first-run onboarding.
- All three onboarding pages, followed by the real home screen.
- Settings in Russian, Kazakh and English; visible UI updated immediately.
- Force-stopping and cold-starting the process preserved English and the completed onboarding state.
- Opening level 1 displayed its first-use animated tutorial and the actual 21-region whale color-by-number activity.
- A mismatched color was rejected: progress stayed at 0 of 21 and the app requested the color for 12.
- The matching color filled one region and progress became 1 of 21; Done remained disabled.
- Saving/leaving, force-stopping, cold-starting and reopening restored the filled region and 1-of-21 count, without repeating the tutorial.
- Rotating the same native activity to landscape preserved the work and moved the palette alongside the canvas without visible overflow.
- Returned to portrait/home for handoff to the parent agent's five-game integration run.

Evidence PNGs are in this directory with the `android-` prefix. This smoke does not establish successful completion of every activity, audio quality, a physical-device result, or store distribution. The emulator was launched without host audio, so sounds and TTS were not audibly evaluated.
