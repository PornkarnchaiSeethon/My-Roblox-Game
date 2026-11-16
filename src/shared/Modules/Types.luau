local Types = {}


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
	Slot10: number?,
}

export type StackData = {
	Name: string,
	DisplayName: string,
	Description: string,
	Image: string,
	ItemType: string,
	IsDroppable: boolean,
	Items: { Tool },
	StackId: number,
}

export type Inventory = {
	Inventory: { StackData },
	Hotbar: { [string]: number },
	NextStackId: number,
}

export type ClientStackData = {
	Name: string,
	DisplayName: string,
	Description: string,
	Image: string,
	ItemType: string,
	IsDroppable: boolean,
	Count: number,
	StackId: number,
}

export type ClientInventory = {
	Hotbar: { [string]: number },
	NextStackId: number,
	Stacks: { ClientStackData },
}

return Types
