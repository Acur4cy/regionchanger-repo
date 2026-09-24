#!/bin/sh
# LG webOS TV Region Change Script
#
# Writes the area option directly to NVRAM via the lowlevelstorage service,
# bypassing factorymanager's geolock permission check. Works on rooted TVs and
# in Developer Mode (no root required).
#
# Based on lennylxx/lg-geolock-bypass (MIT):
#   https://github.com/lennylxx/lg-geolock-bypass/blob/main/change_region.sh
#
# Run this ON THE TV over SSH:  sh change_region.sh <area|read|verify|reboot>
# Common: 22282=US 19461=EU 3122=EU(EU hw) 13741=CN 18789=BR 19345=JP
# ALWAYS save your original value first:  sh change_region.sh read

NODE_PATH=/usr/lib/node_modules:/usr/lib/nodejs
export NODE_PATH

# The webos-service node module requires pmloglib, which isn't available in
# the prisoner shell. This in-memory stub satisfies the dependency.
NODE_BOOTSTRAP='
var Module=require("module"),originalLoad=Module._load;
function noop(){}
function logger(){return{log:noop,info:noop,warning:noop,error:noop};}
var pmloglib={log:noop,info:noop,warning:noop,error:noop,Console:logger,Context:logger};
Module._load=function(request,parent,isMain){
  if(request==="pmloglib")return pmloglib;
  return originalLoad.apply(this,arguments);
};
function createHandle(pb){
  try{return new pb.Handle("");}
  catch(singleArgumentError){
    try{return new pb.Handle("",true);}
    catch(twoArgumentError){
      throw new Error("Unable to create palmbus Handle; single argument: "+
        singleArgumentError.message+"; two arguments: "+twoArgumentError.message);
    }
  }
}'

read_area() {
    node -e "$NODE_BOOTSTRAP"'
var pb=require("palmbus"),h=createHandle(pb);
h.call("luna://com.webos.service.lowlevelstorage/getData",
  JSON.stringify({dbgroups:[{dbid:"factory",items:["contiArea2All"]}]}))
.on("response",function(m){
  var r=JSON.parse(m.payload());
  if(r.returnValue){
    var v=parseInt(r.dbgroups[0].items.contiArea2All);
    console.log("Current area option: "+v);
    console.log("  continentIdx:     "+(v&0x7F));
    console.log("  languageCountry:  "+((v>>7)&0x1F));
    console.log("  hwSettingGroup:   "+((v>>12)&0xF));
  } else {
    console.log("Error: "+m.payload());
  }
  process.exit(0);
});
setTimeout(function(){process.exit(1);},5000);'
}

write_area() {
    AREA="$1"
    node -e "$NODE_BOOTSTRAP"'
var area="'"$AREA"'";
var pb=require("palmbus"),h=createHandle(pb);
h.call("luna://com.webos.service.lowlevelstorage/setData",
  JSON.stringify({dbgroups:[{dbid:"factory",items:{contiArea2All:area}}]}))
.on("response",function(m){
  var r=JSON.parse(m.payload());
  if(r.returnValue){
    console.log("[+] NVRAM contiArea2All set to "+area);
  } else {
    console.log("[-] Failed: "+m.payload());
    process.exit(1);
  }
});
setTimeout(function(){
  h.call("luna://com.webos.service.lowlevelstorage/getData",
    JSON.stringify({dbgroups:[{dbid:"factory",items:["contiArea2All"]}]}))
  .on("response",function(m){
    console.log("[+] Verify: "+m.payload());
    process.exit(0);
  });
},1000);
setTimeout(function(){process.exit(1);},5000);'
}

set_configd_us() {
    node -e "$NODE_BOOTSTRAP"'
var pb=require("palmbus"),h=createHandle(pb);
h.call("luna://com.webos.service.config/setConfigs",
  JSON.stringify({configs:{"tv.model.languageCountrySel":"US","tv.model.hwSettingGroup":"US","tv.model.continentIndx":10}}))
.on("response",function(m){console.log("[+] configd: "+m.payload());});
setTimeout(function(){
  h.call("luna://com.webos.service.settings/setSystemSettings",
    JSON.stringify({category:"option",settings:{country:"USA",smartServiceCountryCode3:"USA",localeCountryGroup:"langSelUS"}}))
  .on("response",function(m){console.log("[+] settings: "+m.payload());process.exit(0);});
},500);
setTimeout(function(){process.exit(1);},5000);'
}

set_configd() {
    AREA="$1"
    node -e "$NODE_BOOTSTRAP"'
var area=parseInt("'"$AREA"'");
var LC=["NORDIC","NON NORDIC","EAST EU","WEST EU","ETC EU","AJ","JA","IL","TW","CO","PA","CN","HK","KR","US","CA","MX","HN","BR","CL","PE","AR","EC","JP","EU","IR","PH","BW","CS"];
var HW=["EU","AJ JA IL","TW CO","CN HK","KR","US","SA","JP"];
var COUNTRY={US:"USA",CA:"CAN",MX:"MEX",BR:"BRA",AR:"ARG",CL:"CHL",PE:"PER",CO:"COL",EC:"ECU",HN:"HND",PA:"PAN",CN:"CHN",HK:"HKG",TW:"TWN",KR:"KOR",JP:"JPN",PH:"PHL",IL:"ISR",EU:"DEU",AJ:"AUS",JA:"ZAF"};
var LANGGRP={US:"langSelUS",CA:"langSelUS",MX:"langSelUS",BR:"langSelBR",CN:"langSelCN",HK:"langSelHK",TW:"langSelTW",KR:"langSelKR",JP:"langSelJP",EU:"langSelEU"};
var ci=area&0x7F, lc=(area>>7)&0x1F, hw=(area>>12)&0xF;
var lcName=LC[lc]||"US", hwName=HW[hw]||"US";
var cc=COUNTRY[lcName]||lcName;
var lg=LANGGRP[lcName]||("langSel"+lcName);
console.log("[+] Decoded: ci="+ci+" lang="+lcName+" hw="+hwName+" country="+cc);
var pb=require("palmbus"),h=createHandle(pb);
h.call("luna://com.webos.service.config/setConfigs",
  JSON.stringify({configs:{"tv.model.languageCountrySel":lcName,"tv.model.hwSettingGroup":hwName,"tv.model.continentIndx":ci}}))
.on("response",function(m){console.log("[+] configd: "+m.payload());});
setTimeout(function(){
  h.call("luna://com.webos.service.settings/setSystemSettings",
    JSON.stringify({category:"option",settings:{country:cc,smartServiceCountryCode3:cc,localeCountryGroup:lg}}))
  .on("response",function(m){console.log("[+] settings: "+m.payload());process.exit(0);});
},500);
setTimeout(function(){process.exit(1);},5000);'
}

reboot_tv() {
    echo "Rebooting TV..."
    node -e "$NODE_BOOTSTRAP"'var pb=require("palmbus");var h=createHandle(pb);h.call("luna://com.webos.service.sleep/shutdown/machineReboot",JSON.stringify({"reason":"remoteKey"}));setTimeout(function(){process.exit(0);},3000);'
}

verify() {
    node -e "$NODE_BOOTSTRAP"'
var pb=require("palmbus"),h=createHandle(pb);
h.call("luna://com.webos.service.lowlevelstorage/getData",
  JSON.stringify({dbgroups:[{dbid:"factory",items:["contiArea2All"]}]}))
.on("response",function(m){console.log("NVRAM:          "+m.payload());});
setTimeout(function(){
  h.call("luna://com.webos.service.config/getConfigs",
    JSON.stringify({configNames:["tv.model.languageCountrySel","tv.model.hwSettingGroup","tv.model.continentIndx"]}))
  .on("response",function(m){console.log("configd:        "+m.payload());});
},500);
setTimeout(function(){
  h.call("luna://com.webos.service.settings/getSystemSettings",
    JSON.stringify({category:"option",keys:["country","smartServiceCountryCode3","localeCountryGroup"]}))
  .on("response",function(m){console.log("settings:       "+m.payload());process.exit(0);});
},1000);
setTimeout(function(){process.exit(1);},5000);'
}

case "$1" in
    read)
        read_area
        ;;
    verify)
        verify
        ;;
    reboot)
        reboot_tv
        ;;
    "")
        echo "Usage: $0 <area_code|read|verify|reboot>"
        echo ""
        echo "Examples:"
        echo "  $0 read          Read current area option (SAVE THIS FIRST)"
        echo "  $0 verify        Verify all region settings"
        echo "  $0 22282         Set area option to US (22282)"
        echo "  $0 19461         Set area option to EU (KR hw)"
        echo "  $0 reboot        Reboot the TV"
        echo ""
        echo "Known area codes:"
        echo "  22282 = US    19461 = EU    3122 = EU(EU hw)"
        echo "  13741 = China 18789 = Brazil 19345 = Japan"
        echo "  18362 = Canada 18456 = Mexico 19123 = Argentina"
        exit 1
        ;;
    *)
        echo "Setting area option to $1..."
        write_area "$1"
        echo ""
        if [ "$1" = "22282" ]; then
            echo "Setting configd and settings to US (verified)..."
            set_configd_us
        else
            echo "Setting configd and settings (best-effort mapping)..."
            set_configd "$1"
        fi
        echo ""
        echo "Done. Run '$0 reboot' or use the remote to reboot."
        ;; 
esac