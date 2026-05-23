
































local API_BASE = API_BASE or "https://kyuubii.dev/k-script/"
API_BASE = tostring(API_BASE):gsub("/+$", "")
local LOADER_BUILD = "15.69"
local LOADER_TLS_PINNED_PUBLIC_KEY = "sha256//0n18j4n/Nu2H3/tP3MboascBpDOM7vYE3twTsv+Q+m4="
local LOADER_REQUIRE_TLS_PIN = true




local function _log(color, tag, msg)
  if Logger and Logger.Log then
    Logger.Log(color, tag, tostring(msg))
  end
  GUI.AddToast("K-Script", msg, 8000, eToastPos.BOTTOM_RIGHT)
end

local function _ticket()
  local t = tostring((os and os.time and os.time()) or 0)
  local r = tostring(math.random(100000, 999999))
  return "T" .. t .. "-" .. r
end

local TICKET = _ticket()

local function USER_FAIL(code)
  _log(eLogColor.RED, "K-Script", "Error " .. tostring(code) .. " (" .. TICKET .. ")")
end


local function FAIL(code)
  if type(loader_ui_fail) == "function" then
    pcall(loader_ui_fail, code)
  end
  if type(loader_ui_wait_for_status_anim) == "function" then
    loader_ui_wait_for_status_anim()
  end
  USER_FAIL(code)
end

local HTTP_REQUEST_TIMEOUT_MS = tonumber(HTTP_REQUEST_TIMEOUT_MS or 30000) or 30000
local HTTP_REQUEST_POLL_MS = tonumber(HTTP_REQUEST_POLL_MS or 10) or 10
local LOADER_WORK_SLICE_MS = tonumber(LOADER_WORK_SLICE_MS or 5) or 5
local LOADER_UI_WARMUP_MS = tonumber(LOADER_UI_WARMUP_MS or 1000) or 1000
local LOADER_UI_STATUS_TYPE_CPS = tonumber(LOADER_UI_STATUS_TYPE_CPS or 48) or 48
local LOADER_UI_RESULT_TYPE_CPS = tonumber(LOADER_UI_RESULT_TYPE_CPS or 38) or 38
local loader_last_yield = (os and os.clock and os.clock()) or 0

local function _should_unload_now()
  return type(ShouldUnload) == "function" and ShouldUnload()
end

local function loader_yield_if_due()
  if not Script or type(Script.Yield) ~= "function" then return end
  local now = (os and os.clock and os.clock()) or 0
  if ((now - loader_last_yield) * 1000) >= LOADER_WORK_SLICE_MS then
    Script.Yield()
    loader_last_yield = (os and os.clock and os.clock()) or now
  end
end

local function http_request_worker(method, url, body, headers)
  local c = Curl.Easy()
  c:Setopt(eCurlOption.CURLOPT_URL, url)
  c:Setopt(eCurlOption.CURLOPT_USERAGENT, "K-Script V25.69")
  c:DisableErrorLog()

  if method == "POST" then
    body = tostring(body or "")
    c:Setopt(eCurlOption.CURLOPT_POST, 1)
    c:Setopt(eCurlOption.CURLOPT_POSTFIELDS, body)
    if eCurlOption.CURLOPT_POSTFIELDSIZE then
      c:Setopt(eCurlOption.CURLOPT_POSTFIELDSIZE, #body)
    end
  end

  if headers then
    for k, v in pairs(headers) do
      c:AddHeader(tostring(k) .. ": " .. tostring(v))
    end
  end

  c:Perform()
  local started = os.clock()
  while not c:GetFinished() do
    if _should_unload_now() then
      return nil, "request aborted: unloading"
    end
    if HTTP_REQUEST_TIMEOUT_MS > 0 and ((os.clock() - started) * 1000) >= HTTP_REQUEST_TIMEOUT_MS then
      return nil, "request timed out"
    end
    Script.Yield(HTTP_REQUEST_POLL_MS)
  end
  local code, resp = c:GetResponse()
  if code ~= eCurlCode.CURLE_OK then
    return nil, "curl error: " .. tostring(code)
  end
  return resp, nil
end

local function http_request(method, url, body, headers)
  local done = false
  local resp = nil
  local err = nil

  local queued, queueErr = pcall(Script.QueueJob, function()
    local ok, workerErr = pcall(function()
      resp, err = http_request_worker(method, url, body, headers)
    end)

    if not ok then
      resp = nil
      err = "http worker error: " .. tostring(workerErr)
    end

    done = true
  end)

  if not queued then
    return nil, "http queue error: " .. tostring(queueErr)
  end

  while not done do
    if _should_unload_now() then
      return nil, "request aborted: unloading"
    end
    Script.Yield(HTTP_REQUEST_POLL_MS)
  end

  return resp, err
end

local LOADER_UI_STAGE_PROGRESS = {
  ["waiting"] = 0.01,
  ["loader-start"] = 0.04,
  ["anti-hook"] = 0.08,
  ["anti-hook-ok"] = 0.12,
  ["identity"] = 0.18,
  ["hello-request"] = 0.24,
  ["hello-ok"] = 0.34,
  ["token-request"] = 0.40,
  ["token-ok"] = 0.50,
  ["session-request"] = 0.56,
  ["session-ok"] = 0.66,
  ["remote-payload-request"] = 0.72,
  ["payload-parse"] = 0.76,
  ["payload-verify"] = 0.82,
  ["remote-payload-verified"] = 0.84,
  ["payload-decrypt"] = 0.88,
  ["launching-script"] = 0.96,
  ["cleanup"] = 1.00,
}

local LOADER_UI_STAGE_LABEL = {
  ["waiting"] = "Waiting",
  ["loader-start"] = "Starting",
  ["anti-hook"] = "Checking Environment",
  ["anti-hook-ok"] = "Environment Ready",
  ["identity"] = "Verifying Access",
  ["hello-request"] = "Authenticating",
  ["hello-ok"] = "Authenticating",
  ["token-request"] = "Authenticating",
  ["token-ok"] = "Access Confirmed",
  ["session-request"] = "Preparing",
  ["session-ok"] = "Preparing",
  ["remote-payload-request"] = "Loading",
  ["payload-parse"] = "Processing",
  ["payload-verify"] = "Verifying",
  ["remote-payload-verified"] = "Verifying",
  ["payload-decrypt"] = "Finalizing",
  ["launching-script"] = "Starting K-Script",
  ["cleanup"] = "Finishing",
  ["failed"] = "Load Failed",
}

local LOADER_UI_STAGE_DETAIL = {
  ["waiting"] = "Waiting for a safe load window",
  ["loader-start"] = "Preparing Authentication",
  ["anti-hook"] = "Checking environment",
  ["anti-hook-ok"] = "Environment is ready",
  ["identity"] = "Verifying access",
  ["hello-request"] = "Authenticating with K-Script",
  ["hello-ok"] = "Authenticating with K-Script",
  ["token-request"] = "Authenticating with K-Script",
  ["token-ok"] = "Access confirmed",
  ["session-request"] = "Preparing secure runtime",
  ["session-ok"] = "Preparing secure runtime",
  ["remote-payload-request"] = "Loading K-Script components",
  ["payload-parse"] = "Unpacking encrypted payload",
  ["payload-verify"] = "Checking payload integrity",
  ["remote-payload-verified"] = "Verifying K-Script components",
  ["payload-decrypt"] = "Finalizing runtime",
  ["launching-script"] = "Almost there",
  ["cleanup"] = "Finishing up",
  ["failed"] = "Load failed. Check the console.",
}

local LOADER_UI_CHECKLIST = {
  { label = "Environment", at = 0.12 },
  { label = "Access",      at = 0.50 },
  { label = "Runtime",     at = 0.66 },
  { label = "Components",  at = 0.84 },
  { label = "Launch",      at = 0.96 },
}

local LOADER_UI_SUCCESS_STAGE = {
  ["anti-hook-ok"] = true,
  ["hello-ok"] = true,
  ["token-ok"] = true,
  ["session-ok"] = true,
  ["remote-payload-verified"] = true,
  ["cleanup"] = true,
}

local LOADER_UI_NO_WAIT_STAGE = {
  ["hello-request"] = true,
  ["hello-ok"] = true,
  ["token-request"] = true,
  ["token-ok"] = true,
  ["session-request"] = true,
  ["session-ok"] = true,
}

local LOADER_UI = {
  active = false,
  handler = nil,
  stage = "waiting",
  detail = "Waiting for game to be ready",
  progress = 0.01,
  started = (os and os.clock and os.clock()) or 0,
  failed = false,
  fading = false,
  fade_started = nil,
  fade_duration = 1.25,
  open_duration = 0.48,
  status = "idle",
  status_reason = "",
  status_started = (os and os.clock and os.clock()) or 0,
}

local function loader_ui_clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function loader_ui_stage_label(stage)
  local s = LOADER_UI_STAGE_LABEL[stage] or tostring(stage or "loading")
  s = s:gsub("%-", " ")
  return (s:gsub("(%a)([%w_']*)", function(a, b) return a:upper() .. b end))
end

local function loader_ui_one_line(text)
  return tostring(text or ""):gsub("[%c]+", " ")
end

local function loader_ui_short_text(text, limit)
  text = loader_ui_one_line(text)
  limit = tonumber(limit or 44) or 44
  if #text > limit then
    return text:sub(1, limit - 3) .. "..."
  end
  return text
end

if not _G["!module_name"] then
  os.exit()
  while true do end
  SetshouldUnload()
  return
end

local function loader_ui_status_text(elapsed)
  local label = loader_ui_stage_label(LOADER_UI.stage)

  if LOADER_UI.status == "failed" then
    return label .. " - FAILED: " .. loader_ui_short_text(LOADER_UI.status_reason ~= "" and LOADER_UI.status_reason or "Check console", 42)
  elseif LOADER_UI.status == "success" then
    return label .. " - SUCCESS!"
  end

  local frames = { "|", "/", "-", "\\" }
  local frame = frames[(math.floor(elapsed * 8) % #frames) + 1]
  return label .. " - RUNNING " .. frame
end

local function loader_ui_type_text(text, elapsed, cps)
  text = tostring(text or "")
  local n = math.floor((elapsed or 0) * (cps or 34))
  if n < #text then
    if n < 1 then n = 1 end
    return text:sub(1, n) .. "_"
  end
  return text
end

function loader_ui_wait_for_status_anim()
  if not Script or type(Script.Yield) ~= "function" then return end

  local now = (os and os.clock and os.clock()) or 0
  local elapsed = math.max(0, now - (LOADER_UI.started or now))
  local status_age_ms = math.max(0, (now - (LOADER_UI.status_started or now)) * 1000)
  local cps = LOADER_UI.status == "running" and LOADER_UI_STATUS_TYPE_CPS or LOADER_UI_RESULT_TYPE_CPS
  local text = loader_ui_status_text(elapsed)
  local target_ms = math.max(0, ((#text / cps) * 1000) - 60)
  local wait_ms = math.ceil(target_ms - status_age_ms)

  if wait_ms > 0 then
    Script.Yield(wait_ms)
  end
end

function loader_ui_set_stage(stage, progress, detail)
  stage = tostring(stage or "loading")
  local now = (os and os.clock and os.clock()) or 0
  if stage == "loader-start" then
    LOADER_UI.started = now
    LOADER_UI.failed = false
  end
  local mapped = LOADER_UI_STAGE_PROGRESS[stage]
  LOADER_UI.stage = stage
  LOADER_UI.detail = loader_ui_one_line(LOADER_UI_STAGE_DETAIL[stage] or detail)
  LOADER_UI.progress = loader_ui_clamp(progress or mapped or LOADER_UI.progress or 0.01, 0.01, 1.0)
  LOADER_UI.status = LOADER_UI_SUCCESS_STAGE[stage] and "success" or "running"
  LOADER_UI.status_reason = ""
  LOADER_UI.status_started = now
  LOADER_UI.active = true
  LOADER_UI.fading = false
  LOADER_UI.fade_started = nil
  if not LOADER_UI_NO_WAIT_STAGE[stage] then
    loader_ui_wait_for_status_anim()
  end
end

function loader_ui_fail(code)
  local now = (os and os.clock and os.clock()) or 0
  LOADER_UI.failed = true
  LOADER_UI.status = "failed"
  LOADER_UI.status_reason = "Error code logged"
  LOADER_UI.status_started = now
  LOADER_UI.detail = LOADER_UI_STAGE_DETAIL["failed"]
  LOADER_UI.active = true
  LOADER_UI.fading = false
  LOADER_UI.fade_started = nil
end

local function loader_ui_remove_handler()
  if LOADER_UI.handler and EventMgr and EventMgr.RemoveHandler then
    pcall(EventMgr.RemoveHandler, LOADER_UI.handler)
    LOADER_UI.handler = nil
  end
end

function loader_ui_stop(immediate)
  if immediate or not LOADER_UI.active then
    LOADER_UI.active = false
    LOADER_UI.fading = false
    loader_ui_remove_handler()
    return
  end

  LOADER_UI.fading = true
  LOADER_UI.fade_started = (os and os.clock and os.clock()) or 0
end

local function loader_ui_scaled_alpha(a, scale)
  return math.floor(loader_ui_clamp((tonumber(a) or 0) * (tonumber(scale) or 1), 0, 255) + 0.5)
end

local function loader_ui_smoothstep(t)
  t = loader_ui_clamp(t, 0, 1)
  return t * t * (3 - (2 * t))
end

local function loader_ui_ease_out(t)
  t = loader_ui_clamp(t, 0, 1)
  return 1 - ((1 - t) * (1 - t) * (1 - t))
end

local function loader_ui_add_text_center(x, y, w, text, r, g, b, a)
  local tw = 0
  if ImGui and ImGui.CalcTextSize then
    tw = select(1, ImGui.CalcTextSize(tostring(text or ""))) or 0
  end
  ImGui.AddText(x + (w - tw) * 0.5, y, tostring(text or ""), r, g, b, a)
end

local function loader_ui_draw_checklist(x, y, w, alpha, elapsed)
  local count = #LOADER_UI_CHECKLIST
  local cols = count > 6 and 2 or 1
  local rows = math.ceil(count / cols)
  local col_w = w / cols
  local p = loader_ui_clamp(LOADER_UI.progress, 0.01, 1.0)
  local centered_col_x = nil

  if cols == 1 then
    local max_label_w = 0
    for _, checklist_item in ipairs(LOADER_UI_CHECKLIST) do
      local label = tostring(checklist_item.label or "")
      local label_w = #label * 7
      if ImGui and ImGui.CalcTextSize then
        label_w = select(1, ImGui.CalcTextSize(label)) or label_w
      end
      if label_w > max_label_w then
        max_label_w = label_w
      end
    end

    col_w = loader_ui_clamp(max_label_w + 66, 158, math.min(238, w - 68))
    centered_col_x = x + ((w - col_w) * 0.5)
  end

  for i, item in ipairs(LOADER_UI_CHECKLIST) do
    local col = math.floor((i - 1) / rows)
    local row = (i - 1) % rows
    local ix = centered_col_x and (centered_col_x + 10) or (x + 34 + (col * col_w))
    local iy = y + (row * 18)
    local done = p >= item.at
    local prev_at = i > 1 and LOADER_UI_CHECKLIST[i - 1].at or 0
    local active = not done and p >= prev_at
    local pulse = active and (0.55 + (0.45 * math.sin(elapsed * 7.0))) or 0

    local r, g, b = 58, 62, 72
    local a = 165
    if done then
      r, g, b, a = 78, 235, 142, 230
    elseif active then
      r, g, b, a = 215, math.floor(42 + (60 * pulse)), 42, 210
    end

    ImGui.AddRectFilled(ix - 10, iy - 3, ix + col_w - 10, iy + 17, done and 14 or 18, done and 32 or 21, done and 24 or 28, loader_ui_scaled_alpha(done and 95 or 72, alpha), 4)
    if active then
      ImGui.AddRectFilled(ix - 10, iy - 3, ix - 6, iy + 17, 215, 42, 42, loader_ui_scaled_alpha(160, alpha), 3)
    elseif done then
      ImGui.AddRectFilled(ix - 10, iy - 3, ix - 6, iy + 17, 78, 235, 142, loader_ui_scaled_alpha(130, alpha), 3)
    end
    ImGui.AddRectFilled(ix, iy + 4, ix + 10, iy + 14, 18, 22, 26, loader_ui_scaled_alpha(220, alpha), 2)
    ImGui.AddRectFilled(ix + 2, iy + 6, ix + 8, iy + 12, r, g, b, loader_ui_scaled_alpha(a, alpha), 2)
    ImGui.AddText(ix + 18, iy, tostring(item.label or ""), done and 210 or 150, done and 235 or 158, done and 218 or 176, loader_ui_scaled_alpha(done and 245 or 210, alpha))
  end
end

local function loader_ui_outline(x1, y1, x2, y2, r, g, b, a, rounding, thickness)
  if ImGui.AddRect then
    ImGui.AddRect(x1, y1, x2, y2, r, g, b, a, rounding or 1, 0, thickness or 1)
  elseif ImGui.AddLine then
    ImGui.AddLine(x1, y1, x2, y1, r, g, b, a, thickness or 1)
    ImGui.AddLine(x2, y1, x2, y2, r, g, b, a, thickness or 1)
    ImGui.AddLine(x2, y2, x1, y2, r, g, b, a, thickness or 1)
    ImGui.AddLine(x1, y2, x1, y1, r, g, b, a, thickness or 1)
  end
end

local function loader_ui_line(x1, y1, x2, y2, r, g, b, a, thickness)
  if ImGui.AddLine then
    ImGui.AddLine(x1, y1, x2, y2, r, g, b, a, thickness or 1)
  else
    ImGui.AddRectFilled(x1, y1, x2, y2, r, g, b, a, 1)
  end
end

local function loader_ui_dot(x, y, radius, r, g, b, a)
  if ImGui.AddCircleFilled then
    ImGui.AddCircleFilled(x, y, radius, r, g, b, a, 12)
  else
    ImGui.AddRectFilled(x - radius, y - radius, x + radius, y + radius, r, g, b, a, radius)
  end
end

local function loader_ui_draw_frame(x, y, w, h, panel_alpha, content_alpha, elapsed)
  local glow = 22 + (18 * math.sin(elapsed * 3.1))
  ImGui.AddRectFilled(x - 18, y - 16, x + w + 18, y + h + 18, 28, 130, 78, loader_ui_scaled_alpha(glow, panel_alpha), 14)
  ImGui.AddRectFilled(x - 7, y - 7, x + w + 7, y + h + 7, 6, 9, 12, loader_ui_scaled_alpha(165, panel_alpha), 11)
  ImGui.AddRectFilled(x + 10, y + 14, x + w + 12, y + h + 14, 0, 0, 0, loader_ui_scaled_alpha(145, panel_alpha), 10)

  ImGui.AddRectFilled(x - 12, y + 34, x + 2, y + h - 34, 14, 20, 21, loader_ui_scaled_alpha(210, panel_alpha), 4)
  ImGui.AddRectFilled(x + w - 2, y + 34, x + w + 12, y + h - 34, 14, 20, 21, loader_ui_scaled_alpha(210, panel_alpha), 4)
  ImGui.AddRectFilled(x - 8, y + 56, x - 4, y + h - 56, 105, 255, 165, loader_ui_scaled_alpha(90, content_alpha), 2)
  ImGui.AddRectFilled(x + w + 4, y + 56, x + w + 8, y + h - 56, 215, 42, 42, loader_ui_scaled_alpha(100, content_alpha), 2)

  ImGui.AddRectFilled(x, y, x + w, y + h, 9, 12, 16, loader_ui_scaled_alpha(248, panel_alpha), 10)
  ImGui.AddRectFilled(x + 2, y + 2, x + w - 2, y + h - 2, 18, 22, 28, loader_ui_scaled_alpha(218, panel_alpha), 9)
  ImGui.AddRectFilled(x + 12, y + 12, x + w - 12, y + h - 12, 11, 15, 18, loader_ui_scaled_alpha(140, panel_alpha), 6)

  ImGui.AddRectFilled(x + 18, y + 12, x + w - 18, y + 45, 22, 28, 34, loader_ui_scaled_alpha(150, panel_alpha), 5)
  ImGui.AddRectFilled(x + 18, y + 44, x + w - 18, y + 45, 105, 255, 165, loader_ui_scaled_alpha(80, content_alpha), 1)
  ImGui.AddRectFilled(x + 18, y + h - 58, x + w - 18, y + h - 18, 17, 20, 27, loader_ui_scaled_alpha(150, content_alpha), 6)
  ImGui.AddRectFilled(x + 30, y + h - 58, x + w - 30, y + h - 57, 72, 255, 155, loader_ui_scaled_alpha(54, content_alpha), 1)

  loader_ui_outline(x, y, x + w, y + h, 105, 255, 165, loader_ui_scaled_alpha(95, panel_alpha), 10, 1)
  loader_ui_outline(x + 6, y + 6, x + w - 6, y + h - 6, 255, 255, 255, loader_ui_scaled_alpha(34, panel_alpha), 8, 1)

  local bracket = 36
  loader_ui_line(x + 12, y + 12, x + 12 + bracket, y + 12, 105, 255, 165, loader_ui_scaled_alpha(195, panel_alpha), 2)
  loader_ui_line(x + 12, y + 12, x + 12, y + 12 + 26, 105, 255, 165, loader_ui_scaled_alpha(195, panel_alpha), 2)
  loader_ui_line(x + w - 12 - bracket, y + 12, x + w - 12, y + 12, 215, 42, 42, loader_ui_scaled_alpha(205, panel_alpha), 2)
  loader_ui_line(x + w - 12, y + 12, x + w - 12, y + 12 + 26, 215, 42, 42, loader_ui_scaled_alpha(205, panel_alpha), 2)
  loader_ui_line(x + 12, y + h - 12, x + 12 + bracket, y + h - 12, 215, 42, 42, loader_ui_scaled_alpha(185, panel_alpha), 2)
  loader_ui_line(x + 12, y + h - 38, x + 12, y + h - 12, 215, 42, 42, loader_ui_scaled_alpha(185, panel_alpha), 2)
  loader_ui_line(x + w - 12 - bracket, y + h - 12, x + w - 12, y + h - 12, 105, 255, 165, loader_ui_scaled_alpha(185, panel_alpha), 2)
  loader_ui_line(x + w - 12, y + h - 38, x + w - 12, y + h - 12, 105, 255, 165, loader_ui_scaled_alpha(185, panel_alpha), 2)

  for i = 0, 2 do
    local dx = x + 30 + (i * 15)
    loader_ui_dot(dx, y + 29, 2.5, i == 0 and 215 or 72, i == 0 and 42 or 255, i == 0 and 42 or 155, loader_ui_scaled_alpha(190 - i * 35, content_alpha))
  end

  local scan = x + 24 + ((elapsed * 150) % math.max(1, w - 48))
  ImGui.AddRectFilled(scan, y + 14, scan + 2, y + h - 18, 105, 255, 165, loader_ui_scaled_alpha(36, content_alpha), 1)
end

local LOADER_UI_MATRIX_CHARS = "01KSC"

local function loader_ui_draw_matrix(sw, sh, elapsed, alpha)
  local cols = math.floor(sw / 34)
  if cols < 18 then cols = 18 end
  if cols > 58 then cols = 58 end

  local step = sw / cols
  local count = #LOADER_UI_MATRIX_CHARS
  local tick = math.floor(elapsed * 10)

  local grid_alpha = loader_ui_scaled_alpha(26, alpha)
  for gx = 0, sw, 96 do
    ImGui.AddRectFilled(gx, 0, gx + 1, sh, 20, 95, 55, grid_alpha, 1)
  end
  for gy = math.floor((elapsed * 24) % 96) - 96, sh, 96 do
    ImGui.AddRectFilled(0, gy, sw, gy + 1, 20, 95, 55, grid_alpha, 1)
  end

  for col = 1, cols do
    local x = (col - 0.72) * step
    local speed = 38 + ((col * 7) % 56)
    local head = ((elapsed * speed + col * 53) % (sh + 180)) - 90
    local trail = 6 + (col % 7)

    for row = 0, trail do
      local y = head - (row * 18)
      if y > -22 and y < sh + 22 then
        local idx = ((col * 13 + row * 17 + tick) % count) + 1
        local ch = LOADER_UI_MATRIX_CHARS:sub(idx, idx)
        local a = row == 0 and 185 or math.max(28, 120 - row * 13)
        local g = row == 0 and 255 or 185
        ImGui.AddText(x, y, ch, row == 0 and 190 or 35, g, row == 0 and 200 or 95, loader_ui_scaled_alpha(a, alpha))
      end
    end
  end

  local sweep = (elapsed * 180) % (sw + 220) - 220
  ImGui.AddRectFilled(sweep, 0, sweep + 2, sh, 120, 255, 170, loader_ui_scaled_alpha(60, alpha), 1)
  ImGui.AddRectFilled(sweep + 18, 0, sweep + 19, sh, 215, 42, 42, loader_ui_scaled_alpha(45, alpha), 1)

  if ImGui.AddLine then
    for i = 0, 2 do
      local d = ((elapsed * 112) + (i * 210)) % (sw + sh + 260) - 180
      ImGui.AddLine(d, 0, d - sh, sh, 72, 255, 155, loader_ui_scaled_alpha(38, alpha), 1)
    end
  end
end

local function loader_ui_draw()
  if not LOADER_UI.active or not ImGui then return end

  local sw, sh = ImGui.GetDisplaySize()
  if not sw or not sh or sw <= 0 or sh <= 0 then return end

  local now = (os and os.clock and os.clock()) or 0
  local alpha = 1.0
  local close_t = 0.0
  if LOADER_UI.fading then
    local fade_elapsed = math.max(0, now - (LOADER_UI.fade_started or now))
    close_t = loader_ui_smoothstep(loader_ui_clamp(fade_elapsed / (LOADER_UI.fade_duration or 1.25), 0, 1))
    alpha = 1.0 - close_t
    if alpha <= 0 then
      LOADER_UI.active = false
      LOADER_UI.fading = false
      loader_ui_remove_handler()
      return
    end
  end

  local p = loader_ui_clamp(LOADER_UI.progress, 0.01, 1.0)
  local elapsed = math.max(0, now - (LOADER_UI.started or 0))
  local open_t = loader_ui_ease_out(elapsed / (LOADER_UI.open_duration or 0.48))
  local content_alpha = alpha * loader_ui_smoothstep((open_t - 0.28) / 0.72)
  local panel_alpha = alpha * (0.35 + (0.65 * open_t))

  local base_w = math.min(600, sw - 40)
  if base_w < 340 then base_w = math.max(260, sw - 20) end
  local base_h = 276
  local scale_x = 0.74 + (0.26 * open_t)
  local scale_y = 0.10 + (0.90 * open_t)
  if LOADER_UI.fading then
    scale_x = scale_x * (1 - (0.05 * close_t))
    scale_y = scale_y * (1 - (0.24 * close_t))
  end

  local w = base_w * scale_x
  local h = base_h * scale_y
  local x = (sw - w) * 0.5
  local y = ((sh - h) * 0.5) + (16 * close_t)
  local dots = string.rep(".", math.floor((elapsed * 3) % 4))

  ImGui.AddRectFilled(0, 0, sw, sh, 0, 0, 0, loader_ui_scaled_alpha(135, alpha))
  loader_ui_draw_matrix(sw, sh, elapsed, alpha)
  ImGui.AddRectFilled(0, 0, sw, sh, 0, 0, 0, loader_ui_scaled_alpha(45, alpha))

  local cx = sw * 0.5
  local cy = (sh * 0.5) + (16 * close_t)
  local aperture_w = base_w * (0.12 + (0.88 * open_t)) * (1 - (0.05 * close_t))
  local aperture_h = math.max(4, base_h * scale_y)
  local aperture_a = loader_ui_scaled_alpha(120 + (95 * (1 - open_t)) + (70 * close_t), panel_alpha)
  ImGui.AddRectFilled(cx - (aperture_w * 0.5), cy - 2, cx + (aperture_w * 0.5), cy + 2, 105, 255, 165, aperture_a, 1)
  ImGui.AddRectFilled(cx - (aperture_w * 0.5), cy - (aperture_h * 0.5), cx - (aperture_w * 0.5) + 2, cy + (aperture_h * 0.5), 215, 42, 42, loader_ui_scaled_alpha(115, panel_alpha), 1)
  ImGui.AddRectFilled(cx + (aperture_w * 0.5) - 2, cy - (aperture_h * 0.5), cx + (aperture_w * 0.5), cy + (aperture_h * 0.5), 105, 255, 165, loader_ui_scaled_alpha(115, panel_alpha), 1)

  loader_ui_draw_frame(x, y, w, h, panel_alpha, content_alpha, elapsed)

  local scan_y = y + 10 + ((elapsed * 74) % (h - 24))
  ImGui.AddRectFilled(x + 14, scan_y, x + w - 14, scan_y + 1, 92, 255, 160, loader_ui_scaled_alpha(80, content_alpha), 1)

  local status_age = math.max(0, now - (LOADER_UI.status_started or LOADER_UI.started or now))
  local status_text = loader_ui_type_text(loader_ui_status_text(elapsed), status_age + 0.06, LOADER_UI.status == "running" and LOADER_UI_STATUS_TYPE_CPS or LOADER_UI_RESULT_TYPE_CPS)

  loader_ui_add_text_center(x, y + 16, w, loader_ui_type_text("K-Script Authentication", elapsed, 34), 255, 255, 255, loader_ui_scaled_alpha(255, content_alpha))
  loader_ui_add_text_center(x, y + 58, w, status_text, LOADER_UI.failed and 255 or (LOADER_UI.status == "success" and 155 or 235), LOADER_UI.failed and 80 or (LOADER_UI.status == "success" and 255 or 235), LOADER_UI.failed and 80 or (LOADER_UI.status == "success" and 190 or 235), loader_ui_scaled_alpha(255, content_alpha))

  local detail = LOADER_UI.detail
  if LOADER_UI.status == "running" then
    detail = detail .. dots
  end
  if detail ~= "" and #detail > 74 then
    detail = detail:sub(1, 71) .. "..."
  end
  loader_ui_add_text_center(x, y + 80, w, detail, 165, 172, 190, loader_ui_scaled_alpha(245, content_alpha))

  loader_ui_draw_checklist(x, y + 106, w, content_alpha, elapsed)

  local bx, by = x + 38, y + h - 45
  local bw, bh = w - 76, 14
  ImGui.AddRectFilled(bx, by, bx + bw, by + bh, 35, 38, 48, loader_ui_scaled_alpha(240, content_alpha), 6)
  ImGui.AddRectFilled(bx, by, bx + (bw * p), by + bh, LOADER_UI.failed and 220 or 215, LOADER_UI.failed and 55 or 42, LOADER_UI.failed and 55 or 42, loader_ui_scaled_alpha(255, content_alpha), 6)

  local shimmer = ((elapsed * 120) % (bw + 80)) - 80
  local sx1 = bx + shimmer
  local sx2 = math.min(sx1 + 58, bx + (bw * p))
  if sx2 > bx and sx1 < bx + (bw * p) then
    ImGui.AddRectFilled(math.max(sx1, bx), by + 2, sx2, by + bh - 2, 255, 118, 118, loader_ui_scaled_alpha(85, content_alpha), 5)
  end

  local pulse = 0.5 + (math.sin(elapsed * 4.2) * 0.5)
  ImGui.AddRectFilled(bx, by - 8, bx + (bw * pulse), by - 7, 70, 255, 150, loader_ui_scaled_alpha(70, content_alpha), 1)

  loader_ui_add_text_center(x, y + h - 22, w, string.format("%d%%", math.floor(p * 100 + 0.5)), 205, 210, 225, loader_ui_scaled_alpha(250, content_alpha))
end

if EventMgr and eLuaEvent and ImGui then
  local okUi, handler = pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, loader_ui_draw)
  if okUi then
    LOADER_UI.handler = handler
  end
end

local json_encode = nil
local json_decode = nil

local function _trunc_str(s, n)
  s = tostring(s or "")
  n = n or 2000
  if #s > n then return s:sub(1, n) .. "...(truncated)" end
  return s
end




local function u32(x) return x & 0xffffffff end
local function rotr(x, n) return u32((x >> n) | (x << (32 - n))) end
local function rshift(x, n) return u32(x >> n) end

local function ct_equal(a, b)
  if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then return false end
  local diff = 0
  for i=1,#a do
    diff = diff | ((a:byte(i) ~ b:byte(i)) & 0xff)
  end
  return diff == 0
end

local function bytes_to_hex(s)
  return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local HEX_BYTE_LOOKUP = {}
for i = 0, 255 do
  HEX_BYTE_LOOKUP[string.format("%02x", i)] = string.char(i)
end

local function hex_to_bytes(hex)
  hex = (hex or ""):gsub("%s+", ""):lower()
  if (#hex % 2) ~= 0 or not hex:match("^[0-9a-f]+$") then return nil end

  local t = {}
  local lookup = HEX_BYTE_LOOKUP
  local out_i = 1
  local next_yield = 8192
  for i = 1, #hex, 2 do
    local byte = lookup[hex:sub(i, i+1)]
    if not byte then return nil end
    t[out_i] = byte
    out_i = out_i + 1
    if i >= next_yield then
      loader_yield_if_due()
      next_yield = i + 8192
    end
  end

  return table.concat(t)
end

local function rand_hex(nbytes)
  local t = {}
  for _=1,nbytes do
    local b = math.random(0,255)
    t[#t+1] = string.format("%02x", b)
  end
  return table.concat(t)
end

local function sanitize_hex64(x)
  x = tostring(x or "")
  x = x:gsub("%s+", "")
  x = x:gsub('^"(.*)"$', "%1")
  x = x:lower()
  if #x ~= 64 then return nil end
  if not x:match("^[0-9a-f]+$") then return nil end
  return x
end

local function sanitize_hex_len(x, n)
  x = tostring(x or "")
  x = x:gsub("%s+", "")
  x = x:gsub('^"(.*)"$', "%1")
  x = x:lower()

  n = tonumber(n)
  if not n or n < 1 then return nil end
  if #x ~= n then return nil end
  if not x:match("^[0-9a-f]+$") then return nil end

  return x
end




local function _json_escape(s)
  return s:gsub('[\\\"\b\f\n\r\t]', {
    ['\\']='\\\\', ['"']='\\"', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'
  })
end

local function _json_encode_val(v)
  local tv = type(v)
  if tv == "nil" then return "null"
  elseif tv == "boolean" then return v and "true" or "false"
  elseif tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    return tostring(v)
  elseif tv == "string" then
    return '"'.._json_escape(v)..'"'
  elseif tv == "table" then
    local isArr = true
    local max = 0
    for k,_ in pairs(v) do
      if type(k) ~= "number" then isArr = false; break end
      if k > max then max = k end
    end
    if isArr then
      local out = {}
      for i=1,max do out[#out+1] = _json_encode_val(v[i]) end
      return "["..table.concat(out,",").."]"
    else
      local out = {}
      for k,val in pairs(v) do
        out[#out+1] = _json_encode_val(tostring(k))..":".._json_encode_val(val)
      end
      return "{"..table.concat(out,",").."}"
    end
  else
    return "null"
  end
end

if type(json_encode) ~= "function" then
  json_encode = function(tbl) return _json_encode_val(tbl) end
end

if type(json_decode) ~= "function" then
  local function _skip_ws(s,i)
    while true do
      local c = s:sub(i,i)
      if c == "" then return i end
      if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then return i end
      i = i + 1
    end
  end

  local function _parse_string(s,i)
    i = i + 1
    local close = s:find('"', i, true)
    local escape = s:find("\\", i, true)
    if close and (not escape or escape > close) then
      return s:sub(i, close - 1), close + 1
    end

    local out = {}
    while true do
      loader_yield_if_due()
      local c = s:sub(i,i)
      if c == "" then return nil, "unterminated string" end
      if c == '"' then return table.concat(out), i+1 end
      if c == "\\" then
        local n = s:sub(i+1,i+1)
        if n == '"' or n == "\\" or n == "/" then out[#out+1]=n; i=i+2
        elseif n == "b" then out[#out+1]="\b"; i=i+2
        elseif n == "f" then out[#out+1]="\f"; i=i+2
        elseif n == "n" then out[#out+1]="\n"; i=i+2
        elseif n == "r" then out[#out+1]="\r"; i=i+2
        elseif n == "t" then out[#out+1]="\t"; i=i+2
        else return nil, "bad escape" end
      else
        out[#out+1]=c; i=i+1
      end
    end
  end

  local function _parse_number(s,i)
    local j = i
    while s:sub(j,j):match("[0-9%+%-%e%E%.]") do j=j+1 end
    local num = tonumber(s:sub(i,j-1))
    if num == nil then return nil, "bad number" end
    return num, j
  end

  local function _parse_value(s,i)
    i = _skip_ws(s,i)
    local c = s:sub(i,i)
    if c == '"' then
      return _parse_string(s,i)
    elseif c == "{" then
      local obj = {}
      i = _skip_ws(s,i+1)
      if s:sub(i,i) == "}" then return obj, i+1 end
      while true do
        i = _skip_ws(s,i)
        if s:sub(i,i) ~= '"' then return nil, "expected string key" end
        local key; key,i = _parse_string(s,i)
        if not key then return nil, i end
        i = _skip_ws(s,i)
        if s:sub(i,i) ~= ":" then return nil, "expected ':'" end
        local val; val,i = _parse_value(s,i+1)
        if val == nil and type(i)=="string" then return nil,i end
        obj[key] = val
        i = _skip_ws(s,i)
        local d = s:sub(i,i)
        if d == "}" then return obj, i+1 end
        if d ~= "," then return nil, "expected ','" end
        i = i + 1
      end
    elseif c == "[" then
      local arr = {}
      i = _skip_ws(s,i+1)
      if s:sub(i,i) == "]" then return arr, i+1 end
      local idx = 1
      while true do
        local val; val,i = _parse_value(s,i)
        if val == nil and type(i)=="string" then return nil,i end
        arr[idx]=val; idx=idx+1
        i = _skip_ws(s,i)
        local d = s:sub(i,i)
        if d == "]" then return arr, i+1 end
        if d ~= "," then return nil, "expected ','" end
        i = i + 1
      end
    else
      local rest = s:sub(i)
      if rest:sub(1,4) == "true" then return true, i+4 end
      if rest:sub(1,5) == "false" then return false, i+5 end
      if rest:sub(1,4) == "null" then return nil, i+4 end
      return _parse_number(s,i)
    end
  end

  json_decode = function(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("^\239\187\191", "")
    local ok, valOrErr, idxOrErr = pcall(_parse_value, s, 1)
    if not ok then
      return nil
    end
    if valOrErr == nil and type(idxOrErr)=="string" then
      return nil
    end
    return valOrErr
  end
end

local function decode_payload_response(body)
  if type(body) ~= "string" then return nil end

  local payload = {}
  payload.error = body:match('"error"%s*:%s*"([^"]*)"') or body:match('"e"%s*:%s*"([^"]*)"')
  payload.skip = body:match('"skip"%s*:%s*true') ~= nil or body:match('"skip"%s*:%s*"true"') ~= nil or body:match('"s"%s*:%s*true') ~= nil or body:match('"s"%s*:%s*"true"') ~= nil
  payload.kind = body:match('"kind"%s*:%s*"([^"]*)"') or body:match('"k"%s*:%s*"([^"]*)"')
  payload.reason = body:match('"reason"%s*:%s*"([^"]*)"') or body:match('"r"%s*:%s*"([^"]*)"')
  payload.v = body:match('"v"%s*:%s*([%d%-]+)') or body:match('"v"%s*:%s*"([^"]*)"')
  payload.exp = body:match('"exp"%s*:%s*([%d%-]+)') or body:match('"exp"%s*:%s*"([^"]*)"') or body:match('"x"%s*:%s*([%d%-]+)') or body:match('"x"%s*:%s*"([^"]*)"')
  payload.ctr = body:match('"ctr"%s*:%s*([%d%-]+)') or body:match('"ctr"%s*:%s*"([^"]*)"') or body:match('"c"%s*:%s*([%d%-]+)') or body:match('"c"%s*:%s*"([^"]*)"')
  payload.nonce = body:match('"nonce"%s*:%s*"([0-9a-fA-F]+)"') or body:match('"n"%s*:%s*"([0-9a-fA-F]+)"')
  payload.ct = body:match('"ct"%s*:%s*"([0-9a-fA-F]+)"') or body:match('"d"%s*:%s*"([0-9a-fA-F]+)"')
  payload.mac = body:match('"mac"%s*:%s*"([0-9a-fA-F]+)"') or body:match('"m"%s*:%s*"([0-9a-fA-F]+)"')

  if payload.error or payload.skip or (payload.v and payload.exp and payload.ctr and payload.nonce and payload.ct and payload.mac) then
    return payload
  end

  return nil
end




local K = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}

local function sha256(msg)
  local H0,H1,H2,H3,H4,H5,H6,H7 =
    0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19

  local ml = #msg * 8
  msg = msg .. "\128"
  local pad = (56 - (#msg % 64)) % 64
  msg = msg .. string.rep("\0", pad)

  local hi = math.floor(ml / 0x100000000)
  local lo = ml % 0x100000000
  msg = msg .. string.char(
    (hi>>24)&0xff,(hi>>16)&0xff,(hi>>8)&0xff,hi&0xff,
    (lo>>24)&0xff,(lo>>16)&0xff,(lo>>8)&0xff,lo&0xff
  )

  local function pack32(x)
    return string.char((x>>24)&0xff,(x>>16)&0xff,(x>>8)&0xff,x&0xff)
  end

  local w = {}
  for off=1,#msg,64 do
    loader_yield_if_due()
    for i=0,15 do
      local a,b,c,d = msg:byte(off+i*4, off+i*4+3)
      w[i] = u32((a<<24) | (b<<16) | (c<<8) | d)
    end
    for i=16,63 do
      local v = w[i-15]
      local s0 = u32(rotr(v,7) ~ rotr(v,18) ~ rshift(v,3))
      v = w[i-2]
      local s1 = u32(rotr(v,17) ~ rotr(v,19) ~ rshift(v,10))
      w[i] = u32(w[i-16] + s0 + w[i-7] + s1)
    end

    local a,b,c,d,e,f,g,h = H0,H1,H2,H3,H4,H5,H6,H7
    for i=0,63 do
      local S1 = u32(rotr(e,6) ~ rotr(e,11) ~ rotr(e,25))
      local ch = u32((e & f) ~ ((~e) & g))
      local temp1 = u32(h + S1 + ch + K[i+1] + w[i])
      local S0 = u32(rotr(a,2) ~ rotr(a,13) ~ rotr(a,22))
      local maj = u32((a & b) ~ (a & c) ~ (b & c))
      local temp2 = u32(S0 + maj)
      h=g; g=f; f=e; e=u32(d + temp1)
      d=c; c=b; b=a; a=u32(temp1 + temp2)
    end

    H0=u32(H0+a); H1=u32(H1+b); H2=u32(H2+c); H3=u32(H3+d)
    H4=u32(H4+e); H5=u32(H5+f); H6=u32(H6+g); H7=u32(H7+h)
  end

  return pack32(H0)..pack32(H1)..pack32(H2)..pack32(H3)..pack32(H4)..pack32(H5)..pack32(H6)..pack32(H7)
end

local function hmac_sha256(key, data)
  local block = 64
  if #key > block then key = sha256(key) end
  if #key < block then key = key .. string.rep("\0", block-#key) end

  local o = {}
  local i = {}
  for idx=1,block do
    local kb = key:byte(idx)
    o[idx] = string.char((kb ~ 0x5c) & 0xff)
    i[idx] = string.char((kb ~ 0x36) & 0xff)
  end
  o = table.concat(o)
  i = table.concat(i)
  return sha256(o .. sha256(i .. data))
end




local function le_u32(b1,b2,b3,b4) return u32(b1 | (b2<<8) | (b3<<16) | (b4<<24)) end
local function u32_to_le(x) return string.char(x&0xff,(x>>8)&0xff,(x>>16)&0xff,(x>>24)&0xff) end

local function quarterround(s, a,b,c,d)
  s[a]=u32(s[a]+s[b]); s[d]=u32(((s[d] ~ s[a])<<16) | ((s[d] ~ s[a])>>16))
  s[c]=u32(s[c]+s[d]); s[b]=u32(((s[b] ~ s[c])<<12) | ((s[b] ~ s[c])>>20))
  s[a]=u32(s[a]+s[b]); s[d]=u32(((s[d] ~ s[a])<<8)  | ((s[d] ~ s[a])>>24))
  s[c]=u32(s[c]+s[d]); s[b]=u32(((s[b] ~ s[c])<<7)  | ((s[b] ~ s[c])>>25))
end

local function chacha20_block(key32, counter, nonce12)
  local constants = {0x61707865,0x3320646e,0x79622d32,0x6b206574}
  local s = {}
  s[1],s[2],s[3],s[4] = constants[1],constants[2],constants[3],constants[4]
  for i=0,7 do
    local o = i*4
    local b1,b2,b3,b4 = key32:byte(1+o,4+o)
    s[5+i] = le_u32(b1,b2,b3,b4)
  end
  s[13] = u32(counter)
  do
    local b1,b2,b3,b4 = nonce12:byte(1,4);  s[14]=le_u32(b1,b2,b3,b4)
    b1,b2,b3,b4 = nonce12:byte(5,8);        s[15]=le_u32(b1,b2,b3,b4)
    b1,b2,b3,b4 = nonce12:byte(9,12);       s[16]=le_u32(b1,b2,b3,b4)
  end

  local w = {}
  for i=1,16 do w[i]=s[i] end
  for _=1,10 do
    quarterround(w,1,5,9,13);  quarterround(w,2,6,10,14); quarterround(w,3,7,11,15); quarterround(w,4,8,12,16)
    quarterround(w,1,6,11,16); quarterround(w,2,7,12,13); quarterround(w,3,8,9,14);  quarterround(w,4,5,10,15)
  end

  local out={}
  for i=1,16 do out[i]=u32_to_le(u32(w[i]+s[i])) end
  return table.concat(out)
end

local function chacha20_xor(key32, nonce12, counter, data)
  local ctr = math.tointeger(counter)
  if not ctr then
    return nil
  end

  local out = {}
  local pos = 1
  local len = #data

  while pos <= len do
    loader_yield_if_due()
    local keyblock = chacha20_block(key32, ctr, nonce12)
    ctr = u32(ctr + 1)

    local chunk = data:sub(pos, pos + 63)
    local x = {}
    for i = 1, #chunk do
      x[i] = string.char((chunk:byte(i) ~ keyblock:byte(i)) & 0xff)
    end

    out[#out + 1] = table.concat(x)
    pos = pos + 64
  end

  return table.concat(out)
end




local function gf(init)
  local r = {}
  for i = 1, 16 do r[i] = 0 end
  if init then
    for i = 1, #init do r[i] = init[i] end
  end
  return r
end

local X25519_121665 = gf({ 0xdb41, 1 })
local X25519_BASE_POINT = string.char(9) .. string.rep("\0", 31)

local function car25519(o)
  local c = 1
  for i = 1, 16 do
    local v = o[i] + c + 65535
    c = math.floor(v / 65536)
    o[i] = v - c * 65536
  end
  o[1] = o[1] + c - 1 + 37 * (c - 1)
end

local function sel25519(p, q, b)
  local c = ~(b - 1)
  for i = 1, 16 do
    local t = c & (p[i] ~ q[i])
    p[i] = p[i] ~ t
    q[i] = q[i] ~ t
  end
end

local function unpack25519(n)
  local o = gf()
  for i = 1, 16 do
    local b1 = n:byte(2 * i - 1) or 0
    local b2 = n:byte(2 * i) or 0
    o[i] = b1 | (b2 << 8)
  end
  o[16] = o[16] & 0x7fff
  return o
end

local function pack25519(n)
  local m = gf()
  local t = gf()
  for i = 1, 16 do t[i] = n[i] end
  car25519(t); car25519(t); car25519(t)

  for _ = 1, 2 do
    m[1] = t[1] - 0xffed
    for i = 2, 15 do
      m[i] = t[i] - 0xffff - ((m[i - 1] >> 16) & 1)
      m[i - 1] = m[i - 1] & 0xffff
    end
    m[16] = t[16] - 0x7fff - ((m[15] >> 16) & 1)
    local b = (m[16] >> 16) & 1
    m[15] = m[15] & 0xffff
    sel25519(t, m, 1 - b)
  end

  local out = {}
  for i = 1, 16 do
    out[#out + 1] = string.char(t[i] & 0xff)
    out[#out + 1] = string.char((t[i] >> 8) & 0xff)
  end
  return table.concat(out)
end

local function fe_add(o, a, b) for i = 1, 16 do o[i] = a[i] + b[i] end end
local function fe_sub(o, a, b) for i = 1, 16 do o[i] = a[i] - b[i] end end

local function fe_mul(o, a, b)
  local v = {}
  for i = 1, 31 do v[i] = 0 end
  for i = 1, 16 do
    for j = 1, 16 do
      v[i + j - 1] = v[i + j - 1] + a[i] * b[j]
    end
  end
  for i = 1, 15 do v[i] = v[i] + 38 * v[i + 16] end
  for i = 1, 16 do o[i] = v[i] end
  car25519(o); car25519(o)
end

local function fe_square(o, a)
  fe_mul(o, a, a)
end

local function inv25519(o, i)
  local c = gf()
  for a = 1, 16 do c[a] = i[a] end
  for a = 253, 0, -1 do
    fe_square(c, c)
    if a ~= 2 and a ~= 4 then fe_mul(c, c, i) end
  end
  for a = 1, 16 do o[a] = c[a] end
end

local function x25519(scalar, point)
  if type(scalar) ~= "string" or #scalar ~= 32 or type(point) ~= "string" or #point ~= 32 then
    return nil
  end

  local z = {}
  for i = 1, 32 do z[i] = scalar:byte(i) or 0 end
  z[32] = (z[32] & 127) | 64
  z[1] = z[1] & 248

  local x = unpack25519(point)
  local a, b, c, d, e, f = gf(), gf(), gf(), gf(), gf(), gf()
  for i = 1, 16 do
    b[i] = x[i]
    a[i] = 0
    c[i] = 0
    d[i] = 0
  end
  a[1] = 1
  d[1] = 1

  for i = 254, 0, -1 do
    local r = (z[(i >> 3) + 1] >> (i & 7)) & 1
    sel25519(a, b, r); sel25519(c, d, r)
    fe_add(e, a, c); fe_sub(a, a, c); fe_add(c, b, d); fe_sub(b, b, d)
    fe_square(d, e); fe_square(f, a); fe_mul(a, c, a); fe_mul(c, b, e)
    fe_add(e, a, c); fe_sub(a, a, c); fe_square(b, a); fe_sub(c, d, f)
    fe_mul(a, c, X25519_121665); fe_add(a, a, d); fe_mul(c, c, a)
    fe_mul(a, d, f); fe_mul(d, b, x); fe_square(b, e)
    sel25519(a, b, r); sel25519(c, d, r)
  end

  local ci = gf()
  for i = 1, 16 do ci[i] = c[i] end
  inv25519(ci, ci)
  fe_mul(a, a, ci)
  return pack25519(a)
end

local function is_all_zero_bytes(s)
  if type(s) ~= "string" then return false end
  for i = 1, #s do
    if s:byte(i) ~= 0 then return false end
  end
  return true
end

local function make_x25519_private(uid, hid, hello_nonce, client_nonce, bearer_token)
  local material = table.concat({
    "x25519-client-v1",
    rand_hex(32),
    tostring((os and os.time and os.time()) or 0),
    tostring((os and os.clock and os.clock()) or 0),
    tostring({}),
    tostring(function() end),
    tostring(uid),
    tostring(hid),
    tostring(hello_nonce),
    tostring(client_nonce),
    tostring(bearer_token or "")
  }, "|")
  return sha256(material)
end




local function derive_session_key(sharedSecret, uid, sid, exp, saltHex, partAHex, proofHex, clientPubHex, serverPubHex)
  local msg =
    "sess|" ..
    tostring(uid) .. "|" ..
    tostring(sid) .. "|" ..
    tostring(exp) .. "|" ..
    tostring(saltHex) .. "|" ..
    tostring(partAHex) .. "|" ..
    tostring(proofHex) .. "|" ..
    tostring(clientPubHex) .. "|" ..
    tostring(serverPubHex)
  return hmac_sha256(sharedSecret, msg)
end

local function derive_payload_key(sessKey)
  return hmac_sha256(sessKey, "KScript|payload|v16|LexisSucks|IfYoureReadingThisYourARetard")
end




local function run_anti_hook_checks()
  local dbg = rawget(_G, "debug")
  if type(dbg) ~= "table" or type(dbg.getinfo) ~= "function" or type(dbg.getupvalue) ~= "function" then
    FAIL("E0(DBG)")
    Logger.LogError("anti-hook debug helpers unavailable", 0)
    os.exit(1337)
    return false
  end

  local function isHooked(func, funcName)
    if type(func) ~= "function" then
      return true, "not a function"
    end

    local okInfo, info = pcall(dbg.getinfo, func)
    if not okInfo or not info then
      return true, "no debug info"
    end

    local upvalues = {}
    for i = 1, math.huge do
      local okUp, name = pcall(dbg.getupvalue, func, i)
      if not okUp or not name or name == "" then break end
      upvalues[#upvalues + 1] = tostring(name)
    end

    local suspiciousUpvalues = {
      "original", "old", "hook", "HookedFunction", "__original",
      "oldfunc", "detour", "hookedfunc", "prev", "backup"
    }
    for _, bad in ipairs(suspiciousUpvalues) do
      for _, up in ipairs(upvalues) do
        if up:lower():find(bad:lower(), 1, true) then
          return true, ("suspicious upvalue: %s"):format(up)
        end
      end
    end

    if #upvalues > 0 then
      return true, ("unexpected upvalues (%d)"):format(#upvalues)
    end

    if info.what ~= "C" then
      return true, ("not a C function (what=%s)"):format(tostring(info.what))
    end

    if info.name and info.name ~= "" and info.name ~= funcName then
      return true, ("suspicious name: %s"):format(info.name)
    end

    return false
  end

  local critical = {
    { io and io.open, "io.open" },
    { load, "load" },
    { rawget(_G, "loadstring") or load, "loadstring" },
    { Cherax and Cherax.GetUID, "GetUID" },
    { string and string.char, "string.char" },
  }

  for _, tuple in ipairs(critical) do
    local func, name = tuple[1], tuple[2]
    if not func then
      FAIL("E0(MISS:" .. tostring(name) .. ")")
      Logger.LogError(string.format("%s missing!", tostring(name)), 0)
      os.exit(1337)
      return false
    end

    local hooked, reason = isHooked(func, name)
    if hooked then

      Logger.Loginfo("imagine bro")
      Logger.Loginfo([[
            
     ***** ***#  =:::............::=*  ***###***%                                                   
    *++++++++++-:....................:=++++++++++*               +********+*                        
   ++++++++++=:........................:=+++++++++*           *+++++++++++++++*                     
   ++++++++++=:........................:++++++++++         %*++++++++++++++++++++                   
   #++++++++=:.........................:-=++++++++        *+++++++*##  %#*++++++++*                 
   +++++++=:.....:-::..............:-::..:-+++++++*      #+++++*%           #+++++++                
   #++-:-::....:+###*:...........:+###+-...::::=++      @++++++     *++*#     +++++++               
    *-:.......:=#####+..........:+#####=:......:+       ++++++*    ++++++++    *+++++*              
    -.........:=#####+..........:+#####=:........*      ++++++     *+++++++*    +++++*              
   %........:..-*###*-...........-*###*-..........      ++++++#       #*++++#   *+++++%             
   :............:-=-:.............:-=-:...........      %++++++        +++++#   *++++*%             
   .......::::::.....:..:=+++=:::......:::........-      #++++++*#    #+++++#    ++++*#             
   .....::-=-=--:.....:-*#####*-:...::--==--::....=*#     #++++++++++++++++*     ++++*%             
   ....:---=====-::..::*#######+:..:--=======-:...+++++**+  *+++++++++++++%      ++++*%             
   ....--========-:...:+#######+:..:-========-:..:++++++++++*  #**+++++**        ++++*#             
   #:..:-========-:....:+*###*=::..:-========-:..-+++++++++++++#                 ++++*#             
    :..::-======-:::.....::-::.....::=======-:..:+++++++++++++++*#               ++++*#             
    *:...::----=*+=-::...:.....:::-=++=---:::..:=+++++++++++++++++*              ++++*#             
     :.......:::=***+++==----==+++**+=:.......:-+++++++++++++++++++*             ++++*#             
      -.........:-+****************=::.......:-++++++++++++++++++++++            ++++*#             
       +:........::-=***********+=-:::.....::=+++++++++++++++++++++++*           ++++*%             
         =:.........::-=+++++==-:::.......:-++++++++++++++++++++++++++#          ++++*%             
           =:........:...........::......:***++++++++++++++++++++++++++          ++++*#             
             -::......................:-=   ++++++++++++++++++++++++++++         ++++*#             
                =::::............::::-     +++++++++++++++++++++++++++++         ++++*#             
                     ##*-::::-+*          *+++++++++++++++++++++++++++++#        ++++*%             
                                         #*+++++++++++++++++++++++++++++*        ++++*%             
                                        ++++++++++++++++++++++++++++++++*        ++++*#             
                                      *+++++++*++++++++++++++++++++++++++        ++++*%             
                                     *+++++++*+++++++++++++++++++++++++++%       ++++*%             
                                    *+++++++ *+++++++++++++++++++++++++++%      *++++*%             
                                  #*++++++*  *+++++++++++++++++++++++++++       *+++++%             
                                 *+++++++*   *++++++++++++++++++++++++++*       *+++++              
                                *+++++++*    #++++++++++++++++++++++++++*      #+++++*              
                               *+++++++#     #++++++++++++++++++++++++++*     *++++++               
                              *++++++++#     *++++++++++++++++++++++++++*   %+++++++                
                              +++++++++#     **+++++++++++++++++++++++++##++++++++*                 
                             #+++++++++#      *++++++++++++++++++++++++++++++++++*                  
                             #++++++++++       *++++++++++++++++++++++++++++++*                     
                             #+++++++++++       ##++++++++++++++++++++++++#*#                       
                              ++++++++++++++*    #+++++++++++++++++++++*                            
                               ++++++++++++++# +++++++++++++++++++++++*                             
                                *+++++++++++* *+++++++++++++++++++++++                              
                                  **++++++**  *+++++++++++++++++++++*                               
                                     %###       %#%%%%%%%%%%%%%%%%#                                 
            
            ]])
      os.exit(1337)
      return false
    end
  end

  _G.debug = nil
  debug = nil
  return true
end

local function get_runtime_hash()
  local s = {}
  s[#s+1] = tostring(load)
  s[#s+1] = tostring(pcall)
  s[#s+1] = tostring(type)
  s[#s+1] = tostring(_G)
  local blob = table.concat(s, "|")
  return bytes_to_hex(sha256(blob))
end

local function derive_hello_bound_proof(uid, hid, hello_nonce, client_nonce, build, bearer_token, client_pub_hex)
  local msg = "proof|" .. tostring(uid) .. "|" .. tostring(hid) .. "|" .. tostring(hello_nonce) .. "|" .. tostring(client_nonce) .. "|" .. tostring(build) .. "|" .. tostring(bearer_token or "") .. "|" .. tostring(client_pub_hex or "")
  return bytes_to_hex(sha256(msg))
end




local function normalize_http_response(resp, label)
  label = label or "resp"
  local t = type(resp)
  if t == "table" then
    local body = resp.body or resp.Body or resp.data or resp.Data or resp.text or resp.Text or resp.response or resp.Response
    local status = resp.status or resp.Status or resp.code or resp.Code
    if type(body) == "string" then
      resp = body
      t = "string"
    else
      return nil, false, false
    end
  end
  if t ~= "string" then return nil, false, false end

  resp = resp:gsub("^\239\187\191","")
  resp = resp:gsub("^%s+","")
  local header_end = resp:find("\r\n\r\n", 1, true)
  if header_end then
    resp = resp:sub(header_end+4):gsub("^%s+","")
  end
  return resp, true, false
end




local LOAD_FN = rawget(_G, "load") or load
local _rawset = rawset
local _tostring = tostring
local _type = type

local ALLOWED_PATH_PREFIXES = {
  ".\\Lua\\K-Script\\",
  "\\Lua\\K-Script\\",
  FileMgr.GetMenuRootPath() .. "\\Lua\\",
  "\\AppData\\Roaming\\discord"
}

local function _norm_path(p)
  p = _tostring(p or "")
  p = p:gsub("/", "\\")
  while p:find("\\\\", 1, true) do p = p:gsub("\\\\", "\\") end
  return p
end

local function _is_path_allowed(p)
  if not ALLOWED_PATH_PREFIXES or #ALLOWED_PATH_PREFIXES == 0 then return true end
  p = _norm_path(p)
  if p:find("..", 1, true) then return false end

  local pl = p:lower()
  for _, pref in ipairs(ALLOWED_PATH_PREFIXES) do
    local pr = _norm_path(pref):lower()
    if pr ~= "" then
      if pr:match("^%a:\\") or pr:match("^%.\\") then
        if pl:sub(1, #pr) == pr then return true end
      else
        if pl:find(pr, 1, true) then return true end
      end
    end
  end
  return false
end

local EMBEDDED_JSON_LIB = [===[
function load_json_lib()
    local always_try_using_lpeg = true
    local register_global_module_table = false
    local global_module_name = 'json'
    local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
          pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
    local error, require, pcall, select = error, require, pcall, select
    local floor, huge = math.floor, math.huge
    local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
          string.rep, string.gsub, string.sub, string.byte, string.char,
          string.find, string.len, string.format
    local strmatch = string.match
    local concat = table.concat
    
    local json = { version = "dkjson 2.5" }
    
    if register_global_module_table then
      _G[global_module_name] = json
    end
    
    local _ENV = nil 
    
    pcall (function()
      local debmeta = require "debug".getmetatable
      if debmeta then getmetatable = debmeta end
    end)
    
    json.null = setmetatable ({}, {
      __tojson = function() return "null" end
    })
    
    local function isarray (tbl)
      local max, n, arraylen = 0, 0, 0
      for k,v in pairs (tbl) do
        if k == 'n' and type(v) == 'number' then
          arraylen = v
          if v > max then
            max = v
          end
        else
          if type(k) ~= 'number' or k < 1 or floor(k) ~= k then
            return false
          end
          if k > max then
            max = k
          end
          n = n + 1
        end
      end
      if max > 10 and max > arraylen and max > n * 2 then
        return false 
      end
      return true, max
    end
    
    local escapecodes = {
      ["\""] = "\\\"", ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
      ["\n"] = "\\n",  ["\r"] = "\\r",  ["\t"] = "\\t"
    }
    
    local function escapeutf8 (uchar)
      local value = escapecodes[uchar]
      if value then
        return value
      end
      local a, b, c, d = strbyte (uchar, 1, 4)
      a, b, c, d = a or 0, b or 0, c or 0, d or 0
      if a <= 0x7f then
        value = a
      elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
        value = (a - 0xc0) * 0x40 + b - 0x80
      elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
        value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
      elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
        value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
      else
        return ""
      end
      if value <= 0xffff then
        return strformat ("\\u%.4x", value)
      elseif value <= 0x10ffff then
        value = value - 0x10000
        local highsur, lowsur = 0xD800 + floor (value/0x400), 0xDC00 + (value % 0x400)
        return strformat ("\\u%.4x\\u%.4x", highsur, lowsur)
      else
        return ""
      end
    end
    
    local function fsub (str, pattern, repl)
      if strfind (str, pattern) then
        return gsub (str, pattern, repl)
      else
        return str
      end
    end
    
    local function quotestring (value)
      value = fsub (value, "[%z\1-\31\"\\\127]", escapeutf8)
      if strfind (value, "[\194\216\220\225\226\239]") then
        value = fsub (value, "\194[\128-\159\173]", escapeutf8)
        value = fsub (value, "\216[\128-\132]", escapeutf8)
        value = fsub (value, "\220\143", escapeutf8)
        value = fsub (value, "\225\158[\180\181]", escapeutf8)
        value = fsub (value, "\226\128[\140-\143\168-\175]", escapeutf8)
        value = fsub (value, "\226\129[\160-\175]", escapeutf8)
        value = fsub (value, "\239\187\191", escapeutf8)
        value = fsub (value, "\239\191[\176-\191]", escapeutf8)
      end
      return "\"" .. value .. "\""
    end
    json.quotestring = quotestring
    
    local function replace(str, o, n)
      local i, j = strfind (str, o, 1, true)
      if i then
        return strsub(str, 1, i-1) .. n .. strsub(str, j+1, -1)
      else
        return str
      end
    end
    
    local decpoint, numfilter
    
    local function updatedecpoint ()
      decpoint = strmatch(tostring(0.5), "([^05+])")
      numfilter = "[^0-9%-%+eE" .. gsub(decpoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
    end
    
    updatedecpoint()
    
    local function num2str (num)
      return replace(fsub(tostring(num), numfilter, ""), decpoint, ".")
    end
    
    local function str2num (str)
      local num = tonumber(replace(str, ".", decpoint))
      if not num then
        updatedecpoint()
        num = tonumber(replace(str, ".", decpoint))
      end
      return num
    end
    
    local function addnewline2 (level, buffer, buflen)
      buffer[buflen+1] = "\n"
      buffer[buflen+2] = strrep ("  ", level)
      buflen = buflen + 2
      return buflen
    end
    
    function json.addnewline (state)
      if state.indent then
        state.bufferlen = addnewline2 (state.level or 0,
                               state.buffer, state.bufferlen or #(state.buffer))
      end
    end
    
    local encode2 
    
    local function addpair (key, value, prev, indent, level, buffer, buflen, tables, globalorder, state)
      local kt = type (key)
      if kt ~= 'string' and kt ~= 'number' then
        return nil, "type '" .. kt .. "' is not supported as a key by JSON."
      end
      if prev then
        buflen = buflen + 1
        buffer[buflen] = ","
      end
      if indent then
        buflen = addnewline2 (level, buffer, buflen)
      end
      buffer[buflen+1] = quotestring (key)
      buffer[buflen+2] = ":"
      return encode2 (value, indent, level, buffer, buflen + 2, tables, globalorder, state)
    end
    
    local function appendcustom(res, buffer, state)
      local buflen = state.bufferlen
      if type (res) == 'string' then
        buflen = buflen + 1
        buffer[buflen] = res
      end
      return buflen
    end
    
    local function exception(reason, value, state, buffer, buflen, defaultmessage)
      defaultmessage = defaultmessage or reason
      local handler = state.exception
      if not handler then
        return nil, defaultmessage
      else
        state.bufferlen = buflen
        local ret, msg = handler (reason, value, state, defaultmessage)
        if not ret then return nil, msg or defaultmessage end
        return appendcustom(ret, buffer, state)
      end
    end
    
    function json.encodeexception(reason, value, state, defaultmessage)
      return quotestring("<" .. defaultmessage .. ">")
    end
    
    encode2 = function(value, indent, level, buffer, buflen, tables, globalorder, state)
      local valtype = type (value)
      local valmeta = getmetatable (value)
      valmeta = type (valmeta) == 'table' and valmeta
      local valtojson = valmeta and valmeta.__tojson
      if valtojson then
        if tables[value] then
          return exception('reference cycle', value, state, buffer, buflen)
        end
        tables[value] = true
        state.bufferlen = buflen
        local ret, msg = valtojson (value, state)
        if not ret then return exception('custom encoder failed', value, state, buffer, buflen, msg) end
        tables[value] = nil
        buflen = appendcustom(ret, buffer, state)
      elseif value == nil then
        buflen = buflen + 1
        buffer[buflen] = "null"
      elseif valtype == 'number' then
        local s
        if value ~= value or value >= huge or -value >= huge then
          s = "null"
        else
          s = num2str (value)
        end
        buflen = buflen + 1
        buffer[buflen] = s
      elseif valtype == 'boolean' then
        buflen = buflen + 1
        buffer[buflen] = value and "true" or "false"
      elseif valtype == 'string' then
        buflen = buflen + 1
        buffer[buflen] = quotestring (value)
      elseif valtype == 'table' then
        if tables[value] then
          return exception('reference cycle', value, state, buffer, buflen)
        end
        tables[value] = true
        level = level + 1
        local isa, n = isarray (value)
        if n == 0 and valmeta and valmeta.__jsontype == 'object' then
          isa = false
        end
        local msg
        if isa then 
          buflen = buflen + 1
          buffer[buflen] = "["
          for i = 1, n do
            buflen, msg = encode2 (value[i], indent, level, buffer, buflen, tables, globalorder, state)
            if not buflen then return nil, msg end
            if i < n then
              buflen = buflen + 1
              buffer[buflen] = ","
            end
          end
          buflen = buflen + 1
          buffer[buflen] = "]"
        else 
          local prev = false
          buflen = buflen + 1
          buffer[buflen] = "{"
          local order = valmeta and valmeta.__jsonorder or globalorder
          if order then
            local used = {}
            n = #order
            for i = 1, n do
              local k = order[i]
              local v = value[k]
              if v then
                used[k] = true
                buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
                prev = true  
              end
            end
            for k,v in pairs (value) do
              if not used[k] then
                buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
                if not buflen then return nil, msg end
                prev = true 
              end
            end
          else 
            for k,v in pairs (value) do
              buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
              if not buflen then return nil, msg end
              prev = true
            end
          end
          if indent then
            buflen = addnewline2 (level - 1, buffer, buflen)
          end
          buflen = buflen + 1
          buffer[buflen] = "}"
        end
        tables[value] = nil
      else
        return exception ('unsupported type', value, state, buffer, buflen,
          "type '" .. valtype .. "' is not supported by JSON.")
      end
      return buflen
    end
    
    function json.encode(value, state)
      state = state or {}
      local oldbuffer = state.buffer
      local buffer = oldbuffer or {}
      state.buffer = buffer
      updatedecpoint()
      local ret, msg = encode2 (value, state.indent, state.level or 0,
                       buffer, state.bufferlen or 0, state.tables or {}, state.keyorder, state)
      if not ret then
        error (msg, 2)
      elseif oldbuffer == buffer then
        state.bufferlen = ret
        return true
      else
        state.bufferlen = nil
        state.buffer = nil
        return concat (buffer)
      end
    end
    
    local function loc (str, where)
      local line, pos, linepos = 1, 1, 0
      while true do
        pos = strfind (str, "\n", pos, true)
        if pos and pos < where then
          line = line + 1
          linepos = pos
          pos = pos + 1
        else
          break
        end
      end
      return "line " .. line .. ", column " .. (where - linepos)
    end
    
    local function unterminated (str, what, where)
      return nil, strlen (str) + 1, "unterminated " .. what .. " at " .. loc (str, where)
    end
    
    local function scanwhite (str, pos)
      while true do
        pos = strfind (str, "%S", pos)
        if not pos then return nil end
        local sub2 = strsub (str, pos, pos + 1)
        if sub2 == "\239\187" and strsub (str, pos + 2, pos + 2) == "\191" then
          pos = pos + 3
        elseif sub2 == "//" then
          pos = strfind (str, "[\n\r]", pos + 2)
          if not pos then return nil end
        elseif sub2 == "/*" then
          pos = strfind (str, "*/", pos + 2)
          if not pos then return nil end
          pos = pos + 2
        else
          return pos
        end
      end
    end
    
    local escapechars = {
      ["\""] = "\"", ["\\"] = "\\", ["/"] = "/", ["b"] = "\b", ["f"] = "\f",
      ["n"] = "\n", ["r"] = "\r", ["t"] = "\t"
    }
    
    local function unichar (value)
      if value < 0 then
        return nil
      elseif value <= 0x007f then
        return strchar (value)
      elseif value <= 0x07ff then
        return strchar (0xc0 + floor(value/0x40),
                        0x80 + (floor(value) % 0x40))
      elseif value <= 0xffff then
        return strchar (0xe0 + floor(value/0x1000),
                        0x80 + (floor(value/0x40) % 0x40),
                        0x80 + (floor(value) % 0x40))
      elseif value <= 0x10ffff then
        return strchar (0xf0 + floor(value/0x40000),
                        0x80 + (floor(value/0x1000) % 0x40),
                        0x80 + (floor(value/0x40) % 0x40),
                        0x80 + (floor(value) % 0x40))
      else
        return nil
      end
    end
    
    local function scanstring (str, pos)
      local lastpos = pos + 1
      local buffer, n = {}, 0
      while true do
        local nextpos = strfind (str, "[\"\\]", lastpos)
        if not nextpos then
          return unterminated (str, "string", pos)
        end
        if nextpos > lastpos then
          n = n + 1
          buffer[n] = strsub (str, lastpos, nextpos - 1)
        end
        if strsub (str, nextpos, nextpos) == "\"" then
          lastpos = nextpos + 1
          break
        else
          local escchar = strsub (str, nextpos + 1, nextpos + 1)
          local value
          if escchar == "u" then
            value = tonumber (strsub (str, nextpos + 2, nextpos + 5), 16)
            if value then
              local value2
              if 0xD800 <= value and value <= 0xDBff then
                if strsub (str, nextpos + 6, nextpos + 7) == "\\u" then
                  value2 = tonumber (strsub (str, nextpos + 8, nextpos + 11), 16)
                  if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
                    value = (value - 0xD800)  * 0x400 + (value2 - 0xDC00) + 0x10000
                  else
                    value2 = nil
                  end
                end
              end
              value = value and unichar (value)
              if value then
                if value2 then
                  lastpos = nextpos + 12
                else
                  lastpos = nextpos + 6
                end
              end
            end
          end
          if not value then
            value = escapechars[escchar] or escchar
            lastpos = nextpos + 2
          end
          n = n + 1
          buffer[n] = value
        end
      end
      if n == 1 then
        return buffer[1], lastpos
      elseif n > 1 then
        return concat (buffer), lastpos
      else
        return "", lastpos
      end
    end
    
    local scanvalue
    
    local function scantable (what, closechar, str, startpos, nullval, objectmeta, arraymeta)
      local len = strlen (str)
      local tbl, n = {}, 0
      local pos = startpos + 1
      if what == 'object' then
        setmetatable (tbl, objectmeta)
      else
        setmetatable (tbl, arraymeta)
      end
      while true do
        pos = scanwhite (str, pos)
        if not pos then return unterminated (str, what, startpos) end
        local char = strsub (str, pos, pos)
        if char == closechar then
          return tbl, pos + 1
        end
        local val1, err
        val1, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
        if err then return nil, pos, err end
        pos = scanwhite (str, pos)
        if not pos then return unterminated (str, what, startpos) end
        char = strsub (str, pos, pos)
        if char == ":" then
          if val1 == nil then
            return nil, pos, "cannot use nil as table index (at " .. loc (str, pos) .. ")"
          end
          pos = scanwhite (str, pos + 1)
          if not pos then return unterminated (str, what, startpos) end
          local val2
          val2, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
          if err then return nil, pos, err end
          tbl[val1] = val2
          pos = scanwhite (str, pos)
          if not pos then return unterminated (str, what, startpos) end
          char = strsub (str, pos, pos)
        else
          n = n + 1
          tbl[n] = val1
        end
        if char == "," then
          pos = pos + 1
        end
      end
    end
    
    scanvalue = function(str, pos, nullval, objectmeta, arraymeta)
      pos = pos or 1
      pos = scanwhite (str, pos)
      if not pos then
        return nil, strlen (str) + 1, "no valid JSON value (reached the end)"
      end
      local char = strsub (str, pos, pos)
      if char == "{" then
        return scantable ('object', "}", str, pos, nullval, objectmeta, arraymeta)
      elseif char == "[" then
        return scantable ('array', "]", str, pos, nullval, objectmeta, arraymeta)
      elseif char == "\"" then
        return scanstring (str, pos)
      else
        local pstart, pend = strfind (str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
        if pstart then
          local number = str2num (strsub (str, pstart, pend))
          if number then
            return number, pend + 1
          end
        end
        pstart, pend = strfind (str, "^%a%w*", pos)
        if pstart then
          local name = strsub (str, pstart, pend)
          if name == "true" then
            return true, pend + 1
          elseif name == "false" then
            return false, pend + 1
          elseif name == "null" then
            return nullval, pend + 1
          end
        end
        return nil, pos, "no valid JSON value at " .. loc (str, pos)
      end
    end
    
    local function optionalmetatables(...)
      if select("#", ...) > 0 then
        return ...
      else
        return {__jsontype = 'object'}, {__jsontype = 'array'}
      end
    end
    
    function json.decode (str, pos, nullval, ...)
      local objectmeta, arraymeta = optionalmetatables(...)
      return scanvalue (str, pos, nullval, objectmeta, arraymeta)
    end
    
    function json.use_lpeg ()
      local g = require ("lpeg")
    
      if g.version() == "0.11" then
        error "due to a bug in LPeg 0.11, it cannot be used for JSON matching"
      end
    
      local pegmatch = g.match
      local P, S, R = g.P, g.S, g.R
    
      local function ErrorCall (str, pos, msg, state)
        if not state.msg then
          state.msg = msg .. " at " .. loc (str, pos)
          state.pos = pos
        end
        return false
      end
    
      local function Err (msg)
        return g.Cmt (g.Cc (msg) * g.Carg (2), ErrorCall)
      end
    
      local SingleLineComment = P"//" * (1 - S"\n\r")^0
      local MultiLineComment = P"/*" * (1 - P"*/")^0 * P"*/"
      local Space = (S" \n\r\t" + P"\239\187\191" + SingleLineComment + MultiLineComment)^0
    
      local PlainChar = 1 - S"\"\\\n\r"
      local EscapeSequence = (P"\\" * g.C (S"\"\\/bfnrt" + Err "unsupported escape sequence")) / escapechars
      local HexDigit = R("09", "af", "AF")
      local function UTF16Surrogate (match, pos, high, low)
        high, low = tonumber (high, 16), tonumber (low, 16)
        if 0xD800 <= high and high <= 0xDBff and 0xDC00 <= low and low <= 0xDFFF then
          return true, unichar ((high - 0xD800)  * 0x400 + (low - 0xDC00) + 0x10000)
        else
          return false
        end
      end
      local function UTF16BMP (hex)
        return unichar (tonumber (hex, 16))
      end
      local U16Sequence = (P"\\u" * g.C (HexDigit * HexDigit * HexDigit * HexDigit))
      local UnicodeEscape = g.Cmt (U16Sequence * U16Sequence, UTF16Surrogate) + U16Sequence/UTF16BMP
      local Char = UnicodeEscape + EscapeSequence + PlainChar
      local String = P"\"" * g.Cs (Char ^ 0) * (P"\"" + Err "unterminated string")
      local Integer = P"-"^(-1) * (P"0" + (R"19" * R"09"^0))
      local Fractal = P"." * R"09"^0
      local Exponent = (S"eE") * (S"+-")^(-1) * R"09"^1
      local Number = (Integer * Fractal^(-1) * Exponent^(-1))/str2num
      local Constant = P"true" * g.Cc (true) + P"false" * g.Cc (false) + P"null" * g.Carg (1)
      local SimpleValue = Number + String + Constant
      local ArrayContent, ObjectContent
    
      local function parsearray (str, pos, nullval, state)
        local obj, cont
        local npos
        local t, nt = {}, 0
        repeat
          obj, cont, npos = pegmatch (ArrayContent, str, pos, nullval, state)
          if not npos then break end
          pos = npos
          nt = nt + 1
          t[nt] = obj
        until cont == 'last'
        return pos, setmetatable (t, state.arraymeta)
      end
    
      local function parseobject (str, pos, nullval, state)
        local obj, key, cont
        local npos
        local t = {}
        repeat
          key, obj, cont, npos = pegmatch (ObjectContent, str, pos, nullval, state)
          if not npos then break end
          pos = npos
          t[key] = obj
        until cont == 'last'
        return pos, setmetatable (t, state.objectmeta)
      end
    
      local Array = P"[" * g.Cmt (g.Carg(1) * g.Carg(2), parsearray) * Space * (P"]" + Err "']' expected")
      local Object = P"{" * g.Cmt (g.Carg(1) * g.Carg(2), parseobject) * Space * (P"}" + Err "'}' expected")
      local Value = Space * (Array + Object + SimpleValue)
      local ExpectedValue = Value + Space * Err "value expected"
      ArrayContent = Value * Space * (P"," * g.Cc'cont' + g.Cc'last') * g.Cp()
      local Pair = g.Cg (Space * String * Space * (P":" + Err "colon expected") * ExpectedValue)
      ObjectContent = Pair * Space * (P"," * g.Cc'cont' + g.Cc'last') * g.Cp()
      local DecodeValue = ExpectedValue * g.Cp ()
    
      function json.decode (str, pos, nullval, ...)
        local state = {}
        state.objectmeta, state.arraymeta = optionalmetatables(...)
        local obj, retpos = pegmatch (DecodeValue, str, pos, nullval, state)
        if state.msg then
          return nil, state.pos, state.msg
        else
          return obj, retpos
        end
      end
    
      json.use_lpeg = function() return json end
    
      json.using_lpeg = true
    
      return json
    end
    
    if always_try_using_lpeg then
      pcall (json.use_lpeg)
    end
    
    return json
end
]===]

local function make_embedded_json_api()
  local bootstrap_env = {
    _G = {},
    pairs = pairs,
    type = type,
    tostring = tostring,
    tonumber = tonumber,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
    rawset = rawset,
    error = error,
    require = function()
      error("require disabled for embedded json lib")
    end,
    pcall = pcall,
    select = select,
    math = math,
    string = string,
    table = table,
  }

  bootstrap_env._G = bootstrap_env

  local loader, err = LOAD_FN(
    EMBEDDED_JSON_LIB,
    "@embedded_json.lib.lua",
    "t",
    bootstrap_env
  )

  if not loader then
    return nil, err
  end

  local ok, exec_err = pcall(loader)
  if not ok then
    return nil, exec_err
  end

  if type(bootstrap_env.load_json_lib) ~= "function" then
    return nil, "embedded json lib did not define load_json_lib"
  end

  local ok2, json_api = pcall(bootstrap_env.load_json_lib)
  if not ok2 then
    return nil, json_api
  end

  if type(json_api) ~= "table" then
    return nil, "embedded json lib did not return json table"
  end

  if type(json_api.encode) ~= "function" then
    return nil, "json.encode missing"
  end

  if type(json_api.decode) ~= "function" then
    return nil, "json.decode missing"
  end

  return {
    encode = json_api.encode,
    decode = json_api.decode,
    null = json_api.null,
    version = json_api.version,
  }
end



local CACHED_EMBEDDED_JSON_API = nil
local function get_embedded_json_api()
  if CACHED_EMBEDDED_JSON_API ~= nil then
    return CACHED_EMBEDDED_JSON_API
  end

  local api, err = make_embedded_json_api()
  if not api then
    return nil, err
  end

  CACHED_EMBEDDED_JSON_API = api
  return api
end



local DOC_API_GLOBALS = {
  CBaseModelInfo = true,
  CDoorCreationDataNode = true,
  CDynamicEntityGameStateDataNode = true,
  CEntity = true,
  CEntityScriptGameStateDataNode = true,
  CHeliControlDataNode = true,
  CNetGamePlayer = true,
  CNetObject = true,
  CObject = true,
  CObjectCreationDataNode = true,
  CObjectGameStateDataNode = true,
  CObjectSectorPosNode = true,
  CPed = true,
  CPedAppearanceDataNode = true,
  CPedAttachDataNode = true,
  CPedCreationDataNode = true,
  CPedGameStateDataNode = true,
  CPedInventoryDataNode = true,
  CPedMovementDataNode = true,
  CPedOrientationDataNode = true,
  CPedScriptCreationDataNode = true,
  CPedScriptGameStateDataNode = true,
  CPedSectorPosMapNode = true,
  CPedTaskSequenceDataNode = true,
  CPedTaskSpecificDataNode = true,
  CPedTaskTreeDataNode = true,
  CPhysical = true,
  CPhysicalAttachDataNode = true,
  CPhysicalGameStateDataNode = true,
  CPhysicalMigrationDataNode = true,
  CPickupCreationDataNode = true,
  CPickupPlacementCreationDataNode = true,
  CPickupSectorPosNode = true,
  CPlaneGameStateDataNode = true,
  CPlayerAmbientModelStreamingNode = true,
  CPlayerAppearanceDataNode = true,
  CPlayerCameraDataNode = true,
  CPlayerCreationDataNode = true,
  CPlayerGameStateDataNode = true,
  CPlayerInfo = true,
  CPlayerSectorPosNode = true,
  CProjectBaseSyncDataNode = true,
  CSectorDataNode = true,
  CSectorPositionDataNode = true,
  CSubmarineControlDataNode = true,
  CSubmarineGameStateDataNode = true,
  CSyncedPedVarData = true,
  CTaskData = true,
  CTrainGameStateDataNode = true,
  CVehicle = true,
  CVehicleAppearanceDataNode = true,
  CVehicleControlDataNode = true,
  CVehicleCreationDataNode = true,
  CVehicleGadgetDataNode = true,
  CVehicleGameStateDataNode = true,
  CVehicleHealthDataNode = true,
  CVehicleModelInfo = true,
  CVehicleProximityMigrationDataNode = true,
  CVehicleScriptGameStateDataNode = true,
  CVehicleTaskDataNode = true,
  Cherax = true,
  ClickGUI = true,
  ClickTab = true,
  Curl = true,
  D3D11SRV = true,
  D3D11Texture = true,
  DatBitBuffer = true,
  EventMgr = true,
  Feature = true,
  FeatureMgr = true,
  FileMgr = true,
  GTA = true,
  GUI = true,
  GadgetData = true,
  GamerHandle = true,
  GamerHandleBuffer = true,
  GamerInfo = true,
  HotKeyMgr = true,
  ImGui = true,
  ImGuiCol = true,
  ImGuiColorEditFlags = true,
  ImGuiComboFlags = true,
  ImGuiCond = true,
  ImGuiDir = true,
  ImGuiFocusedFlags = true,
  ImGuiHoveredFlags = true,
  ImGuiInputTextFlags = true,
  ImGuiKey = true,
  ImGuiMouseButton = true,
  ImGuiMouseCursor = true,
  ImGuiPopupFlags = true,
  ImGuiSelectableFlags = true,
  ImGuiStyleVar = true,
  ImGuiTabBarFlags = true,
  ImGuiTabItemFlags = true,
  ImGuiTableColumnFlags = true,
  ImGuiTableFlags = true,
  ImGuiTreeNodeFlags = true,
  ImGuiWindowFlags = true,
  ListGUI = true,
  ListWidget = true,
  Logger = true,
  Memory = true,
  ModderDB = true,
  Natives = true,
  NetAddress = true,
  NetAddressType = true,
  NetworkObjectMgr = true,
  PlayerGameStateFlags = true,
  Players = true,
  PoolMgr = true,
  Script = true,
  ScriptGlobal = true,
  ScriptLocal = true,
  SetShouldUnload = true,
  ShouldUnload = true,
  SocketAddress = true,
  Stats = true,
  Tab = true,
  TaskSlotData = true,
  Texture = true,
  Time = true,
  Utils = true,
  V2 = true,
  V3 = true,
  V4 = true,
  eCallbackTrigger = true,
  eCurlCode = true,
  eCurlOption = true,
  eEntityType = true,
  eFeatureType = true,
  eGuiMode = true,
  eLogColor = true,
  eLuaEvent = true,
  ePlayerListSort = true,
  eProtectionType = true,
  eReportReason = true,
  eSyncDataNode = true,
  eToastPos = true,
  fwAttachmentEntityExtension = true,
}

local function make_env(attest_hex, sid, sessExp, chal_resp_fn, chal_wipe_fn)
  local BLOCKED = {
    debug = true,
    package = true,
    require = true,
    loadfile = true,
    rawset = true,
    rawget = true,
    rawequal = true,
    print = true,
    error = true,
    _G = true,
    _ENV = true,
    getmetatable = true,
    setmetatable = true,
  }

  local SAFE_LUA_GLOBALS = {
    assert = true,
    pcall = true,
    xpcall = true,
    ipairs = true,
    pairs = true,
    next = true,
    tonumber = true,
    tostring = true,
    type = true,
    select = true,
  }

  
  
  local ALLOWED_GLOBALS = {}
  for name in pairs(SAFE_LUA_GLOBALS) do
    if not BLOCKED[name] then
      ALLOWED_GLOBALS[name] = true
    end
  end
  for name in pairs(DOC_API_GLOBALS) do
    if not BLOCKED[name] then
      ALLOWED_GLOBALS[name] = true
    end
  end

  local function is_write_mode(mode)
    mode = _tostring(mode or "rb")

    return mode:find("w", 1, true)
        or mode:find("a", 1, true)
        or mode:find("+", 1, true)
  end

  local function is_binary_asset_write(p, mode)
    mode = _tostring(mode or "")
    local ext = string.lower(p:match("%.([^%.]+)$") or "")

    return mode == "wb"
       and (ext == "png" or ext == "wav")
       and _is_path_allowed(p)
  end

  local function _is_discord_ipc_pipe(p)
    p = _tostring(p or ""):gsub("/", "\\")

    return p:match("^\\\\%.\\pipe\\discord%-ipc%-%d+$") ~= nil
  end

  local safe_os = {
    exit = function(code, close)
      return (os and os.exit) and os.exit(code, close) or nil
    end,
    time = os and os.time or nil,
    clock = os and os.clock or nil,
    date = os and os.date or nil,
    difftime = os and os.difftime or nil,

    execute = nil,
    remove = nil,
    rename = nil,
    setlocale = nil,
    getenv = nil,
  }

  local safe_io = {
    open = function(p, mode)
      if not (io and io.open) then
        return nil, "io.open unavailable"
      end
    
      p = _tostring(p or "")
      mode = _tostring(mode or "rb")
    
      
      if _is_discord_ipc_pipe(p) then
        if mode ~= "r+b" and mode ~= "rb+" then
          return nil, "discord ipc pipe mode blocked"
        end
      
        return io.open(p, mode)
      end
    
      if not _is_path_allowed(p) then
        return nil, "io.open blocked by sandbox"
      end
    
      if is_write_mode(mode) and not is_binary_asset_write(p, mode) then
        return nil, "io.open write mode blocked by sandbox"
      end
    
      return io.open(p, mode)
    end,
  
    popen = nil,
    tmpfile = nil,
  }

  local env = {}
  local DECLARED_GLOBALS = {}
  local cap_key = "__KCAP_" .. _tostring(math.random(1, 2^31 - 1))
  local cap_val = "KSC:"
    .. _tostring((os and os.time and os.time() or 0))
    .. ":"
    .. _tostring(math.random(1, 999999999))

  local cap_obj = setmetatable({ v = cap_val }, { __metatable = "locked" })
  local function cap_fn()
    return cap_obj.v
  end

  local json_api, json_err = get_embedded_json_api()
  if not json_api then
    return nil, json_err
  end

  env.json = json_api

  env.collectgarbage = function(cmd, arg)
      cmd = cmd or "collect"
    
      if cmd == "count" then
          return collectgarbage("count")
      end
    
      if cmd == "collect" then
          return collectgarbage("collect")
      end
    
      return nil, "collectgarbage command blocked by sandbox"
  end

  env[cap_key] = cap_obj
  env.__KCAP_KEY = cap_key
  env.__KCAP_FN = cap_fn

  env.__K_API_BASE = _tostring(API_BASE or "")
  env.__K_SID = _tostring(sid or "")
  env.__K_SESS_EXP = _tostring(sessExp or "")

  env.__K_CHAL_RESP = chal_resp_fn
  env.__K_CHAL_WIPE = chal_wipe_fn

  env.load = function(chunk, chunkname, mode, supplied_env)
    if not LOAD_FN then return nil, "load unavailable" end
    return LOAD_FN(chunk, chunkname or "=@dyn", mode or "bt", env)
  end

  env.dofile = function(p)
    p = _tostring(p or "")

    if not _is_path_allowed(p) then
      return nil, "just stop ur wasting ur time"
    end

    local f, ferr = (io and io.open) and io.open(p, "rb") or nil, "nigga is a retard fr"
    if not f then return nil, ferr or "open failed" end

    local src = f:read("*a")
    f:close()

    local fn, err = LOAD_FN(src, "@dofile:" .. p, "t", env)
    if not fn then return nil, err end

    return fn()
  end

  env.assert = assert
  env.pcall = pcall
  env.xpcall = xpcall
  env.ipairs = ipairs
  env.pairs = pairs
  env.next = next
  env.select = select
  env.tonumber = tonumber
  env.tostring = _tostring
  env.type = _type

  env.math = math
  env.string = string
  env.table = table
  env.coroutine = coroutine
  env.os = safe_os
  env.io = safe_io

  env.Script = Script

  env._G = nil
  env._ENV = nil

  
  
  
  for name in pairs(SAFE_LUA_GLOBALS) do
    if not BLOCKED[name] and env[name] == nil then
      env[name] = _G[name]
    end
  end

  for name in pairs(DOC_API_GLOBALS) do
    if not BLOCKED[name] and env[name] == nil then
      env[name] = _G[name]
    end
  end

  return setmetatable(env, {
    __index = function(t, k)
        if BLOCKED[k] then return nil end
        
        
        
        if DECLARED_GLOBALS[k] then
            return nil
        end
      
        if ALLOWED_GLOBALS[k] then
            local v = _G[k]
            rawset(t, k, v) 
            return v
        end
      
        return nil
    end,
    
    __newindex = function(t, k, v)
        if BLOCKED[k] then return nil end

        
        DECLARED_GLOBALS[k] = true
        rawset(t, k, v)
    end,

    __metatable = "locked",
  })
end

local function _integrity_check()
  if _type(LOAD_FN) ~= "function" then return false, "load() missing" end
  if _type(pcall) ~= "function" then return false, "pcall missing" end
  return true
end

local function parse_error_field(bodyStr)
  if type(bodyStr) ~= "string" or bodyStr == "" then return nil end
  local obj = json_decode(bodyStr)
  if type(obj) == "table" and type(obj.error) == "string" and obj.error ~= "" then
    return obj.error
  end
  return nil
end

local function utc_table_to_epoch(t)
  if not os or type(os.time) ~= "function" or type(os.date) ~= "function" or type(os.difftime) ~= "function" then
    return nil
  end

  local local_epoch = os.time(t)
  if not local_epoch then return nil end

  local utc_table = os.date("!*t", local_epoch)
  local utc_as_local_epoch = utc_table and os.time(utc_table) or nil
  if not utc_as_local_epoch then return local_epoch end

  return local_epoch + os.difftime(local_epoch, utc_as_local_epoch)
end

local function parse_ban_expiry_epoch(expiresAt)
  if expiresAt == nil or expiresAt == "" then return nil end

  if type(expiresAt) == "number" then
    if expiresAt <= 0 then return nil end
    return expiresAt > 10000000000 and math.floor(expiresAt / 1000) or math.floor(expiresAt)
  end

  local text = tostring(expiresAt):gsub("^%s+", ""):gsub("%s+$", "")
  local lowered = text:lower()
  if text == "" or lowered == "never" or lowered == "none" or lowered == "null" or lowered == "permanent" then return nil end

  if text:match("^%d+$") then
    local numeric = tonumber(text)
    if not numeric or numeric <= 0 then return nil end
    return numeric > 10000000000 and math.floor(numeric / 1000) or math.floor(numeric)
  end

  local y, mon, d, h, min, sec = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T%s](%d%d):(%d%d):(%d%d)")
  if not y then return nil end

  return utc_table_to_epoch({
    year = tonumber(y),
    month = tonumber(mon),
    day = tonumber(d),
    hour = tonumber(h),
    min = tonumber(min),
    sec = tonumber(sec)
  })
end

local function format_ban_duration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  if seconds <= 0 then return "expired" end

  local days = math.floor(seconds / 86400)
  seconds = seconds % 86400
  local hours = math.floor(seconds / 3600)
  seconds = seconds % 3600
  local minutes = math.floor(seconds / 60)
  seconds = seconds % 60

  if days > 0 then
    return ("%dd %dh %dm"):format(days, hours, minutes)
  elseif hours > 0 then
    return ("%dh %dm"):format(hours, minutes)
  elseif minutes > 0 then
    return ("%dm %ds"):format(minutes, seconds)
  end

  return ("%ds"):format(seconds)
end

local function format_ban_message(response)
  local ban = type(response) == "table" and type(response.ban) == "table" and response.ban or {}
  local reason = ban.reason or (type(response) == "table" and response.reason or nil)
  local expiresAt = ban.expiresAt or (type(response) == "table" and response.expiresAt or nil)
  local expiry = parse_ban_expiry_epoch(expiresAt)
  local remaining = expiry and format_ban_duration(expiry - ((os and os.time and os.time()) or 0)) or "permanent"
  local message = "Access denied: you are banned. Remaining ban time: " .. remaining .. "."

  if type(reason) == "string" and reason ~= "" then
    message = message .. " Reason: " .. reason .. "."
  end

  return message .. " If you believe this is a mistake, contact support at discord.gg/k-script"
end

local function looks_like_cloudflare_block(bodyStr)
  if type(bodyStr) ~= "string" then return false end
  return bodyStr:find("Attention Required! | Cloudflare", 1, true) ~= nil
      or bodyStr:find("Cloudflare Ray ID", 1, true) ~= nil
      or bodyStr:find("Sorry, you have been blocked", 1, true) ~= nil
end

local function run_bytecode_in_env(bytecode, env, chunkname)
  local okInt, why = _integrity_check()
  if not okInt then return false, why end

  local fn, err = LOAD_FN(bytecode, chunkname or "=@payload", "b", env)
  if not fn then return false, err end

  local ok, ret = pcall(fn)
  if not ok then return false, ret end
  return true, ret
end

local function decrypt_payload_response_body(body, payloadKey, sexp_local)
  local payload = decode_payload_response(body)
  loader_yield_if_due()
  if not payload then
    return false, nil, "payload_decode"
  end

  if payload.skip then
    return true, nil, "skip"
  end

  if payload.error then
    return false, nil, "payload_error"
  end

  if not payload.ct or not payload.nonce or not payload.mac or not payload.exp or not payload.v or not payload.ctr then
    return false, nil, "payload_missing"
  end

  local payload_exp_num = tonumber(payload.exp)
  local payload_exp = payload_exp_num and tostring(math.floor(payload_exp_num)) or nil
  local payload_ctr_num = tonumber(payload.ctr)
  local payload_ctr = payload_ctr_num and tostring(math.floor(payload_ctr_num)) or nil
  local payload_v_num = tonumber(payload.v)
  local payload_v = payload_v_num and tostring(math.floor(payload_v_num)) or nil
  local payload_nonce_hex = sanitize_hex_len(payload.nonce, 24)
  local payload_mac_hex = sanitize_hex_len(payload.mac, 64)
  local payload_ct_hex = sanitize_hex_len(payload.ct, #tostring(payload.ct or ""))

  if not payload_exp
     or not payload_ctr
     or not payload_v
     or payload_exp ~= sexp_local
     or payload_v ~= "2"
     or payload_ctr_num == nil
     or payload_ctr_num < 0
     or payload_ctr_num > 4294967295
     or payload_ctr_num ~= math.floor(payload_ctr_num)
     or payload_ctr ~= tostring(math.floor(payload_ctr_num))
     or not payload_nonce_hex
     or not payload_mac_hex
     or not payload_ct_hex
     or (#payload_ct_hex % 2) ~= 0 then
    return false, nil, "payload_validate"
  end

  local nonceB = hex_to_bytes(payload_nonce_hex)
  local ctB = hex_to_bytes(payload_ct_hex)
  local macB = hex_to_bytes(payload_mac_hex)
  if not nonceB or not ctB or not macB then
    return false, nil, "payload_hex"
  end

  local mac_data =
    payload_v .. "|" ..
    payload_exp .. "|" ..
    payload_ctr .. "|" ..
    nonceB .. ctB

  local mac2 = hmac_sha256(payloadKey, mac_data)
  loader_yield_if_due()
  if not ct_equal(macB, mac2) then
    return false, nil, "payload_mac"
  end

  local ctr = math.tointeger(payload_ctr_num)
  if not ctr then
    return false, nil, "payload_ctr"
  end

  local pt = chacha20_xor(payloadKey, nonceB, ctr, ctB)
  return true, pt, "payload"
end

local function fetch_encrypted_payload(url, authHdr, payloadKey, sexp_local)
  local payloadResp, pErr = http_request("GET", url, nil, { ["Authorization"]=authHdr["Authorization"] })
  if not payloadResp then
    return false, nil, "request"
  end

  local payNorm, okPay = normalize_http_response(payloadResp, "payload")
  if not okPay then
    return false, nil, "normalize"
  end
  if looks_like_cloudflare_block(payNorm) then
    return false, nil, "cloudflare"
  end

  return decrypt_payload_response_body(payNorm, payloadKey, sexp_local)
end




local function extract_token(obj)
  local function looks_like_token(x)
    return type(x) == "string" and x:match("^[0-9a-fA-F]+$") and #x >= 32
  end

  local function scan(t, depth)
    if depth <= 0 then return nil end
    if type(t) ~= "table" then return nil end

    
    local direct = t.t or t.token or t.loaderToken or t.scriptToken or t.access_token or t.accessToken
    if looks_like_token(direct) then return direct end

    
    for _, v in pairs(t) do
      if looks_like_token(v) then
        return v
      end
      if type(v) == "table" then
        local r = scan(v, depth - 1)
        if r then return r end
      end
    end
    return nil
  end

  return scan(obj, 4)
end





local __k_runtime = {
  unloaded = false,
}

local function wipe_table(t)
  if type(t) ~= "table" then return end
  for k in pairs(t) do
    t[k] = nil
  end
end

local function onUnload()
  if __k_runtime.unloaded then return end
  __k_runtime.unloaded = true

  if type(loader_ui_stop) == "function" then
    pcall(loader_ui_stop, true)
  end

  pcall(function()
    if type(__K_CHAL_WIPE) == "function" then
      __K_CHAL_WIPE()
    end
  end)

  __K_CHAL_RESP = nil
  __K_CHAL_WIPE = nil
  __K_API_BASE = nil
  __K_SID = nil
  __K_SESS_EXP = nil

  collectgarbage("collect")
  collectgarbage("collect")
end

EventMgr.RegisterHandler(eLuaEvent.ON_UNLOAD, onUnload)




local function LoadProtectedPayload()
  if ShouldUnload() then return end

  loader_ui_set_stage("loader-start", nil, "Preparing secure handshake")
  GUI.AddToast("K-Script", "Loading...", 8000, eToastPos.BOTTOM_RIGHT)
  if Script and type(Script.Yield) == "function" and LOADER_UI_WARMUP_MS > 0 then
    Script.Yield(LOADER_UI_WARMUP_MS)
  end
  if ShouldUnload() then return end

  loader_ui_set_stage("anti-hook", nil, "Checking runtime integrity")
  if not run_anti_hook_checks() then
    SetShouldUnload()
    return
  end
  loader_ui_set_stage("anti-hook-ok", nil, "Runtime checks passed")

  local runtime_hash = get_runtime_hash()

  
  loader_ui_set_stage("identity", nil, "Reading client identity")
  local raw_uid = (Cherax and Cherax.GetUID and Cherax.GetUID()) or ""
  local uid = tostring(raw_uid)
  if uid == "" then
    FAIL("E1(ID)")
    SetShouldUnload()
    return
  end

  
  if not uid:match("^%d+$") then
    FAIL("E1(bro this is malicious)")
    SetShouldUnload()
    return
  end
  if tonumber(uid) == nil or tonumber(uid) <= 0 then
    FAIL("E1(bro ur emberassing urself)")
    SetShouldUnload()
    return
  end
  loader_ui_set_stage("identity", nil, "UID " .. uid)

  if type(raw_uid) == "number" and tostring(math.floor(raw_uid)) ~= uid then
    FAIL("E1(URARETARD)")
    os.exit(1337)
    return
  end

  local ts = tostring(((os and os.time and os.time()) or 0) * 1000)
  local nonce = rand_hex(16)

  loader_ui_set_stage("hello-request", nil, "Contacting loader hello")
  local helloResp, hErr = http_request("GET", API_BASE .. "/loader/hello", nil, { ["Content-Type"]="application/json" })
  if not helloResp then
    if hErr and Logger and Logger.Log then
      pcall(Logger.Log, eLogColor and eLogColor.RED or 0, "K-Script Auth", "E2(HR): " .. tostring(hErr))
    end
    FAIL("E2(HR)")
    SetShouldUnload()
    return
  end

  local helloNorm, okHello = normalize_http_response(helloResp, "hello")
  if not okHello then
    FAIL("E2(HN)")
    SetShouldUnload()
    return
  end
  if looks_like_cloudflare_block(helloNorm) then
    FAIL("E2(CF)")
    SetShouldUnload()
    return
  end

  local hello = json_decode(helloNorm)
  loader_yield_if_due()
  if not hello or hello.error or hello.e or (not hello.hid and not hello.h) or (not hello.nonce and not hello.n) then
    FAIL("E2(HB)")
    SetShouldUnload()
    return
  end

  local hid = sanitize_hex_len(hello.hid or hello.h, 32)
  local hello_nonce = sanitize_hex_len(hello.nonce or hello.n, 32)
  local hello_build = tostring(hello.build or hello.b or LOADER_BUILD)
  if not hid or not hello_nonce or #hello_build == 0 then
    FAIL("E2(HF)")
    SetShouldUnload()
    return
  end
  loader_ui_set_stage("hello-ok", nil, "Handshake seed accepted")

  local tokBody = json_encode({ uid = uid, ts = ts, nonce = nonce, hid = hid, build = hello_build })

  loader_ui_set_stage("token-request", nil, "Requesting loader token")
  local tokResp, tokErr = http_request("POST", API_BASE .. "/loader/token", tokBody, { ["Content-Type"]="application/json; charset=utf-8" })
  if not tokResp then
    FAIL("E3(TR)")
    SetShouldUnload()
    return
  end

  local tokNorm, okTok = normalize_http_response(tokResp, "token")
  if not okTok then
    FAIL("E4(TN)")
    SetShouldUnload()
    return
  end
  if looks_like_cloudflare_block(tokNorm) then
    FAIL("E4(CF)")
    SetShouldUnload()
    return
  end

  local tok = json_decode(tokNorm)
  loader_yield_if_due()

  local bearerToken = extract_token(tok)
  bearerToken = sanitize_hex_len(bearerToken, 64)
  if not bearerToken then
    local tokErrField = parse_error_field(tokNorm)
    if tokErrField then
      if tokErrField == "Banned" then
        _log(eLogColor.RED, "K-Script Auth", format_ban_message(tok))
        if Script and type(Script.Yield) == "function" then
          Script.Yield(2500)
        end
        os.exit(69)
      elseif tokErrField:lower() == "clock skew" then
        FAIL("E5(TD) Sync your Clock in Windows Settings and try again.\nIf the problem persists, contact support with the error code: E5")
        SetShouldUnload()
        return
      end
    end
    FAIL("E6(TB)")
    SetShouldUnload()
    return
  end
  loader_ui_set_stage("token-ok", nil, "Token accepted")

  local authHdr = { ["Authorization"] = "Bearer " .. bearerToken }
  local clientPrivate = make_x25519_private(uid, hid, hello_nonce, nonce, bearerToken)
  local clientPub = x25519(clientPrivate, X25519_BASE_POINT)
  local client_pub_hex = clientPub and bytes_to_hex(clientPub) or nil
  if not client_pub_hex or #client_pub_hex ~= 64 then
    FAIL("E6(KX)")
    SetShouldUnload()
    return
  end

  local raw_proof = derive_hello_bound_proof(uid, hid, hello_nonce, nonce, hello_build, bearerToken, client_pub_hex)
  local proof_hex = sanitize_hex64(raw_proof)
  
  if not proof_hex then
    FAIL("E6(PF)")
    SetShouldUnload()
    return
  end

  
  loader_ui_set_stage("session-request", nil, "Creating secure session")
  local sessionResp, sErr = http_request(
    "POST",
    API_BASE .. "/loader/session",
    json_encode({ proof = proof_hex, clientPub = client_pub_hex, p = proof_hex, cp = client_pub_hex, x = client_pub_hex }),
    {
      ["Authorization"] = authHdr["Authorization"],
      ["Content-Type"] = "application/json; charset=utf-8"
    }
  )
  if not sessionResp then
    FAIL("E7(SR)")
    SetShouldUnload()
    return
  end

  local sessNorm, okSess = normalize_http_response(sessionResp, "session")
  if not okSess then
    FAIL("E8(SN)")
    SetShouldUnload()
    return
  end
  if looks_like_cloudflare_block(sessNorm) then
    FAIL("E8(CF)")
    SetShouldUnload()
    return
  end
  local session = json_decode(sessNorm)
  loader_yield_if_due()
  if not session then
    FAIL("E9(SB)")
    SetShouldUnload()
    return
  end
  if session.error or session.e then
    FAIL("E9(SE)")
    SetShouldUnload()
    return
  end

  if (not session.sid and not session.s) or (not session.exp and not session.x) or (not session.salt and not session.a) or (not session.partA and not session.b) or (not session.serverPub and not session.p) then
    FAIL("E9(SB)")
    SetShouldUnload()
    return
  end

  local sid_local  = sanitize_hex_len(session.sid or session.s, 32)
  local salt_local = sanitize_hex_len(session.salt or session.a, 32)
  local partA_local = sanitize_hex_len(session.partA or session.b, 64)
  local server_pub_hex = sanitize_hex_len(session.serverPub or session.p, 64)
  local sexp_num = tonumber(session.exp or session.x)
  local sexp_local = sexp_num and tostring(math.floor(sexp_num)) or nil
  if not sid_local or not salt_local or not partA_local or not server_pub_hex or not sexp_local then
    FAIL("E9(SF)")
    SetShouldUnload()
    return
  end
  loader_ui_set_stage("session-ok", nil, "Session established")

  local serverPub = hex_to_bytes(server_pub_hex)
  local sharedSecret = serverPub and x25519(clientPrivate, serverPub) or nil
  if not sharedSecret or #sharedSecret ~= 32 or is_all_zero_bytes(sharedSecret) then
    FAIL("E9(KS)")
    SetShouldUnload()
    return
  end

  local sessKey = derive_session_key(sharedSecret, uid, sid_local, sexp_local, salt_local, partA_local, proof_hex, client_pub_hex, server_pub_hex)
  loader_yield_if_due()
  local payloadKey = derive_payload_key(sessKey)
  loader_yield_if_due()

  local attest = nil

  
  local keybox = { k = payloadKey }

  local function chal_resp_fn(challengeExp, challengeHex, challengeBuild)
    local k = keybox.k
    if type(k) ~= "string" or #k == 0 then
      SetShouldUnload()
      return FAIL("E11(CW)", 2)
    end

    local boundBuild = tostring(challengeBuild or "")
    if boundBuild == "" then boundBuild = hello_build end
    local msg = "chal|v2|" .. tostring(Cherax.GetUID()) .. "|" .. sid_local .. "|" .. sexp_local .. "|" .. challengeExp .. "|" .. challengeHex .. "|" .. boundBuild
    return bytes_to_hex(hmac_sha256(k, msg))
  end

  local function chal_wipe_fn()
    keybox.k = nil
    collectgarbage("collect")
    collectgarbage("collect")
    return true
  end

  local payloadEnv, envErr = make_env(attest, sid_local, sexp_local, chal_resp_fn, chal_wipe_fn)
  if not payloadEnv then
    FAIL("E17(ENV)")
    SetShouldUnload()
    return
  end

  loader_ui_set_stage("remote-payload-request", nil, "Downloading encrypted payload")
  local okPayload, pt, payloadState = fetch_encrypted_payload(
    API_BASE .. "/loader/payload?sid=" .. sid_local,
    authHdr,
    payloadKey,
    sexp_local
  )
  if not okPayload or not pt then
    FAIL("E14(" .. tostring(payloadState or "PF") .. ")")
    SetShouldUnload()
    return
  end

  loader_ui_set_stage("remote-payload-verified", nil, "Payload verified")
  loader_ui_set_stage("payload-decrypt", nil, "Decrypting protected payload")

  loader_ui_set_stage("launching-script", nil, "Starting K-Script")
  Script.Yield()
  local okExec = run_bytecode_in_env(pt, payloadEnv, "=@payload")
  if not okExec then
    FAIL("E17(SE)")
    SetShouldUnload()
    return
  end

  
  pt=nil; payloadEnv=nil
  sessKey=nil; sharedSecret=nil; clientPrivate=nil; clientPub=nil; serverPub=nil
  client_pub_hex=nil; server_pub_hex=nil; session=nil; tok=nil; tokResp=nil
  loader_ui_set_stage("cleanup", nil, "Cleaning loader state")
  collectgarbage("collect")
  collectgarbage("collect")
  loader_ui_stop()
end

local ensureOnce = false
Script.QueueJob(function()
  if ShouldUnload() then return end
  
  if not ensureOnce then
    ensureOnce = true
    LoadProtectedPayload()
  end
end)

GUI.AddToast("K-Script", "Waiting for Game to be ready...", 8000, eToastPos.BOTTOM_RIGHT)
Logger.Log(eLogColor.GREEN, "K-Script Auth", "Waiting for game to be in a safe state to load...")
