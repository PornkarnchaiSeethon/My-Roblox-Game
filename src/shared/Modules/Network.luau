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

return {
	Pet = PetNetwork,
	PetNetwork = PetNetwork,
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
