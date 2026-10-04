#!/usr/bin/env python3
"""Build self-contained encrypted question chunks and assets for QuestionX Web.

Reads assets/neet.json and assets/jee.json, partitions them by exam & subject,
encrypts each partition with AES-256-GCM (prepended 12-byte IV), and outputs
web/public/data/<chunk>.bin.enc alongside web/public/data/manifest.json.

Also extracts/syncs referenced diagram images to web/public/diagrams/.
"""

import hashlib
import json
import os
import shutil
import sys
import zipfile
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

REPO_ROOT = Path(__file__).resolve().parents[1]
ASSETS_DIR = REPO_ROOT / "assets"
WEB_DIR = REPO_ROOT / "web"
DATA_OUT_DIR = WEB_DIR / "public" / "data"
DIAGRAMS_OUT_DIR = WEB_DIR / "public" / "diagrams"

# Master secret seed for key derivation (must match crypto.ts derivation)
CRYPTO_SEED = b"QuestionX-Nilam2-2026-Sapphire-Secure-Vault-v1"


def derive_key() -> bytes:
    # 256-bit key from SHA-256 of seed
    return hashlib.sha256(CRYPTO_SEED).digest()


def encrypt_chunk(data: bytes, key: bytes) -> bytes:
    aesgcm = AESGCM(key)
    iv = os.urandom(12)
    ciphertext = aesgcm.encrypt(iv, data, None)
    return iv + ciphertext


def main():
    print("🚀 Building QuestionX Web encrypted data chunks...")
    DATA_OUT_DIR.mkdir(parents=True, exist_ok=True)
    DIAGRAMS_OUT_DIR.mkdir(parents=True, exist_ok=True)

    key = derive_key()

    chunks_meta = []

    # Process NEET
    neet_path = ASSETS_DIR / "neet.json"
    if not neet_path.exists():
        sys.exit(f"Missing {neet_path}")

    print("📖 Loading NEET bank...")
    neet_data = json.loads(neet_path.read_text(encoding="utf-8"))

    # Group by subject
    neet_by_subject = {}
    for q in neet_data:
        sub = q.get("subject", "General")
        neet_by_subject.setdefault(sub, []).append(q)

    for sub, qlist in neet_by_subject.items():
        chunk_id = f"neet_{sub.lower().replace(' ', '_')}"
        serialized = json.dumps(qlist, ensure_ascii=False).encode("utf-8")
        encrypted = encrypt_chunk(serialized, key)
        out_file = DATA_OUT_DIR / f"{chunk_id}.bin.enc"
        out_file.write_bytes(encrypted)

        topics = sorted(list({q.get("topic") for q in qlist if q.get("topic")}))
        years = sorted(list({q.get("year") for q in qlist if q.get("year")}))

        chunks_meta.append({
            "id": chunk_id,
            "exam": "NEET",
            "subject": sub,
            "count": len(qlist),
            "file": f"data/{chunk_id}.bin.enc",
            "size": len(encrypted),
            "topics": topics,
            "years": years,
        })
        print(f"  ✓ {chunk_id}: {len(qlist)} questions ({len(encrypted) // 1024} KB)")

    # Process JEE
    jee_path = ASSETS_DIR / "jee.json"
    if not jee_path.exists():
        sys.exit(f"Missing {jee_path}")

    print("📖 Loading JEE bank...")
    jee_data = json.loads(jee_path.read_text(encoding="utf-8"))

    jee_by_subject = {}
    for q in jee_data:
        sub = q.get("subject", "General")
        jee_by_subject.setdefault(sub, []).append(q)

    for sub, qlist in jee_by_subject.items():
        chunk_id = f"jee_{sub.lower().replace(' ', '_')}"
        serialized = json.dumps(qlist, ensure_ascii=False).encode("utf-8")
        encrypted = encrypt_chunk(serialized, key)
        out_file = DATA_OUT_DIR / f"{chunk_id}.bin.enc"
        out_file.write_bytes(encrypted)

        topics = sorted(list({q.get("topic") for q in qlist if q.get("topic")}))
        years = sorted(list({q.get("year") for q in qlist if q.get("year")}))

        chunks_meta.append({
            "id": chunk_id,
            "exam": "JEE",
            "subject": sub,
            "count": len(qlist),
            "file": f"data/{chunk_id}.bin.enc",
            "size": len(encrypted),
            "topics": topics,
            "years": years,
        })
        print(f"  ✓ {chunk_id}: {len(qlist)} questions ({len(encrypted) // 1024} KB)")

    # Write manifest
    manifest = {
        "version": "1.0.0",
        "generated_at": 1727980000,
        "chunks": chunks_meta,
        "total_questions": len(neet_data) + len(jee_data),
    }
    manifest_path = DATA_OUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"📄 Wrote manifest: {manifest_path} ({len(chunks_meta)} chunks, {manifest['total_questions']} questions)")

    # Sync diagrams
    print("🖼️ Syncing diagrams to web/public/diagrams/...")
    copied_count = 0
    # From assets/diagrams
    staged_dir = ASSETS_DIR / "diagrams"
    if staged_dir.exists():
        for f in staged_dir.iterdir():
            if f.is_file() and not f.name.startswith("."):
                shutil.copy2(f, DIAGRAMS_OUT_DIR / f.name)
                copied_count += 1

    # From release data.zip if available
    release_zip = REPO_ROOT / "scripts" / "jee" / "out" / "release" / "data.zip"
    if release_zip.exists():
        with zipfile.ZipFile(release_zip, "r") as z:
            for item in z.namelist():
                if item.startswith("diagrams/") and not item.endswith("/"):
                    basename = Path(item).name
                    dest = DIAGRAMS_OUT_DIR / basename
                    if not dest.exists():
                        dest.write_bytes(z.read(item))
                        copied_count += 1

    print(f"  ✓ Staged {copied_count} diagrams in {DIAGRAMS_OUT_DIR}")
    print("✨ Web data build complete!")


if __name__ == "__main__":
    main()
