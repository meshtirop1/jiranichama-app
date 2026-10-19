# End-to-end test on a device

`integration_test/phase1_e2e_test.dart` walks the whole of Phase 1 through the real app
against a real local API: four people sign in and out on one device (founder/chair,
treasurer, secretary, member), set up a chama, join with invite codes, adopt the rules
by SMS code, upload a bank statement that a second official confirms, see payments
matched and the records checked on the phone, assign an unmatched payment, and send it
back with "This was not me". It then brings in an opening balance (drafted by the
treasurer, confirmed by the chair), records cash at a meeting that the member confirms,
uploads a later statement that repeats the day's lines and adds the cash deposit, and has
the treasurer link that deposit to the cash. Screenshots land in `build/e2e_screenshots/`; the last
passing run is kept in [screenshots/phase1](../screenshots/phase1/).

It is not part of CI, because it needs a running API and a device.

## Run it

1. Start the API in local development mode, with the dev SMS outbox so the test can read
   the codes (nothing is sent by SMS):

   ```
   DJANGO_DEBUG=1 DJANGO_SECURE_SSL_REDIRECT=0 \
   DJANGO_ALLOWED_HOSTS=10.0.2.2,localhost,127.0.0.1 \
   SMS_BACKENDS=apps.notify.sms.DevFileBackend DEV_SMS_FILE=.dev-sms.log \
   CELERY_TASK_ALWAYS_EAGER=1 OTP_THROTTLE_RATE=1000/hour OTP_VERIFY_THROTTLE_RATE=1000/hour \
   python manage.py runserver 0.0.0.0:8000
   ```

2. Forward the device's port 8000 to this computer (emulator or USB phone):

   ```
   adb reverse tcp:8000 tcp:8000
   ```

3. Run:

   ```
   flutter drive --driver=test_driver/integration_test.dart \
     --target=integration_test/phase1_e2e_test.dart -d <device> \
     --dart-define=E2E_HOST=http://127.0.0.1:8000 \
     --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
   ```

Keep a USB phone's screen on (Developer options, Stay awake): the app cannot start on a
sleeping phone. Each run uses fresh phone numbers, so runs never collide.

## What the first runs found and fixed

- Nobody had a name: sign-up never asked. The PIN screen now asks for a name too, and the
  API falls back to the member code where a name is missing.
- The Join and Confirm buttons sat below a long rule book. The main action of the join,
  confirm-rules and setup screens is now pinned to the bottom (`ActionBar`).
- A reversed payment looked live. Reversed records are now struck through and marked,
  and each correction names the receipt it corrects.
- On a real phone, typing into a field right after closing a dropdown can be lost; the
  test now focuses the field first and checks the text arrived.
