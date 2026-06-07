.pragma library

// Sentinels for category drills that pivot to special handling.
const fileCategory = "Files"

// fd excludes (same as launcher ref for build dirs).
const fdExcludes = [
  "node_modules", "target", "dist", "build", ".cache",
  ".venv", "__pycache__", ".tox", ".next", ".nuxt"
]

const imageExts = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "ico", "avif", "svg"]
const textExts = [
  "md", "txt", "qml", "lua", "toml", "sh", "bash", "zsh", "fish",
  "py", "js", "mjs", "cjs", "ts", "tsx", "jsx", "json", "jsonc",
  "yaml", "yml", "rs", "go", "c", "h", "cpp", "hpp", "cc", "hh",
  "html", "css", "scss", "conf", "ini", "cfg", "log", "csv", "xml",
  "rb", "java", "kt", "swift", "php", "sql", "vim", "el", "tex",
  "gitignore", "gitconfig", "dockerfile", "makefile", "env"
]

const fileIcons = {
  "dir": "󰉋", "file": "󰈔",
  "png": "󰋩", "jpg": "󰋩", "jpeg": "󰋩", "webp": "󰋩", "gif": "󰋩",
  "bmp": "󰋩", "ico": "󰋩", "avif": "󰋩", "svg": "󰜡",
  "mp4": "󰕧", "mkv": "󰕧", "webm": "󰕧", "mov": "󰕧", "avi": "󰕧",
  "mp3": "󰝚", "flac": "󰝚", "ogg": "󰝚", "wav": "󰝚",
  "pdf": "󰈦", "zip": "󰗄", "tar": "󰗄", "gz": "󰗄", "bz2": "󰗄", "xz": "󰗄", "7z": "󰗄", "rar": "󰗄",
  "md": "󰍔", "txt": "󰈙", "json": "󰘦", "py": "󰌠", "sh": "󱆃",
  "lua": "󰢱", "qml": "󰢫",
  "ini": "󰒓", "conf": "󰒓", "cfg": "󰒓", "toml": "󰒓", "yaml": "󰒓", "yml": "󰒓",
  "c": "󰙱", "h": "󰙱", "cpp": "󰙲", "hpp": "󰙲", "cc": "󰙲", "hh": "󰙲",
  "rs": "󱘗", "go": "󰟓", "js": "󰌞", "ts": "󰛦", "jsx": "󰜈", "tsx": "󰜈",
  "html": "󰌝", "css": "󰌜", "scss": "󰌜", "log": "󰦪", "csv": "󰈛",
  "dockerfile": "󰡨", "makefile": "󰣪", "license": "󰿃", "readme": "󰋽",
  "code": "󰅩", "config": "󰒓", "archive": "󰀼"
}

const categoryNav = [
  { title: "Quick", icon: "󱎫", category: "Browse", isCategory: true, target: "Quick", keywords: "quick settings dashboard hub overview battery audio wifi bt display media screenshots wallpaper storage disk space du" },
  { title: "Apps", icon: "󰀻", category: "Browse", isCategory: true, target: "App", keywords: "apps applications launcher programs software desktop" },
  { title: "Files", icon: "󰉋", category: "Browse", isCategory: true, target: fileCategory, keywords: "files file search find folder browse path fd", accessory: ">" },
  { title: "Actions", icon: "󰜎", category: "Browse", isCategory: true, target: "Actions", keywords: "actions colon commands run reload lock scratch hypr wallpaper dashboard", accessory: ":" },
  { title: "Websearch", icon: "󰖟", category: "Browse", isCategory: true, target: "Websearch", keywords: "web search documentation engines kagi docs translate wiki", accessory: "@" },
  { title: "System", icon: "󰐥", category: "Browse", isCategory: true, target: "System", keywords: "system lock suspend hibernate logout restart reboot shutdown power session" }
]

const localItems = [
  // System / Session (reached via System category)
  { title: "Lock Screen", icon: "󰌾", category: "System", keywords: "lock screen security", comment: "Lock the current session", command: ["loginctl", "lock-session"] },
  { title: "Suspend", icon: "󰒲", category: "System", keywords: "suspend sleep", comment: "Sleep until next wake", exec: "systemctl suspend" },
  { title: "Hibernate", icon: "󰤁", category: "System", keywords: "hibernate", comment: "Save state to disk and power off", exec: "systemctl hibernate" },
  { title: "Logout", icon: "󰍃", category: "System", keywords: "logout exit session", comment: "End the Hyprland session", exec: "hyprctl dispatch exit" },
  { title: "Restart", icon: "󰜉", category: "System", keywords: "restart reboot", comment: "Reboot the machine", exec: "systemctl reboot" },
  { title: "Shutdown", icon: "󰐥", category: "System", keywords: "shutdown poweroff", comment: "Power off the machine", exec: "systemctl poweroff" },

]

function annotate(items) {
  const out = new Array(items.length)
  for (let i = 0; i < items.length; i++) {
    const it = items[i]
    out[i] = Object.assign({}, it, {
      _t: (it.title || "").toLowerCase(),
      _k: (it.keywords || "").toLowerCase(),
      _c: (it.category || "").toLowerCase()
    })
  }
  return out
}

function basename(p) {
  const s = p.lastIndexOf("/")
  return s >= 0 ? p.substring(s + 1) : p
}
function dirname(p) {
  const s = p.lastIndexOf("/")
  return s >= 0 ? p.substring(0, s) : ""
}
function tildify(p, homeDir) {
  return (homeDir && p.indexOf(homeDir) === 0) ? "~" + p.substring(homeDir.length) : p
}
function fileExt(path) {
  const name = basename(path)
  const dot = name.lastIndexOf(".")
  if (dot <= 0) return name.toLowerCase()
  return name.substring(dot + 1).toLowerCase()
}
function fileIcon(path) {
  return fileIcons[fileExt(path)] || "󰈔"
}
function itemKey(item) {
  if (!item) return ""
  return item.path || item.exec || item.command || (item.title + "|" + item.category)
}
