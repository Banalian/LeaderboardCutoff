// ################
// ### Settings ###
// ################

[Setting category="Display Settings" name="Window visible" description="To move the windows, click and drag while the Openplanet overlay is visible."]
bool windowVisible = true;

const array<string> podiumIcon = {
    "\\$071" + Icons::Kenney::PodiumAlt, // 1st : green
    "\\$db4" + Icons::Kenney::PodiumAlt, // 10th : gold
    "\\$899" + Icons::Kenney::PodiumAlt, // 100th : silver
    "\\$964" + Icons::Kenney::PodiumAlt, // 1000th : bronze
	"\\$444" + Icons::Kenney::PodiumAlt, // 10000th : nothing	
};

const string resetColor = "\\$z";

const string pluginName = "Extra Leaderboard positions";

string currentMapUid = "";

float timer = 0;
float updateFrequency = 300*1000;
bool refreshPosition = false;




class CutoffTime{

    int time;
    int position;
    bool pb = false;

    int opCmp(CutoffTime@ other){
        return position - other.position;
    }
}


array<CutoffTime@> cutoffArray;


void RenderMenu() {
    if (UI::MenuItem(pluginName)) {
        windowVisible = !windowVisible;
    }
}

void Render() {
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    int windowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoDocking;

    if (!UI::IsOverlayShown()) {
        windowFlags |= UI::WindowFlags::NoInputs;
    }


    if(windowVisible && app.CurrentPlayground !is null && cutoffArray.Length > 0){
        UI::Begin(pluginName, windowFlags);

        UI::BeginGroup();

        UI::Text("Extra leaderboard positions");
        
        UI::BeginTable("Main", 4);        

        UI::TableNextRow();
        UI::TableNextColumn();
        UI::TableNextColumn();
        UI::Text("Position");
        UI::TableNextColumn();
        UI::Text("Time");

        int i = 0;
        int offsetPod = 0;
        while(i < cutoffArray.Length){
            UI::TableNextRow();
            UI::TableNextColumn();
            if(cutoffArray[i].pb){
                offsetPod++;
                UI::Text(podiumIcon[i]);
            }else{
                UI::Text(podiumIcon[i-offsetPod]);
            }
            
            UI::TableNextColumn();
            if(cutoffArray[i].position > 10000){
                UI::Text("<" + cutoffArray[i].position);
            }else{
                UI::Text(""+ cutoffArray[i].position);
            }
            
            UI::TableNextColumn();
            UI::Text("" + cutoffArray[i].time);

            if(cutoffArray[i].pb){
                UI::TableNextColumn();
                UI::Text("PB");
            }

            i++;
            
        }



        /*for(uint i = 0; i < cutoffArray.Length; i++){
            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text(podiumIcon[i]);
            UI::TableNextColumn();
            UI::Text("" + cutoffArray[i].position);
            UI::TableNextColumn();
            UI::Text(TimeString(cutoffArray[i].time));
        }*/

        UI::EndTable();

        UI::EndGroup();

        UI::End();
    }
}

void Update(float dt) {

    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    //TODO: maybe only check when network.ServerInfo.CurGameModeStr = "TM_Campaign_Local" or "TM_TimeAttack_Online"

    if(app.CurrentPlayground !is null && network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null){
        bool mapIdChanged = currentMapUid != app.RootMap.MapInfo.MapUid;
        if (mapIdChanged || timer > updateFrequency) {
            currentMapUid = app.RootMap.MapInfo.MapUid;
            refreshPosition = true;
            timer = 0;
        } else {
            timer += dt;
        }
    }else{
        timer = 0;
    }
    
}




Json::Value FetchEndpoint(const string &in route) {
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        yield();
    }
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) {
        yield();
    }
    return Json::Parse(req.String());
}


string TimeString(int scoreTime) {
    return Time::Format(scoreTime);
}

int GetTimeWithOffset(float offset = 0) {

    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    auto server_info = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);

    if (network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null){
        auto info = FetchEndpoint(NadeoServices::BaseURL() + "/api/token/leaderboard/group/Personal_Best/map/"+currentMapUid+"/top?length=1&offset="+offset+"&onlyWorld=true");
    
        if(info.GetType() != Json::Type::Null) {
            auto tops = info["tops"];
            if(tops.GetType() == Json::Type::Array) {
                auto top = tops[0]["top"];
                if(top.Length > 0) {
                    int infoTop = top[0]["score"];
                    return infoTop;
                }
            }            
        }
    }

    return -1;
}

CutoffTime@ GetPersonalBest() {
    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);
    CutoffTime@ best = CutoffTime();
    best.time = -1;
    best.position = -1;
    best.pb = true;

    if (network.ClientManiaAppPlayground !is null && network.ClientManiaAppPlayground.Playground !is null && network.ClientManiaAppPlayground.Playground.Map !is null){
        string mapid = network.ClientManiaAppPlayground.Playground.Map.MapInfo.MapUid;
        
        auto info = FetchEndpoint(NadeoServices::BaseURL() + "/api/token/leaderboard/group/Personal_Best/map/"+mapid+"/surround/0/0?onlyWorld=true");
    
        if(info.GetType() != Json::Type::Null) {
            auto tops = info["tops"];
            if(tops.GetType() == Json::Type::Array) {
                auto top = tops[0]["top"];
                if(top.Length > 0) {
                    best.time = top[0]["score"];
                    best.position = top[0]["position"];
                }
            }
        }
    }

    return best;
}


void updateTimes(){
    // We get the 1st, 10th, 100th and 1000th leaderboard time, as well as the personal best time
    array<CutoffTime@> cutoffArrayTmp;
    int i = 0;
    bool continueLoop = true;

    cutoffArrayTmp.InsertLast(GetPersonalBest());

    while(continueLoop){
        int offset = int(Math::Pow(10,i));
        CutoffTime@ cutoff = CutoffTime();
        cutoff.time = GetTimeWithOffset(offset-1);
        cutoff.position = offset;
        if(cutoff.time != -1){
            cutoffArrayTmp.InsertLast(cutoff);
        }else{
            continueLoop = false;
        }
        if(i == 4){
            //we can't ask for the leadereboard above 10k so we stop.
            continueLoop = false;
        }
        i++;
    }

    //sort the array
    cutoffArrayTmp.SortAsc();

    cutoffArray = cutoffArrayTmp;
}

void Main(){
#if TMNEXT

    // Add the audiences you need
    NadeoServices::AddAudience("NadeoLiveServices");
 
    // Wait until the services are authenticated
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
      yield();
    }

    auto app = cast<CTrackMania>(GetApp());
    auto network = cast<CTrackManiaNetwork>(app.Network);

    while(true){

        if(refreshPosition){
            updateTimes();
            refreshPosition = false;
        }
        yield();

    }

#endif
}
