# Skill Writer — Reference

Read this when a Skill silently fails to activate, throws Skill-loading errors, or conflicts with another Skill — the deeper diagnostic detail that the main instructions only summarize.

## Debug if needed

If the agent doesn't use the Skill:

1. **Make description more specific**:
   - Add trigger words
   - Include file types
   - Mention common user phrases

2. **Check file location**:
   ```bash
   # Claude Code
   ls ~/.claude/skills/skill-name/SKILL.md
   ls .claude/skills/skill-name/SKILL.md

   # Other agents: check your agent's skill directory
   ```

3. **Validate YAML**:
   ```bash
   cat SKILL.md | head -n 10
   ```

4. **Run debug mode** (agent-specific):
   ```bash
   # Claude Code
   claude --debug

   # Other agents: check your agent's debug/verbose flag
   ```

## Troubleshooting

**Skill doesn't activate**:
- Make description more specific with trigger words
- Include file types and operations in description
- Add "Use when..." clause with user phrases

**Multiple Skills conflict**:
- Make descriptions more distinct
- Use different trigger words
- Narrow the scope of each Skill

**Skill has errors**:
- Check YAML syntax (no tabs, proper indentation)
- Verify file paths (use forward slashes)
- Ensure scripts have execute permissions
- List all dependencies
