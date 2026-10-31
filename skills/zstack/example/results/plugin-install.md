# Plugin install runs

Recorded 2026-10-30 on macOS against a local checkout of this repo, each harness pointed at a throwaway
config folder so no real profile was touched. Temp paths are shown as `<tmp>` and the checkout as
`<zstack checkout>`. The CLIs' status symbols are shown as `[ok]`, `[warn]` and `>`. For the published repo, replace the checkout path with `simsketch/zstack`.

## Summary

| Check | Claude Code 2.1.314 | Codex CLI 0.163.0 |
|---|---|---|
| Marketplace add | passed | passed |
| Plugin install | `claude plugin install zstack@zstack` passed; one step `claude plugin install zstack --marketplace <source>` passed | `codex plugin add zstack@zstack` passed |
| Listed as | installed, enabled, 1.0.0 | installed, enabled, 1.0.0 |
| Skill name on this route | `zstack:zstack` (session init lists the skill and slash command as `zstack:zstack`) | `zstack:zstack` (`codex debug prompt-input` lists `zstack:zstack` under Available skills) |
| Session-start hook | ran at startup, exit 0, printed the two-line hint | not live-tested (see below) |
| `claude plugin validate .` | passed (three listing warnings: no icon, and the `<owner>` placeholder URLs, recorded before the owner was set to simsketch) | n/a |

The headless Claude Code session stopped at "Not logged in" after startup, which is expected for a fresh
config folder; the skill list and the hook output come from the session's init and hook events, which
run before login is needed.

Codex hook: Codex 0.163.0 only runs a plugin's hooks after the user reviews and trusts them, so a
non-interactive run in a fresh `CODEX_HOME` never fired it. The Codex binary names `PLUGIN_ROOT` and
`CLAUDE_PLUGIN_ROOT` beside its hook settings, so `hooks/codex-hooks.json` resolves the script from
either variable and exits 0 with no output when neither is set (`tests/test_hooks.sh` covers all three
cases). The hook is not live-tested on Codex.

## Claude Code session

```
$ export CLAUDE_CONFIG_DIR=$(mktemp -d)
$ claude plugin marketplace add <zstack checkout>
Adding marketplace...[ok] Successfully added marketplace: zstack (declared in user settings)
(exit 0)

$ claude plugin install zstack@zstack
Installing plugin "zstack@zstack"...[ok] Successfully installed plugin: zstack@zstack (scope: user)
(exit 0)

$ claude plugin list
Installed plugins:

  > zstack@zstack
    Version: 1.0.0
    Read from: <zstack checkout>
    Scope: user
    Status: [ok] enabled

(exit 0)

$ claude plugin details zstack@zstack
zstack 1.0.0
  Description: A harness-agnostic engineering skill that routes each task to a playbook and a set of working principles, with small scripts for checks, evidence and handoffs.
  Source: zstack@zstack

Component inventory
  Skills (1)  zstack
  Agents (0)
  Hooks (1)  SessionStart  (harness-only — no model context cost)
  MCP servers (0)
  LSP servers (0)

Projected token cost
  Always-on:   ~164 tok   added to every session

Per-component (rounded)
  component  always-on  on-invoke
  zstack          ~160      ~3.8k

  On-invoke cost is paid each time a skill or agent fires.
  Token counts are estimates and may differ from actual usage.
(exit 0)

$ export CLAUDE_CONFIG_DIR=$(mktemp -d)   # a second clean profile for the one-step form
$ claude plugin install zstack --marketplace <zstack checkout>
Adding marketplace...
[ok] Successfully added marketplace: zstack (declared in user settings)
Installing plugin "zstack@zstack"...[ok] Successfully installed plugin: zstack@zstack (scope: user)
(exit 0)

$ claude plugin validate <zstack checkout>
Validating marketplace manifest: <zstack checkout>/.claude-plugin/marketplace.json

Plugin directory checks for <zstack checkout>. The plugin directory is the catalog that plugins are submitted to; this is a subset of what it runs.

[warn] Found 3 plugin directory warnings:

  > .claude-plugin/plugin.json icon: No icon (ICON_MISSING). No icon found in the plugin. The validator looked for `icon` in plugin.json and for a file at .claude-plugin/icon.png or .svg, assets/icon.png or .svg, or a similar path.
    Fix: Add a square PNG to the plugin folder at .claude-plugin/icon.png, or set `icon` in plugin.json to the path of a square PNG or JPEG in the plugin: 512 to 2048 px on each side, under 2 MB. SVG and WebP are not accepted. That file may become the listing icon only once: the first time the plugin is saved or submitted in the developer portal. Adding or changing it later does not change the icon.
  > .claude-plugin/plugin.json homepage: Listing link or icon path not accepted (LISTING_URL_SCHEME). homepage "https://github.com/<owner>/zstack" is not https://; it was dropped from the listing preview.
    Fix: Use an https:// URL.
  > .claude-plugin/plugin.json repository: Listing link or icon path not accepted (LISTING_URL_SCHEME). repository "https://github.com/<owner>/zstack" is not https://; it was dropped from the listing preview.
    Fix: Use an https:// URL.

About these checks:

  > This folder also holds a marketplace manifest. The plugin directory treats such a folder as a plugin, so these checks cover only the plugin in this folder. To check another plugin that the marketplace lists, run validate on that plugin's folder.

These plugin directory checks do not change the result below.

The directory also runs a safety scan and a policy review that this command does not.

[ok] Validation passed
(exit 0)
```

Session start in that profile (`claude -p --output-format stream-json --verbose --include-hook-events`), relevant events:

```
hook SessionStart:startup exit 0 stdout:
zStack is installed. For multi-file changes, design choices, bugs with an unknown cause, performance work, or any request to run work in parallel, start with the zstack skill.
It picks a playbook, names the principles it applies, and reports what each one changed.
init skills: ['zstack:zstack']  slash_commands: ['zstack:zstack']
result: Not logged in · Please run /login
```

## Codex session

```
$ export CODEX_HOME=$(mktemp -d)
$ codex plugin marketplace add <zstack checkout>
Added marketplace `zstack` from <zstack checkout>.
Installed marketplace root: <zstack checkout>
(exit 0)

$ codex plugin add zstack@zstack
Added plugin `zstack` from marketplace `zstack`.
Installed plugin root: <tmp>/plugins/cache/zstack/zstack/1.0.0
(exit 0)

$ codex plugin list
Marketplace `zstack`
<zstack checkout>/.agents/plugins/marketplace.json

PLUGIN         STATUS              VERSION  SOURCE
zstack@zstack  installed, enabled  1.0.0    <zstack checkout>
(exit 0)
```

`codex debug prompt-input "hello"` in that `CODEX_HOME`, the matching line:

```
- zstack:zstack: Routes a non-trivial engineering goal to a playbook, an execution shape and a set of cited principles. ...
```
