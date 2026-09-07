// Argument-taking launcher shortcuts. Tab arms the prefix and the search
// field becomes the argument slot (dict, @engines, >, !, =).
// QML: import "arg_commands.js" as ArgCommands
// Node: require("./arg_commands.js")

function placeholder(command, entry) {
  const cmd = String(command || "")
  if (cmd === "dict") return "Type a word to translate"
  if (cmd === ">") return "Search files in ~"
  if (cmd === "!") return "Search the web"
  if (cmd === "=") return "Type an expression"
  if (entry && entry.name) return "Search " + entry.name
  if (cmd.charAt(0) === "@" && cmd.length > 1) return "Type a search term"
  return "Type an argument"
}

function join(command, arg) {
  const cmd = String(command || "")
  const a = String(arg || "")
  if (!cmd) return a
  if (cmd === ">" || cmd === "!" || cmd === "=") return a ? cmd + " " + a : cmd
  return a ? cmd + " " + a : cmd
}

function argFromQuery(query, command) {
  const q = String(query || "").trim()
  const cmd = String(command || "")
  if (!cmd) return q
  if (cmd === ">" || cmd === "!" || cmd === "=") {
    if (q.charAt(0) !== cmd) return ""
    return q.substring(1).replace(/^\s+/, "")
  }
  const low = q.toLowerCase()
  const head = cmd.toLowerCase()
  if (low === head) return ""
  if (low.indexOf(head + " ") === 0) return q.substring(cmd.length).replace(/^\s+/, "")
  return ""
}

function engineAfter(after, engines) {
  const raw = String(after || "").replace(/^\s+/, "")
  const low = raw.toLowerCase()
  const list = engines || []
  for (let i = 0; i < list.length; i++) {
    const p = String(list[i].prefix || "").toLowerCase()
    if (!p) continue
    if (low === p || low.indexOf(p + " ") === 0) {
      return {
        command: "@" + list[i].prefix,
        arg: raw.substring(p.length).replace(/^\s+/, ""),
        entry: list[i]
      }
    }
  }
  return null
}

function parse(query, engines) {
  const q = String(query || "").trim()
  if (!q) return null
  if (/^dict(?:\s|$)/i.test(q)) {
    return { command: "dict", arg: q.replace(/^dict\s*/i, "") }
  }
  if (q.charAt(0) === ">") return { command: ">", arg: q.substring(1).replace(/^\s+/, "") }
  if (q.charAt(0) === "!") return { command: "!", arg: q.substring(1).replace(/^\s+/, "") }
  if (q.charAt(0) === "=") return { command: "=", arg: q.substring(1).replace(/^\s+/, "") }
  if (q.charAt(0) === "@") {
    const after = q.substring(1)
    if (!String(after || "").trim()) return { command: "@", arg: "" }
    const hit = engineAfter(after, engines)
    if (hit) return { command: hit.command, arg: hit.arg }
    return null
  }
  return null
}

function uniqueEngine(query, engines) {
  let s = String(query || "").trim()
  if (s.charAt(0) !== "@") return null
  s = s.substring(1).replace(/^\s+/, "").toLowerCase()
  if (!s) return null
  const list = engines || []
  const hits = []
  for (let i = 0; i < list.length; i++) {
    const p = String(list[i].prefix || "").toLowerCase()
    if (!p) continue
    if (p === s || p.indexOf(s) === 0) hits.push(list[i])
  }
  return hits.length === 1 ? hits[0] : null
}

function entryCommand(entry) {
  if (!entry) return ""
  if (entry.prefix && (entry.special === "web" || entry.special === "doc")) {
    return "@" + entry.prefix
  }
  if (entry.id === "dict-prompt") return "dict"
  if (entry.special === "dict" && !entry.copy) return "dict"
  return ""
}

// Tab arms when the query or the selected row is a prefix with no argument yet.
// Already-filled arguments return null so Tab keeps walking the result list.
function tabArm(query, entry, engines) {
  const fromEntry = entryCommand(entry)
  if (fromEntry) {
    const arg = argFromQuery(query, fromEntry)
    if (arg) return null
    return { command: fromEntry, placeholder: placeholder(fromEntry, entry) }
  }
  const parsed = parse(query, engines)
  if (parsed) {
    if (parsed.command === "@") return null
    if (parsed.arg) return null
    return { command: parsed.command, placeholder: placeholder(parsed.command) }
  }
  const engine = uniqueEngine(query, engines)
  if (engine) {
    return { command: "@" + engine.prefix, placeholder: placeholder("@" + engine.prefix, engine) }
  }
  return null
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    placeholder: placeholder,
    join: join,
    argFromQuery: argFromQuery,
    parse: parse,
    uniqueEngine: uniqueEngine,
    entryCommand: entryCommand,
    tabArm: tabArm
  }
}
