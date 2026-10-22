#!/usr/bin/env bash
# Claude Code PreToolUse hook (.claude/settings.json) for Bash: refuses `gh pr create` and
# `gh pr edit --body…` unless the body has the mattpocock-skills:pr sections, so a PR body is
# always written with that skill (docs/agents/ticket-workflow.md, PR). The body is read from the
# command itself (--body, or a heredoc with --body-file -) and from a --body-file path.
# Exit 2 blocks the call and shows stderr to the agent.
input="$(cat)"
python3 -I - "$input" <<'PY'
import json, re, shlex, sys

command = json.loads(sys.argv[1]).get("tool_input", {}).get("command", "")
if not re.search(r"\bgh\s+pr\s+(create|edit)\b", command):
    sys.exit(0)
if re.search(r"\bgh\s+pr\s+edit\b", command) and "--body" not in command:
    sys.exit(0)

body = command
match = re.search(r"--body-file[ =](\S+)", command)
if match and match.group(1) != "-":
    try:
        path = shlex.split(match.group(1))[0]
        body += open(path).read()
    except (OSError, ValueError, IndexError):
        # A path with a shell variable can't be read here.
        print(f"Can't read the PR body file {match.group(1)}: give its literal path, in a command of "
              "its own.", file=sys.stderr)
        sys.exit(2)

missing = [s for s in ("## Summary", "## Evidence", "## Merge Danger") if s not in body]
if missing:
    print(f"PR body is missing {', '.join(missing)}. Write it with the mattpocock-skills:pr skill "
          "(Skill tool), then run the command again.", file=sys.stderr)
    sys.exit(2)
PY
