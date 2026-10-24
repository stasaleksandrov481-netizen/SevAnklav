# ============================================================
# ГЛОБАЛЬНОЕ СОСТОЯНИЕ И БАЗА ДАННЫХ ЮНИТОВ
# «СЕВЕРНЫЙ АНКЛАВ: ЛИНИЯ ФРОНТА»
# Автозагрузка: G (project.godot → [autoload])
# Все данные боевых единиц трёх фракций (САК / ФОА / «Шакал»),
# таблицы брони, экономика, состояние кампании, звук.
# ============================================================
extends Node

# ---------- фракции и цвета ----------
const FACTION_NAMES := {
        "sak": "САК — Силы Корпуса Анклава",
        "foa": "ФОА — Фронт Освобождения Анклава",
        "jack": "Синдикат «Шакал»",
}
const FACTION_COLOR := {
        "sak": Color(0.36, 0.55, 0.72),
        "foa": Color(0.72, 0.34, 0.28),
        "jack": Color(0.78, 0.64, 0.30),
}
const TEAM_PLAYER := 1
const TEAM_ENEMY := 2

# ---------- множители брони: класс снаряда → класс цели ----------
const AP_TABLE := {
        "kinetic": {"none": 1.0, "light": 0.9, "med": 0.45, "heavy": 0.22},
        "apcr":    {"none": 1.1, "light": 1.0, "med": 0.9,  "heavy": 0.62},
        "heat":    {"none": 1.2, "light": 1.1, "med": 0.95, "heavy": 0.8},
        "he":      {"none": 1.5, "light": 1.0, "med": 0.55, "heavy": 0.28},
        "frag":    {"none": 1.4, "light": 0.9, "med": 0.5,  "heavy": 0.2},
        "sam":     {"none": 1.0, "light": 1.0, "med": 1.0,  "heavy": 0.9},
}

# ---------- сложность (по ТЗ: только множители) ----------
const DIFFICULTY := {
        0: {"name": "РЯДОВОЙ", "enemy_dmg": 1.0, "price": 1.0, "ai_income": 0.85},
        1: {"name": "ВЕТЕРАН", "enemy_dmg": 1.5, "price": 1.3, "ai_income": 1.05},
        2: {"name": "АНКЛАВ", "enemy_dmg": 2.25, "price": 1.6, "ai_income": 1.3},
}

# ---------- стартовые комплекты (по ТЗ) ----------
const START_KITS := {
        0: {"name": "Штурмовик САК", "desc": "+2 мотострелковых отделения, +1 Урал снабжения"},
        1: {"name": "Диверсант-контрабандист", "desc": "+БРМД-2 разведки, +снайперская пара, +200 реквизиции"},
        2: {"name": "Тяжёлая поддержка", "desc": "Бронетехника дешевле на 15%"},
}

# ---------- сектора кампании (юг → север, к «Заре») ----------
const SECTORS := [
        {"name": "Блокпост «Южный»", "type": "outpost", "enemy": "foa"},
        {"name": "ПГТ «Раздолье»", "type": "town", "enemy": "foa"},
        {"name": "Нефтебаза №4", "type": "industrial", "enemy": "foa"},
        {"name": "Лесной заслон", "type": "forest", "enemy": "foa"},
        {"name": "Завод «Прометей»", "type": "industrial", "enemy": "foa"},
        {"name": "Переправа через Быструю", "type": "river", "enemy": "foa"},
        {"name": "Высота 214", "type": "field", "enemy": "foa"},
        {"name": "Склады ГСМ", "type": "industrial", "enemy": "jack"},
        {"name": "ПГТ «Вьюга»", "type": "town", "enemy": "jack"},
        {"name": "Радар Р-181", "type": "field", "enemy": "jack"},
        {"name": "АЭРОДРОМ «СОКОЛ»", "type": "airbase", "enemy": "jack"},
        {"name": "Мост «Северный»", "type": "river", "enemy": "jack"},
        {"name": "Химзавод «Кислота»", "type": "industrial", "enemy": "jack"},
        {"name": "Крепость «Шакала»", "type": "town", "enemy": "jack"},
        {"name": "Ущелье Сухое", "type": "field", "enemy": "foa"},
        {"name": "Цитадель ФОА", "type": "town", "enemy": "foa"},
        {"name": "Полигон «Вымпел»", "type": "field", "enemy": "jack"},
        {"name": "Подступы к «Заре»", "type": "airbase", "enemy": "jack"},
        {"name": "Командный бункер", "type": "outpost", "enemy": "jack"},
        {"name": "ОБЪЕКТ «ЗАРЯ»", "type": "final", "enemy": "jack"},
]

# ---------- состояние кампании (сохраняется в user://) ----------
var save := {
        "commander": "КОМАНДИР",
        "difficulty": 1,
        "kit": 0,
        "faction": "sak",
        "sector": 0,
        "bank": 0,
        "heli_unlocked": false,
        "upgrades": {"logistics": 0, "scouts": false, "repair": false, "prep": false, "trophy": false},
        "wins": 0, "battles": 0,
        "campaign_won": false,
        "poligon_passed": true,
        "total_losses": 0,     # пермасмерть: совокупные потери за кампанию
        "total_kills": 0,
}

# ============================================================
# КАМПАНИЯ «ЗЕМЛЯ МЕРТВЫХ» (зомби-апокалипсис) — активная кампания.
# Военная кампания САК/ФОА заморожена (код сохранён, доступ закрыт).
# ============================================================
const Z_WEAPON_NAMES := {
        "pistol": "ПМ «Макаров»",
        "smg": "ПП-19 «Витязь»",
        "shotgun": "Сайга-12",
        "rifle": "АК-74М",
        "knife": "Складной нож",
}
const ZWEAPONS := {
        "pistol": {"dmg": 26.0, "rof": 0.40, "rng": 330.0, "mag": 8, "reload": 1.5, "spr": 0.05, "sfx": "z_shot_pistol", "pellets": 1, "price": 0},
        "smg": {"dmg": 15.0, "rof": 0.095, "rng": 380.0, "mag": 30, "reload": 2.0, "spr": 0.08, "sfx": "z_shot_smg", "pellets": 1, "price": 260},
        "shotgun": {"dmg": 11.0, "rof": 0.95, "rng": 230.0, "mag": 8, "reload": 2.6, "spr": 0.17, "sfx": "z_shot_shotgun", "pellets": 7, "price": 320},
        "rifle": {"dmg": 26.0, "rof": 0.125, "rng": 540.0, "mag": 30, "reload": 2.2, "spr": 0.045, "sfx": "z_shot_rifle", "pellets": 1, "price": 420},
        # нож: бесшумный ближний бой — скрытность (по ТЗ: избегать боя выгоднее)
        "knife": {"dmg": 34.0, "rof": 0.55, "rng": 76.0, "mag": 1, "reload": 0.0, "spr": 0.0, "sfx": "z_knife", "pellets": 1, "price": 0, "melee": true},
}
const ZWEAPON_ORDER := ["pistol", "knife", "smg", "shotgun", "rifle"]

# предметы зомби-кампании (инвентарь Barotrauma-стиля)
const ZITEMS := {
        "band": {"name": "БИНТ", "desc": "Перевязывает рану, гасит лёгкую кровь", "price": 30},
        "tq": {"name": "ЖГУТ", "desc": "Останавливает сильное кровотечение конечности", "price": 40},
        "splint": {"name": "ШИНА", "desc": "Фиксирует перелом", "price": 50},
        "morph": {"name": "МОРФИН", "desc": "Снимает боль и стресс", "price": 70},
        "abx": {"name": "АНТИБИОТИК", "desc": "Подавляет заражение (штамм «Заря»)", "price": 80},
        "mag_pistol": {"name": "МАГАЗИН ПМ", "desc": "8 патронов к пистолету", "price": 20},
        "mag_smg": {"name": "МАГАЗИН ПП", "desc": "30 патронов к «Витязю»", "price": 55},
        "mag_shotgun": {"name": "БОЕЗАПАС САЙГА", "desc": "8 патронов к «Сайге»", "price": 60},
        "mag_rifle": {"name": "МАГАЗИН АК", "desc": "30 патронов к АК-74М", "price": 70},
        "food": {"name": "СУХПАЁК", "desc": "Восстанавливает силы (+немного целости)", "price": 35},
        "keycard": {"name": "КЛЮЧ-КАРТА «ЗАРЯ»", "desc": "Карта СБ уровня Б. Открывает технический шлюз.", "price": 0},
        # ---- квестовые предметы пролога «ЗАРЯ» ----
        "propusk": {"name": "ПРОПУСК ВРАЧА", "desc": "Пропуск медсектора. Нужен медицинскому терминалу.", "price": 0},
        "fuse": {"name": "ПРЕДОХРАНИТЕЛЬ", "desc": "Промышленный предохранитель для генератора.", "price": 0},
        "gloves": {"name": "ИЗОЛЯЦИОННЫЕ ПЕРЧАТКИ", "desc": "Без них рубильник в затопленной щитовой бьёт током.", "price": 0},
        "tool_key": {"name": "КЛЮЧ ТЕХНИКА", "desc": "Ключ от инструментальной. Найден у тела в тоннеле.", "price": 0},
        "air_key": {"name": "АВАРИЙНЫЙ КЛЮЧ", "desc": "Аварийный ключ карантина. Открывает шлюз блокировки.", "price": 0},
        "cassette": {"name": "АУДИОКАССЕТА", "desc": "Из ящика палаты № 12. Прослушать — на деке техсектора.", "price": 0},
        "lockpick": {"name": "ОТМЫЧКА", "desc": "Инструмент для замков. Взлом шумный.", "price": 0},
        "medkit": {"name": "АПТЕЧКА", "desc": "Редкий медицинский набор. Пригодится дальше.", "price": 60},
        "smoke": {"name": "ДЫМОВАЯ ШАШКА", "desc": "Завеса: мёртвые теряют вас из виду.", "price": 30},
        "mask": {"name": "ПРОТИВОГАЗ", "desc": "Защищает от утечки охлаждающего газа.", "price": 0},
}

# FIX7v2: число фиксированных ячеек рюкзака (сетка 6x4, как в Майнкрафте)
const INV_SLOTS := 24

# хабар с зомби и трупов: id → {name, value} (продаётся в лагерях)
const ZLOOT := {
        "watch": {"name": "НАРУЧНЫЕ ЧАСЫ", "value": 24},
        "chip": {"name": "ЭЛЕКТРОНИКА", "value": 40},
        "docs": {"name": "ДОКУМЕНТЫ", "value": 30},
        "meds": {"name": "МЕДИКАМЕНТЫ", "value": 36},
        "ammo": {"name": "ПАТРОНЫ", "value": 26},
        "food": {"name": "СУХПАЁК", "value": 20},
}

# сектора зомби-кампании: 20 узлов на север (с 5-го — лагеря)
const ZSECTORS := [
        {"name": "БУНКЕР «ЗАРЯ»", "type": "bunker", "desc": "Подземный медицинский блок. Отсюда всё началось."},
        {"name": "СНЕЖНАЯ ЛИНИЯ", "type": "clear", "desc": "Первая миссия: уйти от группы зачистки в метель. Следы на снегу видны издалека."},
        {"name": "Склады «Заря-2»", "type": "warehouse", "desc": "Зачистить склад с припасами."},
        {"name": "Снежное поле", "type": "tablets", "desc": "Найти 3 планшета с данными в зоне крушения."},
        {"name": "ЛАГЕРЬ «СТРАЖ»", "type": "camp", "desc": "Передышка: перевязка, патроны, торговец."},
        {"name": "ПГТ «Мёртвый Ключ»", "type": "clear", "desc": "Посёлок заполнен ходоками."},
        {"name": "Оборона вышки", "type": "defense", "desc": "Продержаться, пока мачта шлёт сигнал."},
        {"name": "Лесная просека", "type": "rescue", "desc": "Инженер заперся в будке. Спаси его."},
        {"name": "ЛАГЕРЬ «ПРИЮТ»", "type": "camp_big", "desc": "Крупный лагерь: торговля и наём бойцов."},
        {"name": "Замёрзший карьер", "type": "warehouse", "desc": "Зачистить технические склады."},
        {"name": "Автоколонна на трассе", "type": "tablets", "desc": "Планшеты с картой остались в машинах."},
        {"name": "Блокпост на реке", "type": "defense", "desc": "Держать мост, пока идёт переправа."},
        {"name": "Деревня «Тихие Дворы»", "type": "clear", "desc": "Тут ходят целые толпы. Тихо — не значит безопасно."},
        {"name": "ЛАГЕРЬ «РОДНИК»", "type": "camp", "desc": "Передышка: перевязка и патроны."},
        {"name": "Химсклад №9", "type": "warehouse", "desc": "Твари здесь желто-зелёные. Не дышите глубоко."},
        {"name": "Оборона радиостанции", "type": "defense", "desc": "Радиомаяк выживших заработает, если вы продержитесь."},
        {"name": "ЛАГЕРЬ «СЕВЕР-7»", "type": "camp_big", "desc": "Последний большой лагерь перед лабораторией."},
        {"name": "Полевой госпиталь", "type": "rescue", "desc": "Медик знает про штамм. Выведите его живым."},
        {"name": "Разрушенный-reactor", "type": "tablets", "desc": "Планшеты из реакторного блока."},
        {"name": "СЕВЕРНЫЙ БУНКЕР", "type": "final", "desc": "Источник сигнала. Источник штамма. Ответы."},
]

# дневник кампании (запись появляется после выхода из бункера и далее)
const ZDIARY := {
        1: "СЕКТОР 1: ПОБЕГ ИЗ «ЗАРИ»\n\nЯ не помню, как оказался здесь. Терминал называет меня пациентом V-17 и кричит: «ПОВТОРНАЯ СМЕРТЬ: НЕ ДОПУСТИТЬ».\nВ карантине — запись доктора Морозовой: микроорганизм не восстанавливает связи. Он создаёт новые. Я был участником эксперимента № 12. И я не единственный, кто вернулся.\nУ грузового шлюза лежал человек в моей форме, с моим лицом. На рукаве: V-18. Он сказал: «Ты опять опоздал».\nНа площадке ждали бойцы без опознавательных знаков: «Субъект V-17 обнаружен. Разрешение на ликвидацию получено».\nПути назад нет. Только на Север.",
        2: "СЕКТОР 2: СНЕЖНАЯ ЛИНИЯ\n\nМетель прячет следы — мои и их. Бойцы без знаков прочёсывают площадку, прожекторы режут темноту.\nОдин снял шлем: лицо под ним покрыто инеем. Он беззвучно произнёс: «Брат».\nНет. Ты не мог выжить.",
        3: "СЕКТОР 3: СКЛАДЫ\n\nВ складах ещё лежат армейские ящики. Часть — ссохшиеся трупы мародёров.\nМёртвые не уходят далеко от места, где умерли.",
        4: "СЕКТОР 4: КРУШЕНИЕ\n\nНаходки с планшетов: «штамм З-0 переносится только при укусе…\nноситель нулевого штамма невосприимчив…» Носитель. Это я.",
        5: "СЕКТОР 5: ЛАГЕРЬ\n\nЛюди. Живые люди. Первые за долгое время.\nТорговец взял хабар без вопросов. Здесь умеют не спрашивать.",
        6: "СЕКТОР 6: ПОСЁЛОК\n\nВ домах остались приметы обычной жизни. Вспоминать об этом — роскошь.",
        7: "СЕКТОР 7: ВЫШКА\n\nМачта держится. Сигнал ушёл на север. Пусть кто-нибудь услышит.",
        8: "СЕКТОР 8: ПРОСЕКА\n\nИнженер сказал: «Северный бункер — это лаборатория №2. Штамм оттуда».",
        9: "СЕКТОР 9: ПРИЮТ\n\nНаёмники идут за хабар. Мой хабар — моя кровь. Расплата честная.",
        10: "СЕКТОР 10: КАРЬЕР\n\nВ карьерах видны воронки от ЭМИ-удара. Техника стояла мёртвая ещё до того, как встал я.",
        11: "СЕКТОР 11: ТРАССА\n\nАвтоколонна пыталась прорваться на юг. Никто не прорвался.",
        12: "СЕКТОР 12: МОСТ\n\nРека подо льдом. Лёд держит мёртвых. Плохая новость.",
        13: "СЕКТОР 13: ДЕРЕВНЯ\n\nТолпы ходят по кругу, как будто ищут дом, которого больше нет.",
        14: "СЕКТОР 14: РОДНИК\n\nВода здесь чистая. Впервые за долгое время я напился вдоволь.",
        15: "СЕКТОР 15: ХИМСКЛАД\n\nПланшет химиков: «вирус мутирует при контакте с реагентом 9». Хорошо, что я не дышал.",
        16: "СЕКТОР 16: РАДИОСТАНЦИЯ\n\n«Внимание. Выжившим: идите на север. Повторяю: идите на север».",
        17: "СЕКТОР 17: СЕВЕР-7\n\nПоследний тёплый ночлег. Дальше — только холод и они.",
        18: "СЕКТОР 18: ГОСПИТАЛЬ\n\nМедик взял у меня кровь и побледнел. «Антидот из тебя сделают. Или ты — уже решение».",
        19: "СЕКТОР 19: РЕАКТОР\n\nПланшеты реактора совпадают с моим сном: Заря-0. Нулевой штамм. Я.",
        20: "СЕКТОР 20: СЕВЕРНЫЙ БУНКЕР\n\nЯ знаю, кто я. Я знаю, что здесь лежит. Вхожу.",
}

var zsave := {
        "seen_prologue": false,
        "sector": 0,          # следующий непройденный узел (0 = бункер)
        "bank": 0,            # «хабар» — валюта зомби-кампании
        "wins": 0,
        "battles": 0,
        "diff": 1,
        "weapons": ["pistol"],
        "cur_weapon": "pistol",
        "ammo": {"pistol": 24, "smg": 0, "shotgun": 0, "rifle": 0},
        "inv": {"band": 3, "tq": 1, "splint": 0, "morph": 1, "abx": 0, "mag_pistol": 2, "mag_smg": 0, "mag_shotgun": 0, "mag_rifle": 0, "food": 1},
        "inv_slots": [],   # FIX7v2: расположение предметов по ячейкам рюкзака
        "squad": [],          # [{name, alive}]
        "diary": 0,           # последняя прочитанная запись дневника
        "campaign_won": false,
        # ---- ПРОЛОГ «ЗАРЯ»: сложность и переменные кампании ----
        "zdiff": 1,           # 0 ОПЕРАТИВНИК / 1 ВЫЖИВШИЙ / 2 ПОСЛЕДНИЙ
        "pvars": {},          # 9 сюжетных переменных пролога (см. PVAR_DEFAULTS)
}

# ---------- СЛОЖНОСТИ ПРОЛОГА (по ТЗ п.18) ----------
# Главное испытание — решения при недостатке информации и ресурсов,
# а не просто увеличенный урон противников.
const ZDIFF_NAMES := ["ОПЕРАТИВНИК", "ВЫЖИВШИЙ", "ПОСЛЕДНИЙ"]
const ZDIFF := {
        0: {  # ОПЕРАТИВНИК: больше ресурсов, подсказки, повторные взаимодействия
                "desc": "Больше боеприпасов и медикаментов. Подсказки к задачам. Некоторые ошибки прощаются.",
                "ammo_k": 1.6, "med_k": 1.6, "notice_k": 0.85, "countdown_k": 1.5,
                "hypothermia_k": 0.6, "hints": true, "enemy_dmg": 1.0,
        },
        1: {  # ВЫЖИВШИЙ: ограниченный боезапас, заметные холод и усталость
                "desc": "Ограниченный боезапас, редкие медикаменты. Холод и усталость ощутимы. Мёртвые видят и слышат.",
                "ammo_k": 1.0, "med_k": 1.0, "notice_k": 1.0, "countdown_k": 1.0,
                "hypothermia_k": 1.0, "hints": true, "enemy_dmg": 1.15,
        },
        2: {  # ПОСЛЕДНИЙ: минимум ресурсов, без подсказок, потери навсегда
                "desc": "Минимум ресурсов. Никаких подсказок. Часть возможностей теряется навсегда.",
                "ammo_k": 0.55, "med_k": 0.55, "notice_k": 1.3, "countdown_k": 0.72,
                "hypothermia_k": 1.5, "hints": false, "enemy_dmg": 1.35,
        },
}

# ---------- ПЕРЕМЕННЫЕ КАМПАНИИ (по ТЗ п.17) ----------
# Меняют не только текст, но и реальные события пролога и дальше.
const PVAR_DEFAULTS := {
        "helped_serov": false,        # спасли Серова → его контакты помогут позже
        "found_v17_record": false,    # запись палаты № 12 → ранние предупреждения о субъектах
        "repaired_generator": false,  # генератор 18%+ → ресурсы и альтернативный путь
        "saved_medkit": false,        # не потратили редкий меднабор → лечение после пролога
        "heard_unknown_voice": false, # голос у шлюза → фрагмент воспоминания
        "found_v18_body": false,      # осмотрели тело V-18 → запись в журнал
        "alarm_triggered": false,     # подняли тревогу → больше бойцов на площадке
        "used_stealth_route": false,  # карантин без боя → сохранённые боеприпасы
        "trust_ai": false,            # следовали рекомендациям ИИ → часть данных скрыта
}

func zflag(name: String) -> bool:
        return bool(zsave.get("pvars", {}).get(name, false))

func zset_flag(name: String, val := true) -> void:
        if not zsave.has("pvars") or not (zsave["pvars"] is Dictionary):
                zsave["pvars"] = {}
        zsave["pvars"][name] = val
        write_save()

# параметр текущей сложности пролога
func zdiff_param(key: String) -> float:
        return float(ZDIFF.get(int(zsave.get("zdiff", 1)), ZDIFF[1]).get(key, 1.0))

func zdiff_hints() -> bool:
        return bool(ZDIFF.get(int(zsave.get("zdiff", 1)), ZDIFF[1]).get("hints", true))

# ---------- ОЗВУЧКА ПРОЛОГА (чужие голоса) ----------
# Папки: assets/sfx/voice/prologue/ (ai_* — ИИ, radio_* — рация).
# Списки ниже — карта последовательностей: реплики сценария → файлы.
# Отсутствующие файлы молча пропускаются (ZVoice), имена менять нельзя.
const VDIR := "res://assets/sfx/voice/prologue/"
const VOICE_MAP := {
        # ИИ «Заря»: приветствие пациента в сознании
        "ai_intro": ["ai_01.wav", "ai_02.wav", "ai_03.wav"],
        # ответы ИИ на выбор А/Б (вариант Б начинается своими файлами)
        "ai_answer_a": ["ai_a_01.wav", "ai_a_02.wav", "ai_a_03.wav", "ai_a_04.wav", "ai_a_05.wav"],
        "ai_answer_b": ["ai_b_01.wav", "ai_b_02.wav", "ai_a_03.wav", "ai_a_04.wav", "ai_a_05.wav"],
        # голос выжившего / неизвестного по рации
        "radio_survivor": ["radio_01.wav", "radio_02.wav", "radio_03.wav", "radio_04.wav"],
        # СЛЕДУЮЩИЕ ПАРТИИ РЕПЛИК — под будущие WAV (заменит звукорежиссёр):
        "ai_isolation": [],   # «Запускаю процедуру изоляции…»
        "ai_order_changed": [], # «Ранее я выполнял приказ. Теперь приказ изменился»
        "morozova_record": [], # запись доктора Морозовой из комнаты наблюдения
        "serov_wounded": [],   # диалог с Михаилом Серовым в мастерской
        "whisper_vent": [],    # шёпот из вентиляции: «Волков... не открывай...»
        "female_ward": [],     # женский голос в медсекторе: «Алексей, ты обещал вернуться»
        "operator_radio": [],  # оператор на поверхности: «Капитан Волков числится погибшим»
        "commander_radio": [], # командир группы зачистки: «Разрешение на ликвидацию получено»
        "v18_voice": [],       # «Ты опять опоздал»
        "memory_scream": [],   # крик «Капитан, отходите!» во вспышке памяти
}

# готовый список путей озвучки по ключу VOICE_MAP (пропускает пустые)
func voice_list(key: String) -> Array:
        var out: Array = []
        for f in VOICE_MAP.get(key, []):
                out.append(VDIR + str(f))
        return out

func _default_save() -> Dictionary:
        var commander_name: String = str(save.get("commander", "КОМАНДИР"))
        return {
                "commander": commander_name,
                "difficulty": 1,
                "kit": 0,
                "faction": "sak",
                "sector": 0,
                "bank": 0,
                "heli_unlocked": false,
                "upgrades": {"logistics": 0, "scouts": false, "repair": false, "prep": false, "trophy": false},
                "wins": 0, "battles": 0,
                "campaign_won": false,
                "poligon_passed": true,
                "total_losses": 0,
                "total_kills": 0,
        }

func _default_zsave() -> Dictionary:
        return {
                "seen_prologue": false,
                "sector": 0,
                "bank": 0,
                "wins": 0,
                "battles": 0,
                "diff": 1,
                "weapons": ["pistol"],
                "cur_weapon": "pistol",
                "ammo": {"pistol": 24, "smg": 0, "shotgun": 0, "rifle": 0},
                "inv": {"band": 3, "tq": 1, "splint": 0, "morph": 1, "abx": 0, "mag_pistol": 2, "mag_smg": 0, "mag_shotgun": 0, "mag_rifle": 0, "food": 1},
        "inv_slots": [],   # FIX7v2: расположение предметов по ячейкам рюкзака
                "squad": [],
                "diary": 0,
                "campaign_won": false,
                "zdiff": 1,
                "pvars": {},
        }

func reset_all_progress() -> void:
        var default_save: Dictionary = _default_save()
        var default_zsave: Dictionary = _default_zsave()
        for key in default_save.keys():
                save[key] = default_save[key]
        for key in default_zsave.keys():
                zsave[key] = default_zsave[key]
        write_save()

# ---------- настройки интерфейса (отдельная секция сохранения) ----------
var ui_scale := 1.0
var music_vol := 0.6
var sfx_vol := 0.9
var fullscreen := false
var music_track := "z"   # ЗАГЛУШКА: штатной музыки больше нет — см. README_MUSIC.txt

var sfx := {}
var music_player: AudioStreamPlayer = null
var sfx_count := 0

func _ready() -> void:
        _load_save()
        _load_sfx()
        _setup_audio_buses()
        _setup_sfx_pool()
        _apply_saved_settings()
        _start_music()
        # ФПС НА ТЕЛЕФОНАХ: рендерим в буфер 1280x720 и апскейлим на весь экран.
        # Нативные 2400x1080 жрут fill-rate — на слабых телефонах 5-9 FPS.
        # Бонус: при 720 логических пикселях интерфейс крупнее на ~25%.
        if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
                var w := get_window()
                w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
                w.content_scale_size = Vector2i(1280, 720)

func _init() -> void:
        _build_db()

# ================= СОХРАНЕНИЯ =================
func _load_save() -> void:
        var cfg := ConfigFile.new()
        if cfg.load("user://anklav_rts.cfg") == OK:
                save["commander"] = cfg.get_value("camp", "commander", save["commander"])
                save["difficulty"] = cfg.get_value("camp", "difficulty", save["difficulty"])
                save["kit"] = cfg.get_value("camp", "kit", save["kit"])
                save["faction"] = cfg.get_value("camp", "faction", save["faction"])
                save["sector"] = cfg.get_value("camp", "sector", save["sector"])
                save["bank"] = cfg.get_value("camp", "bank", save["bank"])
                save["heli_unlocked"] = cfg.get_value("camp", "heli_unlocked", save["heli_unlocked"])
                save["wins"] = cfg.get_value("camp", "wins", save["wins"])
                save["battles"] = cfg.get_value("camp", "battles", save["battles"])
                save["total_losses"] = int(cfg.get_value("camp", "total_losses", 0))
                save["total_kills"] = int(cfg.get_value("camp", "total_kills", 0))
                var up = cfg.get_value("camp", "upgrades", save["upgrades"])
                if up is Dictionary:
                        for k in up:
                                save["upgrades"][k] = up[k]
        # кампания «Земля мёртвых»
        var zs = cfg.get_value("zcamp", "zsave", null) if cfg.has_section_key("zcamp", "zsave") else null
        if zs is Dictionary:
                for k in zs:
                        zsave[k] = zs[k]
        if not (zsave["weapons"] is Array):
                zsave["weapons"] = ["pistol"]
        if not (zsave["squad"] is Array):
                zsave["squad"] = []
        if not (zsave["ammo"] is Dictionary):
                zsave["ammo"] = {"pistol": 24, "smg": 0, "shotgun": 0, "rifle": 0}
        if not (zsave["inv"] is Dictionary):
                zsave["inv"] = {}
        if not (zsave.get("zdiff") is int) or int(zsave["zdiff"]) < 0 or int(zsave["zdiff"]) > 2:
                zsave["zdiff"] = 1
        if not (zsave.get("pvars") is Dictionary):
                zsave["pvars"] = {}
        for pk in PVAR_DEFAULTS:
                if not zsave["pvars"].has(pk):
                        zsave["pvars"][pk] = false
        # настройки интерфейса
        # масштаб интерфейса больше НЕ настройка и не множитель поверх экрана:
        # вся адаптация делает stretch (canvas_items + expand) и вёрстка экранов
        ui_scale = 1.0
        music_vol = float(cfg.get_value("settings", "music_vol", 0.6))
        sfx_vol = float(cfg.get_value("settings", "sfx_vol", 0.9))
        fullscreen = bool(cfg.get_value("settings", "fullscreen", false))

func default_ui_scale() -> float:
        # 1.0: раньше здесь было 1.5 для мобильных — это множилось на stretch
        # и сжимало холст до ~1067x480, из-за чего меню «не влезало» в экран
        return 1.0

func write_save() -> void:
        if has_meta("qa8"): return
        var cfg := ConfigFile.new()
        cfg.set_value("camp", "commander", save["commander"])
        cfg.set_value("camp", "difficulty", save["difficulty"])
        cfg.set_value("camp", "kit", save["kit"])
        cfg.set_value("camp", "faction", save["faction"])
        cfg.set_value("camp", "sector", save["sector"])
        cfg.set_value("camp", "bank", save["bank"])
        cfg.set_value("camp", "heli_unlocked", save["heli_unlocked"])
        cfg.set_value("camp", "wins", save["wins"])
        cfg.set_value("camp", "battles", save["battles"])
        cfg.set_value("camp", "total_losses", int(save["total_losses"]))
        cfg.set_value("camp", "total_kills", int(save["total_kills"]))
        cfg.set_value("camp", "upgrades", save["upgrades"])
        cfg.set_value("zcamp", "zsave", zsave)
        cfg.set_value("settings", "music_vol", music_vol)
        cfg.set_value("settings", "sfx_vol", sfx_vol)
        cfg.set_value("settings", "fullscreen", fullscreen)
        cfg.save("user://anklav_rts.cfg")

# ================= НАСТРОЙКИ ИНТЕРФЕЙСА =================
func apply_ui_scale() -> void:
        var win := get_window()
        if win != null:
                # content_scale_factor жёстко 1.0: любые дополнительные множители
                # поверх stretch «съедали» холст, и интерфейс вылезал за экран
                win.content_scale_factor = 1.0

func set_music_vol(v: float) -> void:
        music_vol = clampf(v, 0.0, 1.0)
        if music_player != null:
                music_player.volume_db = linear_to_db(maxf(0.001, music_vol))

func set_sfx_vol(v: float) -> void:
        sfx_vol = clampf(v, 0.0, 1.0)
        var idx := AudioServer.get_bus_index("SFX")
        if idx >= 0:
                AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, sfx_vol)))

func set_fullscreen(on: bool) -> void:
        fullscreen = on
        if DisplayServer.get_name() == "headless":
                return
        if on:
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        else:
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_saved_settings() -> void:
        apply_ui_scale()
        set_music_vol(music_vol)
        set_sfx_vol(sfx_vol)
        # полный экран включаем только на десктопе, после готовности окна
        if fullscreen and DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"):
                set_fullscreen.call_deferred(true)

# ================= ЗВУК =================
func _setup_audio_buses() -> void:
        for bus_name in ["Music", "SFX"]:
                if AudioServer.get_bus_index(bus_name) == -1:
                        AudioServer.add_bus()
                        var idx: int = AudioServer.bus_count - 1
                        AudioServer.set_bus_name(idx, bus_name)
                        AudioServer.set_bus_send(idx, "Master")

func _load_sfx() -> void:
        var names := ["ui_click", "radio", "shot_mg", "shot_cannon", "cannon_far", "launch_atgm",
                "launch_sam", "launch_rocket", "expl_s", "expl_m", "expl_l", "artillery_whistle",
                "jet_flyby", "rotor_loop", "engine_loop", "capture", "alarm", "victory", "defeat"]
        # звуки кампании «Земля мёртвых»
        for zn in ["z_growl", "z_growl2", "z_growl3", "z_shriek", "z_bite", "z_hit", "z_spark",
                "z_metal", "z_tinnitus", "z_heart", "z_static", "z_hiss", "z_door", "z_pickup",
                "z_infect", "z_glass", "z_shot_pistol", "z_shot_smg", "z_shot_rifle",
                "z_shot_shotgun", "z_dry", "z_reload", "z_footstep", "z_voice_hurt",
                        "z_voice_gasp", "z_voice_effort", "z_voice_radio",
                # ---- SFX пролога «ЗАРЯ» (процедурная генерация) ----
                "z_hum_reactor", "z_vent_loop", "z_drip1", "z_drip2", "z_drip3", "z_relay",
                "z_whisper1", "z_whisper2", "z_siren_far", "z_siren_near", "z_radio_bed",
                "z_radio_beep", "z_lift_hit1", "z_lift_hit2", "z_lift_hit3", "z_hydro_loop",
                "z_hydro_overheat", "z_glass_hit1", "z_glass_hit2", "z_glass_hit3", "z_cough",
                "z_shock", "z_beep_alarm", "z_data_wipe", "z_foot_metal", "z_pressure_hiss",
                "z_ice_crack", "z_knife", "z_blast_close", "z_seal_lock", "z_memory_flash",
                "z_blizzard_loop"]:
                names.append(zn)
        for n in names:
                var p: String = ("res://assets/sfx/voice/%s.wav" % n.trim_prefix("z_")) if n.begins_with("z_voice_") else ("res://assets/sfx/%s.wav" % n)
                if ResourceLoader.exists(p):
                        sfx[n] = load(p)

# ---------- ПУЛ ЗВУКА (ФПС): ноды не создаются/не удаляются на каждый звук ----------
var _sfx_pool: Array = []          # готовые AudioStreamPlayer
var _sfx_pool_i := 0

func _setup_sfx_pool() -> void:
        for i in range(16):
                var p := AudioStreamPlayer.new()
                p.bus = "SFX"
                p.process_mode = Node.PROCESS_MODE_ALWAYS
                get_tree().root.add_child.call_deferred(p)
                _sfx_pool.append(p)

func play_sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
        if not sfx.has(sfx_name) or _sfx_pool.is_empty():
                return
        # свободный плеер ищем от курсора; если все заняты — забираем по кругу
        var p: AudioStreamPlayer = _sfx_pool[_sfx_pool_i]
        for i in range(_sfx_pool.size()):
                var cand: AudioStreamPlayer = _sfx_pool[(_sfx_pool_i + i) % _sfx_pool.size()]
                if not cand.playing:
                        p = cand
                        _sfx_pool_i = (_sfx_pool_i + i) % _sfx_pool.size()
                        break
        _sfx_pool_i = (_sfx_pool_i + 1) % _sfx_pool.size()
        p.stream = sfx[sfx_name]
        p.volume_db = volume_db
        p.pitch_scale = pitch * randf_range(0.93, 1.07)
        p.play()

func _start_music() -> void:
        _play_music_track(music_track)

func set_music_track(_track: String) -> void:
        # ЗАГЛУШКА МУЗЫКИ: штатных треков больше нет. Игра играет только СВОЙ трек
        # игрока (assets/sfx/music_user.wav / .ogg). Вызовы set_music_track оставлены
        # для совместимости — если трек уже играет, ничего не перезапускаем.
        if music_player != null and is_instance_valid(music_player):
                return
        _play_music_track(_track)

func _play_music_track(_track: String) -> void:
        # Music belongs to MainMenuScreen; never leak it into a battle.
        if is_instance_valid(music_player):
                music_player.stop()

func zdiff_mult() -> float:
        # множитель сложности зомби-кампании (по допуску)
        var d := int(zsave.get("diff", 1))
        return [1.0, 1.35, 1.8][clampi(d, 0, 2)]

func z_give_item(item: String, n := 1) -> void:
        zsave["inv"][item] = int(zsave["inv"].get(item, 0)) + n

func z_take_item(item: String, n := 1) -> bool:
        if int(zsave["inv"].get(item, 0)) < n:
                return false
        zsave["inv"][item] = int(zsave["inv"].get(item, 0)) - n
        return true

func z_sync_inv_slots() -> void:
        # FIX7v2: сетка рюкзака — фиксированные ячейки. Словарь inv (item → count)
        # остаётся источником правды по количеству; inv_slots хранит только то,
        # КАКОЙ тип предмета лежит в какой ячейке (пустая ячейка = "").
        if not (zsave.get("inv_slots") is Array):
                zsave["inv_slots"] = []
        var slots: Array = zsave["inv_slots"]
        var kept: Array = []
        for it in slots:
                var s := str(it)
                if s != "" and int(zsave["inv"].get(s, 0)) > 0 and not kept.has(s):
                        kept.append(s)
        for it in zsave["inv"]:
                if int(zsave["inv"][it]) > 0 and not kept.has(str(it)):
                        kept.append(str(it))
        while kept.size() < INV_SLOTS:
                kept.append("")
        zsave["inv_slots"] = kept.slice(0, INV_SLOTS)

func z_bank_add(v: int) -> void:
        zsave["bank"] = int(zsave["bank"]) + v

# ================= БАЗА ДАННЫХ ЮНИТОВ =================
var DB := {}

func _w(kind: String, d: float, rof: float, rng: float, ap: String, proj: String, ps: float, splash := 0.0, burst := 1, spr := 0.05, only := "", arc := false) -> Dictionary:
        return {"k": kind, "d": d, "rof": rof, "rng": rng, "ap": ap, "proj": proj, "ps": ps,
                "splash": splash, "burst": burst, "spr": spr, "only": only, "arc": arc}

func _build_db() -> void:
        DB.clear()
        # ================= САК =================
        DB["sak_rifle"] = {"name": "Мотострелковое отделение", "fac": "sak", "kind": "inf", "role": "infantry",
                "cost": 180, "build": 4.0, "hp": 240, "armor": "none", "spd": 52, "rot": 6.0, "vision": 430,
                "stealth": 1.0, "radius": 14, "hull": "inf_rifle_sak", "squad": ["rifle", "rifle", "rifle", "rifle", "rifle", "mg"],
                "wpns": [_w("mg", 6, 1.3, 430, "kinetic", "tracer", 1500, 0, 1, 0.10)],
                "desc": "6 бойцов, АК-74 и ПКМ. Универсальная пехота."}
        DB["sak_mg"] = {"name": "Пулемётный расчёт ПКМ", "fac": "sak", "kind": "inf", "role": "infantry",
                "cost": 220, "build": 4.0, "hp": 130, "armor": "none", "spd": 48, "rot": 6.0, "vision": 470,
                "stealth": 1.0, "radius": 12, "hull": "inf_mg_sak", "squad": ["mg", "rifle", "rifle"],
                "wpns": [_w("mg", 9, 4.5, 540, "kinetic", "tracer", 1600, 0, 1, 0.08)],
                "desc": "Град свинца: подавляет пехоту и лёгкие цели."}
        DB["sak_atgm"] = {"name": "Расчёт ПТУР «Фагот»", "fac": "sak", "kind": "inf", "role": "at",
                "cost": 320, "build": 5.0, "hp": 120, "armor": "none", "spd": 46, "rot": 6.0, "vision": 450,
                "stealth": 1.05, "radius": 12, "hull": "inf_at_sak", "squad": ["at", "rifle", "rifle"],
                "wpns": [_w("atgm", 120, 0.13, 900, "heat", "atgm", 260, 30, 1, 0.02)],
                "desc": "Управляемая ракета. Гроза танков на дистанции."}
        DB["sak_rpg"] = {"name": "Гранатомётчики РПГ-7", "fac": "sak", "kind": "inf", "role": "at",
                "cost": 240, "build": 4.0, "hp": 160, "armor": "none", "spd": 54, "rot": 6.0, "vision": 420,
                "stealth": 1.0, "radius": 12, "hull": "inf_rpg_sak", "squad": ["rpg", "rpg", "rifle", "rifle"],
                "wpns": [_w("rpg", 70, 0.3, 300, "heat", "shell", 700, 22, 1, 0.06)],
                "desc": "Ближний бой с бронетехникой. Держи их в укрытиях."}
        DB["sak_sniper"] = {"name": "Снайперская пара", "fac": "sak", "kind": "inf", "role": "recon",
                "cost": 200, "build": 4.0, "hp": 80, "armor": "none", "spd": 50, "rot": 6.0, "vision": 780,
                "stealth": 1.35, "radius": 10, "hull": "inf_sniper_sak", "squad": ["sniper", "sniper"],
                "wpns": [_w("sniper", 30, 0.5, 860, "kinetic", "tracer", 1800, 0, 1, 0.008)],
                "desc": "Дальний обзор 780 м. Глаза армии, целят орудия."}
        DB["sak_medic"] = {"name": "Медбригада", "fac": "sak", "kind": "inf", "role": "support",
                "cost": 250, "build": 5.0, "hp": 120, "armor": "none", "spd": 56, "rot": 6.0, "vision": 400,
                "stealth": 1.0, "radius": 12, "hull": "inf_med_sak", "squad": ["med", "med", "rifle"],
                "wpns": [_w("mg", 5, 0.8, 360, "kinetic", "tracer", 1400, 0, 1, 0.1)],
                "desc": "Аура лечения 110 м: останавливает кровь, поднимает раненых."}
        DB["sak_brdm"] = {"name": "БРМД-2 «Разведка»", "fac": "sak", "kind": "veh", "role": "recon",
                "cost": 240, "build": 6.0, "hp": 220, "armor": "light", "spd": 135, "rot": 3.4, "vision": 700,
                "stealth": 1.15, "radius": 16, "hull": "veh_brdm_sak",
                "wpns": [_w("mg", 7, 2.0, 480, "kinetic", "tracer", 1500, 0, 1, 0.07)],
                "desc": "Быстрая разведка: 700 м обзора, вскрывает засады."}
        DB["sak_btr"] = {"name": "БТР-82А", "fac": "sak", "kind": "veh", "role": "apc",
                "cost": 420, "build": 8.0, "hp": 340, "armor": "light", "spd": 110, "rot": 2.8, "vision": 500,
                "stealth": 1.0, "radius": 18, "hull": "veh_btr_sak", "tur": "tur_btr_sak", "tur_off": Vector2(-2, 0),
                "muzzle": Vector2(15, 0),
                "wpns": [_w("ac", 26, 2.2, 640, "apcr", "shell", 1050, 12, 1, 0.045)],
                "desc": "Колёсный бронетранспортёр, 30-мм автопушка."}
        DB["sak_bmp"] = {"name": "БМП-2", "fac": "sak", "kind": "veh", "role": "ifv",
                "cost": 520, "build": 9.0, "hp": 380, "armor": "med", "spd": 95, "rot": 2.6, "vision": 520,
                "stealth": 1.0, "radius": 18, "hull": "veh_bmp_sak", "tur": "tur_bmp_sak", "tur_off": Vector2(-4, 0),
                "muzzle": Vector2(15, 0),
                "wpns": [_w("ac", 26, 2.4, 660, "apcr", "shell", 1050, 12, 1, 0.045),
                        _w("atgm", 110, 0.10, 880, "heat", "atgm", 250, 28, 1, 0.02)],
                "desc": "Основа мехвойск: 30-мм пушка + ПТУР."}
        DB["sak_t72"] = {"name": "Т-72Б3", "fac": "sak", "kind": "veh", "role": "tank",
                "cost": 850, "build": 13.0, "hp": 850, "armor": "heavy", "spd": 78, "rot": 2.0, "vision": 480,
                "stealth": 0.9, "radius": 22, "hull": "veh_tank_sak", "tur": "tur_tank_sak", "tur_off": Vector2(-2, 0),
                "muzzle": Vector2(24, 0),
                "wpns": [_w("cannon", 95, 0.28, 780, "apcr", "shell", 1150, 26, 1, 0.025),
                        _w("mg", 7, 3.0, 500, "kinetic", "tracer", 1500, 0, 1, 0.08)],
                "desc": "Основной боевой танк. 125-мм гладкоствольная."}
        DB["sak_shilka"] = {"name": "ЗСУ-23-4 «Шилка»", "fac": "sak", "kind": "veh", "role": "aa",
                "cost": 480, "build": 9.0, "hp": 380, "armor": "med", "spd": 80, "rot": 2.4, "vision": 560,
                "stealth": 1.0, "radius": 20, "hull": "veh_shilka_sak",
                "wpns": [_w("flak", 12, 7.0, 640, "frag", "flak", 1000, 10, 1, 0.06, "air"),
                        _w("flak", 10, 4.0, 460, "frag", "flak", 1000, 8, 1, 0.07, "ground")],
                "desc": "Зенитный счетверённый автомат. Сбивает всё, что летает."}
        DB["sak_msta"] = {"name": "2С19 «Мста-С»", "fac": "sak", "kind": "veh", "role": "arty",
                "cost": 700, "build": 12.0, "hp": 360, "armor": "med", "spd": 70, "rot": 2.0, "vision": 330,
                "stealth": 1.0, "radius": 22, "hull": "veh_spg_sak", "tur": "tur_spg_sak", "tur_off": Vector2(-4, 0),
                "muzzle": Vector2(26, 0), "min_rng": 500,
                "wpns": [_w("howitzer", 110, 0.06, 1700, "he", "arcshell", 0, 110, 1, 0.03, "ground", true)],
                "desc": "152-мм САУ. Бьёт из-за холмов — нужен корректировщик."}
        DB["sak_grad"] = {"name": "БМ-21 «Град»", "fac": "sak", "kind": "veh", "role": "arty",
                "cost": 650, "build": 11.0, "hp": 320, "armor": "light", "spd": 82, "rot": 2.2, "vision": 300,
                "stealth": 1.0, "radius": 22, "hull": "veh_mlrs_sak", "min_rng": 700,
                "wpns": [_w("mlrs", 70, 0.5, 1900, "he", "arcshell", 0, 80, 12, 0.05, "ground", true)],
                "desc": "Залп 40 реактивных снарядов по площади."}
        DB["sak_ural"] = {"name": "Урал-4320 (снабжение)", "fac": "sak", "kind": "veh", "role": "supply", "cargo": true,
                "cost": 200, "build": 5.0, "hp": 280, "armor": "light", "spd": 100, "rot": 2.4, "vision": 380,
                "stealth": 1.0, "radius": 18, "hull": "veh_supply_sak",
                "wpns": [], "repair": true,
                "desc": "Ремонтная аура 130 м: латает броню и технику."}
        DB["sak_cmd"] = {"name": "КШМ «Купол»", "fac": "sak", "kind": "veh", "role": "cmd",
                "cost": 350, "build": 7.0, "hp": 260, "armor": "light", "spd": 92, "rot": 2.4, "vision": 600,
                "stealth": 1.0, "radius": 18, "hull": "veh_cmd_sak",
                "wpns": [], "cmd_aura": true,
                "desc": "Штаб на колёсах: +12% к обзору и точности рядом."}
        DB["sak_heli"] = {"name": "Ми-24 «Крокодил»", "fac": "sak", "kind": "heli", "role": "air",
                "cost": 900, "build": 10.0, "hp": 420, "armor": "light", "spd": 185, "rot": 2.4, "vision": 800,
                "stealth": 1.0, "radius": 26, "hull": "veh_heli_sak", "air": true,
                "wpns": [_w("rockets", 45, 0.9, 640, "he", "rocket", 800, 42, 4, 0.05),
                        _w("mg", 8, 4.0, 560, "kinetic", "tracer", 1600, 0, 1, 0.06)],
                "desc": "Штурмовой вертолёт. Требует ПВО прикрытия."}
        # ================= ФОА =================
        DB["foa_militia"] = {"name": "Отряд ополчения", "fac": "foa", "kind": "inf", "role": "infantry",
                "cost": 120, "build": 3.0, "hp": 230, "armor": "none", "spd": 50, "rot": 6.0, "vision": 380,
                "stealth": 1.1, "radius": 14, "hull": "inf_militia_foa", "squad": ["militia", "militia", "militia", "militia", "militia", "militia", "rifle", "militia"],
                "wpns": [_w("mg", 5, 1.1, 380, "kinetic", "tracer", 1400, 0, 1, 0.13)],
                "desc": "Много, дёшево, злые. Числом и внезапностью."}
        DB["foa_vet"] = {"name": "Отряд ветеранов", "fac": "foa", "kind": "inf", "role": "infantry",
                "cost": 240, "build": 4.0, "hp": 220, "armor": "none", "spd": 56, "rot": 6.0, "vision": 440,
                "stealth": 1.15, "radius": 13, "hull": "inf_vet_foa", "squad": ["vet", "vet", "vet", "rifle", "mg"],
                "wpns": [_w("mg", 8, 1.6, 470, "kinetic", "tracer", 1550, 0, 1, 0.08)],
                "desc": "Дезертиры с опытом. Бьют метко, прячутся умело."}
        DB["foa_spg9"] = {"name": "Расчёт СПГ-9 «Копьё»", "fac": "foa", "kind": "inf", "role": "at",
                "cost": 280, "build": 4.0, "hp": 110, "armor": "none", "spd": 44, "rot": 5.0, "vision": 430,
                "stealth": 1.05, "radius": 13, "hull": "prop_spg9", "squad": ["rifle", "rifle"],
                "wpns": [_w("rpg", 85, 0.28, 620, "heat", "shell", 850, 22, 1, 0.04)],
                "desc": "Безоткатка на станке. Пехотная противотанковая артиллерия."}
        DB["foa_igla"] = {"name": "Расчёт ПЗРК «Игла»", "fac": "foa", "kind": "inf", "role": "aa",
                "cost": 320, "build": 5.0, "hp": 100, "armor": "none", "spd": 48, "rot": 6.0, "vision": 520,
                "stealth": 1.1, "radius": 11, "hull": "inf_manpads_foa", "squad": ["manpads", "rifle"],
                "wpns": [_w("sam", 70, 0.12, 820, "sam", "sam", 620, 14, 1, 0.02, "air")],
                "desc": "Переносной ЗРК. Небо не пустует."}
        DB["foa_sniper"] = {"name": "Снайпер ФОА", "fac": "foa", "kind": "inf", "role": "recon",
                "cost": 180, "build": 4.0, "hp": 70, "armor": "none", "spd": 52, "rot": 6.0, "vision": 760,
                "stealth": 1.4, "radius": 9, "hull": "inf_sniper_sak", "squad": ["sniper"],
                "wpns": [_w("sniper", 34, 0.45, 880, "kinetic", "tracer", 1800, 0, 1, 0.008)],
                "desc": "Один выстрел — один труп. Максимальная маскировка."}
        DB["foa_tech_zu"] = {"name": "Техничка с ЗУ-23", "fac": "foa", "kind": "veh", "role": "aa",
                "cost": 260, "build": 6.0, "hp": 170, "armor": "light", "spd": 150, "rot": 3.2, "vision": 540,
                "stealth": 1.0, "radius": 16, "hull": "veh_tech_zu23_foa",
                "wpns": [_w("flak", 10, 6.0, 600, "frag", "flak", 1000, 9, 1, 0.07, "air"),
                        _w("flak", 9, 3.5, 480, "frag", "flak", 1000, 8, 1, 0.08, "ground")],
                "desc": "Пикап со спаркой ЗУ-23. ПВО и поддержка пехоты."}
        DB["foa_tech_atgm"] = {"name": "Техничка с ПТУР", "fac": "foa", "kind": "veh", "role": "at",
                "cost": 340, "build": 7.0, "hp": 170, "armor": "light", "spd": 145, "rot": 3.2, "vision": 520,
                "stealth": 1.0, "radius": 16, "hull": "veh_tech_atgm_foa",
                "wpns": [_w("atgm", 115, 0.11, 880, "heat", "atgm", 260, 28, 1, 0.02), _w("mg", 5, 1.0, 420, "kinetic", "tracer", 1400, 0, 1, 0.1)],
                "desc": "Пусковая на пикапе. Выстрелил — уехал."}
        DB["foa_tech_mg"] = {"name": "Боевая техничка", "fac": "foa", "kind": "veh", "role": "recon",
                "cost": 200, "build": 5.0, "hp": 160, "armor": "light", "spd": 160, "rot": 3.4, "vision": 500,
                "stealth": 1.05, "radius": 16, "hull": "veh_tech_mg_foa",
                "wpns": [_w("mg", 8, 3.2, 500, "kinetic", "tracer", 1550, 0, 1, 0.08)],
                "desc": "Пулемёт в кузове. Рейды по флангам."}
        DB["foa_btr60"] = {"name": "Трофейный БТР-60", "fac": "foa", "kind": "veh", "role": "apc",
                "cost": 300, "build": 7.0, "hp": 300, "armor": "light", "spd": 100, "rot": 2.6, "vision": 460,
                "stealth": 1.0, "radius": 18, "hull": "veh_btr_foa", "tur": "tur_btr_sak", "tur_off": Vector2(-2, 0),
                "muzzle": Vector2(15, 0),
                "wpns": [_w("ac", 20, 1.8, 560, "apcr", "shell", 950, 10, 1, 0.055)],
                "desc": "Угнанный у САК бронетранспортёр."}
        DB["foa_t62"] = {"name": "Т-62 (трофейный)", "fac": "foa", "kind": "veh", "role": "tank",
                "cost": 600, "build": 11.0, "hp": 700, "armor": "heavy", "spd": 72, "rot": 1.9, "vision": 440,
                "stealth": 0.9, "radius": 22, "hull": "veh_tank_foa", "tur": "tur_tank_foa", "tur_off": Vector2(-2, 0),
                "muzzle": Vector2(24, 0),
                "wpns": [_w("cannon", 82, 0.26, 720, "apcr", "shell", 1050, 24, 1, 0.03),
                        _w("mg", 6, 2.4, 460, "kinetic", "tracer", 1450, 0, 1, 0.09)],
                "desc": "Старый, но всё ещё танк. Стучит 115-мм."}
        DB["foa_mortar"] = {"name": "Миномётный расчёт", "fac": "foa", "kind": "inf", "role": "arty",
                "cost": 300, "build": 5.0, "hp": 100, "armor": "none", "spd": 44, "rot": 5.0, "vision": 320,
                "stealth": 1.1, "radius": 12, "hull": "prop_mortar", "squad": ["rifle", "rifle", "rifle"],
                "min_rng": 300,
                "wpns": [_w("howitzer", 60, 0.14, 1150, "he", "arcshell", 0, 70, 1, 0.04, "ground", true)],
                "desc": "82-мм миномёт: навесом через любые холмы."}
        DB["foa_sapper"] = {"name": "Сапёр ФОА (СВУ)", "fac": "foa", "kind": "inf", "role": "special",
                "cost": 200, "build": 4.0, "hp": 90, "armor": "none", "spd": 54, "rot": 6.0, "vision": 400,
                "stealth": 1.2, "radius": 11, "hull": "inf_sapper_foa", "squad": ["sapper"],
                "wpns": [_w("mg", 5, 0.7, 320, "kinetic", "tracer", 1300, 0, 1, 0.12)],
                "mines": 6,
                "desc": "Минирует дороги на марше. СВУ рвутся под техникой."}
        DB["foa_drone"] = {"name": "Дрон-камикадзе FPV", "fac": "foa", "kind": "drone", "role": "air",
                "cost": 220, "build": 4.0, "hp": 25, "armor": "none", "spd": 330, "rot": 9.0, "vision": 700,
                "stealth": 1.0, "radius": 8, "hull": "veh_drone_foa", "air": true,
                "wpns": [_w("kamikaze", 180, 1.0, 100000.0, "heat", "", 0, 80, 1, 0)],
                "desc": "Коммерческий квадрокоптер с зарядом. Одноразовый."}
        DB["foa_ural"] = {"name": "Урал ФОА (снабжение)", "fac": "foa", "kind": "veh", "role": "supply", "cargo": true,
                "cost": 180, "build": 5.0, "hp": 260, "armor": "light", "spd": 96, "rot": 2.4, "vision": 360,
                "stealth": 1.0, "radius": 18, "hull": "veh_supply_foa",
                "wpns": [], "repair": true,
                "desc": "Трофейный ремонтный обоз."}
        DB["foa_med"] = {"name": "Полевые медики ФОА", "fac": "foa", "kind": "inf", "role": "support",
                "cost": 220, "build": 4.0, "hp": 110, "armor": "none", "spd": 54, "rot": 6.0, "vision": 400,
                "stealth": 1.05, "radius": 12, "hull": "inf_med_sak", "squad": ["med", "med", "militia"],
                "wpns": [_w("mg", 5, 0.8, 360, "kinetic", "tracer", 1400, 0, 1, 0.1)],
                "desc": "Аура лечения 110 м."}
        # ================= ШАКАЛ =================
        DB["jack_m4"] = {"name": "Наёмники (M4A1)", "fac": "jack", "kind": "inf", "role": "infantry",
                "cost": 220, "build": 4.0, "hp": 225, "armor": "none", "spd": 54, "rot": 6.0, "vision": 440,
                "stealth": 1.05, "radius": 13, "hull": "inf_rifle_jack", "squad": ["rifle", "rifle", "rifle", "rifle", "mg"],
                "wpns": [_w("mg", 7, 1.5, 450, "kinetic", "tracer", 1550, 0, 1, 0.08)],
                "desc": "Профессионалы ЧВК «Орион». Натовские стволы, оптика."}
        DB["jack_assault"] = {"name": "Штурмовая группа", "fac": "jack", "kind": "inf", "role": "infantry",
                "cost": 260, "build": 4.0, "hp": 230, "armor": "none", "spd": 58, "rot": 6.0, "vision": 410,
                "stealth": 1.0, "radius": 13, "hull": "inf_vet_foa", "squad": ["vet", "vet", "vet", "rpg"],
                "wpns": [_w("mg", 9, 1.8, 340, "kinetic", "tracer", 1500, 0, 1, 0.09),
                        _w("rpg", 65, 0.22, 280, "heat", "shell", 700, 20, 1, 0.07)],
                "desc": "Сайга-12 и РПГ. Зачистка зданий и окопов."}
        DB["jack_m2"] = {"name": "Расчёт M2 Browning", "fac": "jack", "kind": "inf", "role": "infantry",
                "cost": 260, "build": 4.0, "hp": 130, "armor": "none", "spd": 48, "rot": 6.0, "vision": 480,
                "stealth": 1.0, "radius": 12, "hull": "inf_mg_sak", "squad": ["mg", "rifle", "rifle"],
                "wpns": [_w("mg", 10, 4.0, 560, "kinetic", "tracer", 1600, 0, 1, 0.07)],
                "desc": "Крупнокалиберный «Пять-ноль». Пробивает БТР."}
        DB["jack_javelin"] = {"name": "Расчёт Javelin", "fac": "jack", "kind": "inf", "role": "at",
                "cost": 380, "build": 6.0, "hp": 120, "armor": "none", "spd": 46, "rot": 6.0, "vision": 460,
                "stealth": 1.05, "radius": 12, "hull": "inf_at_sak", "squad": ["at", "rifle"],
                "wpns": [_w("atgm", 135, 0.10, 920, "heat", "atgm", 280, 32, 1, 0.015)],
                "desc": "Атакует сверху — брони не хватает никому."}
        DB["jack_sniper"] = {"name": "Снайпер ЧВК (ПНВ)", "fac": "jack", "kind": "inf", "role": "recon",
                "cost": 220, "build": 4.0, "hp": 75, "armor": "none", "spd": 50, "rot": 6.0, "vision": 800,
                "stealth": 1.35, "radius": 9, "hull": "inf_sniper_jack", "squad": ["sniper"],
                "wpns": [_w("sniper", 32, 0.5, 900, "kinetic", "tracer", 1850, 0, 1, 0.007)],
                "desc": "Видит в темноте. Обзор 800 м."}
        DB["jack_recon"] = {"name": "Развед-Хамви", "fac": "jack", "kind": "veh", "role": "recon",
                "cost": 260, "build": 6.0, "hp": 200, "armor": "light", "spd": 140, "rot": 3.4, "vision": 680,
                "stealth": 1.1, "radius": 16, "hull": "veh_brdm_jack",
                "wpns": [_w("mg", 7, 2.0, 480, "kinetic", "tracer", 1500, 0, 1, 0.07)],
                "desc": "Скорость и оптика: вскрывает карту противника."}
        DB["jack_hm_mk19"] = {"name": "Хамви Mk.19", "fac": "jack", "kind": "veh", "role": "ifv",
                "cost": 320, "build": 7.0, "hp": 210, "armor": "light", "spd": 135, "rot": 3.2, "vision": 500,
                "stealth": 1.0, "radius": 16, "hull": "veh_mk19_jack", "tur": "tur_humvee_jack", "tur_off": Vector2(2, 0),
                "muzzle": Vector2(13, 0),
                "wpns": [_w("ac", 20, 2.6, 600, "he", "shell", 950, 18, 1, 0.05)],
                "desc": "40-мм автоматический гранатомёт. Косит пехоту."}
        DB["jack_hm_tow"] = {"name": "Хамви TOW", "fac": "jack", "kind": "veh", "role": "at",
                "cost": 380, "build": 7.0, "hp": 210, "armor": "light", "spd": 135, "rot": 3.2, "vision": 540,
                "stealth": 1.0, "radius": 16, "hull": "veh_tow_jack",
                "wpns": [_w("atgm", 125, 0.10, 900, "heat", "atgm", 270, 30, 1, 0.018)],
                "desc": "ПТУР на крыше. Урон по броне стабильный."}
        DB["jack_m113"] = {"name": "M113 (ЧВК)", "fac": "jack", "kind": "veh", "role": "apc",
                "cost": 340, "build": 8.0, "hp": 320, "armor": "light", "spd": 100, "rot": 2.6, "vision": 470,
                "stealth": 1.0, "radius": 18, "hull": "veh_m113_jack", "tur": "tur_humvee_jack", "tur_off": Vector2(-2, 0),
                "muzzle": Vector2(13, 0),
                "wpns": [_w("mg", 9, 2.4, 520, "kinetic", "tracer", 1550, 0, 1, 0.07)],
                "desc": "Гусеничный бронекапсула наёмников."}
        DB["jack_m60"] = {"name": "M60A3 (куплен у тыла)", "fac": "jack", "kind": "veh", "role": "tank",
                "cost": 700, "build": 12.0, "hp": 820, "armor": "heavy", "spd": 74, "rot": 2.0, "vision": 470,
                "stealth": 0.9, "radius": 22, "hull": "veh_tank_jack", "tur": "tur_tank_jack", "tur_off": Vector2(-2, 0),
                "muzzle": Vector2(24, 0),
                "wpns": [_w("cannon", 90, 0.27, 760, "apcr", "shell", 1100, 25, 1, 0.026),
                        _w("mg", 7, 2.8, 500, "kinetic", "tracer", 1500, 0, 1, 0.08)],
                "desc": "Старый американский МБТ со складов ЧВК."}
        DB["jack_stinger"] = {"name": "Хамви ПВО (Stinger)", "fac": "jack", "kind": "veh", "role": "aa",
                "cost": 360, "build": 8.0, "hp": 200, "armor": "light", "spd": 130, "rot": 3.2, "vision": 580,
                "stealth": 1.0, "radius": 16, "hull": "veh_stinger_jack",
                "wpns": [_w("sam", 75, 0.14, 840, "sam", "sam", 640, 14, 1, 0.02, "air")],
                "desc": "ЗРК на шасси Хамви. Воздушная блокада."}
        DB["jack_m109"] = {"name": "M109 (ЧВК)", "fac": "jack", "kind": "veh", "role": "arty",
                "cost": 720, "build": 12.0, "hp": 350, "armor": "med", "spd": 70, "rot": 2.0, "vision": 330,
                "stealth": 1.0, "radius": 22, "hull": "veh_spg_jack", "tur": "tur_spg_jack", "tur_off": Vector2(-4, 0),
                "muzzle": Vector2(26, 0), "min_rng": 500,
                "wpns": [_w("howitzer", 105, 0.06, 1650, "he", "arcshell", 0, 105, 1, 0.03, "ground", true)],
                "desc": "155-мм самоходная гаубица."}
        DB["jack_smersh"] = {"name": "«Смерч-Т» (трофей)", "fac": "jack", "kind": "veh", "role": "arty",
                "cost": 680, "build": 11.0, "hp": 310, "armor": "light", "spd": 78, "rot": 2.2, "vision": 300,
                "stealth": 1.0, "radius": 22, "hull": "veh_mlrs_jack", "min_rng": 650,
                "wpns": [_w("mlrs", 65, 0.45, 1800, "he", "arcshell", 0, 78, 10, 0.05, "ground", true)],
                "desc": "РСЗО из разграбленных складов."}
        DB["jack_supply"] = {"name": "Обоз ЧВК", "fac": "jack", "kind": "veh", "role": "supply", "cargo": true,
                "cost": 200, "build": 5.0, "hp": 270, "armor": "light", "spd": 98, "rot": 2.4, "vision": 380,
                "stealth": 1.0, "radius": 18, "hull": "veh_supply_jack",
                "wpns": [], "repair": true,
                "desc": "Ремонтная аура 130 м."}
        DB["jack_cmd"] = {"name": "Командный Хамви", "fac": "jack", "kind": "veh", "role": "cmd",
                "cost": 350, "build": 7.0, "hp": 250, "armor": "light", "spd": 96, "rot": 2.4, "vision": 620,
                "stealth": 1.0, "radius": 16, "hull": "veh_cmd_jack",
                "wpns": [], "cmd_aura": true,
                "desc": "Центр связи ЧВК: +12% к обзору и точности."}
        DB["jack_heli"] = {"name": "Вертолёт ЧВК", "fac": "jack", "kind": "heli", "role": "air",
                "cost": 900, "build": 10.0, "hp": 400, "armor": "light", "spd": 180, "rot": 2.4, "vision": 780,
                "stealth": 1.0, "radius": 26, "hull": "veh_heli_jack", "air": true,
                "wpns": [_w("rockets", 42, 0.85, 620, "he", "rocket", 800, 40, 4, 0.05),
                        _w("mg", 8, 3.8, 540, "kinetic", "tracer", 1600, 0, 1, 0.06)],
                "desc": "Ударный вертолёт наёмников."}

        # ================= КОМАНДИРЫ (герой игрока, за него играем) =================
        for fac in ["sak", "foa", "jack"]:
                var nm := "Командир «Заря-1»" if fac == "sak" else ("Командир ФОА" if fac == "foa" else "Командир ЧВК")
                DB[fac + "_cmdr"] = {"name": nm, "fac": fac, "kind": "inf", "role": "cmd", "hero": true,
                        "cost": 0, "build": 1.0, "hp": 230, "armor": "none", "spd": 68, "rot": 6.0, "vision": 640,
                        "stealth": 1.0, "radius": 10, "hull": "inf_cmd_" + fac, "squad": ["cmd"],
                        "wpns": [_w("mg", 8, 1.7, 470, "kinetic", "tracer", 1550, 0, 1, 0.07)],
                        "desc": "Вы. Едиственный. Джойстики: левый — идти, правый — целиться и стрелять."}

        # способности (для панели вызова)
        DB["_ab_air"] = {"name": "Авиаудар Су-25", "cost": 600, "icon": "icon_ab_air"}
        DB["_ab_arty"] = {"name": "Артиллерийский налёт", "cost": 450, "icon": "icon_ab_arty"}
        DB["_ab_smoke"] = {"name": "Дымовая завеса", "cost": 150, "icon": "icon_ab_smoke"}
        DB["_ab_mines"] = {"name": "Минирование", "cost": 250, "icon": "icon_ab_mines"}
        DB["_ab_drones"] = {"name": "Стая дронов", "cost": 400, "icon": "icon_ab_drones"}

# ---------- помощники ----------
func units_of(faction: String) -> Array:
        var res := []
        for id in DB:
                if id.begins_with("_"):
                        continue
                if DB[id]["fac"] == faction:
                        res.append(id)
        return res

func ability_list(faction: String) -> Array:
        match faction:
                "foa":
                        return ["_ab_drones", "_ab_mines", "_ab_smoke", "_ab_arty"]
                "jack":
                        return ["_ab_air", "_ab_arty", "_ab_smoke"]
                _:
                        return ["_ab_air", "_ab_arty", "_ab_smoke"]

func cost_for(id: String, kit: int) -> int:
        var c: int = DB[id]["cost"]
        if kit == 2 and DB[id]["kind"] != "inf":
                c = int(c * 0.85)
        return c

var _tex_cache: Dictionary = {}
func tex(path: String) -> Texture2D:
        # ОПТИМИЗАЦИЯ: кэш — вызовы из _draw идут каждый кадр
        if _tex_cache.has(path):
                return _tex_cache[path]
        var p := "res://assets/sprites/%s.png" % path
        var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
        _tex_cache[path] = t
        return t