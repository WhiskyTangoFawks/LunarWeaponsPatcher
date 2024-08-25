unit wtflib_powerArmor;

uses 'wtfLib\wtfLib_logging';

var
  paConfig, paIndex, armorerTier, scienceTier: TStringList;

//============================================================================  
function initPowerArmorFiles(): integer;
var
  i : integer;
  
begin

//ma_keyword=test, armorer=01, science=02, blacksmith=03

  paConfig := TStringList.create;
  paConfig.LoadFromFile('Edit Scripts\Degrade\powerArmor.ini');

  paIndex := TStringList.create;
  armorerTier := TStringList.create;
  scienceTier := TStringList.create;
  for i := 0 to pred(paConfig.Count) do parsePaConfigLine(paConfig[i]);

    
end;
//============================================================================  
function parsePaConfigLine(line: string): integer;
var
  j, eqIndex: integer;
  key, value: string;
  temp: TStringList;

begin
    if line = '' then exit;
    if not containsText(line, 'ma_keyword') then exit;
    logg(3, 'Loaded ammo config line: ' + line);
    
    temp := TStringList.create;
    temp.Delimiter := ','; 
    temp.DelimitedText := line;
    
    if (temp.count < 3) then raise exception.create('powerArmor.ini missing config property in: ' + line);

    for j := 0 to pred(temp.Count) do begin
      eqIndex := pos('=', temp[j]);
      key := trim(copy(temp[j], 1, eqIndex-1));
      value := trim(copy(temp[j], eqIndex+1, length(temp[j])));
      logg(3, 'parsed key "' + key + '"="' + value + '"');
      if (key='ma_keyword') then paIndex.add(value)
      else if (key='blacksmith') OR (key='armorer') then armorerTier.add(value)
      else if (key='science') then scienceTier.add(value)
      else raise exception.create('powerArmor.ini Unrecognized config key: "'  + key + '" in line: ' + line);
    end;
end;

//============================================================================  
function gePAIndexForArmo(armo: Iinterface): integer;
var
  i: integer;
  newLine, keyword: string;
  properties: IInterface;
  
begin
  result := -1;

  if ContainsText(EditorID(armo), 'Overboss') then result := paIndex.indexOf('ma_PA_T51')
  else if ContainsText(EditorID(armo), 'T4') then result := paIndex.indexOf('ma_PA_T45')
  else if ContainsText(EditorID(armo), 'T5') then result := paIndex.indexOf('ma_PA_T51')
  else if ContainsText(EditorID(armo), 'T6') then result := paIndex.indexOf('ma_PA_T60')
  else if ContainsText(EditorID(armo), 'X0') then result := paIndex.indexOf('ma_PA_X01')
  else if ContainsText(EditorID(armo), 'Raider') then result := paIndex.indexOf('ma_PA_Raider');

  if (result = -1) then for i := 0 to pred(paIndex.Count) do begin
    logg(1, 'Checking for keyword: ' + paIndex[i]);
    if hasKeyword(armo, paIndex[i]) then begin 
      logg(1, 'found keyword: ' + paIndex[i]);
      result := i;
    end;
  end;

  if (result = -1) then raise exception.create('Unable to find ma_keyword for ' + IntToHex(GetLoadOrderFormID(armo), 8) + ' please add a unique keyword for it to powerArmor.ini');
end;

//============================================================================  
function getArmorerTierForPA(armo: IInterface): integer;
var
  i: integer;

begin
  logg(2, 'Looking up armorer tier for ' + EditorID(armo));
  i := gePAIndexForArmo(armo);
  result := armorerTier[i];
end;

//============================================================================  
function getScienceTierForPA(armo: IInterface): integer;
var
  i: integer;

begin
logg(2, 'Looking up science tier for ' + EditorID(armo));
  i := gePAIndexForArmo(armo);
  result := scienceTier[i];
end;
//============================================================================  

function removeLBPACTokens(cobj: IInterface): String;
var
  WorkingComp, eFVPA: IInterface;
  i: integer;
begin
  eFVPA := ElementByPath(cobj, 'FVPA - Components');
  for i := ElementCount(eFVPA)-1 downto 0 do begin
    WorkingComp := ElementByIndex(eFVPA, i);
    if containsText(GetEditValue(ElementByIndex(WorkingComp, 0)), 'PowerArmorExo') then
       Remove(WorkingComp);
  end;
end;

end.