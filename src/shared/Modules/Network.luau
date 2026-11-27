local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages:WaitForChild("bytenet"))

local PetNetwork = ByteNet.defineNamespace("PetNetwork", function()
	local PetSummaryStruct = ByteNet.struct({
		UID = ByteNet.string,
		SpeciesId = ByteNet.string,
		Nickname = ByteNet.string,
		Stage = ByteNet.string,
		Level = ByteNet.uint16,
		GrowthExp = ByteNet.uint32,
		Hunger = ByteNet.uint8,
		PotentialBonus = ByteNet.float32,
		State = ByteNet.string,
		BreedCooldownUntil = ByteNet.uint32,
	})

	local IncubatorStruct = ByteNet.struct({
		ObjectId = ByteNet.string,
		EggItemId = ByteNet.string,
		StartedAt = ByteNet.uint32,
		HatchAt = ByteNet.uint32,
	})

	local BreedingStruct = ByteNet.struct({
		ObjectId = ByteNet.string,
		ParentA_UID = ByteNet.string,
		ParentB_UID = ByteNet.string,
		StartedAt = ByteNet.uint32,
		FinishAt = ByteNet.uint32,
		HasReadyEgg = ByteNet.bool,
	})

	return {
		RequestSync = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
		SyncState = ByteNet.definePacket({
			value = ByteNet.struct({
				MaxPetCapacity = ByteNet.uint16,
				MaxEquippedCombat = ByteNet.uint8,
				Pets = ByteNet.array(PetSummaryStruct),
				Incubators = ByteNet.array(IncubatorStruct),
				BreedingPens = ByteNet.array(BreedingStruct),
			}),
		}),
		FeedPet = ByteNet.definePacket({
			value = ByteNet.struct({
				PetUID = ByteNet.string,
				FoodItemId = ByteNet.string,
			}),
		}),
		TriggerEvolve = ByteNet.definePacket({
			value = ByteNet.struct({
				PetUID = ByteNet.string,
				CatalystItemId = ByteNet.optional(ByteNet.string),
			}),
		}),
		SetPetState = ByteNet.definePacket({
			value = ByteNet.struct({
				PetUID = ByteNet.string,
				TargetState = ByteNet.string,
			}),
		}),
		StartIncubation = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				EggItemId = ByteNet.string,
			}),
		}),
		ClaimHatchedPet = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
			}),
		}),
		StartBreeding = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				ParentA_UID = ByteNet.string,
				ParentB_UID = ByteNet.string,
			}),
		}),
		ClaimBreedingEgg = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
			}),
		}),
		OpenModal = ByteNet.definePacket({
			value = ByteNet.struct({
				ModalType = ByteNet.string,
				ObjectId = ByteNet.string,
			}),
		}),
		PetVisualEvent = ByteNet.definePacket({
			reliabilityType = "unreliable",
			value = ByteNet.struct({
				PetUID = ByteNet.string,
				EventType = ByteNet.string,
				TargetPos = ByteNet.optional(ByteNet.vec3),
			}),
		}),
		NotifyToast = ByteNet.definePacket({
			value = ByteNet.struct({
				IsError = ByteNet.bool,
				Message = ByteNet.string,
			}),
		}),
	}
end)

local PlantNetwork = ByteNet.defineNamespace("PlantNetwork", function()
	local PlanterStateStruct = ByteNet.struct({
		ObjectId = ByteNet.string,
		PlanterType = ByteNet.string,
		CropId = ByteNet.string,
		Stage = ByteNet.string,
		GrowthProgress = ByteNet.float32,
		MoistureUntil = ByteNet.uint32,
		FertilizerId = ByteNet.string,
		HarvestsRemaining = ByteNet.uint8,
	})

	local HarvestStatEntryStruct = ByteNet.struct({
		SeedId = ByteNet.string,
		TotalCount = ByteNet.uint32,
	})

	return {
		RequestSync = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
		SyncState = ByteNet.definePacket({
			value = ByteNet.struct({
				Planters = ByteNet.array(PlanterStateStruct),
				HarvestStats = ByteNet.array(HarvestStatEntryStruct),
			}),
		}),
		SyncSinglePlanter = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				IsEmpty = ByteNet.bool,
				Planter = ByteNet.optional(PlanterStateStruct),
				UpdatedStat = ByteNet.optional(HarvestStatEntryStruct),
			}),
		}),
		PlantSeed = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				SeedItemId = ByteNet.string,
			}),
		}),
		WaterPlant = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
			}),
		}),
		ApplyFertilizer = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				FertilizerItemId = ByteNet.string,
			}),
		}),
		HarvestCrop = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
			}),
		}),
		UprootPlant = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
			}),
		}),
		OpenPlantModal = ByteNet.definePacket({
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				PlanterType = ByteNet.string,
			}),
		}),
		PlantVisualEvent = ByteNet.definePacket({
			reliabilityType = "unreliable",
			value = ByteNet.struct({
				ObjectId = ByteNet.string,
				EventType = ByteNet.string,
				WorldPos = ByteNet.vec3,
			}),
		}),
		NotifyToast = ByteNet.definePacket({
			value = ByteNet.struct({
				IsError = ByteNet.bool,
				Message = ByteNet.string,
			}),
		}),
	}
end)

local AdminNetwork = ByteNet.defineNamespace("AdminNetwork", function()
	local AdminPlayerSummaryStruct = ByteNet.struct({
		UserId = ByteNet.float64,
		Name = ByteNet.string,
		DisplayName = ByteNet.string,
		Level = ByteNet.uint16,
		Cash = ByteNet.float64,
		WalkSpeed = ByteNet.float32,
	})

	local AdminStackItemStruct = ByteNet.struct({
		StackId = ByteNet.uint16,
		ItemId = ByteNet.string,
		DisplayName = ByteNet.string,
		ItemType = ByteNet.string,
		Count = ByteNet.uint16,
		HotbarSlot = ByteNet.uint8,
	})

	local AdminPlayerDetailStruct = ByteNet.struct({
		UserId = ByteNet.float64,
		Name = ByteNet.string,
		DisplayName = ByteNet.string,
		AccountAge = ByteNet.uint32,
		Level = ByteNet.uint16,
		CurrentExp = ByteNet.float64,
		ExpForNextLevel = ByteNet.float64,
		Cash = ByteNet.float64,
		LogInTimes = ByteNet.uint32,
		WalkSpeed = ByteNet.float32,
		Health = ByteNet.float32,
		MaxHealth = ByteNet.float32,
		StackCount = ByteNet.uint8,
		MaxStacks = ByteNet.uint8,
		PetCount = ByteNet.uint8,
		ActivePlanters = ByteNet.uint8,
		PlotObjectCount = ByteNet.uint16,
		Items = ByteNet.array(AdminStackItemStruct),
	})

	local AdminAuditEntryStruct = ByteNet.struct({
		Timestamp = ByteNet.uint32,
		AdminName = ByteNet.string,
		Action = ByteNet.string,
		TargetName = ByteNet.string,
		Detail = ByteNet.string,
	})

	return {
		RequestAccess = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
		SyncAccess = ByteNet.definePacket({
			value = ByteNet.struct({
				IsAdmin = ByteNet.bool,
				CurrentWalkSpeed = ByteNet.float32,
				MissingStudioItems = ByteNet.array(ByteNet.string),
			}),
		}),
		RequestPlayerList = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
		SyncPlayerList = ByteNet.definePacket({
			value = ByteNet.struct({
				Players = ByteNet.array(AdminPlayerSummaryStruct),
			}),
		}),
		RequestAuditLogs = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
		SyncAuditLogs = ByteNet.definePacket({
			value = ByteNet.struct({
				AuditLogs = ByteNet.array(AdminAuditEntryStruct),
			}),
		}),
		InspectPlayer = ByteNet.definePacket({
			value = ByteNet.struct({
				TargetUserId = ByteNet.float64,
			}),
		}),
		SyncPlayerDetail = ByteNet.definePacket({
			value = ByteNet.struct({
				Detail = AdminPlayerDetailStruct,
			}),
		}),
		GiveItem = ByteNet.definePacket({
			value = ByteNet.struct({
				TargetUserId = ByteNet.float64,
				ItemId = ByteNet.string,
				Amount = ByteNet.uint16,
			}),
		}),
		SpawnPet = ByteNet.definePacket({
			value = ByteNet.struct({
				TargetUserId = ByteNet.float64,
				SpeciesId = ByteNet.string,
				Stage = ByteNet.string,
				Amount = ByteNet.uint8,
				InitialState = ByteNet.string,
			}),
		}),
		SetSelfWalkSpeed = ByteNet.definePacket({
			value = ByteNet.struct({
				WalkSpeed = ByteNet.float32,
			}),
		}),
		NotifyToast = ByteNet.definePacket({
			value = ByteNet.struct({
				IsError = ByteNet.bool,
				Message = ByteNet.string,
			}),
		}),
	}
end)

local NPCNetwork = ByteNet.defineNamespace("NPCNetwork", function()
	local NPCBossSummaryStruct = ByteNet.struct({
		NPCUID = ByteNet.string,
		DisplayName = ByteNet.string,
		Level = ByteNet.uint16,
		HP = ByteNet.float32,
		MaxHP = ByteNet.float32,
		CastingSkillName = ByteNet.string,
	})

	return {
		PlayerAttackNPC = ByteNet.definePacket({
			value = ByteNet.struct({
				NPCUID = ByteNet.string,
			}),
		}),
		InteractNPC = ByteNet.definePacket({
			value = ByteNet.struct({
				NPCUID = ByteNet.string,
			}),
		}),
		OpenNPCDialogue = ByteNet.definePacket({
			value = ByteNet.struct({
				NPCUID = ByteNet.string,
				DisplayName = ByteNet.string,
				Lines = ByteNet.array(ByteNet.string),
			}),
		}),
		SyncBosses = ByteNet.definePacket({
			value = ByteNet.struct({
				Bosses = ByteNet.array(NPCBossSummaryStruct),
			}),
		}),
		NPCTelegraphEvent = ByteNet.definePacket({
			reliabilityType = "unreliable",
			value = ByteNet.struct({
				NPCUID = ByteNet.string,
				SkillId = ByteNet.string,
				Shape = ByteNet.string,
				Origin = ByteNet.vec3,
				LookVector = ByteNet.vec3,
				Radius = ByteNet.float32,
				BoxSize = ByteNet.vec3,
				Duration = ByteNet.float32,
			}),
		}),
		NPCVisualEvent = ByteNet.definePacket({
			reliabilityType = "unreliable",
			value = ByteNet.struct({
				NPCUID = ByteNet.string,
				EventType = ByteNet.string,
				WorldPos = ByteNet.vec3,
				Amount = ByteNet.int32,
			}),
		}),
		NotifyToast = ByteNet.definePacket({
			value = ByteNet.struct({
				IsError = ByteNet.bool,
				Message = ByteNet.string,
			}),
		}),
	}
end)

return {
	Pet = PetNetwork,
	PetNetwork = PetNetwork,
	Plant = PlantNetwork,
	PlantNetwork = PlantNetwork,
	Admin = AdminNetwork,
	AdminNetwork = AdminNetwork,
	NPC = NPCNetwork,
	NPCNetwork = NPCNetwork,
	Inventory = ByteNet.defineNamespace("InventoryNetwork", function()
		local ClientStack = ByteNet.struct({
			Name = ByteNet.string,
			DisplayName = ByteNet.string,
			Description = ByteNet.string,
			Image = ByteNet.string,
			ItemType = ByteNet.string,
			IsDroppable = ByteNet.bool,
			Count = ByteNet.uint16,
			StackId = ByteNet.int32,
		})

		local ClientInventory = ByteNet.struct({
			Hotbar = ByteNet.map(ByteNet.string, ByteNet.int32),
			NextStackId = ByteNet.int32,
			Stacks = ByteNet.array(ClientStack),
		})

		return {
			Request = ByteNet.definePacket({
				value = ByteNet.nothing,
			}),
			EquipToHotbar = ByteNet.definePacket({
				value = ByteNet.struct({
					stackId = ByteNet.int32,
					slotNum = ByteNet.uint8,
				}),
			}),
			UnequipFromHotbar = ByteNet.definePacket({
				value = ByteNet.struct({
					stackId = ByteNet.int32,
				}),
			}),
			HoldItem = ByteNet.definePacket({
				value = ByteNet.struct({
					slotNum = ByteNet.uint8,
				}),
			}),
			UnholdItems = ByteNet.definePacket({
				value = ByteNet.nothing,
			}),
			DropItem = ByteNet.definePacket({
				value = ByteNet.struct({
					stackId = ByteNet.int32,
				}),
			}),
			Update = ByteNet.definePacket({
				value = ClientInventory,
			}),
			Error = ByteNet.definePacket({
				value = ByteNet.string,
			}),
		}
	end),
	Plot = ByteNet.defineNamespace("PlotNetwork", function()
		return {
			Request = ByteNet.definePacket({
				value = ByteNet.nothing,
			}),
			Ready = ByteNet.definePacket({
				value = ByteNet.struct({
					plot = ByteNet.inst,
				}),
			}),
			TryPlace = ByteNet.definePacket({
				value = ByteNet.struct({
					name = ByteNet.string,
					targetCF = ByteNet.cframe,
				}),
			}),
			TryDelete = ByteNet.definePacket({
				value = ByteNet.struct({
					target = ByteNet.inst,
				}),
			}),
		}
	end),
}
