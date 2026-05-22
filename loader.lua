  local Loader = {}

local API_BASE = "https://kyuubii.dev/k-script"
local BUILD = "15.69"
local LOADER_USER_AGENT = "K-Script V17.1"

local STATIC_KEY_STREAM_HEX =
  "427e2143290ec05f7d3d709dcb6d2e727e6ab4381767c61934c8dd7deec4109a" ..
  "725751febdcaca00ec628961c021d4d0a783116d30af1c0a692621c1ce4e0ccc"

local PAYLOAD_INFO = "KScript|payload|v16|LexisSucks|IfYoureReadingThisYourARetard"

local function toast(colour, title, body)
  if Logger and Logger.Log then
    Logger.Log(colour, title, tostring(body))
  end
  if GUI and GUI.AddToast then
    GUI.AddToast("K-Script", body, 8000, eToastPos.BOTTOM_RIGHT)
  end
end

local function fail(code)
  toast(eLogColor.RED, "K-Script Error", ("Error %s (%s)"):format(tostring(code), Loader.error_id))
  os.exit(69)
end

local function should_unload()
  return type(ShouldUnload) == "function" and ShouldUnload() or false
end

local function maybe_yield(ms)
  if Script and type(Script.Yield) == "function" then
    Script.Yield(ms)
  end
end

local function bytes_to_hex(bytes)
  return (bytes:gsub(".", function(ch)
    return ("%02x"):format(ch:byte())
  end))
end

local function hex_to_bytes(hex)
  if type(hex) ~= "string" then
    return nil
  end
  hex = hex:gsub("%s+", ""):lower():gsub('^"(.*)"$', "%1")
  if #hex % 2 ~= 0 or not hex:match("^[0-9a-f]+$") then
    return nil
  end
  local out = {}
  for i = 1, #hex, 2 do
    out[#out + 1] = string.char(tonumber(hex:sub(i, i + 1), 16))
  end
  return table.concat(out)
end

local function valid_hex(value, chars)
  if type(value) ~= "string" then
    return nil
  end
  value = value:gsub("%s+", ""):lower():gsub('^"(.*)"$', "%1")
  if #value ~= chars or not value:match("^[0-9a-f]+$") then
    return nil
  end
  return value
end

local function constant_time_equal(a, b)
  if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then
    return false
  end
  local diff = 0
  for i = 1, #a do
    diff = diff | (a:byte(i) ~ b:byte(i))
  end
  return diff == 0
end

local sha256
local hmac_sha256
local chacha20_xor

local function json_encode(value)
  return Loader.json_encode(value)
end

local function json_decode(text)
  return Loader.json_decode(text)
end

local function request(method, url, body, headers)
  local easy = Curl.Easy()
  easy:Setopt(eCurlOption.CURLOPT_URL, url)
  easy:Setopt(eCurlOption.CURLOPT_USERAGENT, LOADER_USER_AGENT)
  easy:DisableErrorLog()

  if method == "POST" then
    body = body or ""
    easy:Setopt(eCurlOption.CURLOPT_POST, 1)
    easy:Setopt(eCurlOption.CURLOPT_POSTFIELDS, body)
    if eCurlOption.CURLOPT_POSTFIELDSIZE then
      easy:Setopt(eCurlOption.CURLOPT_POSTFIELDSIZE, #body)
    end
  end

  for key, value in pairs(headers or {}) do
    easy:AddHeader(tostring(key) .. ": " .. tostring(value))
  end

  easy:Perform()
  local start = os.clock()
  while not easy:GetFinished() do
    if should_unload() then
      return nil, "request aborted: unloading"
    end
    if os.clock() - start >= 30 then
      return nil, "request timed out"
    end
    maybe_yield(10)
  end

  local code, response = easy:GetResponse()
  if code ~= eCurlCode.CURLE_OK then
    return nil, "curl error: " .. tostring(code)
  end
  return response, nil
end

local function response_body(response)
  if type(response) == "table" then
    response = response.body or response.Body or response.data or response.Data or
      response.text or response.Text or response.response or response.Response
  end
  if type(response) ~= "string" then
    return nil
  end
  response = response:gsub("^\239\187\191", ""):gsub("^%s+", "")
  local split = response:find("\r\n\r\n", 1, true)
  if split then
    response = response:sub(split + 4):gsub("^%s+", "")
  end
  return response
end

local function is_cloudflare_block(text)
  return type(text) == "string" and (
    text:find("Attention Required! | Cloudflare", 1, true) or
    text:find("Cloudflare Ray ID", 1, true) or
    text:find("Sorry, you have been blocked", 1, true)
  ) ~= nil
end

local function extract_token(decoded)
  local function check(value)
    return valid_hex(value, 64)
  end
  if type(decoded) ~= "table" then
    return nil
  end
  return check(decoded.t) or check(decoded.token) or check(decoded.loaderToken) or
    check(decoded.scriptToken) or check(decoded.access_token) or check(decoded.accessToken)
end

local function random_hex(byte_count)
  local out = {}
  for _ = 1, byte_count do
    out[#out + 1] = ("%02x"):format(math.random(0, 255))
  end
  return table.concat(out)
end

local function make_error_id()
  return "T" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

local function check_runtime_integrity()
  return true
end

local function runtime_hash()
  return bytes_to_hex(sha256(table.concat({
    tostring(load),
    tostring(pcall),
    tostring(type),
    tostring(_G),
  }, "|")))
end

local function make_token_signature(token_key, uid, ts, client_nonce, hid, server_nonce, build)
  local msg = table.concat({ uid, ts, client_nonce, hid, server_nonce, build }, "|")
  return bytes_to_hex(hmac_sha256(token_key, msg))
end

local function make_session_proof(proof_key, uid, hid, server_nonce, client_nonce, build)
  local msg = table.concat({ "proof", uid, hid, server_nonce, client_nonce, build }, "|")
  return bytes_to_hex(hmac_sha256(proof_key, msg))
end

local function derive_session_secret(proof_key, uid, sid, exp, salt, part_a, proof)
  local msg = table.concat({ "sess", uid, sid, exp, salt, part_a, proof }, "|")
  return hmac_sha256(proof_key, msg)
end

local function derive_payload_key(session_secret)
  return hmac_sha256(session_secret, PAYLOAD_INFO)
end

local function make_challenge_responder(payload_key, uid, sid, session_exp)
  return function(challenge, challenge_exp)
    local msg = table.concat({
      "chal|v2",
      tostring(uid),
      sid,
      session_exp,
      tostring(challenge),
      tostring(challenge_exp),
      BUILD,
    }, "|")
    return bytes_to_hex(hmac_sha256(payload_key, msg))
  end
end

local function build_payload_env(api_base, sid, session_exp, challenge_response, wipe)
  return Loader.build_payload_env(api_base, sid, session_exp, challenge_response, wipe)
end

local function load_payload(source, api_base, sid, session_exp, challenge_response, wipe)
  local env = build_payload_env(api_base, sid, session_exp, challenge_response, wipe)
  local fn, err = load(source, "=@payload", "bt", env)
  if not fn then
    return false, err
  end
  local ok, result = pcall(fn)
  if not ok then
    return false, result
  end
  return true, result
end

function Loader.run()
  if should_unload() then
    return
  end

  Loader.error_id = make_error_id()
  toast(nil, "loader-start", "Preparing secure handshake")
  if Script and type(Script.Yield) == "function" then
    Script.Yield(1000)
  end

  toast(nil, "anti-hook", "Checking runtime integrity")
  if not check_runtime_integrity() then
    os.exit(69)
    return
  end
  runtime_hash()

  local uid = tostring(Cherax.GetUID())
  if uid == "" or not uid:match("^%d+$") or tonumber(uid) <= 0 then
    fail("E1(ID)")
  end
  toast(nil, "identity", "UID " .. uid)

  local ts = tostring(os.time() * 1000)
  local client_nonce = random_hex(16)
  local token_key = hex_to_bytes(TOKEN_HMAC_KEY_HEX)

  local proof_key = Loader.resolve_proof_key and Loader.resolve_proof_key(STATIC_KEY_STREAM_HEX)
  if not token_key or not proof_key then
    fail("E10(MK)")
  end

  toast(nil, "hello-request", "Contacting loader hello")
  local hello_response = assert(request("GET", API_BASE .. "/loader/hello", nil, {
    ["Content-Type"] = "application/json",
  }))
  local hello_body = response_body(hello_response)
  if is_cloudflare_block(hello_body) then
    fail("E2(CF)")
  end
  local hello = json_decode(hello_body)
  local hid = valid_hex(hello and (hello.hid or hello.h), 32)
  local server_nonce = valid_hex(hello and (hello.nonce or hello.n), 32)
  local build = tostring((hello and (hello.build or hello.b)) or BUILD)
  if not hid or not server_nonce or build ~= BUILD then
    fail("E2(HF)")
  end

  local sig = make_token_signature(token_key, uid, ts, client_nonce, hid, server_nonce, build)
  local token_request = json_encode({
    uid = uid,
    ts = ts,
    nonce = client_nonce,
    hid = hid,
    build = build,
    sig = sig,
  })

  toast(nil, "token-request", "Requesting loader token")
  local token_response = assert(request("POST", API_BASE .. "/loader/token", token_request, {
    ["Content-Type"] = "application/json; charset=utf-8",
  }))
  local token_body = response_body(token_response)
  if is_cloudflare_block(token_body) then
    fail("E4(CF)")
  end
  local token_json = json_decode(token_body)
  local token = extract_token(token_json)
  if not token then
    fail("E6(TB)")
  end

  toast(nil, "token-ok", "Token accepted")
  local auth = { Authorization = "Bearer " .. token }
  local proof = make_session_proof(proof_key, uid, hid, server_nonce, client_nonce, build)

  toast(nil, "session-request", "Creating secure session")
  local session_response = assert(request("POST", API_BASE .. "/loader/session", json_encode({
    proof = proof,
  }), {
    Authorization = auth.Authorization,
    ["Content-Type"] = "application/json; charset=utf-8",
  }))
  local session_body = response_body(session_response)
  if is_cloudflare_block(session_body) then
    fail("E8(CF)")
  end
  local session = json_decode(session_body)
  if not session or session.error then
    fail("E9(SE)")
  end

  local sid = valid_hex(session.sid, 32)
  local salt = valid_hex(session.salt, 32)
  local part_a = valid_hex(session.partA, 64)
  local session_exp = session.exp and tostring(math.floor(tonumber(session.exp)))
  if not sid or not salt or not part_a or not session_exp then
    fail("E9(SF)")
  end

  toast(nil, "session-ok", "Session established")
  local session_secret = derive_session_secret(proof_key, uid, sid, session_exp, salt, part_a, proof)
  local payload_key = derive_payload_key(session_secret)

  local payload_response = assert(request("GET", API_BASE .. "/loader/payload?sid=" .. sid, nil, {
    Authorization = auth.Authorization,
  }))
  local payload_body = response_body(payload_response)
  if is_cloudflare_block(payload_body) then
    fail("E13(CF)")
  end
  local payload = json_decode(payload_body)
  if not payload or payload.error then
    fail("E14(PF)")
  end

  local payload_exp = payload.exp and tostring(math.floor(tonumber(payload.exp)))
  local ctr = tonumber(payload.ctr)
  local version = payload.v and tostring(math.floor(tonumber(payload.v)))
  local nonce_hex = valid_hex(payload.nonce, 24)
  local mac_hex = valid_hex(payload.mac, 64)
  local ct_hex = payload.ct and payload.ct:gsub("%s+", ""):lower()
  if payload_exp ~= session_exp or version ~= "2" or not ctr or ctr < 0 or
      ctr > 0xffffffff or ctr ~= math.floor(ctr) or not nonce_hex or
      not mac_hex or not ct_hex or #ct_hex % 2 ~= 0 then
    fail("E14(PV)")
  end

  local nonce = hex_to_bytes(nonce_hex)
  local ciphertext = hex_to_bytes(ct_hex)
  local expected_mac = hmac_sha256(payload_key,
    table.concat({ version, payload_exp, tostring(math.floor(ctr)) }, "|") ..
    "|" .. nonce .. ciphertext)
  if not constant_time_equal(hex_to_bytes(mac_hex), expected_mac) then
    fail("E16(MV)")
  end

  toast(nil, "remote-payload-verified", "Payload verified")
  local plaintext = chacha20_xor(payload_key, nonce, math.floor(ctr), ciphertext)
  local wipe = function()
    payload_key = nil
    collectgarbage("collect")
    collectgarbage("collect")
    return true
  end
  local challenge_response = make_challenge_responder(payload_key, uid, sid, session_exp)
  local ok = load_payload(plaintext, API_BASE, sid, session_exp, challenge_response, wipe)
  if not ok then
    fail("E17(SE)")
  end

  wipe()
end

return Loader
