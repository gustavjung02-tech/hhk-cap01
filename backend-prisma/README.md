# HHK QR & license service — Prisma target

API intended for **Prisma project `gus-02`** and its Prisma Postgres database.
Node/Hono service source is self-contained and currently **fails closed** (503 on all write/license endpoints). It is not deployed to Prisma Compute.

Prisma Compute currently requires an appropriate Prisma ORM/Composer setup and an attached database; **do not treat this Node server shell as a valid Compute deployment** before that integration and migration are completed.

```sh
npm install
npm run typecheck
npm test
npm run build
npm start
```

Never expose signing private keys, database URLs or raw QR tokens in Flutter or Vercel static assets. Future operational endpoints must require authorization and transactions, idempotent redemption, replay resistance, rate limiting, signed device-bound offline leases and administrative audit logs.
