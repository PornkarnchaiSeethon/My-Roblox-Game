local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages:WaitForChild("bytenet"))

return {
	Inventory = ByteNet.defineNamespace("InventoryNetwork", function()
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
				value = ByteNet.string,
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
