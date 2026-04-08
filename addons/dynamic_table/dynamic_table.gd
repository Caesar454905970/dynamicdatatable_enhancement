@tool
extends Control
class_name DynamicTable

# Signals
signal cell_selected(row, column)
signal multiple_rows_selected(selected_row_indices: Array)
signal cell_right_selected(row, column, mousepos)
signal header_clicked(column)
signal column_resized(column, new_width)
signal progress_changed(row, column, new_value)
signal cell_edited(row, column, old_value, new_value)
signal button_pressed(row, column)

# Table properties
@export_group("Default color")
@export var default_font_color: Color = Color(1.0, 1.0, 1.0)
@export_group("Header")
@export var headers: Array[String] = []
@export var header_height: float = 35.0
@export var header_color: Color = Color("#000000")
@export var header_filter_active_font_color: Color = Color(1.0, 1.0, 0.0)
@export_group("Row selection column")
@export var row_select_column_enabled: bool = true # Adds a dedicated checkbox column (not part of data).
@export var row_select_column_width: float = 34.0
@export var row_select_header_toggle_all: bool = true
@export var row_select_header_tooltip: String = "Select rows"
@export_group("Size and grid")
@export var default_minimum_column_width: float = 50.0
@export var row_height: float = 30.0
@export var grid_color: Color = Color("#2b323a")
@export_group("Rows")
@export var selected_back_color: Color = Color("#5f5fcb")
@export var row_color: Color = Color("#1e2329")
@export var alternate_row_color: Color = Color("#232a31")

# Checkbox properties
@export_group("Checkbox")
@export var checkbox_checked_color: Color = Color(0.25, 0.49, 0.96, 1.0)
@export var checkbox_unchecked_color: Color = Color(0.93, 0.94, 0.96, 1.0)
@export var checkbox_border_color: Color = Color(0.86, 0.88, 0.92, 1.0)
@export var checkbox_checkmark_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_group("Checkbox behavior")
@export var checkbox_single_select: bool = false # If true, only one checkbox per column can be checked at a time.
@export var checkbox_header_toggle_all: bool = true # Click checkbox column header to toggle all rows.

# Progress bar properties
@export_group("Progress bar")
@export var progress_bar_start_color: Color = Color.RED
@export var progress_bar_middle_color: Color = Color.ORANGE
@export var progress_bar_end_color: Color = Color.FOREST_GREEN
@export var progress_background_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var progress_border_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var progress_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# Button column properties
@export_group("Buttons")
@export var button_bg_color: Color = Color(0.25, 0.25, 0.25, 1.0)
@export var button_border_color: Color = Color(0.65, 0.65, 0.65, 1.0)
@export var button_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var edit_button_starts_editing: bool = false # For columns tagged as |edit, a click can optionally start cell editing.
@export var edit_button_target_column: int = -1 # -1 => auto-pick first text column.

# Internal variables
var _data = []
var _full_data = [] 
var _column_widths = []
var _min_column_widths = []
var _total_rows = 0
var _total_columns = 0
var _visible_rows_range = [0, 0]
var _h_scroll_position = 0
var _v_scroll_position = 0
var _resizing_column = -1
var _resizing_start_pos = 0
var _resizing_start_width = 0
var _mouse_over_divider = -1
var _divider_width = 5
var _icon_sort = " ▼ "
var _last_column_sorted = -1
var _ascending = true
var _dragging_progress = false
var _progress_drag_row = -1
var _progress_drag_col = -1

# Selection and focus variables
var _selected_rows: Array = []  				# Indici delle righe selezionate
var _previous_sort_selected_rows: Array = []	# Array con le righe selezionate prima dell'ordinamento
var _anchor_row: int = -1       				# Riga di ancoraggio per la selezione con Shift
var _focused_row: int = -1      				# Riga con il focus corrente
var _focused_col: int = -1      				# Colonna con il focus corrente

# Editing variables
var _editing_cell = [-1, -1]
var _edit_line_edit: LineEdit
var _double_click_timer: Timer
var _click_count = 0
var _last_click_pos = Vector2.ZERO
var _double_click_threshold = 400 # milliseconds
var _click_position_threshold = 5 # pixels

# Filtering variables
var _filter_line_edit: LineEdit 
var _filtering_column = -1     

# Tooltip variable
var _tooltip_cell = [-1, -1] # [row, col]

# Node references
var _h_scroll: HScrollBar
var _v_scroll: VScrollBar

# Fonts
var font = get_theme_default_font()
var font_size = get_theme_default_font_size()

func _ready():
	self.focus_mode = Control.FOCUS_ALL # For input from keyboard
	
	_setup_editing_components()
	_setup_filtering_components() 
	
	_h_scroll = HScrollBar.new()
	_h_scroll.name = "HScrollBar"
	_h_scroll.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_h_scroll.offset_top = -12
	_h_scroll.value_changed.connect(_on_h_scroll_changed)
	
	_v_scroll = VScrollBar.new()
	_v_scroll.name = "VScrollBar"
	_v_scroll.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	_v_scroll.offset_left = -12
	_v_scroll.value_changed.connect(_on_v_scroll_changed)
	
	add_child(_h_scroll)
	add_child(_v_scroll)
	
	_update_column_widths()
	
	resized.connect(_on_resized)
	gui_input.connect(_on_gui_input) # Manage input from keyboard whwn has focus control
	
	self.anchor_left = 0.0
	self.anchor_top = 0.0
	self.anchor_right = 1.0
	self.anchor_bottom = 1.0
		
	queue_redraw()

func _setup_filtering_components():
	_filter_line_edit = LineEdit.new()
	_filter_line_edit.name = "FilterLineEdit"
	_filter_line_edit.visible = false
	_filter_line_edit.text_submitted.connect(_apply_filter)
	_filter_line_edit.focus_exited.connect(_on_filter_focus_exited)
	add_child(_filter_line_edit)
	
func _setup_editing_components():
	_edit_line_edit = LineEdit.new()
	_edit_line_edit.visible = false
	_edit_line_edit.text_submitted.connect(_on_edit_text_submitted)
	_edit_line_edit.focus_exited.connect(_on_edit_focus_exited)
	add_child(_edit_line_edit)
	
	_double_click_timer = Timer.new()
	_double_click_timer.wait_time = _double_click_threshold / 1000.0
	_double_click_timer.one_shot = true
	_double_click_timer.timeout.connect(_on_double_click_timeout)
	add_child(_double_click_timer)

func _on_resized():
	_update_scrollbars()
	queue_redraw()

func _update_column_widths():
	_total_columns = _data_column_count() + (1 if _has_row_select_column() else 0)
	_column_widths.resize(_total_columns)
	_min_column_widths.resize(_total_columns)
	for vcol in range(_total_columns):
		if _is_row_select_visual_col(vcol):
			_column_widths[vcol] = row_select_column_width
			_min_column_widths[vcol] = row_select_column_width
			continue

		if vcol >= _column_widths.size() or _column_widths[vcol] == 0 or _column_widths[vcol] == null:
			_column_widths[vcol] = default_minimum_column_width
			_min_column_widths[vcol] = default_minimum_column_width

func _is_date_string(value: String) -> bool:
	var date_regex = RegEx.new()
	date_regex.compile("^\\d{2}/\\d{2}/\\d{4}$")
	return date_regex.search(value) != null

func _get_header_parts(column_index: int) -> Array:
	if column_index < 0 or column_index >= headers.size():
		return []
	return headers[column_index].split("|")

func _get_header_tags(column_index: int) -> String:
	var header_parts = _get_header_parts(column_index)
	if header_parts.size() <= 1:
		return ""
	var tags: Array[String] = []
	for i in range(1, header_parts.size()):
		tags.append(header_parts[i].to_lower())
	return "|".join(tags)

func _header_has_any_tag(column_index: int, tag_names: Array[String]) -> bool:
	var tags = _get_header_tags(column_index)
	if tags.is_empty():
		return false
	for tag_name in tag_names:
		if tags.contains(tag_name.to_lower()):
			return true
	return false

func _is_date_column(column_index: int) -> bool:
	var match_count = 0
	var total = 0
	for row_data_item in _data: # Rinominato `row` a `row_data_item` per evitare shadowing
		if column_index >= row_data_item.size():
			continue
		var value = str(row_data_item[column_index])
		total += 1
		if _is_date_string(value):
			match_count += 1
	return (total > 0 and match_count > total / 2) 

func _is_progress_column(column_index: int) -> bool:
	if column_index >= headers.size():
		return false
	var tags = _get_header_tags(column_index)
	return tags.contains("p") or tags.contains("progress")

func _is_checkbox_column(column_index: int) -> bool:
	if column_index >= headers.size():
		return false
	var tags = _get_header_tags(column_index)
	return tags.contains("check") or tags.contains("checkbox")

func _is_image_column(column_index: int) -> bool:
	if column_index >= headers.size():
		return false
	var tags = _get_header_tags(column_index)
	return tags.contains("image")

func _is_button_column(column_index: int) -> bool:
	if column_index >= headers.size():
		return false
	var tags = _get_header_tags(column_index)
	return tags.contains("btn") or tags.contains("button") or tags.contains("edit")

func _is_edit_button_column(column_index: int) -> bool:
	if column_index >= headers.size():
		return false
	return _get_header_tags(column_index).contains("edit")

func _is_sort_enabled_column(column_index: int) -> bool:
	if column_index < 0 or column_index >= headers.size():
		return false
	return not _header_has_any_tag(column_index, ["nosort", "sortoff", "sortfalse"])

func _is_default_sort_desc_column(column_index: int) -> bool:
	if column_index < 0 or column_index >= headers.size():
		return false
	return _header_has_any_tag(column_index, ["sortdesc", "desc", "descending"])

func _is_default_sort_asc_column(column_index: int) -> bool:
	if column_index < 0 or column_index >= headers.size():
		return false
	return _header_has_any_tag(column_index, ["sortasc", "asc", "ascending"])

func _is_double_click_edit_enabled_column(column_index: int) -> bool:
	if column_index < 0 or column_index >= headers.size():
		return false
	if _header_has_any_tag(column_index, ["editable", "editon", "edittrue"]):
		return not (_is_checkbox_column(column_index) or _is_progress_column(column_index) or _is_image_column(column_index) or _is_button_column(column_index))
	if _header_has_any_tag(column_index, ["noedit", "readonly", "editoff", "editfalse"]):
		return false
	return not (_is_checkbox_column(column_index) or _is_progress_column(column_index) or _is_image_column(column_index) or _is_button_column(column_index))

func _is_text_edit_column(column_index: int) -> bool:
	if column_index < 0 or column_index >= headers.size():
		return false
	return _header_has_any_tag(column_index, ["edittext", "textedit", "text"])

func _can_edit_cell_value(data_col: int, value) -> bool:
	if not _is_double_click_edit_enabled_column(data_col):
		return false
	if _is_text_edit_column(data_col):
		return value == null or value is String or value is StringName
	return true

func _is_numeric_value(value) -> bool:
	if value == null:
		return false
	var str_val = str(value)
	return str_val.is_valid_float() or str_val.is_valid_int()

func _get_progress_value(value) -> float:
	if value == null: return 0.0
	var num_val = 0.0
	if _is_numeric_value(value): num_val = float(str(value))
	if num_val >= 0.0 and num_val <= 1.0: return num_val
	elif num_val >= 0.0 and num_val <= 100.0: return num_val / 100.0
	else: return clamp(num_val, 0.0, 1.0)

func _parse_date(date_str: String) -> Array:
	var parts = date_str.split("/")
	if parts.size() != 3: return [0, 0, 0]
	return [int(parts[2]), int(parts[1]), int(parts[0])] # Year, Month, Day

func _data_column_count() -> int:
	return headers.size()

func _has_row_select_column() -> bool:
	return row_select_column_enabled

func _is_row_select_visual_col(visual_col: int) -> bool:
	return _has_row_select_column() and visual_col == 0

func _visual_to_data_col(visual_col: int) -> int:
	if _has_row_select_column():
		return visual_col - 1
	return visual_col

func _data_to_visual_col(data_col: int) -> int:
	if _has_row_select_column():
		return data_col + 1
	return data_col

func _get_default_value_for_data_column(data_col: int):
	if _is_progress_column(data_col):
		return 0.0
	if _is_checkbox_column(data_col):
		return false
	if _is_image_column(data_col):
		return null
	if _is_button_column(data_col):
		return ""
	return ""

func _visual_col_to_signal_col(visual_col: int) -> int:
	if _is_row_select_visual_col(visual_col):
		return -1
	return _visual_to_data_col(visual_col)

func _get_visual_column_at_x(pos_x: float) -> int:
	var current_x = -_h_scroll_position
	for visual_col in range(_total_columns):
		if visual_col >= _column_widths.size():
			continue
		if pos_x >= current_x and pos_x < current_x + _column_widths[visual_col]:
			return visual_col
		current_x += _column_widths[visual_col]
	return -1

func _toggle_row_selection(row_idx: int, is_shift: bool = false, is_ctrl_cmd: bool = false):
	var emit_multiple_selection_signal = false
	if row_idx < 0 or row_idx >= _total_rows:
		return emit_multiple_selection_signal

	if is_shift and _anchor_row != -1:
		_selected_rows.clear()
		var start_range = min(_anchor_row, row_idx)
		var end_range = max(_anchor_row, row_idx)
		for i in range(start_range, end_range + 1):
			_selected_rows.append(i)
		emit_multiple_selection_signal = _selected_rows.size() > 1
	elif is_ctrl_cmd:
		if _selected_rows.has(row_idx):
			_selected_rows.erase(row_idx)
		else:
			_selected_rows.append(row_idx)
		_anchor_row = row_idx
		emit_multiple_selection_signal = _selected_rows.size() > 1
	else:
		_selected_rows.clear()
		_selected_rows.append(row_idx)
		_anchor_row = row_idx

	_focused_row = row_idx
	if _focused_col == -1 and _data_column_count() > 0:
		_focused_col = _data_to_visual_col(0)
	return emit_multiple_selection_signal

#------------------------------------------------------------
# PUBLIC FUNCTIONS
#------------------------------------------------------------

func set_headers(new_headers: Array):
	var typed_headers: Array[String] = []
	for header in new_headers: typed_headers.append(String(header))
	headers = typed_headers
	_update_column_widths()
	_update_scrollbars()
	queue_redraw()

func set_data(new_data: Array):
	# Memorizza una copia completa dei dati come master list
	_full_data = new_data.duplicate(true) 
	# La vista (_data) contiene riferimenti alle righe nella master list
	_data = _full_data.duplicate(false) 
	
	_total_rows = _data.size()
	_visible_rows_range = [0, min(_total_rows, floor(self.size.y / row_height) if row_height > 0 else 0)]
	
	_selected_rows.clear()
	_anchor_row = -1
	_focused_row = -1
	_focused_col = -1
	
	for row_data_item in _data:
		while row_data_item.size() < _data_column_count():
			var col_to_fill = row_data_item.size()
			row_data_item.append(_get_default_value_for_data_column(col_to_fill))

	# 自动调整列宽已禁用，以保留手动设置的列宽。
	# 如果需要自动调整，可以恢复基于表头和数据内容重新计算 `_column_widths` 的逻辑。
			
	_update_scrollbars()
	queue_redraw()
	
func ordering_data(column_index: int, ascending: bool = true) -> int:
	_finish_editing(false)
	_last_column_sorted = column_index
	_store_selected_rows()
	if _is_date_column(column_index):
		_data.sort_custom(func(a, b):
			var a_val = _parse_date(str(a[column_index]))
			var b_val = _parse_date(str(b[column_index]))
			_set_icon_down() if ascending else _set_icon_up()
			_restore_selected_rows()
			return a_val < b_val if ascending else a_val > b_val)
	elif _is_progress_column(column_index):
		_data.sort_custom(func(a, b):
			var a_val = _get_progress_value(a[column_index])
			var b_val = _get_progress_value(b[column_index])
			_set_icon_down() if ascending else _set_icon_up()
			_restore_selected_rows()
			return a_val < b_val if ascending else a_val > b_val)
	elif _is_checkbox_column(column_index):
		_data.sort_custom(func(a, b):
			var a_val = bool(a[column_index])
			var b_val = bool(b[column_index])
			_set_icon_down() if ascending else _set_icon_up()
			_restore_selected_rows()
			return (a_val and not b_val) if ascending else (not a_val and b_val))
	else:
		_data.sort_custom(func(a, b):
			var a_val = a[column_index]
			var b_val = b[column_index]
			_set_icon_down() if ascending else _set_icon_up()
			# Gestione robusta per tipi misti o null
			if typeof(a_val) != typeof(b_val):
				if a_val == null: 
					return ascending # nulls first if ascending
				if b_val == null: 
					return not ascending # nulls last if ascending
				# Confronta come stringhe se i tipi sono diversi ma non null
				_restore_selected_rows()
				return str(a_val) < str(b_val) if ascending else str(a_val) > str(b_val)
			if a_val == null and b_val == null : 
				return false # Entrambi null, considerati uguali
			if a_val == null: 
				return ascending
			if b_val == null: 
				return not ascending
			_restore_selected_rows()
			return a_val < b_val if ascending else a_val > b_val)
	queue_redraw()
	return -1 # La funzione originale ritornava -1

func insert_row(index: int, row_data: Array):
	while row_data.size() < _data_column_count(): # Assicura consistenza colonne
		var col_to_fill = row_data.size()
		row_data.append(_get_default_value_for_data_column(col_to_fill))
	_data.insert(index, row_data)
	_total_rows += 1
	_update_scrollbars()
	queue_redraw()

func delete_row(index: int):
	if (_total_rows >= 1 and index < _total_rows):
		_data.remove_at(index)
		_total_rows -= 1
		if (_total_rows == 0):
			_selected_rows.clear()
		_update_scrollbars()
		queue_redraw()
		
func update_cell(r: int, column: int, value): # Rinominato `row` a `r`
	if r >= 0 and r < _data.size() and column >= 0 and column < _data_column_count():
		while _data[r].size() <= column: _data[r].append("")
		_data[r][column] = value
		queue_redraw()

func get_cell_value(r: int, column: int): # Rinominato `row` a `r`
	if r >= 0 and r < _data.size() and column >= 0 and column < _data[r].size():
		return _data[r][column]
	return null

func get_row_value(r: int): # Rinominato `row` a `r`
	if r >= 0 and r < _data.size(): return _data[r]
	return null

func set_selected_cell(r: int, col: int): # Rinominato `row` a `r`
	if r >= 0 and r < _total_rows and col >= 0 and col < _data_column_count():
		_focused_row = r
		_focused_col = _data_to_visual_col(col)
		_selected_rows.clear()
		_selected_rows.append(r)
		_anchor_row = r
		_ensure_row_visible(r)
		queue_redraw()
	else: # Selezione non valida, deseleziona tutto
		_focused_row = -1
		_focused_col = -1
		_selected_rows.clear()
		_anchor_row = -1
		queue_redraw()
	cell_selected.emit(_focused_row, col if (r >= 0 and col >= 0 and col < _data_column_count()) else -1)
	
func set_progress_value(r: int, column: int, value: float): # Rinominato `row` a `r`
	if r >= 0 and r < _data.size() and column >= 0 and column < _data_column_count():
		if _is_progress_column(column):
			_data[r][column] = clamp(value, 0.0, 1.0)
			queue_redraw()

func get_progress_value(row_idx: int, column: int) -> float:
	if row_idx >= 0 and row_idx < _data.size() and column >= 0 and column < _data[row_idx].size():
		if _is_progress_column(column):
			return _get_progress_value(_data[row_idx][column]) # Usa la funzione interna per la logica
	return 0.0

func set_progress_colors(bar_start_color: Color, bar_middle_color: Color, bar_end_color: Color, bg_color: Color, border_c: Color, text_c: Color):
	progress_bar_start_color = bar_start_color
	progress_bar_middle_color = bar_middle_color
	progress_bar_end_color = bar_end_color
	progress_background_color = bg_color
	progress_border_color = border_c
	progress_text_color = text_c
	queue_redraw()

#------------------------------------------------------------
# END PUBLIC FUNCTIONS
#------------------------------------------------------------

func _store_selected_rows():
	if (_selected_rows.size() == 0 ):
		return
	_previous_sort_selected_rows.clear()
	for index in range(_selected_rows.size()):
		_previous_sort_selected_rows.append(_data[_selected_rows[index]])

func _restore_selected_rows():
	if (_previous_sort_selected_rows.size() == 0 ):
		return
	_selected_rows.clear()
	for index in range(_previous_sort_selected_rows.size()):
		var idx = _data.find(_previous_sort_selected_rows[index])
		if (idx >= 0):
			_selected_rows.append(idx)
	
func _start_cell_editing(r: int, col: int): # Rinominato `row` a `r`
	if _is_row_select_visual_col(col):
		return
	var data_col = _visual_to_data_col(col)
	if data_col < 0:
		return
	var cell_value = get_cell_value(r, data_col)
	if not _can_edit_cell_value(data_col, cell_value):
		return
	_editing_cell = [r, col]
	var cell_rect = _get_cell_rect(r, col)
	if cell_rect == Rect2(): return
	_edit_line_edit.position = cell_rect.position
	_edit_line_edit.size = cell_rect.size
	if cell_value is float:
		cell_value = snapped(cell_value, 0.01)
	_edit_line_edit.text = str(cell_value) if get_cell_value(r, data_col) != null else ""
	_edit_line_edit.visible = true
	_edit_line_edit.grab_focus()
	_edit_line_edit.select_all()

func _finish_editing(save_changes: bool = true):
	if _editing_cell[0] >= 0 and _editing_cell[1] >= 0:
		var data_col = _visual_to_data_col(_editing_cell[1])
		if save_changes and _edit_line_edit.visible:
			var old_value = get_cell_value(_editing_cell[0], data_col)
			var new_value_text = _edit_line_edit.text
			var new_value = new_value_text # Default a stringa
			if new_value_text.is_valid_int(): new_value = int(new_value_text)
			elif new_value_text.is_valid_float(): new_value = float(new_value_text)
			update_cell(_editing_cell[0], data_col, new_value)
			cell_edited.emit(_editing_cell[0], data_col, old_value, new_value)
		_editing_cell = [-1, -1]
		_edit_line_edit.visible = false
		queue_redraw()

func _get_cell_rect(r: int, col: int) -> Rect2: # Rinominato `row` a `r`
	if r < _visible_rows_range[0] or r >= _visible_rows_range[1]: return Rect2()
	var x_offset = -_h_scroll_position
	var cell_x = x_offset
	for c in range(col): cell_x += _column_widths[c]
	var visible_w = size.x - (_v_scroll.size.x if _v_scroll.visible else 0)
	if col >= _column_widths.size() or cell_x + _column_widths[col] <= 0 or cell_x >= visible_w: return Rect2()
	var row_y_pos = header_height + (r - _visible_rows_range[0]) * row_height
	return Rect2(cell_x, row_y_pos, _column_widths[col], row_height)

func _on_edit_text_submitted(text: String): _finish_editing(true)
func _on_edit_focus_exited(): _finish_editing(true)
func _on_double_click_timeout(): _click_count = 0
func _set_icon_down(): _icon_sort = " ▼ "
func _set_icon_up(): _icon_sort = " ▲ "
		
func _update_scrollbars():
	if not is_inside_tree(): return
	if _total_rows == null or row_height == null:
		_total_rows = 0 if _total_rows == null else _total_rows
		row_height = 30.0 if row_height == null or row_height <=0 else row_height

	var visible_width = size.x - (_v_scroll.size.x if _v_scroll.visible else 0)
	var visible_height = size.y - (_h_scroll.size.y if _h_scroll.visible else 0) - header_height

	var total_content_width = 0 # Rinominato `total_width`
	for width in _column_widths:
		if width != null: total_content_width += width

	_h_scroll.visible = total_content_width > visible_width
	if _h_scroll.visible:
		_h_scroll.max_value = total_content_width
		_h_scroll.page = visible_width
		_h_scroll.step = default_minimum_column_width / 2.0 # Assicura float division

	var total_content_height = float(_total_rows) * row_height # Rinominato `total_height`
	_v_scroll.visible = total_content_height > visible_height
	if _v_scroll.visible:
		_v_scroll.max_value = total_content_height
		_v_scroll.page = visible_height
		_v_scroll.step = row_height
	
func _on_h_scroll_changed(value):
	_h_scroll_position = value
	if _edit_line_edit.visible: _finish_editing(false)
	queue_redraw()

func _on_v_scroll_changed(value):
	_v_scroll_position = value
	if row_height > 0: # Evita divisione per zero
		_visible_rows_range[0] = floor(value / row_height)
		_visible_rows_range[1] = _visible_rows_range[0] + floor((size.y - header_height) / row_height) + 1
		_visible_rows_range[1] = min(_visible_rows_range[1], _total_rows)
	else: # fallback se row_height non è valido
		_visible_rows_range = [0, _total_rows]

	if _edit_line_edit.visible: _finish_editing(false)
	queue_redraw()

func _get_header_text(col: int) -> String:
	if _is_row_select_visual_col(col):
		return ""
	var data_col = _visual_to_data_col(col)
	if data_col < 0 or data_col >= headers.size():
		return ""
	return headers[data_col].split("|")[0]

func _draw():
	
	if not is_inside_tree(): return
	
	var current_x_offset = -_h_scroll_position # Rinominato `x_offset`
	var current_y_offset = header_height # Rinominato `y_offset`
	var visible_drawing_width = size.x - (_v_scroll.size.x if _v_scroll.visible else 0) # Rinominato `visible_width`
	var header_font_color = default_font_color
	
	draw_rect(Rect2(0, 0, size.x, header_height), header_color)
	
	var header_cell_x = current_x_offset
	for col in range(_total_columns):
		if col >= _column_widths.size(): continue # Safety check
		var col_width = _column_widths[col]
		if header_cell_x + col_width > 0 and header_cell_x < visible_drawing_width:
			draw_line(Vector2(header_cell_x, 0), Vector2(header_cell_x, header_height), grid_color)
			var rect_w = min(header_cell_x + col_width, visible_drawing_width)
			draw_line(Vector2(header_cell_x, header_height), Vector2(rect_w, header_height), grid_color)
			
			if _is_row_select_visual_col(col):
				var header_chk_size = min(header_height, col_width) * 0.5
				var checked_count = _selected_rows.size()
				var total_count = _total_rows
				var header_chk_rect = Rect2(
					header_cell_x + (col_width - header_chk_size) / 2.0,
					(header_height - header_chk_size) / 2.0,
					header_chk_size,
					header_chk_size
				)
				draw_rect(header_chk_rect, checkbox_border_color, false, 1.0)
				if total_count > 0 and checked_count > 0:
					var fill_rect = header_chk_rect.grow(-header_chk_size * 0.18)
					if checked_count == total_count:
						draw_rect(fill_rect, checkbox_checked_color)
					else:
						draw_rect(fill_rect, checkbox_unchecked_color)
			else:
				var data_col = _visual_to_data_col(col)
				var align_info = _align_text_in_cell(col) # Array [text, h_align, x_margin]
				var header_text_content = align_info[0]
				var h_align_val = align_info[1]
				var x_margin_val = align_info[2]

				# Header checkbox indicator for checkbox columns
				if checkbox_header_toggle_all and _is_checkbox_column(data_col):
					var checked_count = 0
					var total_count = 0
					for row_data in _data:
						if data_col < row_data.size():
							total_count += 1
							if bool(row_data[data_col]):
								checked_count += 1
					var indicator = "[ ] "
					if total_count > 0 and checked_count == total_count:
						indicator = "[x] "
					elif checked_count > 0:
						indicator = "[-] "
					header_text_content = indicator + header_text_content
					# Keep checkbox header left-aligned for readability.
					h_align_val = HORIZONTAL_ALIGNMENT_LEFT
					x_margin_val = 5

				if (data_col == _filtering_column):
					header_font_color = header_filter_active_font_color
					header_text_content += " (" + str(_data.size()) + ")"
				else:
					header_font_color = default_font_color
				var text_s = font.get_string_size(header_text_content, h_align_val, col_width, font_size) # Rinominato `text_size`
				draw_string(font, Vector2(header_cell_x + x_margin_val, header_height/2.0 + text_s.y/2.0 - (font_size/2.0 - 2.0)), header_text_content, h_align_val, col_width - abs(x_margin_val), font_size, header_font_color)
				if (data_col == _last_column_sorted):
					var icon_h_align = HORIZONTAL_ALIGNMENT_LEFT
					if (h_align_val == HORIZONTAL_ALIGNMENT_LEFT or h_align_val == HORIZONTAL_ALIGNMENT_CENTER):
						icon_h_align = HORIZONTAL_ALIGNMENT_RIGHT
					draw_string(font, Vector2(header_cell_x, header_height/2.0 + text_s.y/2.0 - (font_size/2.0 - 1.0)), _icon_sort, icon_h_align, col_width, font_size/1.3, header_font_color)
	
			var divider_x_pos = header_cell_x + col_width
			if (divider_x_pos < visible_drawing_width and col <= _total_columns -1): # Non disegnare per l'ultima colonna
				draw_line(Vector2(divider_x_pos, 0), Vector2(divider_x_pos, header_height), grid_color, 2.0 if _mouse_over_divider == col else 1.0)
		header_cell_x += col_width
				
	# Disegna le righe di dati
	for r_idx in range(_visible_rows_range[0], _visible_rows_range[1]): # `row` rinominato a `r_idx`
		if r_idx >= _total_rows: continue # Safety break
		var row_y_pos = current_y_offset + (r_idx - _visible_rows_range[0]) * row_height
		
		var current_bg_color = alternate_row_color if r_idx % 2 == 1 else row_color
		draw_rect(Rect2(0, row_y_pos, visible_drawing_width, row_height), current_bg_color)
		
		if _selected_rows.has(r_idx):
			draw_rect(Rect2(0, row_y_pos, visible_drawing_width, row_height -1), selected_back_color)

		draw_line(Vector2(0, row_y_pos + row_height), Vector2(visible_drawing_width, row_y_pos + row_height), grid_color)
		
		var cell_x_pos = current_x_offset # Riferito a -_h_scroll_position
		for c_idx in range(_total_columns): # `col` rinominato a `c_idx`
			if c_idx >= _column_widths.size(): continue
			var current_col_w = _column_widths[c_idx]
			
			if cell_x_pos < visible_drawing_width and cell_x_pos + current_col_w > 0:
				draw_line(Vector2(cell_x_pos, row_y_pos), Vector2(cell_x_pos, row_y_pos + row_height), grid_color)
						
				if not (_editing_cell[0] == r_idx and _editing_cell[1] == c_idx):
					if _is_row_select_visual_col(c_idx):
						_draw_row_select_cell(cell_x_pos, row_y_pos, c_idx, r_idx)
					else:
						var data_col = _visual_to_data_col(c_idx)
						if _is_progress_column(data_col):
							_draw_progress_bar(cell_x_pos, row_y_pos, c_idx, data_col, r_idx)
						elif _is_checkbox_column(data_col):
							_draw_checkbox(cell_x_pos, row_y_pos, c_idx, data_col, r_idx)
						elif _is_image_column(data_col):
							_draw_image_cell(cell_x_pos, row_y_pos, c_idx, data_col, r_idx)
						elif _is_button_column(data_col):
							_draw_button_cell(cell_x_pos, row_y_pos, c_idx, data_col, r_idx)
						else:
							_draw_cell_text(cell_x_pos, row_y_pos, c_idx, data_col, r_idx)
			cell_x_pos += current_col_w
		
		# Disegna la linea verticale destra finale della tabella (bordo destro dell'ultima colonna)
		if cell_x_pos <= visible_drawing_width and cell_x_pos > -_h_scroll_position:
			draw_line(Vector2(cell_x_pos, row_y_pos), Vector2(cell_x_pos, row_y_pos + row_height), grid_color)
				
func _draw_row_select_cell(cell_x: float, row_y: float, visual_col: int, r_idx: int):
	var chk_size = min(row_height, _column_widths[visual_col]) * 0.6
	var x_off_centered = cell_x + (_column_widths[visual_col] - chk_size) / 2.0
	var y_off_centered = row_y + (row_height - chk_size) / 2.0
	var chk_rect = Rect2(x_off_centered, y_off_centered, chk_size, chk_size)
	draw_rect(chk_rect, checkbox_checked_color if _selected_rows.has(r_idx) else checkbox_unchecked_color)
	draw_rect(chk_rect, checkbox_border_color, false, 1.0)
	if _selected_rows.has(r_idx):
		_draw_checkbox_checkmark(chk_rect)

func _draw_progress_bar(cell_x: float, row_y: float, visual_col: int, data_col: int, r_idx: int): # `row` rinominato a `r_idx`
	var cell_val = 0.0 # Rinominato `cell_value`
	if r_idx < _data.size() and data_col < _data[r_idx].size():
		cell_val = _get_progress_value(_data[r_idx][data_col])
	
	var margin = 4.0
	var bar_x_pos = cell_x + margin # Rinominato `bar_x`
	var bar_y_pos = row_y + margin # Rinominato `bar_y`
	var bar_w = _column_widths[visual_col] - (margin * 2.0) # Rinominato `bar_width`
	var bar_h = row_height - (margin * 2.0) # Rinominato `bar_height`
	
	draw_rect(Rect2(bar_x_pos, bar_y_pos, bar_w, bar_h), progress_background_color)
	draw_rect(Rect2(bar_x_pos, bar_y_pos, bar_w, bar_h), progress_border_color, false, 1.0)
	
	var progress_w = bar_w * cell_val # Rinominato `progress_width`
	if progress_w > 0:
		draw_rect(Rect2(bar_x_pos, bar_y_pos, progress_w, bar_h), _get_interpolated_three_colors(progress_bar_start_color, progress_bar_middle_color, progress_bar_end_color, cell_val))
		
	var perc_text = str(int(round(cell_val * 100.0))) + "%" # Rinominato `percentage_text`
	var text_s = font.get_string_size(perc_text, HORIZONTAL_ALIGNMENT_CENTER, bar_w, font_size) # Rinominato `text_size`
	draw_string(font, Vector2(bar_x_pos + bar_w/2.0 - text_s.x/2.0, bar_y_pos + bar_h/2.0 + text_s.y/2.0 - 5.0), perc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, progress_text_color)

func _draw_checkbox(cell_x: float, row_y: float, visual_col: int, data_col: int, r_idx: int): # `row` rinominato a `r_idx`
	var cell_val = false # Rinominato `cell_value`
	if r_idx < _data.size() and data_col < _data[r_idx].size():
		cell_val = bool(_data[r_idx][data_col])
	
	var chk_size = min(row_height, _column_widths[visual_col]) * 0.6 # Rinominato `checkbox_size`
	var x_off_centered = cell_x + (_column_widths[visual_col] - chk_size) / 2.0 # Rinominato `x_offset_centered`
	var y_off_centered = row_y + (row_height - chk_size) / 2.0 # Rinominato `y_offset_centered`
	
	var chk_rect = Rect2(x_off_centered, y_off_centered, chk_size, chk_size) # Rinominato `checkbox_rect`
	
	draw_rect(chk_rect, checkbox_checked_color if cell_val else checkbox_unchecked_color)
	draw_rect(chk_rect, checkbox_border_color, false, 1.0) # Bordo
	if cell_val:
		_draw_checkbox_checkmark(chk_rect)

func _draw_checkbox_checkmark(chk_rect: Rect2):
	var mark_w = chk_rect.size.x
	var p1 = Vector2(chk_rect.position.x + mark_w * 0.22, chk_rect.position.y + mark_w * 0.55)
	var p2 = Vector2(chk_rect.position.x + mark_w * 0.42, chk_rect.position.y + mark_w * 0.74)
	var p3 = Vector2(chk_rect.position.x + mark_w * 0.78, chk_rect.position.y + mark_w * 0.30)
	var line_width = max(2.0, mark_w * 0.12)
	draw_line(p1, p2, checkbox_checkmark_color, line_width)
	draw_line(p2, p3, checkbox_checkmark_color, line_width)

func _draw_image_cell(cell_x: float, row_y: float, visual_col: int, data_col: int, r_idx: int):
	var value = get_cell_value(r_idx, data_col)
	if not value is Texture2D:
		return # Disegna solo se il valore è una texture

	var texture: Texture2D = value
	var margin = 2.0
	var cell_inner_width = _column_widths[visual_col] - margin * 2
	var cell_inner_height = row_height - margin * 2
	
	if cell_inner_width <= 0 or cell_inner_height <= 0: return

	var tex_size = texture.get_size()
	var tex_aspect = tex_size.x / tex_size.y
	var cell_aspect = cell_inner_width / cell_inner_height

	var draw_rect = Rect2()
	if tex_aspect > cell_aspect:
		# La texture è più "larga" della cella, adatta alla larghezza
		draw_rect.size.x = cell_inner_width
		draw_rect.size.y = cell_inner_width / tex_aspect
		draw_rect.position.x = cell_x + margin
		draw_rect.position.y = row_y + margin + (cell_inner_height - draw_rect.size.y) / 2
	else:
		# La texture è più "alta" o uguale, adatta all'altezza
		draw_rect.size.y = cell_inner_height
		draw_rect.size.x = cell_inner_height * tex_aspect
		draw_rect.position.y = row_y + margin
		draw_rect.position.x = cell_x + margin + (cell_inner_width - draw_rect.size.x) / 2
		
	draw_texture_rect(texture, draw_rect, false)

func _draw_button_cell(cell_x: float, row_y: float, visual_col: int, data_col: int, r_idx: int):
	var margin = 4.0
	var rect = Rect2(cell_x + margin, row_y + margin, _column_widths[visual_col] - margin * 2, row_height - margin * 2)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	draw_rect(rect, button_bg_color)
	draw_rect(rect, button_border_color, false, 1.0)

	var label = "Edit" if _is_edit_button_column(data_col) else "Button"
	var cell_val = get_cell_value(r_idx, data_col)
	if cell_val != null and str(cell_val) != "":
		label = str(cell_val)

	var text_s = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size)
	var pos = Vector2(rect.position.x + rect.size.x / 2.0 - text_s.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_s.y / 2.0 - (font_size / 2.0 - 2.0))
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, button_text_color)

func _get_interpolated_three_colors(start_c: Color, mid_c: Color, end_c: Color, t_val: float) -> Color: # Rinominato var
	var cl_t = clampf(t_val, 0.0, 1.0) # Rinominato `clamped_t`
	if cl_t <= 0.5:
		return start_c.lerp(mid_c, cl_t * 2.0)
	else:
		return mid_c.lerp(end_c, (cl_t - 0.5) * 2.0)

func _draw_cell_text(cell_x: float, row_y: float, visual_col: int, data_col: int, r_idx: int): # `row` rinominato a `r_idx`
	var cell_val = "" # Rinominato `cell_value`
	if r_idx >=0 and r_idx < _data.size() and data_col >=0 and data_col < _data[r_idx].size(): # Aggiunto check limiti
		cell_val = str(_data[r_idx][data_col])
	
	var align_info = _align_text_in_cell(visual_col)
	var h_align_val = align_info[1]
	var x_margin_val = align_info[2]
	
	var available_width = _column_widths[visual_col] - abs(x_margin_val) * 2
	var display_text = cell_val

	if available_width > 0:
		var text_full_size = font.get_string_size(cell_val, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_full_size.x > available_width:
			var ellipsis = "..."
			var ellipsis_width = font.get_string_size(ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var max_text_width = available_width - ellipsis_width

			if max_text_width > 0:
				var truncated_text = ""
				for i in range(cell_val.length()):
					var test_text = cell_val.substr(0, i + 1)
					var test_width = font.get_string_size(test_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					if test_width > max_text_width:
						break
					truncated_text = test_text
				display_text = truncated_text + ellipsis
			else:
				display_text = ellipsis

	var text_height = font.get_height(font_size)
	var text_y_pos = row_y + row_height / 2.0 + text_height / 2.0 - (font_size / 2.0 - 2.0)
	draw_string(font, Vector2(cell_x + x_margin_val, text_y_pos), display_text, h_align_val, available_width, font_size, default_font_color)
			
func _align_text_in_cell(col: int):
	if _is_row_select_visual_col(col):
		return ["", HORIZONTAL_ALIGNMENT_CENTER, 0]
	var data_col = _visual_to_data_col(col)
	var header_parts = _get_header_parts(data_col)
	if header_parts.size() == 0:
		return ["", HORIZONTAL_ALIGNMENT_LEFT, 5]
	var h_align_char = "" # Rinominato `_h_alignment`
	var tags = _get_header_tags(data_col)
	for char_code in tags:
		if char_code in ["l", "c", "r"]:
			h_align_char = char_code
			break
	
	var header_text_content = header_parts[0]
	var h_align_enum = HORIZONTAL_ALIGNMENT_LEFT
	var x_marg = 5 # Rinominato `x_margin`
	if (h_align_char == "c"):
		h_align_enum = HORIZONTAL_ALIGNMENT_CENTER
		x_marg = 0
	elif (h_align_char == "r"):
		h_align_enum = HORIZONTAL_ALIGNMENT_RIGHT
		x_marg = -5 # Negativo per margine destro
	return [header_text_content, h_align_enum, x_marg]

func _handle_cell_click(mouse_pos: Vector2, event: InputEventMouseButton):
	_finish_editing(true)

	var clicked_row = -1
	if row_height > 0: # Evita divisione per zero
		clicked_row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	
	if clicked_row < 0 or clicked_row >= _total_rows : # Click fuori area righe valide
		# Opzionale: deseleziona tutto se si clicca fuori
		# _selected_rows.clear()
		# _anchor_row = -1
		# _focused_row = -1
		# _focused_col = -1
		# queue_redraw()
		return

	var clicked_col = _get_visual_column_at_x(mouse_pos.x)
	if clicked_col == -1: return # Click fuori area colonne

	var is_shift = event.is_shift_pressed()
	var is_ctrl_cmd = event.is_ctrl_pressed() or event.is_meta_pressed() # Ctrl o Cmd

	var emit_multiple_selection_signal = _toggle_row_selection(clicked_row, is_shift, is_ctrl_cmd)

	if _is_row_select_visual_col(clicked_col):
		_focused_col = _data_to_visual_col(0) if _data_column_count() > 0 else -1
		cell_selected.emit(_focused_row, -1)
		if emit_multiple_selection_signal:
			multiple_rows_selected.emit(_selected_rows)
		queue_redraw()
		return

	_focused_col = clicked_col
	var signal_col = _visual_col_to_signal_col(clicked_col)
	cell_selected.emit(_focused_row, signal_col)

	# Emetti il nuovo segnale se è stata identificata una selezione multipla
	if emit_multiple_selection_signal:
		multiple_rows_selected.emit(_selected_rows)

	# Handle button column press (after selection update)
	var data_col = _visual_to_data_col(clicked_col)
	if data_col >= 0 and _is_button_column(data_col):
		button_pressed.emit(clicked_row, data_col)
		if edit_button_starts_editing and _is_edit_button_column(data_col):
			var target_col = edit_button_target_column
			if target_col < 0 or target_col >= _data_column_count():
				target_col = -1
				for c_try in range(_data_column_count()):
					if _is_text_edit_column(c_try) and _can_edit_cell_value(c_try, get_cell_value(clicked_row, c_try)):
						target_col = c_try
						break
			if target_col < 0 or target_col >= _data_column_count():
				target_col = -1
				for c_try in range(_data_column_count()):
					if c_try == data_col:
						continue
					if not _can_edit_cell_value(c_try, get_cell_value(clicked_row, c_try)):
						continue
					target_col = c_try
					break
			if target_col != -1:
				_start_cell_editing(clicked_row, _data_to_visual_col(target_col))

	queue_redraw()

func _handle_right_click(mouse_pos: Vector2):
	var r = -1 # Rinominato `row`
	var c = -1 # Rinominato `col`
	if mouse_pos.y >= header_height: # Non su header
		if row_height > 0: r = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
		if r >= 0 and r < _total_rows:
			c = _get_visual_column_at_x(mouse_pos.x)
	var signal_col = _visual_col_to_signal_col(c) if c != -1 else -1
	if (_selected_rows.size() <= 1):
		if signal_col >= 0:
			set_selected_cell(r, signal_col)
		elif r >= 0:
			_focused_row = r
		cell_right_selected.emit(r, signal_col, get_global_mouse_position())
	if (_total_rows > 0 and r <= _total_rows):
		cell_right_selected.emit(r, signal_col, get_global_mouse_position())
	elif (r > _total_rows):
		cell_right_selected.emit(_total_rows, signal_col, get_global_mouse_position())
		
func _handle_double_click(mouse_pos: Vector2):
	if mouse_pos.y >= header_height: # Non su header
		var r = -1 # Rinominato `row`
		if row_height > 0: r = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
		
		if r >= 0 and r < _total_rows:
			var c = _get_visual_column_at_x(mouse_pos.x)
			
			if c != -1 and not _is_row_select_visual_col(c):
				# Se la cella cliccata non è quella correntemente "focused" per la selezione,
				# aggiorna la selezione come un singolo click prima di iniziare l'editing.
				if not (_selected_rows.size() == 1 and _selected_rows[0] == r and _focused_row == r and _focused_col == c) :
					_focused_row = r
					_focused_col = c
					_selected_rows.clear()
					_selected_rows.append(r)
					_anchor_row = r
					cell_selected.emit(r, _visual_col_to_signal_col(c)) # Emetti segnale di selezione
					queue_redraw() # Aggiorna la vista della selezione
					
				_start_cell_editing(r, c)
		
func _handle_header_click(mouse_pos: Vector2):
	var visual_col = _get_visual_column_at_x(mouse_pos.x)
	if visual_col == -1:
		return

	if mouse_pos.x < _divider_width / 2:
		return

	_finish_editing(false)

	if _is_row_select_visual_col(visual_col):
		if row_select_header_toggle_all:
			if _selected_rows.size() == _total_rows and _total_rows > 0:
				_selected_rows.clear()
				_anchor_row = -1
				_focused_row = -1
				_focused_col = -1
			else:
				_selected_rows.clear()
				for r_idx in range(_total_rows):
					_selected_rows.append(r_idx)
				_anchor_row = 0 if _total_rows > 0 else -1
				_focused_row = 0 if _total_rows > 0 else -1
				_focused_col = _data_to_visual_col(0) if _data_column_count() > 0 and _total_rows > 0 else -1
				if _selected_rows.size() > 1:
					multiple_rows_selected.emit(_selected_rows)
			queue_redraw()
		return

	var data_col = _visual_to_data_col(visual_col)

	if checkbox_header_toggle_all and _is_checkbox_column(data_col):
		var total_count = 0
		var checked_count = 0
		for row_data in _data:
			if data_col < row_data.size():
				total_count += 1
				if bool(row_data[data_col]):
					checked_count += 1
		var new_val = true
		if total_count > 0 and checked_count == total_count:
			new_val = false
		if checkbox_single_select:
			new_val = false

		for r_idx in range(_data.size()):
			if data_col >= _data[r_idx].size():
				continue
			var old_val = _data[r_idx][data_col]
			if bool(old_val) == new_val:
				continue
			_data[r_idx][data_col] = new_val
			cell_edited.emit(r_idx, data_col, old_val, new_val)

		queue_redraw()
		header_clicked.emit(data_col)
		return

	if not _is_sort_enabled_column(data_col):
		header_clicked.emit(data_col)
		return

	if (_last_column_sorted == data_col):
		_ascending = not _ascending
	else:
		if _is_default_sort_desc_column(data_col):
			_ascending = false
		elif _is_default_sort_asc_column(data_col):
			_ascending = true
		else:
			_ascending = true
	ordering_data(data_col, _ascending)
	header_clicked.emit(data_col)

#------------------------------------------------------------
# FILTERING FUNCTIONS
#------------------------------------------------------------

func _handle_header_double_click(mouse_pos: Vector2):
	_finish_editing(false) # Termina l'editing di una cella, se attivo
	var col = _get_visual_column_at_x(mouse_pos.x)
	if col == -1 or _is_row_select_visual_col(col):
		return
	var current_x = -_h_scroll_position
	for idx in range(col):
		current_x += _column_widths[idx]
	var col_width = _column_widths[col]
	var header_rect = Rect2(current_x, 0, col_width, header_height)
	_start_filtering(_visual_to_data_col(col), header_rect)

func _start_filtering(col: int, header_rect: Rect2):
	if _filtering_column == col and _filter_line_edit.visible:
		return # Già in modalità filtro su questa colonna

	_filtering_column = col
	_filter_line_edit.position = header_rect.position + Vector2(1, 1)
	_filter_line_edit.size = header_rect.size - Vector2(2, 2)
	_filter_line_edit.text = ""
	_filter_line_edit.visible = true
	_filter_line_edit.grab_focus()

func _apply_filter(search_key: String):
	if not _filter_line_edit.visible: return
	
	_filter_line_edit.visible = false
	if _filtering_column == -1: return

	if search_key.is_empty():
		# Se la chiave è vuota, ripristina tutti i dati (rimuovi il filtro)
		_data = _full_data.duplicate(false)
		_filtering_column = -1
	else:
		var filtered_data = []
		var key_lower = search_key.to_lower()
		for row_data in _full_data:
			if _filtering_column < row_data.size() and row_data[_filtering_column] != null:
				var cell_value = str(row_data[_filtering_column]).to_lower()
				if cell_value.contains(key_lower):
					filtered_data.append(row_data) # Aggiunge il riferimento
		_data = filtered_data

	# Resetta la vista
	_total_rows = _data.size()
	_v_scroll_position = 0
	_v_scroll.value = 0
	_selected_rows.clear()
	_previous_sort_selected_rows.clear()
	_focused_row = -1
	_last_column_sorted = -1 # Resetta l'ordinamento visuale
	
	_update_scrollbars()
	queue_redraw()

func _on_filter_focus_exited():
	# Applica il filtro anche quando si perde il focus dal campo di testo
	if _filter_line_edit.visible:
		_apply_filter(_filter_line_edit.text)
	
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_btn_event = event as InputEventMouseButton
		if mouse_btn_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_btn_event.pressed:
				var m_pos = mouse_btn_event.position
				
				# Gestione doppio click
				if _click_count == 1 and _double_click_timer.time_left > 0 and _last_click_pos.distance_to(m_pos) < _click_position_threshold:
					_click_count = 0
					_double_click_timer.stop()
					if m_pos.y < header_height:
						_handle_header_double_click(m_pos) # <-- NUOVA CHIAMATA
					else:
						_handle_double_click(m_pos)
				else: # Gestione singolo click
					_click_count = 1
					_last_click_pos = m_pos
					_double_click_timer.start()

					if m_pos.y < header_height:
						# Se il LineEdit del filtro è visibile, non processare il click singolo sull'header
						if not _filter_line_edit.visible:
							_handle_header_click(m_pos)
					else:
						var checkbox_handled = _handle_checkbox_click(m_pos)
						if not checkbox_handled:
							_handle_cell_click(m_pos, mouse_btn_event)
						if _is_clicking_progress_bar(m_pos):
							_dragging_progress = true
					if _mouse_over_divider >= 0:
						_resizing_column = _mouse_over_divider
						_resizing_start_pos = m_pos.x
						_resizing_start_width = _column_widths[_resizing_column]
			else: # Mouse button released
				_resizing_column = -1
				_dragging_progress = false
				_progress_drag_row = -1
				_progress_drag_col = -1
		elif mouse_btn_event.button_index == MOUSE_BUTTON_RIGHT and mouse_btn_event.pressed:
			_handle_right_click(mouse_btn_event.position) # Usa mouse_btn_event.position
		elif mouse_btn_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _v_scroll.visible: _v_scroll.value = max(0, _v_scroll.value - _v_scroll.step * 1)
		elif mouse_btn_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _v_scroll.visible: _v_scroll.value = min(_v_scroll.max_value, _v_scroll.value + _v_scroll.step * 1)
			
	elif event is InputEventMouseMotion:
		var mouse_mot_event = event as InputEventMouseMotion # Cast
		var m_pos = mouse_mot_event.position # Rinominato `mouse_pos`
		
		if _dragging_progress and _progress_drag_row >= 0 and _progress_drag_col >= 0:
			_handle_progress_drag(m_pos)
		elif (_resizing_column >= 0 and _resizing_column < _total_columns -1 ): # Modificato headers.size() a _total_columns
			var delta_x = m_pos.x - _resizing_start_pos
			var new_width = max(_resizing_start_width + delta_x, _min_column_widths[_resizing_column])
			_column_widths[_resizing_column] = new_width
			_update_scrollbars()
			column_resized.emit(_resizing_column, new_width)
			queue_redraw()
		else:
			_check_mouse_over_divider(m_pos)
			_update_tooltip(m_pos)
	
	elif event is InputEventKey and event.is_pressed() and has_focus(): # Gestione input tastiera
		_handle_key_input(event as InputEventKey) # Chiama la nuova funzione dedicata
		# accept_event() o get_viewport().set_input_as_handled() sarà chiamato in _handle_key_input
	
func _check_mouse_over_divider(mouse_pos: Vector2):
	_mouse_over_divider = -1
	mouse_default_cursor_shape = CURSOR_ARROW
	if mouse_pos.y < header_height:
		var current_x = -_h_scroll_position
		for col in range(_total_columns -1): # Non per l'ultima colonna
			if col >= _column_widths.size(): continue
			current_x += _column_widths[col]
			var divider_rect = Rect2(current_x - _divider_width / 2, 0, _divider_width, header_height)
			if divider_rect.has_point(mouse_pos):
				_mouse_over_divider = col
				mouse_default_cursor_shape = CURSOR_HSIZE
	queue_redraw() # Aggiorna per mostrare il divisore evidenziato

func _update_tooltip(mouse_pos: Vector2):
	var current_cell = [-1, -1]
	var new_tooltip = ""

	if mouse_pos.y < header_height:
		var col = _get_visual_column_at_x(mouse_pos.x)
		if col != -1:
			new_tooltip = row_select_header_tooltip if _is_row_select_visual_col(col) else _get_header_text(col)
			current_cell = [-2, col]
	else:
		var row = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
		if row >= 0 and row < _total_rows:
			var col = _get_visual_column_at_x(mouse_pos.x)
			if col != -1:
				if _is_row_select_visual_col(col):
					new_tooltip = "Selected" if _selected_rows.has(row) else "Select row"
					current_cell = [row, -1]
				else:
					var data_col = _visual_to_data_col(col)
					if not _is_image_column(data_col) and not _is_progress_column(data_col) and not _is_checkbox_column(data_col):
						new_tooltip = str(get_cell_value(row, data_col))
					current_cell = [row, data_col]

	if current_cell != _tooltip_cell:
		_tooltip_cell = current_cell
		self.tooltip_text = new_tooltip

func _is_clicking_progress_bar(mouse_pos: Vector2) -> bool:
	if mouse_pos.y < header_height: return false
	var r = -1 # Rinominato `row`
	if row_height > 0: r = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	if r < 0 or r >= _total_rows: return false
	
	var c = _get_visual_column_at_x(mouse_pos.x)
	
	if c >= 0 and not _is_row_select_visual_col(c):
		var data_col = _visual_to_data_col(c)
		if not _is_progress_column(data_col):
			return false
		# Imposta _focused_row e _focused_col se si clicca su una progress bar
		# Questo assicura che la riga diventi "attiva"
		if _focused_row != r or _focused_col != c:
			_focused_row = r
			_focused_col = c
			# Se non è già selezionata, la si seleziona come singola
			if not _selected_rows.has(r):
				_selected_rows.clear()
				_selected_rows.append(r)
				_anchor_row = r
			cell_selected.emit(_focused_row, data_col) # Emetti segnale
			queue_redraw()

		_progress_drag_row = r
		_progress_drag_col = c
		return true
	return false

func _handle_progress_drag(mouse_pos: Vector2):
	if _progress_drag_row < 0 or _progress_drag_col < 0 or _progress_drag_col >= _column_widths.size(): return
	var data_col = _visual_to_data_col(_progress_drag_col)
	
	var current_x = -_h_scroll_position # Rinominato `x_offset`
	for c_loop in range(_progress_drag_col): current_x += _column_widths[c_loop]
	
	var margin = 4.0
	var bar_x_pos = current_x + margin
	var bar_w = _column_widths[_progress_drag_col] - (margin * 2.0)
	if bar_w <=0: return # Evita divisione per zero

	var rel_x = mouse_pos.x - bar_x_pos # Rinominato `relative_x`
	var new_prog = clamp(rel_x / bar_w, 0.0, 1.0) # Rinominato `new_progress`
	
	if _progress_drag_row < _data.size() and data_col >= 0 and data_col < _data[_progress_drag_row].size():
		_data[_progress_drag_row][data_col] = new_prog
		progress_changed.emit(_progress_drag_row, data_col, new_prog)
		queue_redraw()

func _handle_checkbox_click(mouse_pos: Vector2) -> bool:
	if mouse_pos.y < header_height: return false
	var r = -1 # Rinominato `row`
	if row_height > 0: r = floor((mouse_pos.y - header_height) / row_height) + _visible_rows_range[0]
	if r < 0 or r >= _total_rows: return false
	
	var c = _get_visual_column_at_x(mouse_pos.x)

	if c >= 0 and _is_row_select_visual_col(c):
		var emit_multiple = _toggle_row_selection(r, false, true)
		_focused_col = _data_to_visual_col(0) if _data_column_count() > 0 else -1
		cell_selected.emit(_focused_row, -1)
		if emit_multiple:
			multiple_rows_selected.emit(_selected_rows)
		queue_redraw()
		return true
	
	if c >= 0 and not _is_row_select_visual_col(c):
		var data_col = _visual_to_data_col(c)
		if not _is_checkbox_column(data_col):
			return false
		# Se si clicca su una checkbox, la riga diventa la selezione singola corrente (se non lo è già)
		if _focused_row != r or _focused_col != c :
			_focused_row = r
			_focused_col = c
			if not _selected_rows.has(r) or _selected_rows.size() > 1: # Se non è l'unica riga selezionata
				_selected_rows.clear()
				_selected_rows.append(r)
				_anchor_row = r
			cell_selected.emit(_focused_row, data_col) # Emetti il segnale per il focus
			# Non chiamare queue_redraw() qui, verrà fatto dopo update_cell

		var old_val = get_cell_value(r, data_col) # Rinominato `old_value`
		var new_val = not bool(old_val) # Rinominato `new_value`

		if checkbox_single_select and new_val:
			for r_idx in range(_data.size()):
				if r_idx == r:
					continue
				if data_col < _data[r_idx].size() and bool(_data[r_idx][data_col]):
					var prev = _data[r_idx][data_col]
					_data[r_idx][data_col] = false
					cell_edited.emit(r_idx, data_col, prev, false)

		update_cell(r, data_col, new_val) # update_cell chiama queue_redraw()
		cell_edited.emit(r, data_col, old_val, new_val)
		return true
	return false

func _ensure_row_visible(row_idx: int):
	if _total_rows == 0 or row_height == 0 or not _v_scroll.visible: return

	var visible_area_height = size.y - header_height - (_h_scroll.size.y if _h_scroll.visible else 0)
	var num_visible_rows_in_page = floor(visible_area_height / row_height)
	
	# _visible_rows_range[0] è la prima riga visibile (indice base 0)
	# _visible_rows_range[1] è l'indice della prima riga NON visibile in basso
	# Quindi le righe visibili vanno da _visible_rows_range[0] a _visible_rows_range[1] - 1
	
	var first_fully_visible_row = _visible_rows_range[0]
	# L'ultima riga completamente visibile è circa first_fully_visible_row + num_visible_rows_in_page - 1
	# Tuttavia, _visible_rows_range[1] è più preciso per il limite superiore delle righe parzialmente/totalmente visibili.
	
	if row_idx < first_fully_visible_row: # La riga è sopra la vista corrente
		_v_scroll.value = row_idx * row_height
	elif row_idx >= first_fully_visible_row + num_visible_rows_in_page: # La riga è sotto la vista corrente
		# Scroll in modo che row_idx sia l'ultima riga (o quasi) nella vista
		_v_scroll.value = (row_idx - num_visible_rows_in_page + 1) * row_height
	
	_v_scroll.value = clamp(_v_scroll.value, 0, _v_scroll.max_value)
	# _on_v_scroll_changed sarà chiamato, aggiornando _visible_rows_range e facendo queue_redraw()
func _handle_key_input(event: InputEventKey):
	if _edit_line_edit.visible: # Lascia che LineEdit gestisca l'input durante l'editing
		if event.keycode == KEY_ESCAPE: # Tranne ESC per cancellare
			_finish_editing(false)
			get_viewport().set_input_as_handled()
		return

	var keycode = event.keycode
	var is_shift = event.is_shift_pressed()
	var is_ctrl = event.is_ctrl_pressed()
	var is_meta = event.is_meta_pressed() # Cmd su Mac
	var is_ctrl_cmd = is_ctrl or is_meta # Per azioni tipo Ctrl+A/Cmd+A

	var current_focused_r = _focused_row
	var current_focused_c = _focused_col

	var new_focused_r = current_focused_r
	var new_focused_c = current_focused_c
	
	var key_operation_performed = false # Flag per tracciare se un'operazione chiave ha modificato lo stato
	var event_consumed = true # Assume che l'evento sarà consumato a meno che non sia specificato diversamente
	var emit_multiple_selection_signal = false
	
	if is_ctrl_cmd and keycode == KEY_A:
		
		if _total_rows > 0:
			_selected_rows.clear()
			for i in range(_total_rows):
				_selected_rows.append(i)
			emit_multiple_selection_signal = true
			
			# Imposta o mantiene il focus e l'ancora
			if current_focused_r == -1: # Se non c'è focus, vai alla prima riga
				_focused_row = 0
				_focused_col = _data_to_visual_col(0) if _data_column_count() > 0 else -1
				_anchor_row = 0
			else: # Altrimenti, mantieni il focus corrente come ancora
				_anchor_row = _focused_row
			
			_ensure_row_visible(_focused_row)
			# Considera _ensure_col_visible(_focused_col) se implementato
		key_operation_performed = true

	elif keycode == KEY_HOME:
		if _total_rows > 0:
			new_focused_r = 0
			new_focused_c = _data_to_visual_col(0) if _data_column_count() > 0 else -1
			key_operation_performed = true
		else:
			event_consumed = false # Nessuna riga, nessuna azione

	elif keycode == KEY_END:
		if _total_rows > 0:
			new_focused_r = _total_rows - 1
			new_focused_c = (_total_columns - 1) if _total_columns > 0 else -1
			key_operation_performed = true
		else:
			event_consumed = false # Nessuna riga, nessuna azione
			
	# Altri tasti di navigazione (generalmente richiedono un focus iniziale)
	elif current_focused_r != -1 and current_focused_c != -1 : 
		match keycode:
			KEY_UP: 
				new_focused_r = max(0, current_focused_r - 1)
				key_operation_performed = true
			KEY_DOWN: 
				new_focused_r = min(_total_rows - 1, current_focused_r + 1)
				key_operation_performed = true
			KEY_LEFT: 
				new_focused_c = max(0, current_focused_c - 1)
				key_operation_performed = true
			KEY_RIGHT: 
				new_focused_c = min(_total_columns - 1, current_focused_c + 1)
				key_operation_performed = true
			KEY_PAGEUP:
				var page_row_count = floor((size.y - header_height) / row_height) if row_height > 0 else 10
				page_row_count = max(1, page_row_count) # Assicura scorrimento di almeno 1 riga
				new_focused_r = max(0, current_focused_r - page_row_count)
				key_operation_performed = true
			KEY_PAGEDOWN:
				var page_row_count = floor((size.y - header_height) / row_height) if row_height > 0 else 10
				page_row_count = max(1, page_row_count)
				new_focused_r = min(_total_rows - 1, current_focused_r + page_row_count)
				key_operation_performed = true
			KEY_SPACE:
				if is_ctrl_cmd: 
					if _selected_rows.has(current_focused_r):
						_selected_rows.erase(current_focused_r)
					else:
						if not _selected_rows.has(current_focused_r): _selected_rows.append(current_focused_r)
					_anchor_row = current_focused_r 
					key_operation_performed = true 
				else: event_consumed = false 
			KEY_ESCAPE: 
				if _selected_rows.size() > 0 or _focused_row != -1: # Agisci solo se c'è una selezione o un focus
					_selected_rows.clear()
					_previous_sort_selected_rows.clear()
					_anchor_row = -1
					_focused_row = -1 
					_focused_col = -1
					key_operation_performed = true 
					set_selected_cell(-1, -1)
				else:
					event_consumed = false # Nessuna selezione/focus da annullare
		
	else: # Nessun focus iniziale per la maggior parte dei tasti di navigazione, o tasto non gestito sopra
		event_consumed = false

	# Se il focus è cambiato o un'operazione chiave ha modificato lo stato della selezione
	if key_operation_performed and (new_focused_r != current_focused_r or new_focused_c != current_focused_c or keycode in [KEY_HOME, KEY_END, KEY_SPACE, KEY_A]):
		var old_focused_r = _focused_row # Salva il focus precedente per l'ancora
		
		_focused_row = new_focused_r
		_focused_col = new_focused_c

		# Logica di aggiornamento della selezione
		if not (is_ctrl_cmd and keycode == KEY_A): # Ctrl+A gestisce la sua selezione
			#var emit_multiple_selection_signal = false
			if is_shift:
				# Imposta l'ancora se non è definita, usando il focus precedente o 0 come fallback
				if _anchor_row == -1: 
					_anchor_row = old_focused_r if old_focused_r != -1 else 0
				
				if _focused_row != -1: # Solo se il nuovo focus sulla riga è valido
					_selected_rows.clear()
					var start_r = min(_anchor_row, _focused_row)
					var end_r = max(_anchor_row, _focused_row)
					for i in range(start_r, end_r + 1):
						if i >= 0 and i < _total_rows: # Verifica validità indice
							if not _selected_rows.has(i): 
								_selected_rows.append(i)
								emit_multiple_selection_signal = true
				# Se _focused_row è -1 (es. tabella vuota), _selected_rows rimane vuoto o viene svuotato
				#if emit_multiple_selection_signal:
					# L'array _selected_rows contiene già gli indici corretti
					#multiple_rows_selected.emit(_selected_rows)
			
			elif is_ctrl_cmd and not (keycode == KEY_SPACE): 
				# Ctrl + Frecce/Pg/Home/End: sposta solo il focus, non cambia la selezione.
				# L'ancora non cambia per permettere future selezioni con Shift.
				pass 
			elif not (keycode == KEY_SPACE and is_ctrl_cmd): 
				# Nessun modificatore (o Ctrl non per navigazione pura): seleziona solo la riga focus
				if _focused_row != -1: # Solo se il nuovo focus sulla riga è valido
					_selected_rows.clear()
					_selected_rows.append(_focused_row)
					_anchor_row = _focused_row
					#emit_multiple_selection_signal = true
				else: # Il nuovo focus sulla riga non è valido (es. tabella vuota)
					_selected_rows.clear()
					_anchor_row = -1
				
					
		if _focused_row != -1 : 
			_ensure_row_visible(_focused_row)
			# Qui potresti aggiungere: _ensure_col_visible(_focused_col) se vuoi scorrimento orizzontale automatico
		
		if current_focused_r != _focused_row or current_focused_c != _focused_col or (keycode == KEY_SPACE and is_ctrl_cmd):
			# Emetti il segnale solo se il focus è effettivamente cambiato o se Ctrl+Spazio ha modificato la selezione
			#cell_selected.emit(_focused_row, _focused_col)
			pass
		
		if emit_multiple_selection_signal:
			# L'array _selected_rows contiene già gli indici corretti
			multiple_rows_selected.emit(_selected_rows)
		
	if key_operation_performed:
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event_consumed: # Consuma l'evento se è stato gestito parzialmente (es. tasto riconosciuto ma nessuna azione)
		get_viewport().set_input_as_handled()
