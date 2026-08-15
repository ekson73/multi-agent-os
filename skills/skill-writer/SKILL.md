---
name: skill-writer
description: Creates and maintains Agent Skills following the open standard (compatible with 30+ AI tools). Use when the user wants to create a new Skill, update an existing SKILL.md's structure, content, or frontmatter, validate a Skill against the spec, audit or rewrite a Skill's description for reliable triggering, debug why a Skill isn't activating, or convert an existing prompt or workflow into a reusable Skill.
---

# Skill Writer

This Skill helps you create well-structured Agent Skills that follow the [Agent Skills open standard](https://agentskills.io) — compatible with Claude Code, Cursor, Codex, Gemini CLI, Kiro, VS Code, GitHub Copilot, Goose, and 25+ other AI tools.

## Instructions

### Step 1: Determine Skill scope

First, understand what the Skill will do:

1. **Ask clarifying questions**:
   - What specific capability should this Skill provide?
   - When should the agent use this Skill?
   - What tools or resources does it need?
   - Is this for personal use or team sharing?

2. **Keep it focused**: One Skill = one capability
   - Good: "PDF form filling", "Excel data analysis"
   - Too broad: "Document processing", "Data tools"

### Step 2: Choose Skill location

Determine where to create the Skill:

**Personal Skills** (user-scoped, not committed to git):
- Individual workflows and preferences
- Experimental Skills
- Personal productivity tools
- Claude Code: `~/.claude/skills/` | Other agents: check your agent's docs for user skill path

**Project Skills** (committed to git, shared with team):
- Team workflows and conventions
- Project-specific expertise
- Shared utilities
- Claude Code: `.claude/skills/` | Other agents: project root or `.agent/skills/`

### Step 3: Create Skill structure

Create the directory and files:

```bash
# Personal
mkdir -p ~/.claude/skills/skill-name

# Project
mkdir -p .claude/skills/skill-name
```

For multi-file Skills:
```
skill-name/
├── SKILL.md (required)
├── reference.md (optional)
├── examples.md (optional)
├── scripts/
│   └── helper.py (optional)
└── templates/
    └── template.txt (optional)
```

### Step 4: Write SKILL.md frontmatter

Create YAML frontmatter with required fields:

```yaml
---
name: skill-name
description: Brief description of what this does and when to use it
---
```

**Field requirements**:

- **name**:
  - Lowercase letters, numbers, hyphens only — becomes the invocation slug parsed programmatically across 30+ tools
  - Max 64 characters — frontmatter field limit enforced by the spec
  - Must match directory name — the loader resolves a Skill by its directory, so a mismatch breaks discovery
  - Good: `pdf-processor`, `git-commit-helper`
  - Bad: `PDF_Processor`, `Git Commits!`

- **description**:
  - Max 1024 characters — frontmatter field limit; longer text gets truncated by loaders
  - Include BOTH what it does AND when to use it — the agent decides whether to invoke the Skill from the description alone, before reading the body
  - Use specific trigger words users would say — matches how agents index descriptions against real user queries
  - Mention file types, operations, and context — sharpens matching accuracy for the phrasing users actually use

**Optional frontmatter fields**:

- **allowed-tools**: Restrict tool access (comma-separated list)
  ```yaml
  allowed-tools: Read, Grep, Glob
  ```
  Use for:
  - Read-only Skills
  - Security-sensitive workflows
  - Limited-scope operations

### Step 5: Write effective descriptions

The description is critical for the agent to discover your Skill.

**Formula**: `[What it does] + [When to use it] + [Key triggers]`

**Examples**:

✅ **Good**:
```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

✅ **Good**:
```yaml
description: Analyze Excel spreadsheets, create pivot tables, and generate charts. Use when working with Excel files, spreadsheets, or analyzing tabular data in .xlsx format.
```

❌ **Too vague**:
```yaml
description: Helps with documents
description: For data analysis
```

**Tips**:
- Include specific file extensions (.pdf, .xlsx, .json)
- Mention common user phrases ("analyze", "extract", "generate")
- List concrete operations (not generic verbs)
- Add context clues ("Use when...", "For...")

### Step 6: Structure the Skill content

Use clear Markdown sections:

```markdown
# Skill Name

Brief overview of what this Skill does.

## Quick start

Provide a simple example to get started immediately.

## Instructions

Step-by-step guidance for the agent:
1. First step with clear action
2. Second step with expected outcome
3. Handle edge cases

## Examples

Show concrete usage examples with code or commands.

## Best practices

- Key conventions to follow
- Common pitfalls to avoid
- When to use vs. not use

## Requirements

List any dependencies or prerequisites:
```bash
pip install package-name
```

## Advanced usage

For complex scenarios, see [reference.md](reference.md).
```

### Step 7: Add supporting files (optional)

Create additional files for progressive disclosure:

**reference.md**: Detailed API docs, advanced options
**examples.md**: Extended examples and use cases
**scripts/**: Helper scripts and utilities
**templates/**: File templates or boilerplate

Reference them from SKILL.md:
```markdown
For advanced usage, see [reference.md](reference.md).

Run the helper script:
\`\`\`bash
python scripts/helper.py input.txt
\`\`\`
```

### Step 8: Validate the Skill

Check these requirements:

✅ **File structure**:
- [ ] SKILL.md exists in correct location — the loader only scans known Skill directories
- [ ] Directory name matches frontmatter `name` — a mismatch breaks discovery (loader resolves by directory)

✅ **YAML frontmatter**:
- [ ] Opening `---` on line 1 — required delimiter for the parser to recognize frontmatter
- [ ] Closing `---` before content — malformed delimiters fail parsing and disable the whole Skill
- [ ] Valid YAML (no tabs, correct indentation) — a parse error disables the whole Skill, not just the bad field
- [ ] `name` follows naming rules — see field requirements above
- [ ] `description` is specific and < 1024 chars — see field requirements above

✅ **Content quality**:
- [ ] Clear instructions for the agent — the agent follows these verbatim when invoked; ambiguity causes wrong behavior
- [ ] Concrete examples provided — reduces the agent's need to guess intended usage
- [ ] Edge cases handled — prevents failure on non-happy-path inputs
- [ ] Dependencies listed (if any) — the agent needs prerequisites known before it can execute the steps

✅ **Testing**:
- [ ] Description matches user questions — validates real-world triggering before shipping
- [ ] Skill activates on relevant queries — confirms discovery actually works end-to-end
- [ ] Instructions are clear and actionable — confirms the Skill is usable, not just discoverable

### Step 9: Test the Skill

1. **Restart your agent** (if running) to load the Skill

2. **Ask relevant questions** that match the description:
   ```
   Can you help me extract text from this PDF?
   ```

3. **Verify activation**: the agent uses the Skill automatically

4. **Check behavior**: confirm the agent follows the instructions correctly

### Step 10: Debug if needed

If the agent doesn't use the Skill, make the description more specific (trigger words, file types, "Use when..." phrases). For the full checklist — file-location checks, YAML validation, agent debug-mode flags — see [reference.md](reference.md); read it when a Skill silently fails to activate or throws Skill-loading errors.

## Common patterns

For copy-paste-ready starting points (read-only Skill, script-based Skill, multi-file Skill with progressive disclosure), see [examples.md](examples.md); read it when starting a new Skill and you want a working template to adapt.

## Best practices for Skill authors

1. **One Skill, one purpose**: Don't create mega-Skills
2. **Specific descriptions**: Include trigger words users will say
3. **Clear instructions**: Write for the agent, not humans
4. **Concrete examples**: Show real code, not pseudocode
5. **List dependencies**: Mention required packages in description
6. **Test with teammates**: Verify activation and clarity
7. **Version your Skills**: Document changes in content
8. **Use progressive disclosure**: Put advanced details in separate files

## Validation checklist

Before finalizing a Skill, verify:

- [ ] Name is lowercase, hyphens only, max 64 chars — see field requirements in Step 4
- [ ] Description is specific and < 1024 chars — see field requirements in Step 4
- [ ] Description includes "what" and "when" — the agent invokes from the description alone
- [ ] YAML frontmatter is valid — a parse error disables the whole Skill
- [ ] Instructions are step-by-step — the agent follows them verbatim; ambiguity causes wrong behavior
- [ ] Examples are concrete and realistic — reduces the agent's need to guess intended usage
- [ ] Dependencies are documented — the agent needs prerequisites known before it can execute the steps
- [ ] File paths use forward slashes — keeps references portable across the 30+ compatible tools/OSes
- [ ] Skill activates on relevant queries — confirms discovery actually works end-to-end
- [ ] Agent follows instructions correctly — confirms the Skill is usable, not just discoverable

## Troubleshooting

See [reference.md](reference.md) for the troubleshooting playbook (activation failures, Skill conflicts, YAML/path errors); read it when a Skill you already wrote starts misbehaving.

## Examples

See the documentation for complete examples:
- Simple single-file Skill (commit-helper)
- Skill with tool permissions (code-reviewer)
- Multi-file Skill (pdf-processing)

## Output format

When creating a Skill, I will:

1. Ask clarifying questions about scope and requirements
2. Suggest a Skill name and location
3. Create the SKILL.md file with proper frontmatter
4. Include clear instructions and examples
5. Add supporting files if needed
6. Provide testing instructions
7. Validate against all requirements

The result will be a complete, working Skill that follows all best practices and validation rules.

## Related skills (lifecycle: create → evaluate → train)

`skill-writer` (this skill) handles **authoring**. After a skill exists:

- **Evaluate** it behaviorally → `agentic-tool-evaluator` ("is this skill good? does it trigger? did it regress?").
- **Improve** it over time, OR **distill** a new skill from an observed human↔agent task → `agentic-tool-trainer` (trace→reflect→distill).

Shared vocabulary/taxonomy/rubric/Rovo-bridge: `protocols/agentic-tool-lifecycle.md`. For **agents** (not skills), the authoring + 33-Socratic-Question + KPI counterpart is `agents/forge.md`.
