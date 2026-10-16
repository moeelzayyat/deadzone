# Git mirror — export procedure

`mirror/src/` is a read-only copy of every script in the place, exported at every checkpoint (step 6) and before Script Analysis (step 2, D-014). It is never edited by hand and never imported back into Studio. Built in A1.3; method in D-015.

## Mapping
| Studio | Mirror |
|---|---|
| `ReplicatedStorage/Shared/...` | `mirror/src/shared/...` |
| `ServerScriptService/Server/...` | `mirror/src/server/...` |
| `StarterPlayer/StarterPlayerScripts/Client/...` | `mirror/src/client/...` |
| `ServerStorage/Tests/...` | `mirror/src/tests/...` |
| Script / LocalScript / ModuleScript | `<Name>.server.luau` / `<Name>.client.luau` / `<Name>.luau` |
| StringValue (license text) | `<Name>.txt` |

Names keep their dots (`TestRunner.spec` → `TestRunner.spec.luau`). Folders become directories; a folder with no scripts below it has no directory. `mirror/sourcemap.json` holds the whole tree of the four roots (every instance) so luau-lsp can resolve `require` paths.

The export refuses to run (lists `errors`, writes nothing) when the one-to-one mapping would break:
- a script anywhere in the place outside the four roots (Workspace, StarterGui, ServerStorage outside `Tests`, ...);
- a script or StringValue nested inside another script or StringValue;
- two siblings whose names differ only by case (one file on Windows);
- a name that can't be a Windows file name (`<>:"/\|?*`, control characters, trailing dot or space, empty).

## Steps
1. **Export (Studio).** Paste the whole of `tools/mirror_export.luau` into `execute_luau` (datamodel **Edit**). It is read-only. The result is one JSON string with a manifest (path, class, byte length, FNV-1a of every script and StringValue), the tree, the DataModel-wide script count, and as many source texts as fit in ~95K characters.
   - Results under ~64K are inlined into the conversation, so the export pads them to 66K; the harness then saves the result to a `tool-results` file. Use that file path in step 2.
   - If the result has `"next": N`, run the export again with `START = N` and keep every result file. Results over 100K are truncated by `execute_luau`; the 95K limit avoids that.
   - Vendor code (`*/Vendor/*`) is not re-sent by default: it is pinned (ART_SOURCES.md) and the existing mirror copy is hash-checked against Studio. If a vendor module changed on purpose, run with `INCLUDE_VENDOR = true`.
2. **Write (local).** From the repo root: `python tools/mirror_write.py <result file> [<more result files>]`. It
   - writes every source that was sent;
   - checks every manifest entry's file by length + FNV-1a against Studio (`OK` / `BAD` / `MISSING`);
   - deletes mirror files that no longer exist in Studio (`DEL`) and empty directories;
   - regenerates `mirror/sourcemap.json`;
   - prints the count check `scripts: DataModel N · under roots N · mirror N · StringValues: studio M · mirror M · MATCH`.
   It exits 0 and prints `ALL OK` only when every file matches and the counts are equal. It refuses incomplete chunk sets and parts taken from different Studio states.
3. **Cross-check.** `script_search` (Studio MCP) lists scripts by name, capped at 10 results; while the place has 10 scripts or fewer, its count must equal the mirror's `.luau` count. Past that, the export's DataModel-wide count (step 1) is the reference.
4. **Analyze.** `bash tools/analyze.sh` → `diagnostics: 0` (D-014).
5. **Commit** `mirror/` with the substage ID in the message.

## Notes
- Hash: FNV-1a 32-bit over the UTF-8 bytes. In Luau the multiply is split as `(bit32.lshift(h, 24) + h * 403) % 2^32` because `h * 16777619` loses precision in a double.
- `.gitattributes` stores text as LF. The writer warns if a source contains CR characters, which would make the committed file differ from Studio.
- Hand edits to the mirror are overwritten by the next export (non-vendor) or reported as `BAD` (vendor).
