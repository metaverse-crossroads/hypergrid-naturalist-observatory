---
Title: Test Comment Masking
---

# Meta-Test: Comment Masking

**Purpose:** Verify that `[#include]` directives inside HTML comments are ignored by the parser.

**Mechanism:** This file contains a commented-out include pointing to a nonexistent file. If the parser fails to mask comments, it will try to resolve this include and fail with an error.

<!-- [#include](nonexistent_file_that_would_cause_error.md) -->

If the Director runs this scenario successfully (reporting "NO OBSERVATIONS RECORDED" or success), then the masking feature is working.
