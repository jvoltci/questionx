/*
 * crypto.js — AES-256-CBC decryption for QuestionX encrypted banks.
 *
 * Ported 1:1 from lib/utils/crypto.dart.
 * Pipeline: .enc file → split IV(16) || ciphertext → AES-CBC decrypt → gunzip → UTF-8 → JSON.
 *
 * Uses the Web Crypto API (no external dependencies).
 * NOTE: This is an INTERNAL debug tool. The key ships in the app binary anyway;
 * exposing it here adds no new attack surface.
 */

(function () {
  // Key assembled from the same parts as crypto.dart (base64 encoded).
  const KEY_B64 = 'SHCCwpDehmPSK1noF7ttQNS7PhedqvBFPMFxiiEb/9c=';

  let _keyPromise = null;

  /** Import the AES key once, cache the CryptoKey object. */
  function getKey() {
    if (!_keyPromise) {
      const raw = Uint8Array.from(atob(KEY_B64), (c) => c.charCodeAt(0));
      _keyPromise = crypto.subtle.importKey('raw', raw, { name: 'AES-CBC' }, false, ['decrypt']);
    }
    return _keyPromise;
  }

  /**
   * Decrypt an ArrayBuffer containing an encrypted .enc payload.
   * Layout: IV(16 bytes) || AES-CBC ciphertext.
   * Returns the plaintext JSON string.
   */
  async function decryptBuffer(buf) {
    const bytes = new Uint8Array(buf);
    const iv = bytes.slice(0, 16);
    const ct = bytes.slice(16);

    const key = await getKey();
    const decrypted = await crypto.subtle.decrypt({ name: 'AES-CBC', iv }, key, ct);

    // The decrypted payload is gzipped — decompress it.
    const gzipped = new Uint8Array(decrypted);
    const ds = new DecompressionStream('gzip');
    const writer = ds.writable.getWriter();
    writer.write(gzipped);
    writer.close();

    const reader = ds.readable.getReader();
    const chunks = [];
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
    }

    // Concatenate and decode as UTF-8
    const totalLen = chunks.reduce((sum, c) => sum + c.length, 0);
    const result = new Uint8Array(totalLen);
    let offset = 0;
    for (const c of chunks) {
      result.set(c, offset);
      offset += c.length;
    }
    return new TextDecoder().decode(result);
  }

  /**
   * Load a question bank by name (e.g. 'jee' or 'neet').
   * Tries plaintext first (/assets/{name}.json), falls back to encrypted (/assets/{name}.json.enc).
   * Returns the parsed array, or [] on failure.
   */
  async function loadBank(name) {
    // 1. Try plaintext JSON first (fastest, available on dev machine)
    try {
      const r = await fetch(`/assets/${name}.json`);
      if (r.ok) {
        const data = await r.json();
        const list = Array.isArray(data) ? data : (data.questions || []);
        if (list.length > 0) {
          console.log(`✔ ${name}: loaded ${list.length} questions from plaintext`);
          return { list, source: 'plaintext' };
        }
      }
    } catch (e) {
      console.warn(`${name}.json failed:`, e);
    }

    // 2. Fall back to encrypted .enc
    try {
      const r = await fetch(`/assets/${name}.json.enc`);
      if (r.ok) {
        const buf = await r.arrayBuffer();
        const json = await decryptBuffer(buf);
        const data = JSON.parse(json);
        const list = Array.isArray(data) ? data : (data.questions || []);
        console.log(`✔ ${name}: decrypted ${list.length} questions from .enc`);
        return { list, source: 'encrypted' };
      }
    } catch (e) {
      console.warn(`${name}.json.enc failed:`, e);
    }

    return { list: [], source: 'none' };
  }

  // Expose
  window.QXCrypto = { decryptBuffer, loadBank };
})();
