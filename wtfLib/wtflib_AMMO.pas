unit wtfLib_AMMO;

uses 'wtfLib\wtfLib_logging';

var
  ammoConfig, ammoIndex, ammoTierList, ammoPerkList: TStringList;

//============================================================================  
function initAmmoTierFiles(): integer;
var
  i : integer;
  
begin

  //Ammo: single file
  //Edid=38Caliber, Tier=1/2/3, CraftingPerk=GunNut

  //Weapons
  //ma_keyword=ma_pipeGun, scrapType=pistol

  ammoConfig := TStringList.create;
  ammoConfig.LoadFromFile('Edit Scripts\Degrade\ammo.ini');

  ammoIndex := TStringList.create;
  ammoTierList := TStringList.create;
  ammoPerkList := TStringList.create;
  for i := 0 to pred(ammoConfig.Count) do parseAmmoConfigLine(ammoConfig[i]);

end;
//============================================================================  
function parseAmmoConfigLine(line: string): integer;
var
  j, eqIndex: integer;
  key, value: string;
  temp: TStringList;

begin
    if line = '' then exit;
    if not containsText(line, 'edid') then exit;
    logg(3, 'Loaded ammo config line: ' + line);
    
    temp := TStringList.create;
    temp.Delimiter := ','; 
    temp.DelimitedText := line;
    
    if (temp.count < 3) then raise exception.create('ammo.ini missing config property in: ' + line);

    for j := 0 to pred(temp.Count) do begin
      eqIndex := pos('=', temp[j]);
      key := trim(copy(temp[j], 1, eqIndex-1));
      value := trim(copy(temp[j], eqIndex+1, length(temp[j])));
      logg(3, 'parsed key "' + key + '"="' + value + '"');
      if (key='edid') then ammoIndex.add(value)
      else if (key='tier') then ammoTierList.add(value)
      else if (key='craftingPerk') then ammoPerkList.add(value)
      else raise exception.create('Unrecognized config key: "'  + key + '" in line: ' + line);
    end;
end;

//============================================================================  
function getAmmoTierForOmod(omod: IInterface): integer;
var
  i: integer;
  ammo: string;

begin
  i := getAmmoIndexForOmod(omod);
  result := ammoTierList[i];
end;

//============================================================================  
function getAmmoPerkForOmod(omod: IInterface): String;
var
  i: integer;
  ammo: string;

begin
  i := getAmmoIndexForOmod(omod);
  result := ammoPerkList[i];
    
end;

//============================================================================  
function getAmmoIndexForOmod(omod: IInterface): integer;
var
  i: integer;
  ammo, newLine: string;
  properties: IInterface;

begin
  ammo:= EditorID(WinningOverride(LinksTo(elementByPath(getTargetWeaponForOMOD(omod), 'DNAM\AMMO'))));
  logg(2, 'Found ammo ' + ammo);
  if (ammo = '') then begin
    logg(4, 'OMOD does not have ammo property, falling back to ma_keyword');
    ammo := EditorID(LinksTo(ElementByIndex(ElementBySignature(omod, 'MNAM'), 0)));
  end;
  result := ammoIndex.indexOf(ammo);

  if result = -1 then begin
    logg(4, 'Ammo tier not found in a config file: ' + ammo);
    newline := 'edid=' + ammo + ', tier=1, craftingPerk=GunNut';
    ammoConfig.add(newLine);
    parseAmmoConfigLine(newLine);
    ammoConfig.SaveToFile('Edit Scripts\Degrade\ammo.ini');
    result := ammoIndex.indexOf(ammo);
  end;
end;



end.