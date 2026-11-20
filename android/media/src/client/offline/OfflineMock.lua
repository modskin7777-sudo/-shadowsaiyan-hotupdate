-- OfflineMock.lua
OfflineMock = OfflineMock or {}
local M = OfflineMock

M.version      = "v6.31-fusion"
M.mode         = "record"
M.lenient      = true

M.show_hud     = false -- log goc trai duoi: luon an
M.show_toast   = false -- thong bao chu vang giua man hinh: luon an
M.max_bytes    = 64 * 1024 * 1024
M.mode_file    = "offline_mode.txt"
M.rec_file     = "offline_rec.txt"
M.miss_file    = "offline_missing.txt"
M.gm_file      = "offline_gm.txt"
M.ud_key       = "offline_mode"
M.gm_ud_key    = "offline_gm"
M.ui_ud_key    = "offline_clean_ui"
M.mirror_dirs  = { "/sdcard/Download/", "/storage/emulated/0/Download/" }
M.taps_needed  = 5
M.tap_window   = 4
M.tap_region   = 0.06
M.max_miss_toast = 0
M.err_file     = "offline_errors.txt"
M.max_err_log  = 60
M.hook_lua_errors = true

-- [FIX log] 5 lenh chi doc/phu (trung tam thuong, nguoi da qua ai npc, doi hinh ai nightmare, nhiem vu dao ban):
-- khong co du lieu ban ghi => tra "0" (rong, thanh cong) im lang, khong ghi vao offline_missing.txt nua.
M.silent_cmds  = { keep_alive = true, record_crash = true, new_bi_log_cmd = true,
	reward_center_init = true, draw_reward_center = true, get_hard_copy_user_formation = true,
	get_copy_clear_user_info = true, file_island_task_info = true }

M.diag_hud     = false
M.diag_secs    = { cmd = 45, bad = 90, err = 120, unstick = 30 }
M.max_err_toast = 6
M.unstick      = true
M.unstick_delay = 3
M.guard_parser = true
M.fight_block  = true

M.fight_cmds   = {
	"arena_launch", "arena_launch2", "duel_launch", "duel_revenge_launch", "grab_launch", "grab_launch_ten",
	"union_fight", "unino_fight", "union_counterpart_fight", "union_battleground_fight", "union_stronghold_fight", "union_copy_fight",
	"three_kingdoms_fight", "three_kingdoms_launch", "towel_launch", "warcraft_fight", "manor_fight",
	"mine_boss_launch", "mine_fight_launch", "mine_event_launch", "random_event_launch",
	"rebel_army_fight", "rebel_boss_fight",
	"pokemon_explore_boss_challenge", "pokemon_explore_single_challenge", "file_island_boss_challenge", "file_island_single_challenge",
	"team_arena_challenge", "cross_arena_challenge", "user_stronghold_plunder", "pet_counterpart_launch", "ship_purify_team_launch",
	"camp_duel_battle_init", "extreme_fast_battle", "environment_fight", "fb_launch",
	"world_boss_launch", "world_boss_attack_start", "world_boss_attack_finish", "world_boss_attack",
}
M.max_reattach = 12
M.gm_button    = true -- [FIX GM AN] hien san khi mo game (an bang nut AN HUD/NUT, hien lai: cham 5 lan goc duoi-trai)
M.gm_button_y  = 0.45
M.use_ls       = true
M.ls_module    = "client.offline.LocalServer"
-- [v5] FightGuard: tu go khi tran dung han khong danh nua (xem client/offline/FightGuard.lua)
M.fight_guard  = true
M.fg_module    = "client.offline.FightGuard"
-- [v6] BlackBox (hop den): nhat ky bo nho/trang thai tran + bao cao khi phien truoc bi thoat dot ngot + van xa bo nho
-- trong tran + bat lai GC sau tran (xem client/offline/BlackBox.lua)
M.blackbox     = true
M.bb_module    = "client.offline.BlackBox"
-- [v6.31] Fusion: HOP THE 3 TUONG (chi offline; nut HOP THE tren bang GM) (xem client/offline/Fusion.lua)
M.fusion       = true
M.fu_module    = "client.offline.Fusion"
M.ls_period    = 0.05
M.om_button    = true -- nut OM luon hien
M.om_button_y  = 0.60
M.tap_min_w    = 380
M.tap_min_h    = 48
M.dump_budget  = 0.005
M.dump_period  = 0.05
M.dump_chunk   = 60
M.dump_steps   = 100
M.dump_core_cap = 10 * 1024 * 1024
M.dump_dir     = "offline_tables/"
M.dump_index_file = "offline_tables_index.txt"
M.dump_core_file  = "offline_tables_core.txt"
M.dump_ed_file    = "offline_ed_overview.txt"

M.flags = M.flags or {}
local F = M.flags
if F.install == nil then F.install = false end
if F.net == nil then F.net = false end
if F.upd == nil then F.upd = false end
if F.send == nil then F.send = false end
if F.poll == nil then F.poll = false end

M.gm = M.gm or { on = true, floors = {} }
if M.clean_ui == nil then M.clean_ui = false end

local function logmsg(...)
	local t = {}
	for i = 1, select("#", ...) do
		t[#t + 1] = tostring((select(i, ...)))
	end
	print("[OfflineMock] " .. table.concat(t, " "))
end

local function running_scene()
	local ok, scene = pcall(function()
		return cc.Director:getInstance():getRunningScene()
	end)
	if ok then return scene end
	return nil
end

local function visible_size()
	local ok, s = pcall(function()
		return cc.Director:getInstance():getVisibleSize()
	end)
	if ok and type(s) == "table" and s.width ~= nil then return s end
	ok, s = pcall(function()
		return cc.Director:getInstance():getWinSize()
	end)
	if ok and type(s) == "table" and s.width ~= nil then return s end
	return { width = 960, height = 640 }
end

local function alive(node)
	if node == nil then return false end
	local tl = rawget(_G, "tolua")
	if type(tl) == "table" and tl.isnull ~= nil then
		local ok, dead = pcall(tl.isnull, node)
		return ok and not dead
	end
	return true
end

local function schedule(interval, fn)
	local id
	local ok = pcall(function()
		local scheduler = cc.Director:getInstance():getScheduler()
		id = scheduler:scheduleScriptFunc(function(dt)
			local done = fn(dt)
			if done and id ~= nil then
				scheduler:unscheduleScriptEntry(id)
			end
		end, interval, false)
	end)
	return ok
end

local function fmt_int(n)
	return string.format("%.0f", n)
end

local function fmt_num(n)
	n = tonumber(n)
	if n == nil then return "-" end
	local s = fmt_int(n)
	local neg = false
	if string.sub(s, 1, 1) == "-" then
		neg = true
		s = string.sub(s, 2)
	end
	while true do
		local r, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then break end
	end
	if neg then s = "-" .. s end
	return s
end

local function to_num(v)
	if type(v) == "number" then return v end
	if type(v) == "string" then return tonumber(v) end
	return nil
end

local function ls_active()
	local LS = M.LS
	return LS ~= nil and LS.enabled() == true
end

local function ls_manages(key)
	if not ls_active() then return false end
	if key == "gold" or key == "silver" then return true end
	if key == "food" or key == "level" then

		return M.LS.user_get ~= nil and M.LS.user_get(key) ~= nil
	end
	return false
end

local HUD_NAME = "offlinemock_hud"

local function make_label(text, size)
	local label
	pcall(function() label = cc.Label:createWithSystemFont(text, "Arial", size) end)
	if label == nil then
		pcall(function() label = ccui.Text:create(text, "Arial", size) end)
	end
	return label
end

local function gm_floor_count()
	local n = 0
	for k, v in pairs(M.gm.floors) do
		if v ~= nil and v > 0 and not ls_manages(k) then n = n + 1 end
	end
	return n
end

local MODE_SHORT = { record = "GHI", replay = "SEVER TEST", off = "TAT" }

local function status_text()
	local function yn(v) return v and "OK" or "-" end
	local s = "OfflineMock " .. M.version .. " | app:" .. yn(F.install)
		.. " send:" .. yn(F.send) .. " poll:" .. yn(F.poll) .. " upd:" .. yn(F.upd) .. " | "
	if M.mode == "record" then
		s = s .. "REC " .. (M._rec_count or 0)
	elseif M.mode == "replay" then
		s = s .. "REPLAY " .. (M.count or 0) .. " rec, thieu " .. (M._miss_n or 0)
		if (M._err_n or 0) > 0 then s = s .. ", loi " .. M._err_n end
		if M.count == 0 then s = s .. " (KHONG CO " .. M.rec_file .. ")" end
		if M.gm_button then
			if M.gm.on then
				s = s .. " | GM " .. gm_floor_count()
			else
				s = s .. " | GM tat"
			end
		end
	else
		s = s .. "OFF"
	end

	local pend = M._pending_mode ~= nil and M._pending_mode() or nil
	if pend ~= nil then
		s = s .. " | LAN SAU: " .. (MODE_SHORT[pend] or tostring(pend)) .. " (thoat han game, mo lai)"
	end

	local dp = M._dump
	if dp ~= nil then
		s = s .. " | DUMP BANG " .. tostring(dp.i) .. "/" .. tostring(#dp.names)
	end

	if M.autoHud ~= nil then s = s .. M.autoHud() end

	if (M._taps or 0) > 0 and os.time() <= (M._tap_show_until or 0) then
		s = s .. " | tap " .. tostring(M._taps) .. "/" .. tostring(M.taps_needed)
	end
	return s
end

local function build_hud(scene)
	local size = cc.Director:getInstance():getWinSize()
	local root = cc.Node:create()
	root:setName(HUD_NAME)

	local status = make_label("", 16)
	status:setName("status")
	status:setAnchorPoint(cc.p(0, 0))
	status:setPosition(cc.p(6, 4))
	pcall(function() status:setColor(cc.c3b(255, 255, 255)) end)
	pcall(function() status:setOpacity(210) end)
	pcall(function() status:enableOutline(cc.c4b(0, 0, 0, 255), 1) end)
	root:addChild(status)

	local status2 = make_label("", 16)
	status2:setName("status2")
	status2:setAnchorPoint(cc.p(0, 0))
	status2:setPosition(cc.p(6, 24))
	pcall(function() status2:setColor(cc.c3b(150, 230, 255)) end)
	pcall(function() status2:setOpacity(235) end)
	pcall(function() status2:enableOutline(cc.c4b(0, 0, 0, 255), 1) end)
	root:addChild(status2)

	local status3 = make_label("", 14)
	if status3 ~= nil then
		status3:setName("status3")
		status3:setAnchorPoint(cc.p(0, 0))
		status3:setPosition(cc.p(6, 44))
		pcall(function() status3:setMaxLineWidth(size.width * 0.9) end)
		pcall(function() status3:setLineBreakWithoutSpace(true) end)
		pcall(function() status3:setColor(cc.c3b(255, 190, 120)) end)
		pcall(function() status3:setOpacity(240) end)
		pcall(function() status3:enableOutline(cc.c4b(0, 0, 0, 255), 1) end)
		pcall(function() status3:setVisible(false) end)
		root:addChild(status3)
	end

	local toast = make_label("", 22)
	toast:setName("toast")
	toast:setAnchorPoint(cc.p(0.5, 0))
	toast:setPosition(cc.p(size.width / 2, size.height * 0.08))
	pcall(function() toast:setMaxLineWidth(size.width * 0.92) end)
	pcall(function() toast:setLineBreakWithoutSpace(true) end)
	pcall(function() toast:setColor(cc.c3b(255, 235, 59)) end)
	pcall(function() toast:enableOutline(cc.c4b(0, 0, 0, 255), 2) end)
	root:addChild(toast)

	scene:addChild(root, 100000)
	return root
end

local function hud_tick()
	local scene = running_scene()
	if scene == nil then return end
	local root = scene:getChildByName(HUD_NAME)
	if root == nil then
		root = build_hud(scene)
		M.hud_builds = (M.hud_builds or 0) + 1
		if not M._stats_restored then

			M._stats_restored = true
			pcall(function()
				cc.Director:getInstance():setDisplayStats(rawget(_G, "OFFLINE_STATS_BEFORE") == true)
			end)
		end
	end
	local status = root:getChildByName("status")
	local toast = root:getChildByName("toast")
	if M.show_hud then
		status:setVisible(true)
		status:setString(status_text())
	else
		status:setVisible(false)
	end
	local status2 = root:getChildByName("status2")
	if status2 ~= nil then
		local t2 = nil
		if M.show_hud and M.mode == "replay" then
			if ls_active() then
				t2 = M.LS.status_text()
			elseif M._ls_err ~= nil then
				t2 = "LS: khong nap duoc (" .. tostring(M._ls_err) .. ")"
			end
		end
		if t2 ~= nil then
			status2:setVisible(true)
			status2:setString(t2)
		else
			status2:setVisible(false)
		end
	end

	local status3 = root:getChildByName("status3")
	if status3 ~= nil then
		local t3 = nil
		if M.show_hud and M.mode == "replay" and M.diagText ~= nil then
			local okd, d = pcall(M.diagText)
			if okd and type(d) == "string" and d ~= "" then t3 = d end
		end
		if t3 ~= nil then
			status3:setVisible(true)
			status3:setString(t3)
		else
			status3:setVisible(false)
		end
	end
	if M.show_toast and M._toast_text ~= nil and os.time() <= (M._toast_until or 0) then
		toast:setVisible(true)
		toast:setString(M._toast_text)
	else
		toast:setVisible(false)
		toast:setString("")
	end
end
M._hudTick = hud_tick

local function notify(text, seconds)
	logmsg(text)
	M._toast_text = text
	M._toast_until = os.time() + (seconds or 6)
	pcall(hud_tick)
	return true
end
M.notify = notify

local function ud_get(key)
	local ok, v = pcall(function()
		return cc.UserDefault:getInstance():getStringForKey(key, "")
	end)
	if ok and type(v) == "string" and v ~= "" then return v end
	return nil
end

local function ud_set(key, value)
	pcall(function()
		local ud = cc.UserDefault:getInstance()
		ud:setStringForKey(key, value)
		if ud.flush ~= nil then ud:flush() end
	end)
end

function M.uiLoad()
	if M._ui_loaded then return end
	M._ui_loaded = true
	M.clean_ui = false -- [FIX GM AN] moi lan mo game nut GM/OM deu HIEN (khong luu trang thai an)
end

function M.uiApply()
	local hide = M.clean_ui == true
	M.show_hud = false
	M.diag_hud = false
	M.gm_button = true -- [FIX GM AN] nut GM luon hien, khong bi an boi AN HUD/NUT hay cham 5 lan (giong nut OM)
	M.om_button = true -- nut OM luon hien, khong bi an
	if hide then
		-- [FIX TN] bang TN (Tournament) KHONG bi an theo "AN HUD/NUT" nua (giong nut OM): khong dong no o day
		M._gm_open = false -- [FIX WW] nut WW khong bi an theo GM/AN HUD nua (giong TN)
	end
	pcall(M.gmRender)
	pcall(M.omRender)
	pcall(M.tpRender)
	pcall(M.wpRender)
	pcall(hud_tick)
end

function M.uiToggle()
	M.clean_ui = not (M.clean_ui == true)
	M.uiApply()
	return M.clean_ui
end

local function writable_dir()
	local ok, p = pcall(function()
		return cc.FileUtils:getInstance():getWritablePath()
	end)
	if ok and type(p) == "string" and p ~= "" then
		if string.sub(p, -1) ~= "/" then p = p .. "/" end
		return p
	end
	return ""
end

local function pkg_name()
	if M._pkg_checked then return M._pkg end
	M._pkg_checked = true
	local w = writable_dir()
	M._pkg = string.match(w, "^/data/user/%d+/([^/]+)/")
		or string.match(w, "^/data/data/([^/]+)/")
	return M._pkg
end

-- [FIX MEDIA] goc luu tru theo user id that (app nhan ban / Second Space chay o /storage/emulated/<uid>/, khong phai 0)
function M.storage_root()
	local w = writable_dir()
	local uid = string.match(w, "^/data/user/(%d+)/")
	return "/storage/emulated/" .. (uid or "0")
end

local function external_app_dir()
	if M._ext_checked then return M._ext_dir end
	M._ext_checked = true
	local pkg = pkg_name()
	if pkg ~= nil then
		local dir = M.storage_root() .. "/Android/data/" .. pkg .. "/files/"
		pcall(function() cc.FileUtils:getInstance():createDirectory(dir) end)
		M._ext_dir = dir
	end
	return M._ext_dir
end

local function media_app_dir()
	local pkg = pkg_name()
	if pkg == nil then return nil end
	return M.storage_root() .. "/Android/media/" .. pkg .. "/"
end

local function ensure_media_dir(path)
	local dir = media_app_dir()
	if dir == nil or string.sub(path, 1, #dir) ~= dir then return end
	if M._media_made then return end
	M._media_made = true
	pcall(function() cc.FileUtils:getInstance():createDirectory(dir) end)
end

local function candidates(name)
	local list = {}
	for i = 1, #M.mirror_dirs do
		list[#list + 1] = M.mirror_dirs[i] .. name
	end
	local med = media_app_dir()
	if med ~= nil then list[#list + 1] = med .. name end
	local ext = external_app_dir()
	if ext ~= nil then list[#list + 1] = ext .. name end
	list[#list + 1] = writable_dir() .. name
	return list
end

local function read_all(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

-- [BAN GHI DONG GOI SAN] Cac file offline_rec.txt / offline_ls_state.txt / offline_mode.txt co the nam ngay trong
-- src (thu muc M.seed_rel). May MOI (chua co file nao trong Download / Android/media / Android/data...) se doc ban
-- dong goi san nay => khong can GHI lai, mo game la chay OFFLINE (offline_mode.txt = replay). File cua chinh may
-- luon duoc uu tien; ban dong goi san chi la du phong khi may chua co file do.
M.seed_rel   = "client/offline/seed/"
M.seed_files = { ["offline_rec.txt"] = true, ["offline_ls_state.txt"] = true, ["offline_mode.txt"] = true, ["offline_gm.txt"] = true,
	-- [ACCOUNT] trang thai LocalServer MAC DINH cap cho moi tai khoan moi dang ky (xem LS.set_account / LS.new_account)
	["offline_ls_default.txt"] = true }
-- [ACCOUNT] Tai khoan offline: dang ky ghi vao offline_accounts.txt, dang nhap doi chieu file do (xem AccountStore.lua).
M.use_accounts = true
M.account_module = "client.offline.AccountStore"

local function seed_paths(name)
	local list = {}
	local med = media_app_dir()
	if med ~= nil then list[#list + 1] = med .. "src/" .. M.seed_rel .. name end
	pcall(function()
		local fu = cc.FileUtils:getInstance()
		local rel = M.seed_rel .. name
		if fu:isFileExist(rel) then
			local full = fu:fullPathForFilename(rel)
			if type(full) == "string" and full ~= "" and full ~= rel then list[#list + 1] = full end
		end
	end)
	return list
end

local function read_seed(name)
	if not M.seed_files[name] then return nil end
	local paths = seed_paths(name)
	for i = 1, #paths do
		local s = read_all(paths[i])
		if s ~= nil and s ~= "" then return s, paths[i] end
	end
	local ok, s = pcall(function()
		local fu = cc.FileUtils:getInstance()
		local rel = M.seed_rel .. name
		if fu:isFileExist(rel) then return fu:getStringFromFile(rel) end
		return nil
	end)
	if ok and type(s) == "string" and s ~= "" then return s, "FileUtils:" .. M.seed_rel .. name end
	return nil
end
M.readSeed = read_seed

local function read_first(name)
	local paths = candidates(name)
	for i = 1, #paths do
		local s = read_all(paths[i])
		if s ~= nil then return s, paths[i] end
	end
	local s, where = read_seed(name)
	if s ~= nil then
		M._seed_used = M._seed_used or {}
		M._seed_used[name] = where
		return s, where
	end
	return nil
end

local function writable_target(name)
	M._targets = M._targets or {}
	if M._targets[name] ~= nil then return M._targets[name] end
	local paths = candidates(name)
	for i = 1, #paths do
		ensure_media_dir(paths[i])
		local f = io.open(paths[i], "ab")
		if f then
			f:close()
			M._targets[name] = paths[i]
			return paths[i]
		end
	end
	return nil
end

local function append_line(name, text)
	local path = writable_target(name)
	if path == nil then return false end
	local f = io.open(path, "ab")
	if not f then return false end
	f:write(text)
	f:close()
	return true
end
M.append_line = append_line

-- [FIX lag 8] Ghi ra file tam roi doi ten: neu game bi tat / treo giua luc ghi thi file cu van nguyen ven
-- (truoc day mo "wb" cat file ngay => tat giua chung la mat trang thai). Doi ten loi thi ghi truc tiep nhu cu.
local function write_atomic(path, text)
	if #text < 4096 then return false end
	local tmp = path .. ".tmp"
	local f = io.open(tmp, "wb")
	if not f then return false end
	local okw = f:write(text)
	local okc = f:close()
	if not okw or okc == nil or okc == false then
		pcall(os.remove, tmp)
		return false
	end
	local okr = os.rename(tmp, path)
	if not okr then
		pcall(os.remove, tmp)
		return false
	end
	return true
end

local function write_first(name, text)
	local paths = candidates(name)
	for i = 1, #paths do
		ensure_media_dir(paths[i])
		local ok_a, done = pcall(write_atomic, paths[i], text)
		if ok_a and done then return paths[i] end
		local f = io.open(paths[i], "wb")
		if f then
			f:write(text)
			f:close()
			return paths[i]
		end
	end
	return nil
end

local function cmd_name(data)
	if data.commandItem ~= nil and data.commandItem.command ~= nil then
		return data.commandItem.command
	end
	if type(data.str) == "string" then
		local name = string.match(data.str, "^[^\r\n]*\r\n([^\r\n]*)")
		if name ~= nil and name ~= "" then return name end
	end
	return nil
end

local function norm_req(q)
	q = tostring(q or "")
	local rest = string.match(q, "^[^\r\n]*\r\n(.*)$")
	if rest ~= nil then return rest end
	return q
end

local ESC = { ["\\"] = "\\\\", ["\r"] = "\\r", ["\n"] = "\\n", ["\t"] = "\\t" }
local UNESC = { ["\\"] = "\\", r = "\r", n = "\n", t = "\t" }
local function esc(s) return (string.gsub(s, "[\\\r\n\t]", ESC)) end
local function unesc(s) return (string.gsub(s, "\\(.)", UNESC)) end

local function seen_before(set, name, req, res)
	local a = set[name]
	if a == nil then a = {}; set[name] = a end
	local b = a[req]
	if b == nil then b = {}; a[req] = b end
	if b[res] then return true end
	b[res] = true
	return false
end

local function split_tokens(res)
	local lines = {}
	local init = 1
	while true do
		local pos = string.find(res, "\r\n", init, true)
		if not pos then
			lines[#lines + 1] = string.sub(res, init)
			break
		end
		lines[#lines + 1] = string.sub(res, init, pos - 1)
		init = pos + 2
	end
	local out, n = {}, 0
	for i = 1, #lines do
		local line = lines[i]
		local s = 1
		while true do
			local p = string.find(line, " ", s, true)
			n = n + 1
			if not p then
				out[n] = string.sub(line, s)
				break
			end
			out[n] = string.sub(line, s, p - 1)
			s = p + 1
		end
	end
	return out
end

local function status_of(res)
	local toks = split_tokens(string.sub(res, 1, 400))
	return tonumber(toks[3])
end

local function is_skipped(data)
	local code = data.command
	local pc = rawget(_G, "protocol_command")
	if pc ~= nil then
		if pc.keep_alive ~= nil and code == pc.keep_alive.code then
			return true
		end
		if pc.record_crash ~= nil and code == pc.record_crash.code then
			return true
		end
	end
	return false
end

local MODE_NAME = { record = "GHI (online)", replay = "SEVER TEST", off = "TAT" }
local NEXT_MODE = { record = "replay", replay = "off", off = "record" }

local function valid_mode(s)
	return s == "off" or s == "record" or s == "replay"
end

function M.getMode()
	if not M._mode_loaded then
		M._mode_loaded = true
		local from = "mặc định"
		local ud = ud_get(M.ud_key)
		if valid_mode(ud) then
			M.mode = ud
			from = "lựa chọn trong game"
		else
			local s, where = read_first(M.mode_file)
			if s ~= nil then
				s = string.lower((string.gsub(s, "%s+", "")))
				if valid_mode(s) then
					M.mode = s
					from = tostring(where)
				end
			end
		end
		-- [REFRESH] TU CAP NHAT da thu het so lan o che do GHI ma khong xong => ve OFFLINE ngay (khong ket o che do GHI)
		if ud_get(M.refresh_key or "offline_refresh") == "1"
			and (tonumber(ud_get(M.refresh_try_key or "offline_refresh_try")) or 0) >= (M.refresh_max_try or 2) then
			ud_set(M.refresh_key or "offline_refresh", "0")
			ud_set(M.refresh_try_key or "offline_refresh_try", "0")
			ud_set(M.ud_key, "replay")
			M.mode = "replay"
			M._refresh_gaveup = true
			from = "TU CAP NHAT that bai nhieu lan -> OFFLINE"
		end
		logmsg("mode =", M.mode, "| nguồn:", from, "| thư mục ghi:", writable_dir())
	end
	return M.mode
end

function M.skipUpdate()
	F.upd = true
	if M.getMode() ~= "replay" then return false end
	-- [UPD] OFFLINE + CAP NHAT bat: AssetsManager chay luong cap nhat goc (co gioi han thoi gian, xem M.updatePlan)
	if M.updatePlan ~= nil then
		local okp, plan = pcall(M.updatePlan)
		if okp and plan == "check" then return false end
	end
	return true
end

function M._pending_mode()
	local n = M._next_mode
	if valid_mode(n) and n ~= M.mode then return n end
	return nil
end

function M.setMode(mode)
	if not valid_mode(mode) then return false end
	ud_set(M.ud_key, mode)
	M._next_mode = mode
	notify("OfflineMock: lần mở game sau sẽ ở chế độ " .. MODE_NAME[mode]
		.. ".\nHãy THOÁT HẲN game rồi mở lại.", 10)
	return true
end

function M.cycleMode()
	local cur = M._next_mode
	if not valid_mode(cur) then cur = ud_get(M.ud_key) end
	if not valid_mode(cur) then cur = M.getMode() end
	local nxt = NEXT_MODE[cur] or "record"
	M.setMode(nxt)
	return nxt
end

function M._onTap(x, y)
	local size = visible_size()
	local ox, oy = 0, 0
	pcall(function()
		local o = cc.Director:getInstance():getVisibleOrigin()
		if type(o) == "table" and o.x ~= nil and o.y ~= nil then ox, oy = o.x, o.y end
	end)
	local maxx = math.max(size.width * M.tap_region, M.tap_min_w or 0)
	local maxy = math.max(size.height * M.tap_region, M.tap_min_h or 0)
	if x - ox > maxx or y - oy > maxy then
		M._taps = 0
		return
	end
	local now = os.time()
	if (M._taps or 0) == 0 or now - (M._tap_t0 or 0) > M.tap_window then
		M._taps = 0
		M._tap_t0 = now
	end
	M._taps = M._taps + 1
	M._tap_show_until = now + 2
	if M._taps >= M.taps_needed then
		M._taps = 0
		M.uiToggle()
	end
	pcall(hud_tick)
end

function M.enableToggle()
	if M._toggle_on then return end
	M._toggle_on = true
	pcall(function()
		local listener = cc.EventListenerTouchOneByOne:create()
		listener:registerScriptHandler(function(touch, event)
			pcall(function()
				local p = touch:getLocation()
				M._onTap(p.x, p.y)
			end)
			return false
		end, cc.Handler.EVENT_TOUCH_BEGAN)
		cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listener, -1000)
	end)
end

function M.record(data)
	F.net = true
	if M.getMode() ~= "record" then return end
	local ok, err = pcall(function()
		if type(data.resouce) ~= "string" or type(data.str) ~= "string" then return end
		if is_skipped(data) then return end
		local name = cmd_name(data)
		if name == nil then return end

		local st = status_of(data.resouce)
		if st == nil or st < 0 then return end

		M._seen = M._seen or {}
		if seen_before(M._seen, name, norm_req(data.str), norm_req(data.resouce)) then return end

		local path = writable_target(M.recWriteName ~= nil and M.recWriteName() or M.rec_file)
		if path == nil then
			if not M._warned_write then
				M._warned_write = true
				notify("OfflineMock: KHÔNG ghi được file nào!\nGame chưa có quyền ghi bộ nhớ.", 10)
			end
			return
		end
		local f = io.open(path, "ab")
		if not f then return end
		local size = f:seek("end") or 0
		if size == 0 then f:write("#OFFLINE_REC v1\n") end
		if size < M.max_bytes then
			f:write(name, "\t", esc(data.str), "\t", esc(data.resouce), "\n")
			M._rec_count = (M._rec_count or 0) + 1
		end
		f:close()

		if M._rec_count == 1 then
			notify("OfflineMock đang GHI vào:\n" .. path, 10)
		elseif M._rec_count ~= nil and M._rec_count % 50 == 0 then
			notify("OfflineMock: đã ghi " .. M._rec_count .. " lệnh", 4)
		end
	end)
	if not ok then logmsg("lỗi khi ghi:", err) end
end

local function add_entry(e)
	local slot = M.db[e.c]
	if slot == nil then
		slot = { all = {}, keys = {} }
		M.db[e.c] = slot
	end
	slot.all[#slot.all + 1] = e
	local k = norm_req(e.q)
	local ks = slot.keys[k]
	if ks == nil then
		ks = { list = {}, pos = 1 }
		slot.keys[k] = ks
	end
	ks.list[#ks.list + 1] = e
	M.count = M.count + 1
end

function M.loadDb()
	if M.db ~= nil then return M.db end
	M.db = {}
	M.count = 0
	M.files = {}
	local seen = {}
	local function eat(src, where)
		M.files[#M.files + 1] = where
		if string.sub(src, -1) ~= "\n" then src = src .. "\n" end
		for line in string.gmatch(src, "([^\n]*)\n") do
			line = (string.gsub(line, "\r$", ""))
			if string.sub(line, 1, 1) ~= "#" and line ~= "" then
				local c, q, r = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)$")
				if c ~= nil then
					q, r = unesc(q), unesc(r)
					if not seen_before(seen, c, norm_req(q), norm_req(r)) then
						add_entry({ c = c, q = q, r = r })
					end
				end
			end
		end
	end
	-- ban ghi dong goi san trong src (xem M.seed_rel): nap TRUOC => ban ghi cua chinh may nay (nap sau) duoc uu tien
	-- khi phai "fallback" (lay ban ghi cuoi cung cua lenh)
	-- [REFRESH] M.recSources: neu co ban GOP ("#REFRESHED") chi dung ban do; khong thi nhu cu (ban dong goi san truoc, roi file cua may)
	local srcs = M.recSources()
	for i = 1, #srcs do
		local s, where = M.recRead(srcs[i])
		if s ~= nil then eat(s, where) end
	end
	logmsg("đã nạp", M.count, "bản ghi từ", #M.files, "file:", table.concat(M.files, " ; "))
	return M.db
end

function M.lookup(name, req)
	local db = M.loadDb()
	local slot = db[name]
	if slot == nil or #slot.all == 0 then return nil end
	local ks = slot.keys[norm_req(req)]
	if ks ~= nil then
		local e = ks.list[ks.pos]

		if ks.pos < #ks.list then ks.pos = ks.pos + 1 end
		return e.r, "exact"
	end
	return slot.all[#slot.all].r, "fallback"
end

local function missing_file_keys()
	if M._miss_file_keys ~= nil then return M._miss_file_keys end
	local keys = {}
	local ok, txt = pcall(read_first, M.miss_file)
	if ok and type(txt) == "string" then
		for line in string.gmatch(txt, "([^\n]*)\n") do
			local n, c = string.match(line, "^([^\t]+)\t([^\t]*)")
			if n ~= nil then keys[n .. "#" .. c] = true end
		end
	end
	M._miss_file_keys = keys
	return keys
end

local function no_rec_text()
	local pkg = pkg_name() or "<goi>"
	return "OFFLINE: KHÔNG tìm thấy " .. M.rec_file .. " (đã tìm: Download, Android/media/" .. pkg
		.. ", Android/data/" .. pkg .. "/files, bộ nhớ app).\nCách có bản ghi: bật mạng 1 lần -> OM -> GHI, thoát hẳn game, mở lại,"
		.. " vào game -> OM -> TU GHI (tự ghi đủ, khoảng 5 phút). Hoặc chép file vào Android/media/" .. pkg
		.. "/ rồi mở lại game."
end

local function log_missing(name, code, req)
	M._miss = M._miss or {}
	M._miss_info = M._miss_info or {}
	local key = tostring(name) .. "#" .. tostring(code)
	local info = M._miss_info[key]
	if info ~= nil then
		info.n = info.n + 1
		return
	end
	local sample = esc(string.sub(tostring(req or ""), 1, 240))
	M._miss[key] = true
	M._miss_info[key] = { name = tostring(name), code = tostring(code), n = 1, sample = sample }
	M._miss_n = (M._miss_n or 0) + 1
	local fk = missing_file_keys()
	if not fk[key] then
		fk[key] = true
		append_line(M.miss_file, tostring(name) .. "\t" .. tostring(code) .. "\t" .. sample .. "\n")
	end

	if M.max_miss_toast > 0 and M._miss_n <= M.max_miss_toast and M.count > 0 then
		notify("OfflineMock: CHƯA có dữ liệu cho lệnh \"" .. tostring(name) .. "\" -> trả rỗng (xem offline_missing.txt)", 5)
	else
		logmsg("CHƯA CÓ DỮ LIỆU cho lệnh:", name, "(code", code, ")")
	end
end

local function count_cmd(name, how)
	M._cmd_stats = M._cmd_stats or {}
	local c = M._cmd_stats[name]
	if c == nil then
		c = { ls = 0, exact = 0, fallback = 0, missing = 0, silent = 0 }
		M._cmd_stats[name] = c
	end
	c[how] = (c[how] or 0) + 1
end

local function deliver(data, res)
	data.resouce = res
	data.resouce_serializer = split_tokens(res)
	data.status = 200
	data.readyState = NetworkAdaptor.XMLHttpRequest.readyState.DONE
	data.dataState = NetworkAdaptor.dataState.DONE
	data.RESPONSE_SUCCESS = true
	NetworkAdaptor.reconnect_count = 0
	NetworkAdaptor.retry_count = 0
end

-- [ACCOUNT] Nap AccountStore (lan dau), gan ham doc/ghi file cua OfflineMock, roi xu ly lenh tai khoan.
-- Dang nhap OK  => LocalServer chuyen sang du lieu cua tai khoan do (LS.set_account).
-- Dang ky OK    => cap trang thai LS mac dinh tu seed cho tai khoan moi (LS.new_account).
function M.accountHandle(name, req, seq)
	if M._acct_mod == nil then
		local ok, mod = pcall(require, M.account_module)
		if not ok or type(mod) ~= "table" then
			M._acct_mod = false
			logmsg("không nạp được AccountStore:", tostring(mod))
			return nil
		end
		mod.attach({ read_first = function(n) local s = read_first(n); return s end, write_first = write_first, append_line = append_line })
		M._acct_mod = mod
		logmsg("đã nạp AccountStore", tostring(mod.VERSION))
	end
	if M._acct_mod == false then return nil end
	return M._acct_mod.handle(name, req, seq,
		function(entry)
			M.current_account, M.current_uid = entry.name, entry.uid
			local LS = M.LS
			if LS ~= nil and LS.set_account ~= nil then
				local okL, errL = pcall(LS.set_account, entry.name, entry.uid)
				if not okL then logmsg("LS.set_account lỗi:", tostring(errL)) end
			end
		end,
		function(entry)
			local LS = M.LS
			if LS ~= nil and LS.new_account ~= nil then
				local okL, errL = pcall(LS.new_account, entry.name, entry.uid)
				if not okL then logmsg("LS.new_account lỗi:", tostring(errL)) end
			end
		end)
end

function M._replay(data)
	if data.str == nil then

		data.str = NetworkProtocol.command_func(data.command, data.data)
	end
	local req = data.str
	local name = cmd_name(data)
	if name == nil then
		data.dataState = NetworkAdaptor.dataState.ERROR
		data.error_code = -9
		data.error_string = "OfflineMock: không xác định được lệnh " .. tostring(data.command)
		return true
	end

	local seq = string.match(tostring(req), "^%s*(%d+)") or "0"
	local res, how = nil, nil

	-- [ACCOUNT] dang ky / dang nhap: kiem tra voi file tai khoan, KHONG phat lai ban ghi (neu khong ai go gi cung vao duoc)
	if M.use_accounts and (name == "platform_user_register" or name == "platform_user_login") then
		local okA, ra = pcall(M.accountHandle, name, req, seq)
		if okA and type(ra) == "string" and ra ~= "" then
			count_cmd(name, "ls")
			pcall(M.noteCmd, name, "ls", ra)
			deliver(data, ra)
			return true
		elseif not okA then
			logmsg("lỗi AccountStore:", tostring(ra))
		end
	end

	if ls_active() then
		local okls, r = pcall(M.LS.respond, name, req, seq)
		if okls and type(r) == "string" and r ~= "" then
			res, how = r, "ls"
		elseif not okls then
			logmsg("lỗi LocalServer.respond:", tostring(r))
		end
	end
	if res == nil then res, how = M.lookup(name, req) end
	local silent = (res == nil and M.silent_cmds ~= nil and M.silent_cmds[name] == true)

	local blocked = (res == nil and not silent and M.isFightCmd(name) == true)
	count_cmd(name, silent and "silent" or (res == nil and "missing" or how))
	if not M._replay_announced then
		M._replay_announced = true
		if M.count == 0 then
			notify(no_rec_text(), 15)
		else
			notify("Server test by Bò Fake", 5)
		end
	end

	local rname = (string.gsub(name, "%s+$", ""))
	if silent then

		res = seq .. "\r\n" .. rname .. "\r\n0"
		how = "silent"
	elseif res == nil then
		log_missing(name, data.command, req)
		how = "missing"
		if blocked then

			how = "blocked"
			res = seq .. "\r\n" .. rname .. "\r\n-1\r\nOffline:_che_do_danh_nay_chua_ho_tro:_" .. tostring(rname)
			notify("OFFLINE: chế độ đánh này (" .. tostring(rname) .. ") CHƯA hỗ trợ offline.", 6)
		elseif M.lenient then
			res = seq .. "\r\n" .. rname .. "\r\n0"
			if M.reward_claim_cmds[rname] == true then
				notify("OFFLINE: lệnh nhận thưởng \"" .. tostring(rname) .. "\" chưa có dữ liệu thưởng, KHÔNG được cộng vật phẩm.", 6)
			end
		else

			res = seq .. "\r\n" .. rname .. "\r\n-1\r\nOffline:_chua_co_du_lieu_cho_lenh_" .. tostring(rname)
		end
	elseif how ~= "ls" then

		res = (string.gsub(res, "^%d+", seq, 1))
	end
	pcall(M.noteCmd, rname, how, res)
	deliver(data, res)
	return true
end

M.reward_claim_cmds = {
	["activity_draw_red_packet"]=true, ["activity_fortune_cat_draw"]=true, ["activity_orders_world_get_reward"]=true, ["activity_pockmon_rescue_draw_ultimate_reward"]=true,
	["activity_pokemon_master_exchage_reward"]=true, ["activity_pokemon_master_get_reward"]=true, ["arena_reward_draw"]=true, ["biographies_draw"]=true,
	["biographies_get_extra_reward"]=true, ["build_patrol_draw"]=true, ["celebration_order_get_day_reward"]=true, ["celebration_order_get_order_reward"]=true,
	["combine_ship_prop_receive"]=true, ["cross_arena_choose_reward"]=true, ["cross_time_limit_jackpot_draw"]=true, ["cross_time_limit_jackpot_get_task_reward"]=true,
	["draw_achievement_reward"]=true, ["draw_activity_reward"]=true, ["draw_answer_reward"]=true, ["draw_arena_lucky"]=true,
	["draw_arena_lucky_reward"]=true, ["draw_arena_order_reward"]=true, ["draw_arena_score_reward"]=true, ["draw_attachment_in_mail"]=true,
	["draw_black_shop_reward"]=true, ["draw_bounty_limit"]=true, ["draw_bounty_limit_reward"]=true, ["draw_cdkey_reward"]=true,
	["draw_divine_reward"]=true, ["draw_duel_order_reward"]=true, ["draw_endurance"]=true, ["draw_equipment_limit"]=true,
	["draw_expedition_reward"]=true, ["draw_fb_reward"]=true, ["draw_first_join_union_reward"]=true, ["draw_first_top_up_reward"]=true,
	["draw_google_bind_reward"]=true, ["draw_hold_integral_reward"]=true, ["draw_matrix_reward"]=true, ["draw_month_card_reward"]=true,
	["draw_month_sign_reward"]=true, ["draw_month_week_reward"]=true, ["draw_morrow_reward"]=true, ["draw_on_hook_reward"]=true,
	["draw_online_reward"]=true, ["draw_rebel_week_reward"]=true, ["draw_reward_center"]=true, ["draw_reward_main"]=true,
	["draw_scene_npc_rewad"]=true, ["draw_scene_rewad"]=true, ["draw_server_fund"]=true, ["draw_share_reward"]=true,
	["draw_union_active_share"]=true, ["draw_union_campsite_reward"]=true, ["draw_union_copy_reward"]=true, ["draw_union_liveness_reward"]=true,
	["draw_union_scene_reward"]=true, ["draw_union_stronghold_reward"]=true, ["draw_vip_every_day_reward"]=true, ["draw_warfare_order_reward"]=true,
	["draw_warfare_task_reward"]=true, ["draw_week_reward"]=true, ["draw_win_count_reward"]=true, ["draw_world_boss_reward"]=true,
	["egg_frenzy_draw"]=true, ["egg_frenzy_get_reward"]=true, ["facebook_get_reward"]=true, ["file_island_friend_task_reward"]=true,
	["first_charge_receive_reward"]=true, ["get_activity_reward"]=true, ["get_task_reward"]=true, ["half_the_ritual_get_reward"]=true,
	["jump_page_get_reward"]=true, ["limit_blessing_draw"]=true, ["limit_blessing_get_blessing_reward"]=true, ["limit_blessing_get_spree_reward"]=true,
	["limit_blessing_get_task_reward"]=true, ["limited_recharge_get_reward"]=true, ["lucky_match_draw"]=true, ["lucky_match_get_reward"]=true,
	["lucky_turntable_draw"]=true, ["magical_animals_activate_get_fate_task_reward"]=true, ["manor_double_reward"]=true, ["manor_reward"]=true,
	["mineral_reward_gain"]=true, ["mineral_reward_gain_all"]=true, ["monopoly_change_achieve_reward"]=true, ["monopoly_get_achieve_reward"]=true,
	["monopoly_get_task_reward"]=true, ["monthly_card_receive_reward"]=true, ["mysterious_egg_receive_reward"]=true, ["normal_war_order_get_reward"]=true,
	["old_user_back_recharge_get_reward"]=true, ["old_user_back_reward_happy_n_day"]=true, ["old_user_back_seven_day_get_reward"]=true, ["one_key_draw_attachment_in_mail"]=true,
	["one_key_draw_reward"]=true, ["one_key_draw_scene_reward"]=true, ["one_key_draw_union_copy_draw_reward"]=true, ["partner_bounty_get_reward"]=true,
	["pet_counterpart_get_reward"]=true, ["pokemon_explore_score_reward"]=true, ["present_endurance"]=true, ["private_custom_reward_get"]=true,
	["privilege_card_get_reward"]=true, ["reward_grow_by_level"]=true, ["reward_happy_n_day"]=true, ["secret_travel_draw"]=true,
	["secret_travel_get_reward"]=true, ["seven_day_recharge_get_reward"]=true, ["share_reward"]=true, ["stride_dial_reward"]=true,
	["study_event_reward"]=true, ["summer_cool_weal_get_reward"]=true, ["three_kingdoms_draw_score_reward"]=true, ["time_limit_jackpot_draw"]=true,
	["time_limit_jackpot_get_task_reward"]=true, ["time_limit_lottery_draw"]=true, ["treasures_draw"]=true, ["union_battleground_reward"]=true,
	["union_copy_draw_npc_reward"]=true, ["union_red_packet_draw_reward"]=true, ["union_ship_slot_machine_draw_reward"]=true, ["union_stick_crazy_adventure_draw_reward"]=true,
	["union_welfare_distribute"]=true, ["user_build_war_order_get_reward"]=true, ["user_sweep_rewards"]=true, ["view_draw_items"]=true,
	["view_world_boss_reward"]=true, ["warcraft_get_reward"]=true, ["world_boss_draw_task_reward"]=true, ["world_city_bonus_draw"]=true,
}

function M.isFightCmd(name)
	if not M.fight_block then return false end
	local list = M.fight_cmds
	if type(list) ~= "table" then return false end
	if M._fight_src ~= list then
		local set = {}
		for k, v in pairs(list) do
			if type(v) == "string" then
				set[v] = true
			elseif v == true and type(k) == "string" then
				set[k] = true
			end
		end
		M._fight_src, M._fight_set = list, set
	end
	local nm = (string.gsub(tostring(name), "%s+$", ""))
	return M._fight_set[nm] == true
end

function M.logLuaError(msg, tb_given)
	M._err_n = (M._err_n or 0) + 1
	local text = tostring(msg)
	local key = string.sub(text, 1, 200)
	M._errs = M._errs or {}

	local short = M.shortErr(text)
	M._last_err = { short = short, t = os.time() }
	if M.unstick and M._unstick_at == nil then M._unstick_at = os.time() + (tonumber(M.unstick_delay) or 3) end
	local e = M._errs[key]
	if e ~= nil then
		e.n = e.n + 1
		return
	end
	M._err_u = (M._err_u or 0) + 1
	M._errs[key] = { n = 1 }
	if M._err_u > M.max_err_log then return end
	local tb = ""
	local dbg = rawget(_G, "debug")
	if type(tb_given) == "string" then
		tb = tb_given
	elseif type(dbg) == "table" and dbg.traceback ~= nil then
		local okt, t = pcall(dbg.traceback, "", 2)
		if okt and type(t) == "string" then

			local lines, n = {}, 0
			for ln in string.gmatch(t, "[^\n]+") do
				if not string.find(ln, "OfflineMock", 1, true) and not string.find(ln, "'pcall'", 1, true)
					and not string.find(ln, "stack traceback", 1, true) then
					n = n + 1
					if n > 10 then break end
					lines[#lines + 1] = (string.gsub(ln, "^%s+", ""))
				end
			end
			tb = table.concat(lines, " <- ")
		end
	end
	append_line(M.err_file, os.date("%H:%M:%S") .. "\t" .. esc(string.sub(text, 1, 300)) .. "\t" .. esc(string.sub(tb, 1, 900)) .. "\n")

	if M._err_u <= (tonumber(M.max_err_toast) or 2) then
		notify("OfflineMock: LỖI LUA - " .. short .. "\n(chi tiết trong " .. M.err_file .. ")", 6)
	end
end

-- [FIX-DUNG-GAME] display.lua (sp.spine) goi ham nay khi file spine THIEU/HONG va da duoc
-- thay bang hieu ung gia. Ghi 1 dong cho moi duong dan vao offline_errors.txt va bao
-- LocalServer (neu co LS.on_bad_spine) de lan sau loc bo tuong dung hieu ung nay.
function M.noteBadSpine(json, atlas, why)
	local key = tostring(json) .. "|" .. tostring(atlas)
	M._bad_spine = M._bad_spine or {}
	if M._bad_spine[key] then return end
	M._bad_spine[key] = true
	M._bad_spine_n = (M._bad_spine_n or 0) + 1
	if M._bad_spine_n <= (tonumber(M.max_err_log) or 60) then
		pcall(append_line, M.err_file, os.date("%H:%M:%S") .. "\tSPINE thieu/hong -> dung hieu ung gia\t"
			.. esc(string.sub(key, 1, 200)) .. "\t" .. esc(string.sub(tostring(why), 1, 200)) .. "\n")
	end
	local ls = M.LS
	if type(ls) == "table" and type(ls.on_bad_spine) == "function" then
		pcall(ls.on_bad_spine, json, atlas, why)
	end
end

function M.shortErr(text)
	local s = tostring(text or "")
	s = string.match(s, "^[^\r\n]*") or s
	s = (string.gsub(s, "[%w_%.%-/]*/([%w_%.%-]+%.lua)", "%1"))
	if string.len(s) > 110 then s = string.sub(s, 1, 107) .. "..." end
	return s
end

function M.hookLuaErrors()
	if M._tb_hooked or not M.hook_lua_errors then return false end
	local orig = rawget(_G, "__G__TRACKBACK__")
	if type(orig) ~= "function" then return false end
	M._tb_hooked = true
	M._tb_orig = orig
	rawset(_G, "__G__TRACKBACK__", function(msg)
		pcall(M.logLuaError, msg)
		print("[OfflineMock] LUA ERROR: " .. tostring(msg))
		return msg
	end)
	return true
end

M.ring_size = 40
local HOW_SHORT = { ls = "ls", exact = "ghi", fallback = "ghi~", missing = "THIEU", silent = "nen", blocked = "CHAN", parser = "PARSER" }

function M.noteCmd(name, how, res)
	local text = tostring(res or "")
	local st = tonumber(string.match(text, "^[^\r\n]*\r\n[^\r\n]*\r\n(%-?%d+)"))
	local msg = nil
	if st ~= nil and st < 0 then
		msg = string.match(text, "^[^\r\n]*\r\n[^\r\n]*\r\n%-?%d+\r\n([^\r\n]*)")
		if msg ~= nil and string.len(msg) > 60 then msg = string.sub(msg, 1, 60) end
	end
	local ent = { name = tostring(name), how = how, st = st, msg = msg, t = os.time() }
	local ring = M._ring
	if ring == nil then
		ring = {}
		M._ring = ring
		M._ring_i = 0
	end
	local n = tonumber(M.ring_size) or 40
	M._ring_i = (M._ring_i % n) + 1
	ring[M._ring_i] = ent
	if how ~= "silent" then M._last_cmd = ent end
	if how == "missing" or how == "blocked" or how == "parser" or (st ~= nil and st < 0) then
		M._last_bad = ent
		M._bad_n = (M._bad_n or 0) + 1
	end
	return ent
end

local function cmd_diag(label, c)
	local s = label .. " " .. c.name .. " " .. (HOW_SHORT[c.how] or tostring(c.how)) .. "/" .. tostring(c.st)
	if c.msg ~= nil and c.msg ~= "" then s = s .. " " .. c.msg end
	return s
end

function M.diagText()
	if not M.diag_hud then return nil end
	local now = os.time()
	local D = M.diag_secs or {}
	local parts = {}
	local lc, lb, le = M._last_cmd, M._last_bad, M._last_err
	if lc ~= nil and now - lc.t <= (D.cmd or 45) then parts[#parts + 1] = cmd_diag("LC", lc) end
	if lb ~= nil and lb ~= lc and now - lb.t <= (D.bad or 90) then parts[#parts + 1] = cmd_diag("BAD", lb) end
	if le ~= nil and now - le.t <= (D.err or 120) then parts[#parts + 1] = "LUA " .. le.short end
	local us = M._unstuck
	if us ~= nil and now - us.t <= (D.unstick or 30) then parts[#parts + 1] = "GO KET " .. us.n .. " nut" end
	do
		local fg = M.FG
		if fg ~= nil and fg.last_act_t ~= nil and now - fg.last_act_t <= (D.unstick or 30) then
			parts[#parts + 1] = "FG: " .. tostring(fg.last_act)
		end
	end
	if ls_active() and type(M.LS.last_fail_text) == "function" then
		local okf, ft = pcall(M.LS.last_fail_text)
		if okf and type(ft) == "string" and ft ~= "" then
			local seen = M._ls_fail_seen
			if seen == nil or seen.text ~= ft then
				seen = { text = ft, t = now }
				M._ls_fail_seen = seen
			end
			if now - seen.t <= (D.bad or 90) then parts[#parts + 1] = ft end
		end
	end
	if #parts == 0 then return nil end
	return table.concat(parts, " | ")
end

function M.hookLocks()
	local sm = rawget(_G, "state_machine")
	if type(sm) ~= "table" or type(sm._lock) ~= "function" or type(sm._unlock) ~= "function" then return false end
	if sm._lock == M._lock_w and sm._unlock == M._unlock_w then return true end
	if (M._lock_hooks or 0) >= M.max_reattach then return false end
	M._lock_hooks = (M._lock_hooks or 0) + 1
	local times = M._lock_times
	if times == nil then
		times = setmetatable({}, { __mode = "k" })
		M._lock_times = times
	end
	local o_lock, o_unlock = sm._lock, sm._unlock
	local function w_lock(t, ...)
		if type(t) == "table" and rawget(t, "_lock") ~= true then times[t] = os.time() end
		return o_lock(t, ...)
	end
	local function w_unlock(t, ...)
		if type(t) == "table" then times[t] = nil end
		return o_unlock(t, ...)
	end
	sm._lock, sm._unlock = w_lock, w_unlock
	M._lock_w, M._unlock_w = w_lock, w_unlock
	return true
end

function M.unstickLocks(min_age)
	local times = M._lock_times
	if times == nil then return 0 end
	local now = os.time()
	local n, names = 0, {}
	for t, ts in pairs(times) do
		if type(t) == "table" then
			if rawget(t, "_lock") ~= true then
				times[t] = nil
			elseif now - ts >= (tonumber(min_age) or 0) then
				rawset(t, "_lock", false)
				times[t] = nil
				n = n + 1
				if #names < 12 then names[#names + 1] = tostring(rawget(t, "_name")) end
			end
		else
			times[t] = nil
		end
	end
	if n > 0 then
		M._unstuck_total = (M._unstuck_total or 0) + n
		M._unstuck = { n = n, t = now, names = names }
		logmsg("OfflineMock: đã mở lại", n, "nút bị khoá sau lỗi Lua:", table.concat(names, ","))
		append_line(M.err_file, os.date("%H:%M:%S") .. "\tGO KET " .. n .. " nut bi khoa\t" .. esc(table.concat(names, ",")) .. "\n")
	end
	return n
end

function M.unstickTick()
	if not M.unstick or M.getMode() ~= "replay" then return end
	M.hookLocks()
	local at = M._unstick_at
	if at ~= nil and os.time() >= at then
		M._unstick_at = nil
		M.unstickLocks(tonumber(M.unstick_delay) or 3)
	end
end

function M.guardParser()
	if not M.guard_parser then return false end
	local NP = rawget(_G, "NetworkProtocol")
	if type(NP) ~= "table" or type(NP.parser_func) ~= "function" then return false end
	if M._pg_w ~= nil and NP.parser_func == M._pg_w then return true end
	if (M._pg_n or 0) >= M.max_reattach then return false end
	M._pg_n = (M._pg_n or 0) + 1
	local orig = NP.parser_func
	local function handler(e)
		local dbg = rawget(_G, "debug")
		local tb = ""
		if type(dbg) == "table" and dbg.traceback ~= nil then tb = tostring(dbg.traceback("", 2)) end
		return { msg = tostring(e), tb = tb }
	end
	local function wrapper(data, ...)
		if type(data) ~= "table" or data.command == nil then return orig(data, ...) end
		local ok, err = xpcall(function() return orig(data) end, handler)
		if not ok then pcall(M.onParserError, data, err) end
	end
	M._pg_w = wrapper
	NP.parser_func = wrapper
	return true
end

function M.onParserError(data, err)
	data.RESPONSE_SUCCESS = false
	local st = tonumber(data.PROTOCOL_STATUS)
	if st == nil or st >= 0 then data.PROTOCOL_STATUS = -1 end
	M._parse_fail = (M._parse_fail or 0) + 1
	local msg, tb = tostring(err), ""
	if type(err) == "table" then msg, tb = tostring(err.msg), tostring(err.tb or "") end
	local name = cmd_name(data) or tostring(data.command)
	local lines, n = {}, 0
	for ln in string.gmatch(tb, "[^\n]+") do
		if not string.find(ln, "OfflineMock", 1, true) and not string.find(ln, "'pcall'", 1, true)
			and not string.find(ln, "stack traceback", 1, true) then
			n = n + 1
			if n > 10 then break end
			lines[#lines + 1] = (string.gsub(ln, "^%s+", ""))
		end
	end
	pcall(M.noteCmd, name, "parser", "0\r\n" .. tostring(name) .. "\r\n-1\r\nPARSER_LOI")
	M.logLuaError("PARSER " .. tostring(name) .. ": " .. msg, table.concat(lines, " <- "))
end

function M.intercept(data)
	F.net = true
	if M.getMode() ~= "replay" then return false end
	local ok, handled = pcall(M._replay, data)
	if not ok then
		logmsg("lỗi replay:", handled)
		data.dataState = NetworkAdaptor.dataState.ERROR
		data.error_code = -9
		data.error_string = "OfflineMock: " .. tostring(handled)
		return true
	end
	return handled
end

function M.loadLS()
	if M._ls_tried then return M.LS end
	M._ls_tried = true
	if not M.use_ls then return nil end
	local ok, mod = pcall(require, M.ls_module)
	if ok and type(mod) == "table" and type(mod.respond) == "function" then
		M.LS = mod
		logmsg("đã nạp LocalServer", tostring(mod.VERSION))
	else
		M._ls_err = tostring(mod)
		if string.len(M._ls_err) > 90 then M._ls_err = string.sub(M._ls_err, 1, 90) end
		logmsg("không nạp được LocalServer (chạy như v4):", tostring(mod))
	end
	return M.LS
end

-- [v5] FightGuard: nap module + lap lich 0.5 s (dt = game-time cua scheduler). Loi nap/chay KHONG anh huong game.
-- [v6.28] FightGuard recibe de OfflineMock sus "manos": escribir el log, avisar en pantalla, contar errores Lua.
local function fg_host(mod)
	mod.host = {
		append = append_line,
		notify = notify,
		err_count = function() return M._err_n or 0 end,
		last_err = function()
			local e = M._last_err
			if e ~= nil then return e.short end
			return nil
		end,
	}
end

-- Si el modulo fue vaciado (app.unload lo deja sin funciones; app.lua ya lo excluye, esto es una red extra) => recargarlo.
local function fg_alive()
	local mod = M.FG
	if type(mod) == "table" and type(mod.tick) == "function" then return mod end
	if (M._fg_revived or 0) >= 5 then return nil end
	M._fg_revived = (M._fg_revived or 0) + 1
	package.loaded[M.fg_module] = nil
	local ok, m2 = pcall(require, M.fg_module)
	if ok and type(m2) == "table" and type(m2.tick) == "function" then
		M.FG = m2
		fg_host(m2)
		logmsg("FightGuard: đã nạp lại (bị xoá rỗng)", tostring(m2.version))
		return m2
	end
	return nil
end

function M.fgStart()
	if M._fg_started or not M.fight_guard then return M.FG end
	M._fg_started = true
	local ok, mod = pcall(require, M.fg_module)
	if not ok or type(mod) ~= "table" or type(mod.tick) ~= "function" then
		M._fg_err = tostring(mod)
		logmsg("không nạp được FightGuard:", M._fg_err)
		return nil
	end
	M.FG = mod
	fg_host(mod)
	schedule(0.5, function(dt)
		local cur = fg_alive()
		if cur ~= nil then pcall(cur.tick, dt) end
		return false
	end)
	logmsg("đã bật FightGuard", tostring(mod.version))
	return mod
end

-- ------------------------------------------------------------------------------------------ [v6.31] Fusion (hop the 3 tuong)
-- Chon 3 tuong trong bang GM (nut HOP THE); vao tran 3 tuong gop thanh 1 chien binh. Chi OFFLINE. Xem client/offline/Fusion.lua.
-- Loi nap/chay Fusion KHONG anh huong game (moi cho deu bao pcall; engine bi loi => tran danh nhu binh thuong).
local function fu_host(mod)
	mod.host = {
		notify = notify,
		scene = running_scene,
		size = visible_size,
		schedule = schedule,
		log = logmsg,
		z = 1000011, -- tren bang GM (Z_GM = 1000001)
	}
end

function M.fuStart()
	if M._fu_started or not M.fusion then return M.FU end
	M._fu_started = true
	local ok, mod = pcall(require, M.fu_module)
	if not ok or type(mod) ~= "table" or type(mod.start) ~= "function" then
		M._fu_err = tostring(mod)
		if string.len(M._fu_err) > 90 then M._fu_err = string.sub(M._fu_err, 1, 90) end
		logmsg("không nạp được Fusion:", tostring(mod))
		return nil
	end
	M.FU = mod
	fu_host(mod)
	local oks, errs = pcall(mod.start)
	if not oks then
		M._fu_err = "start: " .. tostring(errs)
		logmsg("Fusion start lỗi:", M._fu_err)
	end
	logmsg("đã bật Fusion", tostring(mod.version))
	return mod
end

-- ------------------------------------------------------------------------------------------ [v6] BlackBox (hop den)
-- Dang tran? (cua so dieu khien con chay). Dung de hoan viec nang (quet du lieu) khi dang danh.
function M.inFight()
	local fw = rawget(_G, "fwin")
	if type(fw) ~= "table" or type(fw.find) ~= "function" then return false end
	local ok, ctl = pcall(fw.find, fw, "FightRoleControllerClass")
	return ok and type(ctl) == "table" and ctl.current_fight_over == false
end

-- Dau van tay ban dang chay (ghi o dong BOOT cua offline_blackbox.txt): phien ban cac module + file da va (ZZ_PATCH)
function M.bbFingerprint()
	local t = { "om=" .. tostring(M.version) }
	if type(M.LS) == "table" then t[#t + 1] = "ls=" .. tostring(M.LS.VERSION) end
	if type(M.FG) == "table" then t[#t + 1] = "fg=" .. tostring(M.FG.version) end
	if type(M.FU) == "table" then t[#t + 1] = "fu=" .. tostring(M.FU.version) end
	t[#t + 1] = "mode=" .. tostring(M.mode)
	local pt = rawget(_G, "ZZ_PATCH")
	if type(pt) == "table" then
		local keys = {}
		for k in pairs(pt) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		local ps = {}
		for i = 1, #keys do ps[i] = keys[i] .. ":" .. tostring(pt[keys[i]]) end
		t[#t + 1] = "patch=" .. table.concat(ps, ",")
	else
		t[#t + 1] = "patch=none"
	end
	return table.concat(t, "\t")
end

function M.bbHost(mod)
	mod.host = {
		append = append_line,
		write = write_first,
		read = function(name)
			local s = read_first(name)
			return s
		end,
		notify = notify,
		err_count = function() return M._err_n or 0 end,
		last_cmd = function()
			local c = M._last_cmd
			if type(c) ~= "table" then return nil end
			return tostring(c.name) .. ":" .. tostring(c.how) .. "/" .. tostring(os.time() - (tonumber(c.t) or os.time())) .. "s"
		end,
		fingerprint = function() return M.bbFingerprint() end,
	}
end

-- Neu module bi vac rong (app.unload) => nap lai. KHONG chay lai start() (phien van la phien nay).
function M.bbAlive()
	local mod = M.BB
	if type(mod) == "table" and type(mod.tick) == "function" then return mod end
	if (M._bb_revived or 0) >= 5 then return nil end
	M._bb_revived = (M._bb_revived or 0) + 1
	package.loaded[M.bb_module] = nil
	local ok, m2 = pcall(require, M.bb_module)
	if ok and type(m2) == "table" and type(m2.tick) == "function" then
		M.BB = m2
		M.bbHost(m2)
		m2.started = true
		logmsg("BlackBox: đã nạp lại (bị xoá rỗng)", tostring(m2.version))
		return m2
	end
	return nil
end

function M.bbStart()
	if M._bb_started or not M.blackbox then return M.BB end
	M._bb_started = true
	local ok, mod = pcall(require, M.bb_module)
	if not ok or type(mod) ~= "table" or type(mod.tick) ~= "function" then
		M._bb_err = tostring(mod)
		logmsg("không nạp được BlackBox:", M._bb_err)
		return nil
	end
	M.BB = mod
	M.bbHost(mod)
	local oks, errs = pcall(mod.start)
	if not oks then
		M._bb_err = "start: " .. tostring(errs)
		logmsg("BlackBox start lỗi:", M._bb_err)
	end
	schedule(1.0, function(dt)
		local cur = M.bbAlive()
		if cur ~= nil then pcall(cur.tick, dt) end
		return false
	end)
	-- xuong nen / ve lai + os.exit => dau moc de lan sau biet day KHONG phai "chet dot ngot"
	pcall(function()
		local disp = cc.Director:getInstance():getEventDispatcher()
		local bg = cc.EventListenerCustom:create(cc.EVENT_COME_TO_BACKGROUND or "event_come_to_background", function()
			local b = M.bbAlive()
			if b ~= nil then pcall(b.on_bg) end
		end)
		disp:addEventListenerWithFixedPriority(bg, 1)
		local fg = cc.EventListenerCustom:create(cc.EVENT_COME_TO_FOREGROUND or "event_come_to_foreground", function()
			local b = M.bbAlive()
			if b ~= nil then pcall(b.on_fg) end
		end)
		disp:addEventListenerWithFixedPriority(fg, 1)
	end)
	pcall(function()
		if M._exit_wrapped or type(os.exit) ~= "function" then return end
		M._exit_wrapped = true
		local o_exit = os.exit
		os.exit = function(...)
			local b = M.BB
			if type(b) == "table" and type(b.mark_end) == "function" then pcall(b.mark_end, "os.exit") end
			return o_exit(...)
		end
	end)
	logmsg("đã bật BlackBox", tostring(mod.version))
	return mod
end

-- Thay cho collectgarbage("stop") o dau tran (FightLoading): don rac day du 1 lan roi moi dung GC.
function M.bbGcStop()
	local b = M.BB
	if type(b) ~= "table" or type(b.gc_stop) ~= "function" then
		pcall(collectgarbage, "collect")
		collectgarbage("stop")
		return true
	end
	local ok = pcall(b.gc_stop)
	if not ok then collectgarbage("stop") end
	return true
end

-- Dau moc truoc/sau khi tao spine LAN DAU (display.lua). Neu game chet giua chung thi lan sau biet file nao.
function M.bbSpBegin(json, atlas)
	local b = M.BB
	if type(b) == "table" and type(b.sp_begin) == "function" then b.sp_begin(json, atlas) end
end

function M.bbSpDone(json, atlas, ok)
	local b = M.BB
	if type(b) == "table" and type(b.sp_done) == "function" then b.sp_done(json, atlas, ok) end
end

function M.bbEvent(tag, text)
	local b = M.BB
	if type(b) == "table" and type(b.event) == "function" then b.event(tag, text) end
end

function M.extraDump()
	local out = {}
	out[#out + 1] = "[OfflineMock] version=" .. M.version .. " mode=" .. tostring(M.mode) .. " records=" .. tostring(M.count or 0)
	out[#out + 1] = "[OfflineMock] files=" .. table.concat(M.files or {}, " ; ")
	do
		local st = M.auto
		if st == nil then
			out[#out + 1] = "[auto record] chua chay"
		else
			out[#out + 1] = "[auto record] running=" .. tostring(st.running) .. " reason=" .. tostring(st.reason)
				.. " procesados=" .. st.processed .. "/" .. #st.items .. " ok=" .. st.ok .. " rechazados=" .. st.err
				.. " red=" .. st.fail .. " omitidos=" .. st.skip .. " error_parser=" .. st.parse_err
		end
	end
	local f = {}
	for k, v in pairs(M.gm.floors) do f[#f + 1] = k .. "=" .. fmt_int(v) end
	table.sort(f)
	out[#out + 1] = "[GM floors] on=" .. tostring(M.gm.on) .. " " .. table.concat(f, " ")
	local names = {}
	for k in pairs(M._cmd_stats or {}) do names[#names + 1] = k end
	table.sort(names)
	out[#out + 1] = "[commands this session] name ls/exact/fallback/missing[/silent]"
	for _, k in ipairs(names) do
		local c = M._cmd_stats[k]
		out[#out + 1] = "  " .. k .. " " .. c.ls .. "/" .. c.exact .. "/" .. c.fallback .. "/" .. c.missing
			.. ((c.silent or 0) > 0 and ("/" .. c.silent) or "")
	end
	local rec = {}
	for name, slot in pairs(M.db or {}) do rec[#rec + 1] = { name = name, n = #slot.all } end
	table.sort(rec, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return a.name < b.name
	end)
	local parts = {}
	for i = 1, math.min(#rec, 400) do parts[#parts + 1] = rec[i].name .. "(" .. rec[i].n .. ")" end
	out[#out + 1] = "[recorded commands] " .. table.concat(parts, " ")

	local miss = {}
	for _, info in pairs(M._miss_info or {}) do miss[#miss + 1] = info end
	table.sort(miss, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return a.name < b.name
	end)
	out[#out + 1] = "[missing commands this session] " .. #miss .. "  (name code count sample)"
	for i = 1, math.min(#miss, 200) do
		local m = miss[i]
		out[#out + 1] = "  " .. m.name .. " " .. m.code .. " x" .. m.n .. "  " .. string.sub(m.sample, 1, 160)
	end
	local errs = {}
	for key, e in pairs(M._errs or {}) do errs[#errs + 1] = { key = key, n = e.n } end
	table.sort(errs, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return a.key < b.key
	end)
	out[#out + 1] = "[lua errors this session] " .. tostring(M._err_n or 0) .. " total, " .. #errs .. " distintos"
	for i = 1, math.min(#errs, 40) do
		out[#out + 1] = "  x" .. errs[i].n .. "  " .. string.sub(errs[i].key, 1, 200)
	end

	if M.FG ~= nil and type(M.FG.summary) == "function" then
		local okf, fs = pcall(M.FG.summary)
		out[#out + 1] = "[v5 fightguard] " .. tostring(okf and fs or "loi") .. " | lan cuoi: " .. tostring(M.FG.last_act or "-")
			.. " | log: offline_fightguard.txt"
	elseif M._fg_err ~= nil then
		out[#out + 1] = "[v5 fightguard] KHONG NAP DUOC: " .. tostring(M._fg_err)
	end
	if M.BB ~= nil and type(M.BB.summary) == "function" then
		local okb, bs = pcall(M.BB.summary)
		out[#out + 1] = "[v6 blackbox] " .. tostring(okb and bs or "loi") .. " | log: offline_blackbox.txt, offline_crash_reports.txt"
	elseif M._bb_err ~= nil then
		out[#out + 1] = "[v6 blackbox] KHONG NAP DUOC: " .. tostring(M._bb_err)
	end
	out[#out + 1] = "[v6.9 diag] bad_cmds=" .. tostring(M._bad_n or 0) .. " parser_fail=" .. tostring(M._parse_fail or 0)
		.. " unstuck_total=" .. tostring(M._unstuck_total or 0) .. " guard_parser=" .. tostring(M._pg_w ~= nil)
		.. " locks_hooked=" .. tostring(M._lock_w ~= nil) .. " fight_block=" .. tostring(M.fight_block == true)
	if M._unstuck ~= nil then
		out[#out + 1] = "[v6.9 diag] lan go ket cuoi: " .. tostring(M._unstuck.n) .. " nut: " .. table.concat(M._unstuck.names or {}, ",")
	end
	out[#out + 1] = "[v6.22 push] record mac dinh: tu tao " .. tostring(M._push_lazy or 0) .. " | bo sung o thieu " .. tostring(M._push_fill or 0)
		.. " | gan metatable " .. tostring(M._push_mt_n or 0) .. " lan"
	out[#out + 1] = "[v6.22 guard] cham do: da boc " .. tostring(M._rd_count or 0) .. " ham | nuot loi " .. tostring(M._rd_swallowed or 0)
		.. " lan | tim thay o: " .. tostring(M._rd_where or "CHUA TIM THAY")
	do
		local ring, n = M._ring, tonumber(M.ring_size) or 40
		local list = {}
		if ring ~= nil then
			for k = 1, n do
				local ent = ring[((M._ring_i or 0) + k - 1) % n + 1]
				if ent ~= nil then list[#list + 1] = ent end
			end
		end
		out[#out + 1] = "[recent commands] " .. #list .. " gan nhat (cu -> moi): ten how/status [loi]"
		for _, ent in ipairs(list) do
			out[#out + 1] = "  " .. ent.name .. " " .. tostring(ent.how) .. "/" .. tostring(ent.st)
				.. ((ent.msg ~= nil and ent.msg ~= "") and (" " .. ent.msg) or "")
		end
	end
	return table.concat(out, "\n")
end

function M.lsHost()
	return {
		logmsg = function(...) logmsg(...) end,
		notify = function(text, secs) notify(text, secs) end,
		read_first = function(name)
			local s = read_first(name)
			return s
		end,
		write_first = write_first,
		append_line = append_line,
		-- [LIEN SERVER] LocalServer doc ban ghi that (vd. bang xep hang cross_arena_init)
		lookup = function(name, req) return M.lookup(name, req) end,
		-- [v6] LocalServer ghi moc SIM+/SIM- (mo phong tran) vao hop den
		bb_event = function(tag, text) M.bbEvent(tag, text) end,

		initial_money = function(kind, recorded)
			local fl = M.gm.floors[kind]
			if fl ~= nil and fl > recorded then return fl end
			return recorded
		end,
		extra_dump = M.extraDump,
	}
end

function M.startLS()
	local LS = M.loadLS()
	if LS == nil then return false end
	LS.attach(M.lsHost())
	LS.set_enabled(true)
	-- [REFRESH] vua TU GHI xong sau cap nhat: xoa he so hieu chuan cu de LocalServer hieu chuan lai theo tuong that moi
	if M.consumeRecal ~= nil and M.consumeRecal() then
		pcall(function()
			local st = LS._state ~= nil and LS._state() or nil
			if type(st) == "table" and type(st.cfg) == "table" then st.cfg.k = nil end
		end)
		logmsg("REFRESH: se hieu chuan lai LocalServer theo chi so tuong moi")
	end
	return true
end

local P_BIG   = { 0, 1000, 10000, 100000, 1000000, 10000000, 99999999 }
local P_SMALL = { 0, 100, 500, 1000, 5000, 99999 }

local AUTO_ROWS = {
	{ key = "gold",      name = "Vang (gold)",       field = "user_gold",   presets = P_BIG },
	{ key = "silver",    name = "Bac (silver)",      field = "user_silver", presets = P_BIG },
	{ key = "soul",      name = "Hon (soul)",        field = "soul",        presets = P_BIG },
	{ key = "jade",      name = "Ngoc (jade)",       field = "jade",        presets = P_BIG },
	{ key = "honour",    name = "Danh du (honour)",  field = "user_honour", presets = P_BIG },
	{ key = "food",      name = "The luc (food)",    field = "user_food",   maxfield = "max_user_food", presets = P_SMALL },
	{ key = "endurance", name = "Suc ben (endur.)",  field = "endurance",   maxfield = "max_endurance", presets = P_SMALL },
	{ key = "level",     name = "Cap (level)",       kind = "level" },
	{ key = "vip",       name = "VIP",               kind = "vip" },
}
-- [AUTO] 9 dong tren khong hien trong bang nua: tu dong giu o muc toi da (xem M.gmApply).
local GM_ROWS = {
-- [FIX gop nut] Buff arena: dieu chinh luc chien dau cua bot doi thu
	-- (1..100). Truoc day phai bam nut rieng "BUFF ARENA 100" o bang nut;
	-- nay gop thang vao bang GM co san, dung chung co che +/-.
	-- [NHAP SO] 3 dong nhap tay (cham NHAP -> ban phim so): thay cho nut +/- va nut SUC MANH.
	{ key = "ar_power", name = "Buff arena (bot) x",  kind = "input", input = true },
	{ key = "mult",     name = "Suc manh team x",     kind = "input", input = true },
	{ key = "cell_hp",  name = "Mau bot Cell x",      kind = "input", input = true },
}
M._gm_rows = GM_ROWS

local function ed_user()
	local ED = rawget(_G, "_ED")
	if type(ED) ~= "table" then return nil, nil end
	local ui = ED.user_info
	if type(ui) ~= "table" then return ED, nil end
	return ED, ui
end

local function level_cap()
	local cap = 100
	pcall(function()
		local d = rawget(_G, "dms")
		if type(d) == "table" and type(d["user_experience_param"]) == "table" and d.count ~= nil then
			local n = d.count(d["user_experience_param"])
			if type(n) == "number" and n > 10 then cap = n - 1 end
		end
	end)
	if cap > 200 then cap = 200 end
	return cap
end

local function presets_of(row)
	if row.kind == "level" then
		local cap = level_cap()
		local list = { 0 }
		local v = 10
		while v < cap do
			list[#list + 1] = v
			v = v + 10
		end
		list[#list + 1] = cap
		return list
	elseif row.kind == "vip" then
		-- [FIX gop nut] Game goc chan VIP o ED.max_vip_level (thuong 14).
		-- Nang tran len 20 de chon duoc VIP 20 ngay trong bang GM.
		local mx = 20
		local ED = rawget(_G, "_ED")
		if type(ED) == "table" and tonumber(ED.max_vip_level) ~= nil then mx = tonumber(ED.max_vip_level) end
		local list = {}
		for i = 0, mx do list[#list + 1] = i end
		return list
	elseif row.kind == "ar_power" then
		-- [FIX gop nut] 1..100 theo dung ARENA_POWER_STEPS cua LocalServer.
		local list = {}
		for i = 0, 100 do list[#list + 1] = i end
		return list
	end
	return row.presets
end

local function gm_on()
	return M.gm_button and M.getMode() == "replay"
end

local function gm_valid_key(k)
	for i = 1, #GM_ROWS do
		if GM_ROWS[i].key == k then return true end
	end
	return false
end

local function gm_text()
	local t = { "#OFFLINE_GM v1", "on=" .. (M.gm.on and "1" or "0") }
	for i = 1, #GM_ROWS do
		local key = GM_ROWS[i].key
		local v = M.gm.floors[key]
		if v ~= nil and v > 0 then t[#t + 1] = key .. "=" .. fmt_int(v) end
	end
	return table.concat(t, "\n") .. "\n"
end

local function gm_parse(s)
	local floors, on = {}, true
	for line in string.gmatch(s .. "\n", "([^\n]*)\n") do
		line = (string.gsub(line, "\r$", ""))
		local k, v = string.match(line, "^%s*([%w_]+)%s*=%s*(%-?%d+)%s*$")
		if k ~= nil then
			if k == "on" then
				on = (tonumber(v) ~= 0)
			elseif gm_valid_key(k) and tonumber(v) ~= nil and tonumber(v) > 0 then
				floors[k] = tonumber(v)
			end
		end
	end
	return floors, on
end

function M.gmLoad()
	if M._gm_loaded then return end
	M._gm_loaded = true
	local s = ud_get(M.gm_ud_key)
	if s == nil then s = read_first(M.gm_file) end
	if s ~= nil then
		local floors, on = gm_parse(s)
		M.gm.floors = floors
		M.gm.on = on
	end
end

function M.gmSave()
	local txt = gm_text()
	ud_set(M.gm_ud_key, txt)
	pcall(write_first, M.gm_file, txt)
end

local function ls_ledger_row(row)
	return ls_manages(row.key)
end

-- [AUTO] Nap tai nguyen MOT LAN khi vao game (sau do tieu thi giam binh thuong, khong ghim lai).
-- Chi VIP la duoc giu o 20 moi tick; cap + mo ai + tat ca tuong lam 1 lan moi phien.
local INIT_FLOOR = { soul = 99999999, jade = 99999999, honour = 99999999, endurance = 99999 }
local INIT_LS = { gold = 99999999, silver = 999999999, food = 99999 }
local VIP_FIXED = 20

local function auto_ls(ED, first)
	local LS = M.LS
	if not ls_active() or LS.ready == nil or not LS.ready() then return end
	if first then
		for kind, target in pairs(INIT_LS) do
			if kind == "food" then
				if LS.gm_set_food then pcall(LS.gm_set_food, target) end
			else
				if LS.gm_set_money then pcall(LS.gm_set_money, kind, target) end
			end
		end
	end
	local now = os.time()
	if M._auto_t ~= nil and now - M._auto_t < 2 then return end
	M._auto_t = now
	-- VIP 20: ghi vao LS (luu lai) 1 lan moi phien; gmApply giu ED.vip_grade >= 20 moi tick
	if not M._auto_vip and LS.gm_set_vip ~= nil then
		local okv, r = pcall(LS.gm_set_vip, VIP_FIXED)
		if okv and r ~= nil then M._auto_vip = true end
	end
	-- cap toi da + mo full 3 ai: lam 1 lan moi phien (lap lai den khi LS tra ve ket qua)
	if not M._auto_lvl and LS.gm_max_level ~= nil then
		local okl, g = pcall(LS.gm_max_level)
		if okl and g ~= nil then M._auto_lvl = true end
	end
	if M._auto_lvl and not M._auto_camp and LS.gm_open_campaign ~= nil then
		local okc, scenes = pcall(LS.gm_open_campaign)
		if okc and scenes ~= nil then M._auto_camp = true end
	end
	-- tat ca tuong: cap vao du lieu 1 lan moi phien (LS tu bo qua tuong da co)
	if not M._auto_heroes and LS.gm_grant_all ~= nil then
		local okh, n = pcall(LS.gm_grant_all)
		if okh and n ~= nil then M._auto_heroes = true end
	end
end

function M.gmApply()
	-- Auto buff (vang, kim cuong, the luc, VIP 20, cap toi da, mo ai, tat ca tuong) chay theo che do SEVER TEST,
	-- KHONG phu thuoc nut GM co dang hien hay khong.
	if M.getMode() ~= "replay" then return false end
	local ED, ui = ed_user()
	if ui == nil then return false end
	local changed = false
	local ready = true
	if ls_active() then ready = (M.LS.ready ~= nil and M.LS.ready()) and true or false end
	local first = ready and not M._init_done
	for i = 1, #AUTO_ROWS do
		local row = AUTO_ROWS[i]
		if row.kind == "vip" then
			local cur = to_num(ED.vip_grade)
			if cur == nil then cur = to_num(ui.vip_level) end
			if cur == nil or cur < VIP_FIXED then
				local s = fmt_int(VIP_FIXED)
				ED.vip_grade = s
				ui.vip_level = s
				changed = true
			end
		elseif first and INIT_FLOOR[row.key] ~= nil then
			local floor = INIT_FLOOR[row.key]
			local cur = to_num(ui[row.field])
			if cur == nil or cur < floor then
				ui[row.field] = fmt_int(floor)
				changed = true
			end
			if row.maxfield ~= nil then
				local mx = to_num(ui[row.maxfield])
				if mx == nil or mx < floor then ui[row.maxfield] = fmt_int(floor) end
			end
		end
	end
	pcall(auto_ls, ED, first)
	if first then M._init_done = true end
	return changed
end

local GM_BTN_NAME   = "offlinemock_gm_btn"
local GM_PANEL_NAME = "offlinemock_gm_panel"
local Z_GM          = 1000001
local GM_BTN_W, GM_BTN_H = 64, 32

local function gm_btn_rect(size)
	return { x = size.width - GM_BTN_W - 6, y = size.height * M.gm_button_y, w = GM_BTN_W, h = GM_BTN_H }
end

-- [NHAP SO] Thu tu nut chan bang GM: moi phan tu = { id nut (gmFooter), so cot chiem (1..4) }.
-- Da xoa: BU TIEN, CAP MOI, XEP DOI HINH, DO THE LUC, CAP +1, SU KIEN +, ROUND, VO HAN LUOT,
-- ARENA -/+ va SUC MANH (chuyen thanh dong nhap so). VAT PHAM + va TRANG BI + gop lam mot (id 9).
local FOOT_ORDER = {
{ { 1, 1 }, { 5, 1 }, { 6, 1 }, { 41, 1 } },
	{ { 9, 2 }, { 12, 1 }, { 28, 1 } },
	{ { 27, 2 }, { 25, 2 } },
	{ { 21, 2 }, { 22, 2 } },
	{ { 29, 1 }, { 30, 1 }, { 31, 1 }, { 32, 1 } },
	{ { 33, 1 }, { 34, 1 }, { 35, 1 }, { 36, 1 } },
	{ { 37, 1 }, { 39, 1 }, { 40, 2 } },
}

local function gm_layout(size)
	local n = #GM_ROWS
	local nf = #FOOT_ORDER
	local header = 58
	local function foot_h(f) return 8 + nf * f + nf * 6 + 10 end
	local fh, rowh = 38, 42
	local avail = size.height - 12
	if header + foot_h(fh) + n * rowh > avail then
		rowh = math.floor((avail - header - foot_h(fh)) / n)
		if rowh < 30 then
			fh = 30
			rowh = math.floor((avail - header - foot_h(fh)) / n)
			if rowh < 26 then
				fh = 28
				rowh = math.floor((avail - header - foot_h(fh)) / n)
				if rowh < 24 then
					fh = 24
					rowh = math.floor((avail - header - foot_h(fh)) / n)
					if rowh < 22 then
						fh = 22
						rowh = math.max(20, math.floor((avail - header - foot_h(fh)) / n))
					end
				end
			end
		end
	end
	local footer = foot_h(fh)
	local ph = header + footer + n * rowh
	local pw = math.min(size.width - 16, 760)
	local L = { pw = pw, ph = ph, rowh = rowh, header = header, footer = footer }
	L.x = math.floor((size.width - pw) / 2)
	L.y = math.floor((size.height - ph) / 2)
	local bw, gap = 54, 6
	local bx3 = pw - 10 - bw
	local bx2 = bx3 - gap - bw
	local bx1 = bx2 - gap - bw
	L.rows = {}
	for i = 1, n do
		local top = ph - header - (i - 1) * rowh
		local y = top - rowh + 4
		L.rows[i] = {
			cy = top - rowh / 2,
			minus = { x = bx1, y = y, w = bw, h = rowh - 8 },
			plus  = { x = bx2, y = y, w = bw, h = rowh - 8 },
			max   = { x = bx3, y = y, w = bw, h = rowh - 8 },
			-- [NHAP SO] mot nut NHAP rong thay cho 3 nut -/+/MAX
			input = { x = bx1, y = y, w = bx3 + bw - bx1, h = rowh - 8 },
		}
	end
	L.x_name = 10
	L.x_live = math.floor(pw * 0.27)
	L.x_floor = math.floor(pw * 0.45)
	L.close = { x = pw - 10 - 70, y = ph - header + 12, w = 70, h = 34 }
	local fw = math.floor((pw - 10 * 2 - 6 * 3) / 4)
	L.foot = {}
	for line = 1, nf do
		local col = 0
		for _, it in ipairs(FOOT_ORDER[line]) do
			local id, span = it[1], it[2]
			L.foot[id] = {
				x = 10 + col * (fw + 6),
				y = 8 + (nf - line) * (fh + 6),
				w = span * fw + (span - 1) * 6,
				h = fh,
			}
			col = col + span
		end
	end
	-- [NHAP SO] ban phim so (hien khi cham NHAP): luoi 4 hang x 3 cot + hang HUY/OK
	local kw, kh, kg = 84, 40, 6
	local kpw = 3 * kw + 2 * kg + 24
	local base = 8 + kh + 10                              -- day cac phim (tren hang HUY/OK)
	local keys_top = base + 4 * (kh + kg) - kg
	local disp_y = keys_top + 10
	local kph = disp_y + 40 + 34                          -- + o hien so + tieu de
	local kpx = math.floor((pw - kpw) / 2)
	local kpy = math.max(4, math.floor((ph - kph) / 2))
	local K = { x = kpx, y = kpy, w = kpw, h = kph, keys = {} }
	K.disp = { x = kpx + 12, y = kpy + disp_y, w = kpw - 24, h = 40 }
	local labels = { "7", "8", "9", "4", "5", "6", "1", "2", "3", ".", "0", "<" }
	for k = 1, 12 do
		local r, c = math.floor((k - 1) / 3), (k - 1) % 3
		K.keys[k] = { ch = labels[k], x = kpx + 12 + c * (kw + kg), y = kpy + base + (3 - r) * (kh + kg), w = kw, h = kh }
	end
	K.cancel = { x = kpx + 12, y = kpy + 8, w = math.floor((kpw - 24 - kg) / 2), h = kh }
	K.ok = { x = K.cancel.x + K.cancel.w + kg, y = kpy + 8, w = K.cancel.w, h = kh }
	L.kp = K
	return L
end
M._gm_layout = gm_layout
M._gm_btn_rect = gm_btn_rect

local function in_rect(px, py, r)
	return px >= r.x and py >= r.y and px <= r.x + r.w and py <= r.y + r.h
end

local function new_label(parent, text, size, x, y, ax)
	local lb = cc.Label:createWithSystemFont(text, "", size)
	pcall(function() lb:setAnchorPoint(cc.p(ax, 0.5)) end)
	lb:setPosition(cc.p(x, y))
	parent:addChild(lb)
	return lb
end

local function new_rect(parent, r, color)
	local bg = cc.LayerColor:create(color, r.w, r.h)
	bg:setPosition(cc.p(r.x, r.y))
	parent:addChild(bg)
	return bg
end

local function new_button(parent, r, text, size, color)
	local bg = cc.LayerColor:create(color, r.w, r.h)
	bg:setPosition(cc.p(r.x, r.y))
	parent:addChild(bg)
	return new_label(parent, text, size, r.x + r.w / 2, r.y + r.h / 2, 0.5)
end

local function input_value(row)
	local LS = M.LS
	if LS == nil or not ls_active() then return nil end
	if row.key == "ar_power" then
		return LS.get_arena_power ~= nil and LS.get_arena_power() or nil
	elseif row.key == "mult" then
		return LS.get_mult ~= nil and LS.get_mult() or nil
	elseif row.key == "cell_hp" then
		return LS.get_cell_hp ~= nil and LS.get_cell_hp() or nil
	end
	return nil
end

local function fmt_x(v)
	v = tonumber(v)
	if v == nil then return "-" end
	local s = string.format("%.2f", v)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return "x" .. s
end

local function live_value(row)
	if row.input then return input_value(row) end
	local ED, ui = ed_user()
	if ui == nil then return nil end
	if row.kind == "vip" then
		return to_num(ED.vip_grade) or to_num(ui.vip_level)
	elseif row.kind == "level" then
		return to_num(ui.user_grade)
	end
	return to_num(ui[row.field])
end

local function reset_pending()
	return M._reset_ask ~= nil and os.time() - M._reset_ask <= 4
end


local function inf_sig()
	if M.LS == nil or M.LS.inf_state == nil then return "-" end
	local ok, r, a, c = pcall(M.LS.inf_state)
	if not ok then return "?" end
	return (r and "1" or "0") .. (a and "1" or "0") .. tostring(c)
end

local function full_sig()
	if M.LS == nil or M.LS.full_state == nil then return "-" end
	-- [FIX] truoc day chi ghep 6/10 co FULL => bat/tat Than khi, Thien phu, Hop kim, Party khong lam
	-- bang GM ve lai (nut van hien trang thai cu) cho toi khi co thay doi khac trong bang.
	local r = { pcall(M.LS.full_state) }
	if not r[1] then return "?" end
	local t = {}
	for i = 2, 12 do t[#t + 1] = r[i] and "1" or "0" end
	return table.concat(t)
end

local function fh_sig()
	if M.LS == nil or M.LS.fh_state == nil then return "-" end
	local ok, st = pcall(M.LS.fh_state)
	if not ok or type(st) ~= "table" then return "?" end
	if st.running then return "R" .. tostring(st.pos) .. "/" .. tostring(st.total) end
	return "i"
end

local function fu_sig()
	local fu = M.FU
	if type(fu) == "table" and type(fu.sig) == "function" then
		local ok, s = pcall(fu.sig)
		if ok then return tostring(s) end
	end
	return "-"
end

local function gm_sig()
	local t = { M.gm.on and "1" or "0" }
	for i = 1, #GM_ROWS do
		local row = GM_ROWS[i]
		t[#t + 1] = tostring(M.gm.floors[row.key] or 0)
		t[#t + 1] = tostring(live_value(row))
	end
	if ls_active() then
		t[#t + 1] = "LS" .. tostring(M.LS.status_text()) .. "g" .. tostring(M.LS.get_grade()) .. "x" .. tostring(M.LS.get_mult())
			.. "d" .. tostring(M.LS.get_drop_mult ~= nil and M.LS.get_drop_mult() or 1) .. "i" .. inf_sig() .. "f" .. full_sig()
			.. "a" .. tostring(M.LS.get_arena_power ~= nil and M.LS.get_arena_power() or 1)
			.. "c" .. tostring(M.LS.cell_state ~= nil and M.LS.cell_state() or "-")
			.. "t" .. tostring(M.LS.tower_state ~= nil and M.LS.tower_state() or "-")
	else
		t[#t + 1] = "noLS"
	end
	t[#t + 1] = "h" .. fh_sig()
	t[#t + 1] = "u" .. ((M.updateEnabled ~= nil and M.updateEnabled()) and "1" or "0") -- [UPD] estado del boton CAP NHAT
	t[#t + 1] = M.clean_ui and "clean" or "show"
	t[#t + 1] = M._kp ~= nil and ("kp" .. tostring(M._kp.row.key) .. ":" .. M._kp.text) or "nokp"
	t[#t + 1] = reset_pending() and "R" or "r"
	t[#t + 1] = "fu" .. fu_sig()
	return table.concat(t, "|")
end

local function gm_build_panel(scene, L)
	local bg = cc.LayerColor:create(cc.c4b(0, 0, 0, 225), L.pw, L.ph)
	bg:setPosition(cc.p(L.x, L.y))
	pcall(function() bg:setName(GM_PANEL_NAME) end)

new_label(bg, "GM OFFLINE -tien nap 1 lan, VIP/cap/ai/tuong/roi do x5/thap bot: tu dong; cham NHAP de chinh buff", 17, L.x_name, L.ph - 18, 0)
	local lsline
	if ls_active() then
		lsline = tostring(M.LS.status_text())
	elseif M._ls_err ~= nil then
		lsline = "LS: khong nap duoc (" .. tostring(M._ls_err) .. ")"
	else
		lsline = "LS: tat"
	end
	local l2 = new_label(bg, lsline, 14, L.x_name, L.ph - 42, 0)
	pcall(function() l2:setColor(cc.c3b(150, 230, 255)) end)
	new_button(bg, L.close, "DONG", 18, cc.c4b(130, 40, 40, 255))

	for i = 1, #GM_ROWS do
		local row = GM_ROWS[i]
		local R = L.rows[i]
		new_label(bg, row.name, 17, L.x_name, R.cy, 0)
		local live = live_value(row)
		if row.input then
			-- [NHAP SO] hien he so hien tai + nut NHAP (mo ban phim so)
			local lv = new_label(bg, "hien: " .. fmt_x(live), 16, L.x_live, R.cy, 0)
			pcall(function() lv:setColor(cc.c3b(255, 230, 120)) end)
			local hint = new_label(bg, ls_active() and "cham NHAP de go so" or "can LS (OFFLINE)", 14, L.x_floor, R.cy, 0)
			pcall(function() hint:setColor(cc.c3b(150, 230, 255)) end)
			new_button(bg, R.input, "NHAP", 18, ls_active() and cc.c4b(45, 70, 130, 255) or cc.c4b(55, 55, 55, 255))
		else
			new_label(bg, "hien: " .. (live ~= nil and fmt_num(live) or "-"), 16, L.x_live, R.cy, 0)
			if ls_ledger_row(row) then
				local bal, tag
				if row.key == "food" or row.key == "level" then
					bal = M.LS.user_get(row.key)
					tag = (row.key == "food") and "the luc LS: " or "cap LS: "
				else
					bal = M.LS.money_get(row.key)
					tag = "so du LS: "
				end
				local fl = new_label(bg, tag .. (bal ~= nil and fmt_num(bal) or "-"), 16, L.x_floor, R.cy, 0)
				pcall(function() fl:setColor(cc.c3b(150, 230, 255)) end)
			else
				local floor = M.gm.floors[row.key]
				local fl = new_label(bg, "min: " .. ((floor ~= nil and floor > 0) and fmt_num(floor) or "tat"), 16, L.x_floor, R.cy, 0)
				if floor ~= nil and floor > 0 then
					pcall(function() fl:setColor(cc.c3b(120, 255, 120)) end)
				end
			end
			new_button(bg, R.minus, "-", 22, cc.c4b(120, 45, 45, 255))
			new_button(bg, R.plus, "+", 22, cc.c4b(35, 105, 45, 255))
			new_button(bg, R.max, "MAX", 15, cc.c4b(45, 70, 130, 255))
		end
	end

	local lson = ls_active()
	local grade = lson and M.LS.get_grade() or 0
	local off = cc.c4b(55, 55, 55, 255)
	new_button(bg, L.foot[1], M.gm.on and "GM: BAT" or "GM: TAT", 16, cc.c4b(70, 70, 70, 255))
	new_button(bg, L.foot[5], "DUMP DATA", 16, lson and cc.c4b(30, 100, 110, 255) or off)
	new_button(bg, L.foot[6], reset_pending() and "BAM LAI = XOA" or "RESET LS", 16, lson and cc.c4b(150, 40, 40, 255) or off)
	do -- [v6.31] HOP THE 3 TUONG (Fusion.lua)
		local fu = M.FU
		local fl, fc = "HOP THE", off
		if type(fu) == "table" and type(fu.label) == "function" then
			local okl, l1, c1 = pcall(fu.label)
			if okl and l1 ~= nil then fl, fc = tostring(l1), c1 or off end
		end
		new_button(bg, L.foot[41], fl, 14, fc)
	end

	-- [NHAP SO] VAT PHAM + va TRANG BI + gop lam mot nut
	local lsi = lson and M.LS.gm_grant_items ~= nil
	new_button(bg, L.foot[9], "VAT PHAM + TRANG BI", 15, lsi and cc.c4b(40, 110, 90, 255) or off)
	new_button(bg, L.foot[12], "TINH LAI", 16, lson and cc.c4b(60, 90, 140, 255) or off)

	local c_on, c_off = cc.c4b(35, 105, 45, 255), cc.c4b(120, 45, 45, 255)
	local lsf = lson and M.LS.gm_toggle_full ~= nil and M.LS.full_state ~= nil
	local dkf, sgf, csf, maf, hsf, cbf, aff, tlf, alf, spf, wsf = false, false, false, false, false, false, false, false, false, false, false
	if lsf then
		local okx, d1, s1, c1, m1, h1, cb1, af1, tl1, al1, sp1, ws1 = pcall(M.LS.full_state)
		if okx then dkf, sgf, csf, maf, hsf, cbf, aff, tlf, alf, spf, wsf = d1 and true or false, s1 and true or false, c1 and true or false, m1 and true or false, h1 and true or false, cb1 and true or false, af1 and true or false, tl1 and true or false, al1 and true or false, sp1 and true or false, ws1 and true or false end
	end
	local c_man = cc.c4b(45, 70, 130, 255)
	new_button(bg, L.foot[21], "DECK: " .. (dkf and "FULL" or "TU NANG"), 16, lsf and (dkf and c_on or c_man) or off)
	new_button(bg, L.foot[22], "SOUL GUARD: " .. (sgf and "FULL" or "TU NANG"), 16, lsf and (sgf and c_on or c_man) or off)
	new_button(bg, L.foot[29], "12U: " .. (csf and "FULL" or "TU NANG"), 16, lsf and (csf and c_on or c_man) or off)
	new_button(bg, L.foot[30], "THAN THU: " .. (maf and "FULL" or "TU NANG"), 16, lsf and (maf and c_on or c_man) or off)
	new_button(bg, L.foot[31], "HERO SAGA: " .. (hsf and "FULL" or "TU NANG"), 15, lsf and (hsf and c_on or c_man) or off)
	-- [GM] O 32 truoc day la COMBO CARD; Combo Card FULL da tu bat boi TAT CA TUONG nen doi thanh WAR SOUL (Chien Hon)
	new_button(bg, L.foot[32], "WAR SOUL: " .. (wsf and "FULL" or "TU NANG"), 15, lsf and (wsf and c_on or c_man) or off)
	new_button(bg, L.foot[33], "THAN KHI: " .. (aff and "FULL" or "TU NANG"), 15, lsf and (aff and c_on or c_man) or off)
	new_button(bg, L.foot[34], "TALENT: " .. (tlf and "FULL" or "TU NANG"), 15, lsf and (tlf and c_on or c_man) or off)
	new_button(bg, L.foot[35], "Z ALLOY: " .. (alf and "FULL" or "TU NANG"), 15, lsf and (alf and c_on or c_man) or off)
	new_button(bg, L.foot[36], "PARTY: " .. (spf and "FULL" or "TU NANG"), 15, lsf and (spf and c_on or c_man) or off)
	-- [FIX Cell/Thap] CELL GAME (boss bat tu, 5 round, ghi de bang) va THAP BOT (bot random full, +10%/tang)
	local lsx = lson and M.LS.cell_state ~= nil and M.LS.gm_toggle_cell ~= nil
	local cell_on = false
	if lsx then
		local okx, c1 = pcall(M.LS.cell_state)
		cell_on = okx and c1 and true or false
	end
	new_button(bg, L.foot[37], "CELL GAME: " .. (cell_on and "BAT" or "TAT"), 15, lsx and (cell_on and c_on or c_off) or off)
	-- [UPD] CAP NHAT khi mo game (OFFLINE) / KIEM TRA DATA ngay
	local upd_on = false
	if M.updateEnabled ~= nil then
		local okx, u1 = pcall(M.updateEnabled)
		upd_on = okx and u1 and true or false
	end
	new_button(bg, L.foot[39], "CAP NHAT: " .. (upd_on and "BAT" or "TAT"), 15, upd_on and c_on or c_off)
	new_button(bg, L.foot[40], "KIEM TRA DATA", 14, M.updWatchStart ~= nil and cc.c4b(45, 70, 130, 255) or off)
	new_button(bg, L.foot[25], "AN HUD/NUT", 16, cc.c4b(55, 55, 55, 255))

	local lsc = lson and M.LS.gm_clear_formation ~= nil
	new_button(bg, L.foot[28], "GO HET TUONG", 16, lsc and cc.c4b(120, 70, 55, 255) or off)
	local lsh = lson and M.LS.gm_full_heroes ~= nil and M.LS.fh_state ~= nil
	local fhs = nil
	if lsh then
		local okx, st = pcall(M.LS.fh_state)
		if okx and type(st) == "table" then fhs = st end
	end
	local fhl, fhc = "NANG MAX TUONG", lsh and cc.c4b(150, 70, 110, 255) or off
	if lsh and fhs ~= nil and fhs.running then
		fhl, fhc = "DANG NANG " .. tostring(fhs.pos) .. "/" .. tostring(fhs.total), cc.c4b(140, 110, 40, 255)
	end
	new_button(bg, L.foot[27], fhl, 16, fhc)

	-- [NHAP SO] ban phim so (overlay) khi dang nhap mot dong buff
	local kp = M._kp
	if kp ~= nil then
		local K = L.kp
new_rect(bg, { x = 0, y = 0, w = L.pw, h = L.ph }, cc.c4b(0, 0, 0, 150))
new_rect(bg, K, cc.c4b(25, 30, 45, 255))
		local t1 = new_label(bg, kp.row.name, 17, K.x + 12, K.y + K.h - 20, 0)
		pcall(function() t1:setColor(cc.c3b(255, 230, 120)) end)
		new_button(bg, K.disp, (kp.text == "" and "(nhap so)" or kp.text), 22, cc.c4b(10, 10, 15, 255))
		for k = 1, #K.keys do
			local key = K.keys[k]
			new_button(bg, key, key.ch == "<" and "XOA" or key.ch, 20,
				key.ch == "<" and cc.c4b(120, 45, 45, 255) or cc.c4b(60, 66, 90, 255))
		end
		new_button(bg, K.cancel, "HUY", 18, cc.c4b(120, 45, 45, 255))
		new_button(bg, K.ok, "OK", 18, cc.c4b(35, 105, 45, 255))
	end

	scene:addChild(bg, Z_GM)
	return bg
end

function M.gmRender()
	local scene = running_scene()
	if scene == nil then return end
	local size = visible_size()
	local want = gm_on()

	local btn = scene:getChildByName(GM_BTN_NAME)
	if want then
		if btn == nil then
			local r = gm_btn_rect(size)
			local node = cc.Node:create()
			pcall(function() node:setName(GM_BTN_NAME) end)
			new_button(node, r, "GM", 20, cc.c4b(150, 100, 0, 200))
			scene:addChild(node, Z_GM)
		end
	elseif btn ~= nil then
		btn:removeFromParent()
	end

	local panel = scene:getChildByName(GM_PANEL_NAME)
	if want and M._gm_open then
		local sig = gm_sig()
		if panel == nil or M._gm_sig ~= sig then
			if panel ~= nil then panel:removeFromParent() end
			gm_build_panel(scene, gm_layout(size))
			M._gm_sig = sig
		end
	elseif panel ~= nil then
		panel:removeFromParent()
		M._gm_sig = nil
	end
end

function M.gmClose()
	M._kp = nil
	M._gm_open = false
	M._gm_sig = nil
	pcall(M.gmRender)
end

function M.gmChanged()
	M.gmSave()
	M.gmApply()
	M._gm_sig = nil
	pcall(M.gmRender)
end

local function step_value(list, cur, dir)
	if dir == 0 then return list[#list] end
	if dir > 0 then
		for i = 1, #list do
			if list[i] > cur then return list[i] end
		end
		return list[#list]
	end
	for i = #list, 1, -1 do
		if list[i] < cur then return list[i] end
	end
	return list[1]
end

function M.gmStep(row, dir)
	local list = presets_of(row)
	-- [FIX gop nut] Buff arena: goi thang LS.gm_step_arena_power de tang/giam
	-- 1 buoc (clamp 0..100). dir == 0 (nut MAX) thi nhay thang len 100.
	-- [FIX gop nut] VIP: ghi thang qua LS.gm_set_vip de khong bi
	-- ED.max_vip_level (thuong 14) chan lai khi chon moc 20.
	if row.kind == "vip" then
		if M.LS ~= nil and M.LS.gm_set_vip ~= nil and M.LS.ready ~= nil and M.LS.ready() then
			local cur = tonumber(M.LS.user_get and M.LS.user_get("vip")) or 0
			local nv = step_value(list, cur, dir)
			M.LS.gm_set_vip(nv or 20)
			M._gm_sig = nil
			pcall(M.gmRender)
			return
		end
	end
	if ls_ledger_row(row) then

		if not M.LS.ready() then
			notify("LS chua san sang: vao game (qua man dang nhap) roi bam lai.", 5)
			return
		end
		if row.key == "food" then
			local cur = M.LS.user_get("food") or 0
			M.LS.gm_set_food(step_value(list, cur, dir))
		elseif row.key == "level" then
			if dir < 0 then
				notify("LS chi tang cap duoc, khong ha cap.", 4)
			else
				local g = M.LS.gm_player_level(dir == 0 and 10 or 1)
				if g ~= nil then notify("LS: cap nguoi choi = " .. tostring(g) .. " (chuong moi se mo neu du dieu kien).", 5) end
			end
		else
			local cur = M.LS.money_get(row.key) or 0
			M.LS.gm_set_money(row.key, step_value(list, cur, dir))
		end
		M._gm_sig = nil
		pcall(M.gmRender)
		return
	end
	local cur = M.gm.floors[row.key] or 0
	local new = step_value(list, cur, dir)
	if new == nil or new <= 0 then
		M.gm.floors[row.key] = nil
	else
		M.gm.floors[row.key] = new
	end
	M.gmChanged()
end

local function ls_or_toast(need_ready)
	if not ls_active() then
		notify("LocalServer khong chay (thieu file LocalServer.lua hoac khong o che do OFFLINE).", 6)
		return nil
	end
	if need_ready and not M.LS.ready() then
		notify("LS chua san sang: vao game (qua man dang nhap) roi bam lai.", 5)
		return nil
	end
	return M.LS
end

local function row_by_key(k)
	for i = 1, #GM_ROWS do
		if GM_ROWS[i].key == k then return GM_ROWS[i] end
	end
	return nil
end

-- [NHAP SO] Ban phim so de nhap he so buff cho Arena / Suc manh team / Mau bot Cell.
local KP_LIMITS = { ar_power = { 1, 10000 }, mult = { 1, 1000000 }, cell_hp = { 1, 1000000 } }

function M.kpOpen(row)
	if not ls_active() then
		notify("LocalServer khong chay (can che do OFFLINE).", 5)
		return
	end
	M._kp = { row = row, text = "" }
	M._gm_sig = nil
	pcall(M.gmRender)
end

function M.kpCancel()
	M._kp = nil
	M._gm_sig = nil
	pcall(M.gmRender)
end

function M.kpKey(ch)
	local kp = M._kp
	if kp == nil then return end
	if ch == "<" then
		kp.text = string.sub(kp.text, 1, -2)
	elseif ch == "." then
		if kp.text == "" then
			kp.text = "0."
		elseif not string.find(kp.text, ".", 1, true) then
			kp.text = kp.text .. "."
		end
	elseif #kp.text < 9 then
		kp.text = kp.text .. ch
	end
	M._gm_sig = nil
	pcall(M.gmRender)
end

function M.kpOk()
	local kp = M._kp
	if kp == nil then return end
	local v = tonumber(kp.text)
	if v == nil then
		notify("Hay nhap mot so.", 3)
		return
	end
	local key = kp.row.key
	local lim = KP_LIMITS[key] or { 1, 1000000 }
	if v < lim[1] then v = lim[1] end
	if v > lim[2] then v = lim[2] end
	local LS = M.LS
	if LS == nil then return end
	if key ~= "cell_hp" and not LS.ready() then
		notify("LS chua san sang: vao game (qua man dang nhap) roi nhap lai.", 5)
		return
	end
	if key == "ar_power" then
		if LS.gm_set_arena_power == nil then notify("Can LocalServer.lua ban ls-2.31.", 5); return end
		local r = LS.gm_set_arena_power(v)
		if r ~= nil then notify("LS Arena: chi so HP/cong/thu cua bot = " .. fmt_x(r) .. " (ap dung tran sau).", 6) end
	elseif key == "mult" then
		if LS.gm_set_mult == nil then notify("Can LocalServer.lua co gm_set_mult.", 5); return end
		if LS.gm_set_mult(v) then
			notify("LS: he so suc manh team = " .. fmt_x(LS.get_mult()) .. " (chi OFFLINE, ap dung cho tuong cua ban; x1 = nhu goc).", 6)
		end
	elseif key == "cell_hp" then
		if LS.gm_set_cell_hp == nil then notify("Can LocalServer.lua ban co gm_set_cell_hp.", 5); return end
		local r = LS.gm_set_cell_hp(v)
		if r ~= nil then notify("LS: mau boss Cell = " .. fmt_x(r) .. " (ap dung tran Cell moi; CELL GAME phai BAT).", 6) end
	end
	M._kp = nil
	M._gm_sig = nil
	pcall(M.gmRender)
end

function M.gmFooter(i)
	if i == 1 then
		M.gm.on = not M.gm.on
		M.gmChanged()
	elseif i == 5 then
		local LS = ls_or_toast(false)
		if LS == nil then return end
		local path, n = LS.dump()
		if path ~= nil then
			notify("DUMP xong (" .. tostring(n) .. " dong):\n" .. tostring(path), 10)
		else
			notify("DUMP: khong ghi duoc file!", 8)
		end
	elseif i == 6 then
		local LS = ls_or_toast(false)
		if LS == nil then return end
		if reset_pending() then
			M._reset_ask = nil
			LS.reset()
			notify("LS: da xoa tuong/doi hinh do LS tao. Tien duoc giu.", 6)
		else
			M._reset_ask = os.time()
			notify("Bam RESET LS them mot lan nua trong 4 giay de XOA HET tuong do LS tao (tien duoc giu).", 5)
		end
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 9 then
		local LS = ls_or_toast(true)
		if LS == nil then return end
		-- [NHAP SO] gop VAT PHAM + va TRANG BI + thanh mot nut
		local nk, n = LS.gm_grant_items(9999)
		local np, nb, nws
		if LS.gm_grant_equip ~= nil then
			np, nb, nws = LS.gm_grant_equip(99)
		end
		local msg = {}
		if nk ~= nil then
			msg[#msg + 1] = "vat pham: +" .. tostring(n) .. " moi loai (" .. tostring(nk) .. " loai)"
		end
		if np ~= nil then
			msg[#msg + 1] = "trang bi: +99 moi vat lieu (" .. tostring(np) .. " loai), " .. tostring(nb or 0) .. " loai trang bi/manh"
				.. (nws ~= nil and (", +" .. tostring(nws) .. " Chien Hon/da hon") or "")
		end
		if #msg > 0 then notify("LS: " .. table.concat(msg, "; ") .. ".", 8) end
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 12 then

		local LS = ls_or_toast(true)
		if LS == nil then return end
		local okc = LS.gm_recalibrate()
		notify(okc and "LS: da hieu chuan lai chi so tuong LS theo cac tuong that cua ban."
			or "LS: khong co tuong that de hieu chuan.", 6)
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 21 or i == 22 or i == 29 or i == 30 or i == 31 or i == 32 or i == 33 or i == 34 or i == 35 or i == 36 then

		local LS = ls_or_toast(true)
		if LS == nil then return end
		if LS.gm_toggle_full == nil or LS.full_state == nil then
			notify("Can LocalServer.lua ban ls-2.34 de dung nut nay.", 5)
			return
		end
		local spec = {
			[21] = { key = "deck", title = "DECK", on = "moi the cap toi da, chi so cong vao moi tuong" },
			[22] = { key = "sg", title = "SOUL GUARD", on = "4 thu ve cap toi da va LS tu chon tuong tro giup" },
			[29] = { key = "cs", title = "12 UNIVERSE", on = "mo toan bo bao ho va chon muc cao nhat cho moi o" },
			[30] = { key = "ma", title = "THAN THU", on = "max toan bo than thu, sao, ren, lien ket va thien menh" },
			[31] = { key = "hs", title = "HERO SAGA", on = "max toan bo liet truyen, sao va thanh tuu" },
			[32] = { key = "ws", title = "WAR SOUL", on = "kho Chien Hon luon du moi bo / vi tri / pham, MOI con FULL cap + bac (thuc tinh + cuong hoa toi da, ca con dang mac), vat lieu tu bu. Vai giay de chay het",
				off = "ngung tu bu va ngung max; Chien Hon da max van giu nguyen (khong thu hoi)." },
			[33] = { key = "af", title = "THAN KHI", on = "mo khoa toan bo than khi va day moi chi so len gioi han" },
			[34] = { key = "tl", title = "TALENT", on = "max toan bo thien phu va du diem" },
			[35] = { key = "al", title = "Z ALLOY", on = "moi hop kim max cap va max pham" },
			[36] = { key = "sp", title = "WARRIOR PARTY", on = "moi tuong max sao va max cap" },
		}
		local f = spec[i]
		local okt, on = pcall(LS.gm_toggle_full, f.key)
		if not okt then on = nil end
		local reopen = " Man " .. f.title .. " dang mo thi dong ra mo lai de thay."
		if on then
			notify("LS: " .. f.title .. " FULL - " .. f.on .. ". Bam lai = ve tien trinh tu nang." .. reopen, 8)
		elseif on == false then
			notify("LS: " .. f.title .. " TU NANG - " .. (f.off or "tra lai dung tien trinh truoc khi bat FULL.") .. reopen, 7)
		else
			notify("LS chua san sang: vao game roi bam lai.", 5)
		end
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 25 then
		M.uiToggle()
	elseif i == 28 then

		local LS = ls_or_toast(true)
		if LS == nil then return end
		if LS.gm_clear_formation == nil then
			notify("Can LocalServer.lua ban ls-2.33 de dung nut nay.", 5)
			return
		end
		local okf, c, why = pcall(LS.gm_clear_formation)
		if not okf then
			notify("LS: go doi hinh bi loi: " .. tostring(c), 7)
		elseif c == nil and why ~= "ban" then
			notify("LS chua go duoc doi hinh (" .. tostring(why) .. "): doi vai giay roi bam lai.", 6)
		end
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 27 then

		local LS = ls_or_toast(true)
		if LS == nil then return end
		if LS.gm_full_heroes == nil then
			notify("Can LocalServer.lua ban ls-2.32 de dung nut nay.", 5)
			return
		end
		local okf, n, why = pcall(LS.gm_full_heroes)
		if not okf then
			notify("LS: nang max tuong bi loi: " .. tostring(n), 7)
		elseif n == nil and why ~= "ban" and why ~= "thieu ham" then
			notify("LS chua nang duoc (" .. tostring(why) .. "): doi vai giay roi bam lai.", 6)
		end
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 37 then
		local LS = ls_or_toast(true)
		if LS == nil then return end
		if LS.gm_toggle_cell == nil then
			notify("Can LocalServer.lua ban ls-2.45 tro len de dung nut nay.", 5)
			return
		end
		local on = LS.gm_toggle_cell()
		if on then
			notify("LS: CELL GAME BAT - boss the gioi luon la boss toi da (100), BAT TU, moi tran toi da 5 round; sat thuong tran moi nhat GHI DE bang cu.", 9)
		elseif on == false then
			notify("LS: CELL GAME TAT - boss the gioi danh nhu cu (tuan tu, co the ha, cong don sat thuong, round theo cau hinh bang).", 7)
		else
			notify("LS chua san sang: vao game roi bam lai.", 5)
		end
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 39 then
		if M.toggleUpdate == nil then return end
		pcall(M.toggleUpdate)
		M._gm_sig = nil
		pcall(M.gmRender)
	elseif i == 40 then
		if M.updWatchStart == nil then return end
		M.updWatchStart(true)
	elseif i == 41 then
		-- [v6.31] HOP THE 3 TUONG: mo bang chon tuong cua Fusion.lua
		local fu = M.FU
		if type(fu) ~= "table" or type(fu.open) ~= "function" then
			notify("HOP THE chua san sang (" .. tostring(M._fu_err or "chua nap") .. "): can client/offline/Fusion.lua.", 6)
			return
		end
		local okf, errf = pcall(fu.open)
		if not okf then notify("HOP THE loi: " .. tostring(errf), 6) end
	end
end

function M._gmTouch(loc)
	if not gm_on() then return false end
	local scene = running_scene()
	if scene == nil then return false end
	local size = visible_size()
	if not M._gm_open then
		local btn = scene:getChildByName(GM_BTN_NAME)
		if btn == nil then return false end
		local p = btn:convertToNodeSpace(loc)
		if in_rect(p.x, p.y, gm_btn_rect(size)) then
			M._gm_open = true
			M._gm_sig = nil
			pcall(M.gmRender)
			return true
		end
		return false
	end

	local panel = scene:getChildByName(GM_PANEL_NAME)
	if panel == nil then
		pcall(M.gmRender)
		panel = scene:getChildByName(GM_PANEL_NAME)
		if panel == nil then return true end
	end
	local L = gm_layout(size)
	local p = panel:convertToNodeSpace(loc)
	local lx, ly = p.x, p.y
	if lx < 0 or ly < 0 or lx > L.pw or ly > L.ph then
		M.gmClose()
		return true
	end
if M._kp ~= nil then
		-- [NHAP SO] dang mo ban phim so: chi nhan phim, OK, HUY; cham ngoai = huy
		local K = L.kp
		if in_rect(lx, ly, K.ok) then M.kpOk(); return true end
		if in_rect(lx, ly, K.cancel) then M.kpCancel(); return true end
		for k = 1, #K.keys do
			if in_rect(lx, ly, K.keys[k]) then M.kpKey(K.keys[k].ch); return true end
		end
		if not in_rect(lx, ly, K) then M.kpCancel() end
		return true
	end
	if in_rect(lx, ly, L.close) then
		M.gmClose()
		return true
	end
	for i = 1, #GM_ROWS do
		local R = L.rows[i]
		if GM_ROWS[i].input then
			if in_rect(lx, ly, R.input) then M.kpOpen(GM_ROWS[i]); return true end
		else
			if in_rect(lx, ly, R.minus) then M.gmStep(GM_ROWS[i], -1); return true end
			if in_rect(lx, ly, R.plus) then M.gmStep(GM_ROWS[i], 1); return true end
			if in_rect(lx, ly, R.max) then M.gmStep(GM_ROWS[i], 0); return true end
		end
	end
	for i, r in pairs(L.foot) do
		if in_rect(lx, ly, r) then
			M.gmFooter(i)
			return true
		end
	end
	return true
end

local DT = {}
M._dt = DT

DT.priority = {
	"^ship_mould$", "^ship_grow", "^ship_exp", "^ship_", "^play_config$", "^ship_config$", "^fight_config$",
	"^new_recruit", "^recruit", "^draw", "^shop", "^prop", "^equip", "^skill", "^talent", "^fate", "^relation",
	"^user_", "^vip", "^limit", "^star", "^evolution", "^refine", "^cultivate", "^strength", "^destiny",
	"^legend", "^open_formation", "^environment", "^fun", "^upgrade", "^top_up", "^base_consume",
	"config$", "param$",
}

DT.text = { "^word_mould$", "dialogue", "^talkdata$", "^error_code$", "^load_interface$", "sound" }

DT.ed_secret_words = { token = true, password = true, passwd = true, pwd = true, secret = true, session = true,
	phone = true, mobile = true, email = true, imei = true, openid = true, cookie = true, signature = true,
	uuid = true, guid = true, account = true }
DT.ed_allow = { "dispatch_token", "secret_shop", "secretary" }
DT.ed_depth = 4
DT.ed_max_lines = 15000
DT.ed_sub_lines = 300

function DT.rank(v)
	local t = type(v)
	if t == "number" then return 1 end
	if t == "string" then return 2 end
	return 3
end

function DT.key_less(a, b)
	local ra, rb = DT.rank(a), DT.rank(b)
	if ra ~= rb then return ra < rb end
	if ra == 3 then return tostring(a) < tostring(b) end
	return a < b
end

function DT.match_any(name, list)
	for i = 1, #list do
		if string.find(name, list[i]) then return i end
	end
	return nil
end

function DT.list_tables()
	local names = {}
	local d = rawget(_G, "dms")
	if type(d) ~= "table" then return names end
	for k, v in pairs(d) do
		if type(k) == "string" and type(v) == "table" then names[#names + 1] = k end
	end
	local prio = {}
	for i = 1, #names do prio[names[i]] = DT.match_any(names[i], DT.priority) or 1000 end
	table.sort(names, function(a, b)
		if prio[a] ~= prio[b] then return prio[a] < prio[b] end
		return a < b
	end)
	return names
end

function DT.media_dir()
	local w = writable_dir()
	local pkg = string.match(w, "^/data/user/%d+/([^/]+)/")
		or string.match(w, "^/data/data/([^/]+)/")
	if pkg == nil then return nil end
	local dir = M.storage_root() .. "/Android/media/" .. pkg .. "/"
	pcall(function() cc.FileUtils:getInstance():createDirectory(dir) end)
	return dir
end

function DT.pick_base()
	local steps = {}
	for i = 1, #M.mirror_dirs do
		local d = M.mirror_dirs[i]
		steps[#steps + 1] = function() return d end
	end
	steps[#steps + 1] = DT.media_dir
	steps[#steps + 1] = external_app_dir
	steps[#steps + 1] = writable_dir
	local tried = {}
	for i = 1, #steps do
		local dir = steps[i]()
		if dir ~= nil then
			local f = io.open(dir .. M.dump_index_file, "wb")
			if f then
				f:write("# OfflineMock DUMP BANG dang chay (file nay se duoc ghi lai khi xong)\n")
				f:close()
				tried[#tried + 1] = (dir == "" and "(bo nho app)" or dir) .. "=ok"
				return dir, tried
			end
			tried[#tried + 1] = (dir == "" and "(bo nho app)" or dir) .. "=no"
		end
	end
	return nil, tried
end

function DT.pickup_hint(base)
	if string.find(base, "/Android/media/", 1, true) then
		return "Lay file: app Files > Bo nho trong > Android > media > " .. string.match(base, "/Android/media/([^/]+)")
			.. "  (hoac nut dinh kem trong app chat)"
	end
	if string.find(base, "/Android/data/", 1, true) then
		return "Thu muc nam trong Android/data: app chon file co the khong thay -> dung file manager co quyen, hoac noi USB vao may tinh"
	end
	if string.sub(base, 1, 6) == "/data/" then
		return "Thu muc rieng cua app: file manager thuong KHONG thay -> bao toi de tim cach khac"
	end
	return nil
end

function DT.split_cells(line)
	local t, init = {}, 1
	while true do
		local p = string.find(line, "\t", init, true)
		if p == nil then
			t[#t + 1] = string.sub(line, init)
			break
		end
		t[#t + 1] = string.sub(line, init, p - 1)
		init = p + 1
	end
	return t
end

function DT.nth_cell(line, c)
	local init = 1
	for _ = 2, c do
		local p = string.find(line, "\t", init, true)
		if p == nil then return nil end
		init = p + 1
	end
	local e = string.find(line, "\t", init, true)
	if e == nil then return string.sub(line, init) end
	return string.sub(line, init, e - 1)
end

function DT.same_key(cell, key)
	if cell == nil then return false end
	if cell == tostring(key) then return true end
	local a, b = tonumber(cell), tonumber(key)
	return a ~= nil and b ~= nil and a == b
end

function DT.row_line(row)
	local tr = type(row)
	if tr == "string" then
		if string.find(row, "[\r\n]") then
			row = string.gsub(row, "[\r\n]+$", "")
			row = string.gsub(row, "[\r\n]", " ")
		end
		return row
	elseif tr == "table" then
		local n = #row
		local k = n + 1
		while row[k] ~= nil do n = k; k = k + 1 end
		local parts = {}
		for i = 1, n do
			local v = row[i]
			local tv = type(v)
			if tv == "string" then
				if string.find(v, "[\t\r\n]") then v = string.gsub(v, "[\t\r\n]", " ") end
				parts[i] = v
			elseif tv == "number" or tv == "boolean" then
				parts[i] = tostring(v)
			elseif v == nil then
				parts[i] = ""
			else
				parts[i] = "<" .. tv .. ">"
			end
		end
		return table.concat(parts, "\t")
	elseif row == nil then
		return ""
	end
	return tostring(row)
end

function DT.ed_key_ok(k)
	local ks = string.gsub(tostring(k), "(%l)(%u)", "%1_%2")
	local lk = string.lower(ks)
	local allow = DT.ed_allow
	for i = 1, #allow do
		if string.find(lk, allow[i], 1, true) then return true end
	end
	for w in string.gmatch(lk, "%w+") do
		if DT.ed_secret_words[w] then return false end
	end
	return true
end

function DT.show(v)
	if type(v) == "string" then

		if #v >= 32 and string.find(v, "^[%w%-_+/=%.]+$") and string.find(v, "%d") and string.find(v, "%a") then
			return '"<chuoi dai ' .. #v .. ' ky tu - da che>"'
		end
		local s = string.gsub(v, "%c", " ")
		if #s > 120 then s = string.sub(s, 1, 120) .. "..." end
		return '"' .. s .. '"'
	end
	return tostring(v)
end

function DT.count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function dt_idlike(k)
	return type(k) == "number" or tonumber(k) ~= nil
end

function DT.describe(t, ind, depth, out, path, limit)
	if #out >= limit then return end
	if path[t] then
		out[#out + 1] = ind .. "(vong lap)"
		return
	end
	path[t] = true
	local keys, nk = {}, 0
	for k in pairs(t) do
		if nk >= 3000 then break end
		nk = nk + 1
		keys[nk] = k
	end
	table.sort(keys, DT.key_less)
	local probe = math.min(nk, 8)
	local ntab, nid = 0, 0
	for i = 1, probe do
		if type(t[keys[i]]) == "table" then ntab = ntab + 1 end
		if dt_idlike(keys[i]) then nid = nid + 1 end
	end
	if nk >= 4 and ntab >= probe * 0.8 and nid >= probe * 0.8 then
		local ks = {}
		for i = 1, math.min(nk, 12) do ks[#ks + 1] = tostring(keys[i]) end
		out[#out + 1] = ind .. "keys(" .. nk .. (nk >= 3000 and "+" or "") .. "): " .. table.concat(ks, ",")
			.. (nk > 12 and ",..." or "")
		for i = 1, math.min(nk, 2) do
			local v = t[keys[i]]
			out[#out + 1] = ind .. "[" .. tostring(keys[i]) .. "]" .. (type(v) == "table" and "" or (" = " .. DT.show(v)))
			if type(v) == "table" and depth < DT.ed_depth then
				DT.describe(v, ind .. "  ", depth + 1, out, path, limit)
			end
		end
	else
		local shown = 0
		for i = 1, nk do
			if #out >= limit then break end
			if shown >= 250 then
				out[#out + 1] = ind .. "... (con " .. (nk - i + 1) .. " khoa nua)"
				break
			end
			local k = keys[i]
			local v = t[k]
			local tv = type(v)
			if DT.ed_key_ok(k) then
				if tv == "string" or tv == "number" or tv == "boolean" then
					out[#out + 1] = ind .. tostring(k) .. " = " .. DT.show(v)
					shown = shown + 1
				elseif tv == "table" then
					out[#out + 1] = ind .. tostring(k) .. " : table(" .. DT.count(v) .. ")"
					shown = shown + 1
					if depth < DT.ed_depth then DT.describe(v, ind .. "  ", depth + 1, out, path, limit) end
				elseif tv == "userdata" then
					out[#out + 1] = ind .. tostring(k) .. " : userdata"
					shown = shown + 1
				end
			end
		end
	end
	path[t] = nil
end

function DT.write_ed(st)
	local out = {}
	out[1] = "# OfflineMock " .. M.version .. " - tong quan du lieu tai khoan dang nap (_ED) - " .. os.date("%Y-%m-%d %H:%M:%S")
	local words = {}
	for w in pairs(DT.ed_secret_words) do words[#words + 1] = w end
	table.sort(words)
	out[2] = "# Da bo cac khoa co tu: " .. table.concat(words, ", ") .. " ; chuoi dai giong token (>=32 ky tu lien, co chu+so) bi che"
	local ED = rawget(_G, "_ED")
	if type(ED) ~= "table" then
		out[#out + 1] = "# _ED chua co (chua vao game)"
	else
		local keys, nk = {}, 0
		for k in pairs(ED) do
			nk = nk + 1
			keys[nk] = k
		end
		table.sort(keys, DT.key_less)
		out[#out + 1] = "== PHAN 1: cac khoa cap 1 cua _ED (" .. nk .. " khoa) =="
		local tabs = {}
		for i = 1, nk do
			local k = keys[i]
			local v = ED[k]
			local tv = type(v)
			if DT.ed_key_ok(k) then
				if tv == "string" or tv == "number" or tv == "boolean" then
					out[#out + 1] = tostring(k) .. " = " .. DT.show(v)
				elseif tv == "table" then
					out[#out + 1] = tostring(k) .. " : table(" .. DT.count(v) .. ")"
					tabs[#tabs + 1] = k
				elseif tv == "userdata" then
					out[#out + 1] = tostring(k) .. " : userdata"
				end
			end
		end
		out[#out + 1] = "== PHAN 2: chi tiet tung bang con =="
		for i = 1, #tabs do
			if #out >= DT.ed_max_lines then
				out[#out + 1] = "# (cat bot vi qua dai: con " .. (#tabs - i + 1) .. " bang chua ghi chi tiet)"
				break
			end
			out[#out + 1] = "-- " .. tostring(tabs[i])
			DT.describe(ED[tabs[i]], "  ", 2, out, { [ED] = true }, math.min(#out + DT.ed_sub_lines, DT.ed_max_lines))
		end
	end
	if ls_active() then
		local ok, tx = pcall(M.LS.status_text)
		if ok and tx ~= nil then out[#out + 1] = "# " .. tostring(tx) end
	end
	local text = table.concat(out, "\n") .. "\n"
	local f = io.open(st.base .. M.dump_ed_file, "wb")
	if not f then return nil end
	f:write(text)
	f:close()
	return #out
end

function DT.note(st, msg)
	if #st.errors < 150 then st.errors[#st.errors + 1] = msg end
end

function DT.file_name(st, name)
	local base = string.gsub(name, "[^%w_%-%.]", "_")
	if base == "" then base = "_" end
	local fn, n = base, 1
	while st.used[string.lower(fn)] do
		n = n + 1
		fn = base .. "_" .. n
	end
	st.used[string.lower(fn)] = true
	return fn
end

function DT.open_file(st, name)
	local fn = DT.file_name(st, name)
	if not st.flat then
		if st.tdir == nil then
			st.tdir = st.base .. M.dump_dir
			pcall(function() cc.FileUtils:getInstance():createDirectory(st.tdir) end)
		end
		local path = st.tdir .. fn .. ".txt"
		local f = io.open(path, "wb")
		if f then return path, f, M.dump_dir .. fn .. ".txt" end
		st.flat = true
	end
	local rel = "offline_tbl_" .. fn .. ".txt"
	local path = st.base .. rel
	local f = io.open(path, "wb")
	if f then return path, f, rel end
	return nil
end

function DT.begin(st)
	st.i = st.i + 1
	local name = st.names[st.i]
	local d = rawget(_G, "dms")
	local t = nil
	if type(d) == "table" then t = d[name] end
	local cur = { name = name, t = t, pos = 0, bytes = 0, cols = 0, n = 0, core_rows = 0 }
	st.cur = cur
	if type(t) ~= "table" then
		DT.close(st, cur, "da bi go khoi bo nho")
		return
	end
	local n = #t
	local total = DT.count(t)
	if total == n then
		cur.kind = "array"
		cur.n = n
	else

		local keys, nkeys, allnum, allstr = {}, 0, true, true
		for k in pairs(t) do
			nkeys = nkeys + 1
			keys[nkeys] = k
			local tk = type(k)
			if tk ~= "number" then allnum = false end
			if tk ~= "string" then allstr = false end
		end
		if allnum or allstr then
			table.sort(keys)
		else
			table.sort(keys, DT.key_less)
		end
		cur.kind = "keyed"
		cur.keys = keys
		cur.n = #keys
	end
	local path, f, rel = DT.open_file(st, name)
	cur.f, cur.rel = f, rel
	if f == nil then DT.note(st, name .. ": khong mo duoc file de ghi") end
	local core = st.core
	if core.f == nil then
		cur.core_state = "off"
	elseif core.full then
		cur.core_state = "skip"
	elseif DT.match_any(name, DT.text) then
		cur.core_state = "text"
	else
		cur.core_state = "in"
	end
end

function DT.emit(st, cur, chunk, nrows)
	local len = #chunk
	cur.bytes = cur.bytes + len
	st.total_bytes = st.total_bytes + len
	if cur.f ~= nil then
		local okw, err = cur.f:write(chunk)
		if not okw then
			DT.note(st, cur.name .. ": loi ghi file (" .. tostring(err) .. ")")
			pcall(function() cur.f:close() end)
			cur.f = nil
		end
	end
	if cur.core_state == "in" then
		local core = st.core
		local hdr = ""
		if not cur.core_hdr then
			hdr = "@@@ " .. cur.name .. " kind=" .. cur.kind .. " rows=" .. cur.n .. " cols=" .. cur.cols
				.. (cur.key_col ~= nil and (" key_col=" .. cur.key_col) or "") .. "\n"
		end
		if core.bytes + len + #hdr > M.dump_core_cap then
			cur.core_state = "cut"
			core.full = true
		else
			local okc = core.f:write(hdr, chunk)
			if okc then
				cur.core_hdr = true
				core.bytes = core.bytes + len + #hdr
				cur.core_rows = cur.core_rows + nrows
			else
				DT.note(st, "core: loi ghi file -> bo qua file core")
				cur.core_state = "cut"
				core.full = true
			end
		end
	end
end

function DT.rows(st, cur)
	local t, keys = cur.t, cur.keys
	local last = math.min(cur.pos + M.dump_chunk, cur.n)
	local lines, nl = {}, 0
	for i = cur.pos + 1, last do
		local key, row
		if keys ~= nil then
			key = keys[i]
			row = t[key]
		else
			row = t[i]
		end
		if row == nil then cur.holes = (cur.holes or 0) + 1 end
		local line = DT.row_line(row)
		if i == 1 then
			local cells = DT.split_cells(line)
			cur.cols = #cells
			local s = string.gsub(line, "\t", "|")
			if #s > 160 then s = string.sub(s, 1, 160) .. "..." end
			cur.sample = s
			if keys ~= nil then
				for c = 1, #cells do
					if DT.same_key(cells[c], key) then cur.key_col = c; break end
				end
			end
		end
		if keys ~= nil and cur.key_col ~= nil then
			if not DT.same_key(DT.nth_cell(line, cur.key_col), key) then cur.key_bad = (cur.key_bad or 0) + 1 end
		end
		nl = nl + 1
		lines[nl] = line
	end
	cur.pos = last
	if nl > 0 then DT.emit(st, cur, table.concat(lines, "\n") .. "\n", nl) end
	if cur.pos >= cur.n then DT.close(st, cur, nil) end
end

function DT.close(st, cur, note)
	if cur.f ~= nil then
		pcall(function() cur.f:close() end)
		cur.f = nil
	end
	local sch = rawget(_G, cur.name)
	local has_schema = false
	if type(sch) == "table" then
		for k, v in pairs(sch) do
			if type(k) == "string" and type(v) == "number" then has_schema = true; break end
		end
	end
	st.index[#st.index + 1] = {
		name = cur.name, kind = cur.kind or "?", rows = cur.n or 0, cols = cur.cols or 0, bytes = cur.bytes or 0,
		file = cur.rel, core = cur.core_state or "-", core_rows = cur.core_rows or 0, key_col = cur.key_col,
		key_bad = cur.key_bad, holes = cur.holes, sample = cur.sample, note = note, schema = has_schema,
	}
	st.total_rows = st.total_rows + (cur.n or 0)
	st.cur = nil
end

function DT.fail(st, msg)
	DT.note(st, "loi: " .. string.sub(tostring(msg), 1, 200))
	if st.cur ~= nil then DT.close(st, st.cur, "LOI: " .. string.sub(tostring(msg), 1, 80)) end
	if #st.errors >= 100 then st.abort = true end
end

function DT.write_index(st, secs)
	local out = {}
	local function add(s) out[#out + 1] = s end
	add("# OfflineMock " .. M.version .. " - DUMP BANG - " .. os.date("%Y-%m-%d %H:%M:%S"))
	add("# base=" .. st.base .. (st.flat and "  (ghi phang: offline_tbl_<ten>.txt)" or ("  thu muc bang=" .. M.dump_dir)))
	add("# ghi thu (thu tu): " .. table.concat(st.tried or {}, "  "))
	add("# mode=" .. tostring(M.mode) .. " in_game=" .. (st.in_game and "yes" or "no")
		.. " ls=" .. tostring(M.LS ~= nil and M.LS.VERSION or "-"))
	add("# tables=" .. #st.index .. " rows=" .. st.total_rows .. " bytes=" .. st.total_bytes
		.. " core_bytes=" .. st.core.bytes .. " core_cap=" .. M.dump_core_cap
		.. " errors=" .. #st.errors .. " elapsed=" .. secs .. "s ed_lines=" .. tostring(st.ed_lines))
	add("# cot (TAB): name kind rows cols bytes file core core_rows key_col key_bad holes schema sample note")
	add("# core: in = co trong file core | cut = bi cat do het cho | skip = het cho | text = bang chu giao dien | off = khong ghi duoc core")
	for i = 1, #st.index do
		local r = st.index[i]
		add(table.concat({
			r.name, r.kind, tostring(r.rows), tostring(r.cols), tostring(r.bytes), r.file or "-", r.core,
			tostring(r.core_rows), tostring(r.key_col or "-"), tostring(r.key_bad or 0), tostring(r.holes or 0),
			r.schema and "y" or "n", r.sample or "", r.note or "",
		}, "\t"))
	end
	if #st.errors > 0 then
		add("# loi:")
		for i = 1, #st.errors do add("#   " .. st.errors[i]) end
	end

	local dl = rawget(_G, "localData_list")
	if type(dl) == "table" then
		add("# localData_list (" .. #dl .. " muc):")
		for i = 1, math.min(#dl, 800) do add("#   " .. tostring(dl[i])) end
	end
	local f = io.open(st.base .. M.dump_index_file, "wb")
	if not f then return false end
	f:write(table.concat(out, "\n"), "\n")
	f:close()
	return true
end

function DT.finish(st)
	if st.core.f ~= nil then
		pcall(function() st.core.f:close() end)
		st.core.f = nil
	end
	local secs = os.time() - st.t0
	local ok, err = pcall(DT.write_index, st, secs)
	if not ok then DT.note(st, "loi ghi index: " .. tostring(err)) end
	local res = {
		tables = #st.index, rows = st.total_rows, bytes = st.total_bytes, errors = #st.errors, secs = secs,
		base = st.base, flat = st.flat, in_game = st.in_game, ed_lines = st.ed_lines,
		core_bytes = st.core.bytes, index_ok = ok,
	}
	M._dump_result = res
	M._dump = nil
	local msg = "DUMP XONG: " .. res.tables .. " bang, " .. string.format("%.1f", res.bytes / 1048576) .. " MB ("
		.. secs .. "s)\nThu muc: " .. st.base
		.. "\nGui 3 file: " .. M.dump_index_file .. ", " .. M.dump_core_file .. ", " .. M.dump_ed_file
	if not st.in_game then msg = msg .. "\n(CHUA vao game: bang con thieu. Vao game roi bam DUMP BANG lai.)" end
	if res.errors > 0 then msg = msg .. "\n(" .. res.errors .. " loi - xem cuoi file index)" end
	local hint = DT.pickup_hint(st.base)
	if hint ~= nil then msg = msg .. "\n(" .. hint .. ")" end
	notify(msg, 25)
	return true
end

function DT.step(st)
	if st.abort then return DT.finish(st) end
	if st.cur ~= nil then
		DT.rows(st, st.cur)
		return false
	end
	if st.i >= #st.names then return DT.finish(st) end
	DT.begin(st)
	return false
end

function M._dumpPump(all)
	local st = M._dump
	if st == nil then return true end
	local t0 = os.clock()
	local steps = 0
	while true do
		local ok, done = pcall(DT.step, st)
		if not ok then
			DT.fail(st, done)
			done = false
		end
		if done then
			pcall(M.omRender)
			pcall(hud_tick)
			return true
		end
		steps = steps + 1
		if not all and (steps >= M.dump_steps or os.clock() - t0 >= M.dump_budget) then break end
	end
	pcall(hud_tick)
	return false
end

function M.dumpTables()
	local run = M._dump
	if run ~= nil then
		notify("DUMP BANG dang chay: " .. run.i .. "/" .. #run.names .. " - cho xiu (game van choi duoc).", 4)
		return false
	end
	if type(rawget(_G, "dms")) ~= "table" then
		notify("DUMP BANG: game chua nap bang du lieu (dms). Vao game roi bam lai.", 6)
		return false
	end
	local names = DT.list_tables()
	if #names == 0 then
		notify("DUMP BANG: chua co bang nao duoc nap. Vao game (qua man dang nhap) roi bam lai.", 6)
		return false
	end
	local base, tried = DT.pick_base()
	if base == nil then
		notify("DUMP BANG: khong ghi duoc file o dau ca (Download / Android/media / Android/data / bo nho app).", 8)
		return false
	end
	local ED = rawget(_G, "_ED")
	local st = {
		names = names, i = 0, base = base, tried = tried, index = {}, errors = {}, used = {}, total_rows = 0, total_bytes = 0,
		t0 = os.time(), core = { bytes = 0, full = false },
		in_game = type(ED) == "table" and type(ED.user_info) == "table",
	}
	local oked, edn = pcall(DT.write_ed, st)
	if oked then st.ed_lines = edn else DT.note(st, "loi ghi tong quan _ED: " .. tostring(edn)) end
	local cf = io.open(base .. M.dump_core_file, "wb")
	if cf then
		cf:write("# OfflineMock " .. M.version .. " - DUMP BANG core - " .. os.date("%Y-%m-%d %H:%M:%S")
			.. "\n# moi bang bat dau bang dong '@@@ ten kind=.. rows=.. cols=..'; cac dong sau la hang (cot cach nhau TAB)\n")
		st.core.f = cf
	else
		DT.note(st, "khong mo duoc file core")
	end
	M._dump = st
	notify("DUMP BANG: bat dau, " .. #names .. " bang -> " .. base .. "\nHUD hien tien do; xong se bao.", 8)
	if not schedule(M.dump_period, function() return M._dumpPump(false) end) then
		M._dumpPump(true)
	end
	return true
end

do
local function init_auto()

M.auto_list = {
	{ "user_create_time", { "" } },
	{ "daily_mission_init", { "" } },
	{ "activity_init", { "" } },
	{ "email_init", { "2\r\n1\r\n30", "0\r\n1\r\n30", "-1\r\n1\r\n30", "1\r\n1\r\n30" } },
	{ "task_init", { "" } },
	{ "shop_view", { "1", "0" } },
	{ "arena_init", { "0" } },
	{ "union_init", { "0" } },
	{ "first_charge_init", { "" } },
	{ "reward_center_init", { "" } },
	{ "get_user_level_rank_info", { "" } },
	{ "top_rank_init", { "" } },
	{ "black_shop_init", { "" } },
	{ "secret_travel_init", { "" } },
	{ "view_draw_items", { "" } },
	{ "get_online_gift_info", { "" } },
	{ "activity_fortune_cat_init", { "" } },
	{ "activity_group_buy_init", { "" } },
	{ "activity_orders_world_glory_list", { "" } },
	{ "activity_orders_world_init", { "" } },
	{ "activity_pokemon_master_init", { "" } },
	{ "activity_time_limit_rank_init", { "" } },
	{ "answer_init", { "" } },
	{ "arena_shop_init", { "0\r\n0", "1\r\n", "1" } },
	{ "artifact_init", { "" } },
	{ "awaken_shop_init", { "" } },
	{ "biographies_init", { "" } },
	{ "camp_duel_init", { "" } },
	{ "camp_duel_rank_list_get", { "1", "0" } },
	{ "celebrity_bulletin_init", { "0", "1" } },
	{ "check_title_state", { "" } },
	{ "city_resource_hold_init", { "" } },
	{ "combine_ship_init", { "" } },
	{ "cross_arena_battle_report_list", { "" } },
	{ "cross_arena_init", { "" } },
	{ "cross_arena_remaining_challenges", { "" } },
	{ "cross_arena_shop_init", { "" } },
	{ "cross_mine_init", { "" } },
	{ "cross_mine_ref_user_mine_and_server_info", { "" } },
	{ "cross_time_limit_jackpot_init", { "" } },
	{ "cross_time_limit_jackpot_rank", { "" } },
	{ "destiny_init", { "" } },
	{ "dignified_shop_init", { "" } },
	{ "dinner_init", { "" } },
	{ "egg_frenzy_init", { "" } },
	{ "enemy_boss_init", { "" } },
	{ "enemy_boss_rank_list_get", { "0", "1" } },
	{ "expedition_init", { "" } },
	{ "extreme_init", { "" } },
	{ "extreme_rank_get", { "" } },
	{ "fileIslandBossInfo", { "" } },
	{ "fileIslandShopInfo", { "" } },
	{ "fileIslandTaskInfo", { "" } },
	{ "fortune_init", { "" } },
	{ "friend_update", { "" } },
	{ "get_lucky_divine_info", { "" } },
	{ "get_lucky_divine_rank_info", { "" } },
	{ "get_lucky_pull_rod_lottery_record", { "" } },
	{ "get_mineral_prop_list", { "" } },
	{ "get_open_server_rank_info", { "23", "40" } },
	{ "get_recuit_horse_info", { "" } },
	{ "get_ship_count", { "" } },
	{ "get_union_create_info", { "" } },
	{ "get_user_mail", { "" } },
	{ "get_warfare_ranking", { "" } },
	{ "get_warfare_task", { "" } },
	{ "glories_shop_init", { "" } },
	{ "gm_message_init", { "" } },
	{ "guard_list_init", { "" } },
	{ "guard_order_list", { "1", "0" } },
	{ "guard_stronghold_init", { "" } },
	{ "half_the_ritual_init", { "" } },
	{ "hold_integral_init", { "" } },
	{ "limit_blessing_init", { "" } },
	{ "limited_recharge_init", { "" } },
	{ "lucky_match_init", { "" } },
	{ "lucky_pull_rod_init", { "" } },
	{ "lucky_turntable_init", { "" } },
	{ "magical_animals_init", { "" } },
	{ "map_scattered_init", { "" } },
	{ "mineral_workspace_init", { "" } },
	{ "monopoly_init", { "" } },
	{ "monopoly_reward_log", { "" } },
	{ "new_share_reward_init", { "" } },
	{ "normal_war_order_init", { "" } },
	{ "old_user_back_recharge_init", { "" } },
	{ "old_user_back_seven_day_init", { "" } },
	{ "on_hook_init", { "" } },
	{ "partner_bounty_init", { "" } },
	{ "pet_counterpart_init", { "" } },
	{ "pet_shop_init", { "1" } },
	{ "pokemon_explore_boss_info", { "" } },
	{ "pokemon_world_boss_init", { "" } },
	{ "privilege_card_init", { "" } },
	{ "rebel_army_init", { "" } },
	{ "rebel_boss_init", { "" } },
	{ "rebel_exploit_shop_init", { "" } },
	{ "rebel_haunt_list_init", { "" } },
	{ "recharge_rank_init", { "" } },
	{ "refush_msg", { "" } },
	{ "search_order_list", { "16", "11", "12", "10", "2", "6" } },
	{ "seven_day_recharge_init", { "" } },
	{ "share_reward_init", { "" } },
	{ "ship_comment_init", { "" } },
	{ "ship_military_init", { "" } },
	{ "ship_purify_init", { "" } },
	{ "ship_talent_init", { "" } },
	{ "shop_frags_init", { "" } },
	{ "show_self_message", { "" } },
	{ "show_ship_mould_list", { "" } },
	{ "sky_temple_init", { "" } },
	{ "summer_cool_weal_init", { "" } },
	{ "team_arena_battle_report_list", { "" } },
	{ "the_kings_battle_init", { "" } },
	{ "the_kings_battle_self_battle_peakedness_duel_info", { "" } },
	{ "the_kings_battle_self_init", { "" } },
	{ "three_kingdoms_init", { "" } },
	{ "three_kings_get_rank_info", { "" } },
	{ "time_limit_jackpot_init", { "" } },
	{ "time_limit_jackpot_rank", { "" } },
	{ "union_active_init", { "" } },
	{ "union_assistance_all_record", { "" } },
	{ "union_assistance_init", { "" } },
	{ "union_copy_get_lucky_reward_info", { "" } },
	{ "union_copy_init", { "" } },
	{ "union_craft_init", { "" } },
	{ "union_craft_rank_list_get", { "" } },
	{ "union_pve_init", { "" } },
	{ "union_ship_slot_machine_get_rank", { "" } },
	{ "union_ship_train_init", { "" } },
	{ "union_warfare_init", { "" } },
	{ "user_build_war_order_init", { "" } },
	{ "user_card_info_init", { "" } },
	{ "user_card_info_rank", { "" } },
	{ "user_combat_force_order_reward_init", { "" } },
	{ "user_stronghold_init", { "" } },
	{ "warfare_get_my_fight_info", { "" } },
	{ "world_city_list_get", { "" } },
	{ "world_city_shop_init", { "" } },
	{ "world_info_init", { "" } },
}

M.auto_period   = 0.4
M.auto_gap      = 0.9
M.auto_timeout  = 20
M.auto_max_fail = 8
M.auto_ud_key   = "offline_auto_done"

local SESSION_BAD = { [3] = true, [4] = true, [5] = true, [6] = true, [21] = true, [269] = true, [305] = true,
	[306] = true, [493] = true, [243] = true }

local function queue_of()
	local NM = rawget(_G, "NetworkManager")
	if type(NM) == "table" and type(NM.queue) == "table" then return NM, NM.queue end
	return nil, nil
end

local function remove_from_queue(q, req)
	for k = #q, 1, -1 do
		if q[k] == req then table.remove(q, k) end
	end
end

local function guard_views()
	M._auto_guards = M._auto_guards or {}
	local G = M._auto_guards
	local NV = rawget(_G, "NetworkView")
	if type(NV) == "table" then
		for _, fname in ipairs({ "protocolErrorViewDisplay", "networkErrorViewDisplay", "reconnectViewDisplay" }) do
			local cur = NV[fname]
			if type(cur) == "function" and G[fname] ~= cur then
				local orig = cur
				local wrapper = function(self, req, ...)
					if type(req) == "table" and req.om_crawl then return end
					return orig(self, req, ...)
				end
				NV[fname] = wrapper
				G[fname] = wrapper
			end
		end
	end
	local NP = rawget(_G, "NetworkProtocol")
	if type(NP) == "table" and type(NP.parser_func) == "function" and G.parser_func ~= NP.parser_func then
		local orig = NP.parser_func
		local wrapper = function(data, ...)
			if type(data) == "table" and data.om_crawl then
				local list = data.resouce_serializer
				if list == nil and type(data.resouce) == "string" then
					list = split_tokens(data.resouce)
					data.resouce_serializer = list
				end
				if type(list) ~= "table" then return end
				local st = tonumber(list[3])
				if st == nil then
					data.PROTOCOL_STATUS = nil
					return
				end
				if st < 0 then

					data.PROTOCOL_STATUS = st
					return
				end

				local keep = list[2]
				list[2] = "om_crawl"
				local ok, err = pcall(orig, data, ...)
				list[2] = keep
				if not ok then
					data.om_crawl_err = tostring(err)
					logmsg("TU GHI: loi khi doc phan hoi", tostring(data.om_crawl_name), tostring(err))
				end
				return
			end
			return orig(data, ...)
		end
		NP.parser_func = wrapper
		G.parser_func = wrapper
	end
end

local function logged_in()
	local ed = rawget(_G, "_ED")
	local uid = type(ed) == "table" and type(ed.user_info) == "table" and ed.user_info.user_id or nil
	return uid ~= nil and tonumber(uid) ~= nil and tonumber(uid) > 0
end

local function tutorial_open()
	local fw = rawget(_G, "fwin")
	if type(fw) ~= "table" or type(fw.find) ~= "function" then return false end
	local okf, w = pcall(fw.find, fw, "TuitionControllerClass")
	return okf and w ~= nil
end

local STOP_TEXT = {
	tutorial = "TU GHI dung: game dang hien huong dan tan thu. Xong huong dan roi bam lai.",
	login = "TU GHI dung: khong con o trong tai khoan (da thoat/dang nhap lai). Vao game roi bam lai.",
	user = "Da dung TU GHI. Nhung lenh da ghi van duoc giu.",
	mode = "TU GHI dung: da doi che do.",
	nonet = "TU GHI dung: khong thay hang doi mang cua game.",
}

local function finish(st, reason, code)
	if not st.running then return end
	st.running = false
	st.reason = reason
	st.code = code
	st.t_end = os.time()
	local total = #st.items
	local text
	if reason == "done" then
		text = "TU GHI XONG: " .. total .. " lenh - ghi duoc " .. st.ok .. ", server tu choi " .. st.err
			.. ", loi mang " .. st.fail .. ".\nGio chon OM -> OFFLINE, thoat han game, mo lai."
		if M._rf ~= nil then
			text = "TU GHI XONG: " .. total .. " lenh - ghi duoc " .. st.ok .. ", server tu choi " .. st.err
				.. ", loi mang " .. st.fail .. ".\nDang gop vao ban ghi cu..."
		end
		if st.ok >= 5 then ud_set(M.auto_ud_key, tostring(os.time())) end
	elseif reason == "net" then
		text = "TU GHI dung: mang loi lien tiep " .. st.consec_fail .. " lenh (da ghi " .. st.ok .. "). Kiem tra mang roi bam lai."
	elseif reason == "session" then
		text = "TU GHI dung: server bao phien dang nhap co van de (ma -" .. tostring(code) .. "). Vao lai game roi bam lai."
	else
		text = STOP_TEXT[reason] or ("TU GHI dung (" .. tostring(reason) .. ").")
	end
	st.summary = text
	notify(text, 14)
	if M.refreshOnFinish ~= nil then pcall(M.refreshOnFinish, st, reason) end
end

function M.autoActive()
	return M.auto ~= nil and M.auto.running == true
end

function M.autoStop(reason, code)
	local st = M.auto
	if st == nil or not st.running then return false end

	local NM, q = queue_of()
	if st.cur ~= nil and q ~= nil then
		remove_from_queue(q, st.cur.req)
		st.cur = nil
		pcall(function() rawget(_G, "NetworkView"):connectingErase() end)
	end
	finish(st, reason or "user", code)
	return true
end

function M.autoStart()
	local st = M.auto
	if st ~= nil and st.running then return false, "running" end
	if M.getMode() ~= "record" then
		notify("TU GHI chi chay o che do GHI (online): OM -> GHI -> thoat han game -> mo lai, dang nhap vao game -> OM -> TU GHI.", 10)
		return false, "mode"
	end
	local NM, q = queue_of()
	local NP = rawget(_G, "NetworkProtocol")
	local PC = rawget(_G, "protocol_command")
	if NM == nil or type(NP) ~= "table" or type(PC) ~= "table" or not F.send then
		notify("TU GHI: chua gan duoc vao mang cua game (send:" .. (F.send and "OK" or "-") .. "). Doi vai giay roi bam lai.", 8)
		return false, "nonet"
	end
	if not logged_in() then
		notify("TU GHI: hay dang nhap vao game (man hinh chinh) roi moi bam.", 8)
		return false, "login"
	end
	if tutorial_open() then
		notify(STOP_TEXT.tutorial, 8)
		return false, "tutorial"
	end
	local items = {}
	for _, ent in ipairs(M.auto_list) do
		local pc = PC[ent[1]]
		if type(pc) == "table" and type(pc.code) == "number" and type(pc.command_fun) == "function" then
			for _, p in ipairs(ent[2]) do
				items[#items + 1] = { name = ent[1], param = p }
			end
		end
	end
	if #items == 0 then
		notify("TU GHI: khong tim thay lenh nao de goi (ban game khac?).", 8)
		return false, "empty"
	end
	pcall(guard_views)
	M.auto = { running = true, items = items, i = 1, clock = 0, gap_until = 0, ok = 0, err = 0, fail = 0, skip = 0,
		consec_fail = 0, processed = 0, sent = 0, t_start = os.time(), parse_err = 0 }
	M._rec_before_auto = M._rec_count or 0
	notify("TU GHI bat dau: " .. #items .. " lenh, khoang " .. math.ceil(#items * (M.auto_gap + 1.0) / 60)
		.. " phut. Cu de may o man hinh chinh.", 10)
	return true
end

function M.autoToggle()
	if M.autoActive() then
		M.autoStop("user")
		return false
	end
	return (M.autoStart())
end

local function send_item(st, it)
	local PC = rawget(_G, "protocol_command")
	local NP = rawget(_G, "NetworkProtocol")
	local NM, q = queue_of()
	local pc = PC[it.name]
	if type(pc) ~= "table" or type(pc.code) ~= "number" then
		st.skip = st.skip + 1
		st.processed = st.processed + 1
		return
	end
	local old = pc.param_list
	pc.param_list = it.param
	local req
	local okreg = pcall(function()
		req = NM:register(pc.code, nil, nil, nil, nil, nil, false, nil, true)
	end)
	if not okreg or type(req) ~= "table" then
		pc.param_list = old
		st.skip = st.skip + 1
		st.processed = st.processed + 1
		return
	end
	req.om_crawl = true
	req.om_crawl_name = it.name
	local ok, str = pcall(NP.command_func, pc.code, req)
	pc.param_list = old
	if not ok or type(str) ~= "string" or str == "" then
		remove_from_queue(q, req)
		logmsg("TU GHI: khong dung duoc yeu cau", it.name, tostring(str))
		st.skip = st.skip + 1
		st.processed = st.processed + 1
		return
	end
	req.str = str
	st.cur = { req = req, name = it.name, t0 = st.clock }
	st.sent = st.sent + 1
end

function M.autoStep(dt)
	local st = M.auto
	if st == nil or not st.running then return end
	st.clock = st.clock + (tonumber(dt) or M.auto_period)
	local NM, q = queue_of()
	if NM == nil then
		finish(st, "nonet")
		return
	end
	if M.getMode() ~= "record" then
		finish(st, "mode")
		return
	end
	if tutorial_open() then
		M.autoStop("tutorial")
		return
	end
	if not logged_in() then
		M.autoStop("login")
		return
	end
	local cur = st.cur
	if cur ~= nil then
		local inq = false
		for k = 1, #q do
			if q[k] == cur.req then inq = true break end
		end
		if inq then
			if st.clock - cur.t0 > M.auto_timeout then

				remove_from_queue(q, cur.req)
				pcall(function() rawget(_G, "NetworkView"):connectingErase() end)
				st.cur = nil
				st.fail = st.fail + 1
				st.consec_fail = st.consec_fail + 1
				st.processed = st.processed + 1
				st.gap_until = st.clock + M.auto_gap
				if st.consec_fail >= M.auto_max_fail then finish(st, "net") end
			end
			return
		end

		st.cur = nil
		local req = cur.req
		local status = tonumber(req.PROTOCOL_STATUS)
		st.processed = st.processed + 1
		if req.om_crawl_err ~= nil then st.parse_err = st.parse_err + 1 end
		if req.RESPONSE_SUCCESS == true and status ~= nil and status >= 0 then
			st.ok = st.ok + 1
			st.consec_fail = 0
		elseif req.RESPONSE_SUCCESS == true and status ~= nil then
			st.err = st.err + 1
			st.consec_fail = 0
			if SESSION_BAD[-status] then
				finish(st, "session", -status)
				return
			end
		else
			st.fail = st.fail + 1
			st.consec_fail = st.consec_fail + 1
			if st.consec_fail >= M.auto_max_fail then
				finish(st, "net")
				return
			end
		end
		st.gap_until = st.clock + M.auto_gap
		return
	end
	if st.clock < st.gap_until then return end
	if #q > 0 then return end
	if st.i > #st.items then
		finish(st, "done")
		return
	end
	local it = st.items[st.i]
	st.i = st.i + 1
	send_item(st, it)
end

function M.autoHud()
	local st = M.auto
	if st == nil or not st.running then return "" end
	return " | TU GHI " .. st.processed .. "/" .. #st.items
end

function M.autoSig()
	local st = M.auto
	if st == nil then return "a-" end
	return "a" .. (st.running and "1" or "0") .. st.processed .. (st.reason or "")
end

function M.autoInfo()
	local st = M.auto
	if st == nil then return nil end
	local total = #st.items
	if st.running then
		return "TU GHI: " .. st.processed .. "/" .. total .. " lenh | ghi " .. st.ok .. ", tu choi " .. st.err .. ", loi mang " .. st.fail,
			"Dang goi: " .. (st.cur ~= nil and st.cur.name or "...") .. "  (bam TU GHI lai de dung)"
	end
	local why = ({ done = "xong", user = "da dung", net = "mang loi", session = "phien loi", mode = "doi che do",
		nonet = "khong co mang", tutorial = "huong dan tan thu", login = "thoat tai khoan" })[st.reason or ""] or tostring(st.reason)
	return "Lan TU GHI truoc (" .. why .. "): ghi " .. st.ok .. "/" .. total .. ", tu choi " .. st.err .. ", loi mang " .. st.fail,
		"Bam TU GHI de chay lai. Tong ban ghi phien nay: " .. tostring(M._rec_count or 0)
end

function M.autoOffer()
	if M._auto_offered or M.mode ~= "record" or M.auto ~= nil then return end
	if not logged_in() or (M._rec_count or 0) < 10 then return end
	M._auto_offered = true
	if ud_get(M.auto_ud_key) ~= nil then return end
	notify("OfflineMock: de co DU du lieu offline chi can bam nut OM -> TU GHI (tu dong, khoang 5 phut).", 10)
end

function M.autoSchedule()
	if M._auto_scheduled then return end
	M._auto_scheduled = true
	schedule(M.auto_period, function(dt)
		pcall(M.autoStep, dt)
		return false
	end)
end

end
init_auto()
end

local OM_BTN_NAME   = "offlinemock_om_btn"
local OM_PANEL_NAME = "offlinemock_om_panel"
local Z_OM          = 1000002
local OM_BTN_W, OM_BTN_H = 64, 32
local OM_MODES = { "record", "replay", "off" }
local OM_LABEL = {
	record = "GHI - choi online + ghi lai du lieu",
	replay = "SEVER TEST",
	off    = "TAT - game online nhu goc",
}
local OM_COLOR = { record = { 150, 55, 55 }, replay = { 35, 110, 50 }, off = { 80, 80, 80 } }

local function om_btn_rect(size)
	return { x = size.width - OM_BTN_W - 6, y = size.height * M.om_button_y, w = OM_BTN_W, h = OM_BTN_H }
end

local function om_layout(size)
	local pw = math.min(size.width - 16, 520)
	local small = size.height < 440
	local L = { pw = pw, small = small }
	L.modes = {}
	if small then
		L.ph = 270
		for i = 1, 3 do
			L.modes[i] = { x = 20, y = 136 - (i - 1) * 40, w = pw - 40, h = 34 }
		end
		L.close = { x = math.floor(pw / 2) - 50, y = 4, w = 100, h = 34 }
	else
		L.ph = 330
		for i = 1, 3 do
			L.modes[i] = { x = 20, y = 188 - (i - 1) * 56, w = pw - 40, h = 46 }
		end
		L.close = { x = math.floor(pw / 2) - 50, y = 6, w = 100, h = 34 }
	end
	L.x = math.floor((size.width - pw) / 2)
	L.y = math.max(4, math.floor((size.height - L.ph) / 2))
	return L
end
M._om_btn_rect = om_btn_rect
M._om_layout = om_layout

local function om_sig()
	return tostring(M.mode) .. "|" .. tostring(M._pending_mode())
end

local function om_panel_sig()
	local dp, dres = M._dump, M._dump_result
	local d = "n"
	if dp ~= nil then
		d = "d" .. tostring(dp.i)
	elseif dres ~= nil then
		d = "r" .. tostring(dres.tables) .. "_" .. tostring(dres.bytes)
	end
	return om_sig() .. "|" .. d .. "|" .. (M.autoSig ~= nil and M.autoSig() or "")
end

local function om_build_panel(scene, L)
	local bg = cc.LayerColor:create(cc.c4b(0, 0, 0, 230), L.pw, L.ph)
	bg:setPosition(cc.p(L.x, L.y))
	pcall(function() bg:setName(OM_PANEL_NAME) end)
	new_label(bg, "OfflineMock " .. M.version .. " - CHON CHE DO", 20, L.pw / 2, L.ph - 22, 0.5)
	local cur = new_label(bg, "Dang chay: " .. (MODE_NAME[M.mode] or tostring(M.mode)), 17, L.pw / 2, L.ph - 52, 0.5)
	pcall(function() cur:setColor(cc.c3b(150, 230, 255)) end)
	local pend = M._pending_mode()
	local pl
	if pend ~= nil then
		pl = new_label(bg, "Lan mo game sau: " .. MODE_NAME[pend] .. " (THOAT HAN game roi mo lai)", 15, L.pw / 2, L.ph - 78, 0.5)
		pcall(function() pl:setColor(cc.c3b(255, 235, 59)) end)
	else
		pl = new_label(bg, "Chon xong phai THOAT HAN game roi mo lai.", 15, L.pw / 2, L.ph - 78, 0.5)
		pcall(function() pl:setColor(cc.c3b(200, 200, 200)) end)
	end
	for i = 1, 3 do
		local mode = OM_MODES[i]
		local c = OM_COLOR[mode]
		local label = OM_LABEL[mode]
		if mode == M.mode then label = "> " .. label end
		if pend == mode then label = label .. "  [SE DUNG]" end
		new_button(bg, L.modes[i], label, 16, cc.c4b(c[1], c[2], c[3], mode == M.mode and 255 or 190))
	end

	new_button(bg, L.close, "DONG", 18, cc.c4b(130, 40, 40, 255))
	scene:addChild(bg, Z_OM)
	return bg
end

function M.omRender()
	local scene = running_scene()
	if scene == nil then return end
	local size = visible_size()
	M._om_btn_sigs = M._om_btn_sigs or setmetatable({}, { __mode = "k" })
	local btn = scene:getChildByName(OM_BTN_NAME)
	local bsig = om_sig()
	if M.om_button then
		if btn ~= nil and M._om_btn_sigs[btn] ~= bsig then
			btn:removeFromParent()
			btn = nil
		end
		if btn == nil then
			local r = om_btn_rect(size)
			local node = cc.Node:create()
			pcall(function() node:setName(OM_BTN_NAME) end)
			local c = OM_COLOR[M.mode] or OM_COLOR.off
			new_button(node, r, M._pending_mode() ~= nil and "OM*" or "OM", 20, cc.c4b(c[1], c[2], c[3], 200))
			scene:addChild(node, Z_OM)
			M._om_btn_sigs[node] = bsig
		end
	elseif btn ~= nil then
		btn:removeFromParent()
	end

	local panel = scene:getChildByName(OM_PANEL_NAME)
	if M.om_button and M._om_open then
		local psig = om_panel_sig()
		if panel == nil or M._om_sig ~= psig then
			if panel ~= nil then panel:removeFromParent() end
			om_build_panel(scene, om_layout(size))
			M._om_sig = psig
		end
	elseif panel ~= nil then
		panel:removeFromParent()
		M._om_sig = nil
	end
end

function M.omClose()
	M._om_open = false
	M._om_sig = nil
	pcall(M.omRender)
end

function M._omTouch(loc)
	if not M.om_button then return false end
	local scene = running_scene()
	if scene == nil then return false end
	local size = visible_size()
	if not M._om_open then
		if M._gm_open then return false end
		local btn = scene:getChildByName(OM_BTN_NAME)
		if btn == nil then return false end
		local p = btn:convertToNodeSpace(loc)
		if in_rect(p.x, p.y, om_btn_rect(size)) then
			M._om_open = true
			M._om_sig = nil
			pcall(M.omRender)
			return true
		end
		return false
	end

	local panel = scene:getChildByName(OM_PANEL_NAME)
	if panel == nil then
		pcall(M.omRender)
		panel = scene:getChildByName(OM_PANEL_NAME)
		if panel == nil then return true end
	end
	local L = om_layout(size)
	local p = panel:convertToNodeSpace(loc)
	local lx, ly = p.x, p.y
	if lx < 0 or ly < 0 or lx > L.pw or ly > L.ph then
		M.omClose()
		return true
	end
	if in_rect(lx, ly, L.close) then
		M.omClose()
		return true
	end
	for i = 1, 3 do
		if in_rect(lx, ly, L.modes[i]) then
			M.setMode(OM_MODES[i])
			M._om_sig = nil
			pcall(M.omRender)
			pcall(hud_tick)
			return true
		end
	end
	return true
end

-- ======================================================================= TN: bang chon tuong cho Tournament (Dinh cao doi quyet)
-- Nut "TN" (mep phai, duoi nut GM) chi hien khi dang mo man Tournament (SmBattleofKingsWindowClass). Bam vao: bang chon
-- 8 doi x 1-3 tuong (LocalServer.tn_*). BAT DAU -> LocalServer chay 7 tran bang engine that (moi frame mot buoc),
-- xong thi bam MO LAI MAN de client doc lai bang dau + xem replay bang nut "xem" co san cua game.
-- Bang duoc ve trong "khong gian thiet ke" (840 hoac 1040 x 500) roi phong/thu theo man hinh (root:setScale), nen o
-- cham du to tren man hinh nhieu pixel; moi toa do cham doi ve khong gian thiet ke bang root:convertToNodeSpace.
do
	local TP_BTN_NAME   = "offlinemock_tp_btn"
	local TP_PANEL_NAME = "offlinemock_tp_panel"
	local Z_TP          = 1000003
	local TP_BTN_W, TP_BTN_H = 64, 32
	local TP_PH = 500
	local NSLOT = 8
	local PAD = 8
	M.tp_button_y = 0.30
	M._tp = M._tp or { page = 1 }

	-- mau tao luc dung (khong dung cc.* luc nap file: loi o day se lam hong ca OfflineMock)
	local COL, CB = nil, nil
	local function tp_colors()
		if COL == nil then
			COL = {
				idle = cc.c3b(200, 200, 200), run = cc.c3b(255, 235, 59), ok = cc.c3b(120, 230, 120),
				err = cc.c3b(255, 130, 130), warn = cc.c3b(255, 180, 80), dim = cc.c3b(130, 130, 130),
			}
			CB = {
				bg = cc.c4b(0, 0, 0, 238), empty = cc.c4b(58, 58, 74, 255), filled = cc.c4b(35, 85, 150, 255),
				sel = cc.c4b(190, 150, 20, 255), off = cc.c4b(28, 28, 34, 255), normal = cc.c4b(48, 48, 64, 255),
				used = cc.c4b(35, 105, 70, 255), nav = cc.c4b(70, 70, 90, 255), dis = cc.c4b(45, 45, 50, 255),
				rnd = cc.c4b(40, 110, 120, 255), clr = cc.c4b(125, 60, 55, 255), go = cc.c4b(35, 130, 55, 255),
				cancel = cc.c4b(170, 70, 40, 255), re = cc.c4b(45, 95, 160, 255), x = cc.c4b(130, 40, 40, 255),
				btn_idle = cc.c4b(20, 110, 130, 220), btn_run = cc.c4b(150, 100, 0, 220),
				bar_back = cc.c4b(60, 60, 60, 255), bar_fill = cc.c4b(255, 200, 40, 255),
			}
		end
		return COL, CB
	end

	local function clamp(v, lo, hi)
		if v < lo then return lo end
		if v > hi then return hi end
		return v
	end

	-- [FIX TN] nut/bang TN chi phu thuoc che do replay (LocalServer) + dang mo man Tournament, KHONG phu thuoc
	-- nut GM (gm_button / "AN HUD/NUT"): GM bi an thi TN van hien va bam duoc, giong nut OM.
	-- (khong khai bao local moi o day: OfflineMock dang gan gioi han 200 local cua Lua)
	function M.tpEnabled()
		return M.getMode() == "replay"
	end

	local function tp_win_open()
		local fw = rawget(_G, "fwin")
		if type(fw) ~= "table" or type(fw.find) ~= "function" then return false end
		local ok, w = pcall(fw.find, fw, "SmBattleofKingsWindowClass")
		return ok and w ~= nil
	end

	local function tp_api()
		local LS = M.LS
		if LS == nil or type(LS.tn_info) ~= "function" or type(LS.tn_start) ~= "function" then return nil end
		return LS
	end

	local function tp_info()
		local LS = tp_api()
		if LS == nil or not ls_active() then return nil end
		local ok, info = pcall(LS.tn_info)
		if ok and type(info) == "table" and type(info.slots) == "table" then return info end
		return nil
	end

	-- "3.Vegeta_SSGSS_" -> "3.Vegeta SSGSS"
	local function tp_show(name)
		local s = tostring(name or "?")
		s = string.gsub(s, "_", " ")
		s = string.gsub(s, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		if s == "" then s = "?" end
		return s
	end

	-- cat chuoi UTF-8 theo do rong o (khong cat giua ky tu nhieu byte)
	local function tp_fit(s, w, fs)
		local maxc = math.max(3, math.floor((w - 8) / (fs * 0.58)))
		local chars = {}
		for ch in string.gmatch(s, "[\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
		if #chars <= maxc then return s end
		return table.concat(chars, "", 1, maxc - 1) .. "."
	end

	-- danh sach tuong sap theo ten (bo nho dem; dung lai khi pool khong doi)
	local function tp_heroes()
		local LS = tp_api()
		if LS == nil or type(LS.tn_pool) ~= "function" or type(LS.tn_name) ~= "function" then return {}, {}, {} end
		local ok, pool = pcall(LS.tn_pool)
		if not ok or type(pool) ~= "table" then return {}, {}, {} end
		local c = M._tp.cache
		if c ~= nil and c.n == #pool and c.first == pool[1] and c.last == pool[#pool] then return c.list, c.by_id, c.letter end
		local list, by_id, letter = {}, {}, {}
		for _, id in ipairs(pool) do
			local okn, nm = pcall(LS.tn_name, id)
			local show = tp_show(okn and nm or id)
			local h = { id = id, name = show, key = string.lower(show) }
			list[#list + 1] = h
			by_id[id] = h
		end
		table.sort(list, function(a, b)
			if a.key ~= b.key then return a.key < b.key end
			return a.id < b.id
		end)
		for i, h in ipairs(list) do
			local l = string.sub(h.key, 1, 1)
			if letter[l] == nil then letter[l] = i end
		end
		M._tp.cache = { n = #pool, first = pool[1], last = pool[#pool], list = list, by_id = by_id, letter = letter }
		return list, by_id, letter
	end

	local function tp_btn_rect(size)
		return { x = size.width - TP_BTN_W - 6, y = size.height * M.tp_button_y, w = TP_BTN_W, h = TP_BTN_H }
	end

	-- kich thuoc khong gian thiet ke + he so phong/thu
	local function tp_dims(size)
		local pw = (size.width >= size.height * 1.9) and 1040 or 840
		local k = math.min(size.width / (pw + 20), size.height / (TP_PH + 20))
		return pw, TP_PH, clamp(k, 0.3, 2.4)
	end

	-- bo cuc (toa do trong khong gian thiet ke, goc duoi-trai); chi phu thuoc ty le man hinh + so tuong
	local function tp_layout(size, nheroes)
		local L = {}
		L.pw, L.ph, L.k = tp_dims(size)
		L.x = math.floor((size.width - L.pw * L.k) / 2)
		L.y = math.floor((size.height - L.ph * L.k) / 2)
		L.fs = 15

		-- thanh nut duoi (1 hang)
		local bh = 38
		local items = {
			{ k = "lbl", w = 124 }, { k = "s1", w = 38 }, { k = "s2", w = 38 }, { k = "s3", w = 38 },
			{ k = "rnd", w = 108 }, { k = "clr", w = 90 }, { k = "go", w = 132 }, { k = "re", w = 112 }, { k = "x", w = 80 },
		}
		L.bar = {}
		local cx = 0
		for _, it in ipairs(items) do
			L.bar[it.k] = { x = PAD + cx, y = 4, w = it.w, h = bh }
			cx = cx + it.w + 6
		end
		L.bar.x.x = L.pw - PAD - L.bar.x.w
		L.bar_h = 4 + bh

		local y_hi = L.ph - 78
		local y_lo = L.bar_h + 6
		L.y_hi, L.y_lo = y_hi, y_lo

		-- trai: 8 o doi (moi o 1-3 tuong), cac cap dau vong 1 cach nhau 5 don vi
		L.lw = math.floor((L.pw - 3 * PAD) * 0.5)
		L.rowh = clamp(math.floor((y_hi - y_lo - 29) / NSLOT), 24, 44)
		local ncw = 22
		local cw = math.floor((L.lw - ncw - 3 - 3 * 3) / 3)
		L.cell, L.num = {}, {}
		for i = 1, NSLOT do
			local pair = math.floor((i - 1) / 2)
			local top = y_hi - (i - 1) * (L.rowh + 2) - pair * 5
			L.num[i] = { x = PAD, y = top - L.rowh, w = ncw, h = L.rowh }
			L.cell[i] = {}
			for j = 1, 3 do
				L.cell[i][j] = { x = PAD + ncw + 3 + (j - 1) * (cw + 3), y = top - L.rowh, w = cw, h = L.rowh }
			end
		end

		-- phai: phan trang + chu cai nhay nhanh + luoi tuong
		L.rx = 2 * PAD + L.lw
		L.rw = L.pw - L.rx - PAD
		L.prev = { x = L.rx, y = y_hi - 28, w = 56, h = 28 }
		L.next = { x = L.rx + L.rw - 56, y = y_hi - 28, w = 56, h = 28 }
		L.pagelbl = { x = L.rx + 60, y = y_hi - 28, w = L.rw - 120, h = 28 }
		local lwid = math.floor((L.rw - 12 * 2) / 13)
		L.letters = {}
		for k = 1, 26 do
			local col = (k - 1) % 13
			local row_ = (k - 1 >= 13) and 1 or 0
			L.letters[k] = { x = L.rx + col * (lwid + 2), y = y_hi - 28 - 3 - 26 - row_ * 28, w = lwid, h = 26 }
		end
		local gy_hi = y_hi - 28 - 3 - 26 - 28 - 3 + 2
		local ch = 30
		L.gcols = (L.rw >= 480) and 3 or 2
		L.gcw = math.floor((L.rw - (L.gcols - 1) * 4) / L.gcols)
		L.grows = math.max(1, math.floor((gy_hi - y_lo + 3) / (ch + 3)))
		L.per = L.gcols * L.grows
		L.gch = ch
		L.gcell = {}
		for k = 1, L.per do
			local col = (k - 1) % L.gcols
			local row_ = math.floor((k - 1) / L.gcols)
			L.gcell[k] = { x = L.rx + col * (L.gcw + 4), y = gy_hi - (row_ + 1) * ch - row_ * 3, w = L.gcw, h = ch }
		end
		L.pages = math.max(1, math.ceil((nheroes or 0) / L.per))
		return L
	end
	M._tp_layout = tp_layout

	local function tp_status(info)
		if info == nil then return "LocalServer chua san sang", "warn" end
		if not info.ready then return "Game dang tai du lieu - doi xiu roi mo lai bang nay", "warn" end
		if info.running then
			if info.step < 8 then
				return "Dang dung thi sinh " .. tostring(info.step) .. "/8 ...", "run"
			end
			return "Dang dau: da xong " .. tostring(info.step - 8) .. "/7 tran ...", "run"
		end
		if info.err ~= nil then
			local e = tostring(info.err)
			if #e > 110 then e = string.sub(e, 1, 110) .. "..." end
			return "Loi: " .. e, "err"
		end
		if info.has then
			return "Xong! Vo dich: " .. tp_show(info.champ) .. "  -> bam MO LAI MAN de xem bang dau", "ok"
		end
		return "Chon tuong (o trong = ngau nhien) roi bam BAT DAU", "idle"
	end

	local function tp_sig(info, nh, size)
		local st = M._tp
		local t = { tostring(info.size), info.running and ("R" .. tostring(info.step)) or "I", tostring(info.seq), tostring(info.err),
			tostring(info.champ), tostring(info.ready), tostring(st.sel_i), tostring(st.sel_j), tostring(st.page), tostring(nh),
			tostring(size.width) .. "x" .. tostring(size.height) }
		for i = 1, NSLOT do
			local s = info.slots[i]
			t[#t + 1] = tostring(s[1]) .. "," .. tostring(s[2]) .. "," .. tostring(s[3])
		end
		return table.concat(t, "|")
	end

	local function tp_build_panel(scene, L, info, heroes, by_id, letter)
		local st = M._tp
		local COL, C = tp_colors()
		local C_BG, C_EMPTY, C_FILLED, C_SEL, C_OFF = C.bg, C.empty, C.filled, C.sel, C.off
		local C_NORMAL, C_USED, C_NAV, C_DIS = C.normal, C.used, C.nav, C.dis
		-- nut goc (Node thuan: tam co gian la goc duoi-trai) => phong to khong lech vi tri
		local root = cc.Node:create()
		pcall(function() root:setName(TP_PANEL_NAME) end)
		pcall(function() root:setScale(L.k) end)
		root:setPosition(cc.p(L.x, L.y))
		local bg = cc.LayerColor:create(C_BG, L.pw, L.ph)
		bg:setPosition(cc.p(0, 0))
		root:addChild(bg)
		new_label(root, "TOURNAMENT - CHON TUONG DE DAU  (" .. tostring(M.version) .. ")", 18, L.pw / 2, L.ph - 16, 0.5)
		local text, kind = tp_status(info)
		local sl = new_label(root, tp_fit(text, L.pw - 2 * PAD, 14), 14, L.pw / 2, L.ph - 38, 0.5)
		pcall(function() sl:setColor(COL[kind] or COL.idle) end)
		if info.running then
			local bw = L.pw - 2 * PAD
			local frac = clamp((tonumber(info.step) or 0) / math.max(1, tonumber(info.total) or 15), 0, 1)
			local back = cc.LayerColor:create(C.bar_back, bw, 6)
			back:setPosition(cc.p(PAD, L.ph - 52))
			root:addChild(back)
			if frac > 0 then
				local fill = cc.LayerColor:create(C.bar_fill, math.max(2, math.floor(bw * frac)), 6)
				fill:setPosition(cc.p(PAD, L.ph - 52))
				root:addChild(fill)
			end
		end
		local h1 = new_label(root, "CAC DOI  (vong 1: 1-2, 3-4, 5-6, 7-8)", 13, PAD, L.ph - 66, 0)
		pcall(function() h1:setColor(COL.dim) end)
		local h2 = new_label(root, "TUONG  (bam de chon / thay)", 13, L.rx, L.ph - 66, 0)
		pcall(function() h2:setColor(COL.dim) end)

		-- 8 o doi
		local used = {}
		for i = 1, NSLOT do
			local nl = new_label(root, tostring(i), 16, L.num[i].x + L.num[i].w / 2, L.num[i].y + L.num[i].h / 2, 0.5)
			pcall(function() nl:setColor(COL.run) end)
			for j = 1, 3 do
				local r = L.cell[i][j]
				local tid = tonumber(info.slots[i][j]) or 0
				local active = j <= info.size
				local selected = active and st.sel_i == i and st.sel_j == j
				local label, col
				if not active then
					label, col = "-", C_OFF
				elseif tid > 0 then
					local h = by_id[tid]
					label = tp_fit(h ~= nil and h.name or ("#" .. tostring(tid)), r.w, L.fs - 1)
					col = selected and C_SEL or C_FILLED
					used[tid] = (used[tid] or 0) + 1
				else
					label = selected and "[ chon tuong ]" or "(ngau nhien)"
					col = selected and C_SEL or C_EMPTY
				end
				local lb = new_button(root, r, label, L.fs - 1, col)
				if not active or (tid == 0 and not selected) then
					pcall(function() lb:setColor(COL.dim) end)
				end
			end
		end

		-- phai: phan trang + chu cai + luoi tuong
		local pg = clamp(st.page or 1, 1, L.pages)
		new_button(root, L.prev, "<", 20, C_NAV)
		new_button(root, L.next, ">", 20, C_NAV)
		local pl = new_label(root, "trang " .. tostring(pg) .. "/" .. tostring(L.pages) .. "  (" .. tostring(#heroes) .. " tuong)", 14,
			L.pagelbl.x + L.pagelbl.w / 2, L.pagelbl.y + L.pagelbl.h / 2, 0.5)
		pcall(function() pl:setColor(COL.idle) end)
		local first = (pg - 1) * L.per
		local cur_letter = heroes[first + 1] ~= nil and string.sub(heroes[first + 1].key, 1, 1) or ""
		for k = 1, 26 do
			local ch = string.char(64 + k)
			local lk = string.lower(ch)
			local has = letter[lk] ~= nil
			local col = (lk == cur_letter) and C_SEL or (has and C_NAV or C_OFF)
			local lb = new_button(root, L.letters[k], ch, 14, col)
			if not has then pcall(function() lb:setColor(COL.dim) end) end
		end
		for k = 1, L.per do
			local h = heroes[first + k]
			if h == nil then break end
			local r = L.gcell[k]
			local n = used[h.id]
			local label = tp_fit(h.name, r.w - (n and 26 or 0), L.fs - 1)
			if n then label = label .. " x" .. tostring(n) end
			new_button(root, r, label, L.fs - 1, n and C_USED or C_NORMAL)
		end

		-- thanh nut duoi
		local lbl = new_label(root, "SO TUONG/DOI:", 14, L.bar.lbl.x, L.bar.lbl.y + L.bar.lbl.h / 2, 0)
		pcall(function() lbl:setColor(COL.idle) end)
		for n = 1, 3 do
			new_button(root, L.bar["s" .. n], tostring(n), 18, info.size == n and C_SEL or C_NAV)
		end
		local busy = info.running == true
		new_button(root, L.bar.rnd, "NGAU NHIEN", 15, busy and C_DIS or C.rnd)
		new_button(root, L.bar.clr, "XOA HET", 15, busy and C_DIS or C.clr)
		if busy then
			new_button(root, L.bar.go, "HUY (" .. tostring(info.step) .. "/" .. tostring(info.total) .. ")", 16, C.cancel)
		else
			new_button(root, L.bar.go, info.has and "DAU LAI" or "BAT DAU", 17, info.ready and C.go or C_DIS)
		end
		new_button(root, L.bar.re, "MO LAI MAN", 15, (info.has and not busy) and C.re or C_DIS)
		new_button(root, L.bar.x, "DONG", 17, C.x)
		scene:addChild(root, Z_TP)
		return root
	end

	function M.tpRender()
		local scene = running_scene()
		if scene == nil then return end
		local size = visible_size()
		local info = nil
		if M.tpEnabled() and tp_win_open() then info = tp_info() end

		local btn = scene:getChildByName(TP_BTN_NAME)
		if info ~= nil then
			local bsig = (info.running and ("r" .. tostring(info.step)) or "i") .. "|" .. tostring(size.width) .. "x" .. tostring(size.height)
			if btn ~= nil and M._tp_btn_sig ~= bsig then
				btn:removeFromParent()
				btn = nil
			end
			if btn == nil then
				local node = cc.Node:create()
				pcall(function() node:setName(TP_BTN_NAME) end)
				local label = info.running and (tostring(info.step) .. "/" .. tostring(info.total)) or "TN"
				local _, C = tp_colors()
				new_button(node, tp_btn_rect(size), label, info.running and 16 or 20, info.running and C.btn_run or C.btn_idle)
				scene:addChild(node, Z_TP)
				M._tp_btn_sig = bsig
			end
		else
			if btn ~= nil then btn:removeFromParent() end
			M._tp_open = false
		end

		local panel = scene:getChildByName(TP_PANEL_NAME)
		if info ~= nil and M._tp_open then
			local heroes, by_id, letter = tp_heroes()
			local sig = tp_sig(info, #heroes, size)
			if panel == nil or M._tp_sig ~= sig then
				if panel ~= nil then panel:removeFromParent() end
				tp_build_panel(scene, tp_layout(size, #heroes), info, heroes, by_id, letter)
				M._tp_sig = sig
			end
		elseif panel ~= nil then
			panel:removeFromParent()
			M._tp_sig = nil
		end
	end

	function M.tpClose()
		M._tp_open = false
		M._tp_sig = nil
		pcall(M.tpRender)
	end

	-- dong roi mo lai man Tournament de client doc lai bang dau (the_kings_battle_init chay lai trong onInit)
	function M.tpReopen()
		local sm = rawget(_G, "state_machine")
		if type(sm) ~= "table" or type(sm.excute) ~= "function" or not tp_win_open() then return false end
		M.tpClose()
		pcall(sm.excute, "sm_battleof_kings_window_close", 0, nil)
		pcall(M.tpRender)
		schedule(0.5, function()
			pcall(sm.excute, "sm_battleof_kings_window_open", 0, nil)
			return true
		end)
		return true
	end

	-- o trong ke tiep (theo thu tu doi -> vi tri) sau (i0, j0), quay vong; i0 = 0: tu dau; nil neu da du
	local function tp_next_empty(info, i0, j0)
		local total = NSLOT * info.size
		local start = 0
		if i0 > 0 then start = (i0 - 1) * info.size + j0 end
		for off = 0, total - 1 do
			local pos = (start + off) % total
			local i, j = math.floor(pos / info.size) + 1, pos % info.size + 1
			if (tonumber(info.slots[i][j]) or 0) == 0 then return i, j end
		end
		return nil
	end

	local function tp_pick(LS, info, h)
		local st = M._tp
		local i, j = st.sel_i, st.sel_j
		if i == nil or j == nil or j > info.size then
			i, j = tp_next_empty(info, 0, 0)
		end
		if i == nil then
			notify("Da du o - bam mot o de chon thay tuong", 3)
			return
		end
		for jj = 1, info.size do
			if jj ~= j and (tonumber(info.slots[i][jj]) or 0) == h.id then
				notify("Doi " .. tostring(i) .. " da co " .. h.name .. " (moi doi khong trung tuong)", 4)
				return
			end
		end
		LS.tn_set_slot(i, j, h.id)
		local info2 = tp_info()
		st.sel_i, st.sel_j = nil, nil
		if info2 ~= nil then
			local ni, nj = tp_next_empty(info2, i, j)
			if ni ~= nil then st.sel_i, st.sel_j = ni, nj end
		end
	end

	-- xu ly mot lan cham (toa do trong khong gian thiet ke); tra ve true neu da xu ly
	local function tp_hit(L, info, heroes, lx, ly)
		local LS = tp_api()
		if LS == nil then return false end
		local st = M._tp
		local busy = info.running == true

		if in_rect(lx, ly, L.bar.x) then
			M.tpClose()
			return true
		end
		if busy then
			if in_rect(lx, ly, L.bar.go) then
				pcall(LS.tn_cancel)
				M._tp_sig = nil
				pcall(M.tpRender)
			end
			return true   -- dang chay: khong cho sua o chon (LocalServer doc cac o trong luc dung thi sinh)
		end
		if in_rect(lx, ly, L.bar.re) then
			if info.has then M.tpReopen() end
			return true
		end
		if in_rect(lx, ly, L.bar.go) then
			if not info.ready then
				notify("Game chua san sang (dang tai du lieu) - doi xiu roi bam lai", 4)
				return true
			end
			local ok, ret, err = pcall(LS.tn_start)
			if not ok then
				notify("Tournament: loi " .. tostring(ret), 6)
			elseif ret ~= true then
				notify("Tournament: " .. tostring(err or ret or "khong bat dau duoc"), 6)
			end
			st.sel_i, st.sel_j = nil, nil
			M._tp_sig = nil
			pcall(M.tpRender)
			return true
		end
		for n = 1, 3 do
			if in_rect(lx, ly, L.bar["s" .. n]) then
				pcall(LS.tn_set_size, n)
				if st.sel_j ~= nil and st.sel_j > n then st.sel_i, st.sel_j = nil, nil end
				M._tp_sig = nil
				pcall(M.tpRender)
				return true
			end
		end
		if in_rect(lx, ly, L.bar.rnd) then
			pcall(LS.tn_random)
			M._tp_sig = nil
			pcall(M.tpRender)
			return true
		end
		if in_rect(lx, ly, L.bar.clr) then
			pcall(LS.tn_clear)
			st.sel_i, st.sel_j = nil, nil
			M._tp_sig = nil
			pcall(M.tpRender)
			return true
		end
		local changed = false
		for i = 1, NSLOT do
			for j = 1, info.size do
				if not changed and in_rect(lx, ly, L.cell[i][j]) then
					if st.sel_i == i and st.sel_j == j then
						if (tonumber(info.slots[i][j]) or 0) > 0 then
							pcall(LS.tn_set_slot, i, j, 0)
						else
							st.sel_i, st.sel_j = nil, nil
						end
					else
						st.sel_i, st.sel_j = i, j
					end
					changed = true
				end
			end
		end
		if not changed then
			local pg = clamp(st.page or 1, 1, L.pages)
			if in_rect(lx, ly, L.prev) then
				st.page = (pg <= 1) and L.pages or (pg - 1)
				changed = true
			elseif in_rect(lx, ly, L.next) then
				st.page = (pg >= L.pages) and 1 or (pg + 1)
				changed = true
			end
			if not changed then
				for k = 1, 26 do
					if in_rect(lx, ly, L.letters[k]) then
						local _, _, letter = tp_heroes()
						local idx = letter[string.lower(string.char(64 + k))]
						if idx ~= nil then st.page = math.floor((idx - 1) / L.per) + 1 end
						changed = true
						break
					end
				end
			end
			if not changed then
				local first = (pg - 1) * L.per
				for k = 1, L.per do
					local h = heroes[first + k]
					if h == nil then break end
					if in_rect(lx, ly, L.gcell[k]) then
						tp_pick(LS, info, h)
						changed = true
						break
					end
				end
			end
		end
		if changed then
			M._tp_sig = nil
			pcall(M.tpRender)
		end
		return true
	end
	M._tp_hit = tp_hit

	function M._tpTouch(loc)
		if not M.tpEnabled() then return false end
		local scene = running_scene()
		if scene == nil then return false end
		local size = visible_size()
		if not M._tp_open then
			if M._gm_open or M._om_open then return false end
			local btn = scene:getChildByName(TP_BTN_NAME)
			if btn == nil then return false end
			local p = btn:convertToNodeSpace(loc)
			if in_rect(p.x, p.y, tp_btn_rect(size)) then
				M._tp_open = true
				M._tp_sig = nil
				pcall(M.tpRender)
				return true
			end
			return false
		end
		local panel = scene:getChildByName(TP_PANEL_NAME)
		if panel == nil then
			pcall(M.tpRender)
			panel = scene:getChildByName(TP_PANEL_NAME)
			if panel == nil then return M._tp_open == true end
		end
		local info = tp_info()
		if info == nil then
			M.tpClose()
			return true
		end
		local heroes = tp_heroes()
		local L = tp_layout(size, #heroes)
		local p = panel:convertToNodeSpace(loc)
		if p.x < 0 or p.y < 0 or p.x > L.pw or p.y > L.ph then
			M.tpClose()
			return true
		end
		tp_hit(L, info, heroes, p.x, p.y)
		return true
	end
end

-- ======================================================================= WW: bang chon tuong cho Inter-server World War (3v3 co dinh)
-- Nut "WW" (mep phai, duoi nut TN) chi hien khi dang mo man World War (CrossTotalWarClass hoac SmCrossServerBattleofKingsWindowClass). Bam vao: bang chon
-- 8 doi x 1-3 tuong (LocalServer.tn_*). BAT DAU -> LocalServer chay 7 tran bang engine that (moi frame mot buoc),
-- xong thi bam MO LAI MAN de client doc lai bang dau + xem replay bang nut "xem" co san cua game.
-- Bang duoc ve trong "khong gian thiet ke" (840 hoac 1040 x 500) roi phong/thu theo man hinh (root:setScale), nen o
-- cham du to tren man hinh nhieu pixel; moi toa do cham doi ve khong gian thiet ke bang root:convertToNodeSpace.
do
	local WP_BTN_NAME   = "offlinemock_wp_btn"
	local WP_PANEL_NAME = "offlinemock_wp_panel"
	local Z_TP          = 1000003
	local WP_BTN_W, WP_BTN_H = 64, 32
	local WP_PH = 500
	local NSLOT = 8
	local PAD = 8
	M.wp_button_y = 0.18
	M._wp = M._wp or { page = 1 }

	-- mau tao luc dung (khong dung cc.* luc nap file: loi o day se lam hong ca OfflineMock)
	local COL, CB = nil, nil
	local function wp_colors()
		if COL == nil then
			COL = {
				idle = cc.c3b(200, 200, 200), run = cc.c3b(255, 235, 59), ok = cc.c3b(120, 230, 120),
				err = cc.c3b(255, 130, 130), warn = cc.c3b(255, 180, 80), dim = cc.c3b(130, 130, 130),
			}
			CB = {
				bg = cc.c4b(0, 0, 0, 238), empty = cc.c4b(58, 58, 74, 255), filled = cc.c4b(35, 85, 150, 255),
				sel = cc.c4b(190, 150, 20, 255), off = cc.c4b(28, 28, 34, 255), normal = cc.c4b(48, 48, 64, 255),
				used = cc.c4b(35, 105, 70, 255), nav = cc.c4b(70, 70, 90, 255), dis = cc.c4b(45, 45, 50, 255),
				rnd = cc.c4b(40, 110, 120, 255), clr = cc.c4b(125, 60, 55, 255), go = cc.c4b(35, 130, 55, 255),
				cancel = cc.c4b(170, 70, 40, 255), re = cc.c4b(45, 95, 160, 255), x = cc.c4b(130, 40, 40, 255),
				btn_idle = cc.c4b(20, 110, 130, 220), btn_run = cc.c4b(150, 100, 0, 220),
				bar_back = cc.c4b(60, 60, 60, 255), bar_fill = cc.c4b(255, 200, 40, 255),
			}
		end
		return COL, CB
	end

	local function clamp(v, lo, hi)
		if v < lo then return lo end
		if v > hi then return hi end
		return v
	end

	-- man "Inter-server World War" that cua game = CrossTotalWarClass (cross_arena_*); giu them man cross-kings cu
	local WP_WIN_CLASSES = { "CrossTotalWarClass", "SmCrossServerBattleofKingsWindowClass" }
	local function wp_win_which()
		local fw = rawget(_G, "fwin")
		if type(fw) ~= "table" or type(fw.find) ~= "function" then return nil end
		for _, cls in ipairs(WP_WIN_CLASSES) do
			local ok, w = pcall(fw.find, fw, cls)
			if ok and w ~= nil then return cls end
		end
		return nil
	end

	local function wp_win_open()
		return wp_win_which() ~= nil
	end

	local function wp_api()
		local LS = M.LS
		if LS == nil or type(LS.ww_info) ~= "function" or type(LS.ww_start) ~= "function" then return nil end
		return LS
	end

	local function wp_info()
		local LS = wp_api()
		if LS == nil or not ls_active() then return nil end
		local ok, info = pcall(LS.ww_info)
		if ok and type(info) == "table" and type(info.slots) == "table" then return info end
		return nil
	end

	-- "3.Vegeta_SSGSS_" -> "3.Vegeta SSGSS"
	local function wp_show(name)
		local s = tostring(name or "?")
		s = string.gsub(s, "_", " ")
		s = string.gsub(s, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		if s == "" then s = "?" end
		return s
	end

	-- cat chuoi UTF-8 theo do rong o (khong cat giua ky tu nhieu byte)
	local function wp_fit(s, w, fs)
		local maxc = math.max(3, math.floor((w - 8) / (fs * 0.58)))
		local chars = {}
		for ch in string.gmatch(s, "[\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
		if #chars <= maxc then return s end
		return table.concat(chars, "", 1, maxc - 1) .. "."
	end

	-- danh sach tuong sap theo ten (bo nho dem; dung lai khi pool khong doi)
	local function wp_heroes()
		local LS = wp_api()
		if LS == nil or type(LS.ww_pool) ~= "function" or type(LS.ww_name) ~= "function" then return {}, {}, {} end
		local ok, pool = pcall(LS.ww_pool)
		if not ok or type(pool) ~= "table" then return {}, {}, {} end
		local c = M._wp.cache
		if c ~= nil and c.n == #pool and c.first == pool[1] and c.last == pool[#pool] then return c.list, c.by_id, c.letter end
		local list, by_id, letter = {}, {}, {}
		for _, id in ipairs(pool) do
			local okn, nm = pcall(LS.ww_name, id)
			local show = wp_show(okn and nm or id)
			local h = { id = id, name = show, key = string.lower(show) }
			list[#list + 1] = h
			by_id[id] = h
		end
		table.sort(list, function(a, b)
			if a.key ~= b.key then return a.key < b.key end
			return a.id < b.id
		end)
		for i, h in ipairs(list) do
			local l = string.sub(h.key, 1, 1)
			if letter[l] == nil then letter[l] = i end
		end
		M._wp.cache = { n = #pool, first = pool[1], last = pool[#pool], list = list, by_id = by_id, letter = letter }
		return list, by_id, letter
	end

	local function wp_btn_rect(size)
		return { x = size.width - WP_BTN_W - 6, y = size.height * M.wp_button_y, w = WP_BTN_W, h = WP_BTN_H }
	end

	-- kich thuoc khong gian thiet ke + he so phong/thu
	local function wp_dims(size)
		local pw = (size.width >= size.height * 1.9) and 1040 or 840
		local k = math.min(size.width / (pw + 20), size.height / (WP_PH + 20))
		return pw, WP_PH, clamp(k, 0.3, 2.4)
	end

	-- bo cuc (toa do trong khong gian thiet ke, goc duoi-trai); chi phu thuoc ty le man hinh + so tuong
	local function wp_layout(size, nheroes)
		local L = {}
		L.pw, L.ph, L.k = wp_dims(size)
		L.x = math.floor((size.width - L.pw * L.k) / 2)
		L.y = math.floor((size.height - L.ph * L.k) / 2)
		L.fs = 15

		-- thanh nut duoi (1 hang)
		local bh = 38
		local items = {
			{ k = "lbl", w = 150 },
			{ k = "rnd", w = 108 }, { k = "clr", w = 90 }, { k = "go", w = 132 }, { k = "re", w = 112 }, { k = "x", w = 80 },
		}
		L.bar = {}
		local cx = 0
		for _, it in ipairs(items) do
			L.bar[it.k] = { x = PAD + cx, y = 4, w = it.w, h = bh }
			cx = cx + it.w + 6
		end
		L.bar.x.x = L.pw - PAD - L.bar.x.w
		L.bar_h = 4 + bh

		local y_hi = L.ph - 78
		local y_lo = L.bar_h + 6
		L.y_hi, L.y_lo = y_hi, y_lo

		-- trai: 8 o doi (moi o 1-3 tuong), cac cap dau vong 1 cach nhau 5 don vi
		L.lw = math.floor((L.pw - 3 * PAD) * 0.5)
		L.rowh = clamp(math.floor((y_hi - y_lo - 29) / NSLOT), 24, 44)
		local ncw = 22
		local cw = math.floor((L.lw - ncw - 3 - 3 * 3) / 3)
		L.cell, L.num = {}, {}
		for i = 1, NSLOT do
			local pair = math.floor((i - 1) / 2)
			local top = y_hi - (i - 1) * (L.rowh + 2) - pair * 5
			L.num[i] = { x = PAD, y = top - L.rowh, w = ncw, h = L.rowh }
			L.cell[i] = {}
			for j = 1, 3 do
				L.cell[i][j] = { x = PAD + ncw + 3 + (j - 1) * (cw + 3), y = top - L.rowh, w = cw, h = L.rowh }
			end
		end

		-- phai: phan trang + chu cai nhay nhanh + luoi tuong
		L.rx = 2 * PAD + L.lw
		L.rw = L.pw - L.rx - PAD
		L.prev = { x = L.rx, y = y_hi - 28, w = 56, h = 28 }
		L.next = { x = L.rx + L.rw - 56, y = y_hi - 28, w = 56, h = 28 }
		L.pagelbl = { x = L.rx + 60, y = y_hi - 28, w = L.rw - 120, h = 28 }
		local lwid = math.floor((L.rw - 12 * 2) / 13)
		L.letters = {}
		for k = 1, 26 do
			local col = (k - 1) % 13
			local row_ = (k - 1 >= 13) and 1 or 0
			L.letters[k] = { x = L.rx + col * (lwid + 2), y = y_hi - 28 - 3 - 26 - row_ * 28, w = lwid, h = 26 }
		end
		local gy_hi = y_hi - 28 - 3 - 26 - 28 - 3 + 2
		local ch = 30
		L.gcols = (L.rw >= 480) and 3 or 2
		L.gcw = math.floor((L.rw - (L.gcols - 1) * 4) / L.gcols)
		L.grows = math.max(1, math.floor((gy_hi - y_lo + 3) / (ch + 3)))
		L.per = L.gcols * L.grows
		L.gch = ch
		L.gcell = {}
		for k = 1, L.per do
			local col = (k - 1) % L.gcols
			local row_ = math.floor((k - 1) / L.gcols)
			L.gcell[k] = { x = L.rx + col * (L.gcw + 4), y = gy_hi - (row_ + 1) * ch - row_ * 3, w = L.gcw, h = ch }
		end
		L.pages = math.max(1, math.ceil((nheroes or 0) / L.per))
		return L
	end
	M._wp_layout = wp_layout

	local function wp_status(info)
		if info == nil then return "LocalServer chua san sang", "warn" end
		if not info.ready then return "Game dang tai du lieu - doi xiu roi mo lai bang nay", "warn" end
		if info.running then
			if info.step < 8 then
				return "Dang dung thi sinh " .. tostring(info.step) .. "/8 ...", "run"
			end
			return "Dang dau: da xong " .. tostring(info.step - 8) .. "/7 tran ...", "run"
		end
		if info.err ~= nil then
			local e = tostring(info.err)
			if #e > 110 then e = string.sub(e, 1, 110) .. "..." end
			return "Loi: " .. e, "err"
		end
		if info.has then
			return "Xong! Vo dich: " .. wp_show(info.champ) .. "  -> bam MO LAI MAN de xem bang dau", "ok"
		end
		return "Chon tuong (o trong = ngau nhien) roi bam BAT DAU", "idle"
	end

	local function wp_sig(info, nh, size)
		local st = M._wp
		local t = { tostring(info.size), info.running and ("R" .. tostring(info.step)) or "I", tostring(info.seq), tostring(info.err),
			tostring(info.champ), tostring(info.ready), tostring(st.sel_i), tostring(st.sel_j), tostring(st.page), tostring(nh),
			tostring(size.width) .. "x" .. tostring(size.height) }
		for i = 1, NSLOT do
			local s = info.slots[i]
			t[#t + 1] = tostring(s[1]) .. "," .. tostring(s[2]) .. "," .. tostring(s[3])
		end
		return table.concat(t, "|")
	end

	local function wp_build_panel(scene, L, info, heroes, by_id, letter)
		local st = M._wp
		local COL, C = wp_colors()
		local C_BG, C_EMPTY, C_FILLED, C_SEL, C_OFF = C.bg, C.empty, C.filled, C.sel, C.off
		local C_NORMAL, C_USED, C_NAV, C_DIS = C.normal, C.used, C.nav, C.dis
		-- nut goc (Node thuan: tam co gian la goc duoi-trai) => phong to khong lech vi tri
		local root = cc.Node:create()
		pcall(function() root:setName(WP_PANEL_NAME) end)
		pcall(function() root:setScale(L.k) end)
		root:setPosition(cc.p(L.x, L.y))
		local bg = cc.LayerColor:create(C_BG, L.pw, L.ph)
		bg:setPosition(cc.p(0, 0))
		root:addChild(bg)
		new_label(root, "WORLD WAR 3v3 - CHON TUONG DE DAU  (" .. tostring(M.version) .. ")", 18, L.pw / 2, L.ph - 16, 0.5)
		local text, kind = wp_status(info)
		local sl = new_label(root, wp_fit(text, L.pw - 2 * PAD, 14), 14, L.pw / 2, L.ph - 38, 0.5)
		pcall(function() sl:setColor(COL[kind] or COL.idle) end)
		if info.running then
			local bw = L.pw - 2 * PAD
			local frac = clamp((tonumber(info.step) or 0) / math.max(1, tonumber(info.total) or 15), 0, 1)
			local back = cc.LayerColor:create(C.bar_back, bw, 6)
			back:setPosition(cc.p(PAD, L.ph - 52))
			root:addChild(back)
			if frac > 0 then
				local fill = cc.LayerColor:create(C.bar_fill, math.max(2, math.floor(bw * frac)), 6)
				fill:setPosition(cc.p(PAD, L.ph - 52))
				root:addChild(fill)
			end
		end
		local h1 = new_label(root, "CAC DOI  (vong 1: 1-2, 3-4, 5-6, 7-8)", 13, PAD, L.ph - 66, 0)
		pcall(function() h1:setColor(COL.dim) end)
		local h2 = new_label(root, "TUONG  (bam de chon / thay)", 13, L.rx, L.ph - 66, 0)
		pcall(function() h2:setColor(COL.dim) end)

		-- 8 o doi
		local used = {}
		for i = 1, NSLOT do
			local nl = new_label(root, tostring(i), 16, L.num[i].x + L.num[i].w / 2, L.num[i].y + L.num[i].h / 2, 0.5)
			pcall(function() nl:setColor(COL.run) end)
			for j = 1, 3 do
				local r = L.cell[i][j]
				local tid = tonumber(info.slots[i][j]) or 0
				local active = j <= info.size
				local selected = active and st.sel_i == i and st.sel_j == j
				local label, col
				if not active then
					label, col = "-", C_OFF
				elseif tid > 0 then
					local h = by_id[tid]
					label = wp_fit(h ~= nil and h.name or ("#" .. tostring(tid)), r.w, L.fs - 1)
					col = selected and C_SEL or C_FILLED
					used[tid] = (used[tid] or 0) + 1
				else
					label = selected and "[ chon tuong ]" or "(ngau nhien)"
					col = selected and C_SEL or C_EMPTY
				end
				local lb = new_button(root, r, label, L.fs - 1, col)
				if not active or (tid == 0 and not selected) then
					pcall(function() lb:setColor(COL.dim) end)
				end
			end
		end

		-- phai: phan trang + chu cai + luoi tuong
		local pg = clamp(st.page or 1, 1, L.pages)
		new_button(root, L.prev, "<", 20, C_NAV)
		new_button(root, L.next, ">", 20, C_NAV)
		local pl = new_label(root, "trang " .. tostring(pg) .. "/" .. tostring(L.pages) .. "  (" .. tostring(#heroes) .. " tuong)", 14,
			L.pagelbl.x + L.pagelbl.w / 2, L.pagelbl.y + L.pagelbl.h / 2, 0.5)
		pcall(function() pl:setColor(COL.idle) end)
		local first = (pg - 1) * L.per
		local cur_letter = heroes[first + 1] ~= nil and string.sub(heroes[first + 1].key, 1, 1) or ""
		for k = 1, 26 do
			local ch = string.char(64 + k)
			local lk = string.lower(ch)
			local has = letter[lk] ~= nil
			local col = (lk == cur_letter) and C_SEL or (has and C_NAV or C_OFF)
			local lb = new_button(root, L.letters[k], ch, 14, col)
			if not has then pcall(function() lb:setColor(COL.dim) end) end
		end
		for k = 1, L.per do
			local h = heroes[first + k]
			if h == nil then break end
			local r = L.gcell[k]
			local n = used[h.id]
			local label = wp_fit(h.name, r.w - (n and 26 or 0), L.fs - 1)
			if n then label = label .. " x" .. tostring(n) end
			new_button(root, r, label, L.fs - 1, n and C_USED or C_NORMAL)
		end

		-- thanh nut duoi
		local lbl = new_label(root, "3 TUONG/DOI (3v3)", 14, L.bar.lbl.x, L.bar.lbl.y + L.bar.lbl.h / 2, 0)
		pcall(function() lbl:setColor(COL.idle) end)
		local busy = info.running == true
		new_button(root, L.bar.rnd, "NGAU NHIEN", 15, busy and C_DIS or C.rnd)
		new_button(root, L.bar.clr, "XOA HET", 15, busy and C_DIS or C.clr)
		if busy then
			new_button(root, L.bar.go, "HUY (" .. tostring(info.step) .. "/" .. tostring(info.total) .. ")", 16, C.cancel)
		else
			new_button(root, L.bar.go, info.has and "DAU LAI" or "BAT DAU", 17, info.ready and C.go or C_DIS)
		end
		new_button(root, L.bar.re, "MO LAI MAN", 15, (info.has and not busy) and C.re or C_DIS)
		new_button(root, L.bar.x, "DONG", 17, C.x)
		scene:addChild(root, Z_TP)
		return root
	end

	function M.wpRender()
		local scene = running_scene()
		if scene == nil then return end
		local size = visible_size()
		local info = nil
		if M.tpEnabled() and wp_win_open() then info = wp_info() end

		local btn = scene:getChildByName(WP_BTN_NAME)
		if info ~= nil then
			local bsig = (info.running and ("r" .. tostring(info.step)) or "i") .. "|" .. tostring(size.width) .. "x" .. tostring(size.height)
			if btn ~= nil and M._wp_btn_sig ~= bsig then
				btn:removeFromParent()
				btn = nil
			end
			if btn == nil then
				local node = cc.Node:create()
				pcall(function() node:setName(WP_BTN_NAME) end)
				local label = info.running and (tostring(info.step) .. "/" .. tostring(info.total)) or "WW"
				local _, C = wp_colors()
				new_button(node, wp_btn_rect(size), label, info.running and 16 or 20, info.running and C.btn_run or C.btn_idle)
				scene:addChild(node, Z_TP)
				M._wp_btn_sig = bsig
			end
		else
			if btn ~= nil then btn:removeFromParent() end
			M._wp_open = false
		end

		local panel = scene:getChildByName(WP_PANEL_NAME)
		if info ~= nil and M._wp_open then
			local heroes, by_id, letter = wp_heroes()
			local sig = wp_sig(info, #heroes, size)
			if panel == nil or M._wp_sig ~= sig then
				if panel ~= nil then panel:removeFromParent() end
				wp_build_panel(scene, wp_layout(size, #heroes), info, heroes, by_id, letter)
				M._wp_sig = sig
			end
		elseif panel ~= nil then
			panel:removeFromParent()
			M._wp_sig = nil
		end
	end

	function M.wpClose()
		M._wp_open = false
		M._wp_sig = nil
		pcall(M.wpRender)
	end

	-- dong roi mo lai man World War de client doc lai bang dau (the_kings_battle_self_init chay lai trong onInit)
	function M.wpReopen()
		local sm = rawget(_G, "state_machine")
		if type(sm) ~= "table" or type(sm.excute) ~= "function" or not wp_win_open() then return false end
		local cls = wp_win_which()
		M.wpClose()
		if cls == "CrossTotalWarClass" then
			pcall(sm.excute, "cross_total_war_window_close", 0, nil)
			pcall(M.wpRender)
			schedule(0.5, function()
				-- nap lai du lieu (cross_arena_init) roi moi mo man, giong luc vao tu menu Campaign
				local nm, pc = rawget(_G, "NetworkManager"), rawget(_G, "protocol_command")
				local opened = false
				if type(nm) == "table" and type(pc) == "table" and pc.cross_arena_init ~= nil then
					opened = pcall(function()
						nm:register(pc.cross_arena_init.code, nil, nil, nil, M, function(response)
							pcall(sm.excute, "cross_total_war_window_open", 0, 0)
						end, false, nil)
					end)
				end
				if not opened then pcall(sm.excute, "cross_total_war_window_open", 0, 0) end
				return true
			end)
			return true
		end
		pcall(sm.excute, "sm_cross_server_battleof_kings_window_close", 0, nil)
		pcall(M.wpRender)
		schedule(0.5, function()
			pcall(sm.excute, "sm_cross_server_battleof_kings_window_open", 0, nil)
			return true
		end)
		return true
	end

	-- o trong ke tiep (theo thu tu doi -> vi tri) sau (i0, j0), quay vong; i0 = 0: tu dau; nil neu da du
	local function wp_next_empty(info, i0, j0)
		local total = NSLOT * info.size
		local start = 0
		if i0 > 0 then start = (i0 - 1) * info.size + j0 end
		for off = 0, total - 1 do
			local pos = (start + off) % total
			local i, j = math.floor(pos / info.size) + 1, pos % info.size + 1
			if (tonumber(info.slots[i][j]) or 0) == 0 then return i, j end
		end
		return nil
	end

	local function wp_pick(LS, info, h)
		local st = M._wp
		local i, j = st.sel_i, st.sel_j
		if i == nil or j == nil or j > info.size then
			i, j = wp_next_empty(info, 0, 0)
		end
		if i == nil then
			notify("Da du o - bam mot o de chon thay tuong", 3)
			return
		end
		for jj = 1, info.size do
			if jj ~= j and (tonumber(info.slots[i][jj]) or 0) == h.id then
				notify("Doi " .. tostring(i) .. " da co " .. h.name .. " (moi doi khong trung tuong)", 4)
				return
			end
		end
		LS.ww_set_slot(i, j, h.id)
		local info2 = wp_info()
		st.sel_i, st.sel_j = nil, nil
		if info2 ~= nil then
			local ni, nj = wp_next_empty(info2, i, j)
			if ni ~= nil then st.sel_i, st.sel_j = ni, nj end
		end
	end

	-- xu ly mot lan cham (toa do trong khong gian thiet ke); tra ve true neu da xu ly
	local function wp_hit(L, info, heroes, lx, ly)
		local LS = wp_api()
		if LS == nil then return false end
		local st = M._wp
		local busy = info.running == true

		if in_rect(lx, ly, L.bar.x) then
			M.wpClose()
			return true
		end
		if busy then
			if in_rect(lx, ly, L.bar.go) then
				pcall(LS.ww_cancel)
				M._wp_sig = nil
				pcall(M.wpRender)
			end
			return true   -- dang chay: khong cho sua o chon (LocalServer doc cac o trong luc dung thi sinh)
		end
		if in_rect(lx, ly, L.bar.re) then
			if info.has then M.wpReopen() end
			return true
		end
		if in_rect(lx, ly, L.bar.go) then
			if not info.ready then
				notify("Game chua san sang (dang tai du lieu) - doi xiu roi bam lai", 4)
				return true
			end
			local ok, ret, err = pcall(LS.ww_start)
			if not ok then
				notify("World War: loi " .. tostring(ret), 6)
			elseif ret ~= true then
				notify("World War: " .. tostring(err or ret or "khong bat dau duoc"), 6)
			end
			st.sel_i, st.sel_j = nil, nil
			M._wp_sig = nil
			pcall(M.wpRender)
			return true
		end
		if in_rect(lx, ly, L.bar.rnd) then
			pcall(LS.ww_random)
			M._wp_sig = nil
			pcall(M.wpRender)
			return true
		end
		if in_rect(lx, ly, L.bar.clr) then
			pcall(LS.ww_clear)
			st.sel_i, st.sel_j = nil, nil
			M._wp_sig = nil
			pcall(M.wpRender)
			return true
		end
		local changed = false
		for i = 1, NSLOT do
			for j = 1, info.size do
				if not changed and in_rect(lx, ly, L.cell[i][j]) then
					if st.sel_i == i and st.sel_j == j then
						if (tonumber(info.slots[i][j]) or 0) > 0 then
							pcall(LS.ww_set_slot, i, j, 0)
						else
							st.sel_i, st.sel_j = nil, nil
						end
					else
						st.sel_i, st.sel_j = i, j
					end
					changed = true
				end
			end
		end
		if not changed then
			local pg = clamp(st.page or 1, 1, L.pages)
			if in_rect(lx, ly, L.prev) then
				st.page = (pg <= 1) and L.pages or (pg - 1)
				changed = true
			elseif in_rect(lx, ly, L.next) then
				st.page = (pg >= L.pages) and 1 or (pg + 1)
				changed = true
			end
			if not changed then
				for k = 1, 26 do
					if in_rect(lx, ly, L.letters[k]) then
						local _, _, letter = wp_heroes()
						local idx = letter[string.lower(string.char(64 + k))]
						if idx ~= nil then st.page = math.floor((idx - 1) / L.per) + 1 end
						changed = true
						break
					end
				end
			end
			if not changed then
				local first = (pg - 1) * L.per
				for k = 1, L.per do
					local h = heroes[first + k]
					if h == nil then break end
					if in_rect(lx, ly, L.gcell[k]) then
						wp_pick(LS, info, h)
						changed = true
						break
					end
				end
			end
		end
		if changed then
			M._wp_sig = nil
			pcall(M.wpRender)
		end
		return true
	end
	M._wp_hit = wp_hit

	function M._wpTouch(loc)
		if not M.tpEnabled() then return false end
		local scene = running_scene()
		if scene == nil then return false end
		local size = visible_size()
		if not M._wp_open then
			if M._gm_open or M._om_open then return false end
			local btn = scene:getChildByName(WP_BTN_NAME)
			if btn == nil then return false end
			local p = btn:convertToNodeSpace(loc)
			if in_rect(p.x, p.y, wp_btn_rect(size)) then
				M._wp_open = true
				M._wp_sig = nil
				pcall(M.wpRender)
				return true
			end
			return false
		end
		local panel = scene:getChildByName(WP_PANEL_NAME)
		if panel == nil then
			pcall(M.wpRender)
			panel = scene:getChildByName(WP_PANEL_NAME)
			if panel == nil then return M._wp_open == true end
		end
		local info = wp_info()
		if info == nil then
			M.wpClose()
			return true
		end
		local heroes = wp_heroes()
		local L = wp_layout(size, #heroes)
		local p = panel:convertToNodeSpace(loc)
		if p.x < 0 or p.y < 0 or p.x > L.pw or p.y > L.ph then
			M.wpClose()
			return true
		end
		wp_hit(L, info, heroes, p.x, p.y)
		return true
	end
end

function M.enableGMTouch()
	if M._gm_touch then return end
	M._gm_touch = true
	pcall(function()
		local listener = cc.EventListenerTouchOneByOne:create()
		listener:setSwallowTouches(true)
		listener:registerScriptHandler(function(touch, event)
			local ok, res = pcall(function()
				local loc = touch:getLocation()
				-- [v6.31] bang chon HOP THE (Fusion) dang mo: nuot cham truoc moi lop khac
				local fu = M.FU
				if type(fu) == "table" and type(fu.touch) == "function" and fu.touch(loc) then return true end
				if M._tpTouch ~= nil and M._tpTouch(loc) then return true end
				if M._wpTouch ~= nil and M._wpTouch(loc) then return true end
				if M._omTouch(loc) then return true end
				return M._gmTouch(loc)
			end)
			if not ok then logmsg("lỗi GM/OM:", res) end
			return ok and res == true
		end, cc.Handler.EVENT_TOUCH_BEGAN)
		listener:registerScriptHandler(function() end, cc.Handler.EVENT_TOUCH_MOVED)
		listener:registerScriptHandler(function() end, cc.Handler.EVENT_TOUCH_ENDED)
		listener:registerScriptHandler(function() end, cc.Handler.EVENT_TOUCH_CANCELLED)
		cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listener, -130)
	end)
end

local function attach_send()
	local A = rawget(_G, "NetworkAdaptor")
	if type(A) ~= "table" or type(A.send) ~= "function" then return end
	if M._send_wrapper ~= nil and A.send == M._send_wrapper then
		F.send = true
		return
	end
	if (M._send_n or 0) >= M.max_reattach then return end
	M._send_n = (M._send_n or 0) + 1
	local orig = A.send
	local function wrapper(data, ...)
		if type(data) == "table" then
			local ok, handled = pcall(M.intercept, data)
			if ok and handled then return end
		end
		return orig(data, ...)
	end
	M._send_wrapper = wrapper
	A.send = wrapper
	F.send = true
end

function M.onPoll()
	local NM = rawget(_G, "NetworkManager")
	if type(NM) == "table" and type(NM.queue) == "table" then
		local head = NM.queue[1]
		if type(head) == "table" and head.RESPONSE_SUCCESS == true
			and type(head.resouce) == "string" and not head._om_rec then
			head._om_rec = true
			M.record(head)
		end
	end
	M.gmApply()
	if ls_active() then pcall(M.LS.sync) end
end

local function attach_poll()
	local NM = rawget(_G, "NetworkManager")
	if type(NM) ~= "table" or type(NM.poll) ~= "function" then return end
	if M._poll_wrapper ~= nil and NM.poll == M._poll_wrapper then
		F.poll = true
		return
	end
	if (M._poll_n or 0) >= M.max_reattach then return end
	M._poll_n = (M._poll_n or 0) + 1
	local orig = NM.poll
	local function wrapper(...)
		pcall(M.onPoll)
		return orig(...)
	end
	M._poll_wrapper = wrapper
	NM.poll = wrapper
	F.poll = true
end

function M.attach()
	if M.getMode() == "off" then return end
	attach_send()
	attach_poll()
	if M.getMode() == "replay" then pcall(M.guardParser) end
end

local function fallback_skip_update()
	if M._upd_fallback_done or F.upd or M.getMode() ~= "replay" then return end
	local fw = rawget(_G, "fwin")
	local sm = rawget(_G, "state_machine")
	if fw == nil or sm == nil then return end
	local w = fw:find("AssetsManagerClass")
	if w == nil then
		M._upd_seen = nil
		return
	end
	M._upd_seen = M._upd_seen or os.time()
	if os.time() - M._upd_seen >= 2 then
		M._upd_fallback_done = true
		logmsg("AssetsManager đã vá không chạy -> tự bỏ qua màn cập nhật")
		sm.excute("assets_manager_manager_assets_into_login_page", 0, "")
	end
end

-- [HOTFIX v6.21] Boc pcall cho ham cham do (hero_develop) de loi nil khong lam sap UI.
-- v6.20 chi thu require() roi boc truong cua module, nen neu ham la ham toan cuc / nam o bang khac
-- thi khong boc duoc va loi ":662/:647 attempt to index a nil value" van xay ra.
-- Ban nay quet _G, cac bang toan cuc cap 1 va package.loaded, boc moi noi tim thay,
-- va quet lai moi giay (neu game nap lai file thi ham goc xuat hien lai -> boc tiep).
-- [HOTFIX v6.22] v6.21 con sot shipEquipmentIsCanAwake (:706) nen loi van lot ra HUD.
-- Goc loi: file game push_notification_sm_hero_develop.lua doc _ED.push_user_ship_info[id][n].to_push
-- ma khong kiem tra nil. Server that chi gui record nay cho 26 tuong, con LocalServer tao 116 tuong
-- -> tuong khong co record thi nil. v6.22: (1) boc du 10 ham IsCan* cua file do,
-- (2) tu dien record mac dinh {to_push=false} cho moi tuong (xem M.guardPushInfo ben duoi).
M.reddot_names    = {
	"shipIsCanUpGradeStar", "shipIsCanEvolution", "shipIsCanProcess",
	"shipEquipmentIsCanEvolution", "shipEquipmentIsCanAwake", "shipEquipmentIsCanHarden",
	"equipmentIsCanHarden", "equipmentIsCanEvolution", "equipmentIsCanAwake", "equipmentIsCanLevelUp",
}
M.reddot_ui_names = { "formatHeroIconPushUpdate" }

local function reddot_after(name, is_ui, ok, ...)
	if ok then return ... end
	local msg = tostring((...))
	M._rd_swallowed = (M._rd_swallowed or 0) + 1
	local errs = M._rd_errs
	if errs == nil then
		errs = {}
		M._rd_errs = errs
	end
	local key = name .. " " .. string.sub(msg, 1, 160)
	local n = (errs[key] or 0) + 1
	errs[key] = n
	if n == 1 and (M._rd_logged or 0) < 12 then
		M._rd_logged = (M._rd_logged or 0) + 1
		pcall(append_line, M.err_file, os.date("%H:%M:%S") .. "\tGUARD nuot loi " .. esc(key) .. "\n")
	end
	if is_ui then return end
	return false
end

local function reddot_make(old, name, is_ui)
	return function(...)
		return reddot_after(name, is_ui, pcall(old, ...))
	end
end

-- [FIX lag 7] TRUOC DAY moi giay quet TOAN BO _G (~7000 muc) + package.loaded (~4000 module), moi bang goi
-- 10 rawget, lap 2 lan (danh sach ham + danh sach UI): do tren may chu ~40 ms MOI GIAY (dien thoai nang hon nhieu)
-- => giat hinh deu dan moi giay. Ca 10 ham IsCan* la ham TOAN CUC (push_notification_sm_hero_develop.lua) va
-- formatHeroIconPushUpdate la method cua lop HeroIconListCell; moi cho goi trong game deu goi bang ten toan cuc /
-- phuong thuc cua lop (da grep toan bo src: khong co alias nao nam trong bang khac). Nen chi kiem tra vai noi cu the
-- moi giay (re) => van boc lai ngay neu game nap lai file. Quet day du chi con khi goi tay M.reddotFullScan().
M.reddot_holder_globals = { "HeroIconListCell" }
M.reddot_holder_modules = {
	"client.notification.push_notification_sm_hero_develop",
	"client.cells.ship.hero_icon_list_cell",
}

local function reddot_scan(want, full)
	local found = {}
	local g = _G
	local function check(t, where)
		for i = 1, #want do
			local k = want[i]
			local v = rawget(t, k)
			if type(v) == "function" then found[#found + 1] = { t = t, k = k, f = v, where = where } end
		end
	end
	check(g, "_G")
	local hg = M.reddot_holder_globals
	for i = 1, #hg do
		local v = rawget(g, hg[i])
		if type(v) == "table" and v ~= g then check(v, hg[i]) end
	end
	local pk = rawget(g, "package")
	local pl = nil
	if type(pk) == "table" then pl = rawget(pk, "loaded") end
	if type(pl) == "table" then
		local hm = M.reddot_holder_modules
		for i = 1, #hm do
			local v = rawget(pl, hm[i])
			if type(v) == "table" and v ~= g then check(v, "loaded:" .. hm[i]) end
		end
	end
	if full then
		for name, v in next, g do
			if type(v) == "table" and v ~= g then check(v, tostring(name)) end
		end
		if type(pl) == "table" then
			for name, v in next, pl do
				if type(v) == "table" and v ~= g then check(v, "loaded:" .. tostring(name)) end
			end
		end
	end
	return found
end

function M.reddotFullScan()
	M._rd_full = true
	M._rd_t = nil
	pcall(M.guardRedDots)
	M._rd_full = nil
end

function M.guardRedDots()
	local now = os.time()
	if M._rd_t == now then return end
	M._rd_t = now
	local cache = M._rd_cache
	if cache == nil then
		cache = setmetatable({}, { __mode = "k" })
		M._rd_cache = cache
		M._rd_wrappers = setmetatable({}, { __mode = "k" })
		M._rd_where_set = {}
	end
	local wrappers, where = M._rd_wrappers, M._rd_where_set
	local added = 0
	local lists = { { M.reddot_names, false }, { M.reddot_ui_names, true } }
	for li = 1, #lists do
		local found = reddot_scan(lists[li][1], M._rd_full == true)
		for i = 1, #found do
			local h = found[i]
			if wrappers[h.f] == nil then
				local w = cache[h.f]
				if w == nil then
					w = reddot_make(h.f, h.k, lists[li][2])
					cache[h.f] = w
					wrappers[w] = true
				end
				rawset(h.t, h.k, w)
				added = added + 1
				where[h.k .. "@" .. h.where] = true
			end
		end
	end
	if added > 0 then
		M._rd_count = (M._rd_count or 0) + added
		local names = {}
		for k in pairs(where) do names[#names + 1] = k end
		table.sort(names)
		M._rd_where = table.concat(names, ",")
		logmsg("da boc giap cham do:", added, "cho", M._rd_where)
		if (M._rd_filelog or 0) < 20 then
			M._rd_filelog = (M._rd_filelog or 0) + 1
			pcall(append_line, M.err_file, os.date("%H:%M:%S") .. "\tGUARD boc " .. added .. " ham: " .. esc(M._rd_where) .. "\n")
		end
	end
end

-- [HOTFIX v6.22] Du lieu cham do cua tuong: _ED.push_user_ship_info.
-- Dang that: { [ship_id] = { [1..9] = { to_push = bool, demand = "" | {...} } } }.
-- Gan metatable __index len bang nay de MOI tuong (ca tuong moi nhan sau nay) tu co record mac dinh
-- "khong co cham do"; record san co (do server/replay ghi) thi chi bo sung o thieu, khong ghi de.
M.push_slots = 12

local function push_new_slot()
	return { to_push = false, demand = "", push_index = {} }
end

local function push_new_record()
	local rec = {}
	for i = 1, M.push_slots do rec[i] = push_new_slot() end
	return rec
end

local push_mt = {
	__index = function(t, k)
		local tk = type(k)
		if tk ~= "string" and tk ~= "number" then return nil end
		local rec = push_new_record()
		rawset(t, k, rec)
		M._push_lazy = (M._push_lazy or 0) + 1
		return rec
	end,
}

function M.guardPushInfo()
	if M.getMode() == "off" then return end
	local ED = rawget(_G, "_ED")
	if type(ED) ~= "table" then return end
	local t = rawget(ED, "push_user_ship_info")
	if t == nil then
		t = {}
		rawset(ED, "push_user_ship_info", t)
	end
	if type(t) ~= "table" then return end
	-- game co the gan lai bang moi luc dang nhap/dong bo -> moi tick kiem tra lai metatable
	if getmetatable(t) == nil then
		setmetatable(t, push_mt)
		M._push_mt_n = (M._push_mt_n or 0) + 1
	end
	local now = os.time()
	if M._pi_t == now then return end
	M._pi_t = now
	local slots = M.push_slots
	for _, rec in next, t do
		if type(rec) == "table" then
			for i = 1, slots do
				if type(rawget(rec, i)) ~= "table" then
					rawset(rec, i, push_new_slot())
					M._push_fill = (M._push_fill or 0) + 1
				end
			end
		end
	end
end

-- =====================================================================================================
-- [UPD v6.25] CAP NHAT BAN ONLINE -> BAN OFFLINE
--   1. Che do OFFLINE co the chay luong cap nhat goc cua game (tai tu CDN) khi nguoi dung BAT (nut GM "CAP NHAT").
--      Luon co GIOI HAN THOI GIAN: khong co mang / may chu khong tra loi => vao thang man dang nhap nhu cu.
--   2. Phat hien game vua cap nhat (phien ban APK, goi tai nguyen, so dong / cot cac bang du lieu loi) =>
--      ghi offline_update_report.txt + thong bao. Bang tuong / ky nang moi tu ap dung (LocalServer doc bang truc tiep).
--   3. Luong cap nhat goc sap tai file Lua ma mod da sua => liet ke trong bao cao (mod giu ban Lua cu => can port).
-- Khong gay hai gi neu moi thu loi: toan bo la pcall, chi doc bang, chi ghi file bao cao + 1 file moc.
-- =====================================================================================================
do
	M.upd_key        = "offline_update"          -- UserDefault: "1" = BAT, "0" = TAT
	M.upd_file       = "offline_update.txt"      -- hoac file (Download/media): on | off
	M.upd_guard_secs = 25                        -- toi da bao nhieu giay cho buoc KIEM TRA cap nhat (OFFLINE)
	M.upd_fail_max   = 3                         -- lay phien ban that bai tu ngan nay (va >= 5 giay) => coi nhu khong co mang
	M.upd_sig_file   = "offline_data_sig.txt"    -- moc phien ban + cau truc bang cua lan chay truoc
	M.upd_report     = "offline_update_report.txt"
	M.upd_plan_key   = "offline_upd_plan"        -- UserDefault: tom tat goi cap nhat sap tai
	M.upd_step_secs  = 0.002                     -- ngan sach CPU moi buoc quet bang (giay); quet thu cong (nut) = 0.008
	M.upd_delay_secs = 15                        -- doi sau khi dang nhap roi moi quet (tranh tai luc vao game)

	-- File Lua cua game ma mod da SUA. Dung de canh bao khi ban cap nhat chinh thuc cung dong vao nhung file
	-- nay (mod giu ban cu => can port lai).
	M.mod_files = {
		"client/assets/AssetsManager.lua",
		"client/assets/AssetsNotice.lua",
		"client/battle/NormalLogic.lua",
		"client/battle/Ship.lua",
		"client/battle/fight/Fight.lua",
		"client/battle/landscape/FightRole.lua",
		"client/battle/landscape/FightTeamController.lua",
		"client/battle/logics/attack_logic.lua",
		"client/battle/report/BattleObject.lua",
		"client/battle/report/BattleReport.lua",
		"client/battle/report/FightModule.lua",
		"client/battle/report/FightObject.lua",
		"client/battle/report/FightUtil.lua",
		"client/battle/report/TalentSkill.lua",
		"client/cells/formation/Lformation_change_hero_cell.lua",
		"client/formation/FormationTigerGate.lua",
		"client/l_digital/campaign/trialtower/GuanQia.lua",
		"client/l_digital/cells/cultivate/sm_cultivate_spirit_cell.lua",
		"client/landscape/duplicate/pve/LPVENpc.lua",
		"client/loader/EnvironmentDatas.lua",
		"frameworks/app.lua",
		"frameworks/network/NetworkAdaptor.lua",
		"frameworks/support/display.lua",
	}

	-- Bang du lieu "loi" (tuong / ky nang / noi tai / vat pham): theo doi them SO COT va NOI DUNG (tong byte).
	local CORE = {
		"ship_mould", "ship_evo_mould", "ship_config", "ship_grow_param", "ship_experience_param", "ship_skin_mould",
		"ship_talent_mould", "ship_talent_param", "ship_talent_group", "ship_force_mould",
		"skill_mould", "skill_influence", "talent_mould", "skill_equipment_mould", "fate_relationship_mould",
		"mega_ship", "mega_property", "prop_mould", "equipment_mould", "artifact_mould",
		"fight_spirit_mould", "fight_spirit_talent_mould",
	}
	local CORE_SET = {}
	for _, n in ipairs(CORE) do CORE_SET[n] = true end
	local SIG_KEYS = { "app", "pkg", "pmd5", "cur", "dl", "lmd5" }
	local SIG_VOLATILE = { cur = true, dl = true }   -- game tu dat ve "0" khi kiem tra lai => "0" khong co nghia
	local SIG_NAMES = {
		app = "phien ban game (app.version)", pkg = "goi tai nguyen (package)", pmd5 = "package_md5",
		cur = "current-version-code", dl = "downloaded-version-code", lmd5 = "phien ban danh sach file (md5)",
	}
	local LUA_EXT = { lua = true, luac = true }
	local DATA_EXT = { txt = true, cdn = true }

	local function squash(s) return string.lower((string.gsub(tostring(s or ""), "%s+", ""))) end
	local function truthy(s) s = squash(s); return s == "1" or s == "on" or s == "bat" or s == "true" or s == "yes" end
	local function falsy(s) s = squash(s); return s == "0" or s == "off" or s == "tat" or s == "false" or s == "no" end

	-- ---------------------------------------------------------------------------------------- 1. BAT / TAT CAP NHAT
	function M.updateEnabled()
		local ud = ud_get(M.upd_key)
		if ud ~= nil then
			if truthy(ud) then return true end
			if falsy(ud) then return false end
		end
		local now = os.time()
		local c = M._upd_file_cache
		if c ~= nil and now - c.t < 5 then return c.v end
		local ok, s = pcall(read_first, M.upd_file)
		-- [AUTO] MAC DINH BAT: chi TAT khi nguoi dung bam TAT trong GM (UserDefault = 0) hoac file offline_update.txt ghi off
		local v = true
		if ok and type(s) == "string" and falsy(s) then v = false end
		M._upd_file_cache = { t = now, v = v }
		return v
	end

	function M.setUpdateEnabled(on)
		ud_set(M.upd_key, on and "1" or "0")
		M._upd_file_cache = nil
	end

	function M.toggleUpdate()
		local on = not M.updateEnabled()
		M.setUpdateEnabled(on)
		if on then
			notify("CAP NHAT KHI MO GAME: BAT.\nLan mo game sau (OFFLINE) game se thu ket noi may chu cap nhat toi da "
				.. M.updateGuardSecs() .. " giay; khong co mang thi tu vao offline nhu thuong. Neu co ban moi se hien bang tai nhu game goc "
				.. "(nut THOAT o bang do = bo qua, van vao offline).\nHay THOAT HAN game roi mo lai.", 14)
		else
			notify("CAP NHAT KHI MO GAME: TAT - offline hoan toan, khong cham toi mang.", 7)
		end
		return on
	end

	function M.updateGuardSecs()
		local v = tonumber(M.upd_guard_secs)
		if v == nil or v < 5 then v = 25 end
		if v > 120 then v = 120 end
		return v
	end

	-- AssetsManager hoi: "stock" = luong goc (GHI/TAT), "skip" = vao thang man dang nhap, "check" = chay luong
	-- cap nhat goc nhung co gioi han thoi gian (OFFLINE + nguoi dung da BAT).
	function M.updatePlan()
		if M.getMode() ~= "replay" then return "stock" end
		if M.updateEnabled() then return "check" end
		return "skip"
	end

	-- Bang cap nhat goc co nut "Thoat game" (os.exit). OFFLINE: nut do = BO QUA cap nhat va vao game ban hien tai,
	-- neu khong nguoi dung bi ket (mo lai game lai thay bang nay).
	function M.noticeSkip()
		if M.getMode() ~= "replay" then return false end
		notify("Da BO QUA cap nhat - vao game offline (ban hien tai).\nMuon het hien bang cap nhat: GM -> CAP NHAT: TAT. Muon cap nhat: mo lai game va bam CAP NHAT.", 14)
		return true
	end

	function M.noteUpdateAborted(why)
		notify("Cap nhat bo qua (" .. tostring(why) .. ") -> vao game offline binh thuong.", 8)
	end

	-- ---------------------------------------------------------------------------------------- 3. KE HOACH TAI
	local function norm_rel(name)
		local n = string.gsub(tostring(name), "\\", "/")
		n = string.gsub(n, "^%./", "")
		n = string.gsub(n, "%.luac$", ".lua")
		return n
	end

	local function is_mod_file(n)
		local ln = #n
		for _, p in ipairs(M.mod_files or {}) do
			local lp = #p
			if ln >= lp and string.sub(n, ln - lp + 1) == p then
				if ln == lp or string.sub(n, ln - lp, ln - lp) == "/" then return true end
			end
		end
		return false
	end

	local function write_report(lines)
		local txt = table.concat(lines, "\n") .. "\n"
		local ok, where = pcall(write_first, M.upd_report, txt)
		if ok and where ~= nil then M._upd_report_path = where end
		return ok and where or nil
	end

	-- Goi tu AssetsManager:checkVersionDownload khi luong cap nhat goc xac dinh duoc danh sach file se tai.
	-- files: mang ten file (duong dan tuong doi trong goi cap nhat).
	function M.noteUpdate(files)
		if type(files) ~= "table" then return end
		local lua_all, lua_mod, data_n, other_n = {}, {}, 0, 0
		for _, name in ipairs(files) do
			local low = string.lower(tostring(name))
			local ext = string.match(low, "%.([%w_]+)$") or ""
			if LUA_EXT[ext] then
				local n = norm_rel(name)
				lua_all[#lua_all + 1] = n
				if is_mod_file(n) then lua_mod[#lua_mod + 1] = n end
			elseif DATA_EXT[ext] then
				data_n = data_n + 1
			else
				other_n = other_n + 1
			end
		end
		M._upd_plan = { total = #files, lua = #lua_all, lua_mod = #lua_mod, data = data_n, other = other_n, t = os.time() }
		ud_set(M.upd_plan_key, table.concat({ os.time(), #files, #lua_all, #lua_mod, data_n, other_n }, "|"))
		local L = {}
		L[#L + 1] = "OfflineMock " .. M.version .. " - THONG BAO CAP NHAT (truoc khi tai) " .. os.date("%Y-%m-%d %H:%M:%S")
		L[#L + 1] = "Ban cap nhat chinh thuc se tai " .. #files .. " file: " .. #lua_all .. " file Lua, " .. data_n
			.. " bang du lieu (.txt/.cdn), " .. other_n .. " file khac (hinh / am thanh / giao dien...)."
		L[#L + 1] = "- Bang du lieu (tuong, ky nang, noi tai, vat pham, chu...), hinh anh, am thanh: duoc tai ve va AP DUNG binh thuong."
		L[#L + 1] = "- Ma Lua: mod GIU BAN LUA CU cua toan bo thu muc src (mod nam o Android/media/.../src co uu tien cao nhat)."
		L[#L + 1] = "  => " .. #lua_all .. " file Lua cua ban cap nhat KHONG duoc dung trong ban offline cho toi khi duoc port."
		if #lua_mod > 0 then
			L[#L + 1] = "  => " .. #lua_mod .. " file trong so do la file MOD DA SUA (neu logic doi thi CAN PORT, gui lai ban src moi):"
			for i = 1, math.min(#lua_mod, 60) do L[#L + 1] = "       " .. lua_mod[i] end
		end
		if #lua_all > 0 then
			L[#L + 1] = "Danh sach file Lua trong ban cap nhat (toi da 80):"
			for i = 1, math.min(#lua_all, 80) do L[#L + 1] = "       " .. lua_all[i] end
		end
		local where = write_report(L)
		logmsg("cap nhat chinh thuc sap tai", #files, "file (Lua", #lua_all, "| mod da sua", #lua_mod, ") -> bao cao:", tostring(where))
		return where
	end

	-- ---------------------------------------------------------------------------------------- 2. PHAT HIEN THAY DOI
	local function sig_unknown(k, v)
		if v == nil or v == "" or v == "-" then return true end
		if SIG_VOLATILE[k] and (v == "0" or v == "0.0") then return true end
		return false
	end

	local function read_signals()
		local s = {}
		local app = rawget(_G, "app")
		s.app = (type(app) == "table" and app.version ~= nil) and tostring(app.version) or "-"
		s.pkg = ud_get("package") or "0"
		s.pmd5 = ud_get("package_md5") or "0"
		s.cur = ud_get("current-version-code") or "0"
		s.dl = ud_get("downloaded-version-code") or "0"
		local lm = type(app) == "table" and app.lmd5 or nil
		s.lmd5 = (type(lm) == "table" and lm.version ~= nil) and tostring(lm.version) or "-"
		return s
	end

	local function job_new(manual)
		local d = rawget(_G, "dms")
		if type(d) ~= "table" then return nil end
		local names = {}
		for k, v in pairs(d) do
			if type(k) == "string" and type(v) == "table" then names[#names + 1] = k end
		end
		if #names == 0 then return nil end
		table.sort(names)
		return { names = names, i = 1, tbl = {}, sig = read_signals(), manual = manual and true or false, t0 = os.time() }
	end

	-- Suma de comprobacion de una celda. Independiente de como este guardada la fila (cadena cruda "a<TAB>b" o ya cortada
	-- en {"a","b"}) y del orden de iteracion: solo suma enteros modulo P. Numeros: valor x 1000 (redondeado) x peso(columna);
	-- texto: longitud + primer/ultimo byte.
	local CK_P = 2147483647
	local CK_W = {}
	for c = 1, 256 do CK_W[c] = (c * 37 + 11) % 89 + 3 end
	local floor, sbyte = math.floor, string.byte
	local function feed(ck, col, cell)
		local w = CK_W[col] or ((col * 37 + 11) % 89 + 3)
		local v = tonumber(cell)
		if v ~= nil and v == v and v < 1e15 and v > -1e15 then
			return (ck + (floor(v * 1000 + 0.5) % CK_P) * w) % CK_P
		end
		local ln = #cell
		if ln == 0 then return ck end
		return (ck + (ln * 131 + sbyte(cell, 1) * 7 + sbyte(cell, ln) * 3) * w) % CK_P
	end

	-- Quet filas de UNA tabla hasta agotar el presupuesto; true = tabla terminada.
	local function scan_table(job, t, core, deadline)
		local acc = job.acc
		local k = job.key
		local want_id = (job.cur == "ship_mould")
		local n = 0
		while true do
			local row
			k, row = next(t, k)
			if k == nil then return true end
			job.key = k
			if tonumber(k) ~= nil then
				acc.rows = acc.rows + 1
				if core then
					local tr = type(row)
					local ck, cols, first = acc.ck, 0, nil
					if tr == "string" then
						local init = 1
						while true do
							local p = string.find(row, "\t", init, true)
							local cell
							if p == nil then cell = string.sub(row, init) else cell = string.sub(row, init, p - 1) end
							cols = cols + 1
							if cols == 1 then first = cell end
							ck = feed(ck, cols, cell)
							if p == nil then break end
							init = p + 1
						end
					elseif tr == "table" then
						cols = #row
						for i = 1, cols do
							local cell = row[i]
							if type(cell) ~= "string" then cell = tostring(cell) end
							if i == 1 then first = cell end
							ck = feed(ck, i, cell)
						end
					end
					acc.ck = ck
					if cols > acc.cols then acc.cols = cols end
					if want_id and first ~= nil then
						local id = tonumber(first)
						if id ~= nil and id > acc.maxid then acc.maxid = id end
					end
				end
			end
			n = n + 1
			if n % 32 == 0 and os.clock() >= deadline then return false end
		end
	end

	local function job_step(job)
		local d = rawget(_G, "dms")
		if type(d) ~= "table" then return true end
		local deadline = os.clock() + (job.manual and 0.008 or (tonumber(M.upd_step_secs) or 0.002))
		while true do
			if job.cur == nil then
				if job.i > #job.names then return true end
				local name = job.names[job.i]
				job.i = job.i + 1
				local t = d[name]
				if type(t) == "table" then
					job.cur, job.cur_t, job.key = name, t, nil
					job.core = CORE_SET[name] == true
					job.acc = { rows = 0, cols = 0, ck = 0, maxid = 0 }
				end
			end
			if job.cur ~= nil then
				if scan_table(job, job.cur_t, job.core, deadline) then
					local a = job.acc
					job.tbl[job.cur] = { core = job.core and 1 or 0, rows = a.rows, cols = a.cols, ck = a.ck, maxid = a.maxid }
					job.cur, job.cur_t, job.key, job.acc = nil, nil, nil, nil
				end
			end
			if os.clock() >= deadline then return job.cur == nil and job.i > #job.names end
		end
	end

	local function split_tab(line)
		local out, init = {}, 1
		while true do
			local p = string.find(line, "\t", init, true)
			if p == nil then out[#out + 1] = string.sub(line, init); break end
			out[#out + 1] = string.sub(line, init, p - 1)
			init = p + 1
		end
		return out
	end

	local function sig_serialize(sig)
		local out = { "# offline_data_sig v1 " .. os.date("%Y-%m-%d %H:%M:%S")
			.. " (moc de phat hien game cap nhat; xoa file nay = dat lai moc)" }
		for _, k in ipairs(SIG_KEYS) do out[#out + 1] = "S\t" .. k .. "\t" .. tostring(sig.s[k]) end
		local names = {}
		for name in pairs(sig.t) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local r = sig.t[name]
			out[#out + 1] = table.concat({ "T", name, r.core, r.rows, r.cols, r.ck, r.maxid }, "\t")
		end
		return table.concat(out, "\n") .. "\n"
	end

	local function sig_parse(txt)
		if type(txt) ~= "string" then return nil end
		local sig = { s = {}, t = {} }
		for line in string.gmatch(txt, "[^\r\n]+") do
			local f = split_tab(line)
			if f[1] == "S" and f[2] ~= nil and f[3] ~= nil then
				sig.s[f[2]] = f[3]
			elseif f[1] == "T" and f[2] ~= nil then
				sig.t[f[2]] = { core = tonumber(f[3]) or 0, rows = tonumber(f[4]) or 0, cols = tonumber(f[5]) or 0,
					ck = tonumber(f[6]) or 0, maxid = tonumber(f[7]) or 0 }
			end
		end
		local n = 0
		for _ in pairs(sig.t) do n = n + 1 end
		if n == 0 then return nil end
		return sig
	end

	local function by_name(a, b) return a[1] < b[1] end

	local function compare(old, new_s, new_t)
		local r = { sigs = {}, rows = {}, core_rows = 0, cols = {}, edits = {}, new_hero = 0, upgrade = false }
		for _, k in ipairs(SIG_KEYS) do
			local a, b = old.s[k], new_s[k]
			if a ~= nil and b ~= nil and a ~= b and not sig_unknown(k, a) and not sig_unknown(k, b) then
				r.sigs[#r.sigs + 1] = { k, a, b }
			end
		end
		for name, nt in pairs(new_t) do
			local ot = old.t[name]
			if ot == nil or ot.core ~= nt.core then r.upgrade = true end
			if ot ~= nil then
				if ot.rows ~= nt.rows then
					r.rows[#r.rows + 1] = { name, ot.rows, nt.rows, nt.core == 1 }
					if nt.core == 1 then r.core_rows = r.core_rows + 1 end
				end
				if nt.core == 1 and ot.core == 1 then
					if ot.cols ~= nt.cols then
						r.cols[#r.cols + 1] = { name, ot.cols, nt.cols }
					elseif ot.rows == nt.rows and ot.ck ~= nt.ck then
						r.edits[#r.edits + 1] = { name }
					end
				end
			end
		end
		table.sort(r.rows, by_name)
		table.sort(r.cols, by_name)
		table.sort(r.edits, by_name)
		local o, n = old.t["ship_mould"], new_t["ship_mould"]
		if o ~= nil and n ~= nil and o.maxid > 0 and n.maxid > o.maxid then
			-- cuenta modelos de tuong con id mayor que el mayor anterior
			r.new_hero_from = o.maxid
			local d = rawget(_G, "dms")
			local t = type(d) == "table" and d["ship_mould"] or nil
			local ids = {}
			if type(t) == "table" then
				for _, row in pairs(t) do
					local id
					if type(row) == "string" then id = tonumber(string.match(row, "^([^\t]*)"))
					elseif type(row) == "table" then id = tonumber(row[1]) end
					if id ~= nil and id > o.maxid then ids[#ids + 1] = id end
				end
			end
			table.sort(ids)
			r.new_ids = ids
			r.new_hero = #ids
		end
		r.important = (#r.sigs > 0) or (r.core_rows > 0) or (#r.cols > 0) or (#r.edits > 0) or (r.new_hero > 0)
		r.any = r.important or (#r.rows > 0)
		return r
	end

	local function plan_summary()
		local s = ud_get(M.upd_plan_key)
		if s == nil then return nil end
		local f = {}
		for w in string.gmatch(s, "[^|]+") do f[#f + 1] = tonumber(w) or 0 end
		if #f < 6 then return nil end
		return { t = f[1], total = f[2], lua = f[3], lua_mod = f[4], data = f[5], other = f[6] }
	end

	local function build_report(res, manual)
		local L = {}
		L[#L + 1] = "OfflineMock " .. M.version .. " - BAO CAO CAP NHAT " .. os.date("%Y-%m-%d %H:%M:%S")
		if res.important then
			L[#L + 1] = "Nhan dien: game vua duoc cap nhat (hoac du lieu / ban game da doi) so voi lan kiem tra truoc."
		elseif manual then
			L[#L + 1] = "Kiem tra thu cong: khong co thay doi dang ke trong du lieu loi so voi lan truoc."
		end
		L[#L + 1] = ""
		if #res.sigs > 0 then
			L[#L + 1] = "[Phien ban]"
			for _, x in ipairs(res.sigs) do
				L[#L + 1] = "  " .. (SIG_NAMES[x[1]] or x[1]) .. ": " .. x[2] .. " -> " .. x[3]
			end
			L[#L + 1] = ""
		end
		local plan = plan_summary()
		if plan ~= nil and res.important then
			L[#L + 1] = "[Lan cap nhat chinh thuc gan nhat] tai " .. plan.total .. " file: " .. plan.lua .. " Lua (" .. plan.lua_mod
				.. " la file mod da sua), " .. plan.data .. " bang du lieu, " .. plan.other .. " file khac."
			if plan.lua > 0 then L[#L + 1] = "  (danh sach Lua nam trong ban 'THONG BAO CAP NHAT' ghi truoc khi tai - da bi ghi de neu ban doc file nay sau.)" end
			L[#L + 1] = ""
		end
		if #res.cols > 0 then
			L[#L + 1] = "[CANH BAO - doi SO COT bang du lieu loi] LocalDatas.lua (chi so cot cu) co the khong con khop => CAN PORT:"
			for _, x in ipairs(res.cols) do L[#L + 1] = "  " .. x[1] .. ": " .. x[2] .. " cot -> " .. x[3] .. " cot" end
			L[#L + 1] = ""
		end
		if #res.edits > 0 then
			L[#L + 1] = "[Bang loi doi NOI DUNG (cung so dong va so cot)] - vd chi so / ky nang tuong duoc chinh sua:"
			for _, x in ipairs(res.edits) do L[#L + 1] = "  " .. x[1] end
			L[#L + 1] = ""
		end
		if #res.rows > 0 then
			L[#L + 1] = "[Doi so dong] (* = bang loi)"
			for i, x in ipairs(res.rows) do
				if i > 80 then L[#L + 1] = "  ... (con " .. (#res.rows - 80) .. " bang nua)"; break end
				local d = x[3] - x[2]
				L[#L + 1] = "  " .. (x[4] and "* " or "  ") .. x[1] .. ": " .. x[2] .. " -> " .. x[3] .. " (" .. (d >= 0 and "+" or "") .. d .. ")"
			end
			L[#L + 1] = ""
		end
		if res.new_hero > 0 then
			local ids = {}
			for i = 1, math.min(#res.new_ids, 60) do ids[#ids + 1] = tostring(res.new_ids[i]) end
			L[#L + 1] = "[Mau tuong moi trong ship_mould] " .. res.new_hero .. " id: " .. table.concat(ids, ",")
				.. (#res.new_ids > 60 and ",..." or "")
			L[#L + 1] = ""
		end
		L[#L + 1] = "TU AP DUNG: bang tuong / ky nang / noi tai / vat pham / chu moi, hinh anh, am thanh (tran dau tinh trong may => ky nang, noi tai doi"
		L[#L + 1] = "  la co hieu luc ngay; LocalServer doc bang truc tiep => tuong moi co the vao trieu hoi / bot dau truong / bot leo thap neu du file hinh)."
		L[#L + 1] = "KHONG TU AP DUNG: (1) ma Lua cua game (mod giu ban cu) - xem danh sach 'CAN PORT'; (2) chi so tuong / vat pham DA CO"
		L[#L + 1] = "  (do may chu that tinh, offline chi giu ban ghi cu) => TU DONG (neu CAP NHAT: BAT): lan mo game ke tiep se tu GHI roi tu ve OFFLINE, khong can bam OM. Thu cong: OM -> GHI -> mo lai -> OM -> TU GHI -> OM -> OFFLINE;"
		L[#L + 1] = "  (3) su kien / giao thuc server moi chua co trong ban ghi: xem offline_missing.txt."
		L[#L + 1] = "Neu bi loi sau cap nhat: gui lai offline_update_report.txt + offline_errors.txt + ban src moi cua game de port."
		return L
	end

	local function summary_toast(res, armed)
		local parts = {}
		if #res.sigs > 0 then parts[#parts + 1] = "phien ban/goi tai nguyen doi" end
		if #res.cols > 0 then parts[#parts + 1] = #res.cols .. " bang loi DOI SO COT (can port!)" end
		if res.core_rows > 0 then parts[#parts + 1] = res.core_rows .. " bang loi doi so dong" end
		if #res.edits > 0 then parts[#parts + 1] = #res.edits .. " bang loi doi noi dung" end
		if res.new_hero > 0 then parts[#parts + 1] = res.new_hero .. " mau tuong moi" end
		return "GAME VUA CAP NHAT: " .. table.concat(parts, ", ") .. ".\nChi tiet: offline_update_report.txt. Du lieu tuong/ky nang moi tu ap dung."
			.. (armed and "\nChi so tuong DANG CO: lan mo game ke tiep se TU GHI (dang nhap xong de may o man hinh chinh ~5 phut) roi TU ve OFFLINE - khong can bam OM."
				or "\nMuon chi so tuong DANG CO khop ban moi thi GHI lai 1 lan (OM -> GHI).")
	end

	-- Nuevo moc = moc anterior + lo escaneado ahora: una tabla que hoy no esta cargada conserva su valor anterior;
	-- una senal desconocida hoy ("-", o "0" en current/downloaded) no pisa un valor conocido.
	local function merge_sig(old, job)
		local tbl = {}
		for name, r in pairs(old.t) do tbl[name] = r end
		for name, r in pairs(job.tbl) do tbl[name] = r end
		local sg = {}
		for _, k in ipairs(SIG_KEYS) do
			local o, n = old.s[k], job.sig[k]
			if sig_unknown(k, n) and o ~= nil then sg[k] = o else sg[k] = n end
		end
		return { s = sg, t = tbl }
	end

	local function job_finish(job)
		local old = nil
		local ok_r, old_txt = pcall(read_first, M.upd_sig_file)
		if ok_r then old = sig_parse(old_txt) end
		local result = { first = (old == nil), tables = #job.names }
		if old == nil then
			pcall(write_first, M.upd_sig_file, sig_serialize({ s = job.sig, t = job.tbl }))
			logmsg("UPD: luu moc phien ban + cau truc bang (lan dau)", #job.names, "bang")
			if job.manual then
				notify("Da luu MOC du lieu hien tai (lan dau, " .. #job.names .. " bang). Tu lan sau, neu game cap nhat, bao cao se hien o day.", 9)
			end
			M._upd_last = result
			return result
		end
		local res = compare(old, job.sig, job.tbl)
		result.res = res
		if res.important or job.manual then
			local where = write_report(build_report(res, job.manual))
			logmsg("UPD: bao cao:", tostring(where), "| quan trong:", tostring(res.important))
			if res.important then
				local armed = false
				if M.refreshArm ~= nil then
					local okA, a = pcall(M.refreshArm, res)
					armed = okA and a == true
				end
				notify(summary_toast(res, armed), 20)
			else
				notify("Du lieu loi va phien ban game KHONG doi so voi lan kiem tra truoc (" .. #job.names .. " bang).", 8)
			end
		elseif res.any then
			logmsg("UPD: chi doi so dong o bang phu (" .. #res.rows .. " bang) - khong bao")
		else
			logmsg("UPD: du lieu va phien ban khong doi")
		end
		local merged = merge_sig(old, job)
		local sig_moved = false
		for _, k in ipairs(SIG_KEYS) do if merged.s[k] ~= old.s[k] then sig_moved = true end end
		if res.any or res.important or res.upgrade or sig_moved then
			pcall(write_first, M.upd_sig_file, sig_serialize(merged))
			if res.important then ud_set(M.upd_plan_key, "") end
		end
		M._upd_last = result
		return result
	end

	function M.updWatchStart(manual)
		if M._upd_job ~= nil then
			if manual then notify("Dang quet bang du lieu... doi vai giay.", 4) end
			return false
		end
		local job = job_new(manual)
		if job == nil then
			if manual then notify("Chua co bang du lieu de quet (vao game roi bam lai).", 5) end
			return false
		end
		M._upd_job = job
		if manual then notify("Dang kiem tra du lieu game... (vai giay)", 4) end
		local scheduled = schedule(manual and 0.05 or 0.1, function()
			local j = M._upd_job
			if j == nil then return true end
			-- [v6] quet tu dong tam nghi khi dang danh (khong gianh CPU/RAM cua tran); quet tay (nut OM) van chay
			if not manual and M.inFight() then return false end
			local okp, done = pcall(job_step, j)
			if not okp then
				logmsg("UPD: loi khi quet bang:", tostring(done))
				M._upd_job = nil
				return true
			end
			if done then
				M._upd_job = nil
				local okf, err = pcall(job_finish, j)
				if not okf then logmsg("UPD: loi khi so sanh:", tostring(err)) end
				return true
			end
			return false
		end)
		if not scheduled then M._upd_job = nil; return false end
		return true
	end

	local function upd_logged_in()
		local ed = rawget(_G, "_ED")
		local uid = type(ed) == "table" and type(ed.user_info) == "table" and ed.user_info.user_id or nil
		return uid ~= nil and tonumber(uid) ~= nil and tonumber(uid) > 0
	end

	-- Moi 0.5 giay (M.tick): sau khi dang nhap + doi mot luc, quet 1 lan.
	function M.updWatchTick()
		if M._upd_watch_done or M._upd_job ~= nil then return end
		if not upd_logged_in() then return end
		if M.inFight() then return end
		M._upd_login_t = M._upd_login_t or os.time()
		if os.time() - M._upd_login_t < (tonumber(M.upd_delay_secs) or 15) then return end
		M._upd_watch_done = true
		M.updWatchStart(false)
	end

	-- cho test
	M._upd_compare = compare
	M._upd_sig_parse = sig_parse
	M._upd_job_new = job_new
	M._upd_job_step = job_step
	M._upd_job_finish = job_finish
	M._upd_build_report = build_report
end

-- =====================================================================================================
-- [REFRESH v6.30] TU GHI KHI CAP NHAT:  OFFLINE -> (tu dong) GHI -> (tu dong) OFFLINE
-- Truoc day: game cap nhat xong, tuong CO SAN van giu chi so cu => phai tu tay OM -> GHI -> mo lai -> OM -> TU GHI -> OM -> OFFLINE.
-- Gio (can "CAP NHAT: BAT", mac dinh BAT):
--   1. OFFLINE phat hien game vua cap nhat (job_finish -> res.important) => M.refreshArm(): danh dau "can ghi lai" +
--      dat che do lan mo game sau = GHI. Dang choi OFFLINE binh thuong, khong bi gian doan.
--   2. Lan mo ke tiep (GHI): dang nhap xong, doi M.refresh_idle_secs roi TU bam TU GHI. Moi thu ghi vao offline_rec.new.txt
--      (KHONG dung toi ban ghi cu trong luc ghi).
--   3. TU GHI xong => GOP: lenh nao ban ghi moi co thi thay ban cu, lenh nao khong co thi giu ban cu (ban cu sao luu
--      .prev) => dat che do = OFFLINE, hieu chuan lai chi so LocalServer, (tuy chon) tu thoat game. Mo lai la choi OFFLINE.
-- Bao ve: toi da M.refresh_max_try lan mo game o che do GHI; dang nhap khong duoc / mang loi / TU GHI hong => tu ve OFFLINE.
-- Tat: GM -> CAP NHAT: TAT, hoac file offline_refresh.txt ghi "off". Ban ghi gop co dong "#REFRESHED <gio>" (loadDb dung ban nay
-- va bo ban dong goi san + cac ban sao cu).
-- =====================================================================================================
do
	M.refresh_key        = "offline_refresh"       -- UserDefault: "1" = dang cho / dang ghi lai sau cap nhat
	M.refresh_try_key    = "offline_refresh_try"   -- so lan mo game o che do GHI cho dot nay
	M.refresh_recal_key  = "offline_recal"         -- UserDefault: "1" = lan OFFLINE ke tiep hieu chuan lai LocalServer
	M.refresh_file       = "offline_refresh.txt"   -- file (Download/media): off = khong tu ghi khi cap nhat
	M.rec_new_file       = "offline_rec.new.txt"   -- ban ghi tam trong luc tu cap nhat
	M.refresh_max_try    = 2                       -- toi da bao nhieu lan mo game o che do GHI
	M.refresh_login_secs = 240                     -- toi da doi dang nhap (giay)
	M.refresh_idle_secs  = 12                      -- sau khi dang nhap doi bao lau roi tu bam TU GHI
	M.refresh_retry_max  = 3                       -- so lan TU GHI toi da trong 1 phien
	M.refresh_autoquit   = true                    -- ghi xong tu thoat game (mo lai la OFFLINE)
	M.refresh_quit_secs  = 15

	local function rf_logged_in()
		local ed = rawget(_G, "_ED")
		local uid = type(ed) == "table" and type(ed.user_info) == "table" and ed.user_info.user_id or nil
		return uid ~= nil and tonumber(uid) ~= nil and tonumber(uid) > 0
	end

	local function rf_tutorial_open()
		local fw = rawget(_G, "fwin")
		if type(fw) ~= "table" or type(fw.find) ~= "function" then return false end
		local okf, w = pcall(fw.find, fw, "TuitionControllerClass")
		return okf and w ~= nil
	end

	function M.refreshEnabled()
		if M.updateEnabled ~= nil then
			local ok, v = pcall(M.updateEnabled)
			if ok and v == false then return false end
		end
		local ok, s = pcall(read_first, M.refresh_file)
		if ok and type(s) == "string" then
			s = string.lower((string.gsub(s, "%s+", "")))
			if s == "0" or s == "off" or s == "tat" or s == "false" or s == "no" then return false end
		end
		return true
	end

	function M.refreshPending()
		return ud_get(M.refresh_key) == "1"
	end

	-- Ghi vao file tam khi dang tu cap nhat (xem M.record)
	function M.recWriteName()
		local rf = M._rf
		if rf ~= nil and (rf.state == "wait" or rf.state == "run") then return M.rec_new_file end
		return M.rec_file
	end

	-- Goi tu job_finish khi OFFLINE phat hien game vua cap nhat. Tra true neu da len lich tu ghi.
	function M.refreshArm(res)
		if M.getMode() ~= "replay" then return false end
		if M.refreshPending() then return true end
		if not M.refreshEnabled() then return false end
		ud_set(M.refresh_key, "1")
		ud_set(M.refresh_try_key, "0")
		ud_set(M.ud_key, "record")
		M._next_mode = "record"
		logmsg("REFRESH: da len lich TU GHI sau cap nhat (lan mo game ke tiep = GHI tu dong)")
		return true
	end

	-- Goi trong M.install sau khi biet che do cua phien nay.
	function M.refreshBoot(mode)
		if M._refresh_gaveup then
			notify("TU CAP NHAT: da thu " .. tostring(M.refresh_max_try) .. " lan o che do GHI ma khong xong (mang / dang nhap?).\nDa quay lai OFFLINE. Muon thu lai: OM -> GHI -> mo lai -> OM -> TU GHI.", 20)
		end
		if not M.refreshPending() then return end
		if mode ~= "record" then
			-- nguoi dung da tu chon che do khac => ton trong, huy dot tu ghi
			ud_set(M.refresh_key, "0")
			ud_set(M.refresh_try_key, "0")
			return
		end
		local n = (tonumber(ud_get(M.refresh_try_key)) or 0) + 1
		ud_set(M.refresh_try_key, tostring(n))
		M._rf = { t0 = os.time(), state = "wait", tries = 0, n = n }
		pcall(function()
			local p = writable_target(M.rec_new_file)
			if p ~= nil then
				local f = io.open(p, "wb")
				if f then f:close() end
			end
		end)
		notify("TU CAP NHAT CHI SO (lan " .. n .. "/" .. tostring(M.refresh_max_try) .. "): dang nhap vao game roi CU DE MAY O MAN HINH CHINH.\n"
			.. "Game tu ghi du lieu moi (khoang 5 phut), xong tu ve OFFLINE. Khong co mang: bam OM -> OFFLINE.", 20)
		logmsg("REFRESH: phien GHI tu dong, lan", n)
	end

	-- Huy dot tu cap nhat. keep_mode = true: khong dong cham toi che do nguoi dung vua chon.
	function M.refreshAbort(why, keep_mode)
		ud_set(M.refresh_key, "0")
		ud_set(M.refresh_try_key, "0")
		if not keep_mode then
			ud_set(M.ud_key, "replay")
			M._next_mode = "replay"
		end
		M._rf = nil
		logmsg("REFRESH: huy:", tostring(why))
		notify("TU CAP NHAT dung: " .. tostring(why) .. "."
			.. (keep_mode and "" or "\nLan mo game sau se vao OFFLINE (thoat han game roi mo lai)."), 15)
	end

	-- Cac nguon ban ghi theo thu tu nap. Co ban GOP (dong "#REFRESHED" o dau file) => chi dung ban gop moi nhat,
	-- bo ban dong goi san va cac ban sao cu. Chua tung gop => nhu truoc: ban dong goi san truoc, roi cac file cua may.
	function M.recSources()
		local list = {}
		local paths = candidates(M.rec_file)
		local marked, plain, best = {}, {}, nil
		for i = 1, #paths do
			local f = io.open(paths[i], "rb")
			if f then
				local head = f:read(200) or ""
				f:close()
				local mk = string.match(head, "\n#REFRESHED ([^\r\n]*)")
				if mk ~= nil then
					marked[#marked + 1] = { path = paths[i], mk = mk }
					if best == nil or mk > best then best = mk end
				else
					plain[#plain + 1] = { path = paths[i] }
				end
			end
		end
		if best ~= nil then
			for i = 1, #marked do
				if marked[i].mk == best then list[#list + 1] = marked[i] end
			end
			return list, true
		end
		list[#list + 1] = { seed = true }
		for i = 1, #plain do list[#list + 1] = plain[i] end
		return list, false
	end

	function M.recRead(e)
		if e.seed then
			local ok, s, where = pcall(read_seed, M.rec_file)
			if ok and type(s) == "string" and s ~= "" then return s, "[dong goi san] " .. tostring(where) end
			return nil
		end
		local s = read_all(e.path)
		if s ~= nil then return s, e.path end
		return nil
	end

	local function rf_lines(src)
		if string.sub(src, -1) ~= "\n" then src = src .. "\n" end
		return string.gmatch(src, "([^\n]*)\n")
	end

	local function rf_parse(line)
		line = (string.gsub(line, "\r$", ""))
		if line == "" or string.sub(line, 1, 1) == "#" then return nil end
		local c, q, r = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)$")
		if c == nil or c == "" then return nil end
		return c .. "\t" .. norm_req(unesc(q)), line
	end

	-- GOP: ban ghi moi (offline_rec.new.txt) thay cac lenh cung (ten + yeu cau) trong ban cu; giu ban cu cho lenh khong co ban moi.
	local function rf_merge()
		local npath = writable_target(M.rec_new_file)
		local ntxt = npath ~= nil and read_all(npath) or nil
		if type(ntxt) ~= "string" or #ntxt < 20 then return nil, "khong co du lieu moi (offline_rec.new.txt rong)" end
		local newkeys, nseen, nlines = {}, {}, {}
		for line in rf_lines(ntxt) do
			local key, ln = rf_parse(line)
			if key ~= nil and not nseen[ln] then
				nseen[ln] = true
				newkeys[key] = true
				nlines[#nlines + 1] = ln
			end
		end
		if #nlines == 0 then return nil, "ban ghi moi khong co dong hop le" end
		local out = { "#OFFLINE_REC v1", "#REFRESHED " .. os.date("%Y-%m-%d %H:%M:%S") }
		local kept, replaced, rkeys, oseen = 0, 0, {}, {}
		local srcs = M.recSources()
		for i = 1, #srcs do
			local src = M.recRead(srcs[i])
			if src ~= nil then
				for line in rf_lines(src) do
					local key, ln = rf_parse(line)
					if key ~= nil then
						if newkeys[key] then
							if not rkeys[key] then rkeys[key] = true; replaced = replaced + 1 end
						elseif not oseen[ln] then
							oseen[ln] = true
							kept = kept + 1
							out[#out + 1] = ln
						end
					end
				end
			end
		end
		for i = 1, #nlines do out[#out + 1] = nlines[i] end
		local text = table.concat(out, "\n") .. "\n"
		local target = writable_target(M.rec_file)
		if target == nil then return nil, "khong ghi duoc offline_rec.txt" end
		pcall(function()
			local old = read_all(target)
			if old ~= nil and #old > 0 then
				local f = io.open(target .. ".prev", "wb")
				if f then f:write(old); f:close() end
			end
		end)
		local okw = false
		local oka, done = pcall(write_atomic, target, text)
		if oka and done then okw = true end
		if not okw then
			local f = io.open(target, "wb")
			if f then
				local w = f:write(text)
				local c = f:close()
				okw = (w ~= nil and c ~= nil and c ~= false)
			end
		end
		if not okw then return nil, "ghi offline_rec.txt that bai" end
		local back = read_all(target)
		if type(back) ~= "string" or #back ~= #text then return nil, "kiem tra lai file sau khi ghi that bai" end
		pcall(os.remove, npath)
		return { new = #nlines, replaced = replaced, kept = kept, path = target }
	end
	M._rf_merge = rf_merge

	function M.consumeRecal()
		if ud_get(M.refresh_recal_key) == "1" then
			ud_set(M.refresh_recal_key, "0")
			return true
		end
		return false
	end

	local function rf_finalize()
		local rf = M._rf
		if rf == nil then return end
		local info, err = rf_merge()
		if info == nil then
			logmsg("REFRESH: gop that bai:", tostring(err))
			notify("TU CAP NHAT: gop ban ghi that bai (" .. tostring(err) .. "). Ban cu van nguyen ven. Se thu lai lan mo game sau.", 15)
			rf.state = "failed"
			return
		end
		ud_set(M.refresh_key, "0")
		ud_set(M.refresh_try_key, "0")
		ud_set(M.refresh_recal_key, "1")
		ud_set(M.ud_key, "replay")
		M._next_mode = "replay"
		local msg = "TU CAP NHAT XONG: " .. info.new .. " lenh moi (thay " .. info.replaced .. " ban cu, giu " .. info.kept
			.. " ban cu khong co ban moi).\nLan mo game ke tiep = OFFLINE."
		if M.refresh_autoquit then
			rf.state = "quit"
			rf.quit_at = os.time() + (tonumber(M.refresh_quit_secs) or 15)
			msg = msg .. "\nGame tu thoat sau " .. (tonumber(M.refresh_quit_secs) or 15) .. " giay - mo lai la choi OFFLINE."
		else
			rf.state = "done"
			msg = msg .. "\nHay THOAT HAN game roi mo lai."
		end
		logmsg("REFRESH: xong", info.new, info.replaced, info.kept, tostring(info.path))
		notify(msg, 40)
	end

	-- Goi tu finish() cua TU GHI.
	function M.refreshOnFinish(st, reason)
		local rf = M._rf
		if rf == nil or st == nil then return end
		if reason == "done" then
			local total = #st.items
			local need = math.max(5, math.floor(total * 0.5))
			if st.ok >= need then
				rf.state = "merging"
				-- tre 0.5 giay de khong gop tai khung hinh dang xu ly
				local scheduled = schedule(0.5, function()
					local okf, err = pcall(rf_finalize)
					if not okf then
						logmsg("REFRESH: loi khi gop:", tostring(err))
						notify("TU CAP NHAT: loi khi gop (" .. tostring(err) .. "). Ban cu van nguyen ven.", 15)
						if M._rf ~= nil then M._rf.state = "failed" end
					end
					return true
				end)
				if not scheduled then pcall(rf_finalize) end
			else
				rf.state = "failed"
				notify("TU CAP NHAT: ghi duoc it (" .. st.ok .. "/" .. total .. " lenh) - se thu lai lan mo game sau.", 15)
			end
		elseif reason == "mode" then
			M.refreshAbort("ban doi che do", true)
		elseif reason == "user" then
			M.refreshAbort("ban da dung TU GHI")
		else
			-- mang loi / phien loi / thoat tai khoan / huong dan tan thu: cho dang nhap lai roi thu tiep
			rf.state = "wait"
			rf.login_t = nil
		end
	end

	-- Moi 0.5 giay (M.tick)
	function M.refreshTick()
		local rf = M._rf
		if rf == nil then return end
		if M.getMode() ~= "record" then M._rf = nil; return end
		local now = os.time()
		if rf.state == "quit" then
			if now >= (rf.quit_at or now) then
				rf.state = "quitting"
				pcall(os.exit)
			end
			return
		end
		if rf.state ~= "wait" and rf.state ~= "run" then return end
		if M.autoActive() then rf.state = "run"; return end
		rf.state = "wait"
		if not rf_logged_in() then
			rf.login_t = nil
			if now - rf.t0 > (tonumber(M.refresh_login_secs) or 240) then
				M.refreshAbort("khong dang nhap duoc sau " .. tostring(M.refresh_login_secs) .. " giay (khong co mang?)")
			end
			return
		end
		if M.inFight() or rf_tutorial_open() or not F.send then return end
		rf.login_t = rf.login_t or now
		if now - rf.login_t < (tonumber(M.refresh_idle_secs) or 12) then return end
		if rf.next_try ~= nil and now < rf.next_try then return end
		rf.next_try = now + 4
		if rf.tries >= (tonumber(M.refresh_retry_max) or 3) then
			M.refreshAbort("TU GHI loi " .. rf.tries .. " lan lien tiep")
			return
		end
		local ok, started = pcall(M.autoStart)
		if ok and started then
			rf.tries = rf.tries + 1
			rf.state = "run"
		end
	end
end

function M.tick()
	pcall(hud_tick)
	pcall(M.attach)
	pcall(fallback_skip_update)
	pcall(M.gmRender)
	pcall(M.omRender)
	pcall(M.tpRender)
	pcall(M.wpRender)
	pcall(M.autoOffer)
	pcall(M.unstickTick)
	pcall(M.cleanBadShips)
	pcall(M.guardPushInfo)
	pcall(M.guardRedDots)
	pcall(M.updWatchTick)
	pcall(M.refreshTick)
end

function M.install()
	if M._installed then return end
	M._installed = true
	F.install = true
	local mode = M.getMode()
	M.enableToggle()
	pcall(M.uiLoad)
	pcall(M.uiApply)
	pcall(M.gmLoad)
	pcall(M.enableGMTouch)
	pcall(M.attach)
	pcall(M.autoSchedule)
	if mode ~= "off" then pcall(M.fgStart) end
	if mode ~= "off" then pcall(M.fuStart) end

	schedule(0.5, function()
		M.tick()
		return false
	end)

	schedule(0.25, function()
		pcall(M.gmApply)
		return false
	end)
	logmsg("OfflineMock " .. M.version .. ": chế độ " .. MODE_NAME[mode])
	pcall(M.refreshBoot, mode)

	if mode ~= "replay" then
		if mode ~= "off" then pcall(M.bbStart) end
		return
	end

	local okdb, errdb = pcall(M.loadDb)
	if not okdb then logmsg("lỗi nạp dữ liệu ghi:", errdb) end
	local A = NetworkAdaptor

	A.LuaSocket.status = 1
	A.LuaSocket.reconnect = false
	A.socketInit = function(url) A.LuaSocket.url = url end
	A.socketClose = function() A.LuaSocket.url = nil end
	A.reconnectSocket = function() end
	A.restartSocket = function() end
	A.socketIsOpen = function() return true end
	A.socketSend = function(sendStr, request)
		if request ~= nil then
			if request.str == nil then request.str = sendStr end
			M.intercept(request)
		end
		return true
	end

	pcall(M.hookLuaErrors)

	pcall(M.startLS)
	pcall(M.bbStart)
	schedule(M.ls_period, function()
		if ls_active() then pcall(M.LS.sync) end
		return false
	end)
	-- [FIX lag 8] LS ghi trang thai chia nho theo frame => khi game xuong nen ghi dong bo ngay (khong mat thao tac cuoi)
	pcall(function()
		local evname = cc.EVENT_COME_TO_BACKGROUND or "event_come_to_background"
		local lis = cc.EventListenerCustom:create(evname, function()
			if ls_active() and M.LS.flush ~= nil then pcall(M.LS.flush) end
		end)
		cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(lis, 1)
	end)
	logmsg("đã bật chế độ OFFLINE (replay)", ls_active() and "+ LocalServer" or "(không có LocalServer)")
end

function M.cleanBadShips()
	local now = os.time()
	if M._clean_last ~= nil and now - M._clean_last < 5 then return end
	M._clean_last = now
	local e = rawget(_G, "_ED")
	local d = rawget(_G, "dms")
	if e == nil or type(e.user_ship) ~= "table" then return end
	if type(d) ~= "table" or type(d["ship_mould"]) ~= "table" then return end
	if not ls_active() or type(M.LS._state) ~= "function" then return end
	local S = M.LS._state()
	if type(S) ~= "table" or type(S.heroes) ~= "table" then return end

	local sch = rawget(_G, "ship_mould")
	local c_fit = (type(sch) == "table" and tonumber(sch.fitSkillTwo)) or 72
	local c_rank = (type(sch) == "table" and tonumber(sch.max_rank_level)) or 44
	local c_mat = (type(sch) == "table" and tonumber(sch.required_material_id)) or 15
	local c_base2 = (type(sch) == "table" and tonumber(sch.base_mould2)) or 28

	local total, bad, lr_bad = 0, {}, {}
	for sid, ship in pairs(e.user_ship) do
		if type(ship) == "table" then
			total = total + 1
			local tid = tonumber(ship.ship_template_id)
			if tid ~= nil then
				-- Chi tuong do LocalServer them moi duoc tu dong go. Tuong that
				-- cua tai khoan khong bao gio bi dong cham vao day.
				local is_ls = S.heroes[tostring(sid)] ~= nil
				-- 8 tuong Combo Card la LR theo bo du lieu nay, nhung la tướng
				-- bat buoc cua he thong Combo Card. Chi giu dung danh sach nay.
				local combo_ok = false
				if is_ls and type(M.LS.hero_combo_safe) == "function" then
					local ok_combo, yes = pcall(M.LS.hero_combo_safe, tid)
					combo_ok = ok_combo and yes == true
				end
				local keep = true
				if is_ls and type(M.LS.hero_safe) == "function" then
					local ok_safe, safe = pcall(M.LS.hero_safe, tid)
					if ok_safe and safe == false and not combo_ok then keep = false end
				end
				if not keep then
					lr_bad[#lr_bad + 1] = tostring(sid)
				elseif combo_ok then
					-- Bo qua kiem tra du lieu tong quat: mot so Combo Card LR
					-- khong co day du truong cua tuong recruit thong thuong.
				else
					local ok1, fit2 = pcall(d.string, d["ship_mould"], tid, c_fit)
					local ok2, rank = pcall(d.string, d["ship_mould"], tid, c_rank)
					local ok3, mat = pcall(d.string, d["ship_mould"], tid, c_mat)
					local ok4, b2 = pcall(d.string, d["ship_mould"], tid, c_base2)
					local nomat = ok3 and ok4 and ((tonumber(mat) or 0) <= 0 or (tonumber(b2) or 0) <= 0)
					if not ok1 or not ok2 or fit2 == nil or fit2 == "" or fit2 == "-1" or rank == nil or rank == "" or nomat then
						bad[#bad + 1] = tostring(sid)
					end
				end
			end
		end
	end
	-- Nhung tuong LR do tool them truoc do phai duoc go du an toan chung
	-- cua bo don dep du lieu co kich hoat hay khong.
	for i = 1, #lr_bad do bad[#bad + 1] = lr_bad[i] end
	if #bad == 0 then return end
	if (#bad - #lr_bad) * 2 > total then
		if not M._clean_warned then
			M._clean_warned = true
			logmsg("don dep tuong loi: bo qua vi qua nhieu tuong bi coi la loi", #bad - #lr_bad, "/", total)
		end
		bad = lr_bad
	end

	local set = {}
	for i = 1, #bad do set[bad[i]] = true end
	for i = 1, #bad do e.user_ship[bad[i]] = nil end
	if type(e.formetion) == "table" then
		for i = 2, 7 do
			if set[tostring(e.formetion[i])] then e.formetion[i] = "0" end
		end
	end
	if type(e.user_formetion_status) == "table" then
		for i = 1, 6 do
			if set[tostring(e.user_formetion_status[i])] then e.user_formetion_status[i] = "0" end
		end
	end
	if type(S.formation) == "table" then
		for i = 1, 6 do
			if S.formation[i] ~= nil and set[tostring(S.formation[i])] then S.formation[i] = "0" end
		end
	end
	for i = 1, #bad do
		local sid = bad[i]
		S.heroes[sid] = nil
		if type(S.eq) == "table" and type(S.eq.hard) == "table" then S.eq.hard[sid] = nil end
		if type(S.mega) == "table" then S.mega[sid] = nil end
		if type(S.mods) == "table" then S.mods[sid] = nil end
	end
	if type(S.order) == "table" then
		local order = {}
		for i = 1, #S.order do
			if not set[tostring(S.order[i])] then order[#order + 1] = S.order[i] end
		end
		S.order = order
	end
	local count = 0
	for _ in pairs(e.user_ship) do count = count + 1 end
	e.user_ship_number = count
	pcall(M.LS.save_state, true)
	logmsg("da don dep", #bad, "tuong loi")
end

return M
