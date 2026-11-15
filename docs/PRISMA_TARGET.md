# Prisma backend/database — deployment target

**User-specified existing project:** https://console.prisma.io/ph998iyve9m9q7pz3cc2q3mu/t5ke1mdd3u72vvhw1ogmm5vn

As inspected via Prisma connector on **15 November 2026**:
- Workspace ID `wksp_ph998iyve9m9q7pz3cc2q3mu`;
- Project ID `proj_t5ke1mdd3u72vvhw1ogmm5vn` (name `gus-02`);
- Production branch `br_kryap5xyg52hpl1nlyinvfxy` (`main`);
- **No Prisma Postgres databases**, **no Prisma Compute app**, Composer topology empty.
- The current database-create plugin action creates a **database and separate project**, not a database within an existing project. It is **not** appropriate to invoke it for this target because it would break the user's requested project association.

## Required work for QR + license backend
1. Provision Prisma Postgres in the **existing project**, not a new one. Configure region and branch intentionally; never publish connection credentials.
2. Create a preview branch and run `db-prisma/migrations/0001_license_only.sql` there; verify constraints and tests. Production migration requires explicit approval.
3. Convert `backend-prisma/` from fail-closed Node/Hono shell into a production Prisma 8/Compute compatible application with signed offline licenses and QR atomic redemption. Prisma Compute deployment tooling/version must be verified first.
4. Keep service limited to QR/code redemption, campaign configuration, license, revocation and device transfer. Nothing about student answer events/XP/learning history in central DB.
5. Company website hands out key after verifying hidden QR token; Flutter PWA/Android/iOS validates signed offline license locally. A key is not a password and must be rate limited on the server.

## Deliberately excluded
No React UI, no legacy Express, no Cloudflare Workers QR backend, no Neon database, no Chat AI, no online question grading, no automatic progress sync.
