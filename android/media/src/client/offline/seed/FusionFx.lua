-- FusionFx.lua  (fx-1.14)  di kem Fusion.lua (fu-2.2; van chay duoc voi fu-2.1)
-- HIEU UNG HOP THE (chi OFFLINE): tuong hop the = 1 chien binh "moi".
--
--   * Dung yen            : than chinh (tuong 1 trong bang HOP THE) + [fx-1.9] 2 "than dung yen" (tuong 2 va 3) hien / mo
--                           dan ben canh theo nhip video (FusionFx.idle = false => chi 1 con nhu fx-1.8).
--   * Khi than chinh DANH : 2 "than hop the" (model cua tuong 2 va tuong 3) hien ra ben canh, moi con tu chay
--                           dong tac danh, hieu ung chieu va am thanh theo CHIEU CUA CHINH TUONG DO
--                           (skill_mould -> skill_influence), cung danh voi con goc. Het don thi bien mat.
--
-- Day la lop TRINH CHIEU: chi them node con vao nhan vat (khong dong vao sat thuong / ket qua tran / du lieu luu).
-- Moi cho deu bao pcall: loi => tran danh nhu binh thuong (khong co than hop the).
--
-- Hook (idempotent):
--   FightRole:changeActtackToAttackBegan -> tao 2 than, chay dong tac danh + am thanh dau don
--   FightRole:executeAttackInfluence     -> ve hieu ung chieu (va hieu ung trung don + am thanh) cua 2 than
-- LUU Y: class() cua game SAO CHEP ham vao tung doi tuong luc new(), nen hook phai gan TRUOC khi tran tao vai.
--        Fusion.lua goi FusionFx.attach() luc dung tran (truoc khi hien tran) va moi giay.
--
-- Tinh chinh nhanh: FusionFx.offsets (vi tri 2 than, ty le theo be rong nhan vat), FusionFx.stagger (tre giua 2 than, giay),
--                   FusionFx.hit_fx / FusionFx.hit_sound (hieu ung / am thanh trung don cua than), FusionFx.max_life (giay),
--                   FusionFx.raise (nang diem phat hieu ung len, ty le theo chieu cao nhan vat; mac dinh 0 = chan nhan vat nhu engine).
--
-- [fx-1.2] SUA LOI "2 than hien ra nhung KHONG co hieu ung / am thanh chieu, khong cung luc voi than chinh":
--   1) Hieu ung nam duoi nhan vat: engine dat hieu ung o z = kZOrderInFightScene_Effect (2000000) nhung hang so do la
--      `local` trong FightRole.lua nen fx-1.1 doc ra nil va dung z = 100 (thap hon nhan vat dang danh, z = 10000)
--      => hieu ung van tao ra nhung bi che. Nay dung FX.effect_z = 2000000 (cung gia tri voi engine).
--   2) Engine goi executeAttackInfluence NGAY TRONG changeActtackToAttackBegan khi chieu khong co dong tac danh
--      (after_action <= 0) hoac khi muc tieu rong => luc do 2 than chua duoc tao nen hook khong ve gi.
--      Nay hook bat (hoan) cac lan goi do va ve NGAY SAU KHI 2 than xuat hien (cung 1 khung hinh voi con chinh).
--   3) fx-1.1 luon lay dong skill_influence DAU TIEN cua chieu. Nay lay dong DANH THAT (skill_category 0/1/34/35) va
--      theo GIAI DOAN: chieu nhieu giai doan thi giai doan n cua than chinh -> dong danh thu n cua tuong phu.
--   4) fx-1.1 khoa quyen ve hieu ung sau ~4.5-6 giay (chieu dai bi mat hieu ung). Nay quyen ve gan voi tung giai doan
--      (nhan dien bang du lieu chien dau cua than chinh), chi het han an toan sau FX.win_life giay.
--   5) Am thanh: phat TRUOC va TACH RIENG phan hinh (hinh loi van co tieng), theo dung quy tac engine:
--      posterior_lighting_sound_effect_id[n] cho hieu ung thu n (moi muc tieu 1 am voi kieu ve 0 / 2), thay vi chi am dau.
--   6) Ghi log chan doan: <thu muc Android/media cua game>/fusionfx_log.txt (tu cat khi qua lon).
--   7) Xep hang giai doan chi dem dong cua CUNG ke tan cong (don phoi hop / talent cua nguoi khac khong lam lech dong);
--      am thanh theo dung dieu kien project cua engine (danh sach am theo hieu ung / chi lay am dau tien).
--   FX.sync / FX.sync_lo / FX.sync_hi (khop nhip dong tac danh) giu nhu fx-1.1.
--
-- [fx-1.3] SUA LOI "log chi co dong 'da gan hook' roi im lang" (khong co than, khong co hieu ung, khong biet hook dung o dau):
--   1) app.load bi boc CHONG CHAT: LocalServer (INF.hook_load) va FusionFx moi giay deu thay ham app.load khong phai cua minh
--      => boc de len nhau vo han (moi giay them 1-2 lop). Nay nhan ra minh da nam trong chuoi boc (duyet upvalue bang
--      debug.getupvalue) nen chi boc 1 lan; khong co debug thi toi da 3 lan / tien trinh.
--   2) Them hook o muc class(): FightRole luon duoc boc TRUOC KHI new() sao chep ham, ke ca khi FightRole bi nap lai
--      (app.reload) hoac hook app.load bi roi mat. (class() cua game sao chep ham vao tung doi tuong luc new().)
--   3) Moi "cong" co the thoat im lang nay co dong log rieng "[cong] ..." kem ly do va id: began co duoc goi khong, Fusion.battle
--      co nil khong, than chinh khong khop (ghi ca brole._id / mould / head), armature nil ... (toi da FX.gate_max dong / ly do / tran).
--   4) Than chinh khop theo id; neu khong khop thi du phong theo (mouldId + head) cua than chinh (Fusion luu lead_mould / lead_head).
--   5) Fusion.battle bi xoa boi tran bot cua LocalServer (initBattleField lap lai, doi hinh rong) => Fusion khong xoa nua, va
--      FusionFx dung Fusion.last_battle neu Fusion.battle mat.

-- [fx-1.4] SUA LOI "log bao 'da ve hieu ung' cho ca 2 than nhung tren man hinh KHONG thay gi":
--   Nguyen nhan hay gap nhat (xem display.lua [FIX-DUNG-GAME]): file hieu ung effect/effice_<id>.json|.atlas cua tuong phu bi THIEU /
--   cat cut / thieu anh atlas => game am tham thay bang "spine gia" (node rong): createEffect van tra ve doi tuong, addChild van chay,
--   log van ghi "da ve" nhung KHONG co gi hien ra. fx-1.3 khong phan biet duoc.
--   1) Kiem tra file TRUOC khi ve (check_fx): json + atlas + anh trong atlas co that khong, game da danh dau hong chua.
--      Ket qua ghi vao log o dong "[fx-check]" ngay luc vao tran (moi chieu cua moi than) => biet chinh xac ID nao thieu.
--   2) Hieu ung RIENG cua than thieu / hong (hoac game thay bang spine gia) => ve THAY THE bang hieu ung tuong ung cua THAN CHINH
--      (file chac chan ve duoc, vi engine dang ve no cho than chinh) tai cho cua than do. Tat bang FusionFx.fallback_lead_fx = false.
--   3) Moi hieu ung ve ra deu ghi 1 dong log: dung hieu ung rieng hay thay the, toa do the gioi, TRONG / NGOAI man hinh, scale, z.
--   4) Khong tao thu hieu ung da biet thieu file (tranh game ghi them "file hong" vao danh sach loc tuong cua LocalServer).

-- [fx-1.5] Log fx-1.4: file hieu ung cua 2 than deu doc duoc, node la hieu ung that ("own"), nam TRONG man hinh, z = 2000000,
--   hien = true, nhung nguoi choi van khong thay hieu ung chieu => khong phai loi "file thieu" hay "sai toa do".
--   Nghi ngo 1: lop phu / hieu ung man hinh cua engine dung GLOBAL z = 2000000 (FightRole.lua dong 1769) => bi ve SAU (de len) hieu ung cua
--     than, vi hieu ung cua than chi co local z = 2000000 (global z = 0). Nghi ngo 2: [fx-check] canh bao "json co ve bi cut" o 307134 /
--     311614 / 311634 => spine doc DUOC nhung khong co hoat anh (khung bao 0x0).
--   1) Ep hieu ung len tren cung ngay sau khi addChild: setGlobalZOrder(FX.effect_z + FX.global_z_add) + setVisible(true) + setOpacity(255).
--      Tat bang FusionFx.global_z = false.
--   2) Them dong log "[probe]": 0.15s va 0.6s sau khi ve, ghi node con song khong, co cha khong, hien / opacity / chay, khung bao
--      (rong x cao), toa do the gioi, z va global z. Khung bao 0x0 => spine khong ve gi (file / hoat anh); khung bao lon, TRONG man hinh
--      ma van khong thay => bi lop khac che; "node da bi xoa" som => bi xoa truoc khi kip hien.
--      Toi da FX.probe_max (24) hieu ung moi lan chay; tat bang FusionFx.probe = false.
--   CHUA LAM: (a) cac dong chieu thu 2 tro di cua tuong phu khi tuong chinh it giai doan hon (vd Black Frieza chieu dac biet co 2 dong danh);
--     (b) man hinh toi + tia xanh cua chieu dac biet neu video tuong don le co. Luu y: forepart_lighting_effect_id chi duoc engine (landscape)
--     dung de phat am, khong ve hinh, nen khong thieu gi.
--
-- [fx-1.6] LAM XONG muc (a) "CHUA LAM" cua fx-1.5: cac DONG DANH THU 2 TRO DI cua tuong phu.
--   Van de: chieu cua tuong phu co NHIEU dong danh hon tuong chinh (vd Black Frieza chieu dac biet co 2 dong: log ghi "so dong danh 2",
--   con Goku Perfected Ultra Instinct "Silver Dragon Flash" chi 1 giai doan). fx-1.5 chi ve dong 1 cua tuong phu o giai doan 1 cua tuong
--   chinh => dong 2 (phan sau cua chieu Frieza) KHONG BAO GIO duoc ve.
--   1) lead_stage tra them TONG so giai doan cua tuong chinh. O giai doan CUOI, voi moi than con dong chua ve, ve noi tiep tung dong:
--      sinh lai than chay dong tac cua dong do -> cho het dong tac (doc thoi luong that, engine ve hieu ung luc KET THUC dong tac)
--      -> ve hieu ung + am thanh + hieu ung trung don cua dong do -> sang dong ke tiep. Dung lai neu tran ket thuc / bam Skip / cua so dong.
--   2) Log moi: "[fx-rows]" (ngay luc vao tran) liet ke TUNG dong danh cua 2 than (id hieu ung chinh / lop2 / day / kieu ve / hieu ung trung don)
--      => biet dong 2 co hieu ung RIENG hay khong; "[extra]" moi khi ve them 1 dong. Dong khong co hieu ung / am thanh nao thi bo qua.
--   3) Tinh chinh: FusionFx.extra_rows (false = tat), FusionFx.extra_max (so dong them toi da, mac dinh 4),
--      FusionFx.extra_gap (giay cho khi khong doc duoc thoi luong dong tac, mac dinh 1.0),
--      FusionFx.extra_model (false = khong cho than hien lai de danh dong them, chi ve hieu ung + am thanh).
--   4) Chieu danh NGAY (con chinh khong co dong tac): hieu ung dong 1 ve luc t = 0 nhung than van dang dien dong tac dong 1 =>
--      cho dong tac dong truoc dien XONG (toi da thoi luong dong tac + 1 giay) roi moi sinh than cho dong ke, khong cat ngang dong tac.

-- [fx-1.7] SUA LOI "hieu ung cua 2 than hop the khong hien, chi con hieu ung cua Goku":
--   Nguyen nhan: ngoai hieu ung o BANG CHIEU (posterior_lighting_effect_id), engine con sinh hieu ung tu SU KIEN KHUNG HINH nam
--   ngay trong animation cua nhan vat (FightRole onFrameEventRole): `union_<id1>,<id2>` => hieu ung sprite/effect_<id> gan len nhan vat;
--   `shake` / `white` / `black` => rung man hinh / nhay trang / nhay den. Con chinh duoc engine dang ky callback nen co du; make_node()
--   chi tao spine cho 2 than, KHONG dang ky callback nao => 2 than van chay dong tac nhung hieu ung di kem khong bao gio duoc sinh ra.
--   (Hieu ung o bang chieu cua 2 than vua nho vua hay chi de canh nhip - log fx-1.6 cho khung bao 3x2 - nen nhin nhu khong co gi.)
--   1) Moi than dang ky setFrameEventCallFunc. Su kien union_<id>: tao sprite/effect_<id> bang role:createEffect (giong engine) tren 1 NUT GOC
--      rieng cua than (cung vi tri / huong voi model than, song doc lap: model than bi go thi hieu ung van chay het).
--      Thieu file / spine gia => bo qua va ghi log, khong lam game ghi them "file hong".
--   2) Su kien toan canh shake / white / black tu animation cua than VA tu hieu ung chieu cua than => goi lai dung ham engine
--      (fight_scene_shake / fight_scene_blink_white / fight_scene_blink_black); 1 loai chi 1 lan / FX.scene_gap giay de khong
--      nhan doi voi con chinh. KHONG chuyen mcamera / scamera (gan voi con chinh) va hurt / next / after (sat thuong, chuyen luot).
--   3) Log moi: "[union-check]" (ngay luc vao tran: sprite/effect_<model+10/20/30> cua tung than co du file khong - engine tai truoc dung 3 id nay),
--      "[union]" (moi su kien khung hinh cua than va hieu ung tao ra / bo qua) => biet ngay animation cua than co ban su kien nao.
--   4) Tinh chinh: FusionFx.union_fx (false = tat), FusionFx.union_max (so hieu ung / than, mac dinh 16), FusionFx.union_check_files (false = khong
--      kiem tra file truoc khi tao), FusionFx.scene_events (false = tat; hoac { shake = true, white = false, black = false }),
--      FusionFx.scene_gap (giay, mac dinh 0.4), FusionFx.union_log_max (so dong log su kien / than, mac dinh 12).

-- [fx-1.8] SUA THEO VIDEO (1078432.mp4): "hop the cho giong video". Do tu video (15 fps, 133 khung):
--   1) Than hop the dung o 2 BEN con chinh: than trai ~ -95 px, than phai ~ +110 px so voi tam con chinh, chan cung 1 duong.
--      fx-1.7 de CA 2 than lech cung ben trai (-0.55) va chi khac nhau +-0.22 chieu cao => chong len nhau, khac video.
--      Nay FusionFx.offsets = { { -0.93, 0 }, { 1.08, 0 } } (ty le theo be rong o nhan vat ~102 don vi: log fx-1.7 cho 2 than
--      lech nhau 45 don vi khi dy = +-0.22, tuc 0.44 x be rong). Pixel video ~ don vi man hinh (video 1080 cao, man hinh game 1080).
--   2) Than KHONG bat / tat dot ngot: video cho thay than hien dan (0 -> ~90% trong ~2 khung = 0.13 s) va mo dan khi het don.
--      Nay hien dan (FusionFx.fade_in) va mo dan roi moi go (FusionFx.fade_out): mac dinh 0.13 giay x toc do tran, dat 0 = nhu fx-1.7.
--      Moi cho deu pcall: khong lam mo duoc (vd node khong ho tro opacity) => hien / go ngay nhu cu.
--   3) Nhip hien / mat cua video (than hien tre ~0.4 s, ca 2 cung mat gan nhu cung luc, chu ky ~1.56 s) trung voi co che FX.sync
--      (dong tac cua than ket thuc cung luc voi con chinh) da co tu fx-1.1 => khong sua.
--   Khong doi Fusion.lua: fu-2.1 van chay duoc voi fx-1.8 (log fx-1.7: 35/35 lan danh deu ve than; cac dong [cong] chi la tran khong hop the).

-- [fx-1.9] 2 THAN HOP THE DUNG YEN "nhu video" (1078432.mp4): khi con chinh dung yen, 2 than (model tuong 2 va 3) dung 2 BEN, nam SAU con chinh.
--   Do tu video (133 khung, 15 fps): 2 than KHONG luon hien ma hien / mo dan theo chu ky 1.552 giay (lap dung 5 lan, do lech 0.008 s):
--     than TRAI : hien dan ~0.18 s roi mo dan ~0.13 s;  than PHAI : hien dan ~0.17 s roi mo dan ~0.14 s; hai than lech pha (xem FX.idle_profile).
--   Cach lam: moi con chinh co them 2 node than dung yen (chay dong tac dung yen cua chinh model do; con chinh chay / lao toi / quay ve /
--   an mung thi chay cung). Do trong suot = pulse_alpha(than, dong ho) x cong (mo dan khi bat / tat), cap nhat moi khung hinh bang
--   scheduler cua cocos (KHONG dung action => khong xung dot voi stopAllActions cua engine). Khi 1 than DANH hien ra thi than dung yen
--   cung vi tri mo dan nhuong cho (nhin nhu 1 than chuyen tu dung yen sang danh); danh xong thi hien lai.
--   Con chinh chet / an / dang doi tuong / hop the bi tat => 2 than mo dan roi an. Khong sua than khi danh (fx-1.8 giu nguyen).
--   Hook them: FightRole:onInit -> FX.on_role_init (tao 2 than dung yen). Tinh chinh: FusionFx.idle (false = tat), FusionFx.idle_pulse
--   (false = luon hien, khong nhap nhay), FusionFx.idle_period / idle_phase / idle_profile (nhip), FusionFx.idle_fade, FusionFx.idle_resume,
--   FusionFx.idle_offsets (mac dinh = FusionFx.offsets), FusionFx.idle_mirror, FusionFx.idle_shadow. Log: dong "[idle]" trong fusionfx_log.txt.

-- [fx-1.10] 2 THAN DUNG YEN QUAY NGUOC HUONG "nhu video" (1078454.mp4, 1078432.mp4):
--   Trong video, 2 than dung SAU con chinh quay mat NGUOC huong voi con chinh (con chinh nhin sang phai, 2 than nhin sang trai).
--   Nguyen nhan: model goc cua nhan vat nhin sang TRAI; engine lat con chinh de nhin sang phai (FightRole.lua: armature:setScaleX(-1)
--   khi roleCamp == 0, ~dong 10385). fx-1.9 sao chep scaleX cua con chinh cho 2 than => 2 than cung nhin sang phai nhu con chinh.
--   Nay than dung yen dung scaleX = -(scaleX cua con chinh) => nhin sang trai nhu video (chu tren ao cung het bi lat guong).
--   Chi quay nguoc khi than dang o dong tac DUNG YEN (standby). Khi con chinh chay / lao toi / quay ve / an mung thi 2 than chay cung
--   huong con chinh (khong chay lui). Than khi DANH (spawn_twin) giu nguyen nhu fx-1.8 (cung huong con chinh, giong video).
--   Tinh chinh: FusionFx.idle_flip = true (mac dinh, quay nguoc) | false (cung huong con chinh nhu fx-1.9) | { true, false } (than 1 trai,
--   than 2 phai). Log: dong "[idle] huong than ..." trong fusionfx_log.txt (scaleX cua than va cua con chinh).

-- [fx-1.11] BO TRI RIENG KHI DUNG CHIEU NO (chieu dac biet): 1 than DUNG SAU HANG DICH quay mat ve phe minh, 1 than LUI RA SAU con chinh 1 doan.
--   Chi ap dung khi con chinh dung chieu no (role.skillQuality == 1); chieu thuong giu nguyen FX.offsets nhu fx-1.10.
--   * FX.rage_layout = false : tat, quay lai bo tri cu (2 than 2 ben con chinh).
--   * FX.rage_enemy_twin = 1 : than so may dung sau dich (1 = than trai / tuong 2 trong bang HOP THE; 2 = than phai; false = khong co).
--   * FX.rage_back_twin  = 2 : than so may lui ra sau con chinh (false = khong co).
--   * FX.rage_enemy_gap = 0.9 : cach dich xa nhat bay nhieu be rong nhan vat (tinh tu chan dich, ve phia sau dich).
--   * FX.rage_back_gap  = 1.6 : lui ra sau con chinh bay nhieu be rong nhan vat. FX.rage_back_dy = 0 : lech doc (ty le be rong).
--   * Than dung sau dich bi LAT HUONG (nhin ve phe minh), ke ca hieu ung chieu / union cua than do. Khong tim thay dich thi dung vi tri cu.
--   * [fx-1.11] 2 than DUNG YEN: luon hien, khong nhap nhay (CHI khi hop the 2 tuong = 1 than phu: FX.idle_pulse_single = false); hop the 3 tuong giu logic cu (nhap nhay theo video, FX.idle_pulse = true). Than 1 quay NGUOC (nhin ve phia sau), than 2 cung huong con chinh (nhin ve phia truoc) = FX.idle_flip { true, false }.
--   * [fx-1.11] CANH NHIP THEO DONG TAC DAI NHAT: tinh dong tac dai nhat T trong (con chinh, than 1, than 2); than ngan hon lam CHAM de ket thuc dung luc T
--     (truoc day chi khop theo con chinh). Con chinh do engine dieu khien nen khong bi lam cham. Neu T dai hon con chinh thi hieu ung chieu cua than
--     ve TRE den luc T (toi da FX.sync_fx_delay_max = 1.5 giay). Cau hinh: FX.sync_longest (false = khop theo con chinh nhu fx-1.10),
--     FX.sync_fx_delay (false = ve hieu ung ngay), FX.sync_lo (he so cham toi da, mac dinh 0.3 = cham toi da ~3.3 lan).
--   CHUA KIEM CHUNG trong game: thu tu ve (z-order) cua than dung sau dich so voi quan dich va huong bay cua chieu.

FusionFx = FusionFx or {}
local FX = FusionFx

local prev_version = FX.version -- [fx-1.8] module con song qua app.reload: neu la phien ban cu thi nap lai gia tri mac dinh moi
FX.version  = "fx-1.14"
FX.fu       = FX.fu or nil                  -- Fusion (Fusion.bind gan vao)
FX.stagger  = 0                             -- [fx-1.14] ca 3 nhan vat bat dau trong cung luot cap nhat
FX.sync_longest = false                    -- [fx-1.14] moc ket thuc la animation cua nhan vat chinh
FX.sync_fx_delay = false                   -- [fx-1.13] khong tre effect / am thanh cua than phu
FX.sync_fx_delay_max = 0
FX.sync_to_lead = true                  -- [fx-1.13] moc chinh la than goc
FX.sync = true                              -- dong bo thoi diem ket thuc animation cua 2 than theo than chinh
FX.sync_lo  = 0.05                          -- gioi han toc do rong de khop moc ket thuc
FX.sync_hi  = 20.0
FX.max_infl = 24                            -- toi da so lan ve hieu ung chieu trong 1 giai doan (don nhieu hit: moi hit 1 lan)
FX.max_life = 12                            -- an toan: MODEL than tu go sau bay nhieu giay (nhan toc do tran)
FX.win_life = 40                            -- an toan: quyen ve hieu ung cua 1 giai doan het han sau bay nhieu giay (nhan toc do tran)
FX.effect_z = 2000000                       -- = kZOrderInFightScene_Effect cua FightRole.lua (hang so `local` nen khong doc duoc)
FX.raise    = FX.raise or 0                 -- nang diem phat hieu ung (ty le theo chieu cao nhan vat); 0 = chan nhan vat nhu engine
if FX.hit_fx == nil then FX.hit_fx = true end
if FX.hit_sound == nil then FX.hit_sound = true end
if FX.log_file == nil then FX.log_file = true end
if FX.fallback_lead_fx == nil then FX.fallback_lead_fx = true end -- [fx-1.4] hieu ung rieng cua than thieu / hong => ve bang hieu ung tuong ung cua than chinh
FX.desc_max = FX.desc_max or 60                                    -- [fx-1.4] so dong log mo ta hieu ung toi da moi lan chay
if FX.global_z == nil then FX.global_z = true end                  -- [fx-1.5] ep hieu ung len tren cung (setGlobalZOrder)
FX.global_z_add = FX.global_z_add or 10                             -- [fx-1.5] global z cua hieu ung than = effect_z + so nay (cao hon lop phu engine, vi 2 nut cung global z ve theo thu tu tuy y)
if FX.probe == nil then FX.probe = true end                        -- [fx-1.5] ghi log [probe] sau khi ve hieu ung
FX.probe_max = FX.probe_max or 24                                  -- [fx-1.5] so hieu ung toi da duoc probe moi lan chay
if FX.extra_rows == nil then FX.extra_rows = true end               -- [fx-1.6] ve them cac dong danh thu 2 tro di cua tuong phu
FX.extra_max = FX.extra_max or 4                                     -- [fx-1.6] toi da so dong ve them / than / chieu
FX.extra_gap = FX.extra_gap or 1.0                                   -- [fx-1.6] giay (x toc do tran) cho truoc khi ve 1 dong them neu khong doc duoc thoi luong dong tac
if FX.extra_model == nil then FX.extra_model = true end             -- [fx-1.6] cho than hien lai de danh dong them (false = chi ve hieu ung + am thanh)
if FX.union_fx == nil then FX.union_fx = true end                   -- [fx-1.7] sinh hieu ung di kem dong tac (su kien union_<id>) cho 2 than
FX.union_max = FX.union_max or 16                                    -- [fx-1.7] toi da so hieu ung union / than / lan danh
if FX.union_check_files == nil then FX.union_check_files = true end -- [fx-1.7] kiem tra file sprite/effect_<id> truoc khi tao
FX.union_log_max = FX.union_log_max or 12                            -- [fx-1.7] so dong log su kien khung hinh toi da / than
if FX.scene_events == nil then FX.scene_events = true end           -- [fx-1.7] chuyen rung / nhay trang / nhay den cua than sang engine (false = tat)
FX.scene_gap = FX.scene_gap or 0.4                                   -- [fx-1.7] 1 loai su kien toan canh chi 1 lan / so giay nay (x toc do tran)
if FX.trace == nil then FX.trace = true end
FX.log_max  = FX.log_max or 1200             -- so dong log toi da moi lan chay
if prev_version ~= FX.version then FX.offsets = nil; FX.idle_profile = nil end
FX.offsets  = FX.offsets or { { -0.93, 0 }, { 1.08, 0 } } -- { dx, dy } theo be rong nhan vat. [fx-1.8] than 1 ben TRAI, than 2 ben PHAI (theo video)
if FX.rage_layout == nil then FX.rage_layout = true end             -- [fx-1.11]
if FX.rage_enemy_twin == nil then FX.rage_enemy_twin = 1 end        -- [fx-1.11] than dung sau dich (1 / 2 / false)
if FX.rage_back_twin == nil then FX.rage_back_twin = 2 end          -- [fx-1.11] than lui ra sau con chinh (1 / 2 / false)
FX.rage_enemy_gap = FX.rage_enemy_gap or 0.9                         -- [fx-1.11] be rong nhan vat
FX.rage_back_gap  = FX.rage_back_gap  or 1.6                         -- [fx-1.11] be rong nhan vat
FX.rage_back_dy   = FX.rage_back_dy   or 0                           -- [fx-1.11] ty le be rong
FX.fade_in  = FX.fade_in or 0.13            -- [fx-1.8] giay (x toc do tran) than hien dan len; 0 = hien ngay nhu fx-1.7
FX.fade_out = FX.fade_out or 0.13           -- [fx-1.8] giay (x toc do tran) than mo dan roi moi go; 0 = mat ngay nhu fx-1.7
if FX.idle == nil then FX.idle = true end                    -- [fx-1.9] 2 than hop the DUNG YEN canh con chinh (false = tat, chi con than khi danh nhu fx-1.8)
if FX.idle_pulse == nil then FX.idle_pulse = true end        -- [fx-1.9] hien / mo dan theo nhip video (false = luon hien). 3 tuong (2 than phu): giu nhu cu
if FX.idle_pulse_single == nil then FX.idle_pulse_single = false end -- [fx-1.11] CHE DO 2 TUONG (chi 1 than phu): true = nhap nhay, false (mac dinh) = luon hien
FX.idle_period  = FX.idle_period or 1.552                    -- [fx-1.9] chu ky 1 vong hien / mo (giay quy ve toc do 1x), do tu video
FX.idle_phase   = FX.idle_phase or 0.60                      -- [fx-1.9] pha luc bat dau (giay): 0.60 = giong doan dau video (than phai dang hien, than trai sap hien)
FX.idle_fade    = FX.idle_fade or 0.13                       -- [fx-1.9] giay (x toc do tran) hien / mo dan khi bat tat (con chinh chet, than danh nhuong cho ...)
FX.idle_resume  = FX.idle_resume or 0.15                     -- [fx-1.9] giay (x toc do tran) cho sau khi than danh bien mat roi than dung yen moi hien lai
FX.idle_log_max = FX.idle_log_max or 12                      -- [fx-1.9] so dong log [idle] toi da / lan dung than
if FX.idle_mirror == nil then FX.idle_mirror = true end      -- [fx-1.9] con chinh chay / lao toi / quay ve / an mung thi 2 than chay cung
if FX.idle_shadow == nil then FX.idle_shadow = true end      -- [fx-1.9] ve bong duoi chan 2 than
if FX.idle_flip == nil then FX.idle_flip = { true, false } end          -- [fx-1.10] than dung yen QUAY NGUOC huong voi con chinh (nhu video). true / false / { true, false }
FX.idle_profile = FX.idle_profile or {                       -- [fx-1.9] nhip hien / mo (giay trong chu ky; moc 0 = luc than 2 (phai) bat dau mo dan di)
	{ rise = 0.816, fall = 0.111, up = 0.18, down = 0.13 },    --   than 1 (TRAI): hien tam o 0.816 (mat 0.18 s), mo tam o 0.111 (mat 0.13 s)
	{ rise = 0.413, fall = 0.000, up = 0.17, down = 0.14 },    --   than 2 (PHAI): hien tam o 0.413 (mat 0.17 s), mo tam o 0.000 (mat 0.14 s)
}
FX._wrapped = FX._wrapped or setmetatable({}, { __mode = "k" })
FX._seen    = FX._seen or {}
FX._nseen   = FX._nseen or 0
FX._nlog    = FX._nlog or 0
FX._seq     = FX._seq or 0
FX.stats    = FX.stats or {}

-- ------------------------------------------------------------------ tien ich chung
local function G(name) return rawget(_G, name) end

local function bump(name, n)
	local s = FX.stats
	s[name] = (s[name] or 0) + (n or 1)
end

local function join(...)
	local t = {}
	for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
	return table.concat(t, " ")
end

-- ghi log ra file (an toan: loi => bo qua, co gioi han dong)
local function log_path()
	if FX._log_path ~= nil then return FX._log_path end
	local ok, w = pcall(function() return cc.FileUtils:getInstance():getWritablePath() end)
	if not (ok and type(w) == "string") then return nil end
	local uid, pkg = string.match(w, "^/data/user/(%d+)/([^/]+)/")
	if pkg == nil then
		pkg = string.match(w, "^/data/data/([^/]+)/")
		uid = "0"
	end
	if pkg == nil then return nil end
	local dir = "/storage/emulated/" .. uid .. "/Android/media/" .. pkg .. "/"
	pcall(function() cc.FileUtils:getInstance():createDirectory(dir) end)
	FX._log_path = dir .. "fusionfx_log.txt"
	return FX._log_path
end

local function flog(...)
	if FX.log_file == false then return end
	if FX._nlog >= FX.log_max then return end
	local path = log_path()
	if path == nil then return end
	if not FX._log_started then
		FX._log_started = true
		pcall(function() -- file qua lon thi lam rong
			local f = io.open(path, "rb")
			if f ~= nil then
				local size = f:seek("end")
				f:close()
				if type(size) == "number" and size > 200000 then
					local g = io.open(path, "wb")
					if g ~= nil then g:close() end
				end
			end
		end)
	end
	FX._nlog = FX._nlog + 1
	local msg = join(...)
	local ok = pcall(function()
		local f = io.open(path, "ab")
		if f == nil then error("khong mo duoc file log") end
		f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
		f:close()
	end)
	if not ok then FX._nlog = FX.log_max end -- loi ghi file: thoi, khong thu lai
end

-- vet dien bien (chi vao file log)
local function trace(...)
	if FX.trace == false then return end
	pcall(flog, ...)
end

-- [fx-1.3] ghi chan doan ra file log (Fusion.lua dung chung). Khong bao gio nem loi.
function FX.diag(...)
	pcall(flog, ...)
end

-- [fx-1.3] "cong" = cho hook co the thoat im lang. Moi ly do chi ghi toi da FX.gate_max lan moi tran (Fusion goi reset_gates khi
-- dung tran hop the moi) de log cho biet CHINH XAC hook dung o dau, thay vi chi co dong "da gan hook".
FX.gate_max = FX.gate_max or 3
FX._gate = FX._gate or {}
function FX.reset_gates() FX._gate = {} end
local function gate(reason, ...)
	local g = FX._gate
	if type(g) ~= "table" then g = {}; FX._gate = g end
	local n = (g[reason] or 0) + 1
	g[reason] = n
	bump("cong: " .. reason)
	if n <= (tonumber(FX.gate_max) or 3) then pcall(flog, "[cong]", reason, ...) end
end

-- thong bao hiem (loi / canh bao): file log + log cua OfflineMock; moi cau chi 1 lan
local function note(...)
	local s = "[FusionFx] " .. join(...)
	if FX._seen[s] then return end
	if FX._nseen >= 80 then return end -- tranh tran log
	FX._seen[s] = true
	FX._nseen = FX._nseen + 1
	pcall(flog, "!", s)
	local fu = FX.fu
	local f = type(fu) == "table" and type(fu.host) == "table" and fu.host.log or nil
	if type(f) == "function" then pcall(f, s) else print(s) end
end

local function split(s, sep)
	local out = {}
	s = tostring(s == nil and "" or s)
	local start = 1
	while true do
		local i, j = string.find(s, sep, start, true)
		if i == nil then
			out[#out + 1] = string.sub(s, start)
			break
		end
		out[#out + 1] = string.sub(s, start, i - 1)
		start = j + 1
	end
	return out
end

-- "12,13" -> { 12, 13 }
local function nums(s)
	local r = {}
	for _, v in ipairs(split(s, ",")) do
		local n = tonumber(v)
		if n ~= nil then r[#r + 1] = n end
	end
	return r
end

-- "1,2,0,-1" -> { 1, 2, 0, -1 } (giu nguyen vi tri; muc khong doc duoc = 0) - dung cho danh sach am thanh theo hieu ung thu n
local function sound_list(s)
	local r = {}
	for _, v in ipairs(split(s, ",")) do r[#r + 1] = tonumber(v) or 0 end
	return r
end

local function first_pos(list)
	for _, n in ipairs(list) do
		if n > 0 then return n end
	end
	return nil
end

local function enum_idx(name, default)
	local e = G("_enum_animation_l_frame_index")
	if type(e) == "table" and e[name] ~= nil then return e[name] end
	return default
end

local function time_speed(role)
	local s = tonumber(role and role.actionTimeSpeed) or tonumber(G("__fight_recorder_action_time_speed")) or 1
	if s ~= s or s <= 0 then s = 1 end
	return s
end

local function default_delete(a)
	pcall(function() a:removeFromParent(true) end)
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- phat 1 am thanh hieu ung bang ham cua game (tach rieng, loi => chi ghi log)
local function play_sound(id)
	id = tonumber(id)
	if id == nil or id <= 0 then return false end
	local pm = G("playEffectMusic")
	if type(pm) ~= "function" then
		note("thieu ham playEffectMusic")
		return false
	end
	local ok, err = pcall(pm, id)
	if not ok then
		note("phat tieng loi", id, err)
		return false
	end
	bump("sounds")
	return true
end

-- engine (executeEffectSkilling*): cac project nay doc posterior_lighting_sound_effect_id nhu DANH SACH (hieu ung thu n -> am thu n);
-- project khac chi phat am DAU TIEN moi lan ve. Giong dung dieu kien trong FightRole.lua.
local LIST_SOUND_PROJECTS = { "__lua_project_l_digital", "__lua_project_l_dragonball", "__lua_project_l_dragonball2",
	"__lua_project_l_pokemon", "__lua_project_onepiece", "__lua_project_l_naruto" }
local function sound_by_list()
	local pid = G("__lua_project_id")
	if pid == nil then return true end
	for _, name in ipairs(LIST_SOUND_PROJECTS) do
		local v = G(name)
		if v ~= nil and v == pid then return true end
	end
	return false
end

-- ------------------------------------------------------------------ du lieu chieu (skill_mould / skill_influence)
local ATTACK_CAT = { [0] = true, [1] = true, [34] = true, [35] = true } -- giong engine: dong tac danh that

local function is_attack_cat(c)
	c = tonumber(c)
	return c ~= nil and ATTACK_CAT[c] == true
end

local function influence_col(name)
	local t = G("skill_influence")
	if type(t) == "table" then return t[name] end
	return nil
end

local function cell(row, name)
	local c = influence_col(name)
	if c == nil or row == nil then return nil end
	local ok, v = pcall(function() return dms.atos(row, c) end)
	if ok then return v end
	return nil
end

-- hang skill_influence theo id
local function row_of(id)
	id = tonumber(id)
	if id == nil then return nil end
	local ok, row = pcall(function() return dms.element(dms["skill_influence"], id) end)
	if ok and row ~= nil then return row end
	return nil
end

-- cot health_affect cua skill_mould (chuoi id skill_influence, vd "1234" hoac "1234,1235|1236")
local function health_affect_of(skill)
	if type(skill) == "table" then
		if skill.healthAffect ~= nil then return skill.healthAffect end
		skill = skill.id
	end
	local n = tonumber(skill)
	if n == nil then return nil end
	local sm = G("skill_mould")
	if type(sm) ~= "table" or sm.health_affect == nil then return nil end
	local ok, v = pcall(function() return dms.atos(dms.element(dms["skill_mould"], n), sm.health_affect) end)
	if ok then return v end
	return nil
end

-- moi so duong trong chuoi -> danh sach id (giong BattleObject: "a,b|c" duoc dan phang)
local function ids_of(s)
	local r = {}
	if s == nil then return r end
	for d in string.gmatch(tostring(s), "%d+") do
		local n = tonumber(d)
		if n ~= nil and n > 0 then r[#r + 1] = n end
	end
	return r
end

-- cac dong skill_influence cua 1 chieu: tra ve danh sach DONG DANH (skill_category 0/1/34/35) theo thu tu giai doan,
-- moi phan tu { id, row, cat }. Chieu khong co dong danh nao thi dung dong dau (nhu fx-1.1).
local function attack_rows(skill)
	local all, atk = {}, {}
	for _, id in ipairs(ids_of(health_affect_of(skill))) do
		local row = row_of(id)
		if row ~= nil then
			local e = { id = id, row = row, cat = tonumber(cell(row, "skill_category")) }
			all[#all + 1] = e
			if is_attack_cat(e.cat) then atk[#atk + 1] = e end
		end
	end
	if #atk == 0 and #all > 0 then atk[1] = all[1] end
	return atk
end

-- dong cua giai doan k (k lon hon so dong thi lay dong cuoi)
local function pick_row(t, k)
	local rows = t.rows
	if type(rows) ~= "table" or #rows == 0 then return nil, nil end
	local i = tonumber(k) or 1
	if i < 1 then i = 1 end
	if i > #rows then i = #rows end
	return rows[i].row, rows[i].id
end

-- "a,b|c" -> main = a, second = b, bottom = c   (giong cach engine doc posterior_lighting_effect_id)
local function parse_effect_ids(s)
	local groups = split(s, "|")
	local g1 = nums(groups[1])
	local g2 = nums(groups[2])
	local r = {}
	if g1[1] ~= nil and g1[1] >= 0 then r.main = g1[1] end -- engine: posterior_lighting_effect_id >= 0
	if g1[2] ~= nil and g1[2] > 0 then r.second = g1[2] end
	if g2[1] ~= nil and g2[1] > 0 then r.bottom = g2[1] end
	return r
end

-- ------------------------------------------------------------------ [fx-1.4] kiem tra file hieu ung
-- Game doc hieu ung tu effect/effice_<id>.json + .atlas (+ anh .png ghi trong atlas). File THIEU / HONG => display.lua am tham thay bang
-- "spine gia" (node rong): createEffect van tra ve doi tuong, log van ghi "da ve" nhung man hinh KHONG co gi.
local function fx_paths(id)
	local base = "effect/effice_" .. tostring(id)
	return base .. ".json", base .. ".atlas"
end

local function file_exists(path)
	local ok, r = pcall(function() return cc.FileUtils:getInstance():isFileExist(path) end)
	return ok and r == true
end

-- doc file text (nil neu khong doc duoc hoac qua lon); tra them kich thuoc neu biet
local function file_text(path, max_bytes)
	local size
	local oks, n = pcall(function() return cc.FileUtils:getInstance():getFileSize(path) end)
	if oks and type(n) == "number" and n >= 0 then size = n end
	if size ~= nil and size > (max_bytes or 600000) then return nil, size end
	local ok, s = pcall(function() return cc.FileUtils:getInstance():getStringFromFile(path) end)
	if ok and type(s) == "string" then return s, size or #s end
	return nil, size
end

-- ket qua { ok = true | false | nil, why = "...", warn = nil | "..." }; luu cache theo id.
--   ok == false : CHAC CHAN loi (thieu json / atlas / anh atlas, hoac game da danh dau hong) => khong tao hieu ung nay
--   ok == nil   : khong kiem tra duoc (khong phai che do spine, loi doc file ...)
--   warn        : json nhin co ve cut cut (chi canh bao, van thu tao: neu game that su khong doc duoc thi no se tra spine gia)
local function check_fx(id)
	local key = tostring(id)
	local cache = FX._fxcheck
	if type(cache) ~= "table" then cache = {}; FX._fxcheck = cache end
	local c = cache[key]
	if c ~= nil then return c end
	c = { ok = true, why = "ok" }
	cache[key] = c
	if G("animationMode") ~= 1 then
		c.ok, c.why = nil, "khong phai che do spine"
		return c
	end
	local jp, ap = fx_paths(id)
	local okc, errc = pcall(function()
		local spt = G("sp")
		local bad = type(spt) == "table" and rawget(spt, "zz_bad") or nil
		if type(bad) == "table" and bad[jp .. "|" .. ap] then
			c.ok, c.why = false, "game da danh dau file HONG (dung spine gia)"
			return
		end
		if not file_exists(jp) then c.ok, c.why = false, "thieu " .. jp; return end
		if not file_exists(ap) then c.ok, c.why = false, "thieu " .. ap; return end
		local atlas = file_text(ap, 200000)
		if atlas ~= nil then
			if #atlas < 8 then c.ok, c.why = false, "atlas rong " .. ap; return end
			local dir = string.match(ap, "^(.*/)") or ""
			local lines = {}
			for line in string.gmatch(atlas, "[^\r\n]+") do lines[#lines + 1] = line end
			local pages = 0
			for i = 1, #lines - 1 do
				-- trang anh = dong sat le trai, ten co duoi .png/.jpg VA dong ke tiep la "size: ..." (ten vung anh thi khong co dong size)
				local nm = string.match(lines[i], "^([^%s:][^:]-%.[Pp][Nn][Gg])%s*$")
					or string.match(lines[i], "^([^%s:][^:]-%.[Jj][Pp][Ee]?[Gg])%s*$")
				if nm ~= nil and string.match(lines[i + 1], "^%s*size%s*:") then
					pages = pages + 1
					if not file_exists(dir .. nm) then c.ok, c.why = false, "thieu anh atlas " .. dir .. nm; return end
					if pages >= 4 then break end
				end
			end
		end
		local js, size = file_text(jp, 600000)
		if js ~= nil then
			if string.sub(js, 1, 3) == "\239\187\191" then js = string.sub(js, 4) end
			if string.find(js, "^%s*$") then c.ok, c.why = false, "json rong " .. jp; return end -- [fx-1.4] file rong => game se dung spine gia
			local head = string.match(js, "^%s*(.)")
			local tail = string.match(string.sub(js, -64), "(.)%s*$")
			local _, o = string.gsub(js, "{", "")
			local _, cl = string.gsub(js, "}", "")
			if head ~= "{" or tail ~= "}" or o ~= cl then
				c.warn = "json co ve bi cut (dau=" .. tostring(head) .. " cuoi=" .. tostring(tail) .. " { " .. tostring(o) .. " } " .. tostring(cl) .. ")"
			elseif not string.find(js, '"animations"', 1, true) then
				c.warn = 'json khong co muc "animations"'
			end
		elseif size ~= nil and size <= 0 then
			c.ok, c.why = false, "json rong " .. jp
		end
	end)
	if not okc then c.ok, c.why = nil, "khong kiem tra duoc: " .. tostring(errc) end
	return c
end

local function fx_state_text(id)
	local c = check_fx(id)
	local s = tostring(id) .. "="
	if c.ok == false then
		s = s .. "LOI(" .. tostring(c.why) .. ")"
	elseif c.ok == nil then
		s = s .. "?(" .. tostring(c.why) .. ")"
	else
		s = s .. "ok"
	end
	if c.warn ~= nil then s = s .. " [canh bao: " .. c.warn .. "]" end
	return s
end

-- [fx-1.6] mo ta ngan hieu ung cua 1 dong skill_influence: "chinh 311634 lop2 1311634 day - kieu 1 trung -"
local function row_fx_text(row)
	if row == nil then return "-" end
	local ids = parse_effect_ids(cell(row, "posterior_lighting_effect_id"))
	local method = tonumber(cell(row, "lighting_effect_draw_method"))
	local bear = nums(cell(row, "bear_lighting_effect_id"))[1]
	if bear ~= nil and bear < 0 then bear = nil end
	return join("chinh", ids.main or "-", "lop2", ids.second or "-", "day", ids.bottom or "-",
		"kieu", method or "?", "trung", bear or "-")
end

-- [fx-1.6] dong nay co gi de ve khong (hieu ung chinh / hieu ung trung don / am thanh)? Khong => bo qua, khong sinh than vo ich.
local function row_has_fx(row)
	if row == nil then return false end
	local ids = parse_effect_ids(cell(row, "posterior_lighting_effect_id"))
	if ids.main ~= nil then return true end
	local bear = nums(cell(row, "bear_lighting_effect_id"))[1]
	if bear ~= nil and bear > 0 then return true end
	if first_pos(sound_list(cell(row, "posterior_lighting_sound_effect_id"))) ~= nil then return true end
	if first_pos(nums(cell(row, "bear_sound_effect_id"))) ~= nil then return true end
	return false
end

-- bao cao 1 dong / chieu: file hieu ung cua than co day du khong (ghi vao fusionfx_log.txt ngay luc vao tran; khong lap lai neu giong het)
local function report_profile(prof)
	for _, which in ipairs({ "common", "special" }) do
		local skill = prof[which]
		if skill ~= nil then
			local parts, seen = {}, {}
			local rows = attack_rows(skill)
			for _, e in ipairs(rows) do
				local ids = parse_effect_ids(cell(e.row, "posterior_lighting_effect_id"))
				for _, k in ipairs({ "main", "second", "bottom" }) do
					local id = ids[k]
					if id ~= nil and not seen[id] then
						seen[id] = true
						parts[#parts + 1] = k .. " " .. fx_state_text(id)
					end
				end
			end
			local text = join("[fx-check] than", tostring(prof.name or "?"), "model", prof.head,
				which == "special" and "chieu dac biet:" or "chieu thuong:",
				#parts > 0 and table.concat(parts, "; ") or "(khong co hieu ung)")
			local rep = FX._reported
			if type(rep) ~= "table" then rep = {}; FX._reported = rep end
			local key = tostring(prof.head) .. which
			if rep[key] ~= text then
				rep[key] = text
				trace(text)
			end
			-- [fx-1.6] TUNG dong danh rieng (khong gop trung id): dong nao co hieu ung nao
			local rparts = {}
			for i, e in ipairs(rows) do
				rparts[#rparts + 1] = "dong " .. i .. " (" .. tostring(e.id) .. "): " .. row_fx_text(e.row)
			end
			local rtext = join("[fx-rows] than", tostring(prof.name or "?"), "model", prof.head,
				which == "special" and "chieu dac biet:" or "chieu thuong:",
				#rparts > 0 and table.concat(rparts, " | ") or "(khong co dong danh)")
			local rkey = key .. "#rows"
			if rep[rkey] ~= rtext then
				rep[rkey] = rtext
				trace(rtext)
			end
		end
	end
	-- [fx-1.7] hieu ung di kem dong tac (su kien union_<id> => sprite/effect_<id>): engine tai truoc dung model+10 / +20 / +30
	-- (FightRole:loadStartEffect). Thieu file thi 2 than khong the co hieu ung di kem, du da dang ky su kien.
	local head = tonumber(prof.head)
	if head ~= nil then
		local uparts = {}
		for i = 1, 3 do
			local id = string.format("%.0f", head + 10 * i)
			local base = "sprite/effect_" .. id
			local st
			if not file_exists(base .. ".json") then st = "khong co"
			elseif not file_exists(base .. ".atlas") then st = "THIEU atlas"
			else st = "co" end
			uparts[#uparts + 1] = id .. "=" .. st
		end
		local utext = join("[union-check] than", tostring(prof.name or "?"), "model", prof.head,
			"hieu ung di kem dong tac (sprite/effect_<model+10/20/30>):", table.concat(uparts, "; "))
		local urep = FX._reported
		if type(urep) ~= "table" then urep = {}; FX._reported = urep end
		local ukey = tostring(prof.head) .. "#union"
		if urep[ukey] ~= utext then
			urep[ukey] = utext
			trace(utext)
		end
	end
end

local NON_ATTACK = {
	"animation_normal_be_attaked", "animation_normal_conversely", "animation_vertical_floated",
	"animation_diagonal_floated", "animation_miss_action", "animation_dizziness", "animation_conversely",
	"animation_death", "animation_conversely_get_up", "animation_win_action", "animation_win_on_action",
	"animation_conversely_death", "animation_new_skill_29_daodi", "animation_new_skill_30_dingdian",
	"animation_new_skill_31_xia",
}

-- chi so dong tac danh cua than (giong FightRole:skillActionIndex, camp 0 = cot dau)
local function action_index(sie, special, camp, names)
	local fallback = special and enum_idx("animation_power_skill_attacking", 15) or enum_idx("animation_skill_attacking", 14)
	local vals = split(cell(sie, "after_action"), ",")
	local idx = tonumber(vals[(tonumber(camp) or 0) + 1]) or tonumber(vals[1])
	if idx == nil or idx ~= idx or idx <= 0 or idx ~= math.floor(idx) then idx = fallback end
	for _, nm in ipairs(NON_ATTACK) do
		if enum_idx(nm, -999) == idx then idx = fallback; break end
	end
	if type(names) == "table" and #names > 0 and idx >= #names then
		idx = fallback
		if idx >= #names then idx = 0 end
	end
	return idx
end

-- ------------------------------------------------------------------ ho so than hop the (Fusion goi luc dung tran)
-- po = FightObject cua tuong 2 / 3 (da initWithUserData): lay model + chieu thuong + chieu dac biet
function FX.profile(po, rec, name)
	if type(po) ~= "table" then return nil end
	local head = tostring(po.picIndex == nil and "" or po.picIndex)
	if head == "" or head == "0" or head == "nil" then return nil end
	local prof = {
		head = head,
		common = po.commonSkill,
		special = po.specialSkill,
		name = name,
		ship_id = rec and tostring(rec.ship_id) or nil,
	}
	pcall(report_profile, prof) -- [fx-1.4] ghi log "[fx-check]": file hieu ung cua than nay co day du khong
	return prof
end

-- ------------------------------------------------------------------ nhan dien than chinh khi trinh chieu
-- [fx-1.3] tra ve b, hoac nil + ly do. Uu tien fu.battle; neu bi xoa / rong thi dung ban sao tran that gan nhat (fu.last_battle),
-- mien la van dung than chinh dang chon (fu.sel[1]).
local function usable(b, fu)
	if type(b) ~= "table" or type(b.twins) ~= "table" or #b.twins == 0 then return false end
	local sel1 = type(fu.sel) == "table" and fu.sel[1] or nil
	return sel1 ~= nil and tostring(sel1) == tostring(b.lead)
end

local function battle_info()
	local fu = FX.fu
	if type(fu) ~= "table" then return nil, "FX.fu = nil (chua noi voi Fusion)" end
	if not fu.enabled then return nil, "Fusion.enabled = false" end
	if not fu.on then return nil, "HOP THE dang TAT" end
	if not fu.fx_on then return nil, "HIEU UNG dang TAT" end
	local b = fu.battle
	if usable(b, fu) then return b end
	local lb = fu.last_battle
	if lb ~= b and usable(lb, fu) then
		bump("dung ban sao last_battle")
		return lb
	end
	if b == nil and lb == nil then return nil, "Fusion.battle = nil (chua co tran hop the nao, hoac bi xoa)" end
	local ref = b or lb
	if type(ref) == "table" and (type(ref.twins) ~= "table" or #ref.twins == 0) then
		return nil, "khong co than hop the (twins rong)"
	end
	return nil, "than chinh da doi (sel[1]=" .. tostring(type(fu.sel) == "table" and fu.sel[1] or nil) .. ", tran=" .. tostring(ref and ref.lead) .. ")"
end

local function role_brole(role)
	local br = role._brole or role._info
	if type(br) == "table" then return br end
	return nil
end

local function role_id(role)
	local br = role_brole(role)
	if br == nil then return nil end
	return br._id
end

-- tra ve true + cach khop, hoac false + ly do (co id / mould / head de doi chieu trong log)
local function is_lead(role, b)
	if tonumber(role.roleCamp) ~= 0 then return false, "khong phai phe ta" end
	local br = role_brole(role)
	if br == nil then return false, "role khong co _brole/_info" end
	local id = br._id
	if id ~= nil and tostring(id) == tostring(b.lead) then return true, "id" end
	local ni, nl = tonumber(id), tonumber(b.lead)
	if ni ~= nil and nl ~= nil and ni == nl then return true, "id(so)" end
	if b.lead_mould ~= nil and b.lead_head ~= nil
		and tostring(br._mouldId) == tostring(b.lead_mould) and tostring(br._head) == tostring(b.lead_head) then
		return true, "mould+head"
	end
	return false, "brole._id=" .. tostring(id) .. " mould=" .. tostring(br._mouldId) .. " head=" .. tostring(br._head)
		.. " | than chinh id=" .. tostring(b.lead) .. " mould=" .. tostring(b.lead_mould) .. " head=" .. tostring(b.lead_head)
end

-- du lieu chien dau cua giai doan hien tai (engine dat vao current_fight_data_attacker truoc khi goi began / influence)
local function stage_data(role)
	return role.current_fight_data_attacker or role.current_fight_data
end

-- giai doan (thu tu trong cac dong DANH cua chieu) cua `data` VA tong so giai doan cua chieu (cung ke tan cong); nil neu khong doc duoc
-- [fx-1.6] tra them gia tri thu 2 = tong so dong DANH cua tuong chinh trong chieu nay (de biet dau la giai doan CUOI)
local function lead_stage(role, data)
	data = data or stage_data(role)
	if type(data) ~= "table" then return nil end
	local cur, att = data.__skf, data.__attData
	if cur == nil or type(att) ~= "table" or type(att.skillInfluences) ~= "table" then return nil end
	local n = tonumber(att.skillInfluenceCount) or #att.skillInfluences
	local rank, total, found, by_id = 0, 0, nil, nil
	for j = 1, n do
		local s = att.skillInfluences[j]
		if s ~= nil then
			-- chi dem dong cua CUNG ke tan cong (don phoi hop / talent cua nguoi khac khong lam lech giai doan)
			local mine = (s == cur) or (tostring(s.attackerType) == tostring(cur.attackerType)
				and tostring(s.attackerPos) == tostring(cur.attackerPos))
			if mine then
				local row = row_of(s.skillInfluenceId)
				if row ~= nil and is_attack_cat(cell(row, "skill_category")) then
					rank = rank + 1
					total = total + 1
				end
			end
			if found == nil and s == cur then found = rank > 0 and rank or 1 end
			if by_id == nil and tostring(s.skillInfluenceId) == tostring(cur.skillInfluenceId) then
				by_id = rank > 0 and rank or 1
			end
		end
	end
	local stage = found or by_id
	if stage == nil then return nil end
	if total < stage then total = stage end
	return stage, total
end

local function defenders_of(role, data)
	local list = {}
	local dl = data and data.__defenderList
	if type(dl) == "table" then
		for _, v in pairs(dl) do
			if v ~= nil and v ~= role and v.parent ~= nil then list[#list + 1] = v end
		end
	end
	return list
end

-- ------------------------------------------------------------------ than hop the (node phu)
-- [fx-1.8] than hien dan len (khong bat ngay): opacity 0 -> 255 trong FX.fade_in giay (x toc do tran). Loi => hien ngay.
local function fade_in_node(role, node)
	local d = (tonumber(FX.fade_in) or 0) * time_speed(role)
	if node == nil or d <= 0.01 or FX._no_fade then return end
	pcall(function() node:setCascadeOpacityEnabled(true) end)
	local ok = pcall(function()
		node:setOpacity(0)
		node:runAction(cc.FadeTo:create(d, 255))
	end)
	if not ok then pcall(function() node:setOpacity(255) end) end
end

-- t.done = MODEL than da bi go. t.fx_done = da ve hieu ung chieu (hoac khong co gi de ve).
-- Hai viec TACH ROI: than bi go som / khong tao duoc model thi hieu ung + am thanh cua tuong do van ve du.
-- instant = true: go ngay (khong mo dan). Than chua kip hien (t.started ~= true) cung go ngay.
local function kill_twin(t, instant)
	if t.done then return end
	t.done = true
	local node = t.node
	if node == nil then return end
	pcall(function() node:stopAllActions() end)
	local d = (tonumber(FX.fade_out) or 0) * (t.sp or 1)
	if instant or t.started ~= true or d <= 0.01 then
		pcall(function() node:removeFromParent(true) end)
		return
	end
	-- [fx-1.8] mo dan roi moi go (video: than mat dan trong ~2 khung)
	local ok = pcall(function()
		node:runAction(cc.Sequence:create({
			cc.FadeTo:create(d, 0),
			cc.CallFunc:create(function() pcall(function() node:removeFromParent(true) end) end),
		}))
	end)
	if not ok then pcall(function() node:removeFromParent(true) end) end
end

-- than chi bien mat khi: dong tac danh da xong VA (hieu ung chieu da ve HOAC than khong co hieu ung)
local function maybe_finish(t)
	if t.done then return end
	if t.anim_done and (t.fx_done or t.no_fx) then kill_twin(t) end
end

-- "cua so" = 1 giai doan danh cua than chinh (1 lan engine goi changeActtackToAttackBegan cho 1 dong skill_influence)
local function close_window(w)
	if w == nil or w.closed then return end
	w.closed = true
	if type(w.twins) == "table" then
		for _, t in ipairs(w.twins) do
			t.fx_done = true
			kill_twin(t)
		end
	end
	if type(w.extras) == "table" then -- [fx-1.6] than cua cac dong ve them
		for _, t in ipairs(w.extras) do
			t.fx_done = true
			kill_twin(t)
		end
	end
end

local function drop_window(role)
	local w = role._fx_win
	role._fx_win = nil
	close_window(w)
end

-- tao node nhan vat (spine hoac armature) giong FightRole:onInit
local function make_node(head)
	local node
	if G("animationMode") == 1 then
		local names = G("spineAnimations")
		if type(names) ~= "table" then return nil, "thieu spineAnimations" end
		node = sp.spine_sprite(nil, head, names[enum_idx("animation_standby", 0) + 1], true, nil, nil, nil)
		if node == nil then return nil, "khong tao duoc spine " .. head end
		node.animationNameList = names
		sp.initArmature(node, false)
	else
		pcall(function()
			ccs.ArmatureDataManager:getInstance():addArmatureFileInfo("sprite/spirte_" .. head .. ".ExportJson")
		end)
		node = ccs.Armature:create("spirte_" .. head)
		if node == nil then return nil, "khong tao duoc armature " .. head end
	end
	return node
end

local function play(node, idx)
	return pcall(function() node:getAnimation():playWithIndex(idx) end)
end

-- thoi luong dong tac idx (giay o toc do 1x), tinh nhu FightRole:getAnimationDuration cua engine
-- (spine: frame / 30; armature: (frame - 1) / 60). Tra nil neu khong doc duoc.
local function anim_seconds(node, idx)
	if node == nil or idx == nil then return nil end
	local ok, frames = pcall(function() return node:getAnimation():getAnimationDuration(idx) end)
	if not (ok and type(frames) == "number") then
		ok, frames = pcall(function() return node:getAnimationDuration(idx) end) -- du phong
	end
	if not (ok and type(frames) == "number") then return nil end
	local sec
	if G("animationMode") == 1 then sec = frames / 30 else sec = (frames - 1) / 60 end
	if sec ~= sec or sec <= 0 then return nil end
	return sec
end

-- thoi luong THAT (giay) dong tac danh hien tai cua con chinh; nil neu khong co dong tac (danh ngay)
local function lead_attack_seconds(role)
	local a = role.armature
	if a == nil then return nil end
	local idx = tonumber(a._actionIndex)
	if idx == nil or idx <= 0 then return nil end
	local sec = anim_seconds(a, idx)
	if sec == nil then return nil end
	return sec * time_speed(role)
end

-- ------------------------------------------------------------------ [fx-1.7] su kien khung hinh cua than hop the
-- Engine (FightRole onFrameEventRole) sinh them hieu ung tu SU KIEN KHUNG HINH trong animation cua nhan vat:
--   union_<id1>,<id2> => sprite/effect_<id> gan len nhan vat;  shake / white / black => rung / nhay trang / nhay den.
-- Con chinh duoc engine dang ky callback; make_node() chi tao spine => 2 than khong co callback => mat het hieu ung di kem.
local SCENE_FN = { shake = "fight_scene_shake", white = "fight_scene_blink_white", black = "fight_scene_blink_black" }

local function skip_fighting()
	local fr = G("FightRole")
	return fr ~= nil and fr.__skeep_fighting == true
end

-- chuyen 1 su kien toan canh (rung / nhay trang / nhay den) cua than hoac hieu ung cua than sang engine.
-- 1 loai su kien chi 1 lan trong FX.scene_gap giay (con chinh + 2 than + hieu ung cua ho hay ban cung luc).
-- KHONG chuyen mcamera / scamera (gan voi con chinh) va hurt / next / after (sat thuong, chuyen luot).
local function scene_forward(role, token, src)
	local allow = FX.scene_events
	if allow == false then return false end
	if type(allow) == "table" and allow[token] == false then return false end
	local fn = SCENE_FN[token]
	if fn == nil then return false end
	local sm = G("state_machine")
	if type(sm) ~= "table" or type(sm.excute) ~= "function" then return false end
	local now = os.clock()
	local last = FX._scene_last
	if type(last) ~= "table" then last = {}; FX._scene_last = last end
	local gap = (tonumber(FX.scene_gap) or 0.4) * time_speed(role)
	if last[token] ~= nil and (now - last[token]) < gap then
		bump("scene bo qua (trung)")
		return false
	end
	last[token] = now
	local ok, err = pcall(sm.excute, fn, 0, nil)
	if not ok then
		note("su kien toan canh", token, "loi:", tostring(err))
		return false
	end
	bump("scene " .. token)
	trace("  [union] su kien toan canh", token, "tu", tostring(src or "?"), "=> engine", fn)
	return true
end

-- id hop le + file sprite/effect_<id>.json|.atlas co that khong. Tra id dang chuoi, hoac nil + ly do.
local function union_files(id)
	local n = tonumber(id)
	if n == nil or n <= 0 then return nil, "id khong hop le: " .. tostring(id) end
	local sid = string.format("%.0f", n)
	local base = "sprite/effect_" .. sid
	if not file_exists(base .. ".json") then return nil, "thieu " .. base .. ".json" end
	if not file_exists(base .. ".atlas") then return nil, "thieu " .. base .. ".atlas" end
	return sid
end

-- nut goc cua cac hieu ung union cua 1 than: cung vi tri / huong voi model than, nhung song doc lap voi model
-- (model than bi go sau khi danh xong thi hieu ung dang chay van chay het). Tu go sau FX.max_life giay.
local function union_root(role, t)
	if t.fxroot ~= nil then return t.fxroot end
	local root = cc.Node:create()
	if root == nil then return nil end
	root:setPosition(cc.p(t.lx or 0, t.ly or 0))
	pcall(function()
		root:setScaleX(t.node:getScaleX())
		root:setScaleY(t.node:getScaleY())
	end)
	role:addChild(root, -1)
	local life = math.max((tonumber(FX.max_life) or 12) * time_speed(role), 4)
	pcall(function()
		root:runAction(cc.Sequence:create({
			cc.DelayTime:create(life),
			cc.CallFunc:create(function() default_delete(root) end),
		}))
	end)
	t.fxroot = root
	return root
end

-- du phong khi role:createEffect loi (vd bang duration thieu id): tao hieu ung spine giong FightRole:createEffect, bo qua tra bang duration
local function manual_union_effect(role, sid)
	if G("animationMode") ~= 1 then return nil, "khong phai che do spine" end
	local anims = G("effectAnimations")
	if type(anims) ~= "table" then return nil, "thieu effectAnimations" end
	local eff = sp.spine_effect(sid, anims[1], false, nil, nil, nil, nil, nil, nil, "sprite/effect_")
	if eff == nil then return nil, "spine_effect tra nil" end
	eff.animationNameList = anims
	sp.initArmature(eff, true)
	eff._fileName = sid
	eff:getAnimation():playWithIndex(0)
	local cb = G("changeAction_animationEventCallFunc")
	if cb ~= nil then eff:getAnimation():setMovementEventCallFunc(cb) end
	eff:getAnimation():setSpeedScale(1.0 / time_speed(role))
	eff._duration = 0
	return eff
end

-- sinh 1 hieu ung union cho than t (giong engine: role:createEffect(id, "sprite/effect_") roi addChild). Tra eff hoac nil.
local function spawn_union(role, t, id)
	local sid = tostring(id)
	if FX.union_check_files ~= false then
		local okid, why = union_files(id)
		if okid == nil then
			bump("union thieu file")
			trace("  [union] than", t.idx, "id", sid, "BO QUA:", why)
			return nil
		end
		sid = okid
	end
	local root = union_root(role, t)
	if root == nil then
		trace("  [union] than", t.idx, "id", sid, "BO QUA: khong tao duoc nut goc")
		return nil
	end
	local eff, how, err
	local ok1, e1 = pcall(function() return role:createEffect(sid, "sprite/effect_") end)
	if ok1 and e1 ~= nil then
		eff, how = e1, "createEffect"
	else
		err = e1
	end
	if eff == nil then
		local ok2, e2, w2 = pcall(manual_union_effect, role, sid)
		if ok2 and e2 ~= nil then
			eff, how = e2, "thu cong"
		else
			err = tostring(err) .. " / " .. tostring(ok2 and w2 or e2)
		end
	end
	if eff == nil then
		bump("union loi")
		trace("  [union] than", t.idx, "id", sid, "KHONG tao duoc:", tostring(err))
		return nil
	end
	if eff._zzDummy == true then
		pcall(function() eff:stopAllActions() end)
		bump("union spine gia")
		trace("  [union] than", t.idx, "id", sid, "la spine gia (file hong / cat cut), bo qua")
		return nil
	end
	eff._self = role
	eff._invoke = role.__deleteEffectFile or default_delete
	local okadd, erradd = pcall(function() root:addChild(eff) end)
	if not okadd then
		bump("union loi")
		trace("  [union] than", t.idx, "id", sid, "khong addChild duoc:", tostring(erradd))
		return nil
	end
	bump("union fx")
	trace("  [union] than", t.idx, "tao hieu ung sprite/effect_" .. sid, "(" .. how .. ")")
	return eff
end

-- callback su kien khung hinh cua MODEL than: union_<id1>,<id2> => hieu ung; shake / white / black => engine (chong ban doi)
local function twin_frame_event(role, t, evt)
	if FX.union_fx == false and FX.scene_events == false then return end
	if type(evt) ~= "string" or evt == "" or evt == " " then return end
	if skip_fighting() or role == nil or role.fight_over == true then return end
	if t.anim_done == true then return end -- spine lap animation cho den khi than bi go: vong lap sau khong sinh them
	t.nev = (t.nev or 0) + 1
	if t.nev <= (tonumber(FX.union_log_max) or 12) then
		trace("  [union] than", t.idx, tostring(t.prof and t.prof.name or "?"), "su kien khung hinh:", evt)
	end
	bump("su kien khung hinh")
	local toks = split(evt, "_")
	for i, tok in ipairs(toks) do
		if tok == "union" then
			if FX.union_fx ~= false and toks[i + 1] ~= nil then
				for _, id in ipairs(split(toks[i + 1], ",")) do
					if id ~= "" then
						if (t.nunion or 0) >= (tonumber(FX.union_max) or 16) then break end
						t.nunion = (t.nunion or 0) + 1
						spawn_union(role, t, id)
					end
				end
			end
		elseif SCENE_FN[tok] ~= nil then
			scene_forward(role, tok, "than " .. tostring(t.idx))
		end
	end
end

local function attach_twin_events(role, t)
	if FX.union_fx == false and FX.scene_events == false then return end
	local node = t.node
	if node == nil then return end
	local ok, err = pcall(function()
		node:getAnimation():setFrameEventCallFunc(function(bone, evt)
			local ok2, err2 = pcall(twin_frame_event, role, t, evt)
			if not ok2 then note("loi su kien khung hinh cua than", tostring(t.idx), tostring(err2)) end
		end)
	end)
	if ok then
		t.ev_hooked = true
		bump("than dang ky su kien")
	else
		note("khong dang ky duoc su kien khung hinh cho than", tostring(t.idx), tostring(err))
	end
end

-- su kien khung hinh trong animation HIEU UNG chieu cua than (spawn_effect): chi chuyen rung / nhay trang / nhay den
local function hook_effect_events(eff, role, what)
	if FX.scene_events == false then return end
	pcall(function()
		eff:getAnimation():setFrameEventCallFunc(function(bone, evt)
			if type(evt) ~= "string" or evt == "" then return end
			if skip_fighting() then return end
			for _, tok in ipairs(split(evt, "_")) do
				if SCENE_FN[tok] ~= nil then pcall(scene_forward, role, tok, "hieu ung " .. tostring(what or "?")) end
			end
		end)
	end)
end

local function start_twin(role, t)
	if t.done or t.started then return end
	t.started = true
	local node = t.node
	if node == nil then return end
	pcall(function() node:setVisible(true) end)
	fade_in_node(role, node) -- [fx-1.8]
	local ok = play(node, t.action)
	if not ok and t.action ~= t.fallback then
		t.action = t.fallback
		ok = play(node, t.action)
	end
	if not ok then
		note("than", t.idx, "khong chay duoc dong tac", t.action, "(model", t.prof.head .. ") - van ve hieu ung chieu")
		kill_twin(t, true) -- chi go than; hieu ung + am thanh van ve
		return
	end
	-- dang ky ket thuc dong tac SAU khi play (spine: playWithIndex goi callback ngay neu da dang ky)
	pcall(function()
		node:getAnimation():setMovementEventCallFunc(function(a, mtype)
			if mtype == 0 then return end -- armature: START, bo qua
			t.anim_done = true
			maybe_finish(t)
		end)
	end)
	-- nhan vat danh xong (it nhat 1 vong) neu doc duoc thoi luong (da tinh he so gian/nen cua FX.sync)
	local sec = anim_seconds(node, t.action)
	if sec ~= nil then
		local sp_ = time_speed(role)
		pcall(function()
			node:runAction(cc.Sequence:create({
				cc.DelayTime:create(sec * sp_ / (t.mult or 1) + 0.05),
				cc.CallFunc:create(function() t.anim_done = true; maybe_finish(t) end),
			}))
		end)
	end
end

-- tao 1 "than" (model + ho so hieu ung) cho 1 tuong phu o giai doan `stage` cua than chinh.
--   immediate = true: engine danh NGAY (khong co dong tac) => khong gian/nen dong tac theo con chinh.
-- Tra ve t (luon co t); t.node co the nil (khong tao duoc model) => van ve hieu ung + am thanh, chi khong co hinh.
-- [fx-1.11] bo tri chieu no: tra ve lx, ly (toa do cuc bo cua role), flipped. Tra nil => dung FX.offsets nhu cu.
local function rage_place(role, idx, w)
	if FX.rage_layout == false then return nil end
	local is_enemy = (FX.rage_enemy_twin ~= false and FX.rage_enemy_twin ~= nil and tonumber(FX.rage_enemy_twin) == idx)
	local is_back = (not is_enemy) and (FX.rage_back_twin ~= false and FX.rage_back_twin ~= nil and tonumber(FX.rage_back_twin) == idx)
	if not is_enemy and not is_back then return nil end
	local dir = (tonumber(role.roleCamp) == 0) and 1 or -1 -- huong tu phe minh sang phia dich (mac dinh theo phe)
	local list = defenders_of(role, stage_data(role))
	local far, sumy, n, sumx = nil, 0, 0, 0
	local pts = {}
	for _, v in ipairs(list) do
		if v.fight_over ~= true then
			local tsz = v:getContentSize()
			local lp = role:convertToNodeSpace(v:convertToWorldSpace(cc.p((tsz.width or 0) / 2, 0)))
			pts[#pts + 1] = lp
			sumx = sumx + lp.x
			sumy = sumy + lp.y
			n = n + 1
		end
	end
	if n > 0 then
		local avg = sumx / n
		if math.abs(avg - w / 2) > 1 then dir = (avg > w / 2) and 1 or -1 end
		for _, lp in ipairs(pts) do
			if far == nil or (lp.x - far) * dir > 0 then far = lp.x end
		end
	end
	if is_enemy then
		if far == nil then return nil end -- khong tim thay dich: dung vi tri cu
		return far + dir * (tonumber(FX.rage_enemy_gap) or 0.9) * w, sumy / n, true
	end
	return w / 2 - dir * (tonumber(FX.rage_back_gap) or 1.6) * w, (tonumber(FX.rage_back_dy) or 0) * w, false
end

local launch_twin -- [fx-1.11] khai bao truoc, dinh nghia ngay duoi spawn_twin
local function spawn_twin(role, prof, idx, special, stage, immediate, hold)
	local skill = (special and prof.special) or prof.common or prof.special
	local t = { prof = prof, idx = idx, special = special, skill = skill, stage = stage, mult = 1 }
	t.rows = attack_rows(skill)
	t.sie, t.sie_id = pick_row(t, stage)
	t.no_fx = (t.sie == nil)
	t.fallback = special and enum_idx("animation_power_skill_attacking", 15) or enum_idx("animation_skill_attacking", 14)
	local sp_ = time_speed(role)
	t.sp = sp_ -- [fx-1.8] kill_twin dung de tinh thoi gian mo dan

	-- vi tri giong con goc (cho than va cho goc phat hieu ung chieu)
	local size = role:getContentSize()
	local w = (size and size.width) or 120
	local off = FX.offsets[idx] or FX.offsets[1] or { -0.55, 0 }
	t.lx, t.ly = w / 2 + off[1] * w, off[2] * w
	if special then -- [fx-1.11] chieu no: 1 than sau dich, 1 than lui ra sau
		local okp, plx, ply, pfl = pcall(rage_place, role, idx, w)
		if okp and plx ~= nil then
			t.lx, t.ly, t.flipped = plx, ply, (pfl == true)
			trace("  [rage] than", idx, "bo tri chieu no:", t.flipped and "sau dich (lat huong)" or "lui ra sau", string.format("lx=%.0f ly=%.0f", plx, ply or 0))
		elseif not okp then
			note("bo tri chieu no loi:", tostring(plx))
		end
	end

	-- am thanh dau don (chieu dac biet): phat ngay luc con chinh bat dau danh, TACH RIENG phan hinh
	if special and t.sie ~= nil then
		play_sound(first_pos(nums(cell(t.sie, "forepart_lighting_sound_effect_id"))))
	end

	trace("than", idx, prof.name or "?", "model", prof.head, "giai doan", stage, "so dong danh", #t.rows,
		"dong", t.sie_id or "khong", special and "(chieu dac biet)" or "(chieu thuong)")

	local node, err = make_node(prof.head)
	if node == nil then
		note("khong tao duoc than", idx, err, "- van ve hieu ung chieu")
		t.done, t.anim_done = true, true
		return t
	end
	t.node = node
	local names = node.animationNameList
	t.action = action_index(t.sie, special, role.roleCamp, names)
	if type(names) == "table" and #names > 0 and t.fallback >= #names then t.fallback = 0 end
	attach_twin_events(role, t) -- [fx-1.7] su kien khung hinh (union_<id> / shake / white / black) cua than

	-- huong / ti le giong con goc
	local a = role.armature
	pcall(function()
		if a ~= nil then
			node:setScaleX(t.flipped and -a:getScaleX() or a:getScaleX()) -- [fx-1.11] than sau dich nhin ve phe minh
			node:setScaleY(a:getScaleY())
		end
	end)

	t.immediate = immediate
	-- [fx-1.14] hold = true: tao xong ca 2 than truoc, sau do moi chay animation ca hai theo moc con chinh.
	-- `immediate` chi danh dau cac dong danh THEM chay noi tiep; khong duoc dung de bo qua dong bo cho don chinh.
	if hold and FX.sync and not immediate then
		t.lead_sec = lead_attack_seconds(role)
		t.node_sec = t.lead_sec and anim_seconds(node, t.action) or nil
		t.held = true
		return t
	end
	launch_twin(role, t, nil)
	return t
end

-- KHOP NHIP: engine ve hieu ung chieu luc KET THUC dong tac danh cua con chinh, nen cho dong tac cua than
-- KET THUC dung luc do (hoac luc ket thuc dong tac DAI NHAT neu tgt duoc cho): dai hon thi tang toc, ngan hon thi lam cham
-- (gioi han sync_lo..sync_hi), con thieu thi hoan bat dau.
launch_twin = function(role, t, tgt)
	local node, idx, sp_ = t.node, t.idx, t.sp
	local scale = 1.0 / sp_
	local start_delay = 0
	local lead_sec, node_sec
	if t.held then
		lead_sec, node_sec = t.lead_sec, t.node_sec
	else
		lead_sec = (FX.sync and not t.immediate) and lead_attack_seconds(role) or nil
		node_sec = lead_sec and anim_seconds(node, t.action) or nil
	end
	t.held = nil
	local target = (FX.sync_to_lead ~= false and lead_sec ~= nil) and lead_sec or (tgt or lead_sec)
	if target ~= nil and node_sec ~= nil and target > 0.05 then
		local want = clamp(node_sec * sp_ / target, tonumber(FX.sync_lo) or 0.05, tonumber(FX.sync_hi) or 20.0)
		t.mult = want
		scale = (1.0 / sp_) * want
		local real = node_sec * sp_ / want -- thoi luong that cua than sau khi chinh toc
		if real < target - 0.03 then start_delay = target - real end
		trace("  [SYNC-1.13] animation than", tostring(idx), "lead", string.format("%.3fs", lead_sec or 0),
			"twin", string.format("%.3fs", node_sec * sp_), "moc", string.format("%.3fs", target),
			"speed", string.format("%.3f", want), "delay", string.format("%.3fs", start_delay))
	elseif FX.sync_to_lead ~= false then
		note("SYNC-1.13: khong doc duoc duration animation; than", tostring(idx), "se dung toc do mac dinh")
	end
	-- [fx-1.13] Effect va am thanh cua than phu phat tai cung moc influence cua than chinh.
	t.fx_delay = nil
	pcall(function() node:getAnimation():setSpeedScale(scale) end)
	node:setPosition(cc.p(t.lx, t.ly))
	node:setVisible(false)
	role:addChild(node, -1)

	-- an toan: tu go neu co gi do ket (vd khong bao gio nhan duoc su kien ket thuc). Chieu dai (vd 12 giay) van du thoi gian.
	local life = math.max((tonumber(FX.max_life) or 12) * sp_, (target or 0) + 4)
	pcall(function()
		node:runAction(cc.Sequence:create({
			cc.DelayTime:create(life),
			cc.CallFunc:create(function() kill_twin(t) end),
		}))
	end)

	local stag = tonumber(FX.stagger) or 0
	local delay = (idx - 1) * stag * sp_ + start_delay
	if delay > 0.02 then
		local okd = pcall(function()
			node:runAction(cc.Sequence:create({
				cc.DelayTime:create(delay),
				cc.CallFunc:create(function() start_twin(role, t) end),
			}))
		end)
		if not okd then start_twin(role, t) end
	else
		start_twin(role, t)
	end
	bump("spawned")
end

-- ------------------------------------------------------------------ hieu ung chieu cua than
local function effect_layer(role)
	local p = role:getParent()
	local pp = p ~= nil and p:getParent() or nil
	return pp or p or role
end

local function to_layer(layer, node, x, y)
	local wp = node:convertToWorldSpace(cc.p(x, y))
	return layer:convertToNodeSpace(wp)
end

-- [fx-1.4] ghi 1 dong log mo ta hieu ung vua ve (toi da FX.desc_max dong / lan chay): TRONG / NGOAI man hinh la dau hieu chinh de
-- phan biet "hieu ung that nhung o sai cho" voi "hieu ung rong (file thieu)".
local function fx_describe(eff, what, id, used, state)
	FX._ndesc = (FX._ndesc or 0) + 1
	if FX._ndesc > (tonumber(FX.desc_max) or 60) then return end
	local okd, errd = pcall(function()
		local wp = eff:convertToWorldSpace(cc.p(0, 0))
		local vs = cc.Director:getInstance():getVisibleSize()
		local inside = wp.x >= 0 and wp.x <= vs.width and wp.y >= 0 and wp.y <= vs.height
		trace("    hieu ung", what, "id", id, (used ~= id) and ("-> dung " .. tostring(used) .. " (" .. tostring(state) .. ")") or tostring(state),
			string.format("| the gioi (%.0f, %.0f) %s man hinh %.0fx%.0f | scale %.2f/%.2f z %s hien %s",
				wp.x, wp.y, inside and "TRONG" or "NGOAI", vs.width, vs.height, eff:getScaleX(), eff:getScaleY(),
				tostring(eff:getLocalZOrder()), tostring(eff:isVisible())))
	end)
	if not okd then trace("    hieu ung", what, "id", id, tostring(state), "(khong mo ta duoc:", errd, ")") end
end

-- [fx-1.4] tao hieu ung chieu. fb_id = hieu ung TUONG UNG cua than chinh (file chac chan ve duoc vi engine dang ve no cho than chinh):
-- dung thay the khi file hieu ung RIENG cua than thieu / hong, hoac game da thay bang spine gia (node rong).
-- Tra ve eff, id da dung, trang thai: "own" (hieu ung rieng) | "lead" (thay bang cua than chinh) | "dummy" (spine gia, khong thay gi)
--                                    | "missing" (file thieu, khong co gi de thay: khong tao) | "none" (createEffect tra nil)
local function make_effect(role, id, fb_id)
	local allow_fb = (FX.fallback_lead_fx ~= false) and fb_id ~= nil and fb_id ~= id
	if check_fx(id).ok == false then
		if not allow_fb then return nil, id, "missing" end -- khong tao thu: tranh game ghi them "file hong" vao danh sach loc tuong
		local e = role:createEffect(fb_id)
		if e == nil then return nil, fb_id, "none" end
		return e, fb_id, (e._zzDummy == true) and "dummy" or "lead"
	end
	local eff = role:createEffect(id)
	if eff == nil then return nil, id, "none" end
	if eff._zzDummy == true then
		if allow_fb then
			pcall(function() eff:stopAllActions() end)
			local e = role:createEffect(fb_id)
			if e ~= nil then return e, fb_id, (e._zzDummy == true) and "dummy" or "lead" end
		end
		return eff, id, "dummy"
	end
	return eff, id, "own"
end

-- [fx-1.13] Thoi luong effect goc duoc bat truc tiep tu FightRole:createEffect().
-- Moi effect cua than phu duoc chinh toc do de ket thuc cung moc voi effect tuong ung cua than chinh.
local function sync_effect_length(role, eff, target)
	if eff == nil then return nil end
	target = tonumber(target)
	local own = tonumber(eff._duration)
	if target == nil or own == nil or target <= 0 or own <= 0 then return nil end
	local sp_ = time_speed(role)
	local scale = (1.0 / sp_) * (own / target)
	if scale == nil or scale ~= scale or scale <= 0 or scale == math.huge then return nil end
	local ok = pcall(function() eff:getAnimation():setSpeedScale(scale) end)
	if not ok then return nil end
	eff._fx_sync_target_duration = target
	trace("  [SYNC-1.13] effect", tostring(eff._fileName or "?"), "duration",
		string.format("%.3f -> %.3f sec", own, target), "speed", string.format("%.3f", scale))
	return target
end

local function sync_effect_to_lead(role, eff, lead_id)
	if eff == nil or lead_id == nil then return nil end
	local durations = role and role._fx_lead_effect_durations
	local target = type(durations) == "table" and tonumber(durations[tonumber(lead_id)]) or nil
	return sync_effect_length(role, eff, target)
end

-- [fx-1.5] kiem tra hieu ung vua ve con song / co hinh khong (chi ghi log, khong lam gi khac)
local function probe_effect(layer, eff, what, id, state)
	if FX.probe == false then return end
	FX._nprobe = (FX._nprobe or 0) + 1
	if FX._nprobe > (tonumber(FX.probe_max) or 24) then return end
	local function look(tag)
		local ok, err = pcall(function()
			local tl = G("tolua")
			if tl ~= nil and type(tl.isnull) == "function" and tl.isnull(eff) then
				trace("    [probe]", what, "id", id, tag, "node da bi xoa")
				return
			end
			local par = eff:getParent()
			local bb = eff:getBoundingBox()
			local wp = eff:convertToWorldSpace(cc.p(0, 0))
			trace("    [probe]", what, "id", id, tostring(state), tag,
				string.format("cha %s | hien %s | opacity %s | chay %s | khung %.0fx%.0f | the gioi (%.0f, %.0f) | z %s gz %s",
					tostring(par ~= nil), tostring(eff:isVisible()), tostring(eff:getOpacity()), tostring(eff:isRunning()),
					bb.width, bb.height, wp.x, wp.y, tostring(eff:getLocalZOrder()), tostring(eff:getGlobalZOrder())))
		end)
		if not ok then trace("    [probe]", what, "id", id, tag, "loi:", err) end
	end
	pcall(function()
		layer:runAction(cc.Sequence:create({
			cc.DelayTime:create(0.15),
			cc.CallFunc:create(function() look("sau 0.15s") end),
			cc.DelayTime:create(0.45),
			cc.CallFunc:create(function() look("sau 0.6s") end),
		}))
	end)
end

-- lat huong NHU ENGINE: hieu ung chinh lat khi camp == 1; hieu ung lop 2 va lop day lat khi camp == 0.
-- flip_camp = gia tri roleCamp lam hieu ung bi lat (mac dinh 1).
-- [fx-1.2] z = FX.effect_z (= kZOrderInFightScene_Effect cua engine). fx-1.1 doc hang so do tu _G (no la `local` trong
-- FightRole.lua nen ra nil) va dung z = 100 => hieu ung nam DUOI nhan vat dang danh (z 10000) nen khong thay.
local function spawn_effect(role, layer, id, pos, dest, flip_camp, fb_id, what, inv)
	local eff, used, state = make_effect(role, id, fb_id)
	bump("fx " .. tostring(state))
	if eff == nil then
		trace("    hieu ung", what or "?", "id", id, "KHONG ve duoc:", state == "missing" and fx_state_text(id) or tostring(state))
		return nil
	end
	eff._invoke = role.__deleteEffectFile or default_delete
	local sync_duration = sync_effect_to_lead(role, eff, fb_id)
	eff:setPosition(pos)
	local want_flip = (tonumber(role.roleCamp) == (flip_camp == nil and 1 or flip_camp))
	if inv then want_flip = not want_flip end -- [fx-1.11] than sau dich: dao huong hieu ung
	if want_flip then eff:setScaleX(-1 * eff:getScaleX()) end
	layer:addChild(eff, tonumber(FX.effect_z) or 2000000)
	if FX.global_z ~= false then -- [fx-1.5] ep len tren cung + dam bao hien thi
		pcall(function()
			eff:setGlobalZOrder((tonumber(FX.effect_z) or 2000000) + (tonumber(FX.global_z_add) or 0))
			eff:setVisible(true)
			eff:setOpacity(255)
		end)
	end
	hook_effect_events(eff, role, what) -- [fx-1.7] rung / nhay trang / nhay den nam trong animation hieu ung cua than
	local sp_ = time_speed(role)
	if dest ~= nil then
		local d = (tonumber(sync_duration) or tonumber(eff._duration) or 0.3) * sp_
		pcall(function() eff:runAction(cc.MoveTo:create(d, dest)) end)
	end
	pcall(function()
		eff:runAction(cc.Sequence:create({
			cc.DelayTime:create((tonumber(FX.max_life) or 12) * sp_),
			cc.CallFunc:create(function() default_delete(eff) end),
		}))
	end)
	fx_describe(eff, what or "?", id, used, state)
	probe_effect(layer, eff, what or "?", used, state)
	bump("effects")
	return eff
end

-- hieu ung + am thanh trung don len muc tieu (giong FightRole:executeEffectSkillEnd / am thanh bear cua nguoi bi danh)
local function hit_effect(target, t, delay, sync_duration)
	local sie = t.sie
	if sie == nil then return end
	local bid, sid
	if FX.hit_fx then
		bid = nums(cell(sie, "bear_lighting_effect_id"))[1]
		if bid ~= nil and bid < 0 then bid = nil end -- engine: bear_lighting_effect_id >= 0
	end
	if FX.hit_sound then sid = first_pos(nums(cell(sie, "bear_sound_effect_id"))) end
	if bid ~= nil and check_fx(bid).ok == false then
		FX._hitskip = FX._hitskip or {}
		if not FX._hitskip[bid] then FX._hitskip[bid] = true; trace("  hieu ung trung don bo qua:", fx_state_text(bid)) end
		bid = nil
	end
	if bid == nil and sid == nil then return end
	local function go()
		if target == nil or target.fight_over == true or G("FightRole") == nil then return end
		if FightRole.__skeep_fighting == true then return end
		if bid ~= nil then
			local ok, err = pcall(function()
				local eff = target:createEffect(bid)
				if eff == nil then return end
				eff._invoke = target.__deleteEffectFile or default_delete
				sync_effect_length(target, eff, sync_duration)
				local size = target:getContentSize()
				eff:setPosition(cc.p(size.width / 2, 0))
				if tonumber(target.roleCamp) == 1 then eff:setScaleX(-1 * eff:getScaleX()) end
				target:addChild(eff)
				bump("hits")
			end)
			if not ok then note("hieu ung trung don loi:", err) end
		end
		if sid ~= nil then play_sound(sid) end
	end
	if delay ~= nil and delay > 0 and target ~= nil then
		local ok = pcall(function()
			target:runAction(cc.Sequence:create({ cc.DelayTime:create(delay), cc.CallFunc:create(go) }))
		end)
		if not ok then go() end
	else
		go()
	end
end

-- ve hieu ung chieu (chinh / lop 2 / day) + hieu ung trung don + AM THANH cua 1 than.
-- Moi phan bao pcall RIENG: 1 phan loi (vd 1 muc tieu, 1 hieu ung) khong lam mat phan con lai.
-- KHONG dung t.node (model than): hieu ung + am thanh van co du khi than khong co hinh.
-- Am thanh theo dung quy tac engine: posterior_lighting_sound_effect_id = "a,b,c", lan goi ve hieu ung thu n phat am thu n
-- (kieu ve 0 / 2: moi muc tieu 1 lan; kieu ve 1: 1 lan). Phat ca khi chieu khong co hieu ung giua (id < 0), nhu engine.
local function twin_attack_fx(role, t, defenders)
	local sie = t.sie
	if sie == nil then return end
	local layer = effect_layer(role)
	local method = tonumber(cell(sie, "lighting_effect_draw_method")) or 1
	local ids = parse_effect_ids(cell(sie, "posterior_lighting_effect_id"))
	-- [fx-1.4] hieu ung tuong ung cua THAN CHINH (dung thay the khi file hieu ung rieng cua than thieu / hong)
	local lead_ids = {}
	pcall(function()
		local a = role.armature
		lead_ids = parse_effect_ids(cell(a ~= nil and a._sie_action or nil, "posterior_lighting_effect_id"))
	end)
	local sounds = sound_list(cell(sie, "posterior_lighting_sound_effect_id"))
	local size = role:getContentSize()
	local sp_ = time_speed(role)
	local raise = tonumber(FX.raise) or 0
	local from = to_layer(layer, role, t.lx, t.ly + raise * (size.height or 0))
	local calls = 0
	local by_list = sound_by_list()
	local function try(what, fn)
		local ok, err = pcall(fn)
		if not ok then
			bump("errors")
			note("hieu ung chieu loi (" .. what .. "):", err)
		end
	end
	local function call_sound()
		calls = calls + 1
		if by_list then
			play_sound(sounds[calls])
		else
			play_sound(sounds[1]) -- project khac: engine chi lay so dau tien
		end
	end

	if method == 0 then -- duong bay tu than toi tung muc tieu
		for _, v in ipairs(defenders) do
			if ids.main ~= nil then
				try("bay", function()
					local tsz = v:getContentSize()
					local dest = to_layer(layer, v, tsz.width / 2, raise * (tsz.height or 0))
					local eff = spawn_effect(role, layer, ids.main, from, dest, 1, lead_ids.main, "chinh(bay)", t.flipped == true)
					local fly = ((eff and tonumber(eff._fx_sync_target_duration)) or (eff and tonumber(eff._duration)) or 0.3) * sp_
					hit_effect(v, t, fly, eff and eff._fx_sync_target_duration)
				end)
			else
				hit_effect(v, t, 0.3 * sp_)
			end
			call_sound()
		end
	elseif method == 2 then -- ngay tren muc tieu
		for _, v in ipairs(defenders) do
			local sync_duration = nil
			if ids.main ~= nil then
				try("tren muc tieu", function()
					local tsz = v:getContentSize()
					local eff = spawn_effect(role, layer, ids.main, to_layer(layer, v, tsz.width / 2, 0), nil, 1, lead_ids.main, "chinh(muc tieu)", t.flipped == true)
					sync_duration = eff and eff._fx_sync_target_duration or nil
				end)
			end
			hit_effect(v, t, 0.2 * sp_, sync_duration)
			call_sound()
		end
	else -- 1 va cac kieu khac: 1 hieu ung tai cho than dung
		local sync_duration = nil
		if ids.main ~= nil then
			try("tai cho", function()
				local eff = spawn_effect(role, layer, ids.main, from, nil, 1, lead_ids.main, "chinh", t.flipped == true)
				sync_duration = eff and eff._fx_sync_target_duration or nil
			end)
		end
		for _, v in ipairs(defenders) do hit_effect(v, t, 0.3 * sp_, sync_duration) end
		call_sound()
	end

	-- hieu ung lop 2 va lop day: engine chi ve khi co hieu ung chinh (posterior_lighting_effect_id >= 0)
	if ids.main ~= nil then
		if ids.second ~= nil then
			try("lop 2", function()
				spawn_effect(role, layer, ids.second, to_layer(layer, role, t.lx, t.ly), nil, 0, lead_ids.second, "lop2", t.flipped == true)
			end)
		end
		if ids.bottom ~= nil and FX.bottom_fx ~= false then
			try("day", function() -- hieu ung lop day (nen man hinh): goi dung API engine dung cho con chinh
				if check_fx(ids.bottom).ok == false then
					trace("    hieu ung day bo qua:", fx_state_text(ids.bottom))
					return
				end
				local eff = role:createEffect(ids.bottom)
				if eff == nil then return end
				eff._invoke = role.__deleteEffectFile or default_delete
				sync_effect_to_lead(role, eff, lead_ids.bottom)
				if tonumber(role.roleCamp) == 0 then eff:setScaleX(-1 * eff:getScaleX()) end
				state_machine.excute("fight_scene_play_by_attack_screen_bottom_effect", 0, eff)
				bump("effects")
			end)
		end
	end
	trace("  than", t.idx, "da ve: kieu", method, "chinh", ids.main or "-", "lop2", ids.second or "-", "day", ids.bottom or "-",
		"muc tieu", #defenders, "tieng", calls)
end

-- ------------------------------------------------------------------ [fx-1.6] dong danh thu 2 tro di cua tuong phu
-- Chieu cua tuong phu co the co NHIEU dong danh hon tuong chinh (vd Black Frieza chieu dac biet 2 dong; Goku PUI chi 1 giai doan).
-- Giai doan k cua tuong chinh ve dong k cua tuong phu (spawn_twin + pick_row); cac dong k+1 ... n duoc ve NOI TIEP o day, sau khi
-- tuong chinh het giai doan cuoi: moi dong = 1 than moi chay dong tac cua dong do (immediate: khong khop nhip theo con chinh),
-- doi het dong tac roi moi ve hieu ung + am thanh + trung don (engine ve hieu ung luc KET THUC dong tac), roi sang dong ke tiep.
local function skipping()
	local fr = G("FightRole")
	return fr ~= nil and fr.__skeep_fighting == true
end

local function extra_rows_for(role, w, t0, defenders)
	if FX.extra_rows == false then return end
	local rows = t0.rows
	if type(rows) ~= "table" then return end
	local stage = tonumber(w.stage) or 1
	local first = stage + 1
	local last = math.min(#rows, stage + (tonumber(FX.extra_max) or 4))
	local name = tostring(t0.prof and t0.prof.name or "?")
	if first > last then
		if #rows > stage then trace("  [extra] than", t0.idx, name, "bo qua", #rows - stage, "dong (extra_max =", FX.extra_max, ")") end
		return
	end
	trace("  [extra] than", t0.idx, name, "co", #rows, "dong danh, tuong chinh chi co", w.total or stage,
		"giai doan => ve them dong", first == last and tostring(first) or (first .. "-" .. last))
	local sp_ = time_speed(role)
	w.extras = w.extras or {}

	local function targets()
		local list = {}
		for _, v in ipairs(defenders or {}) do
			if v ~= nil and v.parent ~= nil and v.fight_over ~= true then list[#list + 1] = v end
		end
		if #list == 0 then return defenders or {} end
		return list
	end

	local function step(j, prev, waited)
		if j > last then return end
		if w.closed or role.fight_over == true or skipping() then
			trace("  [extra] than", t0.idx, name, "bo dong", j, "(tran ket thuc / bam skip / cua so da dong)")
			return
		end
		local row, row_id = pick_row(t0, j)
		if not row_has_fx(row) then
			trace("  [extra] than", t0.idx, name, "dong", j .. "/" .. #rows, "id", row_id or "khong", "KHONG co hieu ung / am thanh de ve => bo qua")
			return step(j + 1, prev, waited)
		end
		-- than truoc (dong truoc) con dang dien dong tac (vd chieu danh ngay: hieu ung dong 1 ve luc t = 0 nhung than moi bat dau dong tac):
		-- cho no dien XONG roi moi sang dong ke, khong cat ngang dong tac. Cho toi da (thoi luong dong tac + 1 giay), qua han thi chuyen luon.
		if prev ~= nil and not prev.done and not prev.anim_done and prev.node ~= nil then
			local cap = ((anim_seconds(prev.node, prev.action) or 1.0) * sp_) + 1.0
			waited = tonumber(waited) or 0
			if waited < cap then
				if waited == 0 then
					trace("  [extra] than", t0.idx, name, "cho dong tac dong truoc dien xong (toi da", string.format("%.2fs", cap), ") roi ve dong", j)
				end
				local okw = pcall(function()
					role:runAction(cc.Sequence:create({
						cc.DelayTime:create(0.1),
						cc.CallFunc:create(function() step(j, prev, waited + 0.1) end),
					}))
				end)
				if okw then return end
			end
		end
		if prev ~= nil then kill_twin(prev, true) end
		FX._no_fade = true -- [fx-1.8] doi than giua cac dong danh: khong mo dan (tranh nhap nhay)
		local ok, t2 = pcall(spawn_twin, role, t0.prof, t0.idx, t0.special, j, true)
		FX._no_fade = false
		if not ok or t2 == nil then
			bump("errors")
			note("tao than (dong them) loi:", t2)
			return
		end
		w.extras[#w.extras + 1] = t2
		-- thoi gian cho = thoi luong dong tac CUA DONG NAY (engine ve hieu ung luc ket thuc dong tac)
		local wait
		if t2.node ~= nil and not t2.done then
			local sec = anim_seconds(t2.node, t2.action)
			if sec ~= nil then wait = sec * sp_ + 0.05 end
		end
		if wait == nil then wait = (tonumber(FX.extra_gap) or 1.0) * sp_ end
		wait = clamp(wait, 0.05, 10 * sp_)
		if FX.extra_model == false then kill_twin(t2, true) end
		trace("  [extra] than", t0.idx, name, "dong", j .. "/" .. #rows, "id", t2.sie_id or "khong", "dong tac", t2.action or "-",
			"ve sau", string.format("%.2fs", wait), "|", row_fx_text(t2.sie))

		local function fire()
			if w.closed or role.fight_over == true or skipping() then return end
			local okf, errf = pcall(twin_attack_fx, role, t2, targets())
			if not okf then
				bump("errors")
				note("hieu ung chieu (dong them) loi:", errf)
			end
			t2.fx_done = true
			maybe_finish(t2)
			step(j + 1, t2)
		end
		local runner = (t2.node ~= nil and not t2.done) and t2.node or role
		local oks = pcall(function()
			runner:runAction(cc.Sequence:create({ cc.DelayTime:create(wait), cc.CallFunc:create(fire) }))
		end)
		if not oks then fire() end
	end

	step(first, t0)
end

-- ------------------------------------------------------------------ cua so hieu ung = 1 giai doan danh cua than chinh
-- Ve hieu ung + am thanh cua CA 2 than ngay luc engine ve hieu ung cua than chinh (cung 1 khung hinh).
-- Quyen ve gan voi tung giai doan va chi het han an toan sau FX.win_life giay (fx-1.1 khoa sau ~4.5 giay => chieu dai
-- nhu "Silver Dragon Flash" ~12 giay: den luc engine ve hieu ung cuoi don thi than da het quyen ve).
function FX.draw_window(role, w)
	if w == nil or w.closed then return end
	local limit = math.ceil((tonumber(FX.win_life) or 40) * time_speed(role)) + 1
	if w.born ~= nil and (os.time() - w.born) > limit then
		trace("het han cua so (an toan), giai doan", w.stage)
		close_window(w)
		return
	end
	if w.drawn >= (tonumber(FX.max_infl) or 24) then return end
	w.drawn = w.drawn + 1
	local defenders = defenders_of(role, w.data or stage_data(role))
	trace("VE HIEU UNG THAN: lan", w.drawn, "giai doan", w.stage, "so than", #w.twins, "muc tieu", #defenders)
	for _, t in ipairs(w.twins) do
		local function draw_one()
			local ok, err = pcall(twin_attack_fx, role, t, defenders)
			if not ok then
				bump("errors")
				note("hieu ung chieu loi:", err)
			end
			t.fx_done = true
			maybe_finish(t)
		end
		local d = tonumber(t.fx_delay) or 0
		t.fx_delay = nil -- [fx-1.11] chi tre lan ve dau (cac lan ve sau cua cung cua so ve ngay)
		if d > 0.02 then
			-- ve tre bang 1 nut rieng tren lop hieu ung (engine goi stopAllActions tren con chinh / than => khong dung action cua chung)
			local okh = pcall(function()
				local holder = cc.Node:create()
				effect_layer(role):addChild(holder)
				holder:runAction(cc.Sequence:create({
					cc.DelayTime:create(d),
					cc.CallFunc:create(function()
						if not (w.closed or role.fight_over == true or skipping()) then pcall(draw_one) else t.fx_done = true; maybe_finish(t) end
						pcall(function() holder:removeFromParent(true) end)
					end),
				}))
			end)
			if not okh then draw_one() end
		else
			draw_one()
		end
	end
	-- [fx-1.6] giai doan CUOI cua tuong chinh: ve not cac dong danh con lai cua tuong phu (chi 1 lan / cua so)
	if w.last and not w.extra_started and FX.extra_rows ~= false then
		w.extra_started = true
		local snap = {}
		for i, t in ipairs(w.twins) do snap[i] = t end
		for _, t in ipairs(snap) do
			local ok, err = pcall(extra_rows_for, role, w, t, defenders)
			if not ok then
				bump("errors")
				note("ve dong them loi:", err)
			end
		end
	end
end

-- ------------------------------------------------------------------ hook
-- engine vua chay xong changeActtackToAttackBegan cua `role` (than chinh danh)
function FX.on_attack_began(role)
	local pend = role._fx_pend -- true: executeAttackInfluence da chay NGAY TRONG began (chieu khong co dong tac) khi 2 than chua co
	role._fx_pend = nil
	local camp0 = (tonumber(role.roleCamp) == 0)
	if camp0 then gate("began duoc goi", "camp=0", "id=" .. tostring(role_id(role))) end
	if FightRole.__skeep_fighting == true or role.fight_over == true then
		if camp0 then
			gate("bo qua: skeep_fighting/fight_over", "skeep=" .. tostring(FightRole.__skeep_fighting), "over=" .. tostring(role.fight_over))
		end
		return
	end
	local b, why = battle_info()
	if b == nil then
		if camp0 then gate("khong co du lieu hop the", tostring(why)) end
		return
	end
	local lead, how = is_lead(role, b)
	if not lead then
		if camp0 then gate("khong khop than chinh", tostring(how)) end
		return
	end
	local armature = role.armature
	if armature == nil then
		gate("role.armature = nil", "id=" .. tostring(role_id(role)))
		return
	end
	-- chi don danh that su (giong engine: skill_category 0, 1, 34, 35)
	local cat = tonumber(cell(armature._sie_action, "skill_category"))
	if cat ~= nil and not is_attack_cat(cat) then
		trace("bo qua giai doan khong phai don danh (skill_category " .. tostring(cat) .. ")")
		return
	end
	local data = stage_data(role)
	local old = role._fx_win
	if old ~= nil and not old.closed and data ~= nil and old.data == data then
		-- engine goi lai began trong CUNG 1 giai doan: giu than cu (neu engine danh ngay thi ve bu)
		if pend then FX.draw_window(role, old) end
		return
	end
	drop_window(role)
	local stage, total = lead_stage(role, data)
	local known = (stage ~= nil)
	stage = stage or 1
	total = total or stage
	local special = (tonumber(role.skillQuality) == 1)
	local last = (stage >= total) -- [fx-1.6] giai doan CUOI cua tuong chinh => ve not cac dong con lai cua tuong phu
	if not known then
		-- khong doc duoc giai doan: chi cho ve dong them 1 lan / lan danh (tranh lap lai o cac giai doan sau)
		local att = data and data.__attData or nil
		local now = os.time()
		if att ~= nil and role._fx_extra_att == att and (now - (tonumber(role._fx_extra_t) or 0)) < 15 then
			last = false
		else
			role._fx_extra_att, role._fx_extra_t = att, now
		end
	end
	local w = {
		data = data, skf = data and data.__skf or nil, stage = stage, total = total, last = last, special = special,
		twins = {}, born = os.time(), drawn = 0, closed = false,
	}
	trace("BAT DAU DANH: than chinh", tostring(b.lead), "(khop theo " .. tostring(how) .. ")", "giai doan", stage .. "/" .. total,
		known and "" or "(khong doc duoc giai doan)",
		special and "chieu dac biet" or "chieu thuong",
		pend and "(engine influence ngay trong began; van can sync animation)" or "")
	local held = {}
	for i = 1, 2 do
		local prof = b.twins[i]
		if prof ~= nil then
			-- `pend` chi noi engine da phat effect ngay trong began; no KHONG co nghia la bo qua dong bo animation.
			local ok, t = pcall(spawn_twin, role, prof, i, special, stage, false, FX.sync ~= false)
			if ok and t ~= nil then
				w.twins[#w.twins + 1] = t
				if t.held then held[#held + 1] = t end
			elseif not ok then
				bump("errors")
				note("tao than loi:", t)
			end
		end
	end
	role._fx_win = w
	-- [fx-1.11] canh nhip theo dong tac DAI NHAT (con chinh + cac than): con ngan hon lam cham de ket thuc cung luc
	if #held > 0 then
		trace("[SYNC-1.14] held", #held, "pend", tostring(pend == true), "lead", tostring(held[1].lead_sec),
			"targetMode", FX.sync_longest == false and "lead" or "longest")
		local T = held[1].lead_sec
		if T ~= nil and FX.sync_longest ~= false then
			for _, t in ipairs(held) do
				if t.node_sec ~= nil then T = math.max(T, t.node_sec * (t.sp or 1)) end
			end
		end
		for _, t in ipairs(held) do
			local okl, errl = pcall(launch_twin, role, t, T)
			if not okl then
				bump("errors")
				note("canh nhip than loi:", tostring(errl))
				t.held = nil
				t.done, t.anim_done = true, true
				pcall(function() if t.node ~= nil then t.node:removeFromParent(true) end end)
			end
		end
	end
	-- an toan: het quyen ve hieu ung sau win_life giay (ke ca than khong co model)
	pcall(function()
		role:runAction(cc.Sequence:create({
			cc.DelayTime:create((tonumber(FX.win_life) or 40) * time_speed(role)),
			cc.CallFunc:create(function() close_window(w) end),
		}))
	end)
	if pend then
		FX.draw_window(role, w)
		role._fx_lead_effect_durations = nil
	end
end

-- engine vua chay xong executeAttackInfluence cua `role` (luc nay engine da ve hieu ung + phat am thanh cua than chinh)
function FX.on_influence(role)
	if (tonumber(role._fx_depth) or 0) > 0 then
		role._fx_pend = true -- dang ben trong began: 2 than chua duoc tao => ve ngay sau khi chung xuat hien
		return
	end
	local w = role._fx_win
	if w == nil or w.closed then
		if tonumber(role.roleCamp) == 0 then
			gate("influence: chua co cua so ve (than chua tao hoac da dong)", "id=" .. tostring(role_id(role)))
		end
		role._fx_lead_effect_durations = nil
		return
	end
	if FightRole.__skeep_fighting == true or role.fight_over == true then
		role._fx_lead_effect_durations = nil
		return
	end
	local armature = role.armature
	local cat = tonumber(cell(armature and armature._sie_action, "skill_category"))
	if cat ~= nil and not is_attack_cat(cat) then
		trace("bo qua influence khong phai don danh (skill_category " .. tostring(cat) .. ")")
		role._fx_lead_effect_durations = nil
		return
	end
	local data = stage_data(role)
	local same = (w.data == nil) or (data == nil) or (w.data == data) or (w.skf ~= nil and data.__skf == w.skf)
	if not same and w.drawn > 0 then
		trace("bo qua influence: khac giai doan, cua so nay da ve roi")
		role._fx_lead_effect_durations = nil
		return
	end
	FX.draw_window(role, w)
	role._fx_lead_effect_durations = nil
end

-- ------------------------------------------------------------------ [fx-1.9] 2 THAN HOP THE DUNG YEN
-- Con chinh (tuong 1 trong bang HOP THE) co them 2 node "than dung yen" (model cua tuong 2 va 3) dung 2 BEN con chinh
-- (cung FX.offsets voi than khi danh, nam SAU con chinh), chay dong tac dung yen cua chinh model do va HIEN / MO DAN theo
-- nhip do tu video (1078432.mp4): chu ky FX.idle_period = 1.552 giay; than 1 (trai) va than 2 (phai) lech pha nhau theo
-- FX.idle_profile. FX.idle_pulse = false => luon hien.
--   * con chinh chay / lao toi / quay ve / an mung => 2 than chay dong tac do cung (FX.idle_mirror);
--   * khi 1 than DANH (spawn_twin -> start_twin) hien ra thi than dung yen tuong ung mo dan nhuong cho, sau khi than danh
--     bien mat thi hien lai (sau FX.idle_resume giay);
--   * con chinh chet / an / dang doi tuong (needChange) / hop the bi tat => 2 than mo dan roi an; hoi sinh => dung lai node moi.
-- Day van la lop TRINH CHIEU (chi them node con vao nhan vat, khong dong vao sat thuong / ket qua tran / du lieu luu).
-- Moi cho deu pcall: loi => khong co than dung yen, tran van binh thuong.
-- Dong ho = scheduler cua cocos (dt da nhan toc do tran X1/X2/X3, ngung khi tam dung) => nhip hien / mo chay nhanh theo toc do tran.
local function idle_registry()
	local r = rawget(_G, "ZZ_FXIDLE_ROLES")
	if type(r) ~= "table" then
		r = setmetatable({}, { __mode = "k" })
		rawset(_G, "ZZ_FXIDLE_ROLES", r)
	end
	return r
end

-- cac dong tac ma 2 than chay CUNG con chinh (con lai: dung yen). Chi so theo _enum_animation_l_frame_index.
local function mirror_set()
	local s = FX._mirror
	if type(s) == "table" then return s end
	s = {}
	local names = { "animation_standby", "animation_move", "animation_move_back", "animation_onrush", "animation_pursue",
		"animation_pursue_back", "animation_onrush_back", "animation_win_action", "animation_win_on_action",
		"animation_attack_jump", "animation_attack_jump_back", "animation_attack_jump_stay_in_the_sky" }
	local dflt = { 0, 1, 2, 3, 21, 22, 23, 17, 24, 18, 19, 20 }
	for i, name in ipairs(names) do s[enum_idx(name, dflt[i])] = true end
	FX._mirror = s
	return s
end

-- [fx-1.10] dau cua scaleX than dung yen i so voi con chinh: -1 = quay NGUOC huong (nhu video), 1 = cung huong con chinh.
-- Chi quay nguoc khi than dang chay dong tac DUNG YEN (act == standby); chay / lao toi / quay ve ... thi cung huong con chinh.
-- FX.idle_flip: true (ca 2 than) | false (tat) | { true, false } (theo tung than; than nao thieu => true)
local function idle_sign(i, act, standby)
	if act ~= standby then return 1 end
	local f = FX.idle_flip
	if type(f) == "table" then f = f[i] end
	if f == false then return 1 end
	return -1
end

local function smoothstep(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function pulse_alpha(idx, T, ntw)
    if FX.idle_pulse == false then return 1 end
    if (ntw or 2) < 2 and FX.idle_pulse_single == false then return 1 end -- [fx-1.11] che do 2 tuong: khong nhap nhay
    local P = tonumber(FX.idle_period) or 9.0
    local pr = type(FX.idle_profile) == "table" and FX.idle_profile[idx] or nil
    if P < 0.2 or type(pr) ~= "table" then return 1 end

    local up = clamp(tonumber(pr.up) or 1.5, 0.01, P / 3)
    local down = clamp(tonumber(pr.down) or 1.5, 0.01, P / 3)
    local rise, fall = tonumber(pr.rise) or 0, tonumber(pr.fall) or 0
    local hold = (fall - down / 2 - (rise + up / 2)) % P
    if hold + up + down > P then hold = P - up - down end

    local min_alpha = tonumber(pr.min) or 0.25
    local x = (T - (rise - up / 2)) % P
    local factor = 0

    if x < up then
        factor = smoothstep(x / up)
    elseif x < up + hold then
        factor = 1
    elseif x < up + hold + down then
        factor = smoothstep(1 - (x - up - hold) / down)
    end

    return min_alpha + (1 - min_alpha) * factor
end


-- vi tri than dung yen trong toa do cua role (giong than khi danh: w / 2 + dx * w); FX.idle_offsets (neu co) uu tien hon FX.offsets
local function idle_pos(role, idx)
	local size = role:getContentSize()
	local w = (size and size.width) or 120
	local offs = type(FX.idle_offsets) == "table" and FX.idle_offsets or FX.offsets
	local off = offs[idx] or FX.offsets[idx] or FX.offsets[1] or { -0.55, 0 }
	return w / 2 + (tonumber(off[1]) or 0) * w, (tonumber(off[2]) or 0) * w
end

-- dat do trong suot + hien / an 1 node. Node khong ho tro setOpacity => hien / an theo nguong 50%.
local function idle_apply(st, node, op)
	if node == nil then return end
	local ok = true
	if not st.no_opacity then
		ok = pcall(function() node:setOpacity(op) end)
		if not ok then st.no_opacity = true end
	end
	if st.no_opacity then
		pcall(function() node:setVisible(op >= 128) end)
	else
		pcall(function() node:setVisible(op > 0) end)
	end
end

local function idle_clear(role)
	local st = role._fx_idle
	role._fx_idle = nil
	if type(st) ~= "table" then return end
	for i = 1, 2 do
		local n, s = st.nodes and st.nodes[i], st.shadows and st.shadows[i]
		if n ~= nil then pcall(function() n:stopAllActions(); n:removeFromParent(true) end) end
		if s ~= nil then pcall(function() s:stopAllActions(); s:removeFromParent(true) end) end
	end
end

-- tao 1 than dung yen (+ bong) cho ho so prof o vi tri i. box.node / box.shadow luu ngay khi tao de don dep neu loi giua chung.
local function idle_build_one(role, a, prof, i, standby, sp_, box)
	local node, err = make_node(prof.head)
	if node == nil then error(tostring(err), 0) end
	box.node = node
	local lx, ly = idle_pos(role, i)
	pcall(function()
		node:setScaleX(a:getScaleX() * idle_sign(i, standby, standby)) -- [fx-1.10] dung yen => quay nguoc huong con chinh
		node:setScaleY(a:getScaleY())
	end)
	pcall(function() node:getAnimation():setSpeedScale(1.0 / sp_) end)
	pcall(function() node:setCascadeOpacityEnabled(true) end)
	pcall(function() node:setOpacity(0) end)
	node:setPosition(cc.p(lx, ly))
	node:setVisible(false)
	role:addChild(node, -1) -- z = -1: nam sau con chinh (z = 0), cung lop voi than khi danh
	play(node, standby)
	-- bong duoi chan (giong bong cua con chinh trong FightRole:onInit), nam duoi moi thu (z = -2)
	if FX.idle_shadow ~= false then
		pcall(function()
			local sh = cc.Sprite:create("sprite/spirte_2442.png")
			if sh == nil then return end
			sh:setTextureRect(cc.rect(0, 0, 193, 89))
			sh:setAnchorPoint(cc.p(0.5, 0.5))
			sh:setPosition(cc.p(lx, ly))
			sh:setOpacity(0)
			sh:setVisible(false)
			role:addChild(sh, -2)
			box.shadow = sh
		end)
	end
	return lx, ly
end

-- tao (lai) 2 node than dung yen tu ho so profs = { prof1, prof2 } (FX.profile). Tra ve st hoac nil. Node tao xong con AN (idle_step hien dan).
local function idle_build(role, profs, lead_id)
	local a = role.armature
	if a == nil or type(profs) ~= "table" then return nil end
	idle_clear(role)
	local st = { arm = a, profs = profs, lead = lead_id, nodes = {}, shadows = {}, gate = { 0, 0 }, op = { -1, -1 }, sop = { -1, -1 },
		act = { 0, 0 }, free = { 99, 99 }, bad = { {}, {} }, shown = { false, false }, T = tonumber(FX.idle_phase) or 0,
		vt = 0, valid = true, logn = 0 }
	local standby = enum_idx("animation_standby", 0)
	local sp_ = time_speed(role)
	local made, names = 0, {}
	for i = 1, 2 do
		local prof = profs[i]
		if type(prof) == "table" and prof.head ~= nil then
			local box = {}
			local ok, err = pcall(idle_build_one, role, a, prof, i, standby, sp_, box)
			if ok then
				st.nodes[i] = box.node
				st.shadows[i] = box.shadow
				made = made + 1
				names[#names + 1] = tostring(prof.name or "?") .. " (model " .. tostring(prof.head) .. ")"
			else
				if box.node ~= nil then pcall(function() box.node:stopAllActions(); box.node:removeFromParent(true) end) end
				if box.shadow ~= nil then pcall(function() box.shadow:removeFromParent(true) end) end
				bump("errors")
				note("[idle] khong tao duoc than dung yen", i, tostring(err))
			end
		end
	end
	if made == 0 then return nil end
	role._fx_idle = st
	bump("idle: da tao")
	local fl = FX.idle_flip
	local fdesc = type(fl) == "table" and (tostring(fl[1] ~= false) .. "/" .. tostring(fl[2] ~= false)) or tostring(fl ~= false)
	trace("[idle] tao " .. made .. " than dung yen cho than chinh " .. tostring(lead_id) .. ": " .. table.concat(names, ", "),
		"| chu ky", tostring(FX.idle_period), "pha dau", tostring(st.T), (FX.idle_pulse == false or (made < 2 and FX.idle_pulse_single == false)) and "(luon hien)" or "(theo nhip video)",
		"| quay nguoc huong", fdesc)
	return st
end

-- 1 giai doan danh cua than chinh co dang chieu than `idx` khong (than da hien, chua go)? Khi co => than dung yen idx nhuong cho than danh.
local function atk_active(role, idx)
	local w = role._fx_win
	if type(w) ~= "table" then return false end
	local lists = { w.twins, w.extras }
	for k = 1, 2 do
		local list = lists[k]
		if type(list) == "table" then
			for _, t in ipairs(list) do
				if t.idx == idx and t.started == true and not t.done and t.node ~= nil then return true end
			end
		end
	end
	return false
end

local function idle_log(st, ...)
	if st.logn >= (tonumber(FX.idle_log_max) or 12) then return end
	st.logn = st.logn + 1
	trace("[idle]", ...)
end

-- cung ho so (model) voi b.twins khong? Khac => doi tran / doi doi hinh => dung lai
local function same_profs(profs, twins)
	for i = 1, 2 do
		local p, q = profs[i], twins[i]
		local hp = type(p) == "table" and tostring(p.head) or "-"
		local hq = type(q) == "table" and tostring(q.head) or "-"
		if hp ~= hq then return false end
	end
	return true
end

-- moi khung hinh: dong tac / huong / do trong suot cua 2 than dung yen cua `role` (st = role._fx_idle; parent = role:getParent())
local function idle_step(role, st, dt, parent)
	local a = role.armature
	if a == nil then return end
	if st.arm ~= a then -- armature da doi (initChange / updateChange): dung lai theo ho so da luu
		idle_build(role, st.profs, st.lead)
		st = role._fx_idle
		if st == nil then return end
		a = role.armature
	end
	local dead = (role.is_killed == true) or (role.is_deathed == true)
	if dead then
		st.was_dead = true
	elseif st.was_dead then
		-- hoi sinh: node cu co the da bi engine cleanup (dung hoat anh) => dung node moi
		idle_build(role, st.profs, st.lead)
		st = role._fx_idle
		if st == nil then return end
	end

	-- ~2 lan / giay: van con tran hop the nay khong (doi tran / tat hop the / doi than chinh / doi tuong phu)?
	st.vt = st.vt + dt
	if st.vt >= 0.5 then
		st.vt = 0
		local b = battle_info()
		local ok = (b ~= nil) and (is_lead(role, b) == true)
		if ok and not same_profs(st.profs, b.twins) then
			idle_build(role, { b.twins[1], b.twins[2] }, b.lead)
			st = role._fx_idle
			if st == nil then return end
			a = role.armature
		end
		if ok ~= st.valid then
			st.valid = ok
			idle_log(st, ok and "hop the hop le tro lai" or "het hop le (doi tran / tat hop the / doi than chinh) => an 2 than")
		end
	end

	local hidden = false
	pcall(function() hidden = (a:isVisible() == false) or (role:isVisible() == false) end)
	local fu = FX.fu
	local fx_ok = true
	if type(fu) == "table" then fx_ok = (fu.enabled ~= false) and (fu.on ~= false) and (fu.fx_on ~= false) end
	local present = fx_ok and st.valid and parent ~= nil and (not dead) and (not hidden) and role.needChange ~= true

	local k = time_speed(role)
	local d = (tonumber(FX.idle_fade) or 0.13) * k
	local fstep = (d > 0.01) and (dt / d) or 1
	local resume = (tonumber(FX.idle_resume) or 0.15) * k
	st.T = st.T + dt / k -- dong ho cua nhip hien / mo (giay quy ve toc do 1x)

	-- huong / ti le cua con chinh. [fx-1.10] Ti le lay theo con chinh; HUONG cua tung than duoc dat trong vong lap ben duoi
	-- (dung yen => quay nguoc huong con chinh, chay / lao toi ... => cung huong). Chi set khi doi.
	local sx, sy
	pcall(function() sx, sy = a:getScaleX(), a:getScaleY() end)
	st.nsx, st.nsy = st.nsx or {}, st.nsy or {}

	-- dong tac: chay cung con chinh khi dung yen / chay / lao toi / an mung; cac dong tac khac (danh, bi danh ...) thi dung yen
	local standby = enum_idx("animation_standby", 0)
	local want_act = standby
	if FX.idle_mirror ~= false and not dead then
		local cur = tonumber(a._actionIndex)
		if cur ~= nil and mirror_set()[cur] then want_act = cur end
	end

	-- bong cua con chinh dang an (nhay / bay) thi bong cua 2 than cung an
	local sh_ok = true
	pcall(function()
		if role.shadow ~= nil and role.shadow:isVisible() == false then sh_ok = false end
	end)

	for i = 1, 2 do
		local n = st.nodes[i]
		if n ~= nil then
			local target = want_act
			if st.bad[i][target] then target = standby end
			if st.act[i] ~= target then
				local ok = play(n, target)
				if ok then
					st.act[i] = target
				else
					st.bad[i][target] = true -- model nay khong chay duoc dong tac do: ve dung yen
					play(n, standby)
					st.act[i] = standby
				end
			end

			-- [fx-1.10] huong: dang DUNG YEN => quay NGUOC huong con chinh (nhu video); chay / lao toi ... => cung huong con chinh
			if sx ~= nil and sy ~= nil then
				local nsx = sx * idle_sign(i, st.act[i], standby)
				if st.nsx[i] ~= nsx or st.nsy[i] ~= sy then
					if st.nsx[i] == nil then
						idle_log(st, "huong than dung yen", i, "scaleX", nsx, "| con chinh scaleX", sx, nsx == sx and "=> cung huong" or "=> QUAY NGUOC")
					end
					st.nsx[i], st.nsy[i] = nsx, sy
					pcall(function() n:setScaleX(nsx); n:setScaleY(sy) end)
				end
			end

			-- co hien khong: con chinh con song + khong co than danh nao cung vi tri dang chay
			local want = present
			if want then
				if atk_active(role, i) then
					want = false
					st.free[i] = 0
				else
					st.free[i] = st.free[i] + dt
					if st.free[i] < resume then want = false end
				end
			end
			local g = st.gate[i]
			if want then g = math.min(1, g + fstep) else g = math.max(0, g - fstep) end
			st.gate[i] = g
			if want ~= st.shown[i] then
				st.shown[i] = want
				idle_log(st, want and "hien" or "an", "than dung yen", i,
					want and "" or (present and "(than danh dang chay)" or "(con chinh chet / an / doi tuong / tat)"))
			end

			local ntw = (st.nodes[1] ~= nil and 1 or 0) + (st.nodes[2] ~= nil and 1 or 0)
			local alpha = g * pulse_alpha(i, st.T, ntw)
			local op = math.floor(alpha * 255 + 0.5)
			if op ~= st.op[i] then
				st.op[i] = op
				idle_apply(st, n, op)
			end
			local s = st.shadows[i]
			if s ~= nil then
				local sop = sh_ok and math.floor(alpha * 100 + 0.5) or 0
				if sop ~= st.sop[i] then
					st.sop[i] = sop
					idle_apply(st, s, sop)
				end
			end
		end
	end
end

-- 1 role trong bo dem gio. Tra ve false => bo role khoi danh sach theo doi.
local function idle_role_tick(role, info, dt)
	if FX.idle == false then
		if role._fx_idle ~= nil then idle_clear(role) end
		return true
	end
	local parent
	local okp = pcall(function() parent = role:getParent() end)
	if not okp then return false end -- doi tuong da bi huy
	if parent == nil then
		info.orphan = (info.orphan or 0) + dt
		if info.orphan > 15 then return false end -- khong con trong san: thoi theo doi
	else
		info.orphan = 0
	end
	local st = role._fx_idle
	if st == nil then
		-- chua co than dung yen: thu lai (Fusion.battle co the chua san sang luc role duoc tao); toi da ~20 giay
		info.wait = (info.wait or 0) + dt
		if info.wait >= 0.5 then
			info.wait = 0
			info.tries = (info.tries or 0) + 1
			if info.tries > 40 then return false end
			local b = battle_info()
			if b ~= nil then
				if is_lead(role, b) == true then
					FX.idle_ensure(role, b)
				else
					return false -- co du lieu hop the ma day khong phai than chinh: khong can theo doi nua
				end
			end
		end
		return true
	end
	idle_step(role, st, dt, parent)
	return true
end

-- bo dem gio theo khung hinh. Tra ve so role dang theo doi (0 => bo dem gio tu dung).
function FX.idle_tick(dt)
	dt = tonumber(dt) or 0
	if dt ~= dt or dt < 0 then dt = 0 end
	if dt > 0.25 then dt = 0.25 end -- khung hinh dung lau (pause / nap) khong lam than nhay cu
	local reg = idle_registry()
	local n = 0
	for role, info in pairs(reg) do
		n = n + 1
		local ok, keep = pcall(idle_role_tick, role, info, dt)
		if not ok then
			info.errs = (info.errs or 0) + 1
			bump("errors")
			note("[idle] loi:", keep)
			if info.errs >= 5 then
				reg[role] = nil
				pcall(idle_clear, role)
			end
		elseif keep == false then
			reg[role] = nil
		end
	end
	return n
end

-- DUNG 1 bo dem gio / tien trinh (id luu trong _G): tu dung khi het nhan vat, dang ky lai khi co nhan vat moi
local function idle_ensure_ticker()
	if rawget(_G, "ZZ_FXIDLE_TICK") ~= nil then return end
	local ok, id = pcall(function()
		local sch = cc.Director:getInstance():getScheduler()
		return sch:scheduleScriptFunc(function(dt)
			local f = rawget(_G, "FusionFx")
			if type(f) ~= "table" or type(f.idle_tick) ~= "function" then return end
			local okk, n = pcall(f.idle_tick, dt)
			if okk and n == 0 then
				local tid = rawget(_G, "ZZ_FXIDLE_TICK")
				rawset(_G, "ZZ_FXIDLE_TICK", nil)
				pcall(function() cc.Director:getInstance():getScheduler():unscheduleScriptEntry(tid) end)
			end
		end, 0, false)
	end)
	if ok and id ~= nil then
		rawset(_G, "ZZ_FXIDLE_TICK", id)
	else
		note("[idle] khong tao duoc bo dem gio:", tostring(id))
	end
end

-- dam bao role (than chinh) co 2 than dung yen. b = battle_info() da kiem tra khop than chinh.
function FX.idle_ensure(role, b)
	if FX.idle == false or role == nil or type(b) ~= "table" or type(b.twins) ~= "table" then return false end
	local st = role._fx_idle
	if st ~= nil and st.arm == role.armature then return true end
	if role.armature == nil then return false end
	local profs = { b.twins[1], b.twins[2] }
	if profs[1] == nil and profs[2] == nil then return false end
	if idle_build(role, profs, b.lead) == nil then return false end
	local reg = idle_registry()
	if reg[role] == nil then reg[role] = {} end
	idle_ensure_ticker()
	return true
end

-- engine vua chay xong FightRole:onInit (tao armature) cua `role`: dung than dung yen neu la than chinh.
-- Chua co du lieu hop the (Fusion.battle chua san sang) => dang ky de bo dem gio thu lai.
function FX.on_role_init(role)
	if FX.idle == false then return end
	if tonumber(role.roleCamp) ~= 0 then return end
	local b, why = battle_info()
	if b == nil then
		gate("idle: chua co du lieu hop the luc tao role (se thu lai)", tostring(why))
		local reg = idle_registry()
		if reg[role] == nil then reg[role] = {} end
		idle_ensure_ticker()
		return
	end
	local lead, how = is_lead(role, b)
	if not lead then
		gate("idle: khong phai than chinh", tostring(how))
		return
	end
	FX.idle_ensure(role, b)
end

-- so "da boc" nam trong _G (khong nam trong bang FX): FusionFx bi app.unload lam rong / nap lai van khong boc 2 lan
local function registry()
	local r = rawget(_G, "ZZ_FUSIONFX_WRAPPED")
	if type(r) ~= "table" then
		r = setmetatable({}, { __mode = "k" })
		rawset(_G, "ZZ_FUSIONFX_WRAPPED", r)
	end
	return r
end

-- [fx-1.3] tra ve ok, fresh: ok = ham da duoc boc (boi minh hoac truoc do); fresh = vua boc ngay luc nay
local function wrap_method(cls, name, maker)
	if type(cls) ~= "table" then return false, false end
	local f = rawget(cls, name)
	if type(f) ~= "function" then return false, false end
	local reg = registry()
	if reg[f] then return true, false end
	local w = maker(f)
	reg[w] = true
	rawset(cls, name, w)
	return true, true
end

-- goi ham cua FX theo TEN luc chay (FX co the vua bi lam rong / nap lai); moi loi deu nuot, khong lam hong tran
local function call_fx(name, self)
	local f = FX[name]
	if type(f) ~= "function" then return end
	local ok, err = pcall(f, self)
	if not ok then
		pcall(function()
			bump("errors")
			note(name .. " loi:", err)
		end)
	end
end

-- began: nguyen ban chay truoc (khong doi hanh vi tran); trong luc no chay, role._fx_depth > 0 de on_influence biet
-- "engine danh ngay trong began" (chieu khong co dong tac) va hoan viec ve hieu ung cua 2 than.
local function began_maker(orig)
	return function(self, ...)
		local d = tonumber(self._fx_depth) or 0
		self._fx_depth = d + 1
		local ok, r1, r2 = pcall(orig, self, ...)
		self._fx_depth = d
		if not ok then
			self._fx_pend = nil
			error(r1, 0)
		end
		call_fx("on_attack_began", self)
		return r1, r2
	end
end

local function create_effect_maker(orig)
	return function(self, fileIndex, ...)
		local eff = orig(self, fileIndex, ...)
		if (tonumber(self._fx_effect_capture_depth) or 0) > 0 and eff ~= nil then
			local id = tonumber(fileIndex)
			local duration = tonumber(eff._duration)
			if id ~= nil and duration ~= nil and duration > 0 then
				self._fx_lead_effect_durations = self._fx_lead_effect_durations or {}
				self._fx_lead_effect_durations[id] = duration
			end
		end
		return eff
	end
end

local function influence_maker(orig)
	return function(self, ...)
		local depth = tonumber(self._fx_effect_capture_depth) or 0
		if depth == 0 then self._fx_lead_effect_durations = {} end
		self._fx_effect_capture_depth = depth + 1
		local ok, r1, r2 = pcall(orig, self, ...)
		self._fx_effect_capture_depth = depth
		if not ok then error(r1, 0) end
		call_fx("on_influence", self)
		return r1, r2
	end
end

-- [fx-1.9] onInit: nguyen ban chay truoc (engine tao armature), roi dung 2 than dung yen neu la than chinh
local function init_maker(orig)
	return function(self, ...)
		local r1, r2 = orig(self, ...)
		call_fx("on_role_init", self)
		return r1, r2
	end
end

-- [fx-1.3] ham `target` co nam trong chuoi boc cua `f` khong? Duyet upvalue (khong goi ham nao), co tap "da tham" va gioi han
-- so nut (budget) de KHONG BAO GIO treo may du chuoi ham la / nhieu upvalue. Khong co debug => false.
local function chain_has(f, target, depth, seen, budget)
	if f == target then return true end
	if depth <= 0 or type(f) ~= "function" then return false end
	local dbg = rawget(_G, "debug")
	if type(dbg) ~= "table" or type(dbg.getupvalue) ~= "function" then return false end
	seen = seen or {}
	budget = budget or { n = 400 }
	if seen[f] then return false end
	seen[f] = true
	budget.n = budget.n - 1
	if budget.n <= 0 then return false end
	local i = 1
	while i <= 60 do
		local ok, name, val = pcall(dbg.getupvalue, f, i)
		if not ok or name == nil then break end
		if type(val) == "function" and chain_has(val, target, depth - 1, seen, budget) then return true end
		i = i + 1
	end
	return false
end

-- gan hook NGAY KHI engine nap FightRole (truoc khi tran tao vai, class() sao chep ham luc new()).
-- [fx-1.3] Boc app.load DUNG 1 LAN: neu ham dang gan (hoac bat ky ham nao ben duoi no) la ham cua minh thi thoi. Truoc day
-- LocalServer va FusionFx thay nhau boc de len nhau moi giay (chuoi app.load dai vo han).
local FIGHTROLE_PATH = "client.battle.landscape.FightRole"
local function hook_loader()
	local app_ = G("app")
	if type(app_) ~= "table" then return false end
	local cur = rawget(app_, "load")
	if type(cur) ~= "function" then return false end
	if FX._load_top == cur then return true end -- dinh chuoi nay da kiem tra roi
	local installed = rawget(_G, "ZZ_FX_LOADHOOK")
	if type(installed) == "function" and chain_has(cur, installed, 16) then
		FX._load_top = cur
		return true
	end
	local n = tonumber(rawget(_G, "ZZ_FX_LOADHOOK_N")) or 0
	if n >= 3 then return false end -- khong co debug de nhan ra minh trong chuoi: toi da 3 lan / tien trinh
	local w = function(path, ...)
		local r1, r2 = cur(path, ...)
		if path == FIGHTROLE_PATH then
			local f = rawget(_G, "FusionFx")
			if type(f) == "table" and type(f.attach) == "function" then pcall(f.attach) end
		end
		return r1, r2
	end
	rawset(_G, "ZZ_FX_LOADHOOK", w)
	rawset(_G, "ZZ_FX_LOADHOOK_N", n + 1)
	rawset(app_, "load", w)
	FX._load_top = w
	trace("da boc app.load (lan " .. tostring(n + 1) .. ")")
	return true
end

-- [fx-1.3] hook o muc class(): lop "FightRoleClass" vua tao xong => boc new() de TRUOC LAN new() DAU TIEN ta boc 2 ham cua lop do
-- (luc do moi ham cua lop da duoc dinh nghia, va chua doi tuong nao sao chep ham). Chay du FightRole bi nap lai bao nhieu lan.
local function hook_class()
	local cur = rawget(_G, "class")
	if type(cur) ~= "function" then return false end
	if FX._class_top == cur then return true end
	local installed = rawget(_G, "ZZ_FX_CLASSHOOK")
	if type(installed) == "function" and chain_has(cur, installed, 16) then
		FX._class_top = cur
		return true
	end
	local n = tonumber(rawget(_G, "ZZ_FX_CLASSHOOK_N")) or 0
	if n >= 3 then return false end
	local w = function(name, ...)
		local cls = cur(name, ...)
		if name == "FightRoleClass" and type(cls) == "table" then
			pcall(function()
				local onew = rawget(cls, "new")
				if type(onew) == "function" then
					rawset(cls, "new", function(...)
						local f = rawget(_G, "FusionFx")
						if type(f) == "table" and type(f.attach_class) == "function" then pcall(f.attach_class, cls) end
						return onew(...)
					end)
				end
			end)
		end
		return cls
	end
	rawset(_G, "ZZ_FX_CLASSHOOK", w)
	rawset(_G, "ZZ_FX_CLASSHOOK_N", n + 1)
	rawset(_G, "class", w)
	FX._class_top = w
	trace("da boc class() (lan " .. tostring(n + 1) .. ")")
	return true
end

-- boc 2 ham tren 1 lop FightRole cu the (idempotent). Chi ghi log khi thuc su vua boc.
function FX.attach_class(cls)
	local a, fa = wrap_method(cls, "changeActtackToAttackBegan", began_maker)
	local b, fb = wrap_method(cls, "executeAttackInfluence", influence_maker)
	local ce, fce = wrap_method(cls, "createEffect", create_effect_maker) -- [fx-1.13] bat duration effect goc
	local c, fc = wrap_method(cls, "onInit", init_maker) -- [fx-1.9]
	if fa or fb or fce or fc then trace("da boc FightRole (luc tao nhan vat)", FX.version) end
	if not c and type(cls) == "table" then gate("idle: khong boc duoc FightRole.onInit") end
	return (a and b) and true or false
end

function FX.attach()
	pcall(hook_loader)
	pcall(hook_class)
	local cls = G("FightRole")
	local a, fa = wrap_method(cls, "changeActtackToAttackBegan", began_maker)
	local b, fb = wrap_method(cls, "executeAttackInfluence", influence_maker)
	local ce, fce = wrap_method(cls, "createEffect", create_effect_maker) -- [fx-1.13] bat duration effect goc
	local c, fc = wrap_method(cls, "onInit", init_maker) -- [fx-1.9]
	if not c and cls ~= nil then gate("idle: khong boc duoc FightRole.onInit") end
	local was = FX.hooked
	FX.hooked = (a and b) and true or false
	if fa or fb or fce or fc or (FX.hooked and not was) then
		trace("da gan hook FightRole", FX.version, (fa or fb or fce) and "(vua boc)" or "")
	end
	return FX.hooked
end

-- Fusion goi: noi 2 module
function FX.bind(fu)
	FX.fu = fu
end

-- tu noi lai voi Fusion neu FusionFx vua duoc nap lai (Fusion khong bi app.unload nen van song)
if FX.fu == nil then
	local m = package.loaded["client.offline.Fusion"]
	if type(m) == "table" then FX.fu = m end
end

-- [fx-1.4] mo ra cho kiem thu / chan doan thu cong
FX._test = { check_fx = check_fx, make_effect = make_effect, spawn_effect = spawn_effect, twin_attack_fx = twin_attack_fx,
	parse_effect_ids = parse_effect_ids, fx_state_text = fx_state_text, report_profile = report_profile,
	extra_rows_for = extra_rows_for, row_fx_text = row_fx_text, row_has_fx = row_has_fx, lead_stage = lead_stage,
	twin_frame_event = twin_frame_event, attach_twin_events = attach_twin_events, spawn_union = spawn_union,
	scene_forward = scene_forward, union_files = union_files, hook_effect_events = hook_effect_events,
	idle_alpha = pulse_alpha, idle_build = idle_build, idle_step = idle_step, idle_role_tick = idle_role_tick,
	idle_clear = idle_clear }

return FX
