local newAutoplaces = {}

for _, control in pairs(data.raw["autoplace-control"]) do
	if control.category == "resource" then
		log("Resource: " .. control.name)
	end
end