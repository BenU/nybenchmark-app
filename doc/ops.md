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
- **Retention:** 30 days. The backup script deletes files older than 30 days after each upload. (DigitalOcean Spaces does not support S3 lifecycle rules via the AWS CLI.)

---

## OS Maintenance

### Automatic Security Updates
`unattended-upgrades` is enabled.

- **Updates:** Security patches applied daily.
- **Reboots:** Automatic reboot enabled at **03:30 AM Eastern Time** if required by kernel updates.
  - *Note:* This allows a 1.5-hour window after backups (02:00 AM) before a potential reboot.

---

## Infrastructure Scaling Roadmap

The app runs Rails + PostgreSQL in Docker on a single droplet. As data imports grow, the droplet must be resized to keep PG's working set in memory and avoid swap thrashing.

### Current Data Profile (Feb 2026)

- **62 cities** (57 OSC + 4 late filers + NYC)
- **661K observations** (647K OSC + 14K Census)
- **~380 observations per city per year** (OSC) + ~19 per city per year (Census)

### Scaling Phases

| Phase | Import | New Entities | Est. Total Obs | Droplet | Cost | Disk |
|-------|--------|-------------|----------------|---------|------|------|
| Current | Cities only | 62 | 661K | s-1vcpu-1gb | $6/mo | 25GB |
| 1 | Resize (fix slowness) | — | 661K | s-1vcpu-2gb | $12/mo | 50GB |
| 2 | + NYC Checkbook | +1 | ~750K-900K | s-1vcpu-2gb | $12/mo | 50GB |
| 3 | + Counties (~62) | +62 | ~1.5-2M | s-2vcpu-4gb | $24/mo | 80GB |
| 4 | + Towns + Villages (~1,500) | +1,500 | ~15-20M | s-4vcpu-8gb | $48/mo | 160GB |
| 5 | + School districts + Authorities (~1,700) | +1,700 | ~22-28M | s-4vcpu-8gb | $48/mo | 160GB |
| 6 | + Full Census/DCJS for all | — | ~25-30M | s-4vcpu-8gb | $48/mo | 160GB |

### PostgreSQL Tuning by Droplet Size

Tune these in the PG container's `postgresql.conf` (or via `ALTER SYSTEM`). Restart PG after changes.

| Droplet | RAM | shared_buffers | effective_cache_size | work_mem |
|---------|-----|---------------|---------------------|----------|
| 1GB (current) | 961MB | 128MB (default) | 512MB | 4MB |
| 2GB | 2GB | 512MB | 1.5GB | 4MB |
| 4GB | 4GB | 1GB | 3GB | 8MB |
| 8GB | 8GB | 2GB | 6GB | 16MB |

Rules of thumb: `shared_buffers` = 25% of RAM, `effective_cache_size` = 75% of RAM, `work_mem` = 4-16MB (higher = faster sorts but more memory per query).

### Disk Math

Each observation is ~200-300 bytes. With indexes:
- 661K rows → ~1-2GB on disk (current)
- 25M rows → ~15-25GB on disk with indexes
- 160GB disk at the 8GB tier provides ample headroom

### When to Resize

- **Swap usage > 100MB sustained** — check with `ssh deploy@68.183.56.0 "free -h"`
- **Before any bulk import that will >2x observation count**
- **Docker stats showing > 80% memory** — check with `ssh deploy@68.183.56.0 "docker stats --no-stream"`

### How to Resize

**Via DO Dashboard (recommended):** Droplet → Resize → select "CPU options only" (NOT disk — disk resize is permanent and prevents downsizing) → Power Off → Resize → Power On. ~60 seconds downtime.

**Via CLI (requires Full Access API token):**
```bash
doctl compute droplet-action resize <droplet-id> --size s-1vcpu-2gb --wait
```

After resize, verify and tune PG:
```bash
ssh deploy@68.183.56.0 "free -h"
ssh deploy@68.183.56.0 "docker exec nybenchmark_app-db psql -U nybenchmark_app -c \"ALTER SYSTEM SET shared_buffers = '512MB';\" nybenchmark_app_production"
ssh deploy@68.183.56.0 "docker exec nybenchmark_app-db psql -U nybenchmark_app -c \"ALTER SYSTEM SET effective_cache_size = '1.5GB';\" nybenchmark_app_production"
ssh deploy@68.183.56.0 "docker restart nybenchmark_app-db"
```

### When to Consider Managed PostgreSQL

Not needed in the near term. Managed PG (DO DB-Small: $15/mo for 1GB) makes sense when:
- You need automated failover or read replicas
- DB and app need to scale independently
- Multiple contributors need direct DB access
- Ops overhead of self-hosted PG exceeds the cost savings

At current scale, a single droplet with Docker PG is simpler and cheaper.

### Monitoring

**DigitalOcean built-in:** Enable the monitoring agent and set alerts for CPU > 80%, Memory > 90%, Disk > 80%. See "Monitoring" section below.

**Diagnostics cheat sheet:**
```bash
ssh deploy@68.183.56.0 "free -h"                    # Memory + swap
ssh deploy@68.183.56.0 "docker stats --no-stream"   # Container resource usage
ssh deploy@68.183.56.0 "df -h /"                     # Disk space
ssh deploy@68.183.56.0 "uptime"                      # Load average
```

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
