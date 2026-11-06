/**
 * Cross-platform helpers for the lint and check scripts. Uses only node:child_process, so it
 * needs no bash, GNU timeout or POSIX shell arithmetic and runs the same on Windows, macOS
 * and Linux. Commands run through the current Bun executable, never through a shell.
 */
import { spawn } from 'node:child_process';

export const STEP_TIMEOUT_MS = 150_000;

function runBun(args: string[], label: string, timeoutMs: number): Promise<number> {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, args, { stdio: 'inherit' });
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill();
    }, timeoutMs);

    child.on('error', (spawnError) => {
      clearTimeout(timer);
      console.error(`${label}: failed to start: ${spawnError.message}`);
      resolve(1);
    });
    child.on('close', (code) => {
      clearTimeout(timer);
      if (timedOut) {
        console.error(`${label}: timed out after ${timeoutMs / 1000}s. Another heavy process may be running; re-run once it finishes.`);
        resolve(124);
        return;
      }
      resolve(code ?? 1);
    });
  });
}

/** Runs a package binary (e.g. oxlint) through `bun x` with inherited stdio. Returns its exit code. */
export function runBin(bin: string, args: string[], timeoutMs = STEP_TIMEOUT_MS): Promise<number> {
  return runBun(['x', bin, ...args], bin, timeoutMs);
}

/** Runs a package.json script through `bun run` with inherited stdio. Returns its exit code. */
export function runScript(script: string, timeoutMs = STEP_TIMEOUT_MS): Promise<number> {
  return runBun(['run', script], `check: ${script}`, timeoutMs);
}
