extends RefCounted

const OBJECTIVES: Array[Dictionary] = [
	{
		"title": "Connect Station A to Station B",
		"metric": "passenger_connected",
		"target": 1,
		"reward": 100
	},
	{
		"title": "Deliver 25 passengers",
		"metric": "passengers_delivered",
		"target": 25,
		"reward": 200
	},
	{
		"title": "Connect the forest to the terminal",
		"metric": "freight_connected",
		"target": 1,
		"reward": 150
	},
	{
		"title": "Deliver 40 logs",
		"metric": "logs_delivered",
		"target": 40,
		"reward": 300
	}
]

var current_index: int = 0


func is_complete() -> bool:
	return current_index >= OBJECTIVES.size()


func current_goal() -> Dictionary:
	if is_complete():
		return {}

	return OBJECTIVES[current_index]


func advance(metrics: Dictionary) -> Dictionary:
	var completed_count: int = 0
	var reward_total: int = 0

	while not is_complete():
		var goal: Dictionary = current_goal()
		var progress: int = int(metrics.get(goal["metric"], 0))

		if progress < int(goal["target"]):
			break

		reward_total += int(goal["reward"])
		completed_count += 1
		current_index += 1

	return {
		"completed": completed_count,
		"reward": reward_total
	}


func earned_rewards() -> int:
	var total: int = 0

	for index in range(current_index):
		total += int(OBJECTIVES[index]["reward"])

	return total
