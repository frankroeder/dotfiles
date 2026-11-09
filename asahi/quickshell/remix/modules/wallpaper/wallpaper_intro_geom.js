.pragma library
// Wallpaper span canvas (port of asahi-wallpaper-span frames()): a seam (outputs touching along an edge)
// shifts the outputs past it by `gap`; the picture covers the frames' bounding box, centred.

function seams(rects, pos, size, opos, osize) {
  const out = []
  for (const a of rects) for (const b of rects)
    if (Math.abs(a[pos] + a[size] - b[pos]) <= 1 && Math.min(a[opos] + a[osize], b[opos] + b[osize]) - Math.max(a[opos], b[opos]) > 1)
      out.push(Math.round(b[pos]))
  return [...new Set(out)]
}

// Rect of the whole canvas inside output `name`'s window (logical px); the window clips it to its slice.
// Not spanning: the output's own rect.
function videoRect(rects, name, spanOn, gap) {
  const me = rects.find(r => r.name === name)
  if (!me) return { x: 0, y: 0, w: 0, h: 0 }   // output going away: its window is about to be destroyed
  if (!spanOn || rects.length < 2) return { x: 0, y: 0, w: me.w, h: me.h }
  const sx = seams(rects, "x", "w", "y", "h"), sy = seams(rects, "y", "h", "x", "w")
  const frs = rects.map(r => Object.assign({}, r, {
    x: r.x + gap * sx.filter(s => s <= r.x + 1).length, y: r.y + gap * sy.filter(s => s <= r.y + 1).length }))
  const x0 = Math.min(...frs.map(f => f.x)), y0 = Math.min(...frs.map(f => f.y))
  const bw = Math.max(...frs.map(f => f.x + f.w)) - x0, bh = Math.max(...frs.map(f => f.y + f.h)) - y0
  const f = frs.find(r => r.name === name)
  return { x: x0 - f.x, y: y0 - f.y, w: bw, h: bh }
}
