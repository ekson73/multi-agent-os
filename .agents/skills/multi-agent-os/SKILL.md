```markdown
# multi-agent-os Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development patterns and conventions used in the `multi-agent-os` TypeScript codebase. You'll learn about file naming, import/export styles, commit conventions, and how to write and run tests, as well as suggested commands for common workflows. This repository does not use a framework, focusing on clean TypeScript practices.

## Coding Conventions

### File Naming
- Use **PascalCase** for all file names.
  - Example: `AgentManager.ts`, `UserSession.ts`

### Import Style
- Use **relative imports** for referencing other modules.
  - Example:
    ```typescript
    import { Agent } from './Agent';
    import { SessionManager } from '../Session/SessionManager';
    ```

### Export Style
- Use **named exports** rather than default exports.
  - Example:
    ```typescript
    // Agent.ts
    export interface Agent { ... }
    export function createAgent() { ... }
    ```

### Commit Messages
- Follow **conventional commit** style.
- Use prefixes such as `docs` to indicate documentation changes.
  - Example:
    ```
    docs: update README with setup instructions
    ```

## Workflows

### Documentation Updates
**Trigger:** When updating or adding documentation.
**Command:** `/update-docs`

1. Make your documentation changes in the relevant files.
2. Use a conventional commit message with the `docs` prefix.
   - Example: `docs: add usage example to AgentManager`
3. Push your changes and open a pull request if required.

### Adding or Modifying Code
**Trigger:** When implementing new features or updating existing code.
**Command:** `/update-code`

1. Create new files using PascalCase.
2. Use relative imports and named exports.
3. Write or update TypeScript code following the code style conventions.
4. Add or update corresponding test files as needed.
5. Commit changes with a descriptive, conventional commit message.
6. Push your changes and open a pull request if required.

### Running Tests
**Trigger:** Before merging or after making code changes.
**Command:** `/run-tests`

1. Locate test files matching the `*.test.*` pattern.
2. Run the test suite using your preferred TypeScript test runner (e.g., Jest, Mocha).
   - Example command (if using Jest):
     ```
     npx jest
     ```
3. Ensure all tests pass before merging changes.

## Testing Patterns

- Test files are named with the `*.test.*` pattern (e.g., `AgentManager.test.ts`).
- The specific test framework is not specified; use your team's preferred TypeScript test runner.
- Place tests alongside the modules they test or in a dedicated `__tests__` directory.
- Example test file:
  ```typescript
  // AgentManager.test.ts
  import { createAgent } from './AgentManager';

  describe('createAgent', () => {
    it('should create a new agent with default properties', () => {
      const agent = createAgent();
      expect(agent).toBeDefined();
      // more assertions...
    });
  });
  ```

## Commands
| Command         | Purpose                                         |
|-----------------|-------------------------------------------------|
| /update-docs    | Update or add documentation                     |
| /update-code    | Add or modify code following conventions        |
| /run-tests      | Run all tests in the codebase                   |
```
