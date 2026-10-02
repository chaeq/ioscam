# Stage 2: prove callback substitution

Build 2 (v0.2) keeps the same bundle ID so Sideloadly updates the installed viewer.

1. Open app, connect to the PC (current USB tethering address 172.20.10.4, port 5055).
2. PC viewer must still show the selected car image.
3. Select Real camera and grant camera access. Point at a visibly different subject. Expect live camera motion and increasing callback count; replaced count must remain unchanged.
4. Select Hook test. Expect the PC car image in the SAME callback renderer, increasing replaced/supplied counters, advancing PTS, and zero format rejects. These counters plus distinct content establish hook proof; direct PC viewer does not.
5. Switch to Real camera: physical scene must return while the connection remains active.
6. In Hook test with Freeze OFF, tap Disconnect. Expect physical camera fallback. Reconnect: PC image returns.
7. Enable Freeze, then disconnect. Expect PC image frozen but callbacks/PTS continue. Disable Freeze: physical scene returns.

Record actual results before claiming success. Capture format, orientation, fallback and counters remain device-test gates. This build fixes capture to portrait 720x1280 BGRA to avoid guessing arbitrary output formats. It does not replace preview layers, photos, ARKit or any other app's camera. No LiveContainer or Snapchat code is included.
