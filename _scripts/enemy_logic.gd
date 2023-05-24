extends Node

onready var GAME_LOGIC = get_node("../")

#Enemy Specific Variables
var enemy_LP : int
var enemy_deck : Array = []
var enemy_hand : Array = []

#-------------------------------------------------------------------------------
func _ready():
	#Load  Enemy Deck
	enemy_deck = $npc_decks_gd.get_a_deck(PlayerData.going_to_duel)
	enemy_deck.shuffle()

#-------------------------------------------------------------------------------
func enemy_draw_phase():
	GAME_LOGIC.GAME_PHASE = "enemy_draw_phase"
	
	#Pull the necessary amount of cards to Enemy's Hand
	var cards_to_pull = 5 - enemy_hand.size()
	if enemy_deck.size() >= cards_to_pull: #if enemy has enough cards to pull
		for _i in range(cards_to_pull):
			enemy_hand.append(enemy_deck[0]) #add to the hand the first card from deck
			enemy_deck.remove(0) #remove that same card from deck
			
			#Update visual counter for deck size
			get_node("../../user_interface/top_info_box/com_info/deck").text = String(enemy_deck.size())
			$enemy_timer.start(0.2); yield($enemy_timer, "timeout")
	else:
		print("Enemy deck run out")
	
	#Fixed Hand for testing purposes
	#enemy_hand = []
	
	#Reset the 'has_battled' for all monsters on the field
	for i in range(5):
		var this_i_monster : Node = get_node("../../duel_field/enemy_side_zones/monster_" + String(i))
		if this_i_monster.is_visible():
			this_i_monster.this_card_flags.has_battled = false
	
	#Wait some time during draw_phase for better game flow
	$enemy_timer.start(0.5); yield($enemy_timer, "timeout")
	
	#Move to enemy's next phase
	enemy_choosing_card_to_play()

#-------------------------------------------------------------------------------
func enemy_choosing_card_to_play():
	#Create an array with Player's Monsters sorted by highest attack
	var player_monsters_sorted_by_atk : Array = []
	
	#First just add the monsters to the array
	var player_monsters_temp : Array = []
	var player_atk_temp : Array = []
	for i in range(5):
		var card_node_being_checked : Node = get_node("../../duel_field/player_side_zones/monster_" + String(i))
		var that_card_atk : int = int(card_node_being_checked.get_node("card_design/monster_features/atk_def/atk").get_text())
		if card_node_being_checked.is_visible():
			player_monsters_temp.append(card_node_being_checked)
			player_atk_temp.append(that_card_atk)
	#sort the atk reference array for better reference
	player_atk_temp.sort()
	
	#Sort the monsters by attack and get the final array
	for i in range(player_atk_temp.size()):
		for j in range(player_monsters_temp.size()):
			if int(player_monsters_temp[j].get_node("card_design/monster_features/atk_def/atk").get_text()) == player_atk_temp[i]:
				player_monsters_sorted_by_atk.push_front(player_monsters_temp[j])
	
	#Get info from Enemy's Side of the Field
	var enemy_monsters_on_field : int = 0
	for i in range(5):
		if get_node("../../duel_field/enemy_side_zones/monster_" + String(i)).is_visible():
			enemy_monsters_on_field += 1
	
	#Enemy's card choice will depend on various conditions based on the Information we just collected
	var final_card_to_play : Array = ["", "", []] #[[spelltrap_or_monster], card_id, [extra_info] ]
	
	var choose_a_spelltrap : String = "" #card_id
	if enemy_monsters_on_field > player_monsters_sorted_by_atk.size():
		#print("Enemy try a spell")
		choose_a_spelltrap = enemy_try_to_choose_spelltrap() #If enemy has more monsters than the player, it can try to play a Spell or Trap Card
		if choose_a_spelltrap != "":
			final_card_to_play = ["spelltrap", choose_a_spelltrap]
	
	var choose_a_monster : Array = [] #card_id, [cards_to_fuse...]
	if final_card_to_play[0] != "spelltrap": #If the Enemy hasn't already chosen a spell/trap to play, try to play a monster (most usual case)
		#print("Enemy try a monster")
		choose_a_monster = enemy_try_to_choose_monster(player_monsters_sorted_by_atk)
		if choose_a_monster.size() != 0:
			final_card_to_play = ["monster", choose_a_monster[0], choose_a_monster[1]]
	
	match final_card_to_play[0]:
		"spelltrap", "monster":
			#Play the final card
			enemy_play_that_card(final_card_to_play)
		_: #Default value where a card choosen didn't match anything expected
			print("No condition was matched: ", final_card_to_play)

#-------------------------------------------------------------------------------
func enemy_play_that_card(card_to_play_array : Array):
	var kind_of_card : String = card_to_play_array[0] #easy way to say it's a 'monster' or 'spelltrap' for node searching
	enemy_hand.remove(enemy_hand.find(card_to_play_array[1])) #remove the main card being played from enemy hand
	
	#Check if a fusion will happen
	var is_fusion_summon : bool = false
	if typeof(card_to_play_array[2]) == TYPE_STRING: #an optional secondary ID was passed, fuse it with first card passed
		is_fusion_summon = true
		enemy_hand.remove(enemy_hand.find(card_to_play_array[2])) #remove the extra card from Enemy Hand
	
	#Look for a Field Slot to play
	var field_node_to_use = null
	for i in range(5):
		var invisible_node = get_node("../../duel_field/enemy_side_zones/" + kind_of_card + "_" + String(i))
		if !invisible_node.is_visible():
			field_node_to_use = invisible_node
			break
	if field_node_to_use == null: #still didn't find a Free field node, use a monster on the field as part of the fusion
		print("should fuse with a card on the field") #TODO
		#enemy_fusion_order.append( the card on the field )
	
	#FUSE IF NEEDED
	var card_being_played : String = card_to_play_array[1] #by default, just the passed card. Fusion will change this
	var result_of_fusion = []
	if is_fusion_summon:
		result_of_fusion = GAME_LOGIC.fusion_list.check_for_fusion(card_to_play_array[1], card_to_play_array[2])
		card_being_played = result_of_fusion[0]
		
		#Animate the fusing of the two cards
		var fusion_timer : float = 0.8 #in seconds
		var fusion_start_pos_0 : Vector2 = Vector2(83+60, 80)
		var fusion_start_pos_1 : Vector2 = Vector2(856-60, 80)
		var fusion_final_pos : Vector2 = Vector2(475, 80)
		
		$fusion_animation/fusion_order_0.rect_position = fusion_start_pos_0
		$fusion_animation/fusion_order_1.rect_position = fusion_start_pos_1
		$fusion_animation/fusion_order_0.update_card_information(card_to_play_array[1])
		$fusion_animation/fusion_order_1.update_card_information(card_to_play_array[2])
		$fusion_animation/fusion_order_0.show()
		$fusion_animation/fusion_order_1.show()
		$fusion_animation.show()
		$fusion_animation/tween_fusion.interpolate_property($fusion_animation/fusion_order_0, "rect_position", fusion_start_pos_0, fusion_final_pos, fusion_timer, Tween.TRANS_QUINT, Tween.EASE_IN_OUT)
		$fusion_animation/tween_fusion.interpolate_property($fusion_animation/fusion_order_0, "modulate", Color(1, 1, 1, 1), Color(10, 10, 10, 0.666), fusion_timer*0.9, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		$fusion_animation/tween_fusion.interpolate_property($fusion_animation/fusion_order_1, "rect_position", fusion_start_pos_1, fusion_final_pos, fusion_timer, Tween.TRANS_QUINT, Tween.EASE_IN_OUT)
		$fusion_animation/tween_fusion.interpolate_property($fusion_animation/fusion_order_1, "modulate", Color(1, 1, 1, 1), Color(10, 10, 10, 0.666), fusion_timer*0.9, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		$fusion_animation/tween_fusion.start()
		$enemy_timer.start(fusion_timer); yield($enemy_timer, "timeout")
		$fusion_animation/fusion_order_0.hide()
		$fusion_animation/fusion_order_1.hide()
		
		#Do the changes to the resulting card
		field_node_to_use.this_card_flags.fusion_type = "fusion"
		field_node_to_use.this_card_flags.is_facedown = false
		field_node_to_use.get_node("card_design/card_back").hide()
		if typeof(result_of_fusion[1]) == TYPE_ARRAY:
			field_node_to_use.this_card_flags.fusion_type = null
			field_node_to_use.this_card_flags.atk_up = result_of_fusion[1][0]
			field_node_to_use.this_card_flags.atk_up = result_of_fusion[1][1]
		
		#Animate the showing of the result
		var fusion_result_start_size : Vector2 = Vector2(0.7, 0.7)
		var fusion_result_final_size : Vector2 = Vector2(0.9, 0.9)
		
		$fusion_animation/fusion_result_card.modulate = Color(10, 10, 10)
		$fusion_animation/fusion_result_card.rect_scale = fusion_result_start_size
		$fusion_animation/fusion_result_card.this_card_flags.fusion_type = field_node_to_use.this_card_flags.fusion_type
		$fusion_animation/fusion_result_card.update_card_information(card_being_played)
		$fusion_animation/fusion_result_card.show()
		$fusion_animation/tween_fusion.interpolate_property($fusion_animation/fusion_result_card, "modulate", Color(10, 10, 10), Color(1, 1, 1), fusion_timer*0.8, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		$fusion_animation/tween_fusion.interpolate_property($fusion_animation/fusion_result_card, "rect_scale", fusion_result_start_size, fusion_result_final_size, fusion_timer*0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		$fusion_animation/tween_fusion.start()
		$enemy_timer.start(fusion_timer*1.5); yield($enemy_timer, "timeout")
		$fusion_animation/fusion_result_card.hide()
		$fusion_animation.hide()
	
	#Update node on the field with the new card's info
	if !is_fusion_summon:
		field_node_to_use.this_card_flags.fusion_type = null
		field_node_to_use.this_card_flags.is_facedown = true
		field_node_to_use.get_node("card_design/card_back").show()
	
	#Visual Update of card on field
	field_node_to_use.this_card_id = card_being_played
	field_node_to_use.update_card_information(field_node_to_use.this_card_id)
	field_node_to_use.show()
	
	#Update UI with the summoned monster information, if card isn't facedown
	if !field_node_to_use.get_node("card_design/card_back").is_visible():
		get_node("../../").update_user_interface(field_node_to_use)
	else: #Put stuff on 'card_info_box' hidden
		get_node("../../user_interface/card_info_box/colored_bar").hide()
		get_node("../../user_interface/card_info_box/card_name").hide()
		get_node("../../user_interface/card_info_box/atk_def").hide()
		get_node("../../user_interface/card_info_box/extra_icons").hide()
		get_node("../../user_interface/card_info_box/card_text").hide()
	
	#Move to enemy's next phase
	enemy_main_phase()

#-------------------------------------------------------------------------------
func enemy_main_phase():
	GAME_LOGIC.GAME_PHASE = "enemy_main_phase"
	
	#Get monster count
	var enemy_monsters_on_field : int = 0
	for i in range(5):
		if get_node("../../duel_field/enemy_side_zones/monster_" + String(i)).is_visible():
			enemy_monsters_on_field += 1
	
	#Tries ideally once for each monster on COM's side
	for _loop_count in range(enemy_monsters_on_field):#+1):
		print("---- Start of loop ", _loop_count, " ----")
		#Get the currently strongest monster and figure out what to do with it
		var current_strongest_monster = get_com_strongest_monster()
		var player_monsters_array = get_player_monsters_array()
		
		#Catch the case where COM doesn't have a monster to attack
		if current_strongest_monster == null:
			print("COM doesn't have an available monster, ending main_phase")
			enemy_end_turn()
			return
		
		#Do the fake thinking when Player only has facedown monsters
		#TODO
		#not attack, go to the next loop interaction
		#will attack, just pass and execute code as normal
		
		#Timer for better workflow before each monster iteraction
		var battle_timer = 1
		$enemy_timer.start(battle_timer*0.8); yield($enemy_timer, "timeout")
		
		#Try a direct attack
		if player_monsters_array.size() == 0:
			print("-try direct attack")
			#DIRECT ATTACK
			if current_strongest_monster.this_card_flags.is_defense_position == true:
				current_strongest_monster.toggle_battle_position()
				$enemy_timer.start(battle_timer/2); yield($enemy_timer, "timeout")
			GAME_LOGIC.do_direct_attack(current_strongest_monster)
			
			#Battle Timer for better workflow
			$enemy_timer.start(battle_timer); yield($enemy_timer, "timeout")
		#Player has monsters, do the appropriate checks for each of COM's cards 
		else:
			print("-try regular attack")
			var com_atk = int(current_strongest_monster.get_node("card_design/monster_features/atk_def/atk").text)
			var player_atk = int(player_monsters_array[0].get_node("card_design/monster_features/atk_def/atk").text)
			var player_def = int(player_monsters_array[0].get_node("card_design/monster_features/atk_def/def").text)
			
			#Define what status to compare
			var player_status = player_atk
			if player_monsters_array[0].this_card_flags.is_defense_position == true:
				player_status = player_def
			
			#Decide between attacking a monster or being set to defense position
			if com_atk > player_status:
				print("--com atk")
				#ATTACK
				if current_strongest_monster.this_card_flags.is_defense_position == true:
					current_strongest_monster.toggle_battle_position()
					$enemy_timer.start(battle_timer/2); yield($enemy_timer, "timeout")
				GAME_LOGIC.do_battle(current_strongest_monster, player_monsters_array[0])
				
				#Battle Timer for better workflow
				$enemy_timer.start(battle_timer); yield($enemy_timer, "timeout")
				
			#If it's a Tie, COM will self destruct for monsters bigger than 3000
			elif com_atk == player_atk and player_atk >= 3000: #TODO check if COM has more monsters than player, then a suicide attack is OK
				print("--com tie")
				if current_strongest_monster.this_card_flags.is_defense_position == true:
					current_strongest_monster.toggle_battle_position()
					$enemy_timer.start(battle_timer/2); yield($enemy_timer, "timeout")
				GAME_LOGIC.do_battle(current_strongest_monster, player_monsters_array[0])
				
				#Battle Timer for better workflow
				$enemy_timer.start(battle_timer); yield($enemy_timer, "timeout")
				
			#COM's monster wasn't strong enough to battle
			else:
				print("--check for seconds")
				#Check for the second strongest monster on the field, decide if it's worth to fight it
				if player_monsters_array.size() > 1:
					var player_atk2 = int(player_monsters_array[1].get_node("card_design/monster_features/atk_def/atk").text)
					var player_def2 = int(player_monsters_array[1].get_node("card_design/monster_features/atk_def/def").text)
					#If COM is stronger than the second monster and won't be vulnerable to lose the duel
					if com_atk > player_atk2 and player_atk - com_atk <= int(get_node("../../user_interface/top_info_box/com_info/lifepoints").text) + 100 :
						if current_strongest_monster.this_card_flags.is_defense_position == true:
							current_strongest_monster.toggle_battle_position()
							$enemy_timer.start(battle_timer/2); yield($enemy_timer, "timeout")
						GAME_LOGIC.do_battle(current_strongest_monster, player_monsters_array[1])
						
						#Battle Timer for better workflow
						$enemy_timer.start(battle_timer); yield($enemy_timer, "timeout")
						
					#Attack in case the second strongest is in def position
					elif player_monsters_array[1].this_card_flags.is_defense_position == true:
						print("---check for second")
						if com_atk > player_def2:
							if current_strongest_monster.this_card_flags.is_defense_position == true:
								current_strongest_monster.toggle_battle_position()
								$enemy_timer.start(battle_timer/2); yield($enemy_timer, "timeout")
							GAME_LOGIC.do_battle(current_strongest_monster, player_monsters_array[1])
							
							#Battle Timer for better workflow
							$enemy_timer.start(battle_timer); yield($enemy_timer, "timeout")
		
		#Final additional timer before next loop iteration so battles don't overlap
		if current_strongest_monster.this_card_flags.has_battled:
			print("is waiting extra timer")
			$enemy_timer.start(battle_timer); yield($enemy_timer, "timeout")
	
	#After all monsters were checked for attack, check them individually to be set in Defense Position if it's worth it
	for i in range(5):
		var monster_being_checked = get_node("../../duel_field/enemy_side_zones/monster_" + String(i))
		if monster_being_checked.is_visible() and monster_being_checked.this_card_flags.has_battled == false and monster_being_checked.this_card_flags.is_defense_position == false:
			print("-try to put monster in Defense position")
			var com_atk = int(monster_being_checked.get_node("card_design/monster_features/atk_def/atk").text)
			var com_def = int(monster_being_checked.get_node("card_design/monster_features/atk_def/def").text)
			var player_atk = 0
			var player_monster_array = get_player_monsters_array()
			if player_monster_array.size() > 0: player_atk = int(player_monster_array[0].get_node("card_design/monster_features/atk_def/atk").text)
			
			if com_def >= com_atk or com_def >= player_atk or com_atk <= 1000 or player_atk - com_atk >= int(get_node("../../user_interface/top_info_box/com_info/lifepoints").text):
				print("--monster was set to defense")
				monster_being_checked.toggle_battle_position()
				monster_being_checked.this_card_flags.has_battled = true
				
				#Timer for better workflow
				$enemy_timer.start(1); yield($enemy_timer, "timeout")
	
	#After everything, go to End Phase
	enemy_end_turn()

#---- AUXILIARY FUNCTIONS ----#
func get_com_strongest_monster():
	var strongest_monster_node #the node to return at the end
	
	var ref_attacking_value = 0
	for i in range(5):
		if get_node("../../duel_field/enemy_side_zones/monster_" + String(i)).is_visible():
			var com_monster = get_node("../../duel_field/enemy_side_zones/monster_" + String(i))
			if int(com_monster.get_node("card_design/monster_features/atk_def/atk").text) >= ref_attacking_value and com_monster.this_card_flags.has_battled != true:
				ref_attacking_value = int(com_monster.get_node("card_design/monster_features/atk_def/atk").text) #integer of mini_card ATK text
				strongest_monster_node = com_monster
	
	return strongest_monster_node

func get_player_monsters_array():
	var initial_player_monster_array = [] #the array to return at the end
	for i in range(5):
		if get_node("../../duel_field/player_side_zones/monster_" + String(i)).is_visible():
			var player_monster_node = get_node("../../duel_field/player_side_zones/monster_" + String(i))
			initial_player_monster_array.append(player_monster_node)
	
	#organize the array order by strongest status
	var temp_atk_array = []
	for i in range(initial_player_monster_array.size()):
		temp_atk_array.append(int(initial_player_monster_array[i].get_node("card_design/monster_features/atk_def/atk").text))
	temp_atk_array.sort()
	
	var player_monsters_array = []
	for i in range(temp_atk_array.size()):
		for j in range(initial_player_monster_array.size()):
			if temp_atk_array[i] == int(initial_player_monster_array[j].get_node("card_design/monster_features/atk_def/atk").text) and !(player_monsters_array.has(initial_player_monster_array[j])):
				player_monsters_array.append(initial_player_monster_array[j])
	player_monsters_array.invert() #for some reason that is unclear to me right now, I had to invert to get the expected order from Highest to Lowest
	
	return player_monsters_array

#-------------------------------------------------------------------------------
func enemy_end_turn():
	#Wait some time before actually ending the turn for better game flow
	$enemy_timer.start(1); yield($enemy_timer, "timeout")
	
	#Move camera back to player's side of the field
	if get_node("../../duel_field").position == get_node("../../").enemy_field_camera_position:
		get_node("../../").change_field_view()
	
	#End enemy's turn, going back to player's turn
	GAME_LOGIC.get_node("player_logic").start_player_turn()


#---------------------------------------------------------------------------------------------------
# AUXILIARY FUNCTIONS
#---------------------------------------------------------------------------------------------------
func enemy_try_to_choose_spelltrap():
	var chosen_spelltrap : String = ""
	
	#Will look for the Spell traps with the Following priority:
	#Raigeki, Field Spells, Harpie's Feather Duster, Trap Cards
	
	print("enemy_try_to_choose_spelltrap not defined yet.")
	
	return chosen_spelltrap

#-------------------------------------------------------------------------------
func enemy_try_to_choose_monster(player_monsters_sorted_by_atk):
	var chosen_monster : Array = [] #card_id, [cards_to_fuse...]
	
	#First: Look for the strongest monster in Enemy's Hand
	var strongest_monster_id : String = ""
	var strongest_attack : int = 0
	for i in range(enemy_hand.size()):
		if !(CardList.card_list[enemy_hand[i]].attribute in ["spell", "trap"]): #gotta be a monster
			if CardList.card_list[enemy_hand[i]].atk >= strongest_attack:
				strongest_monster_id = enemy_hand[i]
				strongest_attack = CardList.card_list[strongest_monster_id].atk
	
	#check if the select monster is strong enough compared to player's strongest monster
	var strongest_atk_to_compare = 0
	if player_monsters_sorted_by_atk.size() != 0:
		strongest_atk_to_compare = int(player_monsters_sorted_by_atk[0].get_node("card_design/monster_features/atk_def/atk").get_text())
	if CardList.card_list[strongest_monster_id].atk >= strongest_atk_to_compare:
		chosen_monster = [strongest_monster_id, []]
	
	#Second: if couldn't find a monster Stronger than the opponent's, look for highest defense possible
	var fallback_highest_def_id : String = "" #save it in case I end up needing it
	if chosen_monster.size() == 0:
		var highest_def_moster_id : String = ""
		var highest_def : int = 0
		for i in range(enemy_hand.size()):
			if !(CardList.card_list[enemy_hand[i]].attribute in ["spell", "trap"]): #gotta be a monster
				if CardList.card_list[enemy_hand[i]].def >= highest_def and CardList.card_list[enemy_hand[i]].atk <= 3000: #avoid wasting too high atk monsters
					highest_def_moster_id = enemy_hand[i]
					highest_def = CardList.card_list[highest_def_moster_id].def
					fallback_highest_def_id = highest_def_moster_id
		
		#check if the select monster is enough to tank player's strongest monster
		if CardList.card_list[highest_def_moster_id].def >= int(player_monsters_sorted_by_atk[0].get_node("card_design/monster_features/atk_def/atk").get_text()):
			chosen_monster = [highest_def_moster_id, []]
	
	#Third: if highest DEF isn't enough, roll for doing a random fusion or just playing it anyway
	if chosen_monster.size() == 0:
		randomize()
		var fusion_chance = 0.999
		var random_roll = randf()
		
		var card_a; var card_b
		if random_roll <= fusion_chance: #Return a list of cards that can be fused: [card_id, {optional_card_for_fusion}]
			for i in range(4):
				card_a = enemy_hand[i]
				
				for j in range(4-i):
					card_b = enemy_hand[i+j+1]
					var checking_for_fusion = GAME_LOGIC.fusion_list.check_for_fusion(card_a, card_b)
					#print(checking_for_fusion)
					#FIX TO-DO TODO: check if [1] is not an array, it is when it's an "equip fusion". Basically fix so this fusion can also result in an equipment
					if typeof(checking_for_fusion[1]) != TYPE_ARRAY:
						if checking_for_fusion[1] == true: 
							#print(CardList.card_list[card_a].card_name, " and ", CardList.card_list[card_b].card_name, " resulting in ", CardList.card_list[checking_for_fusion[0]].card_name)
							chosen_monster = [card_a, card_b]
							return chosen_monster
					else: #it returned an equip array
						print("EQUIP not correctly implemented. This is just Break prevention.")
		
		#Couldn't perform any fusion, fallback and play the highest def found in previous stage of this code
		if chosen_monster.size() == 0:
			print("Enemy fallback to highest Def it could use")
			chosen_monster = [fallback_highest_def_id, []]
	
	#print("Enemy Hand was: " + CardList.card_list[enemy_hand[0]].card_name, ", " + CardList.card_list[enemy_hand[1]].card_name + ", " + CardList.card_list[enemy_hand[2]].card_name + ", " + CardList.card_list[enemy_hand[3]].card_name + ", " + CardList.card_list[enemy_hand[4]].card_name)
	return chosen_monster #card_id, [cards_to_fuse...]