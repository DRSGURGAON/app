# Google Play Data safety — answers for DocSafe 1.0.0

Based on what the code does (no INTERNET permission, no SDKs for ads/analytics/crash
reporting, everything stored encrypted on the device). Re-check whenever a dependency or
feature changes.

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Data that never leaves the device is not "collected" in Play's definition. DocSafe has no server and no internet permission; documents, names, notes, dates, OCR text and the optional signature stay encrypted on the phone. |
| Is all user data encrypted in transit? | Not applicable (nothing is transmitted) | |
| Do you provide a way for users to request that their data is deleted? | **Yes** — Settings → Erase all data; uninstalling also deletes everything | |
| Independent security review | No | |

## Points to double-check in Play Console

- **Google Play Billing.** Purchases are handled by Google Play; DocSafe only receives
  whether a verified subscription is active and stores nothing. Play's Data safety help
  covers data handled by Google Play billing; read the current help text in Play Console
  when filling the form. If it asks you to declare it, the accurate answer is: *Purchase
  history — collected, not shared, processed ephemerally, required for app functionality
  (subscription)*.
- **Google Play services document scanner.** The scanner UI runs in Google Play services
  on the device and returns images to DocSafe; DocSafe sends nothing. Google's own data
  handling is covered by Google's policy.
- **Backups.** The user saves the encrypted backup file through the Android system dialog
  to a place they choose (Drive, USB, folder). DocSafe does not upload it, so this is not
  collection by DocSafe.

## Permissions (no special declarations needed)

| Permission | Purpose |
|---|---|
| USE_BIOMETRIC / USE_FINGERPRINT | Optional fingerprint/face unlock |
| POST_NOTIFICATIONS | Reminder notifications (generic text, no document names) |
| RECEIVE_BOOT_COMPLETED | Re-arm reminders after a restart |
| com.android.vending.BILLING | DocSafe Premium subscription |
| ACCESS_NETWORK_STATE | Added by Google libraries; DocSafe has no internet access |

No camera, storage, location, contacts, phone, SMS, exact-alarm, accessibility-service or
MANAGE_EXTERNAL_STORAGE permission (CI fails if any appears).
