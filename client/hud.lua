local hudVisible = false

local function sendHud(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

function ShowHeistHud(progress, objective, stage)
    hudVisible = true
    sendHud('show', {
        title = locale('hud_title'),
        progress = progress or 0,
        objective = objective or '',
        stage = stage or 'locate',
    })
end

function UpdateHeistHud(progress, objective, stage)
    if not hudVisible then
        ShowHeistHud(progress, objective, stage)
        return
    end

    sendHud('update', {
        progress = progress,
        objective = objective,
        stage = stage,
        title = locale('hud_title'),
    })
end

function HideHeistHud()
    if not hudVisible then return end
    hudVisible = false
    sendHud('hide')
end
