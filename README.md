# Chambers — shared case planning for lawyers

A web platform where lawyers track court cases and plan what to do before each hearing.

**The rule:** every signed-in lawyer can *view* every case, plan and note. A lawyer can *edit or delete* only the cases, plan steps and notes they created. This is enforced by the database (Supabase Row Level Security), not just hidden in the interface — so it holds even if someone calls the API directly.

## What's inside

| Feature | Who can do it |
|---|---|
| Dashboard — your hearings and plan steps for the next 14 days, overdue items, activity across chambers | Everyone (shows your own work) |
| Cases list — search by party, suit number, court or lawyer; filter by status/court; "Mine / Everyone" | Everyone |
| Case file — suit no., court, judge, parties, next hearing, summary, strategy | Everyone views; owner edits |
| Plan — steps with type and due date, tick off when done | Everyone views; owner adds/edits |
| Notes — add a note to any case (e.g. sharing experience with a judge) | Anyone adds their own; only the author edits/deletes |
| Cause list — all upcoming hearings in chambers by sitting day | Everyone |

## Files

```
index.html             the whole app (single page, no build step)
config.js              your Supabase URL + anon key go here
supabase/schema.sql    tables + security rules — run once in Supabase
vercel.json            Vercel settings (security headers)
```

## Try it first (no setup)

With `config.js` left empty, the app runs in **demo mode** with three sample lawyers and seven cases, stored only in your browser. Open `index.html` through any local server, or deploy straight to Vercel and visit the URL. Pick a lawyer, then open a colleague's case to see view-only mode. Add `?demo=1` to the URL to force demo mode even after Supabase is configured.

## Go live — about 10 minutes

### 1. Supabase (database + sign-in)
1. Create a free project at [supabase.com](https://supabase.com).
2. **SQL Editor → New query**, paste all of `supabase/schema.sql`, click **Run**.
3. **Project Settings → API**: copy the *Project URL* and the *anon public* key into `config.js`.
4. **Authentication → URL Configuration**: set *Site URL* to your Vercel address (e.g. `https://chambers-yourfirm.vercel.app`) so confirmation emails link back to the app.

### 2. Vercel (hosting)
- **Easiest:** push this folder to a GitHub repository, then in Vercel choose **Add New → Project → Import** that repo. Framework preset: **Other**. No build command. Deploy.
- **Or from a terminal:** `npm i -g vercel`, then run `vercel --prod` inside this folder.

### 3. Control who can join (recommended)
Court case information is confidential. By default anyone with the link can sign up and read all cases. To restrict access:
- **Supabase → Authentication → Sign In / Providers → turn off "Allow new users to sign up"**, then add each lawyer yourself from **Authentication → Users → Invite user**.
- Keep **Confirm email** on so nobody can register with someone else's address.

## How the permission rule works

Every case, plan step and note stores an `owner_id`. The policies in `schema.sql` say:

- `select` → allowed for any signed-in user
- `insert` → only with `owner_id = your own id` (plan steps: only on a case you own)
- `update` / `delete` → only rows where `owner_id = your own id`

The interface mirrors this: other lawyers' cases show a "view only" banner, with no edit, delete or tick-box controls.

## Ideas for later
- Document uploads per case (Supabase Storage with the same owner rule)
- Email or SMS reminders the day before a hearing
- Firm workspaces, so separate firms don't see each other's cases
- Optional "co-counsel" field to let a named colleague edit a case
