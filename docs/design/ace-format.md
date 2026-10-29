# Дизайн: формат ACE (дії, умови, вирази)

> Статус: **чернетка v0.1**. Етап 1 дорожньої карти (`docs/ROADMAP.md`).
> Пов'язані документи: `picking.md` (як умови обирають інстанси).
> Код тут — ескізи; ще не запускались.

## 0. Простими словами

**ACE** (Action, Condition, Expression) — це один «пункт меню» в event sheet:
- **дія** — «Встановити позицію», «Знищити», «Відтворити звук»;
- **умова** — «health ≤ 0», «Натиснуто клавішу», «Зіткнувся з…»;
- **вираз** — значення, яке підставляють у поле: `Player.X`, `random(1, 10)`.

Кожен ACE описується **однаковим шматком даних**: назва, речення для аркуша, параметри,
до яких об'єктів підходить, і **який GDScript з нього вийде**. Неважливо, хто його написав:
ми вручну, автогенератор з ClassDB, behavior чи плагін спільноти. Редактор, компілятор і
переклади працюють з усіма однаково.

## 1. Вимоги

1. **Один формат для всіх джерел:** ручні, автогенеровані з ClassDB, behaviors, змінні
   інстансів, ефекти, плагіни, власні GDScript-функції користувача.
2. **Стабільний id.** Аркуш зберігає id ACE, а не текст. Перейменування, переклад чи
   зміна іконки не ламає збережені аркуші.
3. **2D і 3D без дублювання логіки редактора.** Редактор показує лише ті ACE, які підходять
   класу обраного типу. Користувач 3D-об'єкта ніколи не бачить 2D-дій.
4. **Перекладність.** Назви, речення, підказки перекладаються. Речення мають **іменовані**
   місця для параметрів, бо в різних мовах інший порядок слів.
5. **Генерація читабельного GDScript** за шаблоном, без «магії» в рантаймі.
6. **Перевірка при завантаженні.** Помилку в описі ACE видно одразу при старті редактора,
   а не тоді, коли користувач натисне на пункт меню.
7. **Сумісність уперед.** Параметри зберігаються за назвою, тож новий параметр зі
   значенням за замовчуванням не ламає старі аркуші.

## 2. Модель даних

Один ACE — це словник (Dictionary) такої форми. Ту саму форму можна записати в JSON, її
видає автогенератор, і вона ж лежить у файлах ручних описів.

### 2.1 Спільні поля

| Поле | Обов'язкове | Що це |
|---|---|---|
| `id` | так | Стабільний ідентифікатор, `<область>.<дія>`: `node2d.set_position`. Ніколи не змінюється |
| `kind` | так | `"action"` · `"condition"` · `"expression"` |
| `applies_to` | так | До чого застосовується (§2.2) |
| `category` | так | Розділ у меню: «Розміщення», «Зіткнення», «Звук»… |
| `name` | так | Назва в меню вибору: «Встановити позицію» |
| `sentence` | для дій/умов | Як рядок виглядає в аркуші: `"Set position to ({x}, {y})"` |
| `description` | ні | Підказка (1–2 речення) |
| `keywords` | ні | Синоніми для пошуку: `["move", "teleport"]`. Англійські шукаються завжди, в будь-якій мові інтерфейсу |
| `params` | ні | Список параметрів (§2.3) |
| `code` | так | Шаблон GDScript (§3) |
| `icon` | ні | Іконка; за замовчуванням — іконка класу з `applies_to` |
| `tier` | ні | `"basic"` (за замовчуванням для ручних) або `"advanced"` (за замовчуванням для автогенерованих) |
| `covers` | ні | Які автогенеровані ACE цей ручний **замінює** в меню (§5.4): `["Node2D.position"]` |
| `deprecated` | ні | `{replaced_by = "...", params_map = {...}}` — для міграції старих аркушів |

### 2.2 `applies_to` — до чого застосовується

| Значення | Значить | Приклад |
|---|---|---|
| `"system"` | Не прив'язаний до об'єкта, виконується один раз | «Чекати», «Score ≥ 10», `random()` |
| `"<Клас Godot>"` | Будь-який тип, чий корінь — цей клас або його нащадок | `"Node2D"` підходить для Sprite2D, CharacterBody2D… |
| `"behavior:<Назва>"` | Тип, у якого є цей behavior | `"behavior:Platformer"` |
| `"type:<Тип>"` | Лише один конкретний тип (змінні інстансу, §5.3) | `"type:Enemy"` |

Сімейство отримує ACE, спільні для **всіх** його членів: спільний базовий клас плюс
спільні behaviors.

### 2.3 Параметри

```
{name = "x", type = "number", label = "X", default = "0", description = "..."}
```

`name` — стабільний ключ (зберігається в аркуші). `label` — те, що бачить користувач (перекладається).
Значення параметра в аркуші — **вираз** (рядок мовою виразів, окремий документ `expressions.md`)
або вибір зі списку, залежно від типу:

| `type` | Віджет у редакторі | Що підставляється в код |
|---|---|---|
| `number` | поле виразу | `float` |
| `integer` | поле виразу | `int` |
| `text` | поле виразу | `String` |
| `bool` | перемикач / вираз | `bool` |
| `color` | палітра / вираз | `Color` |
| `choice` | випадаючий список з `options` | значення обраного варіанта |
| `comparison` | `= ≠ < ≤ > ≥` | оператор `==`, `!=`, `<`… (без дужок) |
| `object_type` | список типів рівня (можна обмежити `accepts = "PhysicsBody2D"`) | сцена-тип + назва групи |
| `input_action` | список дій з Input Map | `StringName` |
| `key` / `mouse_button` / `joy_button` | «натисни клавішу» | константа Godot |
| `animation` | список анімацій **цього** об'єкта | `StringName` |
| `file` | вибір файлу (`filter = "*.ogg,*.wav"`) | `preload(...)` |
| `any` | поле виразу | `Variant` (для автогенерації, коли тип невідомий) |

### 2.4 Поля для умов

| Поле | Значення | Що значить (див. `picking.md`) |
|---|---|---|
| `pick` | `"filter"` | Перевіряється для кожного інстансу, звужує вибірку (П2). За замовчуванням для об'єктних умов |
| | `"system"` | Просто так/ні, нікого не обирає. За замовчуванням для `applies_to = "system"` |
| | `"list"` | Отримує весь список і повертає новий (pick nearest, pick random, pick highest) |
| | `"trigger"` | Сигнал (П16); потрібні `signal` і, можливо, `trigger_picks` |
| `polled_trigger` | `true` | Звичайна умова, але показується як тригер і мусить стояти першою («Натиснуто клавішу») |
| `invertible` | `true`/`false` | Чи можна інвертувати. За замовчуванням `true` для `filter`/`system`, `false` для `list`/`trigger` |
| `signal` | `"body_entered"` | Назва сигналу (для `trigger`) |
| `signal_source` | `"self"` · `"behavior"` · `"runner"` | Хто випускає сигнал. За замовчуванням `self` |
| `signal_args` | `["other"]` | Імена аргументів сигналу, щоб на них посилатися |
| `trigger_picks` | `{object = "other"}` | Аргумент сигналу, яким обирається параметр-тип (П16) |

### 2.5 Поля для дій

| Поле | Значення | Що значить |
|---|---|---|
| `async` | `true` | Дія чекає (`await`). Подія компілюється за шаблоном «подія з Wait» (П14) |
| `creates` | `"type"` | Дія створює інстанс; шаблон повертає його, і компілятор обирає створені (П7). Значення — назва параметра типу `object_type` |

### 2.6 Поля для виразів

| Поле | Значення | Що значить |
|---|---|---|
| `returns` | `"number"`, `"text"`, `"bool"`, `"color"`, `"any"` | Тип результату, для перевірки й автодоповнення |
| `call_name` | `"DistanceTo"` | Як вираз пишеться в полі: `Enemy.DistanceTo(0, 0)`, `random(1, 6)` |

## 3. Шаблон коду (`code`)

Шаблон — це рядок GDScript з місцями в фігурних дужках. Компілятор підставляє їх і вставляє
результат у шаблони з `picking.md` §4.2.

| Місце | Що підставляється |
|---|---|
| `{<параметр>}` | Скомпільоване значення параметра. **У дужках**, якщо це не одне число, рядок чи ім'я (і крім `comparison`/`choice`), щоб `{x} * 2` не зламалося, коли x = `a + b` |
| `{self}` | Поточний інстанс. Компілятор називає змінну за типом (`enemy`, `player`), бо `self` у GDScript зайняте |
| `{behavior}` | Behavior поточного інстансу (тільки для `applies_to = "behavior:..."`) |
| `{runner}` | Раннер аркуша (`self` у згенерованому скрипті): `spawn`, `wait` тощо |
| `{list}` | Список обраних (тільки для `pick = "list"`) |
| `{{` / `}}` | Буквальні фігурні дужки |

Що має повертати шаблон, залежить від виду ACE:

| Вид | Шаблон — це | Куди потрапляє |
|---|---|---|
| умова `filter` | булевий вираз від `{self}` | `sol.filter(&"Enemy", func(enemy): return <шаблон>)` |
| умова `system` / `polled_trigger` | булевий вираз | `if not (<шаблон>): return false` |
| умова `list` | вираз, що повертає масив з `{list}` | `sol.pick_only(&"T", <шаблон>)` + перевірка на порожнечу |
| умова `trigger` | порожній або додаткова перевірка | обробник сигналу (`picking.md` §4.3, події 2–3) |
| дія об'єкта | інструкція від `{self}` | `for enemy in sol.get_picked(&"Enemy"): <шаблон>` |
| дія `system` | інструкція | один рядок |
| дія `creates` | вираз, що повертає інстанс | `created.append(<шаблон>)`, потім `pick_only` |
| вираз | вираз | місце у виразі параметра |

Шаблон може мати кілька рядків; відступи компілятор вирівнює сам. Якщо логіка складніша
за 2–3 рядки, шаблон викликає функцію з рантайм-бібліотеки (`Es.pick_nearest_2d(...)`),
а не тягне все у згенерований код. Так згенерований код лишається читабельним.

## 4. Приклади

Ручні описи лежать у файлах-«провайдерах»: це GDScript-файл зі статичною функцією `_get_aces()`,
яка повертає масив словників. Behaviors використовують ту саму функцію (§4.6).
Чому GDScript, а не JSON, — див. §7.1.

### 4.1 Дія 2D і та сама дія в 3D

```gdscript
# addons/eventsheet/aces/transform.gd
extends AceProvider


static func _get_aces() -> Array[Dictionary]:
	return [
		{
			id = "node2d.set_position",
			kind = "action",
			applies_to = "Node2D",
			category = "Position",
			name = "Set position",
			sentence = "Set position to ({x}, {y})",
			description = "Move the object to a point on the level.",
			keywords = ["move", "teleport", "place"],
			params = [
				{name = "x", type = "number", label = "X", default = "0"},
				{name = "y", type = "number", label = "Y", default = "0"},
			],
			code = "{self}.global_position = Vector2({x}, {y})",
			covers = ["Node2D.position", "Node2D.global_position"],
		},
		{
			id = "node3d.set_position",
			kind = "action",
			applies_to = "Node3D",
			category = "Position",
			name = "Set position",
			sentence = "Set position to ({x}, {y}, {z})",
			keywords = ["move", "teleport", "place"],
			params = [
				{name = "x", type = "number", label = "X", default = "0"},
				{name = "y", type = "number", label = "Y", default = "0"},
				{name = "z", type = "number", label = "Z", default = "0"},
			],
			code = "{self}.global_position = Vector3({x}, {y}, {z})",
			covers = ["Node3D.position", "Node3D.global_position"],
		},
	]
```

Для користувача це **одна** дія «Встановити позицію». Редактор показує потрібну версію
залежно від того, 2D чи 3D об'єкт обрано.

### 4.2 Умова-фільтр і вираз

```gdscript
{
	id = "node2d.is_on_screen",
	kind = "condition",
	applies_to = "Node2D",
	category = "Position",
	name = "Is on screen",
	sentence = "is on screen",
	code = "Es.is_on_screen_2d({self})",
},
{
	id = "node2d.distance_to",
	kind = "expression",
	applies_to = "Node2D",
	category = "Position",
	name = "Distance to point",
	call_name = "DistanceTo",
	returns = "number",
	params = [
		{name = "x", type = "number", label = "X"},
		{name = "y", type = "number", label = "Y"},
	],
	code = "{self}.global_position.distance_to(Vector2({x}, {y}))",
},
```

Аркуш: `Enemy: is on screen` → згенерується
`sol.filter(&"Enemy", func(enemy): return Es.is_on_screen_2d(enemy))`.
Інвертувати можна без додаткового опису (`invertible` за замовчуванням `true`).

### 4.3 Умова зі списком (pick nearest)

```gdscript
{
	id = "node2d.pick_nearest",
	kind = "condition",
	pick = "list",
	applies_to = "Node2D",
	category = "Pick",
	name = "Pick nearest",
	sentence = "Pick nearest to ({x}, {y})",
	params = [
		{name = "x", type = "number", label = "X"},
		{name = "y", type = "number", label = "Y"},
	],
	code = "Es.pick_nearest_2d({list}, Vector2({x}, {y}))",
},
```

### 4.4 Справжній тригер (сигнал Godot)

```gdscript
{
	id = "area3d.on_body_entered",
	kind = "condition",
	pick = "trigger",
	applies_to = "Area3D",
	category = "Collisions",
	name = "On object entered",
	sentence = "{object} entered",
	params = [{name = "object", type = "object_type", label = "Object", accepts = "PhysicsBody3D"}],
	signal = "body_entered",
	signal_args = ["other"],
	trigger_picks = {object = "other"},
	code = "",
},
```

Компілятор генерує обробник з `picking.md` §4.3. Перевіряє, що `other` належить до групи
обраного типу, обирає обох учасників і виконує дії.

### 4.5 Псевдотригер, Wait, створення

```gdscript
{
	id = "input.on_action_pressed",
	kind = "condition",
	applies_to = "system",
	polled_trigger = true,
	invertible = false,
	category = "Input",
	name = "On action pressed",
	sentence = "On {action} pressed",
	params = [{name = "action", type = "input_action", label = "Action"}],
	code = "Input.is_action_just_pressed({action})",
},
{
	id = "system.wait",
	kind = "action",
	applies_to = "system",
	async = true,
	category = "Time",
	name = "Wait",
	sentence = "Wait {seconds} seconds",
	params = [{name = "seconds", type = "number", label = "Seconds", default = "1"}],
	code = "await {runner}.wait({seconds})",
},
{
	id = "system.create_object",
	kind = "action",
	applies_to = "system",
	creates = "type",
	category = "Objects",
	name = "Create object",
	sentence = "Create {type} at ({x}, {y})",
	params = [
		{name = "type", type = "object_type", label = "Object"},
		{name = "x", type = "number", label = "X", default = "0"},
		{name = "y", type = "number", label = "Y", default = "0"},
	],
	code = "{runner}.spawn({type}, Vector2({x}, {y}))",
},
```

### 4.6 Behavior

Behavior описує свої ACE прямо у своєму скрипті, тож усе про нього лежить в одному файлі:

```gdscript
class_name Platformer
extends EsBehavior2D

signal landed

# ... логіка руху ...


static func _get_aces() -> Array[Dictionary]:
	return [
		{
			id = "platformer.is_on_floor",
			kind = "condition",
			applies_to = "behavior:Platformer",
			category = "Platformer",
			name = "Is on floor",
			sentence = "is on floor",
			code = "{behavior}.is_on_floor()",
		},
		{
			id = "platformer.jump",
			kind = "action",
			applies_to = "behavior:Platformer",
			category = "Platformer",
			name = "Jump",
			sentence = "Jump",
			code = "{behavior}.jump()",
		},
		{
			id = "platformer.on_landed",
			kind = "condition",
			pick = "trigger",
			applies_to = "behavior:Platformer",
			category = "Platformer",
			name = "On landed",
			sentence = "On landed",
			signal = "landed",
			signal_source = "behavior",
			code = "",
		},
	]
```

## 5. Джерела ACE

### 5.1 Ручні (провайдери)
Файли в `addons/eventsheet/aces/*.gd` (пізніше — у модулі). Тут лежать «гарні» ACE з
`tier = "basic"`, які покривають карту можливостей з `ROADMAP.md` §5.1.

### 5.2 Автогенерація з ClassDB
Для кожного класу, доступного у скриптах:

| Що в ClassDB | Що генерується | id |
|---|---|---|
| властивість (можна писати) | дія «Встановити X»; для чисел ще «Додати до X» | `auto.Label.text.set`, `auto.Node2D.rotation.add` |
| властивість (будь-яка) | умова «Порівняти X» (`comparison`) або «X увімкнено» для bool; вираз `X` | `auto.Label.text.compare`, `auto.Label.text.get` |
| метод → `void` | дія | `auto.AnimationPlayer.play` |
| метод → `bool` | умова-фільтр | `auto.Node.is_inside_tree` |
| метод → інше | вираз | `auto.Node2D.get_angle_to` |
| сигнал | тригер; аргументи сигналу доступні як вирази | `auto.AnimationPlayer.animation_finished` |

- Назви людські з імені: `set_collision_mask_value` → «Set collision mask value».
- **Опис береться з документації класів Godot**, яка вже перекладена багатьма мовами (`doc/`).
- Аргументи непідтримуваних типів (Callable, RID, складні Object) — метод пропускається.
- Автогенеровані мають `tier = "advanced"`: їх видно в розділі «Усі можливості», або коли
  пошук не знайшов нічого серед basic.

### 5.3 Змінні інстансу
Для кожної `@export`-змінної кореневого скрипта типу генеруються: «Встановити», «Додати»,
«Відняти» (для чисел), «Порівняти», «Увімкнено» (bool), вираз. `applies_to = "type:Enemy"`,
id `var.Enemy.health.set`. Перейменування змінної в редакторі змінних автоматично оновлює аркуші.

### 5.4 Ручні перекривають автогенеровані
Ручний ACE з `covers = ["Node2D.position"]` ховає з меню автогенеровані ACE цієї властивості,
щоб «Встановити позицію» не з'являлося двічі. Аркуші, які вже використовують автогенерований
id, далі працюють.

### 5.5 Ефекти, плагіни, функції користувача
- **Ефекти** (етап 5): кожен параметр ефекту дає дію «Встановити <параметр> ефекту».
- **Плагіни** реєструють свій провайдер так само, як ручні ACE.
- **Функції користувача** («аварійний люк»): функції в GDScript-файлі, позначені для аркуша,
  з'являються як дії/вирази. Як саме позначати — §7.

## 6. Перевірки при завантаженні

Реєстр перевіряє кожен ACE один раз, коли його завантажує. Далі редактор і компілятор
довіряють даним. При помилці ACE не реєструється, а в консолі з'являється зрозуміле
повідомлення з назвою файлу й id.

1. `id` унікальний; формат `[a-z0-9_.]+` (для `auto.`/`var.` дозволені великі літери з імен класів).
2. `kind`, `pick`, типи параметрів — з дозволених списків.
3. Кожне `{місце}` у `code` і `sentence` — відомий параметр або службове місце, дозволене для цього виду.
4. Кожен параметр згаданий у `sentence` (інакше користувач не побачить його в аркуші).
5. `applies_to` — існуючий клас Godot, behavior чи тип.
6. `trigger` має `signal`; `trigger_picks` посилається на параметр типу `object_type` і на ім'я з `signal_args`.
7. `creates` посилається на параметр типу `object_type`.
8. `{self}` не можна в `system`, `{behavior}` — лише в `behavior:`, `{list}` — лише в `pick = "list"`.
9. `deprecated.replaced_by` існує.

## 7. Відкриті питання

1. **Формат ручних описів.** Зараз пропонується GDScript-файл, який повертає словники. Він
   дає звичний синтаксис, підсвітку в редакторі і жодного окремого парсера, а behavior може
   тримати ACE поруч зі своєю логікою. Мінус: рядки для перекладу треба витягувати своїм
   плагіном (`EditorTranslationParserPlugin`). Альтернатива — JSON. Вирішити до етапу 2.
2. **Назви виразів (`call_name`) у різних мовах.** Як у Construct: завжди англійські
   (`Player.X`, `random()`), а автодоповнення показує перекладений опис? Пропоную так.
3. **Вектори.** Чи давати тип параметра `vector2/vector3`, чи, як у Construct, лише окремі
   числа x/y/z? Для 3D вектори зручніші. Пропоную: окремі числа в basic, вектори — опція.
4. **Як позначати функції користувача:** префікс імені (`func es_jump()`), doc-коментар
   (`## @action`) чи окремий список у налаштуваннях?
5. **Швидкість `{behavior}`:** пошук behavior кожного разу чи кеш на інстансі.
6. **ACE для сімейств:** перетин класів і behaviors — достатньо, чи потрібні ACE, описані
   прямо на сімействі?
7. **Інструмент міграції:** як показувати користувачу, що аркуш оновився через `deprecated`.

## 8. Тести (специфікація поведінки)

| # | Дано | Очікуємо |
|---|---|---|
| A1 | ACE `node2d.set_position` і тип Player (CharacterBody2D) | у меню Player є «Set position» з X, Y |
| A2 | те саме для 3D-типу | у меню є версія з X, Y, Z; 2D-версії немає |
| A3 | аркуш з `node2d.set_position`, x = `a + b` | згенеровано `player.global_position = Vector2((a + b), 0)` |
| A4 | ACE з `{z}` у `code`, але без параметра `z` | ACE не зареєстровано, помилка з id і файлом |
| A5 | два ACE з однаковим id | другий відхилено з помилкою |
| A6 | ручний `covers = ["Node2D.position"]` | автогенерований `auto.Node2D.position.set` не видно в меню, старий аркуш з ним компілюється |
| A7 | ClassDB: `Label.text` | згенеровано set/compare/get з описами з документації |
| A8 | ClassDB: метод з аргументом Callable | метод пропущено, без помилки |
| A9 | тип Enemy з `@export var health := 3` | є «Set health», «Add to health», «Compare health», вираз `Enemy.health` |
| A10 | аркуш зберігає параметри за назвою; до ACE додано параметр із default | старий аркуш відкривається, новий параметр = default |
| A11 | `deprecated` з `replaced_by` | старий аркуш відкривається з новим ACE, параметри перенесені |
| A12 | behavior Platformer на Player | у меню Player є категорія Platformer з Is on floor, Jump, On landed |
| A13 | сімейство (Slime: CharacterBody2D + Platformer, Bat: Area2D) | у сімейства є ACE Node2D, але немає Platformer і CharacterBody2D |
| A14 | інтерфейс українською, пошук «position» | «Встановити позицію» знайдено за англійським ключовим словом |
| A15 | речення українською з іншим порядком місць | параметри показуються на правильних місцях |
