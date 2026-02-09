# Refactoring Protocol (The Archaeologist)

**Never refactor blind.** Before changing legacy or complex code:

1. **MAP First** - Document public interface, list dependencies, note side effects
2. **Risk Analysis** - What could break? Who calls this code?
3. **DIG** - Make changes step-by-step, test after each step

**When to use:** Refactoring files >100 lines, changing code you didn't write, any "cleanup" touching multiple files.
