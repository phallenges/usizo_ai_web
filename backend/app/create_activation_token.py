"""Issue a single-use Plus activation token after manual payment verification.

Run from backend/: python -m app.create_activation_token --reference ECO-12345
The token is printed once; only its SHA-256 digest is persisted.
"""

import argparse
import secrets

from .database import db, init_schema, token_digest, utc_now


def main() -> None:
    parser = argparse.ArgumentParser(description="Issue a UsizoAI Plus activation token")
    parser.add_argument("--reference", required=True, help="Verified EcoCash transaction reference")
    args = parser.parse_args()
    reference = args.reference.strip()
    if not reference:
        parser.error("reference cannot be empty")

    init_schema()
    token = f"USIZO-{secrets.token_urlsafe(18).upper()}"
    with db() as conn:
        try:
            conn.execute(
                "INSERT INTO activation_tokens (token_hash, reference, created_at) VALUES (?, ?, ?)",
                (token_digest(token), reference, utc_now()),
            )
        except Exception as exc:
            parser.error(f"could not issue token: {exc}")
    print(token)


if __name__ == "__main__":
    main()
