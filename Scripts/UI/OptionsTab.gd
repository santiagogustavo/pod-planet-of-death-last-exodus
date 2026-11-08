extends MarginContainer
class_name OptionsTab

signal tab_click_focused

@onready var on_ready_bound: bool = bind_parent_container()

func bind_parent_container() -> bool:
	var parent_container: TabContainer = get_parent()
	var tab_index: int = parent_container.get_children().find(self)
	parent_container.tab_clicked.connect(func (index: int):
		if index == tab_index:
			tab_click_focused.emit()
	)
	return true
