/**
 * Lint then typecheck. Both steps always run so one invocation reports lint AND type
 * errors. Cross-platform replacement for scripts/check.sh (which needs bash).
 */
import { runScript } from './run-tool';

let failed = false;
for (const step of ['lint', 'typecheck']) {
  const code = await runScript(step);
  if (code !== 0) {
    failed = true;
  }
}

process.exit(failed ? 1 : 0);
