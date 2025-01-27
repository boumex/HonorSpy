HonorSpy = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0", "AceComm-2.0", "AceHook-2.1")
local T = AceLibrary("Tablet-2.0")

HonorSpy:RegisterDB("HonorSpyDB")
HonorSpy:RegisterDefaults('realm', {
	hs = {
		limit = 750,
		currentStandings = {},
		last_reset = 0,
		sort = "ThisWeekHonor"
	}
})

local commPrefix = "HonorSpy";
HonorSpy:SetCommPrefix(commPrefix)

local VERSION = "4K4";
local paused = false; -- pause all inspections when user opens inspect frame
local playerName = UnitName("player");

local RealmPlayersAddon = false;
if (type(VF_InspectDone) ~= "nil" and type(VF_StartInspectingTarget) ~= "nil") then
	RealmPlayersAddon = true;
end

function HonorSpy:OnEnable()
	self:Hook("InspectUnit");
	self:RegisterComm(commPrefix, "GROUP", "OnCommReceive")
	self:RegisterComm(commPrefix, "GUILD", "OnCommReceive")
	-- self:RegisterComm(commPrefix, "CUSTOM", "HS", "OnCommReceiveCustom")
	self:RegisterEvent("PLAYER_DEAD");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self.OnMenuRequest = BuildMenu();
	checkNeedReset();
end

local inspectedPlayers = {}; -- stores last_checked time of all players met
local inspectedPlayerName = nil; -- name of currently inspected player

local function StartInspecting(unitID)
	local name = UnitName(unitID);

	if (name ~= inspectedPlayerName) then -- changed target, clear currently inspected player
		ClearInspectPlayer();
		inspectedPlayerName = nil;
	end
	if (name == nil
		or name == inspectedPlayerName
		or not UnitIsPlayer(unitID)
		or not UnitIsFriend("player", unitID)
		or not CheckInteractDistance(unitID, 1)
		or not CanInspect(unitID)) then
		return
	end
	
	local player = HonorSpy.db.realm.hs.currentStandings[name] or inspectedPlayers[name];
	if (player == nil) then
		inspectedPlayers[name] = {last_checked = 0};
		player = inspectedPlayers[name];
	end
	if (time() - player.last_checked < 30) then -- 30 seconds until new inspection request
		return
	end
	-- we gonna inspect new player, clear old one
	ClearInspectPlayer();
	inspectedPlayerName = name;
	player.unitID = unitID;
	NotifyInspect(unitID);
	RequestInspectHonorData();
	_, player.rank = GetPVPRankInfo(UnitPVPRank(player.unitID)); -- rank must be get asap while mouse is still over a unit
	_, player.class = UnitClass(player.unitID); -- same
end

function HonorSpy:INSPECT_HONOR_UPDATE()
	if (inspectedPlayerName == nil or paused) then
		return;
	end

	local player = self.db.realm.hs.currentStandings[inspectedPlayerName] or inspectedPlayers[inspectedPlayerName];
	if (player.class == nil) then player.class = "nil" end

	local _, _, _, _, thisweekHK, thisWeekHonor, _, lastWeekHonor, standing = GetInspectHonorData();
	player.thisWeekHonor = thisWeekHonor;
	player.lastWeekHonor = lastWeekHonor;
	player.standing = standing;

	player.rankProgress = GetInspectPVPRankProgress();
	ClearInspectPlayer();
	NotifyInspect("target"); -- change real target back to player's target, broken by prev NotifyInspect call
	ClearInspectPlayer();
	if (RealmPlayersAddon) then
		VF_TemporarySupressTargetChange = nil;
		VF_PlayerChosenTarget = true;
		VF_StartInspectingTarget();
	end
	player.last_checked = time();
	player.RP = 0;

	if (thisweekHK >= 10) then
		if (player.rank >= 3) then
			player.RP = math.ceil((player.rank-2) * 5000 + player.rankProgress * 5000)
		elseif (player.rank == 2) then
			player.RP = math.ceil(player.rankProgress * 3000 + 2000)
		end
		self.db.realm.hs.currentStandings[inspectedPlayerName] = player;
		self:SendCommMessage("GROUP", inspectedPlayerName, player);
		self:SendCommMessage("GUILD", inspectedPlayerName, player);
		-- self:SendCommMessage("CUSTOM", "HS", inspectedPlayerName, player);
	end
	inspectedPlayers[inspectedPlayerName] = {last_checked = player.last_checked};
	inspectedPlayerName = nil;
end

-- RESET WEEK
function resetWeek(must_reset_on)
	HonorSpy.db.realm.hs.last_reset = must_reset_on;
	inspectedPlayers = {};
	HonorSpy.db.realm.hs.currentStandings={};
	HonorSpyStandings:Refresh();
	HonorSpy:Print("Weekly data was reset");
end
function checkNeedReset()
	if (HonorSpy.db.realm.hs.reset_day == nil) then HonorSpy.db.realm.hs.reset_day = 3 end
	local day = date("!%w");
	local h = date("!%H");
	local m = date("!%M");
	local s = date("!%S");
	local days_diff = (7 + (day - HonorSpy.db.realm.hs.reset_day)) - math.floor((7 + (day - HonorSpy.db.realm.hs.reset_day))/7) * 7;
	local diff_in_seconds = s + m*60 + h*60*60 + days_diff*24*60*60 - 10*60*60 - 1; -- 10 AM UTC - fixed hour of PvP maintenance
	if (diff_in_seconds > 0) then -- it is negative on reset_day untill 10AM
		local must_reset_on = time()-diff_in_seconds;
		if (must_reset_on > HonorSpy.db.realm.hs.last_reset) then resetWeek(must_reset_on) end
	end
end

-- PURGE
function purgeData()
	StaticPopup_Show("PURGE_DATA")
end
StaticPopupDialogs["PURGE_DATA"] = {
	text = "This will purge ALL addon data, you sure?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		inspectedPlayers = {};
		HonorSpy.db.realm.hs.currentStandings={};
		HonorSpyStandings:Refresh();
		HonorSpy:Print("All data was purged");
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- INSPECTION TRIGGERS
function HonorSpy:UPDATE_MOUSEOVER_UNIT()
	if (not paused) then StartInspecting("mouseover") end
end
function HonorSpy:PLAYER_TARGET_CHANGED()
	if (not paused) then
		if (RealmPlayersAddon) then
			VF_TemporarySupressTargetChange = true;
			VF_InspectDone();
		end
		StartInspecting("target");
	end
end

-- GUI
function HonorSpy:OnClick()
	checkNeedReset();
	HonorSpyStandings:Toggle()
end
function HonorSpy:OnTooltipUpdate()
  T:SetHint("by Kakysha, Mistaboom, Moxie and Boumex v"..tostring(VERSION))
end

-- PAUSING to not mess with native inspect calls
local hooked = false;
function HonorSpy:InspectUnit(unitID)
	paused = true;
	self.hooks["InspectUnit"](unitID)
	if (not hooked) then
		self:HookScript(SuperInspectFrame or InspectFrame, "OnHide");
		hooked = true;
	end
end
function HonorSpy:OnHide()
	paused = false;
end

-- CHAT COMMANDS
local options = {
	type = 'group',
	args = {
		show = {
			type = 'execute',
			name = 'Show standings table',
			desc = 'Show standings table',
			func = function() HonorSpyStandings:Toggle() end
		},
		report = {
			type = 'execute',
			name = 'Show standings for said player',
			desc = 'Show standings for said player',
			usage = 'PlayerOfInterest',
			func = function() HonorSpy:Report() end
		},
		search = {
			type = 'text',
			name = 'Show standings for said player',
			desc = 'Show standings for said player',
			usage = 'PlayerOfInterest',
			get = function() return '-' end,
			set = function(info) HonorSpy:Report(info) end
		},		
		players = {
			type = 'range',
			name = 'Limit players shown in standings list',
			desc = 'Limit players shown in standings list. Default is 750. Set 0 for no limit.',
			min = 0,
			max = 10000,
			set = function(value)
				HonorSpy.db.realm.hs.limit = value				
			end,
			get = function()
				return HonorSpy.db.realm.hs.limit
			end
		}
	}
}
HonorSpy:RegisterChatCommand({"/honorspy", "/hs"}, options)

function HonorSpy:HumanTime(t)
	local res
	
	if (t/86400 > 1) then
		res = ""..math.floor(t/86400).."d"
	elseif (t/3600 > 1) then
		res = ""..math.floor(t/3600).."h"
	elseif (t/60 > 1) then
		res = ""..math.floor(t/60).."m"
	else
		res = ""..t.."s"
	end
	
	return res
end

-- REPORT
function HonorSpy:Report(playerOfInterest)
	if (not playerOfInterest) then
		playerOfInterest = playerName
	end
	
	playerOfInterest = string.upper(string.sub(playerOfInterest, 1, 1))..string.lower(string.sub(playerOfInterest, 2))
	
	local standing = -1
	local t = HonorSpyStandings:BuildStandingsTable()
	local avg_lastchecked = 0;
	self.pool_size = math.ceil(1.5 * table.getn(t));
	for i = 1, table.getn(t) do
		avg_lastchecked = avg_lastchecked + t[i][8]
		if (playerOfInterest == t[i][1]) then
			standing = i
		end
	end
	avg_lastchecked = avg_lastchecked / self.pool_size
	--           1    2      3      4      5      6      7	    8      9      10     11     12    13     14
	--local brk = {1, 0.858, 0.715, 0.587, 0.477, 0.377, 0.287, 0.207, 0.137, 0.077, 0.037, 0.017, 0.007, 0.002} -- brkpoints (pre-1.12)
	local brk = {1, 0.845, 0.697, 0.566, 0.436, 0.327, 0.228, 0.159, 0.100, 0.060, 0.035, 0.020, 0.008, 0.003} -- brkpoints (post-1.12)
	local RP  = {0, 400} -- RP for each bracket
	local Ranks = {0, 2000} -- RP for each rank

	if (not HonorSpy.db.realm.hs.currentStandings[playerOfInterest]) then
		ChatFrame1:AddMessage('Unknown player '..playerOfInterest, 1, 0, 0)
		return playerOfInterest
	end
	
	local compute_pool_size = HonorSpy.pool_size;
	--local compute_pool_size = 2841; -- using Anathema's usual pool size
	local my_bracket = 1;
	local inside_br_progress = 0;
	
	if (math.floor(brk[14]*compute_pool_size)+0.5 < 1) then
		for i = 2,14 do
			brk[i] = BreakpointCount(i,compute_pool_size);
			my_bracket = i;
			if (standing > brk[i]) then
				if (standing < 15 and BreakpointCount(15-standing,compute_pool_size) == 1) then
					inside_br_progress = 1
					my_bracket = 15 - standing;
					break
				else
					inside_br_progress = (BreakpointCount(i-1,compute_pool_size) - standing)/(BreakpointCount(i-1,compute_pool_size) - BreakpointCount(i,compute_pool_size))
					my_bracket = i;
					break
				end;
			end;
			
		end;
	else
		for i = 2,14 do
			brk[i] = math.floor(brk[i]*compute_pool_size+.5);
			if (standing > brk[i]) then
				inside_br_progress = (brk[i-1] - standing)/(brk[i-1] - brk[i])
				break
			end;
			my_bracket = i;
		end;
	end;
	
	if (my_bracket == 14 and standing == 1) then inside_br_progress = 1 end;
	for i = 3,14 do
		RP[i] = (i-2) * 1000;
		Ranks[i] = (i-2) * 5000;
	end
	local honor = HonorSpy.db.realm.hs.currentStandings[playerOfInterest].thisWeekHonor
	local lastchecked = HonorSpy.db.realm.hs.currentStandings[playerOfInterest].last_checked
	local award = RP[my_bracket] + 1000 * inside_br_progress;
	local RP = HonorSpy.db.realm.hs.currentStandings[playerOfInterest].RP;
	local EstRP = math.floor(RP*0.8+award+.5);
	local Rank = HonorSpy.db.realm.hs.currentStandings[playerOfInterest].rank;
	local EstRank = 14;
    local Progress;
    if (RP < 2000) then
        Progress = math.floor(100 * math.mod(RP, 2000) / 2000);
    elseif (RP >= 2000 and RP < 5000) then
        Progress = math.floor(100 * math.mod(RP - 2000, 3000) / 3000);
    else
        Progress = math.floor(100 * math.mod(RP, 5000) / 5000);
    end
    local EstProgress;
    if (EstRP < 2000) then
        EstProgress = math.floor(100 * math.mod(EstRP, 2000) / 2000);
    elseif (EstRP >= 2000 and EstRP < 5000) then
        EstProgress = math.floor(100 * math.mod(EstRP - 2000, 3000) / 3000);
    else
        EstProgress = math.floor(100 * math.mod(EstRP, 5000) / 5000);
    end
	local RecPoolSize = HonorSpy.pool_size
	for i = 3,14 do
		if (EstRP < Ranks[i]) then
			EstRank = i-1;
			break;
		end
	end

	ChatFrame1:AddMessage("HonorSpy Report for: "..playerOfInterest..", Last Checked: "..self:HumanTime(time() - lastchecked), 1, 0.5, 0)
	ChatFrame1:AddMessage("Avg. Last Check: "..self:HumanTime(time() - avg_lastchecked), 1, 0.5, 0)
	ChatFrame1:AddMessage("Pool Size = "..RecPoolSize..", Standing = "..standing..",  Bracket = "..my_bracket..", Honor = "..honor, 0, 1, 1)
	ChatFrame1:AddMessage("Cur. RP = "..RP..",  Next Week RP = "..EstRP, 0, 1, 1)
	ChatFrame1:AddMessage("Cur. Rank = "..Rank.." ("..Progress.."%), Next Week Rank = "..EstRank.." ("..EstProgress.."%)", 0, 1, 1)
	
	return playerOfInterest
end

-- BREAKPOINT
	-- num : number of bracket
	-- ps : pool size
function BreakpointCount(num,ps)
	local brk = {1, 0.845, 0.697, 0.566, 0.436, 0.327, 0.228, 0.159, 0.100, 0.060, 0.035, 0.020, 0.008, 0.003} -- brkpoints (post-1.12)
	if math.floor(brk[num]*ps+.5) < 1 then
		return 1
	else
		return math.floor(brk[num]*ps+.5)
	end;
end;

-- MINIMAP
HonorSpy.defaultMinimapPosition = 200
HonorSpy.cannotDetachTooltip = true
HonorSpy.tooltipHidderWhenEmpty = false
HonorSpy.hasIcon = "Interface\\Icons\\Inv_Misc_Bomb_04"
function BuildMenu()
	local options = {
		type = "group",
		desc = "HonorSpy options",
		args = { }
	}

	local days = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
	options.args["reset_day"] = {
		type = "text",
		name = "PvP Week Reset On",
		desc = "Day of week when new PvP week starts (10AM UTC)",
		get = function() return days[HonorSpy.db.realm.hs.reset_day+1] end,
		set = function(v)
			for k,nv in pairs(days) do
				if (v == nv) then HonorSpy.db.realm.hs.reset_day = k-1 end;
			end
			checkNeedReset();
		end,
		validate = days,
	}
	options.args["sort"] = {
		type = "text",
		name = "Sort By",
		desc = "Set up sorting column",
		get = function() return HonorSpy.db.realm.hs.sort end,
		set = function(v)
			HonorSpy.db.realm.hs.sort = v;
			HonorSpyStandings:Refresh();
		end,
		validate = {"Rank", "ThisWeekHonor"},
	}
	options.args["export"] = {
		type = "execute",
		name = "Export to CSV",
		desc = "Show window with current data in CSV format",
		func = function() HonorSpy:ExportCSV() end,
	}
	options.args["report"] = {
		type = "execute",
		name = "Report My Standing",
		desc = "Reports your current standing as emote",
		func = function() HonorSpy:Report(playerName) end,
	}
	options.args["purge_data"] = {
		type = "execute",
		name = "Purge all data",
		desc = "Delete all collected data",
		func = function() purgeData() end,
	}

	return options
end

-- SYNCING --
function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

function store_player(playerName, player)
	if (player == nil) then return end
	
	if (player.last_checked < HonorSpy.db.realm.hs.last_reset
		or player.last_checked > time()
		or player.thisWeekHonor == 0) then
		return
	end
	
	local player = table.copy(player);
	local localPlayer = HonorSpy.db.realm.hs.currentStandings[playerName];
	if (localPlayer == nil or localPlayer.last_checked < player.last_checked) then
		HonorSpy.db.realm.hs.currentStandings[playerName] = player;
	end
end

-- RECEIVE 
--[[function HonorSpy:OnCommReceiveCustom(prefix, sender, distribution, channelName, playerName, player, filtered_players)
	self:OnCommReceive(prefix, sender, distribution, playerName, player, filtered_players)
end]]
function HonorSpy:OnCommReceive(prefix, sender, distribution, playerName, player, filtered_players)
	if (playerName == false) then
		for playerName, player in pairs(filtered_players) do
			store_player(playerName, player);
		end
		return
	end
	store_player(playerName, player);
end

-- SEND
local last_send_time = 0;
function HonorSpy:PLAYER_DEAD()
	local filtered_players, count = {}, 0;
	if (time() - last_send_time < 5*60) then return	end;
	last_send_time = time();

	for playerName, player in pairs(self.db.realm.hs.currentStandings) do
		player.is_outdated = false;
		filtered_players[playerName] = player;
		count = count + 1;
		if (count == 10) then
			self:SendCommMessage("GROUP", false, false, filtered_players);
			self:SendCommMessage("GUILD", false, false, filtered_players);
			-- self:SendCommMessage("CUSTOM", "HS", false, false, filtered_players);
			filtered_players, count = {}, 0;
		end
	end
	if (count > 0) then
		self:SendCommMessage("GROUP", false, false, filtered_players);
		self:SendCommMessage("GUILD", false, false, filtered_players);
		-- self:SendCommMessage("CUSTOM", "HS", false, false, filtered_players);
	end
end
