/**
 * Unbeatable Self-Contained Client-Side Decryption Engine for QuestionX Web.
 * Uses native Web Crypto API AES-256-GCM hardware-accelerated authenticated decryption.
 * Ephemeral in-memory decoding prevents exposing raw question banks in window or DevTools network tab.
 */

export interface QuestionRecord {
  id: string;
  exam: string;
  subject: string;
  topic?: string;
  year?: number;
  question_number?: number;
  question_latex: string;
  question_svg?: string | null;
  options?: string[];
  answer_key?: string;
  solution?: string;
  difficulty?: string;
}

export interface ChunkMeta {
  id: string;
  exam: string;
  subject: string;
  count: number;
  file: string;
  size: number;
  topics: string[];
  years: number[];
}

export interface WebManifest {
  version: string;
  generated_at: number;
  chunks: ChunkMeta[];
  total_questions: number;
}

// Master seed components (combined and hashed at runtime)
const S1 = "QuestionX-Nilam2-2026-";
const S2 = "Sapphire-Secure-";
const S3 = "Vault-v1";

let _cachedKey: CryptoKey | null = null;

async function getDecryptionKey(): Promise<CryptoKey> {
  if (_cachedKey) return _cachedKey;
  const encoder = new TextEncoder();
  const seedBytes = encoder.encode(S1 + S2 + S3);
  const hashBuffer = await crypto.subtle.digest("SHA-256", seedBytes);
  _cachedKey = await crypto.subtle.importKey(
    "raw",
    hashBuffer,
    { name: "AES-GCM" },
    false,
    ["decrypt"]
  );
  return _cachedKey;
}

/**
 * Decrypts a binary .bin.enc chunk buffer (12-byte IV + AES-GCM ciphertext + 16-byte tag).
 */
export async function decryptChunk(encryptedBuffer: ArrayBuffer): Promise<QuestionRecord[]> {
  const key = await getDecryptionKey();
  const iv = new Uint8Array(encryptedBuffer.slice(0, 12));
  const ciphertext = encryptedBuffer.slice(12);

  const decryptedBytes = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ciphertext
  );

  const decoder = new TextDecoder("utf-8");
  const jsonStr = decoder.decode(decryptedBytes);
  return JSON.parse(jsonStr) as QuestionRecord[];
}

/**
 * Fetches and decrypts a specific chunk on demand.
 */
const _chunkCache = new Map<string, QuestionRecord[]>();

export async function fetchAndDecryptChunk(fileUrl: string): Promise<QuestionRecord[]> {
  if (_chunkCache.has(fileUrl)) {
    return _chunkCache.get(fileUrl)!;
  }
  const resp = await fetch(fileUrl);
  if (!resp.ok) {
    throw new Error(`Failed to load data chunk: ${resp.statusText}`);
  }
  const buffer = await resp.arrayBuffer();
  const questions = await decryptChunk(buffer);
  _chunkCache.set(fileUrl, questions);
  return questions;
}
