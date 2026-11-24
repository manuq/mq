extends SceneTree
## Updates the wiki pages LoreQuests-scene-graphs.md and
## StoryQuests-scene-graphs.md with the scene graph of every quest, using
## tools/show_quest_scene_graph.gd of the Threadbare checkout.
##
## Run with `mq threadbare-update-wiki-scene-graphs`. By hand, from the
## Threadbare checkout, pass the commit of main that it matches, to link it,
## and optionally the wiki checkout (default ~/repos/threadbare.wiki):
##   godot --headless --path . --script <this file> -- <commit hash> [wiki path]

const ShowQuestSceneGraph := preload("res://tools/show_quest_scene_graph.gd")
const WIKI_PATH := "repos/threadbare.wiki"
## Appended to the titles of quests with problems. Scripts to check by hand
## and several ends are not a problem.
const WARNING := " ⚠️"
const CHECK_BY_HAND_PREFIX := "Scripts that change scene in code"
const GROUPS := {
	"LoreQuests": "res://scenes/quests/lore_quests",
	"StoryQuests": "res://scenes/quests/story_quests",
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the commit of main that the checkout matches.")
		quit(1)
		return
	var commit := args[0]
	var wiki_path := (
		args[1] if args.size() > 1 else OS.get_environment("HOME").path_join(WIKI_PATH)
	)

	for group_title: String in GROUPS:
		var lines := PackedStringArray()
		lines.append("Generated with `tools/show_quest_scene_graph.gd`.")
		lines.append(
			(
				"%s as of main at [%s](https://github.com/endlessm/threadbare/commit/%s)."
				% [group_title, commit.left(9), commit]
			)
		)
		lines.append("")
		for quest in Quest.enumerate(GROUPS[group_title]):
			lines.append_array(_quest_section(quest))

		var page_path := wiki_path.path_join(group_title + "-scene-graphs.md")
		var file := FileAccess.open(page_path, FileAccess.WRITE)
		if not file:
			push_error("Can't write %s: %s" % [page_path, error_string(FileAccess.get_open_error())])
			quit(1)
			return
		file.store_string("\n".join(lines).strip_edges() + "\n")
		print("Wrote ", page_path)
	quit()


func _quest_section(quest: Quest) -> PackedStringArray:
	var lines := PackedStringArray(["### " + quest.title, "", quest.resource_path, ""])
	var report := ShowQuestSceneGraph.report(quest)
	var mermaid_index := report.find("Mermaid:")
	var findings_index := _find_prefix(report, "Ends:")
	if mermaid_index < 0 or findings_index < 0:
		# The report stopped early, for example with a broken first_scene.
		lines[0] += WARNING
		lines.append("```")
		lines.append_array(report)
		lines.append("```")
		lines.append("")
		return lines

	lines.append("```mermaid")
	lines.append_array(report.slice(mermaid_index + 1))
	lines.append("```")
	lines.append("")
	var findings := PackedStringArray()
	for section in _split_sections(report.slice(findings_index, mermaid_index)):
		var title: String = section[0]
		var items: Array = section.slice(1)
		# Nothing found, or a single end, which is the expected case.
		if title.ends_with(": none") or (title == "Ends:" and items.size() == 1):
			continue
		var is_problem := title != "Ends:" and not title.begins_with(CHECK_BY_HAND_PREFIX)
		if is_problem and not lines[0].ends_with(WARNING):
			lines[0] += WARNING
		findings.append("- " + title)
		for item: String in items:
			findings.append("  - " + item.strip_edges())
	if not findings.is_empty():
		lines.append_array(findings)
		lines.append("")
	return lines


## Groups the lines of the findings into sections: a title line followed by its
## indented items.
func _split_sections(findings_lines: PackedStringArray) -> Array[Array]:
	# Plain arrays, so appending to sections[-1] changes the stored one.
	var sections: Array[Array] = []
	for line in findings_lines:
		if line.is_empty():
			continue
		if line.begins_with("  ") and not sections.is_empty():
			sections[-1].append(line)
		else:
			sections.append([line])
	return sections


func _find_prefix(lines: PackedStringArray, prefix: String) -> int:
	for index in lines.size():
		if lines[index].begins_with(prefix):
			return index
	return -1
