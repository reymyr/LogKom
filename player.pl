:- dynamic(exp/3).
:- dynamic(player/8).
:- dynamic(playerEquipment/3).

/* Job, HP (and also Max HP), Attack, Defense */
growthRate(swordsman, 450, 15, 15).
growthRate(archer, 150, 25, 10).
growthRate(sorcerer, 150, 22, 10).

/* Base Stats di Level 1 */
/* Job, MaxHP, Attack, Defense, Exp, Gold */
baseStat(swordsman, 700, 40, 40, 0, 20000).
baseStat(archer, 500, 70, 20, 0, 20000).
baseStat(sorcerer, 200, 95, 10, 0, 20000).

/* Pas milih class, assert player dengan BaseStat dari jobnya */
/* Di main pas bagian inisialisasi (atau di init.pl juga boleh kalau mau */
/* assertz(Player(......)) */

initialExp :-
	retractall(exp(_,_,_)),
	assertz(exp(1,0,1)).

/* exp(Lv, _, Total) :- Total is 3*Lv*Lv - 2*Lv. */
status :- player(X, Lvl, HP, MaxHP, Att, Def, E, G),
		  playerEquipment(Weapon, Armor, Acc),
		  write('Class     : '), write(X), nl,
		  write('Level     : '), write(Lvl), nl,
		  write('HP        : '), write(HP), write('/'), write(MaxHP), nl,
          write('Attack    : '), write(Att), printEqStat(Weapon), nl,
		  write('Defense   : '), write(Def), printEqStat(Armor), nl,
		  write('Exp       : '), write(E), write('/'), exp(_,_,Total), write(Total), nl,
		  write('Gold      : '), write(G), nl, nl,
		  write('Weapon    : '), write(Weapon), nl,
		  write('Armor     : '), write(Armor), nl,
		  write('Accessory : '), write(Acc), nl.

printEqStat(X) :-
	(equipment(X, _, _, Stat) ->
		write(' (+'), write(Stat), write(')')
	;
		write('')
	).

levelUp(X) :- 
	growthRate(X, Health, Attack, Defense),
	player(Job, Lvl, HP, MaxHP, Att, Def, E, G),
	retract(player(Job, Lvl, HP, MaxHP, Att, Def, E, G)),
	NewLvl is Lvl + 1, NewHP is HP + Health, NewMax is MaxHP + Health, NewAtt is Att + Attack, NewDeff is Def + Defense,
	assertz(player(Job, NewLvl, NewHP, NewMax, NewAtt, NewDeff, E, G)).

/* Menambah gold player */
addGold(X) :-
	player(Job, Lvl, HP, MaxHP, Att, Def, E, G), NewGold is G+X,
	retract(player(Job, Lvl, HP, MaxHP, Att, Def, E, G)), 
	assertz(player(Job, Lvl, HP, MaxHP, Att, Def, E, NewGold)),
	format('You gain ~d gold ~n', [X]).


/* Menambah exp player sembari level up  */
addExp(X) :-
	exp(Lv,Xbefore,Total), NewExp is Xbefore + X,
	(X =:= 0 -> 
		write('You level up again'), nl
	; 
		format('You gain ~d exp ~n', [X])
	),
	(NewExp >= Total ->
		format('Level Up!!! ~n', []),
		NewExp2 is NewExp-Total, NewLvl is Lv + 1, NewTotal is 3*NewLvl*NewLvl - 2*NewLvl,
		retract(exp(Lv,Xbefore,Total)), assertz(exp(NewLvl,NewExp2,NewTotal)),
		player(Job, Lvl, HP, MaxHP, Att, Def, E, G),
		retract(player(Job, Lvl, HP, MaxHP, Att, Def, E, G)), assertz(player(Job, Lvl, HP, MaxHP, Att, Def, NewExp2, G)),
		levelUp(Job),
		(NewExp2 >= NewTotal ->
			addExp(0)
		;
			true
		)
	; 
		Xremain is Total-NewExp,
		format('You need ~d exp to level up ~n', [Xremain]),
		retract(exp(Lv,Xbefore,Total)), assertz(exp(Lv,NewExp,Total)),
		player(Job, Lvl, HP, MaxHP, Att, Def, E, G),
		retract(player(Job, Lvl, HP, MaxHP, Att, Def, E, G)), assertz(player(Job, Lvl, HP, MaxHP, Att, Def, NewExp, G))
	).

/* Memakai equipment dengan nama X */
equip(_) :- inBattle, !, write('Cannot equip item, you are in a battle'), fail.
equip(X) :- inventory(Inv), \+member([X, _], Inv), !, write('You do not have that item'), fail.
equip(X) :- equipment(X, Job, _, _), player(PlayerJob, _, _, _, _, _, _, _), Job \== universal, Job \== PlayerJob, !, write('You are not a/an '), write(Job), fail.
equip(X) :-
	equipment(X, _, Stat, StatInc),
	playerEquipment(Weap, Armor, Acc),
	(Stat == atk ->
		drop(X),
		(Weap \== none -> unequip(weapon), nl ; true),
		retract(playerEquipment(none, Armor, Acc)),
		assertz(playerEquipment(X, Armor, Acc)),
		write('You equipped '), write(X)
	; Stat == def ->
		drop(X),
		(Armor \== none -> unequip(armor), nl ; true),
		retract(playerEquipment(Weap, none, Acc)),
		assertz(playerEquipment(Weap, X, Acc)),
		write('You equipped '), write(X)
	;
		drop(X),
		(Acc \== none -> unequip(accessory), nl ; true),
		player(Job, Lvl, HP, MaxHP, Att, Def, E, G),
		NewHP is HP + StatInc,
		NewMaxHP is MaxHP + StatInc,
		retract(player(Job, Lvl, HP, MaxHP, Att, Def, E, G)),
		assertz(player(Job, Lvl, NewHP, NewMaxHP, Att, Def, E, G)),
		retract(playerEquipment(Weap, Armor, none)),
		assertz(playerEquipment(Weap, Armor, X)),
		write('You equipped '), write(X)
	).

/* Melepas equipment di slot X */
unequip(_) :- inBattle, !, write('Cannot unequip item, you are in a battle'), fail.
unequip(_) :- inventory(Inv), itemCount(Inv, Count), Count =:= 100, !, write('Inventory full, cannot unequip item').
unequip(X) :-
	playerEquipment(Weap, Armor, Acc),
	(X == weapon ->
		(Weap == none ->
			write('You do not have any weapon equipped')
		;
			addItem(Weap, 1),
			retract(playerEquipment(Weap, Armor, Acc)),
			assertz(playerEquipment(none, Armor, Acc)),
			write('You unequipped '), write(Weap)
		)
	; X == armor ->
		(Armor == none ->
			write('You do not have any armor equipped')
		;
			addItem(Armor, 1),
			retract(playerEquipment(Weap, Armor, Acc)),
			assertz(playerEquipment(Weap, none, Acc)),
			write('You unequipped '), write(Armor)
		)
	; X == accessory ->
		(Acc == none ->
			write('You do not have any accessory equipped')
		;
			player(Job, Lvl, HP, MaxHP, Att, Def, E, G),
			equipment(Acc, _, _, StatInc),
			NewMaxHP is MaxHP - StatInc,
			NewHPTemp is HP - StatInc,
			(NewHPTemp =< 0 -> NewHP is 1 ; NewHP is NewHPTemp),
			addItem(Acc, 1),
			retract(player(Job, Lvl, HP, MaxHP, Att, Def, E, G)),
			assertz(player(Job, Lvl, NewHP, NewMaxHP, Att, Def, E, G)),
			retract(playerEquipment(Weap, Armor, Acc)),
			assertz(playerEquipment(Weap, Armor, none)),
			write('You unequipped '), write(Acc)
		)
	;
		write('Invalid input, use "unequip(weapon). / unequip(armor). / unequip(accessory)."')
	).
