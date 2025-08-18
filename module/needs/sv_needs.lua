MadeInFrance.RegisterUsableItem("food_burger", function(data)
    MadeInFrance.SendEventToClient('useNeed', source, 'food_burger', data)
end)