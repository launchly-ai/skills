---
name: launchly
description: Publish an HTML page or a built site to launchly and get a live, private link to share. Use when the user asks to publish, host, deploy or share a page, report, dashboard, prototype or static site you made, or mentions launchly. Not for anything that needs a server, a database or a build on the host.
---

# launchly

launchly turns anything your AI agent builds into a live, shareable link — no Git, no hosting setup.

You give it one HTML page or a folder of built files with an `index.html`. It gives back a URL on `launchly.site`. It does not run builds or server code: build locally first, then publish the output.

## Connect (once)

If your client can add an MCP server and open a browser, prefer that: add `https://app.launchly.ai/api/mcp` as a remote MCP server with no key. The user signs in and approves, and you get tools (`publish`, `set_access`, `invite_viewers`, `rollback` and others). Then skip the script below.

Otherwise connect from the terminal:

```bash
./launchly.sh connect "<your name, as the user should see it>"
```

It prints a link and a short code. Show both to the user, in these words or close to them:

> Open <link> and check that it shows the code <code>.

The user opens the link, signs in (or signs up with just an email), picks a workspace and approves. The script then saves an API key for that workspace in `~/.config/launchly/key`, readable only by the user. They have ten minutes.

If the user already has a key (it starts with `lk_`), set `LAUNCHLY_API_KEY` instead. Never ask the user to paste a key into the chat when `connect` can be used, never guess a key, and never create an account for them.

## Publish

A folder (it must contain `index.html`), or a single `.html` file:

```bash
./launchly.sh publish ./dist --name "Q3 report"
./launchly.sh publish ./report.html --name "Q3 report"
```

That creates a new site and prints its URL, its slug, and who can open it. To publish a new version of a site that exists, pass its slug; the address stays the same:

```bash
./launchly.sh publish ./dist --site q3-report --message "fixed the totals"
```

`./launchly.sh sites` lists the workspace's sites as JSON.

To keep the source next to the build, publish a folder with `build/` (served) and `src/` (archived).

## What to tell the user

- **Give them the URL and say who can open it.** A new site is private: only members of the workspace and the people the user invites can open it. The script prints that sentence; pass it on.
- **Ask before opening a page up.** Making a site reachable by anyone with the link, or public, is the user's decision.
- **Invite only addresses the user gave you.**
- **Say when you replaced something.** Publishing to an existing site changes what its address shows. Earlier versions are kept and can be restored in the dashboard.

Changing who can view a site, inviting people and restoring a version are in the dashboard at `https://app.launchly.ai`, in the MCP tools, and in the REST API (`https://app.launchly.ai/api/spec.json`).

## Requirements and secrets

The script needs `curl` and `python3`; publishing also needs `zip`. Set `LAUNCHLY_URL` to use another launchly address.

Keep the API key out of anything that can be read back: chat messages, commits, logs and the pages you publish.

The complete, current instructions for agents are at `https://app.launchly.ai/api/agent.md`.
