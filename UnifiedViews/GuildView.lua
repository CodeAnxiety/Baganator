local PopupMode = {
  Tab = "tab",
  Money = "money",
}
BaganatorGuildViewMixin = {}

function BaganatorGuildViewMixin:OnLoad()
  ButtonFrameTemplate_HidePortrait(self)
  ButtonFrameTemplate_HideButtonBar(self)
  self.Inset:Hide()
  self:RegisterForDrag("LeftButton")
  self:SetMovable(true)

  self.tabsPool = Baganator.UnifiedViews.GetSideTabButtonPool(self)
  self.currentTab = 1

  self.SearchBox:HookScript("OnTextChanged", function(_, isUserInput)
    if isUserInput and not self.SearchBox:IsInIMECompositionMode() then
      local text = self.SearchBox:GetText()
      Baganator.CallbackRegistry:TriggerEvent("SearchTextChanged", text:lower())
    end
    if self.SearchBox:GetText() == "" then
      self.SearchBox.Instructions:SetText(Baganator.Utilities.GetRandomSearchesText())
    end
  end)

  self.SearchBox.clearButton:SetScript("OnClick", function()
    Baganator.CallbackRegistry:TriggerEvent("SearchTextChanged", "")
  end)

  Baganator.CallbackRegistry:RegisterCallback("GuildCacheUpdate",  function(_, guild, tabIndex, anyChanges)
    if anyChanges then
      for _, layout in ipairs(self.Layouts) do
        layout:RequestContentRefresh()
      end
    end
    if self:IsVisible() then
      self:UpdateForGuild(guild, true)
    end
  end)

  Baganator.CallbackRegistry:RegisterCallback("GuildNameSet",  function(_, guild)
    self.lastGuild = guild
  end)

  Baganator.CallbackRegistry:RegisterCallback("ContentRefreshRequired",  function()
    for _, layout in ipairs(self.Layouts) do
      layout:RequestContentRefresh()
    end
    if self:IsVisible() then
      self:UpdateForGuild(self.lastGuild, self.isLive)
    end
  end)

  Baganator.CallbackRegistry:RegisterCallback("SettingChanged",  function(_, settingName)
    self.settingChanged = true
    if not self.lastGuild then
      return
    end
    if tIndexOf(Baganator.Config.VisualsFrameOnlySettings, settingName) ~= nil then
      if self:IsShown() then
        Baganator.Utilities.ApplyVisuals(self)
      end
    elseif tIndexOf(Baganator.Config.ItemButtonsRelayoutSettings, settingName) ~= nil then
      for _, layout in ipairs(self.Layouts) do
        layout:InformSettingChanged(settingName)
      end
      if self:IsShown() then
        self:UpdateForGuild(self.lastGuild, self.isLive)
      end
    elseif settingName == Baganator.Config.Options.SHOW_BUTTONS_ON_ALT then
      self:UpdateAllButtons()
    end
  end)

  Baganator.CallbackRegistry:RegisterCallback("SearchTextChanged",  function(_, text)
    self:ApplySearch(text)
  end)

  self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
  self:RegisterEvent("GUILDBANKLOG_UPDATE")
  self:RegisterEvent("GUILDBANK_UPDATE_TEXT")
  self:RegisterEvent("GUILDBANK_TEXT_CHANGED")

  Baganator.Utilities.AddBagTransferManager(self) -- self.transferManager

  self.confirmTransferAllDialogName = "Baganator.ConfirmTransferAll_" .. self:GetName()
  StaticPopupDialogs[self.confirmTransferAllDialogName] = {
    text = BAGANATOR_L_CONFIRM_TRANSFER_ALL_ITEMS_FROM_GUILD_BANK,
    button1 = YES,
    button2 = NO,
    OnAccept = function()
      self:RemoveSearchMatches(function() end)
    end,
    timeout = 0,
    hideOnEscape = 1,
  }
end

function BaganatorGuildViewMixin:OnEvent(eventName, ...)
  if eventName == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    local interactType = ...
    if interactType == Enum.PlayerInteractionType.GuildBanker then
      if GuildBankFrame:GetScript("OnHide") ~= nil then
        GuildBankFrame:SetScript("OnHide", nil)
        local hiddenFrame = CreateFrame("Frame")
        hiddenFrame:Hide()
        GuildBankFrame:SetParent(hiddenFrame)
      end
      self.lastGuild = Baganator.GuildCache.currentGuild
      self.isLive = true
      self:Show()
      QueryGuildBankTab(self.currentTab);
    end
  elseif eventName == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local interactType = ...
    if interactType == Enum.PlayerInteractionType.GuildBanker then
      self.isLive = false
      self:Hide()
    end
  elseif eventName == "MODIFIER_STATE_CHANGED" then
    self:UpdateAllButtons()
  elseif eventName == "GUILDBANKLOG_UPDATE" and self.LogsFrame:IsVisible() then
    if self.LogsFrame.showing == PopupMode.Tab then
      self.LogsFrame:ApplyTab()
    else
      self.LogsFrame:ApplyMoney()
    end
  elseif eventName == "GUILDBANK_UPDATE_TEXT" and self.TabTextFrame:IsVisible() then
    self.TabTextFrame:ApplyTab()
  elseif eventName == "GUILDBANK_TEXT_CHANGED" and self.TabTextFrame:IsVisible() then
    QueryGuildBankText(GetCurrentGuildBankTab());
  end
end

function BaganatorGuildViewMixin:OnShow()
  self.SearchBox.Instructions:SetText(Baganator.Utilities.GetRandomSearchesText())
  self:UpdateForGuild(self.lastGuild, self.isLive)
  self:RegisterEvent("MODIFIER_STATE_CHANGED")
end

function BaganatorGuildViewMixin:OnHide()
  self:HideInfoDialogs()
  self:UnregisterEvent("MODIFIER_STATE_CHANGED")
  CloseGuildBankFrame()
end

function BaganatorGuildViewMixin:HideInfoDialogs()
  self.LogsFrame:Hide()
  self.TabTextFrame:Hide()
end

function BaganatorGuildViewMixin:ApplySearch(text)
  self.SearchBox:SetText(text)

  if not self:IsShown() then
    return
  end

  if self.isLive then
    self.GuildLive:ApplySearch(text)
  else
    self.GuildCached:ApplySearch(text)
  end
end

function BaganatorGuildViewMixin:OnDragStart()
  if not Baganator.Config.Get(Baganator.Config.Options.LOCK_FRAMES) then
    self:StartMoving()
    self:SetUserPlaced(false)
  end
end

function BaganatorGuildViewMixin:OnDragStop()
  self:StopMovingOrSizing()
  self:SetUserPlaced(false)
  local point, _, relativePoint, x, y = self:GetPoint(1)
  Baganator.Config.Set(Baganator.Config.Options.GUILD_VIEW_POSITION, {point, UIParent:GetName(), x, y})
end

function BaganatorGuildViewMixin:OpenTabEditor()
  GuildBankPopupFrame:Hide()
  if not CanEditGuildBankTabInfo(GetCurrentGuildBankTab()) then
    return
  end
  if Baganator.Constants.IsRetail then
    GuildBankPopupFrame.mode = IconSelectorPopupFrameModes.Edit
  end
  GuildBankPopupFrame:Show()
  if not Baganator.Constants.IsRetail then
    GuildBankPopupFrame:Update()
  end
  GuildBankPopupFrame:SetParent(self)
  GuildBankPopupFrame:ClearAllPoints()
  GuildBankPopupFrame:SetClampedToScreen(true)
  GuildBankPopupFrame:SetFrameLevel(999)
  GuildBankPopupFrame:SetPoint("LEFT", self, "RIGHT", self.Tabs[1]:GetWidth(), 0)
end

function BaganatorGuildViewMixin:UpdateTabs(guildData)
  local tabScaleFactor = 37
  if Baganator.Config.Get(Baganator.Config.Options.REDUCE_SPACING) then
    tabScaleFactor = 40
  end
  local tabScale = math.min(1, Baganator.Config.Get(Baganator.Config.Options.BAG_ICON_SIZE) / tabScaleFactor)
  -- Prevent regenerating the tabs if the base info hasn't changed since last
  -- time. This avoids failed clicks on the tabs if done quickly.
  if
    -- Need to add/remove the purchase tab button
    (not self.isLive or not IsGuildLeader() or self.purchaseTabAdded) and (self.isLive or not self.purchaseTabAdded) and
    -- Changed tabs
    self.lastTabData and tCompare(guildData.bank, self.lastTabData, 2) then
    for _, tab in ipairs(self.Tabs) do
      tab:SetScale(tabScale)
    end
    return
  end

  self.tabsPool:ReleaseAll()

  local lastTab
  local tabs = {}
  self.lastTabData = {}
  for index, tabInfo in ipairs(guildData.bank) do
    local tabButton = self.tabsPool:Acquire()
    tabButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tabButton.Icon:SetTexture(tabInfo.iconTexture)
    tabButton:SetScript("OnClick", function(_, button)
      self:SetCurrentTab(index)
      self:UpdateForGuild(self.lastGuild, self.isLive)
      if self.isLive and button == "RightButton" then
        self:OpenTabEditor()
      end
    end)
    if not lastTab then
      tabButton:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, -20)
    else
      tabButton:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -12)
    end
    tabButton.SelectedTexture:Hide()
    tabButton:SetID(index)
    tabButton:SetScale(tabScale)
    tabButton:Show()
    tabButton.tabName = tabInfo.name
    tabButton:SetEnabled(tabInfo.isViewable)
    tabButton.Icon:SetDesaturated(not tabInfo.isViewable)
    lastTab = tabButton
    table.insert(tabs, tabButton)
    table.insert(self.lastTabData, CopyTable(tabInfo, 1))
  end

  if self.isLive and GetNumGuildBankTabs() < MAX_BUY_GUILDBANK_TABS and IsGuildLeader() then
    local tabButton = self.tabsPool:Acquire()
    tabButton.Icon:SetTexture("Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab")
    tabButton:SetScript("OnClick", function()
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION);
      StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
    end)
    tabButton:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -12)
    tabButton.SelectedTexture:SetShown(false)
    tabButton:SetScale(tabScale)
    tabButton:Show()
    tabButton.tabName = BUY_GUILDBANK_TAB
    tabButton:SetEnabled(true)
    tabButton.Icon:SetDesaturated(false)
    table.insert(tabs, tabButton)
    self.purchaseTabAdded = true
  else
    self.purchaseTabAdded = false
  end

  self.Tabs = tabs
end

function BaganatorGuildViewMixin:HighlightCurrentTab()
  if not self.Tabs then
    return
  end
  for tabIndex, tab in ipairs(self.Tabs) do
    tab.SelectedTexture:SetShown(tabIndex == self.currentTab)
  end
end

function BaganatorGuildViewMixin:SetCurrentTab(index)
  Baganator.CallbackRegistry:TriggerEvent("TransferCancel")
  self.currentTab = index
  self:HighlightCurrentTab()

  if self.isLive then
    SetCurrentGuildBankTab(self.currentTab)
    QueryGuildBankTab(self.currentTab);
    if GuildBankPopupFrame:IsShown() then
      self:OpenTabEditor()
    end
    if self.LogsFrame:IsShown() and self.LogsFrame.showing == PopupMode.Tab then
      self:ShowTabLogs()
    end
    if self.TabTextFrame:IsShown() then
      self:ShowTabText()
    end
  else
    self.LogsFrame:Hide()
  end
end

function BaganatorGuildViewMixin:UpdateForGuild(guild, isLive)
  guild = guild or ""

  local guildWidth = Baganator.Config.Get(Baganator.Config.Options.GUILD_VIEW_WIDTH)

  self.isLive = isLive

  self.GuildCached:SetShown(not self.isLive)
  self.GuildLive:SetShown(self.isLive)

  local guildData = BAGANATOR_DATA.Guilds[guild]
  if not guildData then
    self:SetTitle("")
    return
  else
    self.lastGuild = guild
    self:SetTitle(BAGANATOR_L_XS_GUILD_BANK:format(guildData.details.guild))
  end

  if self.isLive then
    if self.currentTab ~= GetCurrentGuildBankTab() then
      self.currentTab = GetCurrentGuildBankTab()
      if GuildBankPopupFrame:IsShown() then
        self:OpenTabEditor()
      end
    end
  end
  for _, button in ipairs(self.LiveButtons) do
    button:SetShown(self.isLive)
  end

  self:UpdateTabs(guildData)
  self:HighlightCurrentTab()

  local active

  if not self.isLive then
    self.GuildCached:ShowGuild(guild, self.currentTab, guildWidth)
    active = self.GuildCached
  else
    self.GuildLive:ShowGuild(guild, self.currentTab, guildWidth)
    active = self.GuildLive
  end

  local searchText = self.SearchBox:GetText()

  self:ApplySearch(searchText)

  self.SearchBox:ClearAllPoints()
  self.SearchBox:SetPoint("BOTTOMLEFT", active, "TOPLEFT", 5, 3)
  -- 300 is the default searchbox width
  self.SearchBox:SetWidth(math.min(300, active:GetWidth() - 5))

  if guildData.bank[1] then
    self.Tabs[1]:SetPoint("LEFT", active, "LEFT")
  end

  local sideSpacing = 13
  if Baganator.Config.Get(Baganator.Config.Options.REDUCE_SPACING) then
    sideSpacing = 8
  end

  local detailsHeight = 0
  if self.isLive then
    local _, _, _, canDeposit, _, remainingWithdrawals = GetGuildBankTabInfo(self.currentTab)
    local depositText = canDeposit and GREEN_FONT_COLOR:WrapTextInColorCode(YES) or RED_FONT_COLOR:WrapTextInColorCode(NO)
    local withdrawText
    if remainingWithdrawals == -1 then
      withdrawText = GREEN_FONT_COLOR:WrapTextInColorCode(BAGANATOR_L_UNLIMITED)
    elseif remainingWithdrawals == 0 then
      withdrawText = RED_FONT_COLOR:WrapTextInColorCode(NO)
    else
      withdrawText = FormatLargeNumber(remainingWithdrawals)
    end
    self.WithdrawalsInfo:SetText(BAGANATOR_L_GUILD_WITHDRAW_DEPOSIT_X_X:format(withdrawText, depositText))
    local withdrawMoney = GetGuildBankWithdrawMoney()
    if not CanWithdrawGuildBankMoney() then
      withdrawMoney = 0
      self.WithdrawButton:Disable()
    else
      self.WithdrawButton:Enable()
    end
    local guildMoney = GetGuildBankMoney()
    self.Money:SetText(BAGANATOR_L_GUILD_MONEY_X_X:format(GetMoneyString(math.min(withdrawMoney, guildMoney), true), GetMoneyString(guildMoney, true)))
    detailsHeight = 30

    self.TransferButton:SetShown(remainingWithdrawals == -1 or remainingWithdrawals > 0)
    self.LogsFrame:ApplyTabTitle()
  else -- not live
    self.WithdrawalsInfo:SetText("")
    self.Money:SetText(BAGANATOR_L_GUILD_MONEY_X:format(GetMoneyString(BAGANATOR_DATA.Guilds[guild].money, true)))
    detailsHeight = 10

    self.TransferButton:Hide()
    self.LogsFrame:Hide()
  end

  active:ClearAllPoints()
  active:SetPoint("TOPLEFT", sideSpacing + Baganator.Constants.ButtonFrameOffset, -50)

  self.WithdrawalsInfo:SetPoint("BOTTOMLEFT", sideSpacing + Baganator.Constants.ButtonFrameOffset, 30)
  self.Money:SetPoint("BOTTOMLEFT", sideSpacing + Baganator.Constants.ButtonFrameOffset, 10)
  self.DepositButton:SetPoint("BOTTOMRIGHT", -sideSpacing + 1, 6)

  local height = active:GetHeight() + 6
  self:SetSize(
    active:GetWidth() + sideSpacing * 2 + Baganator.Constants.ButtonFrameOffset,
    height + 60 + detailsHeight
  )

  self:UpdateAllButtons()
end

local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

function BaganatorGuildViewMixin:UpdateAllButtons()
  if self.isLive then
    self.AllButtons = CopyTable(self.FixedButtons, 1)
    tAppendAll(self.AllButtons, self.LiveButtons)
  else
    self.AllButtons = self.FixedButtons
  end
  local parent = self
  if Baganator.Config.Get(Baganator.Config.Options.SHOW_BUTTONS_ON_ALT) and not IsAltKeyDown() then
    parent = hiddenParent
  end
  for _, button in ipairs(self.AllButtons) do
    button:SetParent(parent)
    button:SetFrameLevel(700)
  end
end

function BaganatorGuildViewMixin:RemoveSearchMatches(callback)
  local matches = self.GuildLive.SearchMonitor:GetMatches()

  local emptyBagSlots = Baganator.Transfers.GetEmptyBagsSlots(BAGANATOR_DATA.Characters[Baganator.BagCache.currentCharacter].bags, Baganator.Constants.AllBagIndexes)

  local status, modes = Baganator.Transfers.FromGuildToBags(matches, Baganator.Constants.AllBagIndexes, emptyBagSlots)

  self.transferManager:Apply(status, modes or {"GuildCacheUpdate"}, function()
    self:RemoveSearchMatches(callback)
  end, function()
    callback()
  end)
end

function BaganatorGuildViewMixin:Transfer(button)
  if self.SearchBox:GetText() == "" then
    StaticPopup_Show(self.confirmTransferAllDialogName)
  else
    self:RemoveSearchMatches(function() end)
  end
end

function BaganatorGuildViewMixin:ToggleTabText()
  if self.TabTextFrame:IsShown() then
    self.TabTextFrame:Hide()
    return
  end
  self:HideInfoDialogs()
  self.TabTextFrame:Show()
  self:ShowTabText()
end

function BaganatorGuildViewMixin:ShowTabText()
  self.TabTextFrame:Show()
  self.TabTextFrame:ApplyTab()
  self.TabTextFrame:ApplyTabTitle()
  QueryGuildBankText(GetCurrentGuildBankTab());
end

function BaganatorGuildViewMixin:ToggleTabLogs()
  if self.LogsFrame.showing == PopupMode.Tab and self.LogsFrame:IsShown() then
    self.LogsFrame:Hide()
    return
  end
  self:ShowTabLogs()
end

function BaganatorGuildViewMixin:ShowTabLogs()
  self:HideInfoDialogs()
  self.LogsFrame:Show()
  self.LogsFrame:ApplyTab()
  self.LogsFrame:ApplyTabTitle()
  QueryGuildBankLog(GetCurrentGuildBankTab());
end

function BaganatorGuildViewMixin:ToggleMoneyLogs()
  if self.LogsFrame.showing == PopupMode.Money and self.LogsFrame:IsShown() then
    self.LogsFrame:Hide()
    return
  end
  self:HideInfoDialogs()
  self.LogsFrame:Show()
  self.LogsFrame:SetTitle(BAGANATOR_L_MONEY_LOGS)
  self.LogsFrame:ApplyMoney()
  QueryGuildBankLog(MAX_GUILDBANK_TABS + 1);
end

BaganatorGuildLogsTemplateMixin = {}
function BaganatorGuildLogsTemplateMixin:OnLoad()
  ButtonFrameTemplate_HidePortrait(self)
  ButtonFrameTemplate_HideButtonBar(self)
  self.Inset:Hide()
  self:RegisterForDrag("LeftButton")
  self:SetMovable(true)
  self:SetClampedToScreen(true)
  ScrollUtil.RegisterScrollBoxWithScrollBar(self.TextContainer:GetScrollBox(), self.ScrollBar)
end

function BaganatorGuildLogsTemplateMixin:OnShow()
  self:ClearAllPoints()
  self:SetPoint(unpack(Baganator.Config.Get(Baganator.Config.Options.GUILD_VIEW_DIALOG_POSITION)))
end

function BaganatorGuildLogsTemplateMixin:OnDragStart()
  if not Baganator.Config.Get(Baganator.Config.Options.LOCK_FRAMES) then
    self:StartMoving()
    self:SetUserPlaced(false)
  end
end

function BaganatorGuildLogsTemplateMixin:OnDragStop()
  self:StopMovingOrSizing()
  self:SetUserPlaced(false)
  local point, _, relativePoint, x, y = self:GetPoint(1)
  Baganator.Config.Set(Baganator.Config.Options.GUILD_VIEW_DIALOG_POSITION, {point, UIParent:GetName(), relativePoint, x, y})
end

function BaganatorGuildLogsTemplateMixin:ApplyTabTitle()
  if self.showing ~= PopupMode.Tab then return
  end

  local tabInfo = BAGANATOR_DATA.Guilds[Baganator.GuildCache.currentGuild].bank[GetCurrentGuildBankTab()]
  self:SetTitle(BAGANATOR_L_X_LOGS:format(tabInfo.name))
end

function BaganatorGuildLogsTemplateMixin:ApplyTab()
  self.showing = PopupMode.Tab

  -- Code for logs copied from Blizzard lua dumps and modified
	local tab = GetCurrentGuildBankTab();
	local numTransactions = GetNumGuildBankTransactions(tab);

	local msg = "";
	for i = numTransactions, 1, -1 do
		local type, name, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i);
		if ( not name ) then
			name = UNKNOWN;
		end
		name = NORMAL_FONT_COLOR_CODE..name..FONT_COLOR_CODE_CLOSE;
		if ( type == "deposit" ) then
			msg = msg .. format(GUILDBANK_DEPOSIT_FORMAT, name, itemLink);
			if ( count > 1 ) then
				msg = msg..format(GUILDBANK_LOG_QUANTITY, count);
			end
		elseif ( type == "withdraw" ) then
			msg = msg .. format(GUILDBANK_WITHDRAW_FORMAT, name, itemLink);
			if ( count > 1 ) then
				msg = msg..format(GUILDBANK_LOG_QUANTITY, count);
			end
		elseif ( type == "move" ) then
			msg = msg .. format(GUILDBANK_MOVE_FORMAT, name, itemLink, count, GetGuildBankTabInfo(tab1), GetGuildBankTabInfo(tab2));
		end
    msg = msg..GUILD_BANK_LOG_TIME:format(RecentTimeDate(year, month, day, hour))
    msg = msg .. "\n"
	end

  if numTransactions == 0 then
    msg = BAGANATOR_L_NO_TRANSACTIONS_AVAILABLE
  end

  self.TextContainer:SetText(msg)
end

function BaganatorGuildLogsTemplateMixin:ApplyMoney()
  self.showing = PopupMode.Money
  -- Code for logs copied from Blizzard lua dumps and modified
  local numTransactions = GetNumGuildBankMoneyTransactions();
  local msg = ""
  for i=numTransactions, 1, -1 do
    local type, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i);
    if ( not name ) then
      name = UNKNOWN;
    end
    name = NORMAL_FONT_COLOR_CODE..name..FONT_COLOR_CODE_CLOSE;
    local money = GetDenominationsFromCopper(amount);
    if ( type == "deposit" ) then
      msg = msg .. format(GUILDBANK_DEPOSIT_MONEY_FORMAT, name, money);
    elseif ( type == "withdraw" ) then
      msg = msg .. format(GUILDBANK_WITHDRAW_MONEY_FORMAT, name, money);
    elseif ( type == "repair" ) then
      msg = msg .. format(GUILDBANK_REPAIR_MONEY_FORMAT, name, money);
    elseif ( type == "withdrawForTab" ) then
      msg = msg .. format(GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT, name, money);
    elseif ( type == "buyTab" ) then
      if ( amount > 0 ) then
        msg = msg .. format(GUILDBANK_BUYTAB_MONEY_FORMAT, name, money);
      else
        msg = msg .. format(GUILDBANK_UNLOCKTAB_FORMAT, name);
      end
    elseif ( type == "depositSummary" ) then
      msg = msg .. format(GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT, money);
    end
    msg = msg..GUILD_BANK_LOG_TIME:format(RecentTimeDate(year, month, day, hour))
    msg = msg .. "\n"
  end

  if numTransactions == 0 then
    msg = BAGANATOR_L_NO_TRANSACTIONS_AVAILABLE
  end

  self.TextContainer:SetText(msg)
end

BaganatorGuildTabTextTemplateMixin = {}
function BaganatorGuildTabTextTemplateMixin:OnLoad()
  ButtonFrameTemplate_HidePortrait(self)
  ButtonFrameTemplate_HideButtonBar(self)
  self.Inset:Hide()
  self:RegisterForDrag("LeftButton")
  self:SetMovable(true)
  self:SetClampedToScreen(true)
  ScrollUtil.RegisterScrollBoxWithScrollBar(self.TextContainer:GetScrollBox(), self.ScrollBar)

  self.TextContainer:GetEditBox():SetMaxLetters(500)
end

function BaganatorGuildTabTextTemplateMixin:OnShow()
  self:ClearAllPoints()
  self:SetPoint(unpack(Baganator.Config.Get(Baganator.Config.Options.GUILD_VIEW_DIALOG_POSITION)))
end

function BaganatorGuildTabTextTemplateMixin:ApplyTab()
  local currentTab = GetCurrentGuildBankTab()
  self.TextContainer:SetText(GetGuildBankText(currentTab))
  local canEdit = CanEditGuildTabInfo(currentTab)
  self.SaveButton:SetShown(canEdit)
  self.TextContainer:GetEditBox():SetEnabled(canEdit)
end

function BaganatorGuildTabTextTemplateMixin:ApplyTabTitle()
  local tabInfo = BAGANATOR_DATA.Guilds[Baganator.GuildCache.currentGuild].bank[GetCurrentGuildBankTab()]
  self:SetTitle(BAGANATOR_L_X_INFORMATION:format(tabInfo.name))
end

function BaganatorGuildTabTextTemplateMixin:OnDragStart()
  if not Baganator.Config.Get(Baganator.Config.Options.LOCK_FRAMES) then
    self:StartMoving()
    self:SetUserPlaced(false)
  end
end

function BaganatorGuildTabTextTemplateMixin:OnDragStop()
  self:StopMovingOrSizing()
  self:SetUserPlaced(false)
  local point, _, relativePoint, x, y = self:GetPoint(1)
  Baganator.Config.Set(Baganator.Config.Options.GUILD_VIEW_DIALOG_POSITION, {point, UIParent:GetName(), x, y})
end