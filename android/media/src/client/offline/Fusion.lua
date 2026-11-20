-- Fusion.lua  (fu-2.8)
-- [fu-2.8] BOT HOP THE KHONG XOA TUONG KHOI DOI HINH: truoc day tuong phu (cac o cuoi) bi LOAI khoi tran nen doi hinh bot mat 1-2 chien binh.
--   Nay mac dinh Fusion.bot.keep_team = true: tuong phu chi la NGUON (chi so / talent / ky nang / hinh cua than hop the) - van dung trong doi hinh va van danh nhu binh thuong.
--   Luu y: tuong phu duoc tinh 2 lan (vua gop vao than chinh, vua danh rieng) => bot manh hon. Muon tru bot nhu cu (tuong phu bi loai): Fusion.bot.keep_team = false.
--   Khi keep_team = true, Fusion.bot.min_left khong con tac dung; chi can doi hinh bot co tu 2 tuong tro len (cu: 3 tuong tro len).
-- [fu-2.7] HOP THE NGAU NHIEN CHO BOT ARENA: bot (phe dich) co the duoc ghep ngau nhien 1 than chinh + 1-2 tuong phu LAY TU CHINH DOI HINH BOT
--   (cac o cuoi, nen cac o con lai van lien tuc 1..m). Cung luat voi nguoi choi: chi so = tong cac tuong (3 tuong / 2, 2 tuong khong chia), toc do = cao nhat,
--   gop talent + gop buff ky nang, FusionFx ve 2 than hop the ben phe dich. Chi ap dung cho tran Arena thuong (LocalServer AR.arena_copy / AR.run_core).
--   Quyet dinh theo seed (hang + batch + doi hinh) => cung 1 bot luon co cung ket qua (preview va tran nhat quan); doi batch (lam moi) => bot khac.
--   Tinh chinh: Fusion.bot.enabled | Fusion.bot.chance (0..1, ti le bot co hop the, mac dinh 0.5) | Fusion.bot.p3 (ti le hop 3 tuong, con lai 2 tuong)
--   | Fusion.bot.min_left (so chien binh toi thieu con lai sau khi hop, mac dinh 2) | Fusion.bot.fx (false = khong ve than hop the cua bot).
--   Tat nhanh trong LocalServer: S.cfg.bot_fusion = false.  Loi bat ky => bot danh nhu binh thuong.
-- [fu-2.6] GOP BUFF CUA KY NANG: 3 tuong = (tuong 1 + tuong 2 + tuong 3) / 2; 2 tuong = (tuong 1 + tuong 2) / 3  (KHAC chi so: chi so 2 tuong khong chia).
--   Moi buff la 1 dong skill_influence (healthAffect cua ky nang). Dong buff cua THAN CHINH duoc ghep voi dong CUNG LOAI, CUNG O KY NANG
--   (chieu thuong = commonSkill, chieu dac biet = specialSkill) cua tuong 2, 3; tuong nao khong co dong do thi cong 0.
--   Vd than chinh +20% cong, 2 tuong kia +30% va +10%  =>  (20 + 30 + 10) / 2 = 30%.   Chi co 3 tuong (khong co dong) =>  20 / 2 = 10%.
--   "Cung loai" = cung formulaInfo + cung isRate (% hay so cung) + cung influenceGroup + cung influenceRange; neu 1 ky nang co nhieu dong
--   cung loai thi ghep theo thu tu (dong thu k cua than chinh voi dong thu k cua tuong kia). Chi ap dung cho cac cong thuc trong
--   Fusion.buff_formulas (tang/giam cong, thu, bao kich, khang bao, chinh xac, ne, sat thuong...). Sat thuong / hoi mau / khong che KHONG dung.
--   Cac gia tri thay duoc: skillEffectMinValue + skillEffectMaxValue cua dong buff (cong roi chia, lam tron so nguyen). Ty le kich hoat,
--   so hiep, muc tieu, hieu ung hinh anh giu nguyen cua than chinh. Chi sua doi tuong trong tran (ban sao rieng tung tran), khong dong vao bang du lieu.
--   Tinh chinh: Fusion.merge_buffs (true/false) | Fusion.buff_div = { [2] = 3, [3] = 2 } | Fusion.buff_mult | Fusion.buff_formulas | Fusion.buff_debug.
--   Hook them: BattleObject.initSkillAndTalentInfo (ap gia tri sau khi engine dung xong cac dong buff cua than chinh).
--   Gioi han: buff noi tiep (nextSkillInfluence) va ky nang nho (normalSkillMould) CHUA gop.
-- [fu-2.5] CONG THUC CHI SO HOP THE THEO SO TUONG: 3 tuong = (tuong 1 + tuong 2 + tuong 3) / 2; 2 tuong = tuong 1 + tuong 2 (khong chia).
--   Ap dung cho mau / cong / thu vat ly / thu phep / luc chien (toc do van la cao nhat). Ket qua lam tron so nguyen.
--   Tinh chinh: Fusion.stat_div = { [2] = 1, [3] = 2 } (so chia theo so tuong) | Fusion.stat_mult (he so nhan them, mac dinh 1).
-- [fu-2.4] SUA THANG HO SO GOC: khi hop the dang BAT va than chinh dang o doi hinh, chi so TONG (mau / cong / thu vat ly / thu phep /
--   luc chien, toc do = cao nhat) duoc GHI THANG vao ho so than chinh trong _ED.user_ship => man Doi hinh (Lineup), man tuong... hien dung
--   chi so hop the. Gia tri that cua than chinh duoc giu trong Fu._live.base; TAT hop the / xoa chon / doi than chinh / than chinh roi doi hinh
--   => tra lai nguyen ven. Chi la du lieu trong bo nho: LocalServer luu theo S.heroes / S.mods, KHONG doc nguoc ship_health... nen khong vao file luu.
--   Neu LocalServer ghi lai ho so (len cap, lam moi...) thi gia tri vua ghi duoc coi la gia tri that moi roi cong lai (Fu.live_sync, moi 0.5 giay).
--   Tat tinh nang nay: Fu.live = false (khi do chi hop the luc vao tran nhu fu-2.3).
-- [fu-2.3] HOP THE CHI CAN 2 TUONG (toi da 3): Fu.min_n = 2 (du 2 tuong la tu BAT), Fu.max_n = 3 (van chon them duoc tuong 3).
--   2 tuong => 1 than chinh + 1 than phu; 3 tuong => 1 than chinh + 2 than phu nhu fu-2.1. Chi so = TONG cac tuong da chon.
--   FusionFx.lua (fx-1.11) da xu ly duoc 1 than phu (than 1 quay nguoc, luon hien, khong nhap nhay).
-- [fu-2.1] tu nap lai + noi lai FusionFx neu bi app.unload lam rong (sau doi ngon ngu / cap nhat); xem FusionFx.lua (fx-1.1).
-- HOP THE 3 TUONG (chi OFFLINE): chon 3 tuong trong bang GM, vao tran 3 tuong nay gop thanh 1 chien binh duy nhat.
--
-- Cach hoat dong (khong sua engine goc, chi boc ham bang pcall, loi => tran danh nhu binh thuong):
--   1) Bang GM co nut "HOP THE" (OfflineMock, id 41) mo bang chon tuong (ten, cap, sao, luc chien).
--      Tuong chon DAU TIEN = than chinh (model + ky nang). Chon du 3 tuong => tu BAT.
--   2) Truoc FightModule:initBattleField / initNewBattleField (luc tao doi tuong chien dau phe ta):
--        - than chinh PHAI dang o trong doi hinh, neu khong thi khong ap dung;
--        - 2 tuong con lai (neu dang o doi hinh) bi go TAM khoi doi hinh;
--        - ho so cua than chinh trong _ED.user_ship duoc thay TAM bang ban hop the:
--          mau / cong / thu vat ly / thu phep / luc chien = TONG 3 tuong, toc do = cao nhat.
--      Engine tu tinh moi thu tu ban hop the nen chi so nhat quan (kiem tra copyAt/copyPh da bi OfflineMock bo qua).
--   3) Sau khi tao xong, doi hinh va ho so duoc TRA LAI nguyen ven (ke ca khi engine bao loi).
--   4) FightObject:initWithUserData: gop them thien phu (talent) cua 2 tuong con lai vao than chinh (khong trung).
--
-- Khong ap dung: fightType 1 (dau truong moi truong) va 15 (doi hinh rieng 6 o), tran bot-vs-bot cua LocalServer
-- (doi hinh de rong), tran long nhau (dang trong cua so hop the).
--
-- [fu-2.0] HIEU UNG HOP THE (file FusionFx.lua): dung yen chi thay than chinh; khi than chinh DANH, 2 "than hop the"
--   (model + chieu + hieu ung + am thanh cua tuong 2 va 3) hien ra danh cung. Fusion chi (a) lay ho so chieu cua
--   tuong 2, 3 luc dung tran -> Fusion.battle, (b) nap + gan FusionFx. Nut "HIEU UNG" tren bang chon bat/tat.
--   Khong co FusionFx.lua hoac FusionFx loi => van gop chi so nhu fu-1.0, khong co than hop the.
--
-- Tinh chinh nhanh:  Fusion.stat_mult (he so nhan tren tong chi so, mac dinh 1), Fusion.merge_talents (true/false),
--                    Fusion.fx_on (true/false), Fusion.debug (true = ghi log nhan dien than chinh);
--                    FusionFx.offsets / FusionFx.stagger / FusionFx.hit_fx.

Fusion = Fusion or {}
local Fu = Fusion

Fu.version       = "fu-2.8"
Fu.enabled       = true            -- cong tac tong
Fu.stat_mult     = Fu.stat_mult or 1.0
if Fu.merge_talents == nil then Fu.merge_talents = true end
Fu.ud_key        = "offline_fusion"
Fu.host          = Fu.host or {}   -- OfflineMock cap: notify, scene, size, schedule, log, z
Fu.sel           = Fu.sel or {}    -- { idThanChinh, id2, id3 } (chuoi, khoa trong _ED.user_ship)
Fu.min_n         = Fu.min_n or 2   -- [fu-2.3] so tuong toi thieu de hop the
Fu.max_n         = Fu.max_n or 3   -- [fu-2.3] so tuong toi da (1 chinh + toi da 2 phu)
Fu.on            = Fu.on or false
Fu.fx_module     = "client.offline.FusionFx"
if Fu.fx_on == nil then Fu.fx_on = true end -- bat/tat hieu ung 2 than hop the (chi la trinh chieu)
if Fu.live == nil then Fu.live = true end   -- [fu-2.4] ghi thang chi so hop the vao ho so goc (man Doi hinh thay duoc)
Fu._live         = Fu._live          -- { id, rec, base = {key=gia tri that}, fused = {key=gia tri da ghi}, hist }
Fu.battle        = nil             -- { lead = id than chinh, twins = { ho so tuong 2, ho so tuong 3 } } cua tran dang danh
Fu.debug         = Fu.debug or false
Fu._wrapped      = Fu._wrapped or setmetatable({}, { __mode = "k" })

local unpack = unpack or table.unpack
local PANEL_NAME = "offlinemock_fu_panel"
local STAT_SUM   = { "ship_health", "ship_courage", "ship_intellect", "ship_quick", "hero_fight" }
local LIVE_KEYS  = { "ship_health", "ship_courage", "ship_intellect", "ship_quick", "hero_fight", "ship_wisdom" }

-- [fu-2.5] he so nhan len TONG chi so theo so tuong n: stat_mult / stat_div[n] (3 tuong: / 2, 2 tuong: / 1)
Fu.stat_div = Fu.stat_div or { [1] = 1, [2] = 1, [3] = 2 }
local function stat_factor(n)
	local mult = tonumber(Fu.stat_mult) or 1
	if mult <= 0 then mult = 1 end
	local d = Fu.stat_div
	if type(d) == "table" then d = d[n] end
	d = tonumber(d) or 1
	if d <= 0 then d = 1 end
	return mult / d
end
local function stat_round(x) return math.floor(x + 0.5) end

-- [fu-2.6] gop buff ky nang: so chia theo so tuong (3 tuong: tong / 2, 2 tuong: tong / 3 -- khac chi so)
if Fu.merge_buffs == nil then Fu.merge_buffs = true end
Fu.buff_mult = Fu.buff_mult or 1.0
Fu.buff_div  = Fu.buff_div or { [1] = 1, [2] = 3, [3] = 2 }
if Fu.buff_debug == nil then Fu.buff_debug = false end -- true = ghi log tung dong buff duoc gop
-- skill_influence.formulaInfo cua cac dong buff co gia tri la DO LON (min/max = %, hoac so cung khi isRate ~= 0).
-- Lay theo danh sach cong thuc "do lon" cua MegaBuff.lua, bo cac cong thuc ma min/max la ty le kich hoat / so luot / so hiep.
-- 21 +cong, 22 -cong, 23 +thu, 24 -thu, 25 / 26 sat thuong nhan them / bot, 27 +bao kich, 28 +khang bao, 29 +chinh xac, 30 +ne, 33 +sat thuong,
-- 38 +cuong do do don, 39 -ty le do don, 40 +hut mau, 43 +pha do don, 44 +phan don, 45 +giam sat thuong, 51 -sat thuong cong them,
-- 53 +khong che, 54-55 sat thuong tuyet ky, 56-57 toc do hoi no, 58 sat thuong bao kich, 60 cuong do bao kich, 61 -giam sat thuong, 62 ty le tuyet ky,
-- 63 +do don, 66 -bao kich, 67 -khang bao, 68-69 khang tuyet ky.
Fu.buff_formulas = Fu.buff_formulas or {
	[21] = true, [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true,
	[33] = true, [38] = true, [39] = true, [40] = true, [43] = true, [44] = true, [45] = true, [51] = true,
	[53] = true, [54] = true, [55] = true, [56] = true, [57] = true, [58] = true,
	[60] = true, [61] = true, [62] = true, [63] = true, [66] = true, [67] = true, [68] = true, [69] = true,
}
local function buff_factor(n)
	local mult = tonumber(Fu.buff_mult) or 1
	if mult <= 0 then mult = 1 end
	local d = Fu.buff_div
	if type(d) == "table" then d = d[n] end
	d = tonumber(d) or 1
	if d <= 0 then d = 1 end
	return mult / d
end

-- ------------------------------------------------------------------ tien ich chung
local function log(...)
	local f = Fu.host and Fu.host.log
	local t = {}
	for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
	local s = "[Fusion] " .. table.concat(t, " ")
	if type(f) == "function" then pcall(f, s) else print(s) end
end

local function say(text, secs)
	local f = Fu.host and Fu.host.notify
	if type(f) == "function" then pcall(f, text, secs or 5) else log(text) end
end

local function ED()
	local e = rawget(_G, "_ED")
	if type(e) == "table" then return e end
	return nil
end

local function user_ships()
	local e = ED()
	if e ~= nil and type(e.user_ship) == "table" then return e.user_ship end
	return nil
end

local function ship_of(id)
	local us = user_ships()
	if us == nil or id == nil then return nil end
	local s = us[tostring(id)]
	if type(s) == "table" then return s end
	return nil
end

local function fint(n) return string.format("%.0f", n) end

-- giu nguyen kieu (so / chuoi) cua gia tri goc de engine so sanh khong bi loi
local function like(orig, n)
	if type(orig) == "number" then return n end
	return fint(n)
end

local function cut_utf8(s, n)
	s = tostring(s or "")
	local i, len = 1, 0
	while i <= #s and len < n do
		local c = string.byte(s, i)
		local step = 1
		if c >= 240 then step = 4 elseif c >= 224 then step = 3 elseif c >= 192 then step = 2 end
		i = i + step
		len = len + 1
	end
	if i <= #s then return string.sub(s, 1, i - 1) .. ".." end
	return s
end

local function fmt_num(n)
	n = tonumber(n)
	if n == nil then return "-" end
	local s = fint(n)
	local neg = false
	if string.sub(s, 1, 1) == "-" then neg = true; s = string.sub(s, 2) end
	while true do
		local r, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then break end
	end
	if neg then s = "-" .. s end
	return s
end

-- [fu-2.4] so sanh theo gia tri so (chuoi "123" == so 123)
local function same_num(a, b)
	local x, y = tonumber(a), tonumber(b)
	if x ~= nil and y ~= nil then return x == y end
	return tostring(a) == tostring(b)
end

-- [fu-2.4] gia tri THAT cua 1 truong: neu ho so dang duoc ghi thang (than chinh) thi lay ban goc da luu, khong lay ban da cong
local function base_of(id, key)
	local rec = ship_of(id)
	if rec == nil then return nil end
	local L = Fu._live
	if L ~= nil and L.rec == rec and L.id == tostring(id) and L.base[key] ~= nil then return L.base[key] end
	return rec[key]
end

-- ------------------------------------------------------------------ luu / nap lua chon
local function ud_get(key)
	local ok, v = pcall(function() return cc.UserDefault:getInstance():getStringForKey(key, "") end)
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

function Fu.load()
	if Fu._loaded then return end
	Fu._loaded = true
	local s = ud_get(Fu.ud_key)
	if s == nil then return end
	-- dinh dang: "on|id1,id2,id3" (fu-1.0) hoac "on|id1,id2,id3|fx" (fu-2.0)
	local on, ids, fx = string.match(s, "^(%d)|([^|]*)|?(%d?)$")
	if on == nil then return end
	Fu.on = (on == "1")
	if fx ~= nil and fx ~= "" then Fu.fx_on = (fx == "1") end
	Fu.sel = {}
	for id in string.gmatch(ids, "[^,]+") do
		if #Fu.sel < Fu.max_n then Fu.sel[#Fu.sel + 1] = id end
	end
end

function Fu.save()
	ud_set(Fu.ud_key, (Fu.on and "1" or "0") .. "|" .. table.concat(Fu.sel, ",") .. "|" .. (Fu.fx_on and "1" or "0"))
end

-- ------------------------------------------------------------------ ten / thong tin tuong
local name_cache = {}

local function hero_name(rec)
	if type(rec) ~= "table" then return "?" end
	if tostring(rec.captain_type) == "0" then
		local e = ED()
		local n = e and type(e.user_info) == "table" and e.user_info.user_name
		if n ~= nil and tostring(n) ~= "" then return tostring(n) end
	end
	local tid = tostring(rec.ship_template_id)
	local ck = tid .. "|" .. tostring(rec.evolution_status) .. "|" .. tostring(rec.skin_id)
	local c = name_cache[ck]
	if c ~= nil then return c end
	local ok, name = pcall(function()
		local evo = smGetSkinEvoIdChange(rec)
		local nid = dms.int(dms["ship_evo_mould"], evo, ship_evo_mould.name_index)
		local w = dms.element(dms["word_mould"], nid)
		if type(w) == "table" and w[3] ~= nil then return tostring(w[3]) end
		return ""
	end)
	if ok and type(name) == "string" and name ~= "" and #name <= 36 and name ~= "Chưa có" then
		name_cache[ck] = name
		return name
	end
	return "Hero " .. tid
end

local function hero_list()
	local us = user_ships()
	local list = {}
	if us == nil then return list end
	for k, rec in pairs(us) do
		if type(rec) == "table" and tonumber(k) ~= nil and tonumber(rec.ship_template_id) ~= nil then
			local ct = tostring(rec.captain_type)
			if ct == "1" or ct == "0" then
				list[#list + 1] = { id = tostring(k), rec = rec, power = tonumber(base_of(k, "hero_fight")) or 0 }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.power ~= b.power then return a.power > b.power end
		return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
	end)
	return list
end

-- ------------------------------------------------------------------ ke hoach hop the + ban ghi hop the
-- tra ve { ids = {3 chuoi}, recs = {3 ho so goc} } hoac nil, ly do
local function plan()
	if not Fu.enabled or not Fu.on then return nil, "tat" end
	if #Fu.sel < Fu.min_n then return nil, "chua du " .. Fu.min_n .. " tuong" end
	local ids, recs, seen = {}, {}, {}
	for i = 1, math.min(#Fu.sel, Fu.max_n) do
		local id = tostring(Fu.sel[i])
		if seen[id] then return nil, "trung tuong" end
		seen[id] = true
		local r = ship_of(id)
		if r == nil then return nil, "khong thay tuong " .. id end
		ids[i], recs[i] = id, r
	end
	return { ids = ids, recs = recs }
end

local function fused_record(p)
	local lead = p.recs[1]
	local f = {}
	for k, v in pairs(lead) do f[k] = v end -- sao chep nong: bang con dung chung (chi doc)
	local mult = stat_factor(#p.recs) -- [fu-2.5] 3 tuong: tong / 2; 2 tuong: tong
	for _, key in ipairs(STAT_SUM) do
		local total, any = 0, false
		for i = 1, #p.recs do
			local v = tonumber(base_of(p.ids[i], key)) -- [fu-2.4] than chinh: lay gia tri that (khong cong 2 lan)
			if v ~= nil then total = total + v; any = true end
		end
		if any then f[key] = like(lead[key], stat_round(total * mult)) end
	end
	local sp
	for i = 1, #p.recs do
		local v = tonumber(base_of(p.ids[i], "ship_wisdom"))
		if v ~= nil and (sp == nil or v > sp) then sp = v end
	end
	if sp ~= nil then f.ship_wisdom = like(lead.ship_wisdom, sp) end
	f._fusion = true
	return f
end

-- ------------------------------------------------------------------ ap dung / tra lai quanh luc tao doi tuong chien dau
local function restore(undo)
	if undo == nil then return end
	Fu._ctx = nil
	pcall(function()
		for _, ed in ipairs(undo.edits) do undo.f[ed[1]] = ed[2] end
	end)
	pcall(function() undo.us[undo.lead] = undo.orig end)
end

local function apply(ftype)
	if Fu._ctx ~= nil then return nil end -- dang trong cua so hop the (tran long nhau)
	Fu.battle = nil                       -- tran moi: quen than hop the cua tran truoc
	if not Fu.enabled or not Fu.on then return nil end
	local ft = tonumber(ftype)
	if ft == 1 or ft == 15 then return nil end
	local p = plan()
	if p == nil then return nil end
	local e = ED()
	if e == nil or type(e.formetion) ~= "table" or type(e.user_ship) ~= "table" then return nil end
	local f, us = e.formetion, e.user_ship

	local lead = p.ids[1]
	local member = {}
	for _, mid in ipairs(p.ids) do member[mid] = true end -- [fu-2.3] 2 hoac 3 tuong
	local lead_seat, others = nil, {}
	for k = 2, 7 do -- o doi hinh = formetion[2..7] (formetion[1] la so doi hinh)
		local v = f[k]
		if v ~= nil then
			local sv = tostring(v)
			if sv == lead then
				lead_seat = k
			elseif member[sv] then
				others[#others + 1] = k
			end
		end
	end
	if lead_seat == nil then return nil end -- than chinh khong o doi hinh: khong hop the

	local undo = { f = f, us = us, lead = lead, orig = us[lead], edits = {} }
	local ok, err = pcall(function()
		for _, k in ipairs(others) do
			undo.edits[#undo.edits + 1] = { k, f[k] }
			f[k] = "0"
		end
		us[lead] = fused_record(p)
	end)
	if not ok then
		restore(undo)
		log("loi ap dung hop the:", err)
		return nil
	end
	Fu._ctx = { plan = p }
	Fu.battle = { lead = p.ids[1], twins = {} } -- FusionFx doc; init_maker dien twins; restore() khong xoa (tran con trinh chieu)
	local names = {}
	for i = 1, #p.recs do names[#names + 1] = hero_name(p.recs[i]) end
	Fu.last = table.concat(names, "+")
	return undo
end


-- ------------------------------------------------------------------ [fu-2.4] ghi thang chi so hop the vao ho so goc
-- history_info = AES("jar-world", mau..toc do..leader..cong..thu..phep) giong LocalServer.apply_fields: giu khop voi chi so moi
local function aes_hist(rec)
	local aes = rawget(_G, "aeslua")
	if type(aes) ~= "table" or aes.encrypt == nil then return false end
	local ok, enc = pcall(aes.encrypt, "jar-world",
		tostring(rec.ship_health) .. tostring(rec.ship_wisdom) .. tostring(rec.ship_leader or "0")
		.. tostring(rec.ship_courage) .. tostring(rec.ship_intellect) .. tostring(rec.ship_quick),
		aes.AES128, aes.ECBMODE)
	if ok and enc ~= nil then rec.history_info = enc; return true end
	return false
end

local function lead_in_formation(e, lead)
	local f = e and e.formetion
	if type(f) ~= "table" then return false end
	for k = 2, 7 do
		if f[k] ~= nil and tostring(f[k]) == lead then return true end
	end
	return false
end

-- tra ho so than chinh ve gia tri that (chi dong vao truong nao van dang la gia tri minh da ghi)
local function live_release()
	local L = Fu._live
	if L == nil then return end
	Fu._live = nil
	local us = user_ships()
	if us == nil or us[L.id] ~= L.rec then return end -- ho so da bi thay bang bang khac: khong dong vao
	local rec = L.rec
	for _, key in ipairs(LIVE_KEYS) do
		if L.base[key] ~= nil and L.fused[key] ~= nil and same_num(rec[key], L.fused[key]) then
			rec[key] = L.base[key]
		end
	end
	if not aes_hist(rec) and L.hist ~= nil then rec.history_info = L.hist end
	if Fu.debug then log("da tra ho so than chinh", L.id) end
end

-- goi ~0.5 giay/lan + moi khi doi lua chon. Idempotent, moi loi deu bi pcall o noi goi.
function Fu.live_sync()
	if Fu._ctx ~= nil then return end -- dang giua luc tao tran (dong bo), khong chen vao
	if not Fu.live then live_release(); return end
	local p
	if Fu.enabled and Fu.on then p = plan() end
	local e = ED()
	if p == nil or e == nil then live_release(); return end
	local lead = p.ids[1]
	if not lead_in_formation(e, lead) then live_release(); return end
	local rec = p.recs[1]

	local L = Fu._live
	if L ~= nil and L.id ~= lead then live_release(); L = nil end
	if L ~= nil and L.rec ~= rec then Fu._live = nil; L = nil end -- bang ho so cu da bi thay: bo, khong khoi phuc
	if L == nil then
		L = { id = lead, rec = rec, base = {}, fused = {}, hist = rec.history_info }
		Fu._live = L
	end

	-- gia tri khac gia tri minh vua ghi = gia tri THAT (lan dau, hoac LocalServer vua ghi lai) => lay lam goc moi
	local rebased = false
	for _, key in ipairs(LIVE_KEYS) do
		local cur = rec[key]
		if cur ~= nil and (L.fused[key] == nil or not same_num(cur, L.fused[key])) then
			L.base[key] = cur
			rebased = true
		end
	end
	if rebased then L.hist = rec.history_info end

	local mult = stat_factor(#p.recs) -- [fu-2.5]
	local changed = false
	for _, key in ipairs(STAT_SUM) do
		local b = L.base[key]
		if b ~= nil then
			local total = tonumber(b) or 0
			for i = 2, #p.recs do
				local v = tonumber(p.recs[i][key])
				if v ~= nil then total = total + v end
			end
			local want = like(b, stat_round(total * mult))
			if not same_num(rec[key], want) then rec[key] = want; changed = true end
			L.fused[key] = want
		end
	end
	local bw = L.base.ship_wisdom
	if bw ~= nil then
		local sp = tonumber(bw)
		for i = 2, #p.recs do
			local v = tonumber(p.recs[i].ship_wisdom)
			if v ~= nil and (sp == nil or v > sp) then sp = v end
		end
		if sp ~= nil then
			local want = like(bw, sp)
			if not same_num(rec.ship_wisdom, want) then rec.ship_wisdom = want; changed = true end
			L.fused.ship_wisdom = want
		end
	end
	if changed then
		aes_hist(rec)
		if Fu.debug then log("da ghi chi so hop the vao ho so than chinh", lead, "CR=" .. tostring(rec.hero_fight)) end
	end
end

-- ------------------------------------------------------------------ boc ham engine (idempotent)
local function wrap_method(cls, name, maker)
	if type(cls) ~= "table" then return false end
	local f = rawget(cls, name)
	if type(f) ~= "function" then return false end
	if Fu._wrapped[f] then return true end
	local w = maker(f)
	Fu._wrapped[w] = true
	rawset(cls, name, w)
	return true
end

local function field_maker(arg_pos)
	return function(orig)
		return function(self, ...)
			local ftype = select(arg_pos, ...)
			local undo
			local okp, res = pcall(apply, ftype)
			if okp then undo = res else log("apply loi:", res) end
			if undo ~= nil then pcall(Fu.attach) end -- gan hook FusionFx TRUOC khi tran tao vai (class() sao chep ham luc new)
			local r = { pcall(orig, self, ...) }
			if undo ~= nil then restore(undo) end
			if not r[1] then error(r[2], 0) end
			return r[2], r[3], r[4]
		end
	end
end

-- tao FightObject cua tuong 2, 3 (dung cach engine dung cho tuong that): nguon de gop talent + lay ho so chieu cho than hop the
local function build_extras(orig_init, ...)
	local FO = rawget(_G, "FightObject")
	local ctx = Fu._ctx
	if ctx == nil or type(FO) ~= "table" or type(FO.new) ~= "function" then return nil end
	local coordinate, _, battle_tag, user_id, fm = ...
	local list = {}
	for i = 2, #ctx.plan.recs do
		local po = FO:new()
		local ok, err = pcall(orig_init, po, coordinate, ctx.plan.recs[i], battle_tag, user_id, fm)
		if ok then
			list[#list + 1] = { po = po, rec = ctx.plan.recs[i] }
		else
			log("khong khoi tao duoc tuong phu", i, err)
		end
	end
	return list
end

-- gop talent cua tuong 2, 3 vao tuong hop the (doi tuong chien dau cua than chinh)
local function merge_talents(lead_obj, extras)
	if type(lead_obj.talentMouldList) ~= "table" then return end
	local have = {}
	for _, t in ipairs(lead_obj.talentMouldList) do
		have[tostring(t.id) .. ":" .. tostring(t.level)] = true
	end
	local added = 0
	for _, ex in ipairs(extras) do
		local po = ex.po
		if type(po.talentMouldList) == "table" then
			for _, t in ipairs(po.talentMouldList) do
				local key = tostring(t.id) .. ":" .. tostring(t.level)
				if not have[key] then
					have[key] = true
					table.insert(lead_obj.talentMouldList, t)
					added = added + 1
				end
			end
		end
	end
	if added > 0 then log("da gop", added, "thien phu vao tuong hop the") end
end

-- ho so 2 than hop the cho FusionFx: model (picIndex) + chieu thuong + chieu dac biet cua tuong 2, 3
local function collect_twins(extras)
	local fx, b = Fu.FX, Fu.battle
	if type(fx) ~= "table" or type(fx.profile) ~= "function" or b == nil then return end
	local twins = {}
	for _, ex in ipairs(extras) do
		local okp, prof = pcall(fx.profile, ex.po, ex.rec, hero_name(ex.rec))
		if okp and prof ~= nil then twins[#twins + 1] = prof end
	end
	b.twins = twins
	if Fu.debug then
		local names = {}
		for _, p in ipairs(twins) do names[#names + 1] = tostring(p.name) .. "(model " .. tostring(p.head) .. ")" end
		log("than hop the:", #twins, table.concat(names, ", "), "than chinh id=" .. tostring(b.lead))
	end
end

-- ------------------------------------------------------------------ [fu-2.6] gop BUFF cua ky nang
-- O ky nang -> (truong ky nang tren FightObject, danh sach dong buff tren BattleObject)
local BUFF_SLOTS = {
	{ name = "thuong",    skill = "commonSkill",  list = "commonBattleSkill"  }, -- chieu thuong
	{ name = "dac biet",  skill = "specialSkill", list = "oneselfBattleSkill" }, -- chieu dac biet
}

-- id cac dong skill_influence cua 1 ky nang (giong cach BattleObject:initSkillAndTalentInfo tach healthAffect)
local function influence_ids(skill)
	local out = {}
	if type(skill) ~= "table" or skill.healthAffect == nil then return out end
	for tok in string.gmatch(tostring(skill.healthAffect), "[^,|]+") do
		local n = tonumber(tok)
		if n ~= nil and n > 0 then out[#out + 1] = n end
	end
	return out
end

-- nap 1 dong skill_influence (doi tuong moi, rieng) tu ConfigDB; loi / thieu du lieu => nil
local function load_influence(id)
	local cdb = rawget(_G, "ConfigDB")
	if type(cdb) ~= "table" or type(cdb.load) ~= "function" then return nil end
	local ok, o = pcall(cdb.load, "skill_influence", id)
	if ok and type(o) == "table" and tonumber(o.formulaInfo) ~= nil then return o end
	return nil
end

-- "cung loai": cung cong thuc + cung kieu gia tri (% / so cung) + cung phe tac dung + cung pham vi
local function influence_key(o)
	return table.concat({
		tostring(tonumber(o.formulaInfo)), tostring(tonumber(o.isRate)),
		tostring(tonumber(o.influenceGroup)), tostring(tonumber(o.influenceRange)),
	}, "|")
end

local function influence_lines(skill)
	local lines = {}
	for _, id in ipairs(influence_ids(skill)) do
		local o = load_influence(id)
		if o ~= nil then lines[#lines + 1] = { id = id, o = o, key = influence_key(o) } end
	end
	return lines
end

local function num_text(n)
	if n == nil then return "0" end
	return fint(n)
end

-- Tinh gia tri buff sau khi gop. lead_obj = FightObject than chinh, extras = { {po = FightObject tuong 2, rec}, ... }.
-- Tra ve plan, report:  plan[ten danh sach tren BattleObject] = { {id, min, max}, ... } (theo thu tu dong cua than chinh)
local function build_buff_plan(lead_obj, extras)
	if type(lead_obj) ~= "table" or type(extras) ~= "table" or #extras == 0 then return nil end
	local factor = buff_factor(1 + #extras)
	local formulas = type(Fu.buff_formulas) == "table" and Fu.buff_formulas or {}
	local plan, report = {}, {}
	for _, S in ipairs(BUFF_SLOTS) do
		-- dong cua tuong 2, 3 trong cung o ky nang, gom theo "loai", giu thu tu
		local others = {}
		for j, ex in ipairs(extras) do
			local by = {}
			for _, L in ipairs(influence_lines(type(ex.po) == "table" and ex.po[S.skill] or nil)) do
				local b = by[L.key]
				if b == nil then b = {}; by[L.key] = b end
				b[#b + 1] = L
			end
			others[j] = by
		end
		local seen, entries = {}, {}
		for _, L in ipairs(influence_lines(lead_obj[S.skill])) do
			seen[L.key] = (seen[L.key] or 0) + 1
			local f = tonumber(L.o.formulaInfo)
			local lo, hi = tonumber(L.o.skillEffectMinValue), tonumber(L.o.skillEffectMaxValue)
			if f ~= nil and formulas[f] and lo ~= nil and hi ~= nil and lo <= hi then
				local sum_lo, sum_hi = lo, hi
				local parts, valid = { num_text(hi) }, true
				for j = 1, #others do
					local b = others[j][L.key]
					local M = b and b[seen[L.key]] or nil
					local mlo = M and tonumber(M.o.skillEffectMinValue) or nil
					local mhi = M and tonumber(M.o.skillEffectMaxValue) or nil
					if mlo ~= nil and mhi ~= nil then
						if mlo > mhi then valid = false end
						sum_lo, sum_hi = sum_lo + mlo, sum_hi + mhi
						parts[#parts + 1] = num_text(mhi)
					else
						parts[#parts + 1] = "0" -- tuong nay khong co dong buff cung loai: cong 0
					end
				end
				local new_lo, new_hi = stat_round(sum_lo * factor), stat_round(sum_hi * factor)
				if valid and new_lo <= new_hi then
					entries[#entries + 1] = { id = L.id, min = new_lo, max = new_hi }
					report[#report + 1] = string.format("chieu %s: dong %s (cong thuc %s): max %s -> %s",
						S.name, tostring(L.id), fint(f), table.concat(parts, "+"), num_text(new_hi))
				end
			end
		end
		if #entries > 0 then plan[S.list] = entries end
	end
	if next(plan) == nil then return nil, report end
	return plan, report
end

-- Ap plan len BattleObject (cac SkillInfluence trong BattleSkill la ban nap moi cua rieng doi tuong nay, khong dung chung bang du lieu)
local function apply_buff_plan(bo, plan)
	if type(bo) ~= "table" or type(plan) ~= "table" then return 0 end
	local applied = 0
	for list_name, entries in pairs(plan) do
		local list = bo[list_name]
		if type(list) == "table" then
			local queue, used = {}, {}
			for _, e in ipairs(entries) do
				local q = queue[e.id]
				if q == nil then q = {}; queue[e.id] = q end
				q[#q + 1] = e
			end
			for i = 1, #list do
				local bs = list[i]
				local si = type(bs) == "table" and bs.skillInfluence or nil
				local id = type(si) == "table" and tonumber(si.id) or nil
				local q = id ~= nil and queue[id] or nil
				if q ~= nil then
					used[id] = (used[id] or 0) + 1
					local e = q[used[id]]
					if e ~= nil then
						si.skillEffectMinValue = e.min
						si.skillEffectMaxValue = e.max
						applied = applied + 1
					end
				end
			end
		end
	end
	return applied
end

-- BattleObject:initSkillAndTalentInfo: engine vua tao xong cac BattleSkill => ap gia tri buff da gop cua than hop the
local function battle_init_maker(orig)
	return function(self, ...)
		local r1, r2, r3 = orig(self, ...)
		local fo = type(self) == "table" and self.fightObject or nil
		local plan = type(fo) == "table" and rawget(fo, "_fuBuff") or nil
		if plan ~= nil then
			local ok, n = pcall(apply_buff_plan, self, plan)
			if not ok then
				log("ap buff loi:", n)
			elseif Fu.buff_debug then
				log("da ap", n, "dong buff hop the")
			end
		end
		return r1, r2, r3
	end
end

local function init_maker(orig)
	return function(self, ...)
		local r1, r2, r3 = orig(self, ...)
		if Fu._ctx ~= nil then
			local _, ship = ...
			if type(ship) == "table" and rawget(ship, "_fusion") == true then
				local need_fx = (type(Fu.FX) == "table") and Fu.fx_on and Fu.battle ~= nil
				local need_buff = Fu.merge_buffs and true or false
				if Fu.merge_talents or need_fx or need_buff then
					local oke, extras = pcall(build_extras, orig, ...)
					if oke and type(extras) == "table" then
						if Fu.merge_talents then
							local okm, errm = pcall(merge_talents, self, extras)
							if not okm then log("gop talent loi:", errm) end
						end
						if need_buff then
							rawset(self, "_fuBuff", nil)
							local okb, plan, report = pcall(build_buff_plan, self, extras)
							if okb then
								if plan ~= nil then rawset(self, "_fuBuff", plan) end
								Fu.buff_report = report
								if Fu.buff_debug and type(report) == "table" then
									for _, line in ipairs(report) do log("buff", line) end
								end
							else
								log("gop buff loi:", plan)
							end
						end
						if need_fx then
							local okc, errc = pcall(collect_twins, extras)
							if not okc then log("lay ho so than hop the loi:", errc) end
						end
					elseif not oke then
						log("tao tuong phu loi:", extras)
					end
				end
			end
		end
		return r1, r2, r3
	end
end

-- [fu-2.1] FusionFx KHONG nam trong danh sach app.unload bo qua => sau app.reload module bi LAM RONG (mat ham + mat lien ket).
-- Phat hien va nap lai / noi lai. Idempotent: FusionFx con nguyen thi khong lam gi. Thu nap lai toi da 5 lan (tranh lap vo han neu file loi).
local function ensure_fx()
	local fx = Fu.FX
	if type(fx) == "table" and type(fx.attach) == "function" then
		if fx.fu ~= Fu then pcall(fx.bind, Fu) end
		return fx
	end
	Fu._fx_retry = (Fu._fx_retry or 0) + 1
	if Fu._fx_retry > 5 then return nil end
	pcall(function() package.loaded[Fu.fx_module] = nil end)
	local okx, mod = pcall(require, Fu.fx_module)
	if okx and type(mod) == "table" and type(mod.attach) == "function" then
		Fu.FX = mod
		pcall(mod.bind, Fu)
		log("da nap lai FusionFx", tostring(mod.version))
		return mod
	end
	return nil
end

function Fu.attach()
	local fm = rawget(_G, "FightModule")
	local a = wrap_method(fm, "initBattleField", field_maker(3))    -- (npc, difficulty, fightType, ...)
	local b = wrap_method(fm, "initNewBattleField", field_maker(2)) -- (npcId, fightType)
	local c = wrap_method(rawget(_G, "FightObject"), "initWithUserData", init_maker)
	-- [fu-2.6] ap buff da gop len cac dong buff cua than chinh (khong anh huong Fu.hooked: thieu thi chi mat tinh nang gop buff)
	Fu.buff_hooked = wrap_method(rawget(_G, "BattleObject"), "initSkillAndTalentInfo", battle_init_maker)
	Fu.hooked = (a and b and c) and true or false
	local fx = ensure_fx()
	if type(fx) == "table" and type(fx.attach) == "function" then
		local okf, hooked = pcall(fx.attach)
		Fu.fx_hooked = (okf and hooked == true) and true or false
	end
	return Fu.hooked
end

-- ------------------------------------------------------------------ chon tuong
function Fu.clear()
	Fu.sel = {}
	Fu.save()
	pcall(Fu.live_sync)
end

function Fu.toggle_on()
	if not Fu.on and #Fu.sel < Fu.min_n then
		say("HOP THE: can chon it nhat " .. Fu.min_n .. " tuong truoc khi BAT (dang chon " .. #Fu.sel .. "/" .. Fu.max_n .. ").", 5)
		return
	end
	Fu.on = not Fu.on
	Fu.save()
	pcall(Fu.live_sync)
end

function Fu.toggle_fx()
	Fu.fx_on = not Fu.fx_on
	Fu.save()
	say("HIEU UNG HOP THE: " .. (Fu.fx_on and "BAT" or "TAT"), 3)
end

function Fu.pick(id)
	id = tostring(id)
	for i = 1, #Fu.sel do
		if Fu.sel[i] == id then
			table.remove(Fu.sel, i)
			Fu.save()
			pcall(Fu.live_sync)
			return
		end
	end
	if #Fu.sel >= Fu.max_n then
		say("Da chon du " .. Fu.max_n .. " tuong. Cham tuong da chon de bo, hoac bam XOA CHON.", 4)
		return
	end
	Fu.sel[#Fu.sel + 1] = id
	if #Fu.sel == Fu.min_n then
		Fu.on = true
		say("HOP THE: BAT - than chinh = tuong 1 (phai dang o trong doi hinh).", 6)
	end
	Fu.save()
	pcall(Fu.live_sync)
end

-- ------------------------------------------------------------------ nut tren bang GM
function Fu.label()
	local n = #Fu.sel
	if Fu.on and n >= Fu.min_n then return "HOP THE: BAT", cc.c4b(35, 105, 45, 255) end
	if Fu.on then return "HOP THE: " .. n .. "/" .. Fu.min_n, cc.c4b(140, 110, 40, 255) end
	return "HOP THE: TAT", cc.c4b(120, 45, 45, 255)
end

function Fu.sig()
	return (Fu.on and "1" or "0") .. (Fu.fx_on and "f" or "-") .. ":" .. table.concat(Fu.sel, ",")
end

-- ------------------------------------------------------------------ bang chon tuong (overlay)
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
	new_rect(parent, r, color)
	return new_label(parent, text, size, r.x + r.w / 2, r.y + r.h / 2, 0.5)
end

local function host_scene()
	local f = Fu.host and Fu.host.scene
	if type(f) == "function" then return f() end
	local ok, s = pcall(function() return cc.Director:getInstance():getRunningScene() end)
	if ok then return s end
	return nil
end

local function host_size()
	local f = Fu.host and Fu.host.size
	if type(f) == "function" then return f() end
	return cc.Director:getInstance():getVisibleSize()
end

local function layout(size)
	local pw = math.min(size.width - 16, 720)
	local ph = math.min(size.height - 12, 520)
	if pw < 300 then pw = 300 end
	if ph < 260 then ph = 260 end
	local L = { pw = pw, ph = ph, header = 70, footer = 56, rowh = 38 }
	L.x = math.floor((size.width - pw) / 2)
	L.y = math.floor((size.height - ph) / 2)
	L.per = math.max(3, math.floor((ph - L.header - L.footer) / L.rowh))
	L.close = { x = pw - 10 - 70, y = ph - 40, w = 70, h = 32 }
	local bw = math.floor((pw - 10 * 2 - 6 * 4) / 5)
	L.btn = {}
	for i = 1, 5 do L.btn[i] = { x = 10 + (i - 1) * (bw + 6), y = 8, w = bw, h = 40 } end
	L.rows = {}
	for i = 1, L.per do
		local top = ph - L.header - (i - 1) * L.rowh
		L.rows[i] = { x = 6, y = top - L.rowh + 3, w = pw - 12, h = L.rowh - 6 }
	end
	return L
end

local function sel_index(id)
	for i = 1, #Fu.sel do
		if Fu.sel[i] == id then return i end
	end
	return nil
end

function Fu.render()
	local scene = host_scene()
	if scene == nil then return end
	local old = scene:getChildByName(PANEL_NAME)
	if old ~= nil then old:removeFromParent() end
	if not Fu._open then Fu._view = nil; return end

	local size = host_size()
	local L = layout(size)
	local heroes = hero_list()
	local pages = math.max(1, math.ceil(#heroes / L.per))
	if (Fu._page or 1) > pages then Fu._page = pages end
	if (Fu._page or 1) < 1 then Fu._page = 1 end
	Fu._page = Fu._page or 1
	Fu._view = { L = L, heroes = heroes, pages = pages }

	local root = cc.LayerColor:create(cc.c4b(8, 10, 18, 248), L.pw, L.ph)
	root:setPosition(cc.p(L.x, L.y))
	pcall(function() root:setName(PANEL_NAME) end)

	new_label(root, "HOP THE 2-3 TUONG   trang " .. Fu._page .. "/" .. pages, 18, 10, L.ph - 16, 0)
	local hint = new_label(root, "Tuong 1 = than chinh (phai o doi hinh): chi so TONG ghi thang vao ho so (xem o Doi hinh). Tuong 2 (va 3): gop thien phu; luc danh hien than hop the.", 12, 10, L.ph - 36, 0)
	pcall(function() hint:setColor(cc.c3b(150, 230, 255)) end)
	local parts = {}
	for i = 1, Fu.max_n do
		local rec = Fu.sel[i] ~= nil and ship_of(Fu.sel[i]) or nil
		parts[#parts + 1] = i .. ") " .. (rec ~= nil and cut_utf8(hero_name(rec), 10) or "-")
	end
	local sl = new_label(root, "Chon: " .. table.concat(parts, "   "), 15, 10, L.ph - 56, 0)
	pcall(function() sl:setColor(cc.c3b(255, 230, 120)) end)
	new_button(root, L.close, "DONG", 17, cc.c4b(130, 40, 40, 255))

	local first = (Fu._page - 1) * L.per
	for i = 1, L.per do
		local h = heroes[first + i]
		if h == nil then break end
		local R = L.rows[i]
		local si = sel_index(h.id)
		local col = (i % 2 == 0) and cc.c4b(36, 40, 54, 255) or cc.c4b(28, 32, 44, 255)
		if si == 1 then col = cc.c4b(150, 110, 0, 255) elseif si ~= nil then col = cc.c4b(35, 105, 45, 255) end
		new_rect(root, R, col)
		local cy = R.y + R.h / 2
		new_label(root, si ~= nil and tostring(si) or "", 18, R.x + 16, cy, 0.5)
		new_label(root, cut_utf8(hero_name(h.rec), 16), 16, R.x + 40, cy, 0)
		new_label(root, "Lv" .. tostring(tonumber(h.rec.ship_grade) or "?"), 15, math.floor(L.pw * 0.52), cy, 0)
		new_label(root, "*" .. tostring(tonumber(h.rec.StarRating) or "?"), 15, math.floor(L.pw * 0.64), cy, 0)
		local pl = new_label(root, fmt_num(h.power), 14, L.pw - 14, cy, 1)
		pcall(function() pl:setColor(cc.c3b(150, 230, 255)) end)
	end
	if #heroes == 0 then
		new_label(root, "Chua co tuong nao (vao game roi mo lai bang nay).", 16, L.pw / 2, L.ph / 2, 0.5)
	end

	local off = cc.c4b(55, 55, 55, 255)
	new_button(root, L.btn[1], "< TRUOC", 16, Fu._page > 1 and cc.c4b(45, 70, 130, 255) or off)
	new_button(root, L.btn[2], "SAU >", 16, Fu._page < pages and cc.c4b(45, 70, 130, 255) or off)
	new_button(root, L.btn[3], "XOA CHON", 16, #Fu.sel > 0 and cc.c4b(150, 40, 40, 255) or off)
	new_button(root, L.btn[4], Fu.on and "TAT HOP THE" or "BAT HOP THE", 16,
		Fu.on and cc.c4b(120, 45, 45, 255) or cc.c4b(35, 105, 45, 255))
	new_button(root, L.btn[5], Fu.fx_on and "HIEU UNG: BAT" or "HIEU UNG: TAT", 13,
		Fu.fx_on and cc.c4b(35, 105, 45, 255) or cc.c4b(120, 45, 45, 255))

	scene:addChild(root, tonumber(Fu.host and Fu.host.z) or 1000011)
end

function Fu.open()
	Fu.load()
	Fu._open = true
	Fu._page = Fu._page or 1
	pcall(Fu.render)
end

function Fu.close()
	Fu._open = false
	pcall(Fu.render)
end

-- tra ve true neu cham da duoc bang chon xu ly (nuot cham)
function Fu.touch(loc)
	if not Fu._open then return false end
	local scene = host_scene()
	if scene == nil then return false end
	local root = scene:getChildByName(PANEL_NAME)
	if root == nil then
		pcall(Fu.render)
		root = scene:getChildByName(PANEL_NAME)
		if root == nil then Fu._open = false; return false end
	end
	local v = Fu._view
	if v == nil then return true end
	local L = v.L
	local p = root:convertToNodeSpace(loc)
	local lx, ly = p.x, p.y
	if lx < 0 or ly < 0 or lx > L.pw or ly > L.ph then
		Fu.close()
		return true
	end
	if in_rect(lx, ly, L.close) then Fu.close(); return true end
	if in_rect(lx, ly, L.btn[1]) then
		if Fu._page > 1 then Fu._page = Fu._page - 1; pcall(Fu.render) end
		return true
	elseif in_rect(lx, ly, L.btn[2]) then
		if Fu._page < v.pages then Fu._page = Fu._page + 1; pcall(Fu.render) end
		return true
	elseif in_rect(lx, ly, L.btn[3]) then
		Fu.clear()
		pcall(Fu.render)
		return true
	elseif in_rect(lx, ly, L.btn[4]) then
		Fu.toggle_on()
		pcall(Fu.render)
		return true
	elseif in_rect(lx, ly, L.btn[5]) then
		Fu.toggle_fx()
		pcall(Fu.render)
		return true
	end
	local first = (Fu._page - 1) * L.per
	for i = 1, L.per do
		local h = v.heroes[first + i]
		if h ~= nil and in_rect(lx, ly, L.rows[i]) then
			Fu.pick(h.id)
			pcall(Fu.render)
			return true
		end
	end
	return true
end

-- ------------------------------------------------------------------ khoi dong
function Fu.start()
	if Fu._started then return end
	Fu._started = true
	pcall(Fu.load)
	local okx, fx = pcall(require, Fu.fx_module)
	if okx and type(fx) == "table" then
		Fu.FX = fx
		pcall(fx.bind, Fu)
	else
		log("khong nap duoc FusionFx (chi con gop chi so, khong co than hop the):", fx)
	end
	pcall(Fu.attach)
	local sched = Fu.host and Fu.host.schedule
	if type(sched) == "function" then
		-- engine co the bi nap lai (app.reload) => gan lai moi giay (idempotent)
		sched(1.0, function()
			pcall(Fu.attach)
			return false
		end)
	end
	if type(sched) == "function" then
		-- [fu-2.4] giu chi so hop the tren ho so goc (LocalServer co the ghi lai ho so bat cu luc nao)
		sched(0.5, function()
			if Fu._live ~= nil or (Fu.live and Fu.on) then pcall(Fu.live_sync) end
			return false
		end)
	end
	log("da bat Fusion", Fu.version, "on=" .. tostring(Fu.on), "sel=" .. table.concat(Fu.sel, ","),
		"fx=" .. (type(Fu.FX) == "table" and tostring(Fu.FX.version) or "khong"), "fx_on=" .. tostring(Fu.fx_on),
		"gop_buff=" .. tostring(Fu.merge_buffs), "hook_buff=" .. tostring(Fu.buff_hooked))
end

-- ------------------------------------------------------------------ [fu-2.7] HOP THE NGAU NHIEN CHO BOT ARENA
-- LocalServer (AR.run_core) goi theo thu tu:  Fu.bot_plan(o)  ->  Fu.bot_fuse(ships)  ->  (init FightObject than chinh)  ->  Fu.bot_finish(lead_obj, ships, make).
Fu.bot = Fu.bot or {}
local BOT = Fu.bot
if BOT.enabled == nil then BOT.enabled = true end
if BOT.chance == nil then BOT.chance = 0.5 end   -- ti le bot Arena co hop the
if BOT.p3 == nil then BOT.p3 = 0.5 end           -- trong cac bot co hop the: ti le hop 3 tuong (con lai: 2 tuong)
if BOT.min_left == nil then BOT.min_left = 2 end -- so chien binh toi thieu con lai tren san sau khi hop (than hop the tinh la 1)
if BOT.keep_team == nil then BOT.keep_team = true end -- [fu-2.8] true = tuong phu cua bot VAN o lai doi hinh (khong bi xoa); false = bi loai nhu fu-2.7
if BOT.fx == nil then BOT.fx = true end          -- ve 2 than hop the cua bot (FusionFx); van tuan theo Fusion.fx_on

-- than hop the cua BOT dang trong tran: Fu.foe_battle[tostring(id doi tuong chien dau cua than chinh)] = { lead, twins = { ho so than 1, 2 }, foe = true }
-- FusionFx (fx-1.44) doc bang nay cho role phe dich (roleCamp == 1). Moi tran Arena moi (AR.run_core) bat dau bang Fu.foe_clear().
Fu.foe_battle = Fu.foe_battle or {}
Fu._foe_n = Fu._foe_n or 0

function Fu.foe_clear()
	Fu.foe_battle = {}
	Fu._foe_n = 0
end

local function bot_rng(seed)
	local s = (math.floor(seed) % 2147483629) + 1
	return function()
		s = (s * 48271) % 2147483629
		return s / 2147483629
	end
end

-- seed co dinh theo bot: hang + batch (o.okey) + id + doi hinh (tid cac tuong) => cung bot, cung ket qua
local function bot_seed(o)
	local key = tostring(o.okey or "") .. "|" .. tostring(o.rank or 0) .. "|" .. tostring(o.id or 0)
	local s = 7919
	for i = 1, #key do s = (s * 131 + string.byte(key, i)) % 2147483629 end
	for _, t in ipairs(o.team) do s = (s * 131 + (tonumber(t.tid) or 0)) % 2147483629 end
	return s
end

local function num_lenient(v)
	local x = tonumber(v)
	if x == nil then x = tonumber(string.match(tostring(v or ""), "^%-?%d+%.?%d*")) end
	if x == nil or x ~= x or x == math.huge or x == -math.huge then return nil end
	return x
end

-- san sang chua: Fusion da start (hook FightObject / BattleObject / FusionFx da gan). Goi lai Fu.attach (idempotent) cho chac.
function Fu.bot_ready()
	if not Fu.enabled or not BOT.enabled or not Fu._started then return false end
	pcall(Fu.attach)
	return true
end

-- Ke hoach hop the cho doi hinh bot o.team (o.team[1..n], 1-3 hang truoc, 4-6 hang sau).
-- Tra ve { skip = { [idx] = true }, lead_of = { [idx] = { lead = idx, partners = { idx, ... } } } } hoac nil (khong hop the).
-- Than chinh ngau nhien trong cac o 1..m; tuong phu = cac o CUOI (m+1..n) => o chien dau con lai luon 1..m (khong thung lo).
-- [fu-2.8] keep_team (mac dinh): skip rong => KHONG o nao bi loai, tuong phu van dung o cho cu va danh nhu binh thuong (chi la nguon cho than hop the).
function Fu.bot_plan(o)
	if not Fu.enabled or not BOT.enabled then return nil end
	if type(o) ~= "table" or type(o.team) ~= "table" then return nil end
	local n = #o.team
	local keep = (BOT.keep_team ~= false) -- [fu-2.8] tuong phu o lai doi hinh (khong skip)
	if n < (keep and 2 or 3) then return nil end
	local chance = tonumber(BOT.chance) or 0
	if chance <= 0 then return nil end
	local r = bot_rng(bot_seed(o))
	if r() >= chance then return nil end
	local size = (r() < (tonumber(BOT.p3) or 0.5)) and 3 or 2
	local lo, hi = math.max(2, math.floor(tonumber(Fu.min_n) or 2)), math.max(2, math.floor(tonumber(Fu.max_n) or 3))
	if size > hi then size = hi end
	if size < lo then size = lo end
	if keep then
		while size >= 2 and size > n do size = size - 1 end -- doi hinh nho (2 tuong) khong du cho 3 tuong hop the
	else
		local min_left = math.max(1, math.floor(tonumber(BOT.min_left) or 2))
		while size >= 2 and (n - (size - 1)) < min_left do size = size - 1 end
	end
	if size < 2 then return nil end
	local m = n - (size - 1)
	local lead = math.floor(r() * m) + 1
	if lead > m then lead = m end
	local partners, skip = {}, {}
	for k = m + 1, n do
		partners[#partners + 1] = k
		if not keep then skip[k] = true end -- fu-2.7: tuong phu bi loai khoi tran; fu-2.8 (keep_team): van danh binh thuong
	end
	return { skip = skip, lead_of = { [lead] = { lead = lead, partners = partners } }, size = size, keep = keep }
end

-- ho so hop the cua than chinh bot: ships[1] = than chinh, ships[2..] = tuong phu (ho so ship, da ban sao). Cung cong thuc voi nguoi choi (fused_record):
-- mau / cong / thu vat ly / thu phep / luc chien = tong * stat_factor(so tuong); toc do (ship_wisdom) = cao nhat. Khong dong vao ho so dau vao.
function Fu.bot_fuse(ships)
	if type(ships) ~= "table" or #ships < 2 or type(ships[1]) ~= "table" then return nil, "can it nhat 2 tuong" end
	local lead = ships[1]
	local f = {}
	for k, v in pairs(lead) do f[k] = v end -- sao chep nong: bang con dung chung (chi doc)
	local mult = stat_factor(#ships)
	for _, key in ipairs(STAT_SUM) do
		local total, any = 0, false
		for i = 1, #ships do
			local v = type(ships[i]) == "table" and num_lenient(ships[i][key]) or nil
			if v ~= nil then total = total + v; any = true end
		end
		if any then f[key] = like(lead[key], stat_round(total * mult)) end
	end
	local sp
	for i = 1, #ships do
		local v = type(ships[i]) == "table" and num_lenient(ships[i].ship_wisdom) or nil
		if v ~= nil and (sp == nil or v > sp) then sp = v end
	end
	if sp ~= nil then f.ship_wisdom = like(lead.ship_wisdom, sp) end
	return f
end

-- Goi SAU khi FightObject cua than chinh da initWithUserData (voi ho so da hop) VA da gan lead_obj.id.
-- make(ship) tao FightObject cho 1 tuong phu (cung o / phe / id nguoi choi voi than chinh). Viec: gop talent, gop buff ky nang (_fuBuff, ap o
-- BattleObject:initSkillAndTalentInfo), ghi ho so 2 than hop the vao Fu.foe_battle cho FusionFx. Tung buoc deu pcall; loi buoc nao thi bo buoc do.
function Fu.bot_finish(lead_obj, ships, make)
	if type(lead_obj) ~= "table" or type(ships) ~= "table" or type(make) ~= "function" then return false end
	local extras = {}
	for i = 2, #ships do
		local okm, po = pcall(make, ships[i])
		if okm and type(po) == "table" then
			extras[#extras + 1] = { po = po, rec = ships[i] }
		else
			log("bot: khong khoi tao duoc tuong phu", i, po)
		end
	end
	if #extras == 0 then return false end
	if Fu.merge_talents then
		local ok, err = pcall(merge_talents, lead_obj, extras)
		if not ok then log("bot: gop talent loi:", err) end
	end
	if Fu.merge_buffs then
		rawset(lead_obj, "_fuBuff", nil)
		local ok, plan, report = pcall(build_buff_plan, lead_obj, extras)
		if ok then
			if plan ~= nil then rawset(lead_obj, "_fuBuff", plan) end
			if Fu.buff_debug and type(report) == "table" then
				for _, line in ipairs(report) do log("bot buff", line) end
			end
		else
			log("bot: gop buff loi:", plan)
		end
	end
	local fx = Fu.FX
	if BOT.fx and Fu.fx_on ~= false and type(fx) == "table" and type(fx.profile) == "function" and lead_obj.id ~= nil then
		local twins, names = {}, {}
		for _, ex in ipairs(extras) do
			local nm = hero_name(ex.rec)
			local okp, prof = pcall(fx.profile, ex.po, ex.rec, nm)
			if okp and prof ~= nil then
				twins[#twins + 1] = prof
				names[#names + 1] = tostring(nm)
			end
		end
		if #twins > 0 then
			Fu._foe_n = (Fu._foe_n or 0) + 1
			if Fu._foe_n > 32 then Fu.foe_battle = {}; Fu._foe_n = 1 end -- an toan: khong de bang phinh to
			local key = tostring(lead_obj.id)
			Fu.foe_battle[key] = { lead = key, twins = twins, foe = true }
			if Fu.debug then log("bot hop the: than chinh id=" .. key .. " + " .. table.concat(names, ", ")) end
		end
	end
	return true
end

-- chi cho kiem thu
Fu._plan, Fu._apply, Fu._restore, Fu._fused_record = plan, apply, restore, fused_record
Fu._live_release = live_release
Fu._buff_plan, Fu._apply_buff_plan = build_buff_plan, apply_buff_plan -- [fu-2.6]

return Fu
