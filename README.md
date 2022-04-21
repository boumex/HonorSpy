### Fork of [kakysha/HonorSpy](https://github.com/kakysha/HonorSpy)

### V4 Kronos4
If you are upgrading from previous version of HonorSpy **Delete your WOWFOLDER/WTF/Account/ACCOUNTNAME/SavedVariables/HonorSpy.lua** and **HonorSpy.lua.bak**

* Increased pool size by 50% as was added to **Kronos 4** 9th of March 2022
* Characters with atleast 10 HK are counted to ranking ladder

### V4

Un-merged additions:
* Added slash command `/hs players 0-10000` to limit number of players shown in table to a specified value. Table functionality was becoming near unusable on Elysium. _Removed artificial limitation from previous version._


### V3
Un-merged additions:
* Reports using the private ChatFrame1 instead of the public emote channel
* Improved reports, notably shows the average Last Checked time of the record pool ("about how outdated is my data?")
* Added two commands: `/hs report` (self) and `/hs search PlayerName` (someone else)
* Don't need to open the standing table before a report, the report request will trigger the computations by itself
* Reduced the standing table display to the highest 300 standings only (reduces lag/freeze on opening). _TODO WTF setting for that number, and GUI or Slash command to parametrise it_

Note: Brackets use the ascending notation. Bracket N is the bracket awarding progression towards rank N. (Clarification as Bracket 14 is commonly referred to as "Bracket 1" on Anathema).

### Install
Download zip of 'master' branch (just click Clone or Download -> Download ZIP), unzip the archive, remove '-master' suffix from folder name and put it in Interface/Addons folder, relaunch WoW.

### About
Addon does all the magic in background.

1. It inspects every player in 'inspect range' which you target or mouseover
2. It syncs your db with other party/raid/bg members and your guildmates on your death
3. It can estimate your onward RP, Rank and Progress, taking into account your standing and pool size.
3. It can export your internal DB in CSV format to copy-paste it into Google Spreadsheets for future calculations. [Spreadsheet done specially for HonorSpy](https://docs.google.com/spreadsheets/d/1OvZ7PRhrFjRn8IoH8HIPwHfRDEq50uO64YLCsSsjBQc/edit#gid=2113352865), it will estimate RP for all players.
4. It supports automatic weekly pvp reset. Reset day can be configured.
5. You can see how old every player data is in your db by hovering it in table
6. Supports sorting by RP and ThisWeekHonor

Options can be invoked by right clicking on the minimap icon.

It only stores players with >15HKs.
Reset day can be configured, default is Wednesday. Reset time is fixed at 10AM UTC.

P.S. Do not be afraid of losing all your data, very likely that another players with HonorSpy will push you their database very soon. The more players use and collects data -> the more up-to-date data you will have. Magic of sync.

### Commands
* `/hs report` -> shows your own standing report and rank estimate.
* `/hs search PlayerName` -> shows another player's standing report and rank estimate (case insensitive).
* `/hs players 0-10000` -> defines the max number of players to show in standings table.
* `/hs show` -> show/hide standings table.
* `/hs standby` -> enable/disable addon (in case you disabled it from right-click menu this helps to re-enable it).

### Screenshot

![HonorSpy Screenshot](https://habrastorage.org/files/31b/e92/f9e/31be92f9eb044a53b4eb642d0ca43bbc.png)
