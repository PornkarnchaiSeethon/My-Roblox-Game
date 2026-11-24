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

export type PetInstanceData = {
	UID: string,
	SpeciesId: string,
	Nickname: string,
	Stage: string,
	Level: number,
	GrowthExp: number,
	Hunger: number,
	PotentialBonus: number,
	State: string,
	LastFedAt: number?,
	BreedCooldownUntil: number,
}

export type IncubatorClientData = {
	ObjectId: string,
	EggItemId: string,
	StartedAt: number,
	HatchAt: number,
}

export type BreedingPenClientData = {
	ObjectId: string,
	ParentA_UID: string,
	ParentB_UID: string,
	StartedAt: number,
	FinishAt: number,
	HasReadyEgg: boolean,
}

export type PetModalInfo = {
	Type: "Incubator" | "Breeding",
	ObjectId: string,
}

export type PetToastInfo = {
	IsError: boolean,
	Message: string,
}

export type PlanterStateData = {
	ObjectId: string,
	PlanterType: string,
	CropId: string,
	Stage: string,
	GrowthProgress: number,
	PlantedAt: number?,
	LastSimulatedAt: number?,
	MoistureUntil: number,
	FertilizerId: string,
	HarvestsRemaining: number,
}

export type HarvestStatEntry = {
	SeedId: string,
	TotalCount: number,
}

export type PlantModalInfo = {
	ObjectId: string,
	PlanterType: string,
}

export type PlantToastInfo = {
	IsError: boolean,
	Message: string,
	Timestamp: number?,
}

export type AdminPlayerSummary = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Level: number,
	Cash: number,
	WalkSpeed: number,
}

export type AdminStackItem = {
	StackId: number,
	ItemId: string,
	DisplayName: string,
	ItemType: string,
	Count: number,
	HotbarSlot: number,
}

export type AdminPlayerDetail = {
	UserId: number,
	Name: string,
	DisplayName: string,
	AccountAge: number,
	Level: number,
	CurrentExp: number,
	ExpForNextLevel: number,
	Cash: number,
	LogInTimes: number,
	WalkSpeed: number,
	Health: number,
	MaxHealth: number,
	StackCount: number,
	MaxStacks: number,
	PetCount: number,
	ActivePlanters: number,
	PlotObjectCount: number,
	Items: { AdminStackItem },
}

export type AdminAuditEntry = {
	Timestamp: number,
	AdminName: string,
	Action: string,
	TargetName: string,
	Detail: string,
}

export type AdminToastInfo = {
	IsError: boolean,
	Message: string,
	Timestamp: number?,
}

return Types
