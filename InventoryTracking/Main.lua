local function AddItemCheck()
  return Baganator.Config.Get(Baganator.Config.Options.SHOW_INVENTORY_TOOLTIPS) and (not Baganator.Config.Get(Baganator.Config.Options.SHOW_TOOLTIPS_ON_SHIFT) or IsShiftKeyDown()) 
end

local function AddToItemTooltip(tooltip, summaries, itemLink)
  Baganator.Tooltips.AddItemLines(tooltip, summaries, itemLink)
end

local function AddCurrencyCheck()
  return Baganator.Config.Get(Baganator.Config.Options.SHOW_CURRENCY_TOOLTIPS) and (not Baganator.Config.Get(Baganator.Config.Options.SHOW_TOOLTIPS_ON_SHIFT) or IsShiftKeyDown())
end

local function AddToCurrencyTooltip(tooltip, summaries, itemLink)
  Baganator.Tooltips.AddCurrencyLines(tooltip, summaries, itemLink)
end

local function InitializeSavedVariables()
  if BAGANATOR_DATA == nil then
    BAGANATOR_DATA = {
      Version = 1,
      Characters = {},
      Guilds = {},
    }
  end
end

local currentCharacter
local function InitCurrentCharacter()
  currentCharacter = Baganator.Utilities.GetCharacterFullName()

  if BAGANATOR_DATA.Characters[currentCharacter] == nil or BAGANATOR_DATA.Characters[currentCharacter].details.realmNormalized == nil then
    BAGANATOR_DATA.Characters[currentCharacter] = {
      bags = {},
      bank = {},
      money = 0,
      details = {
        realmNormalized = GetNormalizedRealmName(),
        realm = GetRealmName(),
        character = UnitName("player"),
        hidden = false,
      }
    }
  end

  local characterData = BAGANATOR_DATA.Characters[currentCharacter]
  characterData.details.className, characterData.details.class = select(2, UnitClass("player"))
  characterData.details.faction = UnitFactionGroup("player")
  characterData.details.race = select(2, UnitRace("player"))
  characterData.details.sex = UnitSex("player")
  characterData.mail = characterData.mail or {}
  characterData.equipped = characterData.equipped or {}
  characterData.containerInfo = characterData.containerInfo or {}
  characterData.currencies = characterData.currencies or {}
  characterData.void = characterData.void or {}
  characterData.auctions = characterData.auctions or {}
end

local function SetupDataProcessing()
  Baganator.Utilities.CacheConnectedRealms()

  local bagCache = CreateFrame("Frame")
  Mixin(bagCache, BaganatorBagCacheMixin)
  bagCache:OnLoad()
  bagCache:SetScript("OnEvent", bagCache.OnEvent)

  Baganator.BagCache = bagCache

  local mailCache = CreateFrame("Frame")
  Mixin(mailCache, BaganatorMailCacheMixin)
  mailCache:OnLoad()
  mailCache:SetScript("OnEvent", mailCache.OnEvent)

  Baganator.MailCache = mailCache

  local equippedCache = CreateFrame("Frame")
  Mixin(equippedCache, BaganatorEquippedCacheMixin)
  equippedCache:OnLoad()
  equippedCache:SetScript("OnEvent", equippedCache.OnEvent)

  Baganator.EquippedCache = equippedCache

  local currencyCache = CreateFrame("Frame")
  Mixin(currencyCache, BaganatorCurrencyCacheMixin)
  currencyCache:OnLoad()
  currencyCache:SetScript("OnEvent", currencyCache.OnEvent)

  Baganator.CurrencyCache = currencyCache

  local voidCache = CreateFrame("Frame")
  Mixin(voidCache, BaganatorVoidCacheMixin)
  voidCache:OnLoad()
  voidCache:SetScript("OnEvent", voidCache.OnEvent)

  Baganator.VoidCache = voidCache

  local guildCache = CreateFrame("Frame")
  Mixin(guildCache, BaganatorGuildCacheMixin)
  guildCache:OnLoad()
  guildCache:SetScript("OnEvent", guildCache.OnEvent)

  Baganator.GuildCache = guildCache

  local auctionCache = CreateFrame("Frame")
  Mixin(auctionCache, BaganatorAuctionCacheMixin)
  auctionCache:OnLoad()
  auctionCache:SetScript("OnEvent", auctionCache.OnEvent)

  Baganator.AuctionCache = auctionCache
end

local function SetupItemSummaries()
  local summaries = CreateFrame("Frame")
  Mixin(summaries, BaganatorItemSummariesMixin)
  summaries:OnLoad()
  Baganator.ItemSummaries = summaries
end

function Baganator.InventoryTracking.Initialize()
  InitializeSavedVariables()

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function()
    InitCurrentCharacter()
    SetupDataProcessing()
  end)
  SetupItemSummaries()

  Baganator.CallbackRegistry:RegisterCallback("CharacterDeleted", function(_, name)
    if name == currentCharacter then
      InitCurrentCharacter()
    end
  end)

  Baganator.CallbackRegistry:RegisterCallback("GuildNameSet", function(_, guild)
    BAGANATOR_DATA.Characters[Baganator.BagCache.currentCharacter].details.guild = guild
  end)

  if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      if tooltip == GameTooltip or tooltip == GameTooltipTooltip or tooltip == ItemRefTooltip then
        local itemName, itemLink = TooltipUtil.GetDisplayedItem(tooltip)

        -- Fix to get recipes to show the inventory data for the recipe when
        -- tooltip shown via a hyperlink
        local info = tooltip.processingInfo
        if info and info.getterName == "GetHyperlink" then
          local _, newItemLink = GetItemInfo(info.getterArgs[1])
          if newItemLink ~= nil then
            itemLink = newItemLink
          end
        elseif info and info.getterName == "GetGuildBankItem" then
          local newItemLink = GetGuildBankItemLink(info.getterArgs[1], info.getterArgs[2])
          if newItemLink ~= nil then
            itemLink = newItemLink
          end
        end

        if itemLink and AddItemCheck() then
          AddToItemTooltip(tooltip, Baganator.ItemSummaries, itemLink)
        end
      end
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tooltip, data)
      if tooltip == GameTooltip or tooltip == GameTooltipTooltip or tooltip == ItemRefTooltip then
        local data = tooltip:GetPrimaryTooltipData()
        if AddCurrencyCheck() then
          AddToCurrencyTooltip(tooltip, data.id)
        end
      end
    end)
  else
    local function SetItemTooltipHandler(tooltip)
      local ready = true
      tooltip:HookScript("OnTooltipSetItem", function(tooltip)
        if not ready then
          return
        end
        local _, itemLink = tooltip:GetItem()
        if AddItemCheck() then
          AddToItemTooltip(tooltip, Baganator.ItemSummaries, itemLink)
        end
        ready = false
      end)
      tooltip:HookScript("OnTooltipCleared", function(tooltip)
        ready = true
      end)
    end
    SetItemTooltipHandler(GameTooltip)
    SetItemTooltipHandler(ItemRefTooltip)
    local function CurrencyTooltipHandler(tooltip, index)
      local link = C_CurrencyInfo.GetCurrencyListLink(index)
      if link ~= nil then
        local currencyID = tonumber((link:match("|Hcurrency:(%d+)")))
        if currencyID ~= nil and AddCurrencyCheck() then
          AddToCurrencyTooltip(tooltip, currencyID)
        end
      end
    end
    hooksecurefunc(GameTooltip, "SetCurrencyToken", CurrencyTooltipHandler)
    hooksecurefunc(ItemRefTooltip, "SetCurrencyToken", CurrencyTooltipHandler)
  end

  if BattlePetToolTip_Show then
    local function PetTooltipShow(tooltip, speciesID, level, breedQuality, maxHealth, power, speed, ...)
      if not AddItemCheck() then
        return
      end
      -- Reconstitute item link from tooltip arguments
      local name, icon, petType = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
      local itemString = "battlepet"
      for _, part in ipairs({speciesID, level, breedQuality, maxHealth, power, speed}) do
        itemString = itemString .. ":" .. part
      end

      local quality = ITEM_QUALITY_COLORS[breedQuality].color
      local itemLink = quality:WrapTextInColorCode("|H" .. itemString .. "|h[" .. name .. "]|h")

      AddToItemTooltip(tooltip, Baganator.ItemSummaries, itemLink)
    end
    hooksecurefunc("BattlePetToolTip_Show", function(...)
      PetTooltipShow(BattlePetTooltip, ...)
    end)
    hooksecurefunc("FloatingBattlePet_Toggle", function(...)
      if FloatingBattlePetTooltip:IsShown() then
        PetTooltipShow(FloatingBattlePetTooltip, ...)
      end
    end)
  end
end
