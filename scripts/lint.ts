/**
 * Type-aware lint of src and scripts, then a general lint of the whole project.
 * Both passes always run, and the first non-zero exit code is returned, so one
 * invocation reports everything. Replaces a POSIX-shell one-liner that Bun's
 * Windows shell rejects.
 */
import { runBin } from './run-tool';

const typeAware = await runBin('oxlint', ['--type-aware', 'src', 'scripts', '--fix']);
const general = await runBin('oxlint', ['--fix', '.']);

process.exit(typeAware > 0 ? typeAware : general);
