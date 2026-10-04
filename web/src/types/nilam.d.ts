declare module "nilam/tulip" {
  export function isTulipUnlocked(): boolean;
  export function unlockTulip(root?: HTMLElement | null): boolean;
  export function lockTulip(root?: HTMLElement | null): boolean;
  export function listenTulipUnlock(opts?: { timeout?: number; target?: EventTarget | null }): () => void;
}
