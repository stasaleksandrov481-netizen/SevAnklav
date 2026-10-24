# ============================================================
# SCENECHECK — ДОВОЛЬНАЯ ПРОВЕРКА РУКОПИСНОЙ СЦЕНЫ (.tscn) ДО ЗАГРУЗКИ
#
# ЗАЧЕМ: локации (Bunker_Zarya.tscn, Surface.tscn) часто правят
# вручную — двигают мебель, добавляют пропы. Одна потерянная скобка
# или опечатка в Vector2/Rect2/Color — и сцена перестаёт загружаться,
# а Godot показывает только сухую красную строку. SceneCheck читает
# файл как ТЕКСТ и по-русски объясняет, что именно сломано и в какой
# строке, чтобы сцену можно было починить (или игра собрала уровень
# из резервной планировки и осталась проходимой).
#
# Проверки:
#   1. файл существует и читается;
#   2. баланс скобок ( ) [ ] { } с учётом кавычек;
#   3. синтаксис Vector2/Rect2/Color (число аргументов, только числа);
#   4. каждый ext_resource path существует в проекте;
#   5. ссылки parent="..." указывают на существующие ноды,
#      имена нод в пределах родителя не дублируются;
#   6. (для локаций) есть хотя бы один def_type="spawn" и def_type="zone".
#
# Использование:
#   var errs := SceneCheck.validate_tscn("res://scenes/locations/Bunker_Zarya.tscn", true)
#   if not errs.is_empty(): ...
# ============================================================
class_name SceneCheck
extends RefCounted

const KNOWN_DEF_TYPES := ["zone", "wall", "room", "door", "prop", "spr", "light_lab", "light_red", "blood", "corpse", "zombie", "spawn"]

const ARG_COUNT := {
        "Vector2": 2, "Vector2i": 2,
        "Rect2": 4, "Rect2i": 4,
        "Color": 4,
}


static func validate_tscn(path: String, need_level_defs := false) -> PackedStringArray:
        var errs: PackedStringArray = []
        var f := FileAccess.open(path, FileAccess.READ)
        if f == null:
                errs.append("Файл не найден или не читается: %s (код %d)" % [path, FileAccess.get_open_error()])
                return errs
        var lines: PackedStringArray = f.get_as_text().split("\n")
        f.close()

        var depth := 0
        var depth_line := 0
        var node_paths := {}          # "A/B/C" -> true (все известные ноды)
        var siblings := {}            # "путь_родителя/имя" — для поиска дублей
        var node_stack := []          # пути родителей для вложенных нод
        var root_seen := false
        var has_spawn := false
        var has_zone := false
        var ext_count := 0
        var in_node := false
        var cur_node_path := ""
        var cur_parent := "."
        var cur_node_line := 0

        for i in range(lines.size()):
                var raw := lines[i]
                var ln := i + 1
                var s := strip_strings(raw)
                # --- баланс скобок ---
                for ch in s:
                        if ch == "(" or ch == "[" or ch == "{":
                                depth += 1
                        elif ch == ")" or ch == "]" or ch == "}":
                                depth -= 1
                                if depth < 0:
                                        errs.append("строка %d: лишняя закрывающая скобка «%s»" % [ln, ch])
                                        depth = 0
                if depth > 0 and depth_line == 0:
                        depth_line = ln

                var t := raw.strip_edges()

                # --- ext_resource: файл должен существовать ---
                if t.begins_with("[ext_resource "):
                        ext_count += 1
                        var p := extract_str(t, "path")
                        if p == "":
                                errs.append("строка %d: у ext_resource нет path" % ln)
                        elif not ResourceLoader.exists(p):
                                errs.append("строка %d: ext_resource указывает на несуществующий файл: %s" % [ln, p])

                # --- заголовок ноды ---
                if t.begins_with("[node "):
                        in_node = true
                        cur_node_line = ln
                        var nm := extract_str(t, "name")
                        cur_parent = extract_str(t, "parent")
                        if cur_parent == "":
                                # корневая нода (без parent)
                                if root_seen:
                                        errs.append("строка %d: вторая корневая нода «%s» — корень должен быть один" % [ln, nm])
                                root_seen = true
                                cur_node_path = nm
                                node_stack = [nm]
                        else:
                                # parent может быть "../..", "Prop1", "Prop1/Spr" — проверяем префиксы
                                var base := cur_parent
                                if base.begins_with("../"):
                                        errs.append("строка %d: нода «%s» ссылается выше корня (parent=\"%s\")" % [ln, nm, base])
                                        base = ""
                                var ok := true
                                if base != "." and base != "":
                                        if not node_paths.has(base):
                                                errs.append("строка %d: у ноды «%s» родитель «%s» не найден (переименован или удалён?)" % [ln, nm, base])
                                                ok = false
                                cur_node_path = ("" if base == "." else base) + ("/" if base != "." and base != "" else "") + nm
                                var sib_key := ("" if base == "." else base) + "::" + nm
                                if siblings.has(sib_key):
                                        errs.append("строка %d: дубликат имени ноды «%s» внутри «%s» — Godot не загрузит сцену. Переименуйте одну из нод." % [ln, nm, base])
                                siblings[sib_key] = true
                                if ok:
                                        node_paths[cur_node_path] = true
                                        node_stack.append(cur_node_path)
                        continue

                # --- конец секции ноды (следующая [секция] закрывает текущую) ---
                if in_node and t.begins_with("[") and not t.begins_with("[node "):
                        in_node = false

                # --- свойства внутри ноды ---
                if in_node and t.contains("=") and not t.begins_with("["):
                        var eq := t.find("=")
                        var key := t.substr(0, eq).strip_edges()
                        var val := t.substr(eq + 1).strip_edges()
                        if key == "def_type":
                                var dv := val.trim_prefix("\"").trim_suffix("\"")
                                if dv == "spawn":
                                        has_spawn = true
                                elif dv == "zone":
                                        has_zone = true
                                if not KNOWN_DEF_TYPES.has(dv):
                                        errs.append("строка %d: неизвестный def_type «%s» (допустимо: %s)" % [ln, dv, ", ".join(KNOWN_DEF_TYPES)])
                        # синтаксис векторных/цветных значений
                        for ctype in ARG_COUNT:
                                if val.begins_with(ctype + "("):
                                        var ve := check_vec(val, ctype, ln)
                                        if ve != "":
                                                errs.append(ve)
                                        break

        if depth != 0:
                errs.append("файл кончился с незакрытыми скобками: %d (начало на строке %d) — скорее всего потеряна «)» или «]»" % [depth, depth_line])
        if not root_seen:
                errs.append("в сцене нет ни одной корневой ноды — файл повреждён")

        if need_level_defs:
                if not has_spawn:
                        errs.append("нет ни одной ноды с def_type = \"spawn\" — игроку негде появиться (нода PlayerSpawn удалена или переименована?)")
                if not has_zone:
                        errs.append("нет ни одной ноды с def_type = \"zone\" — у уровня нет пола")
        return errs


# Проверка Vector2(x, y) / Rect2(x, y, w, h) / Color(r, g, b, a)
static func check_vec(val: String, ctype: String, ln: int) -> String:
        var inner := val.substr(ctype.length() + 1)
        var close := inner.rfind(")")
        if close == -1:
                return "строка %d: %s(...) без закрывающей скобки: «%s»" % [ln, ctype, val]
        inner = inner.substr(0, close)
        var parts := inner.split(",")
        var need := int(ARG_COUNT[ctype])
        # Color может быть 3 или 4 аргумента
        if ctype == "Color" and parts.size() == 3:
                need = 3
        if parts.size() != need:
                return "строка %d: %s ожидает %d аргумента(ов), найдено %d: «%s»" % [ln, ctype, need, parts.size(), val]
        for p in parts:
                var t := p.strip_edges()
                if t == "":
                        return "строка %d: пустой аргумент в «%s»" % [ln, val]
                var tt := t.trim_prefix("-")
                if tt == "":
                        return "строка %d: в «%s» не число: «%s»" % [ln, val, t]
                for ch in tt:
                        if not ((ch >= "0" and ch <= "9") or ch == "."):
                                return "строка %d: в «%s» не число: «%s»" % [ln, val, t]
        return ""


static func extract_str(s: String, key: String) -> String:
        var needle := key + "=\""
        var a := s.find(needle)
        if a == -1:
                return ""
        a += needle.length()
        var b := s.find("\"", a)
        if b == -1:
                return ""
        return s.substr(a, b - a)


static func strip_strings(s: String) -> String:
        var out := ""
        var in_str := false
        for ch in s:
                if ch == "\"":
                        in_str = not in_str
                        continue
                if not in_str:
                        out += ch
        return out


# Удобный вывод: единый текст отчёта (для push_error/журнала)
static func report(path: String, errs: PackedStringArray) -> String:
        var out := "Проверка сцены %s — проблем: %d" % [path.get_file(), errs.size()]
        for e in errs:
                out += "\n  • " + e
        return out
