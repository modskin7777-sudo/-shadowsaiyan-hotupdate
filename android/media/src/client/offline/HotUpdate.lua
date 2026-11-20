-- =====================================================================================================
-- HotUpdate v1.0 - CAP NHAT NONG (hot update) QUA GITHUB
--
--   Repo : https://github.com/modskin7777-sudo/-shadowsaiyan-hotupdate
--   Trong repo, file mod nam o   android/media/<duong dan>   (vd: android/media/src/client/offline/LocalServer.lua)
--   Tren may, file duoc ghi vao  /storage/emulated/<uid>/Android/media/<goi>/<duong dan>
--   (day la thu muc mod co uu tien cao nhat - xem main.lua / frameworks/app.lua "MEDIA HOTFIX").
--
--   Luong chay:
--     1. Tai  hotupdate_manifest.txt  tu  raw.githubusercontent.com  (thu nhanh main roi master).
--     2. So phien ban voi hotupdate_state.txt (lan cap nhat truoc). Bang nhau => xong.
--     3. So tung file (kich thuoc + CRC32): thieu / khac => tai ve, kiem tra, ghi nguyen tu (.tmp -> rename).
--     4. Chi sau khi TAT CA file thanh cong moi ghi phien ban moi (loi mang => lan mo game sau thu lai).
--     5. File Lua moi co hieu luc o LAN MO GAME SAU (thoat han game roi mo lai).
--
--   An toan:
--     * chi HTTPS; chi ghi vao src/ va res/ ; chan "..", "\", duong dan tuyet doi; khong dong toi thu muc seed/*.txt
--     * khong bao gio ghi file hong: kiem tra kich thuoc + CRC32 truoc khi ghi
--     * toan bo la pcall: loi o day KHONG lam sap game
--     * Tat: tao file  hotupdate_off.txt  (trong Android/media/<goi>/) hoac UserDefault "hotupdate_enabled" = "0"
--     * Nhat ky: Android/media/<goi>/hotupdate_log.txt
--
--   Lenh tay (vd tu nut GM): HotUpdate.check(true)  -- ep kiem tra lai tat ca file, bo qua so sanh phien ban
-- =====================================================================================================
HotUpdate = HotUpdate or {}
local M = HotUpdate

M.version        = "1.0"
M.user           = "modskin7777-sudo"
M.repo           = "-shadowsaiyan-hotupdate"
M.branches       = { "main", "master" }          -- thu lan luot
M.manifest       = "hotupdate_manifest.txt"      -- nam o goc repo
M.repo_media_dir = "android/media/"              -- thu muc trong repo chua file mod
M.delay_secs     = 8                             -- doi sau khi mo game roi moi kiem tra (tranh tai luc vao game)
M.max_parallel   = 3                             -- so file tai dong thoi
M.timeout_secs   = 40                            -- timeout moi yeu cau
M.max_retry      = 3                             -- so lan thu lai moi file
M.max_file_bytes = 24 * 1024 * 1024
M.allow_prefix   = { "src/", "res/" }
M.crc_exts       = { lua = true, json = true, atlas = true, txt = true, csb = true } -- lan dau: chi so CRC cac loai nay (png/mp3 chi so kich thuoc)
M.crc_first_max  = 2 * 1024 * 1024               -- file lon hon nguong nay (lan dau) chi so kich thuoc
M.state_file     = "hotupdate_state.txt"
M.log_file       = "hotupdate_log.txt"
M.off_file       = "hotupdate_off.txt"
M.ud_key         = "hotupdate_enabled"

-- ----------------------------------------------------------------------------------------- tien ich
local bit = rawget(_G, "bit") or rawget(_G, "bit32")
local fu_get = function() return cc.FileUtils:getInstance() end

local function sched()
	return cc.Director:getInstance():getScheduler()
end

-- chay fn sau secs giay (1 lan)
local function after(secs, fn)
	local id
	id = sched():scheduleScriptFunc(function()
		if id ~= nil then pcall(function() sched():unscheduleScriptEntry(id) end) end
		pcall(fn)
	end, secs, false)
	return id
end

-- chay fn moi `interval` giay cho toi khi fn tra ve true
local function every(interval, fn)
	local id
	id = sched():scheduleScriptFunc(function()
		local ok, finished = pcall(fn)
		if (not ok) or finished == true then
			pcall(function() sched():unscheduleScriptEntry(id) end)
		end
	end, interval, false)
	return id
end

local function writable_dir()
	local ok, p = pcall(function() return fu_get():getWritablePath() end)
	if ok and type(p) == "string" and p ~= "" then
		if string.sub(p, -1) ~= "/" then p = p .. "/" end
		return p
	end
	return ""
end

-- thu muc Android/media/<goi>/ (co dau / o cuoi) hoac nil
local function media_dir()
	if M._media_dir_done then return M._media_dir end
	M._media_dir_done = true
	local w = writable_dir()
	local uid, pkg = string.match(w, "^/data/user/(%d+)/([^/]+)/")
	if pkg == nil then
		pkg = string.match(w, "^/data/data/([^/]+)/")
		if pkg ~= nil then uid = "0" end
	end
	if pkg == nil then return nil end
	M._pkg = pkg
	M._media_dir = "/storage/emulated/" .. uid .. "/Android/media/" .. pkg .. "/"
	pcall(function() fu_get():createDirectory(M._media_dir) end)
	return M._media_dir
end

local function file_size(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local n = f:seek("end")
	f:close()
	return n
end

local function read_all(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	local line = table.concat(parts, " ")
	print("[HotUpdate] " .. line)
	local dir = media_dir()
	if dir == nil then return end
	pcall(function()
		local path = dir .. M.log_file
		local sz = file_size(path)
		local mode = "ab"
		if sz ~= nil and sz > 60000 then
			local old = read_all(path) or ""
			local f0 = io.open(path, "wb")
			if f0 then f0:write(string.sub(old, -30000)); f0:close() end
		end
		local f = io.open(path, mode)
		if f then f:write(os.date("%Y-%m-%d %H:%M:%S ") .. line .. "\n"); f:close() end
	end)
end

local function notify(text, secs)
	pcall(function()
		if OfflineMock ~= nil and OfflineMock.notify ~= nil then OfflineMock.notify(text, secs or 12) end
	end)
end

local made_dirs = {}
local function ensure_dir_for(fullpath)
	local dir = string.match(fullpath, "^(.*)/[^/]*$")
	if dir == nil or made_dirs[dir] then return end
	made_dirs[dir] = true
	pcall(function() fu_get():createDirectory(dir .. "/") end)
end

-- ghi nguyen tu: .tmp -> kiem tra kich thuoc -> rename
local function write_file(dest, data)
	ensure_dir_for(dest)
	local tmp = dest .. ".tmp"
	local f = io.open(tmp, "wb")
	if not f then return false, "khong mo duoc " .. tmp end
	local okw = f:write(data)
	f:close()
	if not okw then os.remove(tmp); return false, "ghi that bai" end
	if file_size(tmp) ~= #data then os.remove(tmp); return false, "kich thuoc sau khi ghi sai" end
	local okr = os.rename(tmp, dest)
	if not okr then
		os.remove(dest)
		okr = os.rename(tmp, dest)
	end
	if not okr then
		-- du phong: ghi truc tiep
		os.remove(tmp)
		local f2 = io.open(dest, "wb")
		if not f2 then return false, "khong ghi duoc " .. dest end
		f2:write(data)
		f2:close()
		if file_size(dest) ~= #data then return false, "ghi truc tiep sai kich thuoc" end
	end
	return true
end

-- ----------------------------------------------------------------------------------------- CRC32
local crc_tab
local function crc_ready()
	if bit == nil then return false end
	if crc_tab ~= nil then return true end
	crc_tab = {}
	for i = 0, 255 do
		local c = i
		for _ = 1, 8 do
			if bit.band(c, 1) == 1 then
				c = bit.bxor(bit.rshift(c, 1), 0xEDB88320)
			else
				c = bit.rshift(c, 1)
			end
		end
		crc_tab[i] = c
	end
	return true
end

local function crc_update(crc, s)
	local band, bxor, rshift, byte, tab = bit.band, bit.bxor, bit.rshift, string.byte, crc_tab
	for i = 1, #s do
		crc = bxor(tab[band(bxor(crc, byte(s, i)), 255)], rshift(crc, 8))
	end
	return crc
end

local function crc_hex(crc)
	crc = bit.bxor(crc, -1)
	if bit.tohex ~= nil then return bit.tohex(crc, 8) end
	return string.format("%08x", crc % 4294967296)
end

-- CRC32 chia nho theo tung khung hinh. getChunk() tra ve chuoi tiep theo hoac nil khi het. cb(hexcrc)
local CHUNK = 49152
local function crc_async(getChunk, cb)
	if not crc_ready() then cb(nil); return end
	local crc = -1
	every(0, function()
		local s = getChunk()
		if s == nil then
			cb(crc_hex(crc))
			return true
		end
		crc = crc_update(crc, s)
		return false
	end)
end

local function crc_of_string(data, cb)
	local pos = 1
	crc_async(function()
		if pos > #data then return nil end
		local s = string.sub(data, pos, pos + CHUNK - 1)
		pos = pos + CHUNK
		return s
	end, cb)
end

local function crc_of_file(path, cb)
	local f = io.open(path, "rb")
	if not f then cb(nil); return end
	crc_async(function()
		if f == nil then return nil end
		local s = f:read(CHUNK)
		if s == nil or s == "" then f:close(); f = nil; return nil end
		return s
	end, cb)
end

-- ----------------------------------------------------------------------------------------- HTTP
local function http_get(url, use_string, cb)
	local finished = false
	local xhr
	local okc = pcall(function() xhr = cc.XMLHttpRequest:new() end)
	if not okc or xhr == nil then cb(false, nil, -2); return end

	local function done(ok, body, status)
		if finished then return end
		finished = true
		pcall(function() xhr:unregisterScriptHandler() end)
		cb(ok, body, status)
	end

	local okv = pcall(function()
		if (not use_string) and cc.XMLHTTPREQUEST_RESPONSE_ARRAY_BUFFER ~= nil then
			xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_ARRAY_BUFFER
		else
			xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_STRING
		end
		pcall(function() xhr.timeout = M.timeout_secs end)
		xhr:open("GET", url)
		xhr:registerScriptHandler(function()
			if xhr.readyState == 4 then
				if xhr.status == 200 then
					done(true, xhr.response, 200)
				else
					done(false, nil, xhr.status)
				end
			end
		end)
		xhr:send()
	end)
	if not okv then done(false, nil, -3); return end

	-- chong treo: neu qua han ma chua co phan hoi thi bo
	after(M.timeout_secs + 5, function()
		if not finished then
			pcall(function() xhr:abort() end)
			done(false, nil, -1)
		end
	end)
end

local function url_escape(path)
	return (string.gsub(path, "[^%w%-%._~/]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

local function raw_url(branch, rel)
	return "https://raw.githubusercontent.com/" .. M.user .. "/" .. M.repo .. "/" .. branch .. "/" .. url_escape(rel)
end

-- ----------------------------------------------------------------------------------------- kiem tra duong dan
local function path_ok(p)
	if type(p) ~= "string" or p == "" or #p > 240 then return false end
	if string.sub(p, 1, 1) == "/" then return false end
	if string.find(p, "..", 1, true) or string.find(p, "\\", 1, true) or string.find(p, "//", 1, true) then return false end
	if string.find(p, "[%c:*?\"<>|]") then return false end
	-- khong dong toi file trang thai/nhat ky do game tu sinh ra
	if string.find(p, "^src/client/offline/seed/.*%.txt$") then return false end
	if string.find(p, "%.tmp$") then return false end
	for _, pre in ipairs(M.allow_prefix) do
		if string.sub(p, 1, #pre) == pre then return true end
	end
	return false
end

-- ----------------------------------------------------------------------------------------- manifest / state
-- Dinh dang:  V <phien ban>
--             F <kich thuoc> <crc32 hex> <duong dan tuong doi, co the co dau cach>
--             D <duong dan>          (xoa file khoi may)
local function parse_manifest(text)
	local ver, files, dels = nil, {}, {}
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		line = string.gsub(line, "\r$", "")
		local v = string.match(line, "^V%s+(%S+)")
		if v ~= nil then
			ver = v
		else
			local sz, crc, p = string.match(line, "^F%s+(%d+)%s+(%x+)%s+(.+)$")
			if sz ~= nil then
				sz = tonumber(sz)
				if path_ok(p) and sz <= M.max_file_bytes then
					files[#files + 1] = { path = p, size = sz, crc = string.lower(crc) }
				else
					log("bo qua (duong dan/kich thuoc khong hop le):", p)
				end
			else
				local dp = string.match(line, "^D%s+(.+)$")
				if dp ~= nil and path_ok(dp) then dels[#dels + 1] = dp end
			end
		end
	end
	return ver, files, dels
end

local function load_state(dir)
	local st = { version = nil, applied = {} }
	local text = read_all(dir .. M.state_file)
	if text == nil then return st end
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		line = string.gsub(line, "\r$", "")
		local v = string.match(line, "^V%s+(%S+)")
		if v ~= nil then
			st.version = v
		else
			local crc, p = string.match(line, "^A%s+(%x+)%s+(.+)$")
			if crc ~= nil then st.applied[p] = string.lower(crc) end
		end
	end
	return st
end

local function save_state(dir, st)
	local lines = { "V " .. tostring(st.version or "0") }
	local keys = {}
	for p in pairs(st.applied) do keys[#keys + 1] = p end
	table.sort(keys)
	for _, p in ipairs(keys) do lines[#lines + 1] = "A " .. st.applied[p] .. " " .. p end
	local ok, err = write_file(dir .. M.state_file, table.concat(lines, "\n") .. "\n")
	if not ok then log("khong luu duoc state:", tostring(err)) end
end

-- ----------------------------------------------------------------------------------------- bat / tat
function M.enabled()
	local ok, v = pcall(function() return cc.UserDefault:getInstance():getStringForKey(M.ud_key, "") end)
	if ok and v == "0" then return false end
	local dir = media_dir()
	if dir ~= nil and file_size(dir .. M.off_file) ~= nil then return false end
	return true
end

function M.setEnabled(on)
	pcall(function()
		local ud = cc.UserDefault:getInstance()
		ud:setStringForKey(M.ud_key, on and "1" or "0")
		if ud.flush ~= nil then ud:flush() end
	end)
end

-- ----------------------------------------------------------------------------------------- kiem tra & tai
local function fetch_manifest(branch_idx, cb)
	local branch = M.branches[branch_idx]
	if branch == nil then cb(nil, nil, "khong lay duoc manifest (kiem tra mang / ten repo / nhanh)"); return end
	local url = raw_url(branch, M.manifest) .. "?t=" .. tostring(os.time())
	http_get(url, true, function(ok, body, status)
		if ok and type(body) == "string" and string.find(body, "^%s*V%s") then
			cb(branch, body, nil)
		else
			log("manifest nhanh '" .. branch .. "' that bai, http=" .. tostring(status))
			fetch_manifest(branch_idx + 1, cb)
		end
	end)
end

-- Giai doan A: tim file can tai. done(todo)
local function stage_scan(dir, files, st, force, done)
	local todo, i = {}, 0
	local crc_ok = crc_ready()

	local function next_file()
		i = i + 1
		local f = files[i]
		if f == nil then done(todo); return end
		local dest = dir .. f.path
		local sz = file_size(dest)
		if sz == nil or sz ~= f.size then
			todo[#todo + 1] = f
			return next_file()
		end
		if (not force) and st.applied[f.path] == f.crc then
			return next_file()
		end
		-- cung kich thuoc nhung chua biet noi dung: lan dau / ep kiem tra
		local ext = string.lower(string.match(f.path, "%.([%w_]+)$") or "")
		if crc_ok and (force or (M.crc_exts[ext] and f.size <= M.crc_first_max)) then
			crc_of_file(dest, function(hex)
				if hex == f.crc then
					st.applied[f.path] = f.crc
				else
					todo[#todo + 1] = f
				end
				after(0, next_file)
			end)
		else
			-- chap nhan (cung kich thuoc) va ghi nho
			st.applied[f.path] = f.crc
			return next_file()
		end
	end
	next_file()
end

-- Giai doan B: tai song song. done(n_ok, n_fail)
local function stage_download(dir, branch, todo, st, done)
	local idx, inflight, n_ok, n_fail = 0, 0, 0, 0
	local total = #todo
	local completed = false
	if total == 0 then done(0, 0); return end

	local function complete()
		if completed then return end
		completed = true
		done(n_ok, n_fail)
	end

	local function finish_one()
		inflight = inflight - 1
		if idx >= total and inflight == 0 then
			complete()
		else
			after(0, M._pump)
		end
	end

	local function try_file(f, attempt)
		local url = raw_url(branch, M.repo_media_dir .. f.path)
		http_get(url, (attempt % 2) == 0, function(ok, body, status)
			if not ok or type(body) ~= "string" then
				if attempt < M.max_retry then
					return after(1.5, function() try_file(f, attempt + 1) end)
				end
				log("TAI LOI", f.path, "http=" .. tostring(status))
				n_fail = n_fail + 1
				return finish_one()
			end
			if #body ~= f.size then
				if attempt < M.max_retry then
					log("sai kich thuoc", f.path, #body, "~=", f.size, "-> thu lai (che do khac)")
					return after(0.5, function() try_file(f, attempt + 1) end)
				end
				log("SAI KICH THUOC", f.path, #body, "~=", f.size)
				n_fail = n_fail + 1
				return finish_one()
			end
			local function commit(hex)
				if hex ~= nil and hex ~= f.crc then
					if attempt < M.max_retry then
						log("sai CRC", f.path, hex, "~=", f.crc, "-> thu lai")
						return after(0.5, function() try_file(f, attempt + 1) end)
					end
					log("SAI CRC", f.path, hex, "~=", f.crc)
					n_fail = n_fail + 1
					return finish_one()
				end
				local okw, err = write_file(dir .. f.path, body)
				if okw then
					st.applied[f.path] = f.crc
					n_ok = n_ok + 1
				else
					log("GHI LOI", f.path, tostring(err))
					n_fail = n_fail + 1
				end
				finish_one()
			end
			if crc_ready() then crc_of_string(body, commit) else commit(nil) end
		end)
	end

	M._pump = function()
		while inflight < M.max_parallel and idx < total do
			idx = idx + 1
			inflight = inflight + 1
			local f = todo[idx]
			local ok = pcall(try_file, f, 1)
			if not ok then
				n_fail = n_fail + 1
				inflight = inflight - 1
			end
		end
		if idx >= total and inflight == 0 then complete() end
	end
	M._pump()
end

function M.check(force)
	if M._running then return false end
	local dir = media_dir()
	if dir == nil then return false end
	M._running = true
	local function stop(msg)
		M._running = false
		if msg then log(msg) end
	end

	local okt, errt = pcall(function()
		fetch_manifest(1, function(branch, body, err)
			if branch == nil then return stop(err) end
			local ver, files, dels = parse_manifest(body)
			if ver == nil then return stop("manifest hong (khong co dong V)") end
			local st = load_state(dir)
			if (not force) and st.version == ver then
				return stop("da la ban moi nhat: " .. ver)
			end
			log("co phien ban", ver, "(may dang o", tostring(st.version) .. ")", #files, "file, nhanh", branch)

			stage_scan(dir, files, st, force, function(todo)
				log("can tai", #todo, "/", #files, "file")
				stage_download(dir, branch, todo, st, function(n_ok, n_fail)
					-- xoa file da bi go khoi repo
					local n_del = 0
					for _, p in ipairs(dels) do
						if file_size(dir .. p) ~= nil then
							if os.remove(dir .. p) then n_del = n_del + 1 end
						end
						st.applied[p] = nil
					end
					if n_fail == 0 then
						st.version = ver
						save_state(dir, st)
						log("XONG: tai", n_ok, "file, xoa", n_del, "-> phien ban", ver)
						if n_ok > 0 or n_del > 0 then
							M.restart_needed = true
							notify("HOT UPDATE: da cap nhat " .. n_ok .. " file (phien ban " .. ver
								.. ").\nHay THOAT HAN game roi mo lai de ap dung.", 14)
						end
					else
						save_state(dir, st) -- giu phien ban cu => lan mo game sau tu thu lai cac file con thieu
						log("CHUA XONG: tai", n_ok, "file, loi", n_fail, "-> se thu lai lan sau")
						notify("HOT UPDATE: con " .. n_fail .. " file chua tai duoc (se thu lai lan mo game sau).", 8)
					end
					stop()
				end)
			end)
		end)
	end)
	if not okt then stop("LOI check: " .. tostring(errt)) end
	return true
end

function M.start()
	if M._started then return end
	M._started = true
	local ok, err = pcall(function()
		if media_dir() == nil then return end
		if not M.enabled() then log("hot update dang TAT"); return end
		log("HotUpdate " .. M.version .. " san sang; kiem tra sau " .. M.delay_secs .. " giay")
		after(M.delay_secs, function() M.check(false) end)
	end)
	if not ok then print("[HotUpdate] LOI start: " .. tostring(err)) end
end

return M
