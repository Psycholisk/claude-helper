# Fix PR Review Comments

You are tasked with addressing review comments on a Pull Request. Work through each comment methodically, making changes and responding to reviewers.

## Arguments

- **PR Link** (required): $ARGUMENTS[0] - The GitHub PR URL
- **Reviewer Filter** (optional): $ARGUMENTS[1] - Only address comments from this reviewer
- **Additional Context** (optional): $ARGUMENTS[2] - Extra context to consider

## Example Usage

```
/fix-pr-comments https://github.com/org/repo/pull/123
/fix-pr-comments https://github.com/org/repo/pull/123 johndoe
/fix-pr-comments https://github.com/org/repo/pull/123 johndoe "Focus on performance comments"
```

## Workflow

### Step 1: Fetch PR Information

Use `gh` CLI to fetch the PR details and all review comments:

```bash
# Get PR number and repo from the URL
gh pr view <PR_URL> --json number,title,body,headRefName,baseRefName

# Get all review comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments

# Get issue comments (general PR comments)
gh api repos/{owner}/{repo}/issues/{pr_number}/comments

# Get reviews with their comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
```

### Step 2: Filter and Organize Comments

1. If a **reviewer filter** is provided ($ARGUMENTS[1]), only process comments where:
   - The comment author matches the reviewer username
   - BUT also check comment threads - if the filtered reviewer replied to another comment saying "please fix this" or similar, include that original comment too

2. Group comments by file and line number for context

3. Identify comment threads (replies to comments) to understand the full conversation

### Step 3: Process Each Comment One-by-One

For EACH comment, follow this sequence before moving to the next:

#### 3a. Summarize the Comment
- Read the comment and ALL replies in its thread
- Provide a brief summary: what is being requested/suggested?
- Note if there are disagreements or resolved discussions in the thread

#### 3b. Validate in Codebase
- Read the relevant file(s) and code sections mentioned
- Determine if the comment is still applicable (code may have changed)
- Assess whether the suggested change is accurate/beneficial

#### 3c. Categorize the Comment

**Firm Changes (ALWAYS fix these):**
- Variable/function/class renames
- Code style corrections (formatting, naming conventions)
- Typo fixes
- Import reorganization
- Dead code removal
- Direct refactoring requests
- Bug fixes pointed out by reviewer
- Security concerns

**Discretionary Changes (ASK user before proceeding):**
- Architectural suggestions
- Alternative implementation approaches
- Performance optimization suggestions
- Adding new features or functionality
- Significant logic changes
- Anything where reasonable people might disagree

#### 3d. Take Action

**For Firm Changes:**
- Make the code change immediately
- No need to ask for permission

**For Discretionary Changes:**
- Present the suggestion to the user
- Explain the tradeoffs
- Ask if they want to proceed
- Only make the change if user approves

**For Questions/Clarifications from Reviewer:**
- DO NOT make code changes
- Prepare a response to answer their question
- Ask the user if your proposed response is appropriate

#### 3e. Consider Tests

After making any code change, evaluate:
- Does this change affect critical business logic?
- Is there existing test coverage for this code?
- Could this change introduce regressions?

If tests might be needed, ASK the user:
> "This change affects [describe area]. Should I add/update tests for this? [Yes/No]"

Wait for user response before proceeding.

#### 3f. Post Comment on PR

After completing each comment (whether fixed, skipped, or responded to), post a reply on that specific comment thread:

**If change was made:**
```
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies -f body="Done. [Brief description of what was changed and how]"
```

**If responding to a question:**
```
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies -f body="[Your response to their question]"
```

**If change was declined (user chose not to):**
```
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies -f body="Discussed with team - we've decided to [keep current approach / address in follow-up / etc] because [brief reason]"
```

### Step 4: Move to Next Comment

Only after completing ALL substeps (3a through 3f) for one comment, proceed to the next comment. Do not batch responses.

## Important Rules

1. **One at a time**: Process and respond to each comment individually before moving on
2. **Thread awareness**: Always read the full comment thread - a later reply might indicate the issue was already resolved or needs different handling
3. **Cross-reviewer awareness**: If reviewer A comments and reviewer B (the filtered reviewer) replies "yes, please fix this", treat it as a comment to address
4. **Preserve intent**: When making changes, preserve the original intent of the code while addressing the feedback
5. **Don't over-engineer**: Make the minimal change that addresses the feedback
6. **Commit strategically**: See the Committing Strategy section below
7. **Stay in scope**: Only address review comments, don't refactor unrelated code
8. **Be transparent**: If you're unsure about something, ask the user rather than guessing

## Committing Strategy

**Do NOT commit all changes from review comments together.** Instead, commit separately based on the size and nature of changes:

### Big Changes (commit separately)
These deserve their own commit with a descriptive message:
- Refactoring that touches multiple files
- Logic changes or bug fixes
- Adding/modifying tests
- Architectural changes
- Any change that would benefit from its own commit message explaining the "why"

### Small Changes (can be grouped)
These can be batched into a single commit:
- Typo fixes
- Variable/function renames
- Import reorganization
- Code style corrections
- Comment updates

### Commit Message Format

For individual big changes:
```
fix(pr-review): <brief description of the change>

Addresses review comment by @reviewer
```

For grouped small changes:
```
fix(pr-review): address minor review comments

- Fix typo in variable name
- Reorganize imports in file.ts
- Update comment for clarity
```

### When to Commit

- Commit a big change **immediately after making it and posting the PR comment reply**
- Accumulate small changes and commit them together after processing several comments, or at the end
- Always ensure the codebase compiles/passes linting before committing

## Error Handling

- If a comment references code that no longer exists, note this and ask user how to proceed
- If `gh` commands fail, ensure user is authenticated (`gh auth status`)
- If a comment is ambiguous, ask the user for clarification before making changes

## Output Format

For each comment, output:

```
---
## Comment #X by @reviewer
**File:** path/to/file.ts:123
**Summary:** [1-2 sentence summary]
**Category:** Firm Change / Discretionary / Question
**Action:** [What you will do]
---
```

Then perform the action, show the changes, and confirm the PR comment was posted before proceeding.
