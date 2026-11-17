# launchly skills

Agent skills for [launchly](https://launchly.ai). launchly turns anything your AI agent builds into a live, shareable link — no Git, no hosting setup.

This repository holds one skill, `launchly`. With it, an agent can publish an HTML page or a folder of built files and hand you back a link. New pages are private: only your workspace and the people you invite can open them.

## What is in here

| Path                   | What it is                                                             |
| ---------------------- | ---------------------------------------------------------------------- |
| `launchly/SKILL.md`    | The instructions your agent reads, in the agent-skills format          |
| `launchly/launchly.sh` | One shell script the agent runs to connect, publish and list sites     |

The skill works with any agent that reads skills or can run a script.

## Install

Copy the `launchly` folder into the folder your agent reads skills from. For Claude Code:

```bash
git clone https://github.com/launchly-ai/skills.git
mkdir -p ~/.claude/skills
cp -R skills/launchly ~/.claude/skills/launchly
```

For another agent, use its skills folder instead; the docs for each agent are at [docs.launchly.ai](https://docs.launchly.ai).

Then ask your agent: "Publish this page with launchly."

## Do you need the skill?

Maybe not. If your agent can add an MCP server and open a browser (Claude, Claude Code, ChatGPT, Cursor and Codex can), add `https://app.launchly.ai/api/mcp` as a remote MCP server. You sign in, pick a workspace, and the agent gets its tools with no key and no script.

The skill is for agents that only have a terminal, and for people who prefer a script they can read.

## Use the script yourself

You do not need an agent to run it.

```bash
cd launchly

# Connect this machine, once. Prints a link and a short code.
./launchly.sh connect "My laptop"

# Publish a folder that contains index.html, or a single HTML file.
./launchly.sh publish ./dist --name "Q3 report"
./launchly.sh publish ./report.html --name "Q3 report"

# Publish a new version of a site that exists. The address stays the same.
./launchly.sh publish ./dist --site q3-report --message "fixed the totals"

# List the sites in the workspace, as JSON.
./launchly.sh sites
```

`connect` prints a link and a code. Open the link, check that the page shows the same code, sign in (an email address is enough to sign up), pick a workspace and approve. You have ten minutes. The script then saves an API key for that workspace.

`publish` prints the URL, the site's slug and who can open it.

launchly serves the files you send as they are. It does not run builds or server code, so build first and publish the output.

## Requirements

- `curl` and `python3` (to read JSON)
- `zip`, for publishing

## Settings

| Variable            | What it does                                              | Default                    |
| ------------------- | --------------------------------------------------------- | -------------------------- |
| `LAUNCHLY_API_KEY`  | Use this key (it starts with `lk_`) and skip `connect`    | not set                    |
| `LAUNCHLY_KEY_FILE` | Where `connect` saves the key                             | `~/.config/launchly/key`   |
| `LAUNCHLY_URL`      | The launchly address to talk to                           | `https://app.launchly.ai`  |

## Your key

The key gives access to one workspace. `connect` saves it in a file only you can read. Keep it out of chat messages, commits, logs and the pages you publish. To take access back, revoke the key in the workspace settings at [app.launchly.ai](https://app.launchly.ai).

## More

- Docs: [docs.launchly.ai](https://docs.launchly.ai)
- Instructions written for agents, always current: [app.launchly.ai/api/agent.md](https://app.launchly.ai/api/agent.md)
- REST API description: [app.launchly.ai/api/spec.json](https://app.launchly.ai/api/spec.json)

The skill is developed together with the launchly API and copied here on each change.

## Licence

[MIT](LICENSE).
