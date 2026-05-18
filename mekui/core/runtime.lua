--[[
  mekui/core/runtime.lua
  Central event loop with timer management and event dispatch.
  Wraps os.startTimer, os.pullEvent, parallel.waitForAny.
]]

local runtime = {}
local R = {}

function R:new()
  return setmetatable({
    _running   = false,
    _timers    = {},
    _handlers  = {},
    _next_id   = 0,
    _on_start  = nil,
    _on_stop   = nil,
    _poll_rate = 0,        -- default: no auto-timer
    _timer_ids = {},       -- maps handler id -> os timer id
  }, { __index = R })
end

-- ── Event Registration ───────────────────────────────────────────────

function R:on(event_name, handler)
  if not self._handlers[event_name] then
    self._handlers[event_name] = {}
  end
  table.insert(self._handlers[event_name], handler)
  return self
end

function R:off(event_name, handler)
  local list = self._handlers[event_name]
  if not list then return self end
  for i = #list, 1, -1 do
    if list[i] == handler then
      table.remove(list, i)
      break
    end
  end
  return self
end

-- ── Timer Management ─────────────────────────────────────────────────

function R:timer(delay, handler)
  local id = self._next_id
  self._next_id = self._next_id + 1

  self._timers[id] = handler

  if self._running then
    local timer_id = os.startTimer(delay)
    self._timer_ids[id] = timer_id
  end

  return id
end

function R:cancelTimer(id)
  local timer_id = self._timer_ids[id]
  if timer_id then
    os.cancelTimer(timer_id)
    self._timer_ids[id] = nil
  end
  self._timers[id] = nil
  return self
end

-- ── Poll Rate (auto-draw timer) ──────────────────────────────────────

function R:setPollRate(seconds)
  self._poll_rate = seconds
  return self
end

-- ── Event Dispatch ───────────────────────────────────────────────────

function R:_dispatch(event_name, ...)
  local list = self._handlers[event_name]
  if not list then return end
  local args = { ... }
  for _, handler in ipairs(list) do
    local ok, err = pcall(handler, table.unpack(args))
    if not ok then
      print("[mekui] Handler error on " .. tostring(event_name) .. ": " .. tostring(err))
    end
  end
end

-- ── Hooks ────────────────────────────────────────────────────────────

function R:onStart(handler)
  self._on_start = handler
  return self
end

function R:onStop(handler)
  self._on_stop = handler
  return self
end

-- ── Main Event Loop ──────────────────────────────────────────────────

function R:run()
  if self._running then return self end
  self._running = true

  -- start auto-poll timer if configured
  local poll_timer_id = nil
  if self._poll_rate > 0 then
    poll_timer_id = os.startTimer(self._poll_rate)
  end

  -- Fire on_start
  if self._on_start then
    pcall(self._on_start)
  end

  -- Make new timers that were registered before run() started
  for id, handler in pairs(self._timers) do
    if not self._timer_ids[id] then
      local delay = 0
      -- determine delay from handler metadata if available
      self._timer_ids[id] = os.startTimer(1)
    end
  end

  while self._running do
    local event_data = { os.pullEvent() }
    local event_name = event_data[1]
    table.remove(event_data, 1)

    if event_name == "timer" then
      local timer_id = event_data[1]

      -- Check auto-poll timer (handled first; skip other timer dispatch for poll)
      if poll_timer_id and timer_id == poll_timer_id then
        poll_timer_id = os.startTimer(self._poll_rate)
        self:_dispatch("timer")
      else
        -- Dispatch to registered timer handlers
        for id, stored_timer_id in pairs(self._timer_ids) do
          if stored_timer_id == timer_id then
            local handler = self._timers[id]
            if handler then
              local ok, err = pcall(handler, id)
              if not ok then
                print("[mekui] Timer handler error: " .. tostring(err))
              end
            end
            -- One-shot: clean up
            self._timer_ids[id] = nil
            self._timers[id] = nil
            break
          end
        end
      end
    elseif event_name == "terminate" then
      self:_dispatch("terminate")
      self:stop()
      break
    else
      -- Dispatch generic event
      self:_dispatch(event_name, table.unpack(event_data))
    end
  end

  -- Cleanup
  if self._on_stop then
    pcall(self._on_stop)
  end

  return self
end

-- ── Stop ─────────────────────────────────────────────────────────────

function R:stop()
  self._running = false
  return self
end

-- ── State Queries ────────────────────────────────────────────────────

function R:isRunning()
  return self._running
end

return R
