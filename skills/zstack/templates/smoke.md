# Smoke list

Fixed journeys appended to every manual-test checklist. Copy to `.git/zstack/smoke.md` and edit for this
repo. One line each: `- [ ] <journey>: <steps> -> <expected>`.

- [ ] Sign in: open the app, sign in with the test account -> the home screen shows the account name
- [ ] Core create flow: create a new item from the main screen, save it -> the item appears in the list with the entered values
- [ ] Payments (test mode): start checkout with a test card -> the confirmation screen shows and the order is marked paid
- [ ] Sign out: open the account menu, sign out -> the sign-in screen shows and a protected page redirects to it
