/**
 * opencode-maos — thin OpenCode plugin entry for MAOS.
 *
 * Does not vendor the full skill corpus into OpenCode hooks.
 * Skills/agentic-tools remain in-repo and are consumed via:
 *   - Claude: maos plugin / eko-plugin-marketplace
 *   - Pi: `pi install git:github.com/ekson73/multi-agent-os@main`
 *   - Skills CLI: `npx skills add ekson73/multi-agent-os`
 *
 * This module only registers a harmless lifecycle presence so the package
 * is a valid OpenCode plugin and can be listed in opencode.json.
 */

/** @param {Record<string, unknown>} ctx */
export const MaosPlugin = async (ctx) => {
  try {
    const log = ctx?.client?.app?.log
    if (typeof log === "function") {
      await log({
        body: {
          service: "opencode-maos",
          level: "info",
          message: "MAOS OpenCode plugin loaded (thin entry). Install skills via npx skills add ekson73/multi-agent-os",
        },
      })
    }
  } catch {
    // logging optional — never block startup
  }
  return {
    // Hook surface reserved for future non-skill integrations.
  }
}

export default MaosPlugin
