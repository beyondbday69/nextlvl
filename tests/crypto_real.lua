-- standalone check of the Lua crypto used in the bootstrap (same code)
local function extractArray(file, name)
  local src = io.open(file, "r"):read("*all")
  io.open(file, "r"):close()
  local s, e = string.find(src, name .. " = %{")
  local s2 = string.find(src, "%}", e)
  local body = string.sub(src, e + 1, s2 - 1)
  local t = {}
  for v in string.gmatch(body, "(%d+)") do t[#t + 1] = tonumber(v) end
  return t
end

local NIB = {}
for a = 0, 15 do
  for b = 0, 15 do
    local r, x, y, p = 0, a, b, 1
    for _ = 1, 4 do
      if (x % 2) ~= (y % 2) then r = r + p end
      x = math.floor(x / 2); y = math.floor(y / 2); p = p * 2
    end
    NIB[a * 16 + b] = r
  end
end
local function bx(x, y)
  return NIB[math.floor(x / 16) * 16 + math.floor(y / 16)] * 16 + NIB[(x % 16) * 16 + (y % 16)]
end

local function rc4(key, data)
  local S = {}
  for i = 0, 255 do S[i] = i end
  local j, kl = 0, #key
  for i = 0, 255 do
    j = (j + S[i] + string.byte(key, (i % kl) + 1)) % 256
    S[i], S[j] = S[j], S[i]
  end
  local i, j2 = 0, 0
  local out = {}
  local n = 0
  for k = 1, #data do
    i = (i + 1) % 256
    j2 = (j2 + S[i]) % 256
    S[i], S[j2] = S[j2], S[i]
    n = n + 1
    out[n] = string.char(bx(string.byte(data, k), S[(S[i] + S[j2]) % 256]))
  end
  return table.concat(out)
end

local B64M = {}
do
  local B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  for i = 1, 64 do B64M[string.sub(B, i, i)] = i - 1 end
end
local function b64d(s)
  local t, n, i, l = {}, 0, 1, #s
  while i <= l do
    local c1 = B64M[string.sub(s, i, i)]; i = i + 1
    local c2 = B64M[string.sub(s, i, i)]; i = i + 1
    local c3s = string.sub(s, i, i); i = i + 1
    local c4s = string.sub(s, i, i); i = i + 1
    local c3 = c3s ~= "=" and B64M[c3s] or 0
    local c4 = c4s ~= "=" and B64M[c4s] or 0
    n = n + 1
    t[n] = string.char(c1 * 4 + math.floor(c2 / 16))
    if c3s ~= "=" then
      n = n + 1
      t[n] = string.char((c2 % 16) * 16 + math.floor(c3 / 4))
    end
    if c4s ~= "=" then
      n = n + 1
      t[n] = string.char((c3 % 4) * 64 + c4)
    end
  end
  return table.concat(t)
end

local INJ = "../dist/game_frontend_hud.lua"
local CHUNK = "../dist/chunks/c01.lua"

local mk = extractArray(INJ, "mk")
local mask = extractArray(INJ, "m")

local Mchars = {}
for i = 1, #mk do
  Mchars[i] = string.char(bx(mk[i], mask[(i - 1) % #mask + 1]))
end
local M = table.concat(Mchars)
print("M len:", #M)

local f = io.open(CHUNK, "r")
local b64 = f:read("*all")
f:close()
b64 = string.gsub(b64, "%s", "")
local raw = b64d(b64)
print("raw len:", #raw)

local pt = rc4(M .. "c01.lua", raw)
print("decrypted:", string.format("%q", pt))
local ok = string.find(pt, "AimbotConfig", 1, true) ~= nil
print("CONTAINS TEST_LOADED:", ok)
os.exit(ok and 0 or 1)
