
-- Add default search paths for game.
-- [MEDIA HOTFIX v2] doc mod tu Android/media. Tu lay ten goi + user id tu getWritablePath (ho tro app nhan ban),
-- thu nhieu goc luu tru, nhan ca src/src. Ghi nhat ky vao Android/media/<goi>/media_hook.txt de kiem tra.
pcall(function()
    local fu = cc.FileUtils:getInstance()
    local log = {}
    local function L(s) log[#log + 1] = s; print("[MediaHook] " .. s) end
    local function dirOk(p)
        local ok = false
        pcall(function() ok = fu:isDirectoryExist(p) == true end)
        if not ok then pcall(function() ok = fu:isFileExist(p .. "/main.lua") == true end) end
        if not ok then local f = io.open(p .. "/main.lua", "r"); if f then f:close(); ok = true end end
        if not ok then local f2 = io.open(p .. "/client/launch.lua", "r"); if f2 then f2:close(); ok = true end end
        return ok
    end
    local pkg, uid, wp
    pcall(function()
        wp = fu:getWritablePath()
        uid, pkg = wp:match("^/data/user/(%d+)/([^/]+)/")
        if not pkg then
            pkg = wp:match("^/data/data/([^/]+)/")
            if pkg then uid = "0" end
        end
    end)
    if not pkg then
        pcall(function()
            local f = io.open("/proc/self/cmdline", "rb")
            if f then
                local s = f:read("*a"); f:close()
                pkg = s:match("^[%w_%.]+")
            end
        end)
    end
    L("pkg=" .. tostring(pkg) .. " uid=" .. tostring(uid) .. " writable=" .. tostring(wp))
    local roots = {}
    local function addRoot(r)
        for _, x in ipairs(roots) do if x == r then return end end
        roots[#roots + 1] = r
    end
    addRoot("/sdcard")
    addRoot("/storage/self/primary")
    addRoot("/storage/emulated/0")
    if uid then addRoot("/storage/emulated/" .. uid) end
    local cands = {}
    for _, r in ipairs(roots) do cands[#cands + 1] = r .. "/Android/media/src" end
    if pkg then
        for _, r in ipairs(roots) do cands[#cands + 1] = r .. "/Android/media/" .. pkg .. "/src" end
    end
    local added, n = {}, 0
    local function use(p)
        if added[p] then return end
        added[p] = true
        n = n + 1
        fu:addSearchPath(p, true)
        package.path = p .. "/?.lua;" .. p .. "/?/init.lua;" .. package.path
        L("DUNG: " .. p)
    end
    for _, c in ipairs(cands) do
        if dirOk(c) then
            use(c)
            if dirOk(c .. "/src") then use(c .. "/src") end
        else
            L("khong co: " .. c)
        end
    end
    L("tong so thu muc mod: " .. n)
    if pkg then
        local text = "[" .. "main.lua" .. "]\n" .. table.concat(log, "\n") .. "\n"
        for _, r in ipairs(roots) do
            local d = r .. "/Android/media/" .. pkg .. "/"
            pcall(function() fu:createDirectory(d) end)
            local f = io.open(d .. "media_hook.txt", "w")
            if f then f:write(text); f:close(); break end
        end
    end
end)
cc.FileUtils:getInstance():addSearchPath("src")
cc.FileUtils:getInstance():addSearchPath("res")

-- CC_USE_DEPRECATED_API = true
require "cocos.init"

-- cclog
local cclog = function(...)
    print(string.format(...))
end

-- `printError` no lo define NADIE en esta build, y las cuatro guardas
-- «node must be a userdata» del framework (cocostudio.lua:268 y :313,
-- gray.lua:22 y :170) lo llaman. Como el `__index` de abajo revienta con
-- los globales que no existen, la guarda que deberia AVISAR tumbaba la
-- pantalla: la del Deck, al grisar el retrato de una carta sin imagen.
function printError(...)
    print("[error] " .. table.concat({...}, " "))
    print(debug.traceback("", 2))
end

function __sleep(n)
    if cc.Application:getInstance():getTargetPlatform() ~= cc.PLATFORM_OS_WINDOWS then 
        os.execute("sleep " .. n)
    end
end

-- for CCLuaEngine traceback
function __G__TRACKBACK__(msg)
    local errorFunc = "LUA Func\r\n"
    local errorLine = "0\r\n"
    local errorName = "LUA ERROR\r\n"
    local errorMsg = "LUA ERROR: " .. tostring(msg) .. "\r\n"
    local traceback = debug.traceback()
    local tbString = errorFunc..errorLine..errorName..errorMsg .. traceback
    if NetworkManager~=nil and protocol_command~= nil and protocol_command.record_crash.param_list ~= tbString then
        protocol_command.record_crash.param_list = tbString
        local request = NetworkManager:register(protocol_command.record_crash.code, nil, nil, nil, nil, nil, false, nil)
        NetworkAdaptor.send(request)
        -- handlePlatformRequest(0, COLLECT_CRASH_REPORT_TESTIN, msg.."|"..traceback)
        __sleep(1)
    end
    cclog("----------------------------------------")
    cclog("LUA ERROR: " .. tostring(msg) .. "\n")
    cclog(debug.traceback())
    cclog("----------------------------------------")
    -- debug.error(true, "----------------------------------------\r\n".."LUA ERROR: " .. tostring(msg) .. "\r\n"..debug.traceback().."\r\n----------------------------------------")
    return msg
end

local function main()
    collectgarbage("collect")
    -- avoid memory leak
    collectgarbage("setpause", 100)
    collectgarbage("setstepmul", 5000)

    -- load frameworks moudle for create application.
    local _app = require("frameworks.app")
    _app.create()

    -- launch the game.
    app.load("client.launch")

    local m_targetPlatform = cc.Application:getInstance():getTargetPlatform()
    if m_targetPlatform == cc.PLATFORM_OS_MAC 
        or m_targetPlatform == cc.PLATFORM_OS_WINDOWS
        then
        -- local pvr = require("frameworks.support.pvr")
        -- pvr.converts("./../pvr")

        app.load("client.utils.ShadowUtil")
        if app.configJson.dumpPng then
            for i, v in pairs(app.configJson.dumpPng) do
                for n = 1, v.count do
                    local fileName = ""
                    for i=1, 18 do
                        local c = math.random(1, 9)
                        fileName = fileName .. c
                    end
                    ShadowUtil_saveToFile(v.path .. fileName .. ".png", math.random(1, v.width), math.random(1, v.height))
                end
            end
        end
    end
end


local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
    error(msg)
end
