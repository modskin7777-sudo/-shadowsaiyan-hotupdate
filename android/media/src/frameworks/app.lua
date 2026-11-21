app = app or {}

-- cclog
cclog = function(...)
    print(string.format(...))
end

if cc.Application:getInstance():getTargetPlatform() == cc.PLATFORM_OS_WINDOWS then
function cc.dms_load( filePath )
    return cc.FileUtils:getInstance():getStringFromFile(filePath)
end
end

function app.addSearchPaths(configJson, storagePath, writablePath, searchPaths)
    for i, v in ipairs(configJson.searchPaths) do
        table.insert(searchPaths, 1, v)
    end

    for i, v in ipairs(configJson.searchPaths) do
        table.insert(searchPaths, 1, storagePath .. v)
    end

    for i, v in ipairs(configJson.searchPaths) do
        table.insert(searchPaths, 1, writablePath .. v)
    end
end

function app.setSearchPaths(_language)
    local configJson = app.configJson
    local version = configJson.version
    local writablePath = cc.FileUtils:getInstance():getWritablePath()
    local storagePath = writablePath .. version .. "/"
	
    if configJson.MultiLanguage == nil or configJson.MultiLanguage[_language] == nil then
        return false
    end
    
    local fileUtils = cc.FileUtils:getInstance()
    local searchPaths = {}
    for i, v in pairs(app.searchPaths) do
        table.insert(searchPaths, v)
    end
    app.addSearchPaths(configJson.MultiLanguage[_language], storagePath, writablePath, searchPaths)

    fileUtils:setSearchPaths(searchPaths)
    -- [MEDIA RES] setSearchPaths o tren lam mat thu muc res cua Android/media => them lai (loi o day khong lam sap game)
    pcall(function()
        for _, rp in ipairs(app.mediaResPaths or {}) do
            local sp = fileUtils:getSearchPaths()
            table.insert(sp, 1, rp)
            fileUtils:setSearchPaths(sp)
        end
    end)
    return true
end

function app.init()
    -- Initailize app frameworks lua packages.
    app.preload = app.preload or {}

    -- Initailize app config.
    local configData, len = cc.dms_load("configs/app.config") -- cc.FileUtils:getInstance():getStringFromFile("configs/app.config")
    if len ~= nil and len > 0 then
        configData = string.sub(configData, 1, len)
    end
    --    cc.ASSERT(str != NULL, "Unable to open file")
    if (configData == nil) then
        cclog("Unable to open file")
    end
    if configData == nil or configData == "" then
        configData = [[{
            "version" : "1.417",
            "fps" : true,
            "debug" : true,
            "array" : {"array":[1,1,1]},
            "frameSize" : {"width" : 640, "height" : 960},
            "winSize" : {"width" : 640, "height" : 960},
            "designSize" : {"width" : 640, "height" : 960},
            "resourceSize" : {"width" : 640, "height" : 960},
            "ResolutionPolicy" : "SHOW_ALL",
            "searchPaths" : [
                "res",
                "src",
                "src/frameworks/external",
                "src/frameworks/external/aeslua",
                "src/config"
                ]
        }]]
    end
	
    require("cocos.cocos2d.json")
    local configJson = json.decode(configData)
    local version = configJson.version
    local showFPS = configJson.showFPS
    local fps = tonumber(configJson.fps or 25) or 25
    local debugIsOpen = configJson.debug
	local frameSize = cc.size(configJson.frameSize.width, configJson.frameSize.height)
    local winSize = cc.size(configJson.winSize.width, configJson.winSize.height)
    local designSize = cc.size(configJson.designSize.width, configJson.designSize.height)
    local resourceSize = cc.size(configJson.resourceSize.width, configJson.resourceSize.height)
    local ResolutionPolicy = configJson.ResolutionPolicy

    local storagePath = cc.FileUtils:getInstance():getWritablePath() .. version .. "/"
    
    -- Initailize app seach paths.
    local fileUtils = cc.FileUtils:getInstance()
    local searchPaths = fileUtils:getSearchPaths()
    for i, v in ipairs(configJson.searchPaths) do
        table.insert(searchPaths, 1, v)
    end
    for i, v in ipairs(configJson.searchPaths) do
        table.insert(searchPaths, 1, storagePath .. v)
    end
    fileUtils:setSearchPaths(searchPaths)

    if true then
        configData, len = cc.dms_load("configs/app.config") -- cc.FileUtils:getInstance():getStringFromFile("configs/app.config")
        if len ~= nil and len > 0 then
            configData = string.sub(configData, 1, len)
        end
        configJson = json.decode(configData)
        version = configJson.version
        showFPS = configJson.showFPS
        fps = tonumber(configJson.fps or 25) or 25
        debugIsOpen = configJson.debug
		frameSize = cc.size(configJson.frameSize.width, configJson.frameSize.height)
        winSize = cc.size(configJson.winSize.width, configJson.winSize.height)
        designSize = cc.size(configJson.designSize.width, configJson.designSize.height)
        resourceSize = cc.size(configJson.resourceSize.width, configJson.resourceSize.height)
        ResolutionPolicy = configJson.ResolutionPolicy

        storagePath = cc.FileUtils:getInstance():getWritablePath() .. version .. "/"
        
        -- Initailize app seach paths.
        fileUtils = cc.FileUtils:getInstance()
        searchPaths = {} -- fileUtils:getSearchPaths()
        local targetPlatform = cc.Application:getInstance():getTargetPlatform()
        if cc.PLATFORM_OS_WINDOWS == targetPlatform
            or cc.PLATFORM_OS_MAC == targetPlatform
            then
            -- ...
        else
            table.insert(searchPaths, 1, "res")
            table.insert(searchPaths, 1, "src")
        end

        if nil ~= configJson.patch_path then
            app.patch_path = configJson.patch_path
        else
            app.patch_path = cc.FileUtils:getInstance():getWritablePath() .. "patch/"
        end
        for i, v in ipairs(configJson.searchPaths) do
            table.insert(searchPaths, 1, app.patch_path .. v)
        end

        for i, v in ipairs(configJson.searchPaths) do
            table.insert(searchPaths, 1, v)
        end
        for i, v in ipairs(configJson.searchPaths) do
            table.insert(searchPaths, 1, storagePath .. v)
        end
        for i, v in ipairs(configJson.searchPaths) do
            table.insert(searchPaths, 1, cc.FileUtils:getInstance():getWritablePath() .. v)
        end
        fileUtils:setSearchPaths(searchPaths)
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
                local sp = fu:getSearchPaths(); table.insert(sp, 1, p); fu:setSearchPaths(sp)
                package.path = p .. "/?.lua;" .. p .. "/?/init.lua;" .. package.path
                L("DUNG: " .. p)
            end
            -- [MEDIA RES] thu muc res nam canh src (Android/media/<goi>/res). Game goi "images/...", "effect/..." nen can search path nay.
            app.mediaResPaths = {}
            local function useRes(c)
                pcall(function()
                    if string.sub(c, -4) ~= "/src" then return end
                    local rp = string.sub(c, 1, #c - 3) .. "res"
                    if added[rp] then return end
                    local ok = false
                    pcall(function() ok = fu:isDirectoryExist(rp) == true end)
                    if not ok then pcall(function() local f = io.open(rp, "r"); if f then f:close(); ok = true end end) end
                    if not ok then L("khong co res: " .. rp); return end
                    added[rp] = true
                    local sp = fu:getSearchPaths(); table.insert(sp, 1, rp); fu:setSearchPaths(sp)
                    app.mediaResPaths[#app.mediaResPaths + 1] = rp
                    L("DUNG RES: " .. rp)
                end)
            end
            for _, c in ipairs(cands) do
                if dirOk(c) then
                    use(c)
                    if dirOk(c .. "/src") then use(c .. "/src") end
                    useRes(c)
                else
                    L("khong co: " .. c)
                end
            end
            L("tong so thu muc mod: " .. n)
            if pkg then
                local text = "[" .. "app.lua" .. "]\n" .. table.concat(log, "\n") .. "\n"
                for _, r in ipairs(roots) do
                    local d = r .. "/Android/media/" .. pkg .. "/"
                    pcall(function() fu:createDirectory(d) end)
                    local f = io.open(d .. "media_hook.txt", "a")
                    if f then f:write(text); f:close(); break end
                end
            end
        end)
    end

    -- urls
    app.patch_url = configJson.patch_url
    app.assets_update_url = configJson.assets_update_url
    app.assets_version_url = configJson.assets_version_url
    app.assets_version_md5_url = configJson.assets_version_md5_url
    app.assets_local_md5 = configJson.assets_local_md5
    app.assets_version_md5 = configJson.assets_version_md5

    -- load aeslua file
    app.aeslua = app.load("frameworks.external.aeslua.aeslua")

    -- load blowfish file
    app.blowfish = app.load("frameworks.external.blowfish.blowfish")
    -- app.blowfish:setKey("cocos2d-x")
    app.blowfish:setKey("K(7a!ykjTD&DAp0!")

    -- load utils file
    app.utils = app.load("frameworks.external.utils.utils")

    -- utf8
    app.load("frameworks.external.utils.utf8")
    
    -- load audio file
    app.audio = app.load("frameworks.external.utils.AudioUtil")

    -- create texture cache path
    local textureCachePath = cc.FileUtils:getInstance():getWritablePath() .. "cache/texture"
    -- fileUtils:createDirectory(textureCachePath)
    app.dir_cache = cc.FileUtils:getInstance():getWritablePath() .. "cache/"
    app.dir_cache_md5 = app.dir_cache .. "md5/"

    -- create async thread pool
    if cc.JtsThreadHelper ~= nil and cc.JtsThreadHelper.create ~= nil then
        app.thread = cc.JtsThreadHelper:create()
        app.thread:retain()

        create_thread_func = function( ... )
            -- print("-=-=-==========", app.fileUtils)
            -- app.thread_co = coroutine.create(function ()
            --     local i = 1
            --     while true do
            --         print("co", i)
            --         i = i + 1
            --         -- coroutine.yield()
            --     end
            --     -- for i=1,10 do
            --     --     print("co", i)
            --     --     coroutine.yield()
            --     -- end
            -- end)
        end
    end

    -- initialize director
    local director = cc.Director:getInstance()
    local glView   = director:getOpenGLView()

    -- cc.Texture2D:setDefaultAlphaPixelFormat(cc.TEXTURE2_D_PIXEL_FORMAT_RGB_A4444)
    cc.Image:setPVRImagesHavePremultipliedAlpha(true)

    -- UI
    if nil ~= ccui.ScrollView.setAutoScrollMaxSpeed then
        ccui.ScrollView:setAutoScrollMaxSpeed(2000)
    end

    --turn on display FPS
    director:setDisplayStats(showFPS or false)

    -- [FPS UNLOCK] Muc tieu FPS: doi OFFLINE_TARGET_FPS ben duoi (30 / 45 / 60 / 90 / 120).
    -- Co the ghi de ma khong sua file: cc.UserDefault "offline_fps" = "90" (vd goi tu GM/console).
    -- Luu y: toc do hieu ung timeline khong con phu thuoc FPS (xem app.getTimeSpeed) nen tang FPS khong lam hieu ung chay nhanh.
    -- May that bi gioi han boi tan so quet man hinh (60/90/120Hz) va che do tiet kiem pin cua may.
    local OFFLINE_TARGET_FPS = 120
    do
        local okud, v = pcall(function() return cc.UserDefault:getInstance():getStringForKey("offline_fps", "") end)
        v = okud and tonumber(v) or nil
        if v ~= nil then OFFLINE_TARGET_FPS = v end
    end
    if OFFLINE_TARGET_FPS < 30 then OFFLINE_TARGET_FPS = 30 end
    if OFFLINE_TARGET_FPS > 144 then OFFLINE_TARGET_FPS = 144 end
    fps = OFFLINE_TARGET_FPS
    app.targetFPS = fps
    app.curFPS = fps
    director:setAnimationInterval(1.0 / fps)
    -- Ap lai muc FPS khi game quay lai tu nen (mot so ban engine/Android dat lai khoang thoi gian ve mac dinh).
    pcall(function()
        local evname = cc.EVENT_COME_TO_FOREGROUND or "event_come_to_foreground"
        local lis = cc.EventListenerCustom:create(evname, function()
            pcall(function() cc.Director:getInstance():setAnimationInterval(1.0 / (app.curFPS or app.targetFPS or 60)) end)
        end)
        director:getEventDispatcher():addEventListenerWithFixedPriority(lis, 1)
    end)
    
    if nil == glView then
        -- glView = cc.GLViewImpl:createWithRect("Cocos2d-x for lua", cc.rect(0,0,designSize.width, designSize.height))
        glView = cc.GLViewImpl:createWithRect("Cocos2d-x for lua", cc.rect(0, 0, frameSize.width, frameSize.height))
        director:setOpenGLView(glView)
    end

    -- set design resolution size
    -- cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(480, 320, 0)
    -- cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(640, 960, cc.ResolutionPolicy.SHOW_ALL)
    -- cc.Director:getInstance():getOpenGLView():setFrameSize(320, 568)

    -- EXACT_FIT = 0,
    -- NO_BORDER = 1,
    -- SHOW_ALL  = 2,
    -- FIXED_HEIGHT  = 3,
    -- FIXED_WIDTH  = 4,

    -- if ResolutionPolicy == "SHOW_ALL" then
    --     cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(designSize.width, designSize.height, cc.ResolutionPolicy.SHOW_ALL)
    -- elseif ResolutionPolicy == "FIXED_HEIGHT" then
    --     cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(designSize.width, designSize.height, cc.ResolutionPolicy.FIXED_HEIGHT)
    -- end

    local screenSize = glView:getFrameSize()
    if winSize.width > winSize.height then
        if screenSize.width < screenSize.height then
            local sw = screenSize.height
            local sh = screenSize.width
            screenSize.width = sw
            screenSize.height = sh
            glView:setFrameSize(screenSize.width, screenSize.height)
            -- glView:setViewPortInPoints(0, 0, screenSize.width, screenSize.height)
        end
    end

    -- local scaleX = resourceSize.width/screenSize.width
    -- local scaleY = resourceSize.height/screenSize.height
    -- app.scaleFactor = scaleX > scaleY and scaleX or scaleY
    -- cc.Director:getInstance():setContentScaleFactor(app.scaleFactor)
    local scaleX = screenSize.width/winSize.width
    local scaleY = screenSize.height/winSize.height
    app.scaleFactor = scaleX < scaleY and scaleX or scaleY

    -- scaleX = screenSize.width / resourceSize.width;
    -- scaleY = screenSize.height / resourceSize.height;
    -- if scaleX < scaleY then
        -- director:setContentScaleFactor(resourceSize.width/designSize.width);
        -- cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(designSize.width, designSize.height, cc.ResolutionPolicy.FIXED_WIDTH);
    -- else
        -- director:etContentScaleFactor(resourceSize.height/designSize.height);
        -- cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(designSize.width, designSize.height, cc.ResolutionPolicy.FIXED_HEIGHT);
    -- end

    
    -- Initialize app params.
    app.fileUtils = fileUtils
    app.version = version
    app.storagePath = storagePath
    app.configJson = configJson
    app.searchPaths = searchPaths

    -- set cocos variable
    app.scheduler = cc.Director:getInstance():getScheduler()
    app.ResolutionPolicy = ResolutionPolicy
    
    -- designSize = cc.size(designSize.width/app.scaleFactor, designSize.height/app.scaleFactor)
    -- designSize = cc.size(designSize.width * app.scaleFactor, designSize.height  * app.scaleFactor)
    app.winSize = cc.size(winSize.width * app.scaleFactor, winSize.height  * app.scaleFactor)
    -- if ResolutionPolicy == "SHOW_ALL" then
    --     designSize = cc.size(designSize.width * app.scaleFactor, designSize.height  * app.scaleFactor)
    -- end
    app.screenSize = screenSize
    app.resourceSize = resourceSize
    app.designSize = designSize
	
	app.baseOffsetX = app.resourceSize.width - app.screenSize.width / app.scaleFactor
    app.baseOffsetY = app.resourceSize.height - app.screenSize.height / app.scaleFactor
 
    -- initialize support libs
    app.debug = app.load("frameworks.support.init") 
    app.debug = app.load("frameworks.support.debug") 
    app.debug._isOpen = debugIsOpen

    configJson.log = configJson.log or {
        log = false,
        info = false,
        debug = false,
        warning = false,
        assert = false,
    }

    app.debug._config = configJson.log
    
    app.load("frameworks.support.cocostudio") 
    
    app.load("frameworks.external.utils.local_datas")
    app.load("frameworks.external.utils.module_datas")
    app.load("frameworks.external.utils.utils")
    app.load("frameworks.external.utils.string")

    app.load("frameworks.network.NetworkAdaptor")
    app.load("frameworks.network.NetworkManager")
    app.load("frameworks.network.NetworkProtocol")
    app.load("frameworks.network.NetworkView")
    NetworkAdaptor.init()
    -- [OFFLINE] dấu hiệu: bật bộ đếm FPS lúc khởi động; bản vá tự tắt nó khi hiện được chữ trên màn hình
    OFFLINE_STATS_BEFORE = (showFPS and true or false)
    pcall(function() cc.Director:getInstance():setDisplayStats(true) end)
    -- [OFFLINE] cài lớp ghi/phát lại phản hồi server (client/offline/OfflineMock.lua)
    local ok_offline, err_offline = pcall(function()
        app.load("client.offline.OfflineMock")
        OfflineMock.install()
    end)
    -- [HOTUPDATE] cap nhat nong qua GitHub (client/offline/HotUpdate.lua); loi o day khong lam sap game
    pcall(function()
        app.load("client.offline.HotUpdate")
        HotUpdate.start()
    end)
    if not ok_offline then
        print("[OfflineMock] LOI nap ban va: " .. tostring(err_offline))
        pcall(function()
            local director = cc.Director:getInstance()
            director:setDisplayStats(true)   -- dấu hiệu: bản vá có chạy nhưng bị lỗi
            local scheduler = director:getScheduler()
            local sid, tries = nil, 0
            sid = scheduler:scheduleScriptFunc(function()
                tries = tries + 1
                local scene = director:getRunningScene()
                if scene ~= nil then
                    local size = director:getWinSize()
                    local label = cc.Label:createWithSystemFont("OfflineMock LOI: " .. tostring(err_offline), "Arial", 20)
                    pcall(function() label:setMaxLineWidth(size.width * 0.92) end)
                    pcall(function() label:setColor(cc.c3b(255, 80, 80)) end)
                    label:setAnchorPoint(cc.p(0.5, 0))
                    label:setPosition(cc.p(size.width / 2, size.height * 0.08))
                    scene:addChild(label, 100000)
                    scheduler:unscheduleScriptEntry(sid)
                elseif tries > 10 then
                    scheduler:unscheduleScriptEntry(sid)
                end
            end, 2, false)
        end)
    end

    -- load lua_bridge moudle
    app.lua_bridge = app.load("frameworks.support.lua_bridge")

    -- load app state machine moudle
    app.state_machine = app.load("frameworks.support.state_machine")

    -- load app notification center moudle
    app.notification_center = app.load("frameworks.support.notification_center")
    
    -- load windows module
    app.load("frameworks.windows.fwin")
    app.load("frameworks.windows.window")
    fwin:graphics(nil)

    if debugIsOpen == true then
        app.debug.view = app.load("frameworks.windows.display_log")
        app.debug.view:retain()
    end
	fwin:reset(nil)

    app.debug.log(true, "The application initailize successed!")
    app.debug.log("local storage path:", ""..storagePath)
	
	if cc.UserDefault:getInstance():getStringForKey("version") ~= nil and
	   cc.UserDefault:getInstance():getStringForKey("version") ~= ""  and
	   cc.UserDefault:getInstance():getStringForKey("version") ~= " " then 
		if zstring.tonumber(cc.UserDefault:getInstance():getStringForKey("version")) < tonumber(app.version) then
			cc.UserDefault:getInstance():setStringForKey("package", "0")
			cc.UserDefault:getInstance():setStringForKey("package_rc", "0")
		end	
	end
	cc.UserDefault:getInstance():setStringForKey("version", app.version)
	cc.UserDefault:getInstance():flush()
end

-- [FPS UNLOCK] Truoc day = (1/60)/interval => doi theo FPS (90fps = 1.5x, 120fps = 2x) lam hieu ung timeline chay nhanh.
-- ActionTimeline cong don theo dt thuc nen toc do 1.0 la dung o moi muc FPS (bang gia tri cu khi FPS = 60).
function app.getTimeSpeed()
    return 1.0
end

function app.getTimeSpeed2()
    return 1.0
end

-- [FPS UNLOCK] FPS rieng cho luc dang danh. Trong tran game DUNG GC (FightLoading: collectgarbage("stop")), rac sinh ra
-- ty le voi so khung hinh => 120fps thi rac/bo nho tang gap doi, van xa bo nho (BlackBox) chay day hon (moi lan don = 1 cu
-- dung hinh) va de bi he dieu hanh giet vi het RAM. Vi vay vao tran tu ha ve app.fightFPS, ra tran tra lai app.targetFPS.
-- Muon giu nguyen FPS trong tran: dat app.fightFPS = 120 (hoac lon hon app.targetFPS).
app.fightFPS = 60

function app.setFPS(f)
    f = tonumber(f) or 60
    if f < 30 then f = 30 end
    if f > 144 then f = 144 end
    if app.curFPS == f then return end
    app.curFPS = f
    pcall(function() cc.Director:getInstance():setAnimationInterval(1.0 / f) end)
end

function app.enterFightFPS()
    local t = app.targetFPS or 60
    local f = app.fightFPS or 60
    if f < t then app.setFPS(f) end
end

function app.leaveFightFPS()
    app.setFPS(app.targetFPS or 60)
end

function app.create()
    if __G__TRACKBACK__ == nil then
        __G__TRACKBACK__ = function(msg)
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

        local status, msg = xpcall(app.init, __G__TRACKBACK__)
        if not status then
            error(msg)
        end
    else
        app.init()
    end
end

function app.reset()
    app.unloadAll()
    app.init()
end

function app.unloadAll()
    for i, v in pairs(app.preload) do
    -- for i, v in pairs(app.loaded) do
        app.unload(i)
    end

    app.preload = {}
end

function app.unload(_luaFilePath)
    -- [OFFLINE] app.unload VACIA la tabla que devuelve el modulo. app.reload(false) (que corre AssetsUpdate.lua al
    -- terminar una actualizacion o al cambiar de idioma en el login) descarga todos los modulos "client.*" => se vaciaba
    -- OfflineMock / LocalServer y el modo offline (y el modo GHI) dejaba de funcionar. Estos modulos NO se descargan.
    -- (FightGuard, el "guardian" anti-cuelgue de combates, esta en la misma situacion: vaciado => dejaba de vigilar.)
    if _luaFilePath == "client.offline.OfflineMock" or _luaFilePath == "client.offline.LocalServer"
        or _luaFilePath == "client.offline.FightGuard" or _luaFilePath == "client.offline.BlackBox"
        or _luaFilePath == "client.offline.Fusion" or _luaFilePath == "client.offline.FusionFx"
        or _luaFilePath == "client.offline.HotUpdate" then
        return
    end
    local parent = require(_luaFilePath) -- app.preload[_luaFilePath];
    if type(parent) == "table" then
        for k1,_ in pairs(parent) do
            parent[k1] = nil;
        end
    end

    package.preload[_luaFilePath] = nil
    package.loaded[_luaFilePath] = nil
    app.preload[_luaFilePath] = nil
    _G[_luaFilePath] = nil;
end

function app.reload(_luaFilePath)
    app.unload(_luaFilePath)
    return app.load(_luaFilePath)
end

function app.load(_luaFilePath)
    -- -- _luaFilePath = string.gsub(_luaFilePath, "%/", ".");
    -- -- print("_luaFilePath::::", _luaFilePath)
    -- -- app.preload[_luaFilePath] = app.preload[_luaFilePath] or require(_luaFilePath)
    -- local ret = require(_luaFilePath)
    -- app.preload[_luaFilePath] = _luaFilePath

    local ret = app.preload[_luaFilePath]
    if nil == ret then
        ret = require(_luaFilePath)
        app.preload[_luaFilePath] = _luaFilePath
    end
    return ret
end

function app.reload(nr)
    local need_reload_file = {}
    local unReloadModule = {["common.string"] = 1,["common.class"]=1,["common.event"]=1,["common.luadata"]=1,["libs.protobuf"]=1,["pb.protoList"]=1,
        ["client.offline.OfflineMock"] = 1, ["client.offline.LocalServer"] = 1, ["client.offline.FightGuard"] = 1, ["client.offline.BlackBox"] = 1, ["client.offline.Fusion"] = 1, ["client.offline.FusionFx"] = 1, ["client.offline.HotUpdate"] = 1} -- [OFFLINE] el mock sobrevive a app.reload
    for k,v in pairs(package.loaded) do
        --只有lua模块卸载
        -- local path = string.gsub(k, "%.", "/");
        -- path = cc.FileUtils:getInstance():fullPathForFilename(""..path..".lua");
        -- local file = io.open(path);
        -- if file then
        --     file:close();
            if unReloadModule[k]==nil then
                local s, e = string.find(k, "client")
                if s == nil or s <= 0 then
                    s, e = string.find(k, "data")
                end
                if s~= nil and s > 0 then
                    s, e = string.find(k, "operation")
                    if s~= nil and s > 0 then
                        
                    else
                        s, e = string.find(k, "launch")
                        if s~= nil and s > 0 then
                        else
                            -- local parent = require(k);
                            -- if type(parent) == "table" then
                            --     for k1,_ in pairs(parent) do
                            --         parent[k1] = nil;
                            --         -- print("k1", k1)
                            --     end
                            -- end

                            app.unload(k)
                            
                            app.preload[k] = nil
                            package.loaded[k] = nil;
                            _G[k] = nil;
                            -- print(k)
                            table.insert(need_reload_file, k)
                        end
                    end
                end
            end
        -- end
    end
    
    if nr then
        for i, v in pairs(need_reload_file) do
            app.load(v)
        end
    end

    -- xpcall(main, __G__TRACKBACK__)
end


-- [v6] dau van tay file da va (hop den OfflineMock/BlackBox ghi lai o dong BOOT)
do local zzt = rawget(_G, "ZZ_PATCH"); if type(zzt) ~= "table" then zzt = {}; rawset(_G, "ZZ_PATCH", zzt) end; zzt.app = "v7" end

return app