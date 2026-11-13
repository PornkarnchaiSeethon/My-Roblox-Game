local Types = {}

export type StackData = {
	Name: string,
	Description: string,
	Image: string,
	ItemType: string,
	IsDropable: boolean,
	Items: { Tool },
	StackId: number,
}

export type Armor = {
	Head: number?,
	Chest: number?,
	Legs: number?,
}

export type Hotbar = {
	Slot1: number?,
	Slot2: number?,
	Slot3: number?,
	Slot4: number?,
	Slot5: number?,
	Slot6: number?,
	Slot7: number?,
	Slot8: number?,
	Slot9: number?,
}

export type Inventory = {
	Inventory: { StackData },
	Hotbar: { [string]: number },
	Armor: { [string]: number },
	NextStackId: number,
}

return Types
