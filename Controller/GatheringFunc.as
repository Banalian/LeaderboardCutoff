// File containing all functions that gather data from the API


/**
 * Get the personal best time of the current map from the online leaderboard
 */
LeaderboardEntry@ GetPersonalBestEntry() {
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    LeaderboardEntry@ pbTimeTmp = LeaderboardEntry();
    pbTimeTmp.time = -1;
    pbTimeTmp.position = -1;
    pbTimeTmp.entryType = EnumLeaderboardEntryType::PB;
    pbTimeTmp.desc = "PB";
    pbTimeTmp.positionData = currentPbPositionData;

    if(!validMap){
        return pbTimeTmp;
    }

    // Check that we're in a map
    if (network.ClientManiaAppPlayground is null || network.ClientManiaAppPlayground.Playground is null || network.ClientManiaAppPlayground.Playground.Map is null) {
        return pbTimeTmp;
    }

    string mapid = network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;
    auto info = FetchEndpoint(NadeoServices::BaseURLLive() + "/api/token/leaderboard/group/Personal_Best/map/"+mapid+"/surround/0/0?onlyWorld=true");
    if(info.GetType() == Json::Type::Null) {
        // error fetching data
        return pbTimeTmp;
    }

    auto tops = info["tops"];
    if(tops.GetType() != Json::Type::Array || tops.Length == 0) {
        // error fetching data, empty object or array
        return pbTimeTmp;
    }

    auto top = tops[0]["top"];
    if(top.Length == 0) {
        // error fetching data, empty array
        return pbTimeTmp;
    }

    pbTimeTmp.time = top[0]["score"];
    pbTimeTmp.position = top[0]["position"];
    trace("Nadeo returned: score: " + tostring(pbTimeTmp.time) + " position: " + tostring(pbTimeTmp.position));

    return pbTimeTmp;
}


/**
 * Return the leaderboard entry of a given position
 */
LeaderboardEntry@ GetSpecificTimeEntry(int position) {
    LeaderboardEntry@ positionEntry = LeaderboardEntry();
    if(!validMap){
        return positionEntry;
    }

    // find the related positionData
    for (uint i = 0; i < allPositionData.Length; i++) {
        if (int(allPositionData[i].position) == position) {
            positionEntry.positionData = allPositionData[i];
            break;
        }
    }
    int offset = position - 1;

    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    //check that we're in a map
    if (network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null){
        auto info = FetchEndpoint(NadeoServices::BaseURLLive() + "/api/token/leaderboard/group/Personal_Best/map/"+currentMapUid+"/top?length=1&offset="+offset+"&onlyWorld=true");

        if(info.GetType() != Json::Type::Null) {
            auto tops = info["tops"];
            if(tops.GetType() == Json::Type::Array) {
                auto top = tops[0]["top"];
                if(top.Length > 0) {
                    int infoTop = top[0]["score"];
                    positionEntry.time = infoTop;
                    positionEntry.position = position;
                    positionEntry.entryType = EnumLeaderboardEntryType::POSITION;
                    return positionEntry;
                }
            }
        }
    }

    return positionEntry;
}

/**
 *  Return the position of a given time. You still need to check if the time is valid (i.e. if it's different from the top 1, or from the PB)
 */
LeaderboardEntry@ GetSpecificPositionEntry(int time) {
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    LeaderboardEntry@ positionEntry = LeaderboardEntry();
    positionEntry.time = -1;
    positionEntry.position = -1;
    positionEntry.entryType = EnumLeaderboardEntryType::TIME;

    if(!validMap){
        return positionEntry;
    }

    //check that we're in a map
    if (network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null){
        string mapid = network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;

        auto info = FetchEndpoint(NadeoServices::BaseURLLive() + "/api/token/leaderboard/group/Personal_Best/map/"+mapid+"/surround/0/0?score="+time+"&onlyWorld=true");

        if(info.GetType() != Json::Type::Null) {
            auto tops = info["tops"];
            if(tops.GetType() == Json::Type::Array) {
                auto top = tops[0]["top"];
                if(top.Length > 0) {
                    positionEntry.time = top[0]["score"];
                    positionEntry.position = top[0]["position"];
                }
            }
        }
    }

    return positionEntry;
}


/**
 * Returns an array of LeaderboardEntry with the medals times, if we're able to get them
 */
array<LeaderboardEntry@> GetMedalsEntries(){

    array<LeaderboardEntry@> tmpArray;

    if(!showMedals){
        return tmpArray;
    }
    // We get the medals time
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto map = app.RootMap;

    int atTime;
    int goldTime;
    int silverTime;
    int bronzeTime;


    if(network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null){
        atTime = map.TMObjective_AuthorTime;
        goldTime = map.TMObjective_GoldTime;
        silverTime = map.TMObjective_SilverTime;
        bronzeTime = map.TMObjective_BronzeTime;

#if DEPENDENCY_CHAMPIONMEDALS
        if(showChampionMedals){
            int championTime = ChampionMedals::GetCMTime();
            if((championTime != 0) && (atTime < currentPbEntry.time || currentPbEntry.time == -1)){
                auto championPosition = GetSpecificPositionEntry(championTime);
                championPosition.desc = "Champion";
                championPosition.entryType = EnumLeaderboardEntryType::MEDAL;
                championPosition.positionData = championMedalPositionData;
                if(isAValidMedalTime(championPosition)) {
                    tmpArray.InsertLast(championPosition);
                }
            }
        }
#endif

#if DEPENDENCY_WARRIORMEDALS
        if(showWarriorMedals){
            int warriorTime = WarriorMedals::GetWMTime();
            if((warriorTime != 0) && (atTime < currentPbEntry.time || currentPbEntry.time == -1)){
                auto warriorPosition = GetSpecificPositionEntry(warriorTime);
                warriorPosition.desc = "Warrior";
                warriorPosition.entryType = EnumLeaderboardEntryType::MEDAL;
                warriorPosition.positionData = warriorMedalPositionData;
                if(isAValidMedalTime(warriorPosition)) {
                    tmpArray.InsertLast(warriorPosition);
                }
            }
        }
#endif

#if DEPENDENCY_SBVILLECAMPAIGNCHALLENGES
        if(showSBVilleATMedal){
            int SBVilleATTime = SBVilleCampaignChallenges::getChallengeTime();
            if((SBVilleATTime != 0) && (atTime < currentPbEntry.time || currentPbEntry.time == -1)){
                auto SBVillePosition = GetSpecificPositionEntry(SBVilleATTime);
                SBVillePosition.desc = "SBVille AT";
                SBVillePosition.entryType = EnumLeaderboardEntryType::MEDAL;
                SBVillePosition.positionData = sbVillePositionData;
                if(isAValidMedalTime(SBVillePosition)) {
                    tmpArray.InsertLast(SBVillePosition);
                }
            }
        }
#endif

#if DEPENDENCY_S314KEMEDALS
        if(showS314keMedals){
            int s314keTime = s314keMedals::GetS314keMedalTime();
            if(( s314keTime != 0) && (atTime < currentPbEntry.time || currentPbEntry.time == -1)){
                auto s314kePosition = GetSpecificPositionEntry(s314keTime);
                s314kePosition.desc = "S314ke";
                s314kePosition.entryType = EnumLeaderboardEntryType::MEDAL;
                s314kePosition.positionData = s314keMedalPositionData;
                if(isAValidMedalTime(s314kePosition)) {
                    tmpArray.InsertLast(s314kePosition);
                }
            }
        }
#endif

        // We get the positions of the 4 medals and add them if they are valid and if we need to show them
        if(showAT){
            if(atTime < currentPbEntry.time || currentPbEntry.time == -1){
                auto atPosition = GetSpecificPositionEntry(atTime);
                atPosition.desc = "AT";
                atPosition.entryType = EnumLeaderboardEntryType::MEDAL;
                atPosition.positionData = atPositionData;
                if(isAValidMedalTime(atPosition)) {
                    tmpArray.InsertLast(atPosition);
                }
            }
            
        }

        if(showGold){
            if(goldTime < currentPbEntry.time || currentPbEntry.time == -1){
                auto goldPosition = GetSpecificPositionEntry(goldTime);
                goldPosition.desc = "Gold";
                goldPosition.entryType = EnumLeaderboardEntryType::MEDAL;
                goldPosition.positionData = goldPositionData;
                if(isAValidMedalTime(goldPosition)) {
                    tmpArray.InsertLast(goldPosition);
                }
            }
        }

        if(showSilver){
            if(silverTime < currentPbEntry.time || currentPbEntry.time == -1){
                auto silverPosition = GetSpecificPositionEntry(silverTime);
                silverPosition.desc = "Silver";
                silverPosition.entryType = EnumLeaderboardEntryType::MEDAL;
                silverPosition.positionData = silverPositionData;
                if(isAValidMedalTime(silverPosition)) {
                    tmpArray.InsertLast(silverPosition);
                }
            }
        }

        if(showBronze){
            if(bronzeTime < currentPbEntry.time || currentPbEntry.time == -1){
                auto bronzePosition = GetSpecificPositionEntry(bronzeTime);
                bronzePosition.desc = "Bronze";
                bronzePosition.entryType = EnumLeaderboardEntryType::MEDAL;
                bronzePosition.positionData = bronzePositionData;
                if(isAValidMedalTime(bronzePosition)) {
                    tmpArray.InsertLast(bronzePosition);
                }
            }
        }

    }

    return tmpArray;

}