# Operations Notes (NYBenchmark)

This document describes how the NYBenchmark production system is operated
and maintained. It exists to make routine operations safe, repeatable,
and boring.

These notes prioritize correctness and simplicity over clever automation.

---

## Production Environment

- **Hosting:** DigitalOcean Droplet
- **OS:** Ubuntu 24.04 LTS (noble)
- **Deployment:** Kamal + Docker
- **Web:** HTTP (80) / HTTPS (443) via Traefik (Kamal)
- **Database:** PostgreSQL (Docker container on droplet)
- **Storage:** DigitalOcean Spaces (S3-compatible)
- **Email:** Brevo (SMTP)

---

## Access & Security

### SSH
- Access via public key only.
- **User:** `deploy` (Root login disabled).
- SSH is publicly reachable on port 22.
- Fail2Ban / UFW handles brute-force mitigation.

### Firewall (UFW)
UFW is enabled. Default policy: **Deny Incoming**.

- **Allow:**
  - 22/tcp (SSH)
  - 80/tcp (HTTP)
  - 443/tcp (HTTPS)

### Database Isolation
PostgreSQL (Port 5432) is **not** exposed to the public internet.
- It is bound **only** to the internal Docker network.
- Application containers access it via the hostname `nybenchmark_app-db`.
- **Manual Access:** Must be done via SSH tunnel or `kamal app exec`.

---

## Data Safety (Backups)

### Database Backups
- **Frequency:** Daily at **02:00 AM Eastern Time**.
- **Method:** `pg_dump` via cron script.
- **Destination:** DigitalOcean Spaces (`s3://nybenchmark-production/db-backups/`).
- **Retention:** Managed via Lifecycle Rules on DigitalOcean Spaces (e.g., expire after 30 days).

---

## OS Maintenance

### Automatic Security Updates
`unattended-upgrades` is enabled.

- **Updates:** Security patches applied daily.
- **Reboots:** Automatic reboot enabled at **03:30 AM Eastern Time** if required by kernel updates.
  - *Note:* This allows a 1.5-hour window after backups (02:00 AM) before a potential reboot.

---

## Disaster Recovery Drills

### Monthly Fire Drill (Restore Verification)
**Objective:** Prove that backups are valid and can be restored locally.

1. **Download:** Get the latest `.sql.gz` from DO Spaces and place it in the project root.
2. **Reset Local DB:**
   ```bash
   # WARNING: Deletes local development data
   dcr db:drop db:create
3. **Import:**
  ```bash
  gunzip -c backup.sql.gz | docker compose exec -T db psql -U nybenchmark_app -d nybenchmark_app_development
4. **Verify:**
  ```bash
  dcr runner "puts Entity.count"

---
