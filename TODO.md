# TODO

## P0 — Core workflow: authenticated CRUD UI for data
- Add signed-in-only admin-style UI to manage:
  - Entities (index/show/new/edit/delete)
  - Metrics (index/show/new/edit/delete)
  - Observations (index/show/new/edit/delete)
  - Documents (upload/delete and any URL metadata)
- Access control:
  - Require login for all mutation endpoints (already mostly in place)
  - Ensure unapproved users cannot access any authenticated pages
  - Add friendly “pending approval” messaging where appropriate
- UX minimum viable:
  - Clear navigation to each resource
  - Flash messages for create/update/destroy
  - Basic validation error display (Pico.css-friendly)

## P1 — Admin approval operations
- Create `/admin/users` page:
  - List pending users (approved=false), newest first
  - Approve button per user (sets approved=true)
  - (Optional) Reject/delete button (or disable account)
- Add basic admin authorization:
  - Introduce `admin:boolean` on users OR allowlist by email (ADMIN_EMAIL) temporarily
  - Restrict `/admin/*` routes to admin users only
- When admin approves:
  - Notify the user their account is active (optional for now)

## P2 — Production email (Brevo)
- Configure ActionMailer SMTP in production using Brevo:
  - SMTP_ADDRESS=smtp-relay.brevo.com
  - SMTP_PORT=587
  - SMTP_USERNAME / SMTP_PASSWORD from Brevo SMTP credentials
  - SMTP_DOMAIN=nybenchmark.org
  - ADMIN_EMAIL=admin@nybenchmark.org
- Add/send a production smoke-test mail via `rails runner`
- Verify domain SPF/DKIM so messages deliver reliably

## P3 — Cleanup / hardening
- Decide whether Solid Queue should run in production:
  - If yes, run it as a separate worker role (do not couple to Puma web)
  - If no, keep it disabled and remove unused recurring config
- Document “How to run locally” (Docker dev vs host) in README
- Add a short “Ops” section: deploy, migrate, logs, console, approve a user