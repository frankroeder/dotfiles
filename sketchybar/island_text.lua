-- Exact text measurement for island pill sizing.
--
-- Advance widths of SF Pro Semibold at 15pt, measured with NSString
-- sizeWithAttributes against the installed /Library/Fonts/SF-Pro.ttf using the
-- same descriptor sketchybar resolves (family "SF Pro", face "Semibold").
-- Char-sum vs full-string deviation is ≤ 0.6px on every island toast string
-- ("Momentum 4… · 100%" sum 161.5 vs rendered 161.1), so summing advances is
-- accurate enough for wing sizing. Regenerate with a JXA probe if the font
-- family ever changes.
local W15 = {
  [32] = 3.762, -- space
  [33] = 4.860,
  [34] = 7.796,
  [35] = 9.608,
  [36] = 9.608,
  [37] = 14.693,
  [38] = 10.750,
  [39] = 4.701,
  [40] = 5.938,
  [41] = 5.938,
  [42] = 6.961,
  [43] = 9.608,
  [44] = 4.701,
  [45] = 6.961,
  [46] = 4.701,
  [47] = 4.619,
  [48] = 9.733,
  [49] = 7.178,
  [50] = 9.194,
  [51] = 9.569,
  [52] = 9.832,
  [53] = 9.467,
  [54] = 9.762,
  [55] = 8.640,
  [56] = 9.870,
  [57] = 9.762,
  [58] = 4.701,
  [59] = 4.701,
  [60] = 9.608,
  [61] = 9.608,
  [62] = 9.608,
  [63] = 7.878,
  [64] = 13.621,
  [65] = 10.430,
  [66] = 9.967,
  [67] = 10.744,
  [68] = 10.861,
  [69] = 8.949,
  [70] = 8.588,
  [71] = 11.094,
  [72] = 11.288,
  [73] = 4.262,
  [74] = 8.435,
  [75] = 10.126,
  [76] = 8.539,
  [77] = 13.184,
  [78] = 11.144,
  [79] = 11.479,
  [80] = 9.659,
  [81] = 11.479,
  [82] = 9.955,
  [83] = 9.683,
  [84] = 9.523,
  [85] = 11.043,
  [86] = 10.323,
  [87] = 14.676,
  [88] = 10.429,
  [89] = 10.096,
  [90] = 9.822,
  [91] = 5.938,
  [92] = 4.619,
  [93] = 5.938,
  [94] = 9.608,
  [95] = 8.933,
  [96] = 7.266,
  [97] = 8.401,
  [98] = 9.332,
  [99] = 8.424,
  [100] = 9.332,
  [101] = 8.616,
  [102] = 5.631,
  [103] = 9.247,
  [104] = 9.006,
  [105] = 3.852,
  [106] = 3.847,
  [107] = 8.464,
  [108] = 3.958,
  [109] = 13.406,
  [110] = 8.933,
  [111] = 8.902,
  [112] = 9.269,
  [113] = 9.268,
  [114] = 5.993,
  [115] = 8.025,
  [116] = 5.683,
  [117] = 8.933,
  [118] = 8.283,
  [119] = 12.073,
  [120] = 8.165,
  [121] = 8.425,
  [122] = 8.111,
  [123] = 5.938,
  [124] = 4.032,
  [125] = 5.938,
  [126] = 9.608,
  [176] = 6.961, -- °
  [183] = 4.701, -- ·
  [228] = 8.401, -- ä
  [233] = 8.616, -- é
  [246] = 8.902, -- ö
  [252] = 8.933, -- ü
  [8211] = 8.933, -- –
  [8212] = 13.184, -- —
  [8217] = 4.701, -- ’
  [8230] = 13.255, -- …
}

-- Unknown codepoints get a full em (15 at 15pt): over-estimating only widens
-- the pill; under-estimating would run text into the notch. Covers CJK-ish
-- app/device names without a per-script table.
local FALLBACK = 15
local ELLIPSIS = 8230

local M = {}

local function codepoints(text)
  local cps = {}
  if utf8 then
    local ok = pcall(function()
      for _, cp in utf8.codes(text) do
        cps[#cps + 1] = cp
      end
    end)
    if ok then
      return cps
    end
    cps = {}
  end
  for i = 1, #text do
    cps[i] = text:byte(i)
  end
  return cps
end

-- Rendered width of `text` at `size` pt (SF Pro Semibold metrics).
function M.measure(text, size)
  text = tostring(text or "")
  size = size or 15
  local total = 0
  for _, cp in ipairs(codepoints(text)) do
    total = total + (W15[cp] or FALLBACK)
  end
  return total * size / 15
end

-- Truncate `text` (with a trailing ellipsis) so it renders within `max_w` px.
-- Pixel-based, unlike utils.ellipsize's codepoint count — the hard guarantee
-- that pill text can never run under the notch even at the max pill width.
function M.fit(text, size, max_w)
  text = tostring(text or "")
  size = size or 15
  local scale = size / 15
  local cps = codepoints(text)
  local total = 0
  for _, cp in ipairs(cps) do
    total = total + (W15[cp] or FALLBACK)
  end
  if total * scale <= max_w then
    return text
  end
  local budget = max_w / scale - W15[ELLIPSIS]
  local acc = 0
  local keep = 0
  for i, cp in ipairs(cps) do
    acc = acc + (W15[cp] or FALLBACK)
    if acc > budget then
      break
    end
    keep = i
  end
  local out = {}
  for i = 1, keep do
    out[i] = utf8 and utf8.char(cps[i]) or string.char(cps[i])
  end
  return table.concat(out) .. "…"
end

return M
