# ============================================================
# АНАТОМИЧЕСКАЯ МЕДИЦИНА И ПСИХОЛОГИЯ (ТЗ 4.1 и 4.6, Barotrauma-стиль)
# 6 зон тела: голова, торс, 2 руки, 2 ноги. Раны: кровотечение,
# перелом. Этапное лечение: жгут → зажим → бинт → шина → морфин.
# Стресс: от взрывов и гибели товарищей → паника / ступор / ярость.
# Тяжелораненый («тяжёлый») падает без движения — нужна эвакуация.
# Модуль статических функций: состояние бойца лежит в его словаре.
# ============================================================
extends RefCounted

const ZONES := ["head", "torso", "la", "ra", "ll", "rl"]
const ZONE_RU := {
        "head": "ГОЛОВА", "torso": "ТОРС",
        "la": "Л.РУКА", "ra": "П.РУКА", "ll": "Л.НОГА", "rl": "П.НОГА",
}
const ZONE_W := {"head": 8.0, "torso": 32.0, "la": 15.0, "ra": 15.0, "ll": 15.0, "rl": 15.0}
const DMG_MULT := {"head": 2.1, "torso": 1.0, "la": 0.6, "ra": 0.6, "ll": 0.7, "rl": 0.7}
const EVAC_FRAC := 0.42   # ниже — боец «тяжёлый», волочить
const MORPH_STRESS := 45.0

# русские названия предметов (для интерфейса и журнала)
const ITEM_RU := {
        "tq": "ЖГУТ", "clamp": "ЗАЖИМ", "band": "БИНТ",
        "splint": "ШИНА", "morph": "МОРФИН", "mag": "МАГАЗИН",
}

const LIMBS := ["la", "ra", "ll", "rl"]

# ================= СОСТОЯНИЕ НОВОГО БОЙЦА =================
static func mk_state() -> Dictionary:
        return {
                "body": {"head": 1.0, "torso": 1.0, "la": 1.0, "ra": 1.0, "ll": 1.0, "rl": 1.0},
                "wounds": [],          # [{zone, bleed(0..2), tq, clamp, band}]
                "frac": [],            # зоны переломов (не зашинированных)
                "stress": 0.0,
                "state": "ok",         # ok/panic/stupor/rage/down
                "state_t": 0.0,
                "treat_t": 0.0,
                "roll_t": 0.0,
                "bleed_t": 0.0,
                "down": false,
                "dragged": false,      # его тащат
                "dragging": null,      # кого тащим (словарь бойца)
                "scream_cd": 0.0,
        }

# ================= ПОПАДАНИЕ ПО ЗОНЕ =================
# возвращает множитель урона и добавляет рану
static func hit_soldier(s: Dictionary, explosive: bool) -> float:
        var st: Dictionary = s["st"]
        # выбор зоны по весам
        var total: float = 0.0
        for z in ZONES:
                total += ZONE_W[z]
        var pick := randf() * total
        var zone := "torso"
        for z in ZONES:
                pick -= ZONE_W[z]
                if pick <= 0.0:
                        zone = z
                        break
        # урон по зоне
        var mult: float = DMG_MULT[zone]
        var integrity: float = st["body"][zone]
        mult *= lerpf(1.25, 0.75, integrity)   # повторное ранение в ту же зону больнее
        st["body"][zone] = maxf(0.0, integrity - randf_range(0.22, 0.4))
        # кровотечение (жгуты/зажимы ставятся на конкретную рану)
        var b := 1
        if zone == "torso" or zone == "head":
                b = 2
        if explosive:
                b = mini(2, b + 1)
        var already := false
        for w in st["wounds"]:
                if w["zone"] == zone and w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                        w["bleed"] = mini(2, w["bleed"] + 1)
                        already = true
                        break
        if not already and b > 0 and randf() < 0.8:
                st["wounds"].append({"zone": zone, "bleed": b, "tq": false, "clamp": false, "band": false})
        # переломы от взрывов и тяжёлых пуль
        if explosive and zone in ["ll", "rl", "la", "ra"] and not st["frac"].has(zone):
                if randf() < 0.4:
                        st["frac"].append(zone)
                        add_stress(s, 18.0)
        elif explosive and zone in ["ll", "rl"] and not st["frac"].has(zone):
                if randf() < 0.2:
                        st["frac"].append(zone)
        # стресс от ранения
        add_stress(s, 12.0 + randf() * 8.0)
        # тяжёлое состояние: торс/голова пробиты — падает
        if not st["down"]:
                var crit: bool = (st["body"]["torso"] < EVAC_FRAC) or (st["body"]["head"] < EVAC_FRAC)
                if crit or (total_bleed(s) >= 4.0 and integrity < 0.5):
                        set_down(s, true)
        return mult

# ================= КРОВОТЕЧЕНИЕ / ПЕРЕЛОМЫ =================
static func total_bleed(s: Dictionary) -> float:
        var st: Dictionary = s["st"]
        var t := 0.0
        for w in st["wounds"]:
                if w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                        t += float(w["bleed"])
        return t

static func leg_mult(s: Dictionary) -> float:
        var st: Dictionary = s["st"]
        if st["down"]:
                return 0.0
        var m := 1.0
        if st["frac"].has("ll"):
                m -= 0.28
        if st["frac"].has("rl"):
                m -= 0.28
        return clampf(m, 0.35, 1.0)

static func arm_mult(s: Dictionary) -> float:
        var st: Dictionary = s["st"]
        var m := 1.0
        if st["frac"].has("la"):
                m += 0.35
        if st["frac"].has("ra"):
                m += 0.35
        # болевые руки — хуже стреляют
        for z in ["la", "ra"]:
                if st["body"][z] < 0.5:
                        m += 0.2
        return m

static func worst_zone(s: Dictionary) -> String:
        var st: Dictionary = s["st"]
        var wz := ""
        var wv := 2.0
        for z in ZONES:
                if st["body"][z] < wv:
                        wv = st["body"][z]
                        wz = z
        return wz

# ================= ТИК БОЙЦА (стресс, кровь, боль) =================
static func tick(s: Dictionary, delta: float, danger: bool) -> void:
        var st: Dictionary = s["st"]
        if st["scream_cd"] > 0.0:
                st["scream_cd"] -= delta
        # затухание стресса вне опасности
        if not danger:
                st["stress"] = maxf(0.0, st["stress"] - delta * 5.0)
        else:
                st["stress"] = maxf(0.0, st["stress"] - delta * 1.2)
        # прокрутка состояния
        if st["state"] != "ok" and st["state"] != "down":
                st["state_t"] -= delta
                if st["state_t"] <= 0.0:
                        st["state"] = "ok"
        # периодический бросок на панику/ступор
        st["roll_t"] -= delta
        if st["roll_t"] <= 0.0:
                st["roll_t"] = 2.6 + randf() * 1.6
                if not st["down"] and st["state"] == "ok":
                        var sr: float = st["stress"]
                        if sr > 72.0:
                                st["state"] = "panic"
                                st["state_t"] = 2.2 + randf() * 1.8
                        elif sr > 54.0 and randf() < 0.5:
                                st["state"] = "stupor"
                                st["state_t"] = 1.4 + randf() * 1.2

# ================= СОБЫТИЯ СТРЕССА =================
static func add_stress(s: Dictionary, amount: float) -> void:
        var st: Dictionary = s["st"]
        st["stress"] = minf(100.0, st["stress"] + amount)
        # мгновенная реакция на сильное потрясение
        if amount >= 16.0 and st["state"] == "ok" and not st["down"]:
                if st["stress"] > 78.0 and randf() < 0.6:
                        st["state"] = "panic"
                        st["state_t"] = 2.5
                elif st["stress"] > 60.0 and randf() < 0.3:
                        st["state"] = "stupor"
                        st["state_t"] = 1.6

static func buddy_died(squad: Array) -> void:
        for s in squad:
                if not s["alive"]:
                        continue
                var st: Dictionary = s["st"]
                add_stress(s, 22.0 + randf() * 10.0)
                # ярость: смерть товарища рядом может всколыхнуть
                if st["stress"] > 40.0 and st["stress"] < 80.0 and randf() < 0.3:
                        st["state"] = "rage"
                        st["state_t"] = 3.5

# ================= ТЯЖЁЛОРАНЕНЫЙ (эвакуация волоком) =================
static func set_down(s: Dictionary, on: bool) -> void:
        var st: Dictionary = s["st"]
        st["down"] = on
        if on:
                st["state"] = "down"
                st["dragging"] = null
        elif st["state"] == "down":
                st["state"] = "ok"

static func need_evac(s: Dictionary) -> bool:
        var st: Dictionary = s["st"]
        return st["down"] and not st["dragged"]

# ================= ЭТАПНОЕ ЛЕЧЕНИЕ =================
# items: tq=жгут, clamp=зажим, band=бинт, splint=шина, morph=морфин
# возвращает: "" — лечение применено, иначе текст что нужно/причина
static func treat(s: Dictionary, item: String) -> String:
        var st: Dictionary = s["st"]
        match item:
                "tq":
                        # жгут: limb-рана с кровотечением
                        for w in st["wounds"]:
                                if w["bleed"] > 0 and not w["tq"] and not w["clamp"] and w["zone"] in ["la", "ra", "ll", "rl"]:
                                        w["tq"] = true
                                        return ""
                        return "нет ран на конечностях"
                "clamp":
                        # зажим: торс/голова
                        for w in st["wounds"]:
                                if w["bleed"] > 0 and not w["tq"] and not w["clamp"] and w["zone"] in ["torso", "head"]:
                                        w["clamp"] = true
                                        return ""
                        return "нет ран на торсе"
                "band":
                        # бинт: самая разбитая зона + гасит лёгкое кровотечение
                        var wz := worst_zone(s)
                        if wz == "":
                                return "боец цел"
                        st["body"][wz] = minf(1.0, st["body"][wz] + 0.34)
                        for w in st["wounds"]:
                                if w["zone"] == wz and w["bleed"] == 1 and not w["tq"]:
                                        w["band"] = true
                                        w["bleed"] = 0
                                        break
                        # после перевязки — восстановление с «тяжёлого»
                        if st["down"] and st["body"]["torso"] >= EVAC_FRAC and st["body"]["head"] >= EVAC_FRAC and total_bleed(s) < 1.0:
                                set_down(s, false)
                        return ""
                "splint":
                        if not st["frac"].is_empty():
                                st["frac"].pop_back()
                                return ""
                        return "переломов нет"
                "morph":
                        st["stress"] = maxf(0.0, st["stress"] - MORPH_STRESS)
                        if st["down"] and total_bleed(s) < 3.0:
                                set_down(s, false)
                        return ""
        return "неизвестный предмет"

# ================= ЛЕЧЕНИЕ КОНКРЕТНОЙ ЗОНЫ (перетаскивание в санчасти) =================
# Игрок тащит предмет из инвентаря на зону тела. Возвращает "" — применено,
# иначе — понятный текст, почему нельзя (подсказка вместо молчания).
static func treat_zone(s: Dictionary, item: String, zone: String) -> String:
        var st: Dictionary = s["st"]
        match item:
                "tq":
                        if not zone in LIMBS:
                                # есть ли вообще рана на конечности — подскажем, куда надо
                                for w in st["wounds"]:
                                        if w["bleed"] > 0 and not w["tq"] and not w["clamp"] and w["zone"] in LIMBS:
                                                return "жгут накладывают на КОНЕЧНОСТЬ — здесь: " + ZONE_RU[w["zone"]]
                                return "жгут некуда накладывать: конечности не кровоточат"
                        for w in st["wounds"]:
                                if w["zone"] == zone and w["bleed"] > 0 and not w["tq"] and not w["clamp"]:
                                        w["tq"] = true
                                        return ""
                        if st["body"][zone] < 0.85:
                                return ZONE_RU[zone] + ": крови нет — попробуйте БИНТ"
                        return ZONE_RU[zone] + ": раны нет — зона цела"
                "band":
                        if st["body"][zone] > 0.92:
                                var has_bleed := false
                                for w2 in st["wounds"]:
                                        if w2["zone"] == zone and w2["bleed"] > 0 and not w2["tq"]:
                                                has_bleed = true
                                                break
                                if not has_bleed:
                                        return ZONE_RU[zone] + ": цел — бинт не нужен"
                        st["body"][zone] = minf(1.0, st["body"][zone] + 0.34)
                        for w in st["wounds"]:
                                if w["zone"] == zone and w["bleed"] == 1 and not w["tq"]:
                                        w["band"] = true
                                        w["bleed"] = 0
                                        break
                        if st["down"] and st["body"]["torso"] >= EVAC_FRAC and st["body"]["head"] >= EVAC_FRAC and total_bleed(s) < 1.0:
                                set_down(s, false)
                        return ""
                "splint":
                        if zone in LIMBS and st["frac"].has(zone):
                                st["frac"].erase(zone)
                                return ""
                        if not st["frac"].is_empty():
                                return "перелом не в " + ZONE_RU[zone] + " — шина нужна на: " + ZONE_RU[st["frac"][0]]
                        return "переломов нет — шина не нужна"
                "morph":
                        st["stress"] = maxf(0.0, st["stress"] - MORPH_STRESS)
                        if st["down"] and total_bleed(s) < 3.0:
                                set_down(s, false)
                        return ""
                "mag":
                        return "МАГАЗИН: магазин набивается вне схемы тела (кнопка инвентаря)"
        return "неизвестный предмет"

# что нужно этому бойцу в первую очередь (подсказка медику/интерфейсу)
static func worst_item(s: Dictionary) -> String:
        var st: Dictionary = s["st"]
        for w in st["wounds"]:
                if w["bleed"] == 2 and not w["tq"] and not w["clamp"]:
                        return "clamp" if w["zone"] in ["torso", "head"] else "tq"
        for w in st["wounds"]:
                if w["bleed"] == 1 and not w["tq"] and not w["clamp"]:
                        return "band"
        if not st["frac"].is_empty():
                return "splint"
        if st["stress"] > 55.0:
                return "morph"
        if st["body"][worst_zone(s)] < 0.8:
                return "band"
        return ""

# краткий статус для интерфейса
static func status_str(s: Dictionary) -> String:
        var st: Dictionary = s["st"]
        var parts: Array = []
        var bl := total_bleed(s)
        if bl > 0.0:
                parts.append("кровь x%d" % int(bl))
        if not st["frac"].is_empty():
                parts.append("перелом")
        if st["down"]:
                parts.append("ТЯЖЁЛЫЙ")
        if st["state"] == "panic":
                parts.append("ПАНИКА")
        elif st["state"] == "stupor":
                parts.append("СТУПОР")
        elif st["state"] == "rage":
                parts.append("ЯРОСТЬ")
        elif st["stress"] > 50.0:
                parts.append("стресс %d%%" % int(st["stress"]))
        if parts.is_empty():
                return ""
        return " / ".join(parts)
