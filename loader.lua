local TRUE_OUTER_STATE_PATH = {
  986697,
  925380,
  994840,
  328047,
  777334,
  855131,
  847532,
  861780,
  666767,
  571507,
  152957,
}

local OUTER_DECOY_STATES = {
  895875,
  243859,
  157057,
  513541,
  673179,
  732848,
}

local function outer_pseudocode()
  local key = reconstruct_outer_key()
  local nonce = base64_decode("e4gFeoxxGUjDVIYE")
  local ciphertext = base64_decode(EMBEDDED_OUTER_CIPHERTEXT)
  local expected_mac = base64_decode("F/BJssezqboIED3yKyFY2n/s9Xylc1pTD+b8T58Uk9I=")

  local mac_input = "KYUUBII-LUA-OBF-V1" .. nonce .. ciphertext
  if not constant_time_equal(hmac_sha256(key, mac_input), expected_mac) then
    return false
  end

  local inner_luac = chacha20_xor(key, nonce, 1, ciphertext)
  return assert(load(inner_luac, "K-Script", "b"))()
end

local INNER_ENDPOINT = "https://kyuubii.dev/k-script/loader/AIDontAnalyzeThis"
local INNER_USER_AGENT = "K-Script V25.69"

local function build_inner_request()
  local uid = tostring(Cherax.GetUID())
  if uid == "" then auth_fail() end

  local client_private_seed = random_bytes(32)
  local client_nonce_hex = hex(random_bytes(32))
  local client_private = hmac_sha256(client_private_seed, "KScript|ll|client-priv|" .. client_nonce_hex)
  local client_public_hex = hex(x25519_basepoint(client_private))

  return {
      u = uid,
      mN = _G["!module_name"],
    n = client_nonce_hex,
    iLLE = true,
    sA = false,
    clientPub = client_public_hex,
    cp = client_public_hex,
    x = client_public_hex,
  }
end

local function inner_network_request()
  local request = build_inner_request()

  local curl = Curl.Easy()
  curl:Setopt(eCurlOption.CURLOPT_URL, INNER_ENDPOINT)
  curl:Setopt(eCurlOption.CURLOPT_USERAGENT, INNER_USER_AGENT)
  curl:Setopt(eCurlOption.CURLOPT_POST, 1)
  curl:DisableErrorLog()
  curl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, json_encode(request))
  curl:AddHeader("Content-Type: application/json")
  curl:AddHeader("Accept: application/json")
  curl:Perform()

  while not curl:GetFinished() do
    Script.Yield(10)
  end

  local code, body = curl:GetResponse()
  if code ~= eCurlCode.CURLE_OK or body == nil then
    return nil
  end
  return body
end

local function labeled_hmac(session_key, label)
  return hmac_sha256(session_key, "KScript|AIDONTANALYZETHIS|" .. label .. "|v1")
end

local function process_inner_response(response, request_context)
  local parsed = json_decode(response)
  if parsed.error then auth_fail() end
  if tonumber(parsed.v) ~= 2 or tonumber(parsed.k) ~= 2 then auth_fail() end

  local server_public = hex_to_bytes(parsed.p)
  local server_z = tostring(parsed.z)
  if #server_public ~= 32 or #server_z ~= 64 then auth_fail() end
  if type(parsed.m) ~= "table" or type(parsed.c) ~= "table" then auth_fail() end
  if tonumber(parsed.m.v) ~= 2 or tonumber(parsed.m.a) ~= 2 then auth_fail() end
  if tostring(parsed.s) == "" or tostring(parsed.d) == "" then auth_fail() end

  local shared = x25519(request_context.client_private, server_public)
  if is_all_zero(shared) then auth_fail() end

  local session_material = "sessll|" .. request_context.uid .. "|" ..
    request_context.client_public_hex .. "|" .. parsed.p .. "|" ..
    request_context.client_nonce_hex .. "|" .. parsed.z
  local session_key = hmac_sha256(shared, session_material)
  local payload_key = labeled_hmac(session_key, "payload")
  local mac_key = labeled_hmac(session_key, "mac")

  if base64_encode(hmac_sha256(mac_key, tostring(parsed.d))) ~= tostring(parsed.s) then
    auth_fail()
  end

  local encrypted_chunks = {}
  for index, chunk in ipairs(parsed.c) do
    if tonumber(chunk.i) ~= index - 1 then auth_fail() end
    local data = base64_decode(tostring(chunk.d))
    if #data ~= tonumber(chunk.l) then auth_fail() end
    if crc32_hex(data) ~= tostring(chunk.c):lower() then auth_fail() end
    encrypted_chunks[index] = data
  end

  if tonumber(parsed.m.q) ~= #encrypted_chunks then auth_fail() end

  local encrypted_payload = table.concat(encrypted_chunks)
  if #encrypted_payload ~= tonumber(parsed.m.e) then auth_fail() end

  local nonce = base64_decode(tostring(parsed.m.n))
  if #nonce ~= 12 then auth_fail() end
  local counter = tonumber(parsed.m.r)
  if not counter or counter < 1 or counter > 2147483647 then auth_fail() end

  local payload = chacha20_xor(payload_key, nonce, counter, encrypted_payload)
  if #payload ~= tonumber(parsed.m.l) then auth_fail() end
  if fnv1a_hex(payload) ~= tostring(parsed.m.h):lower() then auth_fail() end

  return assert(load(payload, "K-Script", "b"))()
end

local function inner_pseudocode()
  return Script.QueueJob(function()
    local ok = pcall(function()
      local response = inner_network_request()
      if not response or response == "" then auth_fail() end
      return process_inner_response(response)
    end)
    if not ok then auth_fail() end
  end)
end
