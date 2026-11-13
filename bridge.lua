-- ==============================================================================
-- Aero Executor — Universal Bridge Connector Hook
-- ==============================================================================
-- This script serves as the live API bridge between the Roblox client and
-- AeroExecutor.exe. Host this on GitHub (raw.githubusercontent.com) or load
-- directly from local server:
--   loadstring(game:HttpGet("http://127.0.0.1:5588/bridge.lua"))()
-- ==============================================================================

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Stop any previous bridge instance
if getgenv().AERO_BRIDGE_ACTIVE then
    getgenv().AERO_BRIDGE_ACTIVE = false
    task.wait(0.2)
end

getgenv().AERO_BRIDGE_ACTIVE = true
getgenv().identifyexecutor = function()
    return "Aero Executor", "3.0.0"
end

local SERVER_URL = getgenv().AERO_BRIDGE_URL or "http://127.0.0.1:5588"

local function sendLog(message, logType)
    pcall(function()
        local payload = HttpService:JSONEncode({
            type = logType or "print",
            message = tostring(message)
        })
        if request then
            request({
                Url = SERVER_URL .. "/log",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        elseif syn and syn.request then
            syn.request({
                Url = SERVER_URL .. "/log",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        elseif http_request then
            http_request({
                Url = SERVER_URL .. "/log",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end
    end)
end

print("[Aero Bridge] Connecting to AeroExecutor at " .. SERVER_URL .. "...")
sendLog("Client connected to Aero Bridge!", "info")

-- Main Polling Loop (fetches queued payloads dispatched from Execute button)
task.spawn(function()
    while getgenv().AERO_BRIDGE_ACTIVE do
        local success, res = pcall(function()
            return game:HttpGet(SERVER_URL .. "/poll")
        end)

        if success and res and #res > 0 then
            local decodeOk, data = pcall(function()
                return HttpService:JSONDecode(res)
            end)

            if decodeOk and data and data.script and #data.script > 0 then
                task.spawn(function()
                    local fn, compileErr = loadstring(data.script)
                    if fn then
                        local runOk, runErr = pcall(fn)
                        if not runOk then
                            warn("[Aero Runtime Error] " .. tostring(runErr))
                            sendLog("[Runtime Error] " .. tostring(runErr), "warn")
                        end
                    else
                        warn("[Aero Compile Error] " .. tostring(compileErr))
                        sendLog("[Compile Error] " .. tostring(compileErr), "warn")
                    end
                end)
            end
        end

        task.wait(0.15)
    end

    print("[Aero Bridge] Disconnected.")
    sendLog("Client disconnected from Aero Bridge.", "info")
end)
