# DynamicDataTable for Godot 4 中文说明

`DynamicDataTable` 是一个适用于 Godot 4 的 GDScript 插件，用来快速创建和管理可交互的数据表格。

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
* 支持按钮列 / 编辑按钮列
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
5. 根据需要在 Inspector 中调整样式和行为

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

### 选择与进度条

* `set_selected_cell(row, column)`
* `set_progress_value(row, column, value)`
* `get_progress_value(row, column)`
* `set_progress_colors(...)`

## 示例

```gdscript
extends Control

@onready var dynamic_table = $DynamicTable
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

## 说明补充

* 当前文本列默认会在列宽不足时显示省略号 `...`
* 插件目前默认不会根据内容自动重新拉伸列宽，以保留手动设置的宽度
* 如果你在 Inspector 中手动改过某些导出属性，Godot 会优先使用场景中保存的值

## 支持开发

如果你觉得这个插件有帮助，也可以支持原作者的持续维护与开发。

原 README 中提供了捐赠方式，可参考英文版 `README.md`
