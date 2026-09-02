#!/usr/bin/env python3
"""Fetch a user's cloud backup by email.

Email -> user_id requires the Supabase *service_role* key (the anon key in
the app's .env can't do this — RLS only lets a user read their own row).
That's a much higher-privilege secret, so it lives only in this folder's own
.env, never the app's root .env. See tools/agent_lab/README.md.

Usage:
    python fetch_backup.py --email you@example.com
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import requests
from dotenv import dotenv_values

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
LAB_DIR = Path(__file__).resolve().parent
BACKUPS_DIR = LAB_DIR / "backups"


def _load_env() -> dict[str, str]:
    # SUPABASE_URL comes from the app's root .env (already gitignored, not a
    # secret worth duplicating); SUPABASE_SERVICE_ROLE_KEY only ever lives in
    # this folder's own .env.
    env = dict(dotenv_values(REPO_ROOT / ".env"))
    env.update(dotenv_values(LAB_DIR / ".env"))
    return env


def find_user_id(base_url: str, service_role_key: str, email: str) -> str:
    headers = {"apikey": service_role_key, "Authorization": f"Bearer {service_role_key}"}
    page = 1
    per_page = 200
    while True:
        resp = requests.get(
            f"{base_url}/auth/v1/admin/users",
            headers=headers,
            params={"page": page, "per_page": per_page},
            timeout=30,
        )
        resp.raise_for_status()
        users = resp.json().get("users", [])
        if not users:
            break
        for user in users:
            if (user.get("email") or "").lower() == email.lower():
                return user["id"]
        if len(users) < per_page:
            break
        page += 1
    raise SystemExit(f"No Supabase user found with email {email!r}.")


def fetch_backup_row(base_url: str, service_role_key: str, user_id: str) -> dict:
    headers = {"apikey": service_role_key, "Authorization": f"Bearer {service_role_key}"}
    resp = requests.get(
        f"{base_url}/rest/v1/backups",
        headers=headers,
        params={"user_id": f"eq.{user_id}", "select": "data"},
        timeout=30,
    )
    resp.raise_for_status()
    rows = resp.json()
    if not rows:
        raise SystemExit(f"No backup row found for user_id {user_id}.")
    return rows[0]["data"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True)
    parser.add_argument("--out", default=None, help="Output path (default: backups/<email>.json)")
    args = parser.parse_args()

    env = _load_env()
    base_url = env.get("SUPABASE_URL")
    service_role_key = env.get("SUPABASE_SERVICE_ROLE_KEY")
    if not base_url or not service_role_key:
        sys.exit(
            "Missing SUPABASE_URL (root .env) or SUPABASE_SERVICE_ROLE_KEY "
            "(tools/agent_lab/.env) — see .env.example."
        )

    user_id = find_user_id(base_url, service_role_key, args.email)
    data = fetch_backup_row(base_url, service_role_key, user_id)

    BACKUPS_DIR.mkdir(exist_ok=True)
    out_path = Path(args.out) if args.out else BACKUPS_DIR / f"{args.email}.json"
    out_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"Wrote {out_path} ({len(data.get('transactions', []))} transactions)")


if __name__ == "__main__":
    main()
