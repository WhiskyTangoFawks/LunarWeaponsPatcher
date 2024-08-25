unit wtfLib_WEAP;

uses 'wtfLib\wtfLib_logging';

var
  weapConfig, weapIndex, weapScrap, weapIsPrewar: TStringList;

//============================================================================  
function initWeapTierFiles(): integer;
var
  i : integer;
  
begin

  //Weapons
  //ma_keyword=ma_pipeGun, scrap=pistol

  weapConfig := TStringList.create;
  weapConfig.LoadFromFile('Edit Scripts\Degrade\weapon.ini');

  weapIndex := TStringList.create;
  weapScrap := TStringList.create;
  weapIsPrewar := TStringList.create;
  for i := 0 to pred(weapConfig.Count) do parseWeapConfigLine(weapConfig[i]);

end;
//============================================================================  
function parseweapConfigLine(line: string): integer;
var
  j, eqIndex: integer;
  key, value: string;
  temp: TStringList;

begin
    if line = '' then exit;
    if not containsText(line, 'ma_keyword') then exit;
    line := StringReplace(line, ' ', '', [rfReplaceAll, rfIgnoreCase]);
    logg(3, 'Loaded weap config line: ' + line);
    
    temp := TStringList.create;
    temp.Delimiter := ','; 
    temp.DelimitedText := line;
    
    
//PROBLEM: the delimited text is delimiting on spaces, not jsut the comma

    if (temp.count < 4) then raise exception.create('Weapon.ini missing config property in: ' + line);
   
    for j := 0 to pred(temp.Count) do begin
      logg(1, 'parsing delimited: ' + temp[j]);
      eqIndex := pos('=', temp[j]);
      key := trim(copy(temp[j], 1, eqIndex-1));
      value := trim(copy(temp[j], eqIndex+1, length(temp[j])));
      logg(2, 'parsed key "' + key + '"="' + value + '"');
      if (key='ma_keyword') then weapIndex.add(value)
      else if (key='name') then logg(2, 'Adding ' + value)
      else if (key='scrap') then weapScrap.add(value)
      else if (key='isPreWar') then begin
        if containsText(value, 'true') then weapIsPrewar.add('true')
        else if containsText(value, 'false') then weapIsPrewar.add('false')
        else raise exception.create('Unrecognized boolean value: "'  + value + '" in line: ' + line);
      end
      else raise exception.create('Unrecognized config key: "'  + key + '" in line: ' + line);
    end;
end;

//============================================================================  
function getScrapForReciever(omod: IInterface): string;
var
  i: integer;

begin
  logg(1, 'getScrapForReciever for ' + editorID(omod));
  i := getWeapIndexForOmod(omod);
  result := weapScrap[i];
  result := 'c_' + result + 'Scrap_MoreDamage' + IntToStr(getDamageLevel(omod));

end;

//============================================================================  
function getIsWeapForOmodPreWar(omod: IInterface): boolean;
var
  i: integer;

begin

  i := getWeapIndexForOmod(omod);
  if (weapIsPrewar[i] = 'true') then result := true;
  if (weapIsPrewar[i] = 'false') then result := false;
end;

//============================================================================  
function getWeapIndexForOmod(omod: IInterface): integer;
var
  i: integer;
  kywd, newLine, full: string;
  properties: IInterface;

begin
  kywd := EditorID(LinksTo(ElementByIndex(ElementBySignature(omod, 'MNAM'), 0)));
  full := getElementEditValues(getTargetWeaponForOMOD(omod), 'FULL');
  logg(1, 'getting weap index for omod ' + editorId(omod) + ' ' + kywd);
  result := weapIndex.indexOf(kywd);
  logg(1, 'weap index for omod = ' + intToStr(result));

  if result = -1 then begin
    logg(4, 'weapon scrap not found in a config file: ' + kywd);
    newline := 'name='+ full +', ' 'ma_keyword=' + kywd + ', isPreWar='+ BoolToStr(fallbackIsPreWar(getTargetWeaponForOMOD(omod))) +', scrap=' + getWeaponClassForOmod(omod);
    weapConfig.add(newLine);
    parseWeapConfigLine(newLine);
    weapConfig.SaveToFile('Edit Scripts\Degrade\weapon.ini');
    result := weapIndex.indexOf(kywd);
  end;
end;

//============================================================================  
function getWeaponClassForOmod(omod: IInterface): String;
var
  WorkingComp, eFVPA, weap, mnam, omodRef: IInterface;
  i, oldCount: integer;
  cmpo: String;
  hasRifle, hasPistol: boolean;

begin
    weap := getTargetWeaponForOMOD(omod);
    if hasKeyword(weap, 'WeaponTypeBallistic') then begin
        if hasKeyword(weap, 'WeaponTypeShotgun') then begin
            if (StrToInt(getElementEditValues(weap, 'DNAM\Capacity')) > 4) then result := 'AutoShotgun'
            else result := 'Shotgun';
        end
        else if hasKeyword(weap, 'WeaponTypePistol') then begin
            //if has any keyword that contains 'revolver'
            if (getElementEditValues(weap, 'DNAM\Flags\Bolt Action') = '1') then result := 'Revolver'
            else result := 'Pistol'
        end
        else if hasKeyword(weap, 'WeaponTypeRifle') then begin
            if (getElementEditValues(weap, 'DNAM\Flags\Bolt Action') = '1') then result := 'Rifle'
            else result := 'AutoRifle'
        end
        else if hasKeyword(weap, 'WeaponTypeHeavy') then result := 'AutoRifle'
        else begin //try iterating through the OMODs looking for pistol/rifle keywords
            mnam := LinksTo(ElementByIndex(ElementBySignature(omod, 'MNAM'), 0));
        
            for i := 0 to ReferencedByCount(mnam)-1 do begin
                omodRef := ReferencedByIndex(mnam, i);
            
                if not isWinningOverride(omodRef) then continue;
                if (Signature(omodRef) <> 'OMOD') then continue;
                if isModcol(omodRef) then continue;
                
                if omodHasKeyword(omodRef, 'WeaponTypePistol') then hasPistol := true
                else if omodHasKeyword(omodRef, 'WeaponTypeRifle') then hasRifle := true;
            end;

            if hasPistol and (NOT hasRifle) then begin
                if (getElementEditValues(weap, 'DNAM\Flags\Bolt Action') = '1') then result := 'Revolver'
                else result := 'Pistol'
            end
            else if hasRifle and (NOT hasPistol) then begin
                if (getElementEditValues(weap, 'DNAM\Flags\Bolt Action') = '1') then result := 'Rifle'
                else result := 'AutoRifle'
            end
            else result := 'Pistol';
        end;
    end
    else begin
        if hasKeyword(weap, 'WeaponTypeLaser') then result := 'Capacitor'
        else result := 'SuperCapacitor';
    end;

    if not Assigned(result) then raise Exception.Create('**ERROR** Unable to find a scrap type');

end;

//UTIL============================================================================  
function fallbackIsPreWar(weap: IInterface): boolean;
var
    weapName: string;
begin
    logg(4, 'Using fallback isPreWar for ' + EditorID(weap));
    if (Signature(weap) <> 'WEAP') then raise Exception.Create('**ERROR** fallback isPreWar called with non-weap record');
    weapName := getElementEditValues(weap, 'FULL');
    result := not (containsText(weapName, 'pipe')
        OR containsText(weapName, 'handmade')
        OR containsText(weapName, 'makeshift')
        OR containsText(weapName, 'wasteland')
        or containsText(weapName, 'commonwealth')
        or containsText(weapName, 'railway')
        or containsText(weapName, 'junk')
        or containsText(weapName, 'improv')
        or containsText(weapName, 'musket')
        or containsText(weapName, 'syringer')
        );
    logg(3, 'isPreWar = ' + BoolToStr(result));
end;


end.