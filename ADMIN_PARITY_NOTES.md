# Web and mobile admin alignment

The admin opens on Manage Orders. The horizontally scrolling tabs include Manage Orders, Live Chat, Analytics, RFID Cards, Users, Samples & Services, Place Order (the services manager), GCash Settings, and Archive. Store inventory and the existing profile/home screens remain available.

Services, custom requirements and prices use `services`; sample works use `sample_products`; GCash details use `settings/gcash_config`. Customer order forms subscribe to the shared catalog. Requirements support text, numbers, select, radio and checkbox choices, including required/optional flags. Numeric typing limits are retained.

Products use `products` with the existing `artifacts/printcraft-pro/public/data/store_products` compatibility copy. Reads include legacy-only records. Archive, restore, permanent deletion and stock transitions update related records atomically. Customer profiles resolve existing `customers` and `users` documents by email, retaining their document IDs. RFID balances are stored on those profiles with tap history in `rfid_logs`.

Android Print Ticket opens the Android print dialog, including Save as PDF. Other platforms show an explicit unsupported message. Product images support both ordinary image URLs and the website's existing image data URLs.

For a QR image stored as a relative website path, upload a QR image in mobile GCash Settings to save a shared absolute URL, or run/build with `--dart-define=WEBSITE_BASE_URL=https://your-website.example`. Existing Firebase/Supabase access policies still apply. No production rules were deployed and no live data migration was performed.

Verification:

```text
flutter test --no-pub
flutter build apk --debug --no-pub
```

In the web repository:

```text
python -m unittest discover -s tests -v
```

Backend regression tests use an in-memory transaction double and never initialize Firebase. Browser script checks run Node's syntax checker. Live Firestore permissions, Supabase uploads, device printing, FCM delivery and the SQLite upgrade require testing in the installed app. Mobile status changes create shared notification records; server-side push delivery is still tied to the web backend's existing push integration.

For live acceptance, edit a service/requirement and QR on each platform, then check the other platform and its customer order form. Archive and restore a product and customer in both directions. Approve a store order on one platform and complete it on the other, checking that stock is deducted once; reject another approved order and verify stock is restored once. Offline queued orders retain their complete payload and will not overwrite an existing server order on retry.
