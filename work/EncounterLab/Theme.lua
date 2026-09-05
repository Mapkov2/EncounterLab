local _, EL = ...
local Theme = {}
EL.Theme = Theme

-- Original controls styled to match MSUF's stock Midnight palette. No MSUF
-- implementation or media is bundled; its installed font is optional.
Theme.colors = {
    shell={.020,.039,.071,.98}, rail={.027,.063,.106,.97},
    content={.035,.067,.114,.96}, raised={.055,.098,.161,.98},
    border={.102,.173,.259,.90}, accent={.231,.510,.965,1},
    selected={.141,.365,.741,.98}, hover={.063,.145,.255,1},
    text={.933,.957,1,1}, muted={.659,.706,.780,1},
}
local mask = "Interface\\AddOns\\EncounterLab\\Media\\RoundedMask.tga"

local function layer(parent, inset, drawLayer, color)
    local textures = {}
    local points = {
        {"TOPLEFT",0,.25,0,.25}, {"TOPRIGHT",.75,1,0,.25},
        {"BOTTOMLEFT",0,.25,.75,1}, {"BOTTOMRIGHT",.75,1,.75,1},
    }
    for i, p in ipairs(points) do
        local t = parent:CreateTexture(nil, drawLayer)
        t:SetTexture(mask); t:SetTexCoord(p[2],p[3],p[4],p[5]); t:SetSize(6,6)
        t:SetPoint(p[1], parent, p[1], p[1]:find("LEFT") and inset or -inset, p[1]:find("TOP") and -inset or inset)
        textures[i] = t
    end
    local edges = {
        {"TOPLEFT",1,"TOPRIGHT","BOTTOMRIGHT",2,"BOTTOMLEFT",.25,.75,0,.25},
        {"TOPLEFT",3,"TOPRIGHT","BOTTOMRIGHT",4,"BOTTOMLEFT",.25,.75,.75,1},
        {"TOPLEFT",1,"BOTTOMLEFT","BOTTOMRIGHT",3,"TOPRIGHT",0,.25,.25,.75},
        {"TOPLEFT",2,"BOTTOMLEFT","BOTTOMRIGHT",4,"TOPRIGHT",.75,1,.25,.75},
        {"TOPLEFT",1,"BOTTOMRIGHT","BOTTOMRIGHT",4,"TOPLEFT",.25,.75,.25,.75},
    }
    for i, p in ipairs(edges) do
        local t = parent:CreateTexture(nil, drawLayer)
        t:SetTexture(mask); t:SetTexCoord(p[7],p[8],p[9],p[10])
        t:SetPoint(p[1],textures[p[2]],p[3]); t:SetPoint(p[4],textures[p[5]],p[6])
        textures[i+4] = t
    end
    for _, t in ipairs(textures) do t:SetVertexColor(unpack(color)) end
    return textures
end

function Theme.Panel(frame, color)
    layer(frame,0,"BACKGROUND",Theme.colors.border)
    local inside = layer(frame,1,"BORDER",color or Theme.colors.content)
    return function(nextColor)
        for _, t in ipairs(inside) do t:SetVertexColor(unpack(nextColor)) end
    end
end

function Theme.Font(font, size, heading)
    local face = heading and "Expressway SemiBold.ttf" or "Expressway Regular.ttf"
    if not font:SetFont("Interface\\AddOns\\MidnightSimpleUnitFrames\\Media\\Fonts\\"..face,size,"") then
        font:SetFont("Fonts\\ARIALN.TTF",size,"")
    end
    font:SetTextColor(unpack(Theme.colors.text))
    font:SetShadowColor(0,0,0,.35)
    font:SetShadowOffset(1,-1)
end
