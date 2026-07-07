# DynamicTable for Godot 4 中文说明

`DynamicTable` 是一个适用于 Godot 4 的 GDScript 表格插件，用来快速创建和管理可交互的数据表格。它支持排序、过滤、编辑、复选框、按钮列、进度条、图片列，以及运行时切换主题样式。

## 功能特性

* 动态创建表格，自定义表头和数据
* 支持动态调整列宽
* 支持多种单元格类型
* 字符串
* 数字
* 日期（格式：`dd/mm/yyyy`）
* 进度条
* 复选框
* 图片 / 图标
* 按钮 / 编辑按钮
* 支持列排序（升序 / 降序）
* 支持按列过滤
* 支持双击单元格编辑
* 支持多行选择
* 支持每列独立设置文本对齐方式
* 支持表头和单元格鼠标事件
* 支持键盘操作
* 上下方向键
* PageUp / PageDown
* Home / End
* 支持通过 Inspector 自定义外观
* 支持普通复选框列的“全选 / 单选模式”
* 支持左侧“行选择专用勾选列”
* 支持通过函数动态开启 / 关闭左侧勾选列
* 支持 Element 风格的白天 / 黑夜主题切换
* 兼容 Godot 4.3 及以上版本

## 安装方法

1. 下载插件压缩包
2. 解压到你的 Godot 项目的 `addons` 目录下
3. 打开 Godot，在 `Project Settings > Plugins` 中启用插件

## 使用方法

1. 在场景中添加一个 `DynamicTable` 节点，通常作为 `Control` 的子节点
2. 在外部脚本中准备表头数组和数据数组
3. 调用 `set_headers()` 设置表头
4. 调用 `set_data()` 设置数据
5. 根据需要在 Inspector 中调整样式、行为和主题

或者：

直接运行本仓库中的示例场景 `example.tscn`

## 表头标签写法

表头支持使用 `标题|标签1|标签2|标签3` 的形式，为某一列添加行为控制。

例如：

```gdscript
"Name|c|editable"
"Age|c|r|sortdesc"
"Completed|c|check|nosort"
"Edit|c|edit"
```

### 对齐标签

* `|l` 左对齐
* `|c` 居中对齐
* `|r` 右对齐

### 类型标签

* `|p` 或 `|progress`：进度条列
* `|check` 或 `|checkbox`：复选框列
* `|image`：图片列，单元格值必须是 `Texture2D`
* `|btn` 或 `|button`：按钮列
* `|edit`：编辑按钮列

### 排序控制标签

* `|sortasc`：首次点击表头时按升序排序
* `|sortdesc`：首次点击表头时按降序排序
* `|nosort`：禁用该列排序

### 编辑控制标签

* `|editable`：显式允许该列双击编辑
* `|noedit`：禁用该列双击编辑
* `|readonly`：只读，不允许双击编辑
* `|edittext`：只允许文本类型内容进入编辑

## 左侧行选择专用勾选列

插件支持一个内置的左侧行选择列，可在 Inspector 中开启：

* `row_select_column_enabled`
* `row_select_column_width`
* `row_select_header_toggle_all`
* `row_select_header_tooltip`

特点：

* 这是一个“虚拟列”
* 不占用 `headers` 的位置
* 不影响你的数据结构
* 点击某一行的勾选框可以选中 / 取消选中该行
* 点击表头勾选框可以全选 / 清空所有选中行
* 可以在运行时通过函数动态开启或关闭

### 动态切换左侧勾选列

```gdscript
dynamic_table.set_row_select_column_enabled(true)
dynamic_table.set_row_select_column_enabled(false)
```

可配合以下函数判断当前状态：

```gdscript
var enabled := dynamic_table.is_row_select_column_enabled()
```

### 列宽分配说明

当左侧勾选列开启时，表格会先预留 `row_select_column_width` 的宽度，再把剩余宽度分配给数据列。

说明：

* 左侧勾选列不属于 `headers`
* 如果外部只传入数据列宽数组，插件会自动在最前面补上勾选列宽度，避免列宽错位
* `set_headers()` 和勾选列开关切换时，会自动重新分配数据列宽

## 普通复选框列

普通数据列中的复选框支持以下 Inspector 行为配置：

* `checkbox_single_select`
* `true`：同一列只能勾选一项，效果类似单选
* `false`：允许多项勾选
* `checkbox_header_toggle_all`
* 是否允许点击该列表头进行全选 / 清空

当前复选框视觉风格接近 Element UI：

* 未勾选：浅灰底 + 灰边框
* 已勾选：蓝底 + 白色对勾

## 白天 / 黑夜主题

插件内置了两套接近 Element UI / Element Plus 的主题样式：

* `ThemeMode.LIGHT`
* `ThemeMode.DARK`

主题会统一切换以下元素颜色：

* 表头背景色
* 表格行背景色
* 隔行背景色
* 网格线颜色
* 文字颜色
* 选中行背景色
* 复选框颜色
* 进度条颜色
* 按钮颜色
* 过滤输入框 / 编辑输入框颜色

### Inspector 配置

可以在 Inspector 中直接设置：

* `theme_mode`

### 运行时切换主题

推荐直接调用以下函数：

```gdscript
dynamic_table.set_dark_mode(true)   # 切换为黑夜模式
dynamic_table.set_dark_mode(false)  # 切换为白天模式
```

或者：

```gdscript
dynamic_table.set_theme_mode(DynamicTable.ThemeMode.LIGHT)
dynamic_table.set_theme_mode(DynamicTable.ThemeMode.DARK)
```

读取当前主题状态：

```gdscript
var mode := dynamic_table.get_theme_mode()
var is_dark := dynamic_table.is_dark_mode()
```

## 按钮列

当列使用 `|btn`、`|button` 或 `|edit` 标签时，会绘制为按钮样式。

支持信号：

* `button_pressed(row, column)`

说明：

* `|edit` 是特殊按钮列
* 是否点击按钮后自动进入编辑，由 Inspector 中的 `edit_button_starts_editing` 控制
* `edit_button_target_column` 可指定按钮触发后编辑哪一列

## 常用信号

插件提供以下常用信号：

* `cell_selected(row, column)`
* `multiple_rows_selected(selected_row_indices)`
* `cell_right_selected(row, column, mousepos)`
* `header_clicked(column)`
* `column_resized(column, new_width)`
* `progress_changed(row, column, new_value)`
* `cell_edited(row, column, old_value, new_value)`
* `button_pressed(row, column)`

说明：

* 当点击左侧行选择专用勾选列时，`cell_selected` 的 `column` 参数为 `-1`

## 常用 API

### 基础接口

* `set_headers(new_headers)`
* `set_data(new_data)`
* `ordering_data(column_index, ascending := true)`

### 数据操作

* `insert_row(index, row_data)`
* `delete_row(index)`
* `update_cell(row, column, value)`
* `get_cell_value(row, column)`
* `get_row_value(row)`

### 选择与勾选列

* `set_selected_cell(row, column)`
* `set_row_select_column_enabled(enabled)`
* `is_row_select_column_enabled()`

### 进度条

* `set_progress_value(row, column, value)`
* `get_progress_value(row, column)`
* `set_progress_colors(bar_start_color, bar_middle_color, bar_end_color, bg_color, border_c, text_c)`

### 主题切换

* `set_theme_mode(mode)`
* `get_theme_mode()`
* `set_dark_mode(enabled)`
* `is_dark_mode()`

### 列宽辅助

* `fit_data_columns_to_control_width()`

说明：

* 当你希望按当前控件宽度重新平均分配数据列宽时，可以主动调用这个函数
* 若左侧勾选列开启，函数会自动先扣除勾选列宽度

## 示例

```gdscript
extends Control

@onready var dynamic_table: DynamicTable = $DynamicTable
@onready var ico = load("res://addons/dynamic_table/icon.png")

var headers
var data

func _ready():
	headers = [
		"ID|c|sortasc",
		"Name|c|editable",
		"Age|r|noedit",
		"Task|c|p",
		"Completed|c|check",
		"Icon|c|image",
		"Edit|c|edit"
	]

	dynamic_table.set_headers(headers)
	dynamic_table.set_dark_mode(false)
	dynamic_table.set_row_select_column_enabled(true)

	data = [
		[1, "Michael", 34, 0.5, true, ico, "Edit"],
		[2, "Louis", 28, 0.2, false, ico, "Edit"]
	]

	dynamic_table.set_data(data)
	dynamic_table.ordering_data(0, true)

	dynamic_table.button_pressed.connect(_on_button_pressed)
	dynamic_table.cell_selected.connect(_on_cell_selected)

func _on_button_pressed(row, column):
	print("Button pressed:", row, column)

func _on_cell_selected(row, column):
	print("Cell selected:", row, column)
```

## Inspector 中常见可配置项

### 表格视觉

* `default_font_color`
* `header_color`
* `grid_color`
* `row_color`
* `alternate_row_color`
* `selected_back_color`

### 左侧勾选列

* `row_select_column_enabled`
* `row_select_column_width`
* `row_select_header_toggle_all`
* `row_select_header_tooltip`

### 普通复选框行为

* `checkbox_single_select`
* `checkbox_header_toggle_all`

### 主题模式

* `theme_mode`

### 按钮行为

* `edit_button_starts_editing`
* `edit_button_target_column`

## 说明补充

* 当前文本列默认会在列宽不足时显示省略号 `...`
* 插件不会根据内容自动测量并拉伸列宽，而是保留当前列宽设定
* `set_headers()` 会按当前控件宽度平均分配数据列宽
* 如果你手动设置过 `_column_widths`，插件会尽量保留现有列宽
* 如果你在 Inspector 中手动改过某些导出属性，Godot 会优先使用场景中保存的值
* 编辑器内如果场景没有预置 `headers` 和 `data`，某些视觉效果需要运行场景后才更容易观察到

## 支持开发

如果你觉得这个插件有帮助，也可以支持原作者的持续维护与开发。

原 README 中提供了捐赠方式，可参考英文版 `README.md`
