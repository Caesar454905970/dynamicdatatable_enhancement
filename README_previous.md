# DynamicDataTable for Godot 4

DynamicDataTable is a GDScript plugin for Godot 4 that allows you to create and manage dynamic data tables easily and flexibly.

![Table example](https://github.com/jospic/dynamicdatatable/blob/master/ex_table_1.png)
*Table example*

[![Some features](https://github.com/jospic/dynamicdatatable/blob/master/main_video_features_1.png)](https://www.youtube.com/watch?v=WT5OIcFDpVk)

*Click to see some features video*
 
## Features

* Dynamically create tables with customizable headers and data.
* Dynamic resizing column widths.
* Support for various data types (strings, numbers, dates in the format dd/mm/yyyy, progressbars, checkboxes, images/icon).
* Column sorting in ascending or descending order.
* Filtering rows by column.
* Cell edit mode by left mouse button double click
* Multirows selection.
* Independent horizontal alignment for columns (left, center or right).
* Mouse events on headers and data cells.
* Keyboard events on selected row (cursor up/down, page up/down, home, end).
* Appearance customization through themes and styles.
* Compatibility from Godot 4.3.
* Checkbox column: optional header click select-all + single-select mode.
* Button column: draw clickable buttons (e.g. edit button) via header tag.
* Optional dedicated row-select checkbox column on the left, independent from your data columns.

## Installation

1.  Download the plugin as a ZIP archive.
2.  Extract the archive to the `addons` folder of your Godot project.
3.  Enable the plugin from the `Project Settings > Plugins` menu.

## Usage

1.  Add a `DynamicDataTable` node to your scene, as child of a Control node.
2.  Add script to Control node and create a data array representing the table rows.
3.  Set the column headers using the `set_headers()` method.
4.  Set the table data using the `set_data()` method.
5.  Customize the table appearance through the Inspector properties.

### Column tags (header syntax)

Use `Header|tag` to add per-column behaviors:

* Alignment: `|l`, `|c`, `|r`
* Progress bar: `|p` / `|progress`
* Checkbox: `|check` / `|checkbox`
* Image: `|image` (cell value must be a `Texture2D`)
* Button: `|btn` / `|button`
* Edit button: `|edit` (a special button; can optionally start editing on click via Inspector settings)
* Disable sorting for a column: `|nosort`
* Default first sort to ascending: `|sortasc`
* Default first sort to descending: `|sortdesc`
* Disable double-click editing for a column: `|noedit` / `|readonly`
* Explicitly allow double-click editing: `|editable`
* Text-only editing for a column: `|edittext`

### Dedicated row-select column

Enable `row_select_column_enabled` in the Inspector to show a built-in checkbox column at the far left.

* This column is virtual: it does not consume an entry in `headers` and does not change your row data shape.
* Click a row checkbox to select/deselect that row.
* Click the header checkbox to select all / clear all when `row_select_header_toggle_all` is enabled.

or

Download this entire Godot Project and run the main scene (example.tscn)

## Code Example

```gdscript

extends Control

# Reference to dynamic table
@onready var dynamic_table = $DynamicTable
# Popups
@onready var popup = $PopupMenu
@onready var confirm_popup = $ConfirmationDialog
@onready var ico = load("res://addons/dynamic_table/icon.png")

var headers																				# array of columns header
var data																				# array of data, rows and columns
var current_selected_row = -1															# current selected row
var current_multiple_selected_rows = -1													# current multiple selected_rows
var multiple_selected_rows = null														# array o selected rows

func _ready():
	# Set table header
	headers = ["ID|C", "Name", "Lastname", "Age|r", "Job", "City", "Date", "Task|p", "Completed|check", "Icon|image"]
	dynamic_table.set_headers(headers)
	
	# Example data
	data = [
		[1, "Michael", "Smith", 34, "Engineer", "London", "10/12/2005", 0.5, 1, ico],
		[2, "Louis", "Johnson", 28, "Doctor", "New York", "05/11/2023", 0],
		[3, "Ann", "Williams", 42, "Lawyer", "Tokyo", "18/03/2025", 0, 0],
		[4, "John", "Brown", 31, "Teacher", "Sydney", "02/07/2024", 0, 0],
		[5, "Frances", "Jones", 25, "Designer", "Paris", "29/09/2023", 0, 0],
		[6, "Robert", "", 39, "Architect", "Berlin", "14/01/2026", 0, 0],
		[7, "Lucy", "Davis", 36, "Accountant", "Madrid", "07/04/2024", 0, 0],
		[8, "Mark", "Miller", 44, "Entrepreneur", "Toronto", "21/08/2025", 0, 0],
		[9, "Paula", "Wilson", 29, "Journalist", "Rio de Janeiro", "10/12/2023", 0, 0],
		[10, "Stephen", "Moore", 33, "Programmer", "Dubai", "30/11/2024", 0, 0],
		[11, "Mark", "Jefferson", 31, "Dentist", "Lisbona", "10/02/2018", 0.47, 1],
		[12, "James", "Taylor", 28, "Doctor", "Chicago", "03/06/2026", 0, 0],
		[13, "Carmen", "Anderson", 42, "Lawyer", "Hong Kong", "25/02/2024", 0, 0],
		[14, "John", "Thomas", 39, "Architect", "Amsterdam", "17/10/2025", 0, 0],
		[15, "Paul", "Jackson", 44, "Entrepreneur", "Singapore", "09/05/2023", 0, 0],
		[16, "Jennifer", "White", 29, "Journalist", "Cape Town", "01/03/2023", 0, 0],
		[17, "Luke", "Harris", 33, "Programmer", "Seoul", "28/04/2023", 0, 0],
		[18, "Peter", "Martin", 25, "Designer", "Mexico City", "11/08/2024", 0, 0],
		[19, "Matthew", "Thompson", 39, "Architect", "Moscow", "13/09/2024", 0, 0],
		[20, "Louise", "Garcia", 36, "Accountant", "Istanbul", "04/12/2025", 0, 0],
		[21, "Matthew", "Martinez", 44, "Entrepreneur", "Buenos Aires", "06/01/2025", 0, 0],
		[22, "Stephanie", "Robinson", 29, "Journalist", "Cairo", "22/07/2023", 0, 0],
		[23, "Christopher", "Clark", 51, "Architect", "Tokyo", "12/05/2021", 0, 0],
		[24, "Amanda", "Rodriguez", 33, "Graphic Designer", "Sydney", "11/03/2020", 0, 0],
		[25, "Daniel", "Lewis", 47, "Software Engineer", "Berlin", "03/04/2023", 0, 0],
		[26, "Victoria", "Lee", 28, "Marketing Specialist", "Toronto", "04/05/2021", 0, 0],
		[27, "Joseph", "Walker", 55, "Professor", "London", "12/05/2021", 0, 0],
		[28, "Ashley", "Young", 39, "Chef", "Paris", "22/05/2024", 0, 0],
		[29, "Kevin", "Allen", 42, "Financial Analyst", "Mexico City", "08/02/2025", 0, 0],
		[30, "Elizabeth", "King", 31, "Photographer", "Rome", "11/09/2020", 0, 0]
	]	

	# Insert data table
	dynamic_table.set_data(data)
	# Default sorted column 
	dynamic_table.ordering_data(0, true)  # 0 -> ID column and true -> ascending order
	
	# Signals connections
	dynamic_table.cell_selected.connect(_on_cell_selected)
	dynamic_table.cell_right_selected.connect(_on_cell_right_selected)
	dynamic_table.cell_edited.connect(_on_cell_edited)
	dynamic_table.header_clicked.connect(_on_header_clicked)
	dynamic_table.column_resized.connect(_on_column_resized)
	dynamic_table.multiple_rows_selected.connect(_on_multiple_rows_selected)

func _process(_delta):
	if (Input.is_key_pressed(KEY_DELETE) and (current_selected_row >= 0 or current_multiple_selected_rows > 0)):  # add support deleting items from keyboard
		_confirm_delete_rows()
		
# On selected cell callback
func _on_cell_selected(row, column):
	print("Cell selected on row ", row, ", column ", column, " Cell value: ", dynamic_table.get_cell_value(row, column), " Row value: ", dynamic_table.get_row_value(row))
	current_selected_row = row
	current_multiple_selected_rows = -1
	
# On right selected cell callback
func _on_cell_right_selected(row, column, mouse_pos):
	print("Cell right selected on row ", row, ", column ", column, " Mouse position x: ", mouse_pos.x, " y: ", mouse_pos.y)
	if (row >= 0):		# ignore header cells
		current_selected_row = row
		popup.position = mouse_pos
		if (data.size() == 0 or row == data.size()):
			popup.set("item_1/disabled", true)
			current_multiple_selected_rows = -1
		else:
			popup.set("item_1/disabled", false)
		popup.show()
		
# On multiple rows selected
func _on_multiple_rows_selected(rows: Array):
	current_multiple_selected_rows = rows.size()		# number of current multiple rows selected
	multiple_selected_rows = rows						# current multiple rows selected array
	
# On edited cell callback
func _on_cell_edited(row, column, old_value, new_value):
	print("Cell edited on row ", row, ", column ", column, " Old value: ", old_value, " New value: ", new_value)
		
# On clicked header cell callback
func _on_header_clicked(column):
	print("Header clicked on column ", column)
	
# On resized column callback
func _on_column_resized(column, new_width):
	print("Column ", column, " resized at width ", new_width)

# On pressed popup menu entry
func _on_popup_menu_id_pressed(id: int) -> void:
	if (id == 0):	# Insert data row
		dynamic_table.insert_row(current_selected_row, [0, "----", "--------", "--", "-----", "-----", "01/01/2000", 0, 0])
	else:			# Delete data row
		_confirm_delete_rows()
		
# On confirm delete row(s)
func _confirm_delete_rows():
	var dialogtext = "Are you sure you want to delete %s?"
	if (current_multiple_selected_rows > 0):
		confirm_popup.dialog_text = dialogtext % ["these " + str(current_multiple_selected_rows) + " rows"]
	else:
		confirm_popup.dialog_text = dialogtext % "this row"
	confirm_popup.show()

# On delete confirmation 
func _on_confirmation_dialog_confirmed() -> void:
	if (current_multiple_selected_rows > 0):			# multiple rows
		multiple_selected_rows.sort_custom(func(a, b): return a > b) 
		for rowidx in range (0, multiple_selected_rows.size()):
			dynamic_table.delete_row(multiple_selected_rows[rowidx])
		multiple_selected_rows.clear()
	else:
		dynamic_table.delete_row(current_selected_row)	# single row
	dynamic_table.set_selected_cell(-1, -1)				# cancel current selection
		

```	

## Support the Development

This plugin is provided free of charge to the community. If you appreciate the work that has gone into its development and find it useful, please consider making a donation. Your support helps me dedicate more time to maintaining and improving this plugin, as well as creating new free resources.

Any amount is greatly appreciated!

My [Paypal donation link](https://www.paypal.me/donatejospic?locale.x=it_IT)

BTC address: bc1quru9ev0y8hwzmdxcfrmqd3j53yaxdhvef53q7t

ETH address: 0xdB5416934F4EfBA54c804a15f3F61542CD710333

Thank you for your support!
