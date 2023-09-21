CharacterSelectSidebarMixin = {}

function CharacterSelectSidebarMixin:OnLoad()
  self:SetTitle(BAGANATOR_L_ALL_CHARACTERS)

  local function UpdateForSelection(frame)
    if frame:GetText() ~= self.selectedCharacter then
      frame:Enable()
      frame:SetAlpha(1)
    else
      frame:Disable()
      frame:SetAlpha(0.5)
    end
  end

  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(20)
  view:SetElementInitializer("Button", function(frame, elementData)
    frame:SetNormalFontObject(GameFontHighlight)
    --local fs = frame:CreateFontString(nil, nil, "GameFontHighlight")
    frame:SetText(elementData)
    --fs:SetAllPoints()
    frame:SetScript("OnClick", function()
      Baganator.CallbackRegistry:TriggerEvent("CharacterSelect", elementData)
    end)
    UpdateForSelection(frame)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)

  Baganator.CallbackRegistry:RegisterCallback("CharacterSelect", function(_, character)
    self.selectedCharacter = character
    for _, frame in self.ScrollBox:EnumerateFrames() do
      UpdateForSelection(frame)
    end
  end)

  self.SearchBox:HookScript("OnTextChanged", function()
    self:UpdateList()
  end)
end

function CharacterSelectSidebarMixin:UpdateList()
  local characters = {}
  local searchText = self.SearchBox:GetText():lower()
  for char in pairs(BAGANATOR_DATA.Characters) do
    if searchText == "" or char:lower():find(searchText, nil, true) then
      table.insert(characters, char)
    end
  end
  table.sort(characters)
  self.ScrollBox:SetDataProvider(CreateDataProvider(characters))
end

function CharacterSelectSidebarMixin:OnShow()
  self:UpdateList()
end