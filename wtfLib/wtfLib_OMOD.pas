unit wtfLib_OMOD;

uses 'wtfLib\wtfLib_COBJ';
uses 'wtfLib\wtfLib_logging';

//============================================================================  
//Removes an omod, and all references to it
function disableOMOD(e: IInterface): IInterface;
var
  ref, listmods, omod, misc: IInterface;
  i, j: integer;
begin
 logg(3, 'Disabling OMOD - ' + EditorID(e));
  for i := 0 to ReferencedByCount(e)-1 do if isWinningOverride(ReferencedByIndex(e, i)) then begin
    ref := ReferencedByIndex(e, i);
    logg(2, 'Cleaning ref for ' + Signature(ref) + ' : ' + EditorID(ref));

    if Signature(ref) = 'OMOD' then if getElementEditValues(ref, 'Record Header\record flags\Mod Collection') = '1' then begin
      AddRequiredElementMasters(ref, mxPatchFile, false);
      ref := wbCopyElementToFile(ref, mxPatchFile, false, true);
      listmods := ElementByPath(ref, 'DATA\Includes');
      for j := ElementCount(listMods) downto 0 do begin
          omod := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j), 'Mod')));
          if getElementEditValues(e, 'EDID') = getElementEditValues(omod, 'EDID') then begin 
            removeByIndex(listMods, j, true);
            logg(2, 'Removed OMOD from Modcol ' + EditorID(ref));
          end;
      end;
      if ElementCount(listMods) = 0 then disableOMOD(ref);
    end
    else if signature(ref) = 'COBJ' then begin
      ref := wbCopyElementToFile(ref, mxPatchFile, false, true);
      logg(2, 'Removed CNAM from COBJ ' + EditorID(ref));
      removeElement(e, 'CNAM');
    end
    else if signature(ref) = 'MISC' then begin
      disableMISC(ref);
    end
    else if signature(ref) = 'WEAP' then begin 
      logg(5, 'Omod to disable found in a weapon template: ' + EditorID(ref));
    end;

  end;

end;

//============================================================================  
//removes a misc, and all references to it in levelled lists
function disableMISC(e: IInterface): IInterface;
var
  ref, listmods, target, misc: IInterface;
  i, j: integer;
  
begin
  for i := 0 to (ReferencedByCount(e)-1) do if isWinningOverride(ReferencedByIndex(e, i)) then begin
    ref := ReferencedByIndex(e, i);
    if signature(ref) = 'LVLI' then begin
      AddRequiredElementMasters(ref, mxPatchFile, false);
      ref := wbCopyElementToFile(ref, mxPatchFile, false, true);
      listmods := ElementByPath(ref, 'Leveled List Entries');
      
      for j := ElementCount(listMods) downto 0 do begin
        target := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j), 'LVLO\Reference')));
        if EditorID(e) = EditorID(target)  then begin 
          logg(2, 'Removed MISC from LVLI ' + EditorID(ref));
          removeByIndex(listMods, j, true);       
        end;
      end;     

    end
    else if signature(ref) = 'OMOD' then begin
    end
    else if signature(ref) = 'FLST' then begin
      if not containsText(EditorId(ref), 'DLC05PitchingMachineList') then 
        logg(3, 'unchecked FLST while disabling OMOD : ' + EditorID(ref));
    end
    else logg(3, ' Unregnized reference while removing misc for omod ' + Signature(ref) + ' : ' + EditorID(ref));
  end;

end;

//============================================================================  
//Gets the WEAP record for an OMOD based on the MNAM filter keyword
function getTargetWeaponForOMOD(e: IInterface): IInterface;
var
  ref, mnam: IInterface;
  i, refCount: integer;
begin
  refCount := -1;
  if (Signature(e) = 'COBJ') then e := winningOverride(LinksTo(ElementBySignature(e, 'CNAM')));
  mnam:= LinksTo(ElementByIndex(ElementBySignature(e, 'MNAM'), 0));
  for i := 0 to ReferencedByCount(mnam)-1 do begin
    ref := ReferencedByIndex(mnam, i);
    if not(isWinningOverride(ref)) then continue;
    if (signature(ref) <> 'WEAP') then continue;
    if (getElementEditValues(ref, 'CNAM') <> '') then continue; 
    if (getElementEditValues(ref, 'Record Header\record flags\Non-Playable') = '1') then continue;
    if containsText(getElementEditValues(ref, 'DNAM\AMMO'), 'workshop') then continue;
    if containsText(getElementEditValues(ref, 'DNAM\AMMO'), 'MS02NukeMissileAmmoFar') then continue;

    if ReferencedByCount(ref) > refCount then begin
      refCount := ReferencedByCount(ref);
      result := ref;
    end;
    
  end;
  //if not assigned(result) then raise Exception.Create('**ERROR** find weapon for omod');
end;
//============================================================================  
//Gets the ARMO record for an OMOD based on the MNAM filter keyword
function getTargetArmorForOMOD(e: IInterface): IInterface;
var
  ref, mnam: IInterface;
  i: integer;
begin
  if Signature(e) = 'COBJ' then e := winningOverride(LinksTo(ElementBySignature(e, 'CNAM')));
  mnam:= LinksTo(ElementByIndex(ElementBySignature(e, 'MNAM'), 0));
  for i := 0 to ReferencedByCount(mnam)-1 do begin
    ref := ReferencedByIndex(mnam, i);
    if signature(ref) = 'ARMO' then begin
      result := WinningOverride(ref);
      exit;
    end;
  end;
end;


//============================================================================  

function getDamageOffsetOmod(omod: IInterface; offset: Integer): IInterface;

  
begin
    
  result := getOffsetByReference(omod, offset);
  if assigned(result) then exit;
  
  logg(4, 'Refby failed to find a suitable OMOD trying MODCOL search');

end;

//============================================================================  

function getOffsetByReference(omod: IInterface; offset: Integer): IInterface;
var
  omodRef, mnam: IInterface;
  i, level: integer;
  ap: String;
  isAuto: Boolean;

begin
  level := getDamageLevel(omod) + offset;
  mnam := LinksTo(ElementByIndex(ElementBySignature(omod, 'MNAM'), 0));
  ap := getElementEditValues(omod, 'DATA\Attach Point');
  isAuto := omodHasKeyword(omod, 'WeaponTypeAutomatic') or omodHasProperty(omod, 'isAutomatic');
  
  for i := 0 to ReferencedByCount(mnam)-1 do begin
    omodRef := ReferencedByIndex(mnam, i);
    
    if (Signature(omodRef) <> 'OMOD') then continue;
    if not isWinningOverride(omodRef) then continue;
    if ap <> getElementEditValues(omodRef, 'DATA\Attach Point') then continue;
    if isModcol(omodRef) then continue;
    if isNonStandardReceiver(omodRef) then continue;
    if level <> getDamageLevel(omodRef) then continue;
    if isAuto <>  (omodHasKeyword(omodRef, 'WeaponTypeAutomatic') or omodHasProperty(omodRef, 'isAutomatic')) then continue;
    
    result := omodRef;
    logg(2, 'get RefBy offset Found ' + EditorID(result));
    exit;
    
  end;

end;

//============================================================================  

function isNonStandardReceiver(omod: IInterface): boolean;
var weaponName: String;
begin
  result := false;
  
    weaponName := getElementEditValues(getTargetWeaponForOMOD(omod), 'FULL');
    
    //addMessage('non standard receiver testing - name ' + weaponName);


    if omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals1')
    OR omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals2')
    //OR omodHasProperty(omod, 'CriticalDamageMult')
    OR omodHasPropertyValue(omod, 'Enchantments', 'enchMod_LaserReceiver_Fire2')
    
    OR omodHasKeyword(omod, 'dn_HasReceiver_Heavy')
    OR omodHasKeyword(omod, 'dn_HasReceiver_FastBoltAction')
    OR omodHasKeyword(omod, 'dn_HasReceiver_Light')
    OR omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing1')
    OR omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing2')
    OR omodHasKeyword(omod, 'dn_HasReceiver_FastSemiAuto')
    OR omodHasKeyword(omod, 'dn_HasReceiver_Converted') OR omodHasProperty(omod, 'Ammo')
    OR omodHasKeyword(omod, 'dn_HasReceiver_Automatic2')

    OR (NOT containsText(weaponName, 'Piercing')) AND containsText(EditorID(omod), 'Piercing')
    OR (NOT containsText(weaponName, 'Critical')) AND containsText(EditorID(omod), 'Critical')
    OR (NOT containsText(weaponName, 'Crits')) AND containsText(EditorID(omod), 'Crits')
    OR (NOT containsText(weaponName, 'Fast')) AND containsText(EditorID(omod), 'Fast')
    OR (NOT containsText(weaponName, 'Light')) AND containsText(EditorID(omod), 'Light')
    OR (NOT containsText(weaponName, 'Heavy')) AND containsText(EditorID(omod), 'Heavy')
    OR (NOT containsText(weaponName, 'Better')) AND containsText(EditorID(omod), 'Better')
    then begin  
      
      result := true;
    end;
     //if log then addMessage('Checking if isNonStandardReceiver - ' + EditorID(omod) + ' = ' + BoolToStr(result));

end;

//============================================================================  

function disableLargeQuickMags(omod, cobj: IInterface): boolean;
begin
  result := false;
  
  if omodHasKeyword(omod, 'dn_HasMag_Quick') OR containsText(getElementEditValues(omod, 'FULL'), 'Quick') then begin 
      if log then addMessage('Checking if quick Magazine should be disabled');
      if omodHasKeyword(omod, 'dn_HasMag_Large')
      OR ContainsText(EditorID(omod), 'Large') 
      OR ContainsText(EditorID(omod), 'Drum') 
      OR ContainsText(getElementEditValues(omod, 'FULL'), 'Large')
      OR ContainsText(getElementEditValues(omod, 'FULL'), 'Drum') then begin 
         if log then addMessage('Disabling quick eject large or drum mag');
        removeElement(cobj, 'CNAM');
        setElementEditValues(cobj, 'EDID', '_disabled_'+EditorID(cobj));
        disableOMOD(omod);
        result := true;
        exit;
    end;
      end;

end;
//============================================================================  

function sortModcolByLevel(omod: IInterface): boolean;
var
  listMods : IInterface;
  lastLevel, i : Integer;
begin
    lastLevel := -1;
    listmods := ElementByPath(omod, 'DATA\Includes');
    
    for i := 0 to ElementCount(listMods)-1 do begin
      if lastLevel > StrToInt(getElementEditValues(ElementByIndex(listMods, i), 'Minimum Level')) then begin
        ElementAssign(listMods, HighInteger, ElementByIndex(listMods, i-1), false);
        removeByIndex(listMods, i-1, true);
        sortModcolByLevel(omod);
        exit;
      end
      else begin
        lastLevel := StrToInt(getElementEditValues(ElementByIndex(listMods, i), 'Minimum Level'));
      end;
      
    end;


end;

//============================================================================  
function createUpgrade(templateOmod: IInterface; templateMisc: IInterface; templateCobj: IInterface): IInterface;
var
  omod, misc, cobj, properties, listmods, entry, conds: IInterface;
  i, newKeywordFormID, x, y: integer;
  oldValue, newValue: Float;
  oldKeyword, propertyName, temp: String;

begin
  AddMessage('Creating upgrade from: ' + EditorID(templateOmod));
  omod := wbCopyElementToFile(templateOmod, mxPatchFile, true, true);
  misc := wbCopyElementToFile(templateMisc, mxPatchFile, true, true);
  cobj := wbCopyElementToFile(templateCobj, mxPatchFile, true, true);
  
    //omod here is the the  template - the first step is setting the damage keyword +1
    if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage2') AND omodHasKeyword(omod, 'dn_HasReceiver_Automatic') then begin
      setOmodDamageKeyword(omod, '3');
      setOmodPropertyValue(omod, 'AttackDamage', '0.4');
      setOmodPropertyValue(omod, 'Weight', '0.4');
      setOmodPropertyValue(omod, 'Value', '0.85');
    end
    else If omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage3') AND not omodHasKeyword(omod, 'dn_HasReceiver_Automatic') then begin
      setOmodDamageKeyword(omod, '4');
      setOmodPropertyValue(omod, 'AttackDamage', '1');
      setOmodPropertyValue(omod, 'Weight', '0.5');
      setOmodPropertyValue(omod, 'Value', '0.9');
      
    end
    else If omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage2') AND not omodHasKeyword(omod, 'dn_HasReceiver_Automatic') then begin
      setOmodDamageKeyword(omod, '3');
      setOmodPropertyValue(omod, 'AttackDamage', '.75');
      setOmodPropertyValue(omod, 'Weight', '0.4');
      setOmodPropertyValue(omod, 'Value', '0.85');
      
    end;

   //omod EDID
    setElementEditValues(omod, 'EDID', getUpgradeString(EditorID(omod)));
    //omod full
    setElementEditValues(omod, 'FULL', getUpgradeString(getElementEditValues(omod, 'FULL')));
    //omod desc
    setElementEditValues(omod, 'DESC', getReceiverDesc(getDamageLevel(omod), omodHasKeyword(omod, 'dn_HasReceiver_Automatic')));
    //omod LNAM
    setElementEditValues(omod, 'LNAM', IntToHex(GetLoadOrderFormID(misc) , 8));

    //add OMOD to Modcol
    x := 0;
    for i := 0 to ReferencedByCount(templateOmod) do 
    if isWinningOverride(ReferencedByIndex(templateOmod, i))
    AND (getElementEditValues(ReferencedByIndex(templateOmod, i), 'Record Header\record flags\Mod Collection') = '1') then begin
      
      listmods := ElementByPath(ReferencedByIndex(templateOmod, i), 'DATA\Includes');
      x := StrToInt(getElementEditValues(elementByIndex(listMods,ElementCount(listMods)-2), 'Minimum Level'));
      y := StrToInt(getElementEditValues(elementByIndex(listMods,ElementCount(listMods)-1), 'Minimum Level'));
      entry := ElementAssign(listMods, HighInteger, nil, true);
      SetElementEditValues(entry, 'Mod', IntToHex(GetLoadOrderFormID(omod), 8));
      SetElementEditValues(entry, 'Minimum Level', ((y-x) * 2) + y);
    end;
    if x = 0 then AddMessage('**WARNING** Failed to add new mod to existing modcol');

    //cobj EDID
    setElementEditValues(cobj, 'EDID', getUpgradeString(EditorID(cobj)));
    //cobj CNAM
    setElementEditValues(cobj, 'CNAM', IntToHex(GetLoadOrderFormID(omod) , 8));
    //Cobj recipe counts
    increaseRecipeCounts(cobj);
    //Cobj - increase perk req
    increasePerkReqs(cobj) ;

    //Misc EDID
    temp := EditorID(misc);
    if pos('[', temp) > 0 then temp := copy(temp, 1, pos('[', temp)-2);
    if pos('"', temp) > 0 then temp := copy(temp, 1, pos('"', temp)-2);
    temp := getUpgradeString(temp);
    addMessage('Upgraded Misc String ' + temp);
    setElementEditValues(misc, 'EDID', temp);
    //Misc FULL
    setElementEditValues(misc, 'FULL', getUpgradeString(getElementEditValues(misc, 'FULL')));

    

  result := cobj;

end;

//============================================================================  

function getReceiverDesc(lvl: Integer; isAuto: boolean): String;
begin

if lvl = 1 and not isAuto then result := 'Better damage.'
else if lvl = 2 and not isAuto then result := 'Superior damage.'
else if lvl = 3 and not isAuto then result := 'Exceptional damage.'
else if lvl = 4 and not isAuto then result := 'Incredible damage.'
else if lvl = 1 and isAuto then result := 'Improved rate of fire. Reduced damage. Inferior range.'
else if lvl = 2 and isAuto then result := 'Improved damage and rate of fire. Inferior Range.'
else if lvl = 3 and isAuto then result := 'Exceptional damage and rate of fire. Inferior range.';

if not Assigned(result) then raise Exception.Create('getReceiver called unexpected values. level = ' + IntToStr(lvl) + ', isAuto=' + BoolToStr(isAuto));

end;
//============================================================================  

function getUpgradeString(str: String): String;
begin
  addMessage('Upgrading String: ' + str);
  if containsText(str, 'Standard') then 
    result := StringReplace(str, 'Standard', 'MoreDamage1', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Automatic1') then 
    result := StringReplace(str, 'Automatic1', 'Automatic1_and_MoreDamage1', [rfReplaceAll, rfIgnoreCase])  
  else if containsText(str, 'MoreDamage1') then 
    result := StringReplace(str, 'MoreDamage1', 'MoreDamage2', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'MoreDamage2') then 
    result := StringReplace(str, 'MoreDamage2', 'MoreDamage3', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'MoreDamage3') then 
    result := StringReplace(str, 'MoreDamage3', 'MoreDamage4', [rfReplaceAll, rfIgnoreCase])

  else if containsText(str, 'MoreDamage_1') then 
    result := StringReplace(str, 'MoreDamage_1', 'MoreDamage_2', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'MoreDamage_2') then 
    result := StringReplace(str, 'MoreDamage_2', 'MoreDamage_3', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'MoreDamage_3') then 
    result := StringReplace(str, 'MoreDamage_3', 'MoreDamage_4', [rfReplaceAll, rfIgnoreCase])

  else if containsText(str, 'Hardened') then 
    result := StringReplace(str, 'Hardened', 'Powerful', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Powerful') then 
    result := StringReplace(str, 'Powerful', 'Advanced', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Advanced') then 
    result := StringReplace(str, 'Advanced', 'Masterwork', [rfReplaceAll, rfIgnoreCase])

  else if containsText(str, 'boosted') then 
    result := StringReplace(str, 'Boosted', 'Optimized', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Optimized') then 
    result := StringReplace(str, 'Optimized', 'Maximized', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Optimised') then 
    result := StringReplace(str, 'Optimised', 'Maximized', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Maximized') then 
    result := StringReplace(str, 'Maximized', 'Overcharged', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Maximised') then 
    result := StringReplace(str, 'Maximised', 'Overcharged', [rfReplaceAll, rfIgnoreCase])

  else if containsText(str, 'Better') then 
    result := StringReplace(str, 'Better', 'Superior', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Exceptional') then 
    result := StringReplace(str, 'Exceptional', 'Incredible', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, 'Superior') then 
    result := StringReplace(str, 'Superior', 'Incredible', [rfReplaceAll, rfIgnoreCase])
  
  else if containsText(str, '1') then 
    result := StringReplace(str, '1', '2', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '2') then 
    result := StringReplace(str, '2', '3', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '3') then 
    result := StringReplace(str, '3', '4', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '4') then 
    result := StringReplace(str, '4', '5', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '5') then 
    result := StringReplace(str, '5', '6', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '6') then 
    result := StringReplace(str, '6', '7', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '7') then 
    result := StringReplace(str, '7', '8', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '8') then 
    result := StringReplace(str, '8', '9', [rfReplaceAll, rfIgnoreCase])
  else if containsText(str, '9') then 
    result := StringReplace(str, '9', '10', [rfReplaceAll, rfIgnoreCase]);

  
  if not assigned(result) then raise Exception.Create('*Error - failed to upgrade string - ' + str);
  
end;

//============================================================================  

function setOmodPropertyValue(omod: IInterface; propertyToSet, newValue: String): String;
var
  properties: IInterface;
  propertyName: String;
  i: IInterface;

begin
  addMessage('Setting Property Value: ' + propertyToSet + ', ' + newValue);
  properties := ElementByPath(omod, 'DATA\Properties');
    for i := 0 to ElementCount(properties)-1 do begin
        propertyName := getElementEditValues(ElementByIndex(properties, i), 'Property');
        if propertyName = propertyToSet then begin
          setElementEditValues(ElementByIndex(properties, i), 'Value 1', newValue);
        end
    end;
  
end;

//============================================================================  

function setOmodDamageKeyword(omod: IInterface; newValue: String): String;
var
  properties: IInterface;
  propertyName, oldKeyword: String;
  i, newKeywordFormID: integer;

begin
  AddMessage('Setting damage keyword to ' + newValue);
  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do
  if getElementEditValues(ElementByIndex(properties, i), 'Property') = 'Keywords' then begin
    oldKeyword := getElementEditValues(ElementByIndex(properties, i), 'Value 1');
    if containsText(oldKeyword, 'dn_HasReceiver_MoreDamage') then begin
      addMessage('Found ' + oldKeyword);
      if newValue = '4' then newKeywordFormID := GetLoadOrderFormID(MainRecordByEditorID(GroupBySignature(masterFiles[3], 'KYWD'), 'dn_HasReceiver_MoreDamage'+ newValue))
      else newKeywordFormID := GetLoadOrderFormID(MainRecordByEditorID(GroupBySignature(masterFiles[0], 'KYWD'), 'dn_HasReceiver_MoreDamage'+ newValue));
      addMessage('Setting damage keyword' + IntToStr(newKeywordFormID));
      setElementEditValues(ElementByIndex(properties, i), 'Value 1', IntToHex(newKeywordFormID, 8)); 
      if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage'+ newValue) then begin
        addMessage('keyword successfully assigned');
        //Exit; - Don't exit, if omod has duplicate keywords it causes issues
      end;
    end;
  end;

end;
//============================================================================  

function addOmodKeyword(omod: IInterface; keyword: int): IInterface;

begin
    result := ElementAssign(ElementByPath(omod, 'DATA\Properties'), HighInteger, nil, true);
    SetElementEditValues(result, 'Value Type', 'FormID,Int');
    SetElementEditValues(result, 'Function Type', 'ADD');
    SetElementEditValues(result, 'Property', 'Keywords');
    SetElementEditValues(result, 'Value 1', keyword);
end;
//============================================================================  

function expectOmodPropertyValueRange(omod: IInterface; expectedProperty: String; min, max: Float): boolean;
var
  properties: IInterface;
  valueOne: float;
  i: IInterface;

begin
  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do begin
      if expectedProperty = getElementEditValues(ElementByIndex(properties, i), 'Property') then begin
        valueOne := getElementEditValues(ElementByIndex(properties, i), 'Value 1');
        if (valueOne < min) OR (valueOne > max) then begin
          addMessage('Found value outside expected range ' + expectedProperty);
          //set to the average of the two values
          valueOne := (max+min)/2;
          setElementEditValues(ElementByIndex(properties, i), 'Value 1', valueOne);
          result := true;
          exit;
        end;
        addMessage('Found value inside expected range ' + expectedProperty);
        exit;
      end
  end;
  addMessage('Property not found, adding: ' + expectedProperty);
  valueOne := (max+min)/2 ;
  if min <> 0 then addPropertyToOmod(omod, 'Float', 'MUL+ADD', expectedProperty, valueOne, '1');
  
end;
//============================================================================  

function expectOmodPropertyValueTwoRange(omod: IInterface; expectedProperty, valueOne: String; min, max: Float): boolean;
var
  properties: IInterface;
  valueTwo: float;
  i: IInterface;

begin
  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do begin
      if expectedProperty = getElementEditValues(ElementByIndex(properties, i), 'Property') then begin
        valueTwo := getElementEditValues(ElementByIndex(properties, i), 'Value 2');
        if (valueTwo < min) OR (valueTwo > max) then begin
          addMessage('Found value outside expected range ' + expectedProperty);
          //set to the average of the two values
          valueTwo := (max+min)/2;
          setElementEditValues(ElementByIndex(properties, i), 'Value 2', valueTwo);
          result := true;
          exit;
        end;
        addMessage('Found value inside expected range ' + expectedProperty);
        exit;
      end
  end;
  valueTwo := (max+min)/2 ;
  if min < 0 then addPropertyToOmod(omod, 'FormID,Float', 'MUL+ADD', expectedProperty, valueOne, valueTwo);
  
end;
//============================================================================  
//Returns the OMOD that is preceding this in the first modcol it finds referencing it
function doubleModcolMinLevels(modcol: IInterface): IInterface;
var
  ref, listmods, omod: IInterface;
  i, j, oldLevel: integer;
begin
    listmods := ElementByPath(modcol, 'DATA\Includes');
    //j=1 because we don't want to consider it if it's the 0th position in the modcol
    for j := 0 to ElementCount(listMods)-1 do begin
      oldLevel := StrToInt(getElementEditValues(elementByIndex(listMods, j), 'Minimum Level'));
      if oldLevel > 1 then setElementEditValues(elementByIndex(listMods, j), 'Minimum Level', oldLevel * 2);
    end;
  

end;
//============================================================================  

function omodHasKeyword(omod: IInterface; keyword: String): Boolean;
var
  properties: IInterface;
  i: integer;
begin
  result := false;
  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do
  if getElementEditValues(ElementByIndex(properties, i), 'Property') = 'Keywords' then begin
    if containsText(getElementEditValues(ElementByIndex(properties, i), 'Value 1'), keyword) then begin
      result := true;
      exit;
    end;
  end;
  

end;
//============================================================================  

function omodHasProperty(omod: IInterface; prop: String): Boolean;
var
  properties: IInterface;
  i: integer;
begin
  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do
  if getElementEditValues(ElementByIndex(properties, i), 'Property') = prop then begin
      result := true;
      exit;
  end;

end;

//============================================================================  

function omodHasPropertyValue(omod: IInterface; prop, valueOne: String): Boolean;
var
  properties: IInterface;
  i: integer;
begin
  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do
  if getElementEditValues(ElementByIndex(properties, i), 'Property') = prop then begin
    if containsText(getElementEditValues(ElementByIndex(properties, i), 'Value 1'), valueOne) then begin
      result := true;
      exit;
    end;
  end;
end;
//============================================================================  

function isModcol(omod: IInterface): Boolean;
begin
   result := false;
   if Signature(omod) = 'OMOD' then if
   assigned(getElementEditValues(omod, 'Record Header\record flags\Mod Collection'))
    then if getElementEditValues(omod, 'Record Header\record flags\Mod Collection') = 1
      then result := true;
end;

//============================================================================  

function getAmmo(omod: IInterface): String;
var
  properties: IInterface;
  i: integer;
  ammo: String;
begin

  result := getElementEditValues(winningOverride(getTargetWeaponForOMOD(omod)), 'DNAM\AMMO');

  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do
  if getElementEditValues(ElementByIndex(properties, i), 'Property') = 'Ammo' then begin
    Result := getElementEditValues(ElementByIndex(properties, i), 'Value 1');
    exit;
  end;

end;

//============================================================================  

function addPropertyToOmod(omod: IInterface; ValueType, FunctionType, PropertyToSet, ValueOne, ValueTwo: String): IInterface;
var
  properties: IInterface;

begin
    if log then addMessage('Adding property ' + PropertyToSet);
    properties := ElementByPath(omod, 'DATA\Properties');
    result := ElementAssign(Properties, HighInteger, nil, true);
    SetElementEditValues(result, 'Value Type', ValueType);
    SetElementEditValues(result, 'Function Type', FunctionType);
    SetElementEditValues(result, 'Property', PropertyToSet);
    SetElementEditValues(result, 'Value 1', ValueOne);
    SetElementEditValues(result, 'Value 2', ValueTwo);
end;

//============================================================================  

function getDamageLevel(omod: IInterface): Integer;
  
begin

  result := 0;
  
  if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage1') 
    OR containsText(editorID(omod), 'MoreDamage1') 
    OR omodHasKeyword(omod, 'dn_HasReceiver_Crank2')
    OR omodHasPropertyValue(omod, 'Attack Damage', '0.250000') then
      result := 1
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage2') 
    OR containsText(editorID(omod), 'MoreDamage2') 
    OR omodHasKeyword(omod, 'dn_HasReceiver_Crank3')
    OR omodHasPropertyValue(omod, 'Attack Damage', '0.500000')  then
      result := 2
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage3')
    OR containsText(editorID(omod), 'MoreDamage3') 
    OR omodHasKeyword(omod, 'dn_HasReceiver_Crank4')
    OR omodHasPropertyValue(omod, 'Attack Damage', '0.750000') then
      result := 3
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage4') 
    OR containsText(editorID(omod), 'MoreDamage4') 
    OR omodHasKeyword(omod, 'dn_HasReceiver_Crank5')
    OR omodHasPropertyValue(omod, 'Attack Damage', '1.000000') then
      result := 4

end;
//============================================================================  

function getModifiedDamageLevel(omod: IInterface): Integer;
  
begin

  result := 0;
  
  if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage1') OR containsText(editorID(omod), 'MoreDamage1') then
    result := 1
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage2') OR containsText(editorID(omod), 'MoreDamage2')  then
    result := 2
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage3')  OR containsText(editorID(omod), 'MoreDamage3') then
    result := 3
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage4')  OR containsText(editorID(omod), 'MoreDamage4') then
    result := 4;
  
  if omodHasKeyword(omod, 'WeaponTypeAutomatic') then result := result+1;
  if omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals1') then result := result+1;
  if omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals2') then result := result+2;
  if omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing1') then result := result+1;
  if omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing2') then result := result+2;
    
end;
//============================================================================  

function removeRecipeComponents(e: IInterface): String;
var
  WorkingComp, eFVPA: IInterface;
  i: integer;
begin
  eFVPA := ElementByPath(e, 'FVPA - Components');
  for i := ElementCount(eFVPA)-1 downto 0 do begin
    WorkingComp := ElementByIndex(eFVPA, i);
    Remove(WorkingComp);
  end;
end;
//============================================================================  

function getPropertyValueOne(omod: IInterface; prop:String): String;
var
  properties: IInterface;
  i: integer;
  ammo: String;
begin

  properties := ElementByPath(omod, 'DATA\Properties');
  for i := 0 to ElementCount(properties)-1 do
  if getElementEditValues(ElementByIndex(properties, i), 'Property') = prop then begin
    Result := getElementEditValues(ElementByIndex(properties, i), 'Value 1');
    exit;
  end;

end;

//============================================================================  

function GetPerk(edid: string): IInterface;
var
  i: integer;
begin
  if log then addMessage('Getting load order formID for ' + edid);
  for i := 0 to (Length(masterFiles) - 1) do begin
    result := MainRecordByEditorID(GroupBySignature(masterFiles[i], 'PERK'), edid);
    if result <> 0 then exit;
  end;
  addMessage('**ERROR**: Masterfile not found for: ' + edid);

end;
//=====
end.