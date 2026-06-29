// Pure helper for wiring rtk's rspec passthrough into its TOML config.
// Kept dependency-free and side-effect-free so it is unit-testable;
// cli.js handles the actual file read/write around it.

export const RSPEC_EXCLUDES = ['rspec', 'bundle exec rspec']

// Merge rspec exclude_commands into an rtk config object, idempotently,
// without clobbering other keys/sections. Returns the same object.
// rtk garbles the rspec pass/fail summary unless these are excluded.
export function mergeRtkExcludeCommands(config = {}, entries = RSPEC_EXCLUDES) {
  if (!config.hooks) config.hooks = {}
  if (!Array.isArray(config.hooks.exclude_commands)) config.hooks.exclude_commands = []
  for (const entry of entries) {
    if (!config.hooks.exclude_commands.includes(entry)) {
      config.hooks.exclude_commands.push(entry)
    }
  }
  return config
}
