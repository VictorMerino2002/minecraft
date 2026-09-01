### Minecraft

CC: Tweaked programs for in-game computers and turtles.

## clone.lua

Downloads a single folder (and branch) of this repo onto an in-game
computer through the HTTP API. CC: Tweaked has no `git`, so this is the
way to pull code in.

### Install

```
wget https://raw.githubusercontent.com/VictorMerino2002/minecraft/main/clone.lua clone.lua
```

### Usage

```
clone <folder> [branch] [destination]
```

| Argument      | Default          | Description                                  |
| ------------- | ---------------- | -------------------------------------------- |
| `folder`      | *(required)*     | Repo folder to download, e.g. `core`. Use `.` or `/` for the whole repo. |
| `branch`      | `main`           | Branch to pull from.                         |
| `destination` | same as `folder` | Local path to write the files to.            |

### Examples

```
clone core                 -- core/ from main  -> /core
clone core dev             -- core/ from dev   -> /core
clone core main /lib/core  -- core/ from main  -> /lib/core
```

### Behavior

- Lists the branch tree via `api.github.com`, then downloads each file
  under `folder/` from `raw.githubusercontent.com`.
- The `folder/` prefix is stripped, so `core/turtle.lua` lands at
  `<destination>/turtle.lua`.
- Existing files are overwritten; files removed from the repo are **not**
  deleted locally. For a clean sync, delete the destination folder first.

### Requirements

HTTP must be enabled in `computercraft-server.toml` (it is by default) and
the access rules must allow `api.github.com` and `raw.githubusercontent.com`
(the default `"*" allow` rule covers them).
