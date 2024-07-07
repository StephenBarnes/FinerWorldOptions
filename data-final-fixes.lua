local newAutoplaces = {}

for _, control in pairs(data.raw["autoplace-control"]) do
	if control.category == "resource" then
		log("Resource: " .. serpent.block(control))
		table.insert(newAutoplaces, {
			type = "autoplace-control",
			name = control.name .. "-FinerWorldOptions-multiplier",
			--intended_property = control.intended_property,
			richness = control.richness,
			order = control.order .. "-FinerWorldOptions",
			category = "resource",
			localised_name = {"autoplace-control-names.FinerWorldOptions-extension", control.localised_name or ("autoplace-control-names." .. control.name)},
			localised_description = {"autoplace-control-description.FinerWorldOptions-extension"},
			-- TODO separate ones for normal vs squared vs cubed
		})
	end
end

data:extend(newAutoplaces)