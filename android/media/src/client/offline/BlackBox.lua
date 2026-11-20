-- BlackBox.lua  (v6, bb-1.0)
-- "HOP DEN" cho loi "dang danh thi van ca game" (game thoat hang, khong de lai loi Lua nao).
--
-- Khi game bi he dieu hanh / loi native giet giua tran thi KHONG co dong loi Lua nao de doc. Module nay lam 4 viec:
--   1) Ghi nhat ky ngan "offline_blackbox.txt": moi 5 giay luc dang danh (20 giay luc ranh) 1 dong gom bo nho Lua,
--      RSS/RAM con trong cua may (doc /proc), so texture, loai tran, vong dau, lenh cuoi... + cac su kien
--      FSTART/FEND (vao/ra tran), VALVE (xa bo nho), GCSTOP/GC-RESTART, SIM+/SIM- (mo phong tran cua LocalServer), BG/FG.
--   2) Lan mo game KE TIEP: neu phien truoc khong co dau ket thuc (khong phai END / dang o nen) thi chep ~40 dong cuoi
--      cua phien truoc thanh 1 BAO CAO vao "offline_crash_reports.txt" (kem ket luan: dang danh hay khong, dinh dang
--      bo nho truoc luc thoat, file spine dang tao do). Neu game chet NGAY TRONG luc tao 1 file spine (dau moc BEGIN
--      khong co DONE) thi file do bi "cach ly" (offline_bb_quarantine.txt) => khong the lap lai vong chet.
--   3) VAN BO NHO trong tran: game dung GC suot tran (collectgarbage("stop")) trong khi tran chay engine that trong may
--      => rac cu cong don. Moi giay do bo nho Lua; tang qua valve_mb so voi moc, hoac qua tran tuyet doi, hoac RAM may
--      con it => don rac day du (+ giai phong texture khong dung khi sap het RAM) roi dung GC lai nhu cu.
--   4) Bao dam GC duoc BAT LAI sau tran (neu tran ket thuc bat thuong khong qua Fight:fightEnd thi GC dung mai).
-- Toan bo bao boc pcall: loi trong module nay KHONG BAO GIO duoc lam hong game.

BlackBox = BlackBox or {}
local B = BlackBox

B.version = "bb-1.1-tower-lifecycle"
B.enabled = true
B.file_cur   = "offline_blackbox.txt"
B.file_crash = "offline_crash_reports.txt"
B.file_sp    = "offline_bb_sp.txt"
B.file_quar  = "offline_bb_quarantine.txt"
B.proc_root  = "/proc"

B.fight_secs  = 5          -- chu ky ghi mau khi dang danh
B.idle_secs   = 20         -- chu ky ghi mau luc ranh
B.tex_every   = 3          -- thong tin texture: moi N mau
B.ring_n      = 120        -- so dong giu trong RAM de xoay vong file
B.max_cur_lines = 400      -- qua so dong nay thi viet lai file chi con ring_n dong cuoi
B.report_lines = 40        -- so dong cuoi cua phien truoc chep vao bao cao
B.report_max_bytes = 160 * 1024
B.quar_max    = 50
B.valve_mb    = 48         -- tang so voi moc => don rac day du
B.valve_abs_mb = 700       -- tuyet doi => don rac + giai phong texture
B.low_avail_mb = 450       -- RAM con trong cua may it hon => don rac + giai phong texture
B.valve_gap   = 3          -- giay toi thieu giua 2 lan xa
B.pressure_gap = 12        -- giay toi thieu giua 2 lan xa do ap luc (RAM may / tuyet doi)
B.pressure_mult_max = 8    -- xa do ap luc ma khong giai phong duoc gi (bo nho "song") => gian cach x2 moi lan, toi da x8 (96 giay)
B.valve_max   = 80         -- toi da moi tran
B.gc_restart_after = 2     -- so tick (giay) khong con tran roi moi bat lai GC
B.stop_grace  = 15         -- sau gc_stop (dau tran): cho toi da ngan nay giay de cua so tran xuat hien truoc khi bat lai GC
B.tex_purge_mb = 160       -- sau tran: neu cache texture (theo getCachedTextureInfo) lon hon muc nay => giai phong texture khong dung
B.pre_collect_mb = 10      -- gc_stop: chi don rac day du neu uoc tinh rac >= muc nay (tranh khung hinh luc vao tran)
B.toast_gap   = 30
B.host = B.host or {}

local floor = math.floor

local function g(name) return rawget(_G, name) end

local function num(v, d)
	v = tonumber(v)
	if v == nil then return d end
	return v
end

local function new_state()
	return { infight = false, fight_no = 0, fight_t = 0, base_kb = nil, maxkb = 0, last_valve = -1000, last_pressure = -1000,
		valves = 0, nofight = 0, gc_expected = false, acc = 0, samples = 0, mem = {}, tex = nil, last_toast = -1000,
		stop_n = 0, restart_n = 0, valve_total = 0, ty = nil }
end

B.st = B.st or new_state()
B.ring = B.ring or {}
B.now = B.now or 0
B.nlines = B.nlines or 0
B.sp_ring = B.sp_ring or {}

-- ------------------------------------------------------------------------------------------ tien ich
-- gia tri 1 truong: chi ASCII in duoc (khong TAB / xuong dong => khong the phat dong gia hay pha cot)
local function clean(s, n)
	s = tostring(s)
	s = string.gsub(s, "[^ -~]", "?")
	n = n or 200
	if #s > n then s = string.sub(s, 1, n) end
	return s
end

-- ca 1 dong: giu TAB (ngan cach cot), con lai chi ASCII in duoc
local function clean_line(s, n)
	s = tostring(s)
	s = string.gsub(s, "[^\t -~]", "?")
	n = n or 900
	if #s > n then s = string.sub(s, 1, n) end
	return s
end

local function clock() return os.date("%H:%M:%S") end
local function stamp() return os.date("%Y-%m-%d %H:%M:%S") end

local function count_kb()
	local ok, v = pcall(collectgarbage, "count")
	if ok then return num(v, 0) end
	return 0
end

local function mb1(kb)
	if kb == nil then return "-" end
	return string.format("%.1f", kb / 1024)
end

local function mb0(kb)
	if kb == nil then return "-" end
	return string.format("%.0f", kb / 1024)
end

local function find_window(name)
	local fw = g("fwin")
	if type(fw) ~= "table" or type(fw.find) ~= "function" then return nil end
	local ok, w = pcall(fw.find, fw, name)
	if ok then return w end
	return nil
end

-- tran dang chay: cua so dieu khien ton tai va chua ket thuc
local function fight_ctl()
	local ctl = find_window("FightRoleControllerClass")
	-- Window is a ccui.Layout userdata in the Android build, not a Lua table.
	local t = type(ctl)
	if (t == "table" or t == "userdata") and ctl.current_fight_over == false then return ctl end
	return nil
end

local function battle_type()
	local ed = g("_ED")
	if type(ed) == "table" and type(ed.battleData) == "table" then
		return ed.battleData.battle_init_type
	end
	return nil
end

local function read_file(path, maxlen)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read(maxlen or 8192)
	f:close()
	return s
end

local function kb_of(s, key)
	local v = string.match(s, key .. ":%s*(%d+)")
	if v ~= nil then return tonumber(v) end
	return nil
end

-- RSS / RAM may (KB) tu /proc. Khong doc duoc => truong nil (khong loi).
function B.read_mem()
	local m = {}
	local ok = pcall(function()
		local s = read_file(B.proc_root .. "/self/status", 8192)
		if s ~= nil then
			m.rss = kb_of(s, "VmRSS")
			m.anon = kb_of(s, "RssAnon")
			m.vsz = kb_of(s, "VmSize")
			m.swap = kb_of(s, "VmSwap")
			m.thr = tonumber(string.match(s, "Threads:%s*(%d+)"))
		end
		s = read_file(B.proc_root .. "/meminfo", 4096)
		if s ~= nil then
			m.avail = kb_of(s, "MemAvailable")
			m.total = kb_of(s, "MemTotal")
		end
	end)
	if not ok then return {} end
	return m
end

-- "N textures, for K KB" cua TextureCache (nil neu khong co API)
function B.read_tex()
	local ccm = g("cc")
	if type(ccm) ~= "table" then return nil end
	local ok, s = pcall(function()
		return ccm.Director:getInstance():getTextureCache():getCachedTextureInfo()
	end)
	if not ok or type(s) ~= "string" then return nil end
	local n, kb = string.match(s, "(%d+) textures, for (%d+) KB")
	if n == nil then return nil end
	return { n = tonumber(n), kb = tonumber(kb) }
end

-- GC dang chay? (true/false) hoac nil neu khong ho tro "isrunning" (LuaJIT cu)
local function gc_running()
	local ok, v = pcall(collectgarbage, "isrunning")
	if ok and type(v) == "boolean" then return v end
	return nil
end

-- ------------------------------------------------------------------------------------------ ghi file
local function host_call(name, ...)
	local h = B.host
	if type(h) ~= "table" or type(h[name]) ~= "function" then return nil end
	local ok, a = pcall(h[name], ...)
	if ok then return a end
	return nil
end

local function rotate()
	local ring = B.ring
	B.nlines = #ring
	if #ring > 0 then
		host_call("write", B.file_cur, table.concat(ring, "\n") .. "\n")
	end
end

local function emit(line)
	line = clean_line(line, 900)
	B.nlines = B.nlines + 1
	local ring = B.ring
	ring[#ring + 1] = line
	if #ring > B.ring_n then table.remove(ring, 1) end
	host_call("append", B.file_cur, line .. "\n")
	if B.nlines > B.max_cur_lines then rotate() end
end

local function event(tag, text)
	emit(clock() .. "\t" .. tag .. "\t" .. clean(text or "", 400))
end
B.event = function(tag, text)
	if not B.enabled or not B.started then return end
	event(clean(tag, 12), text)
end

local function toast(text)
	if B.now - (B.st.last_toast or -1000) < B.toast_gap then return end
	B.st.last_toast = B.now
	host_call("notify", text, 8)
end

-- ------------------------------------------------------------------------------------------ mau
local function round_text(ctl)
	local t = type(ctl)
	if t ~= "table" and t ~= "userdata" then return "-" end
	return tostring(ctl.current_fight_round) .. "/" .. tostring(ctl.current_fight_index)
end

local function build_sample(ctl, m, tex)
	local st = B.st
	local kb = count_kb()
	local parts = { clock(), "S" }
	local function add(k, v) parts[#parts + 1] = k .. "=" .. clean(v, 60) end
	add("f", ctl ~= nil and "1" or "0")
	add("ty", ctl ~= nil and (battle_type() or "-") or "-")
	add("rd", round_text(ctl))
	add("lua", mb1(kb))
	add("rss", mb0(m.rss))
	add("anon", mb0(m.anon))
	add("avail", mb0(m.avail))
	add("swap", mb0(m.swap))
	add("thr", m.thr or "-")
	if tex ~= nil then add("tex", tex.n .. "/" .. mb0(tex.kb)) end
	local gr = gc_running()
	add("gc", gr == nil and "?" or (gr and "run" or "stop"))
	add("err", host_call("err_count") or "-")
	local lc = host_call("last_cmd")
	if lc ~= nil then add("cmd", lc) end
	local sr = B.sp_ring
	if #sr > 0 then add("sp", sr[#sr]) end
	add("up", floor(B.now))
	return table.concat(parts, "\t"), kb
end

local function sample(ctl)
	local st = B.st
	st.samples = st.samples + 1
	local m = B.read_mem()
	st.mem = m
	local tex = nil
	local every = floor(num(B.tex_every, 3))
	if every < 1 then every = 1 end
	if (st.samples - 1) % every == 0 then
		tex = B.read_tex()
		st.tex = tex or st.tex
	end
	local line, kb = build_sample(ctl, m, tex)
	if kb > st.maxkb then st.maxkb = kb end
	emit(line)
	return m
end

-- ------------------------------------------------------------------------------------------ xa bo nho
-- Giai phong texture KHONG ai dung (refcount = 1, chi cache giu): giong cacher.removeAllTextures() cua game.
-- TUYET DOI khong goi SpriteFrameCache:removeUnusedSpriteFrames(): ArmatureDataManager (Cocostudio) giu TEN frame, xoa frame
-- ma no van nho thi lan tao armature sau se tro vao frame rong.
local function purge_textures()
	local ccm = g("cc")
	if type(ccm) ~= "table" then return false end
	local ok = pcall(function() ccm.Director:getInstance():getTextureCache():removeUnusedTextures() end)
	return ok
end

local function tex_text(tex)
	if tex == nil then return "-" end
	return tex.n .. "/" .. mb0(tex.kb)
end

-- sau tran (hoac khi can): neu cache texture lon => giai phong texture khong dung va ghi PURGE
local function maybe_purge(why, force)
	-- A finished controller can still own live Spine nodes on the result screen.
	-- Never run the AFTER-fight purge during loading, battle or result teardown.
	if why == "after-fight" and (find_window("FightClass") ~= nil
		or find_window("FightSceneClass") ~= nil or find_window("FightMapClass") ~= nil
		or find_window("FightRoleControllerClass") ~= nil
		or find_window("BattleStartEffectClass") ~= nil) then return false end
	local tex = B.read_tex()
	local st = B.st
	if tex ~= nil then st.tex = tex end
	if not force then
		if tex == nil or tex.kb < B.tex_purge_mb * 1024 then return false end
	end
	local c0 = os.clock()
	local ok = purge_textures()
	local after = B.read_tex()
	if after ~= nil then st.tex = after end
	st.purges = (st.purges or 0) + 1
	event("PURGE", string.format("why=%s ok=%s tex=%s -> %s ms=%.0f n=%d", why, ok and "1" or "0", tex_text(tex), tex_text(after),
		(os.clock() - c0) * 1000, st.purges))
	return true
end

-- don rac day du. Neu dang trong tran thi dung GC lai (collect lam GC chay tiep).
local function collect_now(why, purge, infight)
	local st = B.st
	local before = count_kb()
	local c0 = os.clock()
	pcall(collectgarbage, "collect")
	local after = count_kb()
	local ms = (os.clock() - c0) * 1000
	local purged = false
	if purge then purged = purge_textures() end
	if infight then pcall(collectgarbage, "stop") end
	st.base_kb = after
	st.last_valve = B.now
	st.valves = st.valves + 1
	st.valve_total = st.valve_total + 1
	event("VALVE", string.format("why=%s before=%sMB after=%sMB ms=%.0f purge=%s n=%d gapx=%d", why, mb1(before), mb1(after), ms,
		purged and "1" or "0", st.valves, st.pressure_mult or 1))
	return before, after
end

-- xa do ap luc (RAM may it / tran tuyet doi): neu lan don rac khong giai phong duoc gi (bo nho dang "song", khong phai rac)
-- thi don them cung vo ich va gay khung hinh => gian cach cac lan sau ra x2 moi lan (toi da pressure_mult_max).
local function pressure_collect(why)
	local st = B.st
	local before, after = collect_now(why, true, true)
	if before - after < math.max(4 * 1024, before * 0.05) then
		st.pressure_mult = math.min((st.pressure_mult or 1) * 2, num(B.pressure_mult_max, 8))
	else
		st.pressure_mult = 1
	end
end

local function valve_check(m)
	local st = B.st
	if st.valves >= B.valve_max then return end
	local gap = B.now - st.last_valve
	if gap < B.valve_gap then return end
	local kb = count_kb()
	if kb > st.maxkb then st.maxkb = kb end
	local base = st.base_kb
	if base == nil then st.base_kb = kb; return end
	if kb - base >= B.valve_mb * 1024 then
		collect_now("growth", false, true)
		return
	end
	if B.now - st.last_pressure < B.pressure_gap * (st.pressure_mult or 1) then return end
	if kb >= B.valve_abs_mb * 1024 then
		st.last_pressure = B.now
		pressure_collect("abs")
		return
	end
	local avail = m and m.avail
	if avail ~= nil and avail < B.low_avail_mb * 1024 then
		st.last_pressure = B.now
		pressure_collect("lowmem")
	end
end

-- "san" bo nho Lua (heap song uoc tinh): muc thap nhat gan day; tang cham neu heap song to ra
local function track_floor(kb)
	local st = B.st
	if st.floor_kb == nil or kb < st.floor_kb then
		st.floor_kb = kb
	else
		st.floor_kb = st.floor_kb + (kb - st.floor_kb) * 0.002
	end
end

-- Goi tu FightLoading (thay cho collectgarbage("stop") cua game): don rac day du neu co nhieu rac, roi dung GC suot tran.
-- (Bo qua don rac khi rac uoc tinh < pre_collect_mb: GC cua game chay gan nhu lien tuc nen thuong da sach, tranh khung hinh.)
function B.gc_stop()
	local st = B.st
	local before = count_kb()
	local est = before - (st.floor_kb or 0)
	local c0 = os.clock()
	local did = false
	if st.floor_kb == nil or est >= B.pre_collect_mb * 1024 then
		pcall(collectgarbage, "collect")
		did = true
	end
	local after = count_kb()
	local ms = (os.clock() - c0) * 1000
	pcall(collectgarbage, "stop")
	st.gc_expected = true
	st.gc_stop_t = B.now
	st.fight_since_stop = false
	st.nofight = 0
	st.base_kb = after
	st.last_valve = B.now
	st.stop_n = st.stop_n + 1
	if did then track_floor(after) end
	if B.enabled and B.started then
		event("GCSTOP", string.format("before=%sMB after=%sMB collect=%s ms=%.0f n=%d", mb1(before), mb1(after), did and "1" or "0", ms,
			st.stop_n))
	end
	return true
end

-- ------------------------------------------------------------------------------------------ vao / ra tran
local function on_fight_start(ctl)
	local st = B.st
	st.infight = true
	-- [FPS UNLOCK] vao tran: ha FPS ve app.fightFPS (GC bi dung trong tran, rac ty le voi so khung hinh)
	pcall(function()
		local a = rawget(_G, "app")
		if type(a) == "table" and a.enterFightFPS ~= nil then a.enterFightFPS() end
	end)
	st.fight_no = st.fight_no + 1
	st.fight_t = B.now
	st.valves = 0
	st.pressure_mult = 1
	st.maxkb = count_kb()
	st.nofight = 0
	-- game dung GC o moi tran (FightLoading); sau tran ta bat lai neu no con dung
	if st.base_kb == nil or not st.gc_expected then st.base_kb = st.maxkb end
	st.gc_expected = true
	st.fight_since_stop = true
	local m = B.read_mem()
	st.mem = m
	local tex = B.read_tex()
	st.tex = tex or st.tex
	st.ty = battle_type()
	event("FSTART", string.format("no=%d ty=%s lua=%sMB rss=%sMB avail=%sMB tex=%s gc=%s", st.fight_no, clean(st.ty or "-", 12),
		mb1(st.maxkb), mb0(m.rss), mb0(m.avail), tex and (tex.n .. "/" .. mb0(tex.kb)) or "-",
		tostring(gc_running())))
	st.acc = 0
end

local function on_fight_end()
	local st = B.st
	st.infight = false
	-- [FPS UNLOCK] ra tran: tra FPS ve muc muc tieu
	pcall(function()
		local a = rawget(_G, "app")
		if type(a) == "table" and a.leaveFightFPS ~= nil then a.leaveFightFPS() end
	end)
	st.nofight = 0
	local m = B.read_mem()
	st.mem = m
	local tex = B.read_tex()
	st.tex = tex or st.tex
	event("FEND", string.format("no=%d dur=%.0fs lua=%sMB max=%sMB rss=%sMB avail=%sMB tex=%s valves=%d", st.fight_no,
		B.now - st.fight_t, mb1(count_kb()), mb1(st.maxkb), mb0(m.rss), mb0(m.avail),
		tex and (tex.n .. "/" .. mb0(tex.kb)) or "-", st.valves))
end

local function gc_restart_guard()
	local st = B.st
	if not st.gc_expected then return end
	-- vua dung GC o dau tran nhung cua so tran chua xuat hien: cho them (man loading co the lau)
	if not st.fight_since_stop and B.now - (st.gc_stop_t or -1000) < B.stop_grace then
		st.nofight = 0
		return
	end
	st.nofight = st.nofight + 1
	if st.nofight < B.gc_restart_after then return end
	pcall(collectgarbage, "restart")
	-- [FPS UNLOCK] tran ket thuc bat thuong (khong qua on_fight_end) van phai tra lai FPS
	pcall(function()
		local a = rawget(_G, "app")
		if type(a) == "table" and a.leaveFightFPS ~= nil then a.leaveFightFPS() end
	end)
	st.gc_expected = false
	st.restart_n = st.restart_n + 1
	st.base_kb = nil
	event("GC-RESTART", string.format("lua=%sMB gc=%s n=%d", mb1(count_kb()), tostring(gc_running()), st.restart_n))
	-- sau tran: neu cache texture da phinh to thi giai phong texture khong con ai dung (hero ngau nhien moi tran = texture moi)
	pcall(maybe_purge, "after-fight", false)
end

-- ------------------------------------------------------------------------------------------ vong lap
function B.tick(dt)
	if not B.enabled then return end
	dt = num(dt, 1)
	if dt < 0 then dt = 0 end
	if dt > 5 then dt = 5 end
	B.now = B.now + dt
	local st = B.st
	local ctl = fight_ctl()
	if ctl == nil then track_floor(count_kb()) end
	if ctl ~= nil and not st.infight then
		on_fight_start(ctl)
	elseif ctl == nil and st.infight then
		on_fight_end()
	end
	if ctl ~= nil then
		valve_check(st.mem)
	else
		gc_restart_guard()
	end
	st.acc = st.acc + dt
	local period = (ctl ~= nil) and B.fight_secs or B.idle_secs
	if st.acc >= period then
		st.acc = 0
		sample(ctl)
	end
end

-- ------------------------------------------------------------------------------------------ dau moc spine
function B.sp_begin(json, atlas)
	if not B.enabled then return end
	local key = clean(json, 120) .. "|" .. clean(atlas, 120)
	B.sp_cur = key
	local sr = B.sp_ring
	local short = string.match(clean(json, 120), "([^/\\]+)$") or clean(json, 40)
	sr[#sr + 1] = short
	if #sr > 8 then table.remove(sr, 1) end
	host_call("write", B.file_sp, "BEGIN\t" .. stamp() .. "\t" .. clean(json, 160) .. "\t" .. clean(atlas, 160) .. "\n")
end

function B.sp_done(json, atlas, ok)
	if not B.enabled then return end
	B.sp_cur = nil
	host_call("write", B.file_sp, "DONE\t" .. stamp() .. "\t" .. clean(json, 160) .. "\t" .. clean(atlas, 160) .. "\t"
		.. (ok and "ok" or "fail") .. "\n")
end

-- dua 1 cap json|atlas vao danh sach cam cua display.lua (sp.zz_bad) de khong bao gio goi ham native lai
local function ban_spine(json, atlas)
	local spt = g("sp")
	if type(spt) ~= "table" then return false end
	if type(spt.zz_bad) ~= "table" then spt.zz_bad = {} end
	spt.zz_bad[tostring(json) .. "|" .. tostring(atlas)] = true
	return true
end

local function load_quarantine()
	local s = host_call("read", B.file_quar)
	if type(s) ~= "string" or s == "" then return 0 end
	local n = 0
	for ln in string.gmatch(s, "[^\r\n]+") do
		local j, a = string.match(ln, "^(.-)|(.*)$")
		if j ~= nil and j ~= "" then
			if ban_spine(j, a) then n = n + 1 end
			if n >= B.quar_max then break end
		end
	end
	B.quar_loaded = n
	return n
end

-- ------------------------------------------------------------------------------------------ phan tich phien truoc
local function split_lines(s)
	local t = {}
	for ln in string.gmatch(s, "[^\r\n]+") do t[#t + 1] = ln end
	return t
end

local function tag_of(line)
	return string.match(line, "^[^\t]*\t([^\t]*)")
end

local function field_of(line, key)
	return string.match(line, "\t" .. key .. "=([^\t]*)")
end

-- so dau tien cua truong (bo hau to "MB", chi lay phan so: "12.3MB" -> 12.3)
local function numfield(line, key)
	local v = field_of(line, key)
	if v == nil then return nil end
	return tonumber(string.match(v, "^%-?[%d%.]+"))
end

-- ket luan ve phien truoc: { verdict = "clean"|"bg"|"abnormal", infight = bool, ... }
function B.classify(lines)
	local r = { verdict = "none", infight = false, last = nil, boot = nil, samples = 0 }
	if #lines == 0 then return r end
	r.last = lines[#lines]
	local lt = tag_of(r.last)
	if lt == "END" then r.verdict = "clean"
	elseif lt == "BG" then r.verdict = "bg"
	else r.verdict = "abnormal" end
	local decided = false
	local peak_lua, peak_rss, min_av = 0, 0, nil
	for i = #lines, 1, -1 do
		local t = tag_of(lines[i])
		if not decided then
			if t == "FSTART" then r.infight = true; decided = true
			elseif t == "FEND" then r.infight = false; decided = true
			elseif t == "S" then r.infight = (field_of(lines[i], "f") == "1"); decided = true end
		end
		if t == "S" or t == "FSTART" or t == "FEND" or t == "VALVE" or t == "GCSTOP" then
			r.samples = r.samples + 1
			local lu = numfield(lines[i], "lua")
			local rs = numfield(lines[i], "rss")
			local av = numfield(lines[i], "avail")
			if lu ~= nil and lu > peak_lua then peak_lua = lu end
			if rs ~= nil and rs > peak_rss then peak_rss = rs end
			if av ~= nil and (min_av == nil or av < min_av) then min_av = av end
		end
		if t == "BOOT" and r.boot == nil then r.boot = lines[i] end
	end
	r.peak_lua, r.peak_rss, r.min_avail = peak_lua, peak_rss, min_av
	return r
end

local function trim_reports()
	local s = host_call("read", B.file_crash)
	if type(s) ~= "string" or #s <= B.report_max_bytes then return end
	local cut = #s - floor(B.report_max_bytes / 2)
	local p = string.find(s, "\n=== ", cut, true)
	local keep
	if p ~= nil then keep = string.sub(s, p + 1) else keep = string.sub(s, cut) end
	host_call("write", B.file_crash, keep)
end

local function report_text(prev_lines, info, spmark, banned)
	local out = {}
	local function w(s) out[#out + 1] = s end
	local head
	if info.verdict == "abnormal" then
		head = info.infight and "PHIEN TRUOC THOAT DOT NGOT LUC DANG DANH" or "PHIEN TRUOC THOAT DOT NGOT (khong o trong tran)"
	elseif info.verdict == "bg" then
		head = "PHIEN TRUOC KET THUC KHI DANG O NEN" .. (info.infight and " (luc do dang trong tran)" or "")
	else
		head = "PHIEN TRUOC"
	end
	w("=== " .. stamp() .. " :: " .. head .. " ===")
	if info.boot ~= nil then w("boot truoc : " .. clean_line(info.boot, 500)) end
	w("dong cuoi  : " .. clean_line(info.last or "-", 400))
	w(string.format("dinh        : lua=%.0fMB rss=%.0fMB RAM-con-thap-nhat=%sMB", info.peak_lua or 0, info.peak_rss or 0,
		info.min_avail ~= nil and string.format("%.0f", info.min_avail) or "-"))
	if spmark ~= nil and spmark ~= "" then w("spine cuoi : " .. clean_line((string.gsub(spmark, "[\r\n]+$", "")), 500)) end
	if banned ~= nil then w("CACH LY    : " .. clean(banned, 300) .. "  (dung hieu ung gia tu nay)") end
	w("-- " .. tostring(math.min(#prev_lines, B.report_lines)) .. " dong cuoi cua phien truoc --")
	local from = #prev_lines - B.report_lines + 1
	if from < 1 then from = 1 end
	for i = from, #prev_lines do w(clean_line(prev_lines[i], 500)) end
	w("")
	return table.concat(out, "\n") .. "\n"
end

-- Doc nhat ky + dau moc spine cua phien truoc, ghi bao cao neu can. Tra ve info.
function B.analyze(prev, spmark)
	if type(prev) ~= "string" or prev == "" then return nil end
	local lines = split_lines(prev)
	local info = B.classify(lines)
	if info.verdict == "clean" or info.verdict == "none" then return info end
	local banned = nil
	if type(spmark) == "string" and string.sub(spmark, 1, 6) == "BEGIN\t" and info.verdict == "abnormal" then
		local _, json, atlas = string.match(spmark, "^BEGIN\t([^\t]*)\t([^\t]*)\t([^\t\r\n]*)")
		if json ~= nil and json ~= "" then
			local n = B.quar_loaded or 0
			if n < B.quar_max then
				host_call("append", B.file_quar, json .. "|" .. (atlas or "") .. "\n")
				ban_spine(json, atlas or "")
				B.quar_loaded = n + 1
				banned = json .. "|" .. (atlas or "")
				local mockup = g("OfflineMock")
				if type(mockup) == "table" and type(mockup.noteBadSpine) == "function" then
					pcall(mockup.noteBadSpine, json, atlas or "", "game chet luc dang tao (BEGIN khong co DONE)")
				end
			end
		end
	end
	if info.verdict == "abnormal" or info.infight then
		trim_reports()
		host_call("append", B.file_crash, report_text(lines, info, spmark, banned))
	else
		host_call("append", B.file_crash, "=== " .. stamp() .. " :: phien truoc ket thuc khi dang o nen (khong trong tran), khong co gi bat thuong ===\n")
	end
	B.prev = info
	return info
end

-- ------------------------------------------------------------------------------------------ khoi dong
local function fingerprint()
	local fp = host_call("fingerprint")
	if type(fp) ~= "string" then fp = "" end
	return clean_line(fp, 400)
end

function B.start()
	if B.started then return B.prev end
	B.started = true
	if not B.enabled then return nil end
	pcall(load_quarantine)
	local prev = host_call("read", B.file_cur)
	local spmark = host_call("read", B.file_sp)
	local already = g("ZZ_BB_BOOTED")
	local info = nil
	if already == nil then
		local ok, r = pcall(B.analyze, prev, spmark)
		if ok then info = r end
		rawset(_G, "ZZ_BB_BOOTED", os.time())
		-- dau moc spine cua phien truoc da duoc xu ly: xoa de lan sau khong xu ly lai
		host_call("write", B.file_sp, "")
	end
	-- phien moi: file moi (ghi de) co dong BOOT
	B.ring = {}
	B.nlines = 0
	host_call("write", B.file_cur, "")
	local m = B.read_mem()
	B.st.mem = m
	B.st.base_kb = nil
	local tex = B.read_tex()
	B.st.tex = tex
	emit(stamp() .. "\tBOOT\tbb=" .. B.version .. "\t" .. fingerprint() .. "\tlua=" .. mb1(count_kb()) .. "MB\trss=" .. mb0(m.rss)
		.. "MB\tavail=" .. mb0(m.avail) .. "MB\ttotal=" .. mb0(m.total) .. "MB\ttex=" .. (tex and (tex.n .. "/" .. mb0(tex.kb)) or "-")
		.. "\treload=" .. (already ~= nil and "1" or "0") .. "\tquar=" .. tostring(B.quar_loaded or 0)
		.. "\tgc=" .. tostring(gc_running()))
	if info ~= nil and info.verdict == "abnormal" and info.infight then
		toast("Lần trước game thoát đột ngột lúc đang đánh. Đã ghi lại vào offline_crash_reports.txt")
	end
	return info
end

function B.on_bg()
	if not B.enabled or not B.started then return end
	emit(stamp() .. "\tBG\tlua=" .. mb1(count_kb()) .. "MB\tf=" .. (B.st.infight and "1" or "0"))
end

function B.on_fg()
	if not B.enabled or not B.started then return end
	emit(stamp() .. "\tFG\tlua=" .. mb1(count_kb()) .. "MB")
end

function B.mark_end(why)
	if not B.enabled or not B.started then return end
	emit(stamp() .. "\tEND\t" .. clean(why or "exit", 60))
end

function B.summary()
	local st = B.st
	local pv = B.prev and B.prev.verdict or "-"
	return string.format("BB %s samples=%d fights=%d valves=%d gcstop=%d gcrestart=%d lines=%d prev=%s quar=%s", B.version,
		st.samples, st.fight_no, st.valve_total, st.stop_n, st.restart_n, B.nlines, pv, tostring(B.quar_loaded or 0))
end

-- cho test
B._classify = B.classify
B._fight_ctl = fight_ctl
B._emit = emit
B._rotate = rotate
B._collect_now = collect_now
B._valve_check = valve_check
B._load_quarantine = load_quarantine

return B
