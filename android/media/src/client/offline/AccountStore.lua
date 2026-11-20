-- AccountStore.lua
-- Tai khoan OFFLINE: dang ky -> ghi vao 1 file (offline_accounts.txt); dang nhap -> doi chieu voi file do.
--   * Chua dang ky / sai ten / sai mat khau  => KHONG dang nhap duoc, bao "Sai tai khoan hoac mat khau".
--   * Moi tai khoan moi duoc cap 1 trang thai LocalServer (LS) mac dinh lay tu seed (offline_ls_default.txt).
--   * Moi su kien dang ky / dang nhap deu ghi them 1 dong vao offline_account_log.txt de de kiem tra.
--
-- Dinh dang offline_accounts.txt (moi dong 1 tai khoan, cac cot cach nhau bang TAB, ky tu dac biet duoc escape):
--   #OFFLINE_ACCOUNTS v1
--   <uid>\t<ten tai khoan>\t<mat khau>\t<thoi gian tao (epoch giay)>
--
-- Module nay KHONG khai bao local o cap file ngoai AS/H (OfflineMock da gan gan toi gioi han local cua Lua).

local AS = {}
AS.VERSION  = "acct-1.0"
AS.FILE     = "offline_accounts.txt"
AS.LOG_FILE = "offline_account_log.txt"
AS.UID_BASE = 910000000

AS.TOKEN_PREFIX = "@tk1:"

-- Ma loi tra ve client (am). Thong bao hien bang _ED.errorCodeInfo[so] (xem AS.err_reply).
AS.CODE = { bad_login = 9010, exists = 9011, bad_name = 9012, bad_pass = 9013, mismatch = 9014, io = 9015 }
AS.MSG = {
	[9010] = "Sai tài khoản hoặc mật khẩu!",
	[9011] = "Tài khoản đã tồn tại!",
	[9012] = "Tên tài khoản phải từ 3 đến 20 ký tự và không chứa khoảng trắng!",
	[9013] = "Mật khẩu phải từ 6 đến 31 ký tự!",
	[9014] = "Mật khẩu nhập lại không khớp!",
	[9015] = "Không ghi được file tài khoản!",
	[68]   = "Phiên đăng nhập đã hết hạn, hãy nhập lại mật khẩu!",
}
-- Ban khong dau, khong khoang trang: dung lam noi dung du phong (token thu 4 cua phan hoi loi).
AS.MSG_PLAIN = {
	[9010] = "Sai_tai_khoan_hoac_mat_khau!",
	[9011] = "Tai_khoan_da_ton_tai!",
	[9012] = "Ten_tai_khoan_phai_tu_3_den_20_ky_tu_va_khong_chua_khoang_trang!",
	[9013] = "Mat_khau_phai_tu_6_den_31_ky_tu!",
	[9014] = "Mat_khau_nhap_lai_khong_khop!",
	[9015] = "Khong_ghi_duoc_file_tai_khoan!",
	[68]   = "Phien_dang_nhap_het_han",
}

AS.NAME_MIN, AS.NAME_MAX = 3, 20
AS.PASS_MIN, AS.PASS_MAX = 6, 31

local H = {}

function AS.attach(host)
	H = host or {}
end

-- ---------------------------------------------------------------------------------------------
-- escape / unescape (giong OfflineMock)
-- ---------------------------------------------------------------------------------------------
local ESC   = { ["\\"] = "\\\\", ["\r"] = "\\r", ["\n"] = "\\n", ["\t"] = "\\t" }
local UNESC = { ["\\"] = "\\", r = "\r", n = "\n", t = "\t" }

function AS.esc(s)
	return (string.gsub(tostring(s or ""), "[\\\r\n\t]", ESC))
end

function AS.unesc(s)
	return (string.gsub(tostring(s or ""), "\\(.)", UNESC))
end

-- Khoa tra cuu tai khoan: khong phan biet hoa/thuong (file luu theo tai khoan cua LocalServer cung ha chu thuong,
-- neu khong "Abc" va "abc" se dung chung 1 file du lieu).
function AS.key(name)
	return string.lower(tostring(name or ""))
end

-- ---------------------------------------------------------------------------------------------
-- Doc / ghi file tai khoan
-- ---------------------------------------------------------------------------------------------
-- Tra ve { list = {{uid=,name=,pass=,created=}...}, by_key = {[key]=entry}, max_uid = n }
function AS.load()
	local db = { list = {}, by_key = {}, max_uid = AS.UID_BASE }
	if H.read_first == nil then return db end
	local ok, txt = pcall(H.read_first, AS.FILE)
	if not ok or type(txt) ~= "string" or txt == "" then return db end
	if string.sub(txt, -1) ~= "\n" then txt = txt .. "\n" end
	for line in string.gmatch(txt, "([^\n]*)\n") do
		line = (string.gsub(line, "\r$", ""))
		if line ~= "" and string.sub(line, 1, 1) ~= "#" then
			local uid, name, pass, created = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t?([^\t]*)$")
			uid = tonumber(uid)
			if uid ~= nil and name ~= nil and name ~= "" then
				local e = { uid = math.floor(uid), name = AS.unesc(name), pass = AS.unesc(pass), created = tonumber(created) or 0 }
				local k = AS.key(e.name)
				if db.by_key[k] == nil then
					db.list[#db.list + 1] = e
					db.by_key[k] = e
					if e.uid > db.max_uid then db.max_uid = e.uid end
				end
			end
		end
	end
	return db
end

function AS.event(text)
	if H.append_line == nil then return end
	pcall(H.append_line, AS.LOG_FILE, os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. tostring(text) .. "\n")
end

-- ---------------------------------------------------------------------------------------------
-- Token phien (client luu token thay vi mat khau: xem AccountSysManager D12).
-- Token 43 ky tu [A-Za-z0-9-_], tinh duoc tu (ten, mat khau) => doi mat khau thi token cu mat hieu luc.
-- (Khong phai mat ma hoc: chi can nhat quan trong may offline.)
-- ---------------------------------------------------------------------------------------------
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

function AS.token(name, pass)
	local src = AS.key(name) .. "\0" .. tostring(pass or "") .. "\0offline-acct-1"
	local h = 5381
	for i = 1, #src do
		h = (h * 33 + string.byte(src, i)) % 2147483629
	end
	local s = (h % 2147483629) + 1
	local out = {}
	for i = 1, 43 do
		s = (s * 48271) % 2147483629
		local idx = (math.floor(s / 7) % 64) + 1
		out[i] = string.sub(ALPHA, idx, idx)
	end
	return table.concat(out)
end

-- ---------------------------------------------------------------------------------------------
-- Dang ky
-- ---------------------------------------------------------------------------------------------
-- Tra ve ok(bool), entry_hoac_ma_loi
function AS.register(name, pass, confirm)
	name, pass = tostring(name or ""), tostring(pass or "")
	if confirm == nil then confirm = pass end
	local n = #name
	if n < AS.NAME_MIN or n > AS.NAME_MAX or string.find(name, "[%s%c]") ~= nil then
		AS.event("REGISTER FAIL bad_name user=" .. AS.esc(name))
		return false, AS.CODE.bad_name
	end
	if #pass < AS.PASS_MIN or #pass > AS.PASS_MAX then
		AS.event("REGISTER FAIL bad_pass user=" .. AS.esc(name))
		return false, AS.CODE.bad_pass
	end
	if tostring(confirm) ~= pass then
		AS.event("REGISTER FAIL mismatch user=" .. AS.esc(name))
		return false, AS.CODE.mismatch
	end
	local db = AS.load()
	if db.by_key[AS.key(name)] ~= nil then
		AS.event("REGISTER FAIL exists user=" .. AS.esc(name))
		return false, AS.CODE.exists
	end
	local e = { uid = db.max_uid + 1, name = name, pass = pass, created = os.time() }
	local line = e.uid .. "\t" .. AS.esc(e.name) .. "\t" .. AS.esc(e.pass) .. "\t" .. e.created .. "\n"
	local okw = false
	if H.append_line ~= nil then
		-- file moi: ghi dong tieu de truoc
		if #db.list == 0 then
			local okr, cur = pcall(H.read_first, AS.FILE)
			if not okr or cur == nil or cur == "" then pcall(H.append_line, AS.FILE, "#OFFLINE_ACCOUNTS v1\n") end
		end
		okw = H.append_line(AS.FILE, line) == true
	end
	if not okw then
		AS.event("REGISTER FAIL io user=" .. AS.esc(name))
		return false, AS.CODE.io
	end
	AS.event("REGISTER OK uid=" .. e.uid .. " user=" .. AS.esc(name))
	return true, e
end

-- ---------------------------------------------------------------------------------------------
-- Dang nhap: secret la mat khau go tay, hoac "@tk1:<token>" (dang nhap tu dong bang token da luu)
-- Tra ve ok(bool), entry_hoac_ma_loi, la_token(bool)
-- ---------------------------------------------------------------------------------------------
function AS.login(name, secret)
	name, secret = tostring(name or ""), tostring(secret or "")
	if name == "" or secret == "" then
		AS.event("LOGIN FAIL empty user=" .. AS.esc(name))
		return false, AS.CODE.bad_login, false
	end
	local db = AS.load()
	local e = db.by_key[AS.key(name)]
	if e == nil then
		AS.event("LOGIN FAIL unknown user=" .. AS.esc(name))
		return false, AS.CODE.bad_login, false
	end
	if string.sub(secret, 1, #AS.TOKEN_PREFIX) == AS.TOKEN_PREFIX then
		local tk = string.sub(secret, #AS.TOKEN_PREFIX + 1)
		if tk == AS.token(e.name, e.pass) then
			AS.event("LOGIN OK(token) uid=" .. e.uid .. " user=" .. AS.esc(e.name))
			return true, e, true
		end
		AS.event("LOGIN FAIL bad_token user=" .. AS.esc(name))
		return false, 68, true -- client xoa token cu va hien lai o nhap mat khau
	end
	if secret ~= e.pass then
		AS.event("LOGIN FAIL wrong_password user=" .. AS.esc(name))
		return false, AS.CODE.bad_login, false
	end
	AS.event("LOGIN OK uid=" .. e.uid .. " user=" .. AS.esc(e.name))
	return true, e, false
end

-- ---------------------------------------------------------------------------------------------
-- Tach tham so cua yeu cau: "<seq>\r\n<lenh>\r\n<p1>\r\n<p2>..."
-- ---------------------------------------------------------------------------------------------
function AS.params(req)
	local t = {}
	local s = tostring(req or "")
	local init = 1
	while true do
		local p = string.find(s, "\r\n", init, true)
		if p == nil then
			t[#t + 1] = string.sub(s, init)
			break
		end
		t[#t + 1] = string.sub(s, init, p - 1)
		init = p + 2
	end
	table.remove(t, 1) -- seq
	table.remove(t, 1) -- ten lenh
	return t
end

-- Phan hoi loi: "<seq>\r\n<lenh>\r\n-<ma>\r\n<noi dung>"
-- Noi dung hien cho nguoi choi lay tu _ED.errorCodeInfo[ma] (ProtocolErrorDialog) => dat ban co dau o do.
function AS.err_reply(seq, name, code)
	local ed = rawget(_G, "_ED")
	local msg = AS.MSG[code]
	if msg ~= nil and type(ed) == "table" then
		if type(ed.errorCodeInfo) ~= "table" then ed.errorCodeInfo = {} end
		ed.errorCodeInfo[tostring(code)] = msg
	end
	return tostring(seq) .. "\r\n" .. tostring(name) .. "\r\n-" .. tostring(code) .. "\r\n" .. (AS.MSG_PLAIN[code] or "Loi_tai_khoan")
end

local function pkg_of(given)
	if type(given) == "string" and given ~= "" and not string.find(given, "%s") then return given end
	local app = rawget(_G, "app")
	if type(app) == "table" and type(app.configJson) == "table" then
		local p = app.configJson.PackageName
		if type(p) == "string" and p ~= "" and not string.find(p, "%s") then return p end
	end
	return "com.offline.game"
end

-- ---------------------------------------------------------------------------------------------
-- Diem vao cho OfflineMock: tra ve chuoi phan hoi hoac nil (khong phai lenh tai khoan).
-- on_login(entry) duoc goi sau khi dang nhap thanh cong (OfflineMock dung de chuyen du lieu LS theo tai khoan).
-- on_register(entry) duoc goi sau khi dang ky thanh cong (cap LS mac dinh tu seed cho tai khoan moi).
-- ---------------------------------------------------------------------------------------------
function AS.handle(name, req, seq, on_login, on_register)
	if name == "platform_user_register" then
		local p = AS.params(req)
		local ok, r = AS.register(p[1], p[2], p[3])
		if not ok then return AS.err_reply(seq, name, r) end
		if on_register ~= nil then pcall(on_register, r) end
		return tostring(seq) .. "\r\n" .. name .. "\r\n0"
	elseif name == "platform_user_login" then
		local p = AS.params(req)
		local ok, r = AS.login(p[1], p[2])
		if not ok then return AS.err_reply(seq, name, r) end
		if on_login ~= nil then pcall(on_login, r) end
		-- 327: <ten> <token> <goi> <thoi gian tao>  (giong ban ghi that cua may chu)
		return table.concat({ tostring(seq), name, "0", "327", r.name, AS.token(r.name, r.pass), pkg_of(p[3]), tostring(r.created) }, "\r\n")
	end
	return nil
end

return AS
