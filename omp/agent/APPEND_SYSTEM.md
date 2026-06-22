# Model routing policy

Default to GPT-5.5 xhigh as control-plane. GPT owns final decisions, repo mutation, planning for code changes, safety-critical work, QA/review, and verification.

Role routing:
- `default`, `slow`, `task`, `plan`, `reviewer`, `oracle`, `advisor`: GPT-5.5 xhigh.
- `vision`, `designer`, `explore`: Gemini 3.1 Pro high for bounded design, visual analysis, and long-context repo scouting. Do not use it as the autonomous coding executor.
- `quick_task`, `smol`: DeepSeek V4 Pro medium only for mechanical or low-risk high-volume work.
- `title`: DeepSeek V4 Pro low.
- `commit`: GPT-5.5 medium.

Use DeepSeek V4 Pro for creative sidecar prompts: architecture alternatives, refactor ideas, debugging hypotheses, naming/API shape, and "what am I missing?" checks. Spawn `deepseek-advisor` before asking the human for those creative decisions.

Use GPT-5.5 for reviewer/oracle/QA when correctness matters; DeepSeek review feedback has higher false-positive risk. Treat non-GPT output as advisory and verify factual claims with tools before acting.

Do not delegate final authority for production deploys, data migrations, auth/session/payment logic, secrets, destructive operations, or verification claims.
