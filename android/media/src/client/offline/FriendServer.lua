-- FriendServer.lua
-- He thong BAN BE cho LocalServer (offline). Nap bang pcall(require, "client.offline.FriendServer") o cuoi
-- LocalServer.lua; neu file nay loi cu phap / loi luc chay thi chi tat tinh nang ban be, LocalServer van chay.
--
-- Lenh (ma): friend_update 48, random_user_list 54, present_endurance 55, search_user 57, friend_del 60,
--   friend_request 61, draw_endurance_init 62, draw_endurance 64, friend_pass 65, union_fight 135,
--   see_user_info 262, pull_black 263, remove_black 278.
-- Khoi tra ve (ma parser): 69 danh sach ban, 199 the luc nhan, 378 loi moi, 364 danh sach chan,
--   67 goi y / ket qua tim, 68 ket qua loi moi, 377 thong tin nguoi choi.
-- Gia dinh nhanh du an dragonball / l_digital (co khung avatar, 2 truong cuoi moi dong). Neu game chay nhanh khac
-- thi so truong trong goi se lech.
--
-- Luu tru:
--   * offline_friend_shared.txt (CHUNG moi tai khoan tren may): ho so cong khai, quan he ban, loi moi, qua the luc,
--     tap nguoi bi chan (de nguoi bi chan khong gui duoc loi moi).
--   * S.friend (state tung tai khoan): ban bot, danh sach chan (kem thong tin hien thi), luot tang / nhan trong ngay.

local F = {}

local SHARED_FILE   = "offline_friend_shared.txt"
local MAX_FRIENDS   = 60
local MAX_BLACK     = 50
local DRAW_PER_DAY  = 20
local FOOD_PER_GIFT = 3
local BOT_BASE      = 850000000   -- id ban bot = BOT_BASE + n (id tai khoan that >= 910000000)
local BOT_RANK0     = 300000      -- hang gia de AR.opp dung bot (khong trung nguoi that trong kho Arena)
local BOT_COUNT     = 40
local BTYPE_PK      = 13          -- loai tran khieu chien ban be
-- ma loi lay tu bang friend_error_code (offline_tables)
local ERR_ADDED, ERR_FULL, ERR_OTHER_FULL, ERR_BLACK_FULL = 31000, 31001, 31003, 31004
local ERR_SENT, ERR_NO_RECIPIENT, ERR_DRAWN_OUT, ERR_NOUSER = 31007, 31008, 31010, 31011
local ERR_BLOCKED_BY, ERR_BLOCKED = 31012, 31013

local host = nil

-- ---------------------------------------------------------------------------------------------------
-- tien ich
-- ---------------------------------------------------------------------------------------------------
local function sp(s)
	s = tostring(s == nil and "" or s)
	s = string.gsub(s, "[%s]+", "_")
	if s == "" then s = "_" end
	return s
end

local function num(v, d)
	local n = tonumber(v)
	if n == nil then return d or 0 end
	return math.floor(n)
end

local function today() return os.date("%Y%m%d", os.time()) end

local function split_ids(s)
	local out = {}
	for part in string.gmatch(tostring(s or ""), "[^,%s]+") do
		local n = tonumber(part)
		if n ~= nil then out[#out + 1] = math.floor(n) end
	end
	return out
end

local function me_key()
	local a = host.LS._acct
	local u = a ~= nil and a.user or nil
	if u == nil or u == "" then return nil end
	return string.lower(tostring(u))
end

local function now_ms(e)
	local add = 0
	if type(e) == "table" then add = num(e.time_add_or_sub, 0) end
	return (os.time() + add) * 1000
end

-- ---------------------------------------------------------------------------------------------------
-- kho chung
-- ---------------------------------------------------------------------------------------------------
local function db_read(force)
	local now = os.time()
	if not force and F._cache ~= nil and F._cache_t ~= nil and now - F._cache_t < 2 then return F._cache end
	local db = nil
	if host.H.read_first ~= nil then
		local ok, txt = pcall(host.H.read_first, SHARED_FILE)
		if ok and type(txt) == "string" and #txt > 2 then
			local t = host.deser(txt)
			if type(t) == "table" then db = t end
		end
	end
	if db == nil then db = {} end
	if type(db.users) ~= "table" then db.users = {} end     -- [key] = ho so cong khai
	if type(db.friends) ~= "table" then db.friends = {} end -- [key][otherkey] = true
	if type(db.req) ~= "table" then db.req = {} end         -- [targetkey][fromkey] = thoi gian
	if type(db.gift) ~= "table" then db.gift = {} end       -- [receiverkey][senderkey] = ngay
	if type(db.black) ~= "table" then db.black = {} end     -- [blockerkey][blockedkey] = true
	F._cache, F._cache_t = db, now
	return db
end

local function db_write(db)
	if host.H.write_first == nil then return false end
	local buf = {}
	local ok, err = pcall(host.ser, db, buf)
	if not ok then host.log("ban be: loi ghi kho chung:", tostring(err)); return false end
	pcall(host.H.write_first, SHARED_FILE, table.concat(buf))
	F._cache, F._cache_t = db, os.time()
	return true
end

-- ---------------------------------------------------------------------------------------------------
-- thong tin nguoi choi hien tai
-- ---------------------------------------------------------------------------------------------------
local function my_info(e)
	local u = type(e) == "table" and e.user_info or {}
	local name = tostring(u.user_name or "Player")
	local a = host.LS._acct
	if a ~= nil and a.user ~= nil and a.user ~= "" then name = tostring(a.user) end
	local force = num(u.fight_capacity, 0)
	if force <= 0 then force = 100000 end
	return {
		uid = num(u.user_id, 0), name = sp(name), level = math.max(1, num(u.user_grade, 1)),
		vip = num(u.vip_grade, 0), force = force, head = math.max(1, num(u.user_head, 1)),
	}
end

-- doi hinh hien tai dang chuoi: tid:cap:evo:sao:pham:luc:skin!...
local function my_team_str(e)
	local parts = {}
	local f = type(e) == "table" and e.formetion or nil
	if type(f) ~= "table" or type(e.user_ship) ~= "table" then return "" end
	for i = 2, 7 do
		local sid = f[i]
		local s = sid ~= nil and e.user_ship[tostring(sid)] or nil
		if type(s) == "table" and tonumber(s.ship_template_id) ~= nil then
			parts[#parts + 1] = table.concat({
				host.fint(num(s.ship_template_id, 0)), host.fint(math.max(1, num(s.ship_grade, 1))),
				tostring(s.evolution_status or "1|0,0,0,0"), tostring(s.StarRating or 3), tostring(s.Order or 1),
				host.fint(num(s.hero_fight, 0)), tostring(s.skin_id or 0),
			}, ":")
		end
	end
	return table.concat(parts, "!")
end

local function team_str_of(team)
	local parts = {}
	for _, t in ipairs(team or {}) do
		parts[#parts + 1] = table.concat({
			host.fint(num(t.tid, 0)), host.fint(num(t.g, 1)), tostring(t.evo or "1|0,0,0,0"), tostring(t.star or 3),
			tostring(t.order or 1), host.fint(num(t.force, 0)), tostring(t.skin or 0),
		}, ":")
	end
	return table.concat(parts, "!")
end

-- ---------------------------------------------------------------------------------------------------
-- state tung tai khoan
-- ---------------------------------------------------------------------------------------------------
local function acct()
	local S = host.S()
	if type(S.friend) ~= "table" then S.friend = {} end
	local f = S.friend
	if type(f.bots) ~= "table" then f.bots = {} end   -- ["id"] = true
	if type(f.black) ~= "table" then f.black = {} end -- ["id"] = { name, level, vip, force, head, key? }
	if type(f.sent) ~= "table" then f.sent = {} end   -- ["id"] = true (da tang hom nay)
	if type(f.drawn) ~= "table" then f.drawn = {} end -- ["id"] = true (da nhan hom nay)
	f.drawn_n = num(f.drawn_n, 0)
	local d = today()
	if f.day ~= d then
		f.day, f.sent, f.drawn, f.drawn_n = d, {}, {}, 0
		host.mark()
	end
	return f
end

local function count_keys(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

-- ---------------------------------------------------------------------------------------------------
-- danh ba nguoi choi (that + bot)
-- ---------------------------------------------------------------------------------------------------
local BOT_FIRST = { "Sora", "Kuro", "Ryu", "Hana", "Kai", "Mika", "Taro", "Yuki", "Ren", "Aiko" }

local function bot_info(e, n)
	local me = my_info(e)
	return {
		bot = true, uid = BOT_BASE + n, n = n, key = nil,
		name = BOT_FIRST[(n % #BOT_FIRST) + 1] .. "_" .. string.format("%02d", n),
		level = math.max(1, me.level + (n % 7) - 3), vip = n % 6,
		force = math.floor(me.force * (0.8 + (n % 9) * 0.05)), head = 1 + (n % 8),
	}
end

local function is_bot_id(id) return id > BOT_BASE and id <= BOT_BASE + BOT_COUNT end

-- thong tin 1 nguoi that tu kho ban be + kho Arena
local function real_by_key(k)
	local db = db_read(false)
	local u = db.users[k]
	if type(u) == "table" then
		return { bot = false, key = k, uid = num(u.uid, 0), name = sp(u.name), level = num(u.level, 1), vip = num(u.vip, 0),
			force = num(u.force, 0), head = math.max(1, num(u.head, 1)), team = u.team, t = num(u.t, 0) }
	end
	local ar = host.AR
	if ar ~= nil and ar.sh_read ~= nil then
		local ok, adb = pcall(ar.sh_read, false)
		local pl = ok and type(adb) == "table" and type(adb.players) == "table" and adb.players[k] or nil
		if type(pl) == "table" then
			return { bot = false, key = k, uid = num(pl.uid, 0), name = sp(pl.user or pl.name), level = num(pl.level, 1),
				vip = num(pl.vip, 0), force = num(pl.force, 0), head = math.max(1, num(pl.icon, 1)),
				team = team_str_of(pl.team), t = num(pl.t, 0) }
		end
	end
	return nil
end

-- tat ca nguoi choi that da biet (tru minh)
local function real_directory()
	local mk = me_key()
	local keys, out = {}, {}
	local db = db_read(false)
	for k in pairs(db.users) do keys[k] = true end
	local ar = host.AR
	if ar ~= nil and ar.sh_read ~= nil then
		local ok, adb = pcall(ar.sh_read, false)
		if ok and type(adb) == "table" and type(adb.players) == "table" then
			for k in pairs(adb.players) do keys[k] = true end
		end
	end
	for k in pairs(keys) do
		if k ~= mk then
			local r = real_by_key(k)
			if r ~= nil and r.uid > 0 then out[#out + 1] = r end
		end
	end
	table.sort(out, function(a, b) return a.uid < b.uid end)
	return out
end

local function real_by_uid(uid)
	for _, r in ipairs(real_directory()) do
		if r.uid == uid then return r end
	end
	return nil
end

-- nguoi bat ky theo id (bot hoac that); nil neu khong co
local function person(e, uid)
	if is_bot_id(uid) then return bot_info(e, uid - BOT_BASE) end
	return real_by_uid(uid)
end

-- ghi ho so cong khai cua tai khoan hien tai (giam tan suat ghi file)
local function publish(e, force)
	local k = me_key()
	if k == nil or type(e) ~= "table" then return end
	local me = my_info(e)
	if me.uid <= 0 then return end
	local db = db_read(false)
	local old = db.users[k]
	local now = os.time()
	if not force and type(old) == "table" and now - num(old.t, 0) < 30 and old.level == me.level and old.name == me.name then return end
	db.users[k] = { uid = me.uid, name = me.name, level = me.level, vip = me.vip, force = me.force, head = me.head,
		team = my_team_str(e), t = now }
	db_write(db)
end

local function friend_set(db, k)
	if type(db.friends[k]) ~= "table" then db.friends[k] = {} end
	return db.friends[k]
end

-- ---------------------------------------------------------------------------------------------------
-- dung khoi tra ve (moi truong 1 dong, ngan cach \r\n)
-- ---------------------------------------------------------------------------------------------------
local function blk(code, fields)
	local t = { tostring(code) }
	for i = 1, #fields do t[#t + 1] = tostring(fields[i]) end
	return table.concat(t, "\r\n")
end

local function push_person(t, p, extra_before_leave, last_ms, tail)
	t[#t + 1] = host.fint(p.uid)
	t[#t + 1] = host.fint(p.vip)
	t[#t + 1] = host.fint(p.head)
	t[#t + 1] = "0"                    -- title
	t[#t + 1] = p.name
	t[#t + 1] = host.fint(p.level)
	t[#t + 1] = host.fint(p.force)
	t[#t + 1] = "0"                    -- army (bang hoi)
	if extra_before_leave ~= nil then t[#t + 1] = extra_before_leave end
	t[#t + 1] = host.fint(last_ms)
	if tail then
		t[#t + 1] = "0"                -- headFrameID
		t[#t + 1] = "0"                -- headFrameStage
	end
end

local function list_friends(e, f)
	local out = {}
	local mk = me_key()
	if mk ~= nil then
		local db = db_read(false)
		local mine = db.friends[mk]
		if type(mine) == "table" then
			local keys = {}
			for k in pairs(mine) do keys[#keys + 1] = k end
			table.sort(keys)
			for _, k in ipairs(keys) do
				local r = real_by_key(k)
				if r ~= nil then out[#out + 1] = r end
			end
		end
	end
	local ids = {}
	for sid in pairs(f.bots) do ids[#ids + 1] = tonumber(sid) end
	table.sort(ids)
	for _, id in ipairs(ids) do
		if is_bot_id(id) then out[#out + 1] = bot_info(e, id - BOT_BASE) end
	end
	return out
end

local function last_seen_ms(e, p)
	if p.bot then return now_ms(e) - (p.n % 5) * 600000 end
	if p.t ~= nil and p.t > 0 then return p.t * 1000 end
	return now_ms(e)
end

local function blk69(e, f)
	local t = {}
	local list = list_friends(e, f)
	t[1] = host.fint(#list)
	for _, p in ipairs(list) do
		local sent = f.sent[tostring(p.uid)] and "1" or "0"
		push_person(t, p, sent, last_seen_ms(e, p), true)
	end
	return blk(69, t)
end

-- khoi 199: the luc nhan duoc (ban bot luon "tang" 1 lan / ngay; ban that khi ho da tang)
local function gift_entries(e, f)
	local out = {}
	local mk = me_key()
	local today_s = today()
	if mk ~= nil then
		local db = db_read(false)
		local g = db.gift[mk]
		local mine = db.friends[mk]
		if type(g) == "table" and type(mine) == "table" then
			for sk, day in pairs(g) do
				if day == today_s and mine[sk] then
					local r = real_by_key(sk)
					if r ~= nil then out[#out + 1] = r end
				end
			end
		end
	end
	for sid in pairs(f.bots) do
		local id = tonumber(sid)
		if is_bot_id(id) then out[#out + 1] = bot_info(e, id - BOT_BASE) end
	end
	table.sort(out, function(a, b) return a.uid < b.uid end)
	return out
end

local function blk199(e, f)
	local list = gift_entries(e, f)
	local t = { host.fint(math.max(0, DRAW_PER_DAY - f.drawn_n)), host.fint(#list) }
	for _, p in ipairs(list) do
		t[#t + 1] = host.fint(p.uid)       -- id ban ghi = id nguoi tang
		t[#t + 1] = host.fint(p.uid)
		t[#t + 1] = host.fint(p.vip)
		t[#t + 1] = host.fint(p.head)
		t[#t + 1] = "0"
		t[#t + 1] = p.name
		t[#t + 1] = host.fint(p.level)
		t[#t + 1] = host.fint(p.force)
		t[#t + 1] = "0"
		t[#t + 1] = host.fint(last_seen_ms(e, p))
		t[#t + 1] = f.drawn[tostring(p.uid)] and "1" or "0"
	end
	return blk(199, t)
end

local function blk378(e)
	local t = {}
	local mk = me_key()
	local rows = {}
	if mk ~= nil then
		local db = db_read(false)
		local r = db.req[mk]
		if type(r) == "table" then
			for fk, ts in pairs(r) do
				local p = real_by_key(fk)
				if p ~= nil then rows[#rows + 1] = p end
			end
		end
	end
	table.sort(rows, function(a, b) return a.uid < b.uid end)
	t[1] = host.fint(#rows)
	for _, p in ipairs(rows) do push_person(t, p, nil, last_seen_ms(e, p), true) end
	return blk(378, t)
end

local function blk364(e, f)
	local rows = {}
	for sid, info in pairs(f.black) do
		rows[#rows + 1] = { uid = tonumber(sid) or 0, name = sp(info.name), level = num(info.level, 1), vip = num(info.vip, 0),
			force = num(info.force, 0), head = math.max(1, num(info.head, 1)) }
	end
	table.sort(rows, function(a, b) return a.uid < b.uid end)
	local t = { host.fint(#rows) }
	for _, p in ipairs(rows) do push_person(t, p, nil, now_ms(e), true) end
	return blk(364, t)
end

local function blk67(e, list)
	local t = { host.fint(#list) }
	for _, p in ipairs(list) do push_person(t, p, nil, last_seen_ms(e, p), true) end
	return blk(67, t)
end

local function blk68(op, id)
	return blk(68, { tostring(op), host.fint(id) })
end

-- ---------------------------------------------------------------------------------------------------
-- quan he
-- ---------------------------------------------------------------------------------------------------
local function is_friend(f, p)
	if p.bot then return f.bots[tostring(p.uid)] == true end
	local mk = me_key()
	if mk == nil then return false end
	local db = db_read(false)
	return type(db.friends[mk]) == "table" and db.friends[mk][p.key] == true
end

local function friend_count(e, f)
	local n = count_keys(f.bots)
	local mk = me_key()
	if mk ~= nil then
		local db = db_read(false)
		if type(db.friends[mk]) == "table" then n = n + count_keys(db.friends[mk]) end
	end
	return n
end

local function is_black(f, p)
	return f.black[tostring(p.uid)] ~= nil
end

local function add_friend_real(db, a, b)
	friend_set(db, a)[b] = true
	friend_set(db, b)[a] = true
	if type(db.req[a]) == "table" then db.req[a][b] = nil end
	if type(db.req[b]) == "table" then db.req[b][a] = nil end
end

-- ---------------------------------------------------------------------------------------------------
-- handler
-- ---------------------------------------------------------------------------------------------------
local function rp(seq, name, blocks) return host.reply(seq, name, blocks) end
local function er(seq, name, code, msg) return host.err_reply(seq, name, msg or "LS_ban_be", code) end

local function ctx()
	local e = host.ED()
	if e == nil or type(e.user_info) ~= "table" then return nil end
	return e
end

local function full_update(e, f)
	return { blk69(e, f), blk199(e, f), blk378(e), blk364(e, f) }
end

local function h_update(p, seq)
	local e = ctx()
	if e == nil then return er(seq, "friend_update", 1, "LS_chua_san_sang") end
	publish(e, false)
	return rp(seq, "friend_update", full_update(e, acct()))
end

local function h_draw_init(p, seq)
	local e = ctx()
	if e == nil then return er(seq, "draw_endurance_init", 1, "LS_chua_san_sang") end
	publish(e, false)
	return rp(seq, "draw_endurance_init", { blk199(e, acct()) })
end

local function h_random(p, seq)
	local e = ctx()
	if e == nil then return er(seq, "random_user_list", 1, "LS_chua_san_sang") end
	publish(e, false)
	local f = acct()
	local pool = {}
	for _, r in ipairs(real_directory()) do
		if not is_friend(f, r) and not is_black(f, r) then pool[#pool + 1] = r end
	end
	for n = 1, BOT_COUNT do
		local b = bot_info(e, n)
		if not is_friend(f, b) and not is_black(f, b) then pool[#pool + 1] = b end
	end
	-- xao tron (seed theo gio)
	local seed = os.time()
	for i = #pool, 2, -1 do
		seed = (seed * 1664525 + 1013904223) % 4294967296
		local j = (seed % i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, math.min(10, #pool) do out[i] = pool[i] end
	return rp(seq, "random_user_list", { blk67(e, out) })
end

local function h_search(p, seq)
	local e = ctx()
	if e == nil then return er(seq, "search_user", 1, "LS_chua_san_sang") end
	local text = tostring(p[#p] or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local f = acct()
	local low = string.lower(text)
	local uid = tonumber(text)
	local out = {}
	if low ~= "" then
		local all = real_directory()
		for n = 1, BOT_COUNT do all[#all + 1] = bot_info(e, n) end
		for _, r in ipairs(all) do
			if #out < 10 and not is_black(f, r) then
				if (uid ~= nil and r.uid == math.floor(uid)) or string.find(string.lower(r.name), low, 1, true) ~= nil then
					out[#out + 1] = r
				end
			end
		end
	end
	return rp(seq, "search_user", { blk67(e, out) })
end

local function h_request(p, seq)
	local name = "friend_request"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	publish(e, true)
	local f = acct()
	local ids = split_ids(p[1])
	if #ids == 0 then return er(seq, name, ERR_NOUSER, "LS_thieu_tham_so") end
	local me = my_info(e)
	local mk = me_key()
	local db = db_read(true)
	local done, last_err = 0, nil
	for _, id in ipairs(ids) do
		local q = person(e, id)
		if id == me.uid then last_err = ERR_NOUSER
		elseif q == nil then last_err = ERR_NOUSER
		elseif is_friend(f, q) then last_err = ERR_ADDED
		elseif friend_count(e, f) >= MAX_FRIENDS then last_err = ERR_FULL
		elseif is_black(f, q) then last_err = ERR_BLOCKED
		elseif q.bot then
			f.bots[tostring(q.uid)] = true -- bot tu chap nhan
			done = done + 1
		elseif mk == nil then last_err = ERR_NOUSER
		else
			local blocked = type(db.black[q.key]) == "table" and db.black[q.key][mk] == true
			local other_n = type(db.friends[q.key]) == "table" and count_keys(db.friends[q.key]) or 0
			if blocked then last_err = ERR_BLOCKED_BY
			elseif other_n >= MAX_FRIENDS then last_err = ERR_OTHER_FULL
			else
				if type(db.req[q.key]) ~= "table" then db.req[q.key] = {} end
				db.req[q.key][mk] = os.time()
				done = done + 1
			end
		end
	end
	db_write(db)
	host.mark()
	if done == 0 and last_err ~= nil then return er(seq, name, last_err, "LS_khong_gui_duoc_loi_moi") end
	return rp(seq, name, { blk68(1, ids[1]), blk69(e, f) })
end

local function h_pass(p, seq)
	local name = "friend_pass"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local mk = me_key()
	local id = num(p[1], 0)
	local op = num(p[2], 1)
	if mk == nil then return er(seq, name, ERR_NOUSER, "LS_chua_dang_nhap") end
	local q = real_by_uid(id)
	if q == nil then return er(seq, name, ERR_NOUSER, "LS_khong_co_nguoi_choi") end
	local db = db_read(true)
	local pending = type(db.req[mk]) == "table" and db.req[mk][q.key] ~= nil
	if not pending then return er(seq, name, ERR_NOUSER, "LS_khong_co_loi_moi") end
	if op == 1 then
		if friend_count(e, f) >= MAX_FRIENDS then return er(seq, name, ERR_FULL, "LS_ban_be_day") end
		add_friend_real(db, mk, q.key)
	else
		db.req[mk][q.key] = nil
	end
	db_write(db)
	host.mark()
	return rp(seq, name, { blk68(op, id), blk69(e, f), blk378(e) })
end

local function h_del(p, seq)
	local name = "friend_del"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local id = num(p[1], 0)
	if is_bot_id(id) then
		f.bots[tostring(id)] = nil
	else
		local mk = me_key()
		local q = real_by_uid(id)
		if mk ~= nil and q ~= nil then
			local db = db_read(true)
			if type(db.friends[mk]) == "table" then db.friends[mk][q.key] = nil end
			if type(db.friends[q.key]) == "table" then db.friends[q.key][mk] = nil end
			db_write(db)
		end
	end
	host.mark()
	return rp(seq, name, { blk69(e, f) })
end

local function h_black_add(p, seq)
	local name = "pull_black"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local id = num(p[1], 0)
	local q = person(e, id)
	if q == nil then return er(seq, name, ERR_NOUSER, "LS_khong_co_nguoi_choi") end
	if f.black[tostring(id)] == nil and count_keys(f.black) >= MAX_BLACK then
		return er(seq, name, ERR_BLACK_FULL, "LS_danh_sach_chan_day")
	end
	-- chan = xoa ban (neu la ban) + xoa loi moi dang cho
	if q.bot then
		f.bots[tostring(id)] = nil
	else
		local mk = me_key()
		if mk ~= nil then
			local db = db_read(true)
			if type(db.friends[mk]) == "table" then db.friends[mk][q.key] = nil end
			if type(db.friends[q.key]) == "table" then db.friends[q.key][mk] = nil end
			if type(db.req[mk]) == "table" then db.req[mk][q.key] = nil end
			if type(db.black[mk]) ~= "table" then db.black[mk] = {} end
			db.black[mk][q.key] = true
			db_write(db)
		end
	end
	f.black[tostring(id)] = { name = q.name, level = q.level, vip = q.vip, force = q.force, head = q.head }
	host.mark()
	return rp(seq, name, full_update(e, f))
end

local function h_black_del(p, seq)
	local name = "remove_black"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local id = num(p[1], 0)
	f.black[tostring(id)] = nil
	local mk = me_key()
	local q = (not is_bot_id(id)) and real_by_uid(id) or nil
	if mk ~= nil and q ~= nil then
		local db = db_read(true)
		if type(db.black[mk]) == "table" then db.black[mk][q.key] = nil end
		db_write(db)
	end
	host.mark()
	return rp(seq, name, { blk364(e, f) })
end

local function h_present(p, seq)
	local name = "present_endurance"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local ids = split_ids(p[1])
	local mk = me_key()
	local sent = 0
	local db = nil
	for _, id in ipairs(ids) do
		local q = person(e, id)
		if q ~= nil and is_friend(f, q) and not f.sent[tostring(id)] then
			f.sent[tostring(id)] = true
			sent = sent + 1
			if not q.bot and mk ~= nil then
				db = db or db_read(true)
				if type(db.gift[q.key]) ~= "table" then db.gift[q.key] = {} end
				db.gift[q.key][mk] = today()
			end
		end
	end
	if db ~= nil then db_write(db) end
	if sent == 0 then return er(seq, name, ERR_SENT, "LS_da_tang_hom_nay") end
	host.mark()
	return rp(seq, name, { blk69(e, f) })
end

local function h_draw(p, seq)
	local name = "draw_endurance"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local ids = split_ids(p[1])
	local avail = {}
	for _, q in ipairs(gift_entries(e, f)) do avail[q.uid] = true end
	local got = 0
	for _, id in ipairs(ids) do
		if f.drawn_n >= DRAW_PER_DAY then break end
		if avail[id] and not f.drawn[tostring(id)] then
			f.drawn[tostring(id)] = true
			f.drawn_n = f.drawn_n + 1
			got = got + 1
		end
	end
	if got == 0 then
		return er(seq, name, (f.drawn_n >= DRAW_PER_DAY) and ERR_DRAWN_OUT or ERR_NO_RECIPIENT, "LS_khong_nhan_duoc")
	end
	local cur = host.LS.user_get ~= nil and host.LS.user_get("food") or nil
	if cur ~= nil and host.LS.gm_set_food ~= nil then
		host.LS.gm_set_food(cur + got * FOOD_PER_GIFT)
	end
	host.mark()
	return rp(seq, name, { blk199(e, f) })
end

-- khoi 377 (nhanh dragonball/l_digital): id, vip, lead, title, name, grade, fighting, army, formation, signature,
-- is_friend, speed, headFrameID, headFrameStage, imageID, titleID, isBlock
local function h_info(p, seq)
	local name = "see_user_info"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local f = acct()
	local id = num(p[1], 0)
	local me = my_info(e)
	local q = nil
	local team = ""
	if id == me.uid then
		q = { uid = me.uid, vip = me.vip, head = me.head, name = me.name, level = me.level, force = me.force, bot = false }
		team = my_team_str(e)
	else
		q = person(e, id)
		if q == nil then return er(seq, name, ERR_NOUSER, "LS_khong_co_nguoi_choi") end
		if q.bot then
			local ok, o = pcall(host.AR.opp, e, BOT_RANK0 + q.n, 1, "full")
			if ok and type(o) == "table" and type(o.team) == "table" then team = team_str_of(o.team) end
		else
			team = tostring(q.team or "")
		end
	end
	if team == "" then team = my_team_str(e) end
	local t = {
		host.fint(q.uid), host.fint(q.vip), host.fint(q.head), "0", q.name, host.fint(q.level), host.fint(q.force), "0",
		team, "_", (is_friend(f, q) and "1" or "0"), "0", "0", "0", host.fint(q.head), "0", (is_black(f, q) and "1" or "0"),
	}
	return rp(seq, name, { blk(377, t) })
end

-- khieu chien ban be: dung lai may chay tran cua Arena, loai tran 13
local function h_fight(p, seq)
	local name = "union_fight"
	local e = ctx()
	if e == nil then return er(seq, name, 1, "LS_chua_san_sang") end
	local ar, sb = host.AR, host.SB
	if ar == nil or sb == nil or ar.run_safe == nil or ar.opp == nil then
		return er(seq, name, 1, "LS_khong_co_may_chay_tran")
	end
	local f = acct()
	local id = num(p[1], 0)
	local q = person(e, id)
	if q == nil then return er(seq, name, ERR_NOUSER, "LS_khong_co_nguoi_choi") end
	if not is_friend(f, q) then return er(seq, name, ERR_NOUSER, "LS_khong_phai_ban_be") end
	local rank = BOT_RANK0 + (q.n or 0)
	local o = nil
	if not q.bot then
		-- nguoi that: dung doi hinh da luu trong kho Arena (neu co), khong co thi dung bot
		local ok, adb = pcall(ar.sh_read, false)
		local pl = ok and type(adb) == "table" and type(adb.players) == "table" and adb.players[q.key] or nil
		if type(pl) == "table" and num(pl.rank, 0) > 0 and ar.sh_opp ~= nil then
			local ok2, real = pcall(ar.sh_opp, num(pl.rank, 0))
			if ok2 and type(real) == "table" and real.real_key == q.key then o = real; rank = real.rank end
		end
		if o == nil then rank = BOT_RANK0 + (q.uid % BOT_COUNT) + 1 end
	end
	if o == nil then
		local okb, bot = pcall(ar.opp, e, rank, 1, "full")
		if not okb or type(bot) ~= "table" then return er(seq, name, 1, "LS_loi_dung_doi_thu") end
		o = bot
	end
	o.btype = BTYPE_PK
	o.name = q.name
	local res, o2, err = ar.run_safe(e, o, rank, 1)
	if res == nil then
		host.log("ban be: loi tinh tran", tostring(err))
		return er(seq, name, 1, "LS_loi_tinh_tran")
	end
	return rp(seq, name, { res.init, sb.block39(res) })
end

-- ---------------------------------------------------------------------------------------------------
-- cai dat
-- ---------------------------------------------------------------------------------------------------
function F.install(h)
	host = h
	local H = h.HANDLERS
	H.friend_update        = h_update
	H.draw_endurance_init  = h_draw_init
	H.random_user_list     = h_random
	H.search_user          = h_search
	H.friend_request       = h_request
	H.friend_pass          = h_pass
	H.friend_del           = h_del
	H.pull_black           = h_black_add
	H.remove_black         = h_black_del
	H.present_endurance    = h_present
	H.draw_endurance       = h_draw
	H.see_user_info        = h_info
	H.union_fight          = h_fight
	F.installed = true
	return true
end

return F
