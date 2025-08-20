LSLegacy.RegisterClientEvent('useIdCard', function(data)
    LSLegacy.ShowNotification('Identité', 'Prénom : '..data.Prenom..'\nNom : '..data.NDF..'\nDate de naissance : '..data.DDN..'\nLieu de naissance : '..data.LDN..'\nTaille : '..data.Taille..'cm', 'info')
end)