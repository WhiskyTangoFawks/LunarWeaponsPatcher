unit wtfLib_OMOD;

uses 'wtfLib\wtfLib_COBJ';

//============================================================================  
//Removes an omod, and all references to it
function disableOMOD(e: IInterface): IInterface;
var
  ref, listmods, omod, misc: IInterface;
  i, j: integer;
begin
  if log then AddMessage('Disabling OMOD - ' + EditorID(e));
  for i := 0 to ReferencedByCount(e) do if isWinningOverride(ReferencedByIndex(e, i)) then begin
    ref := ReferencedByIndex(e, i);
    if log then addMessage('Cleaning ref for ' + Signature(ref) + ' : ' + EditorID(ref));

    if Signature(ref) = 'OMOD' then if getElementEditValues(ref, 'Record Header\record flags\Mod Collection') = '1' then begin
      
      ref := wbCopyElementToFile(ref, mxPatchFile, false, true);
      listmods := ElementByPath(ref, 'DATA\Includes');
      for j := ElementCount(listMods) downto 0 do begin
          omod := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j), 'Mod')));
          if getElementEditValues(e, 'EDID') = getElementEditValues(omod, 'EDID') then begin 
            removeByIndex(listMods, j, true);
            if log then addMessage('Removed OMOD from Modcol ' + EditorID(ref));
          end;
      end;
      if ElementCount(listMods) = 0 then disableOMOD(ref);
    end
    else if signature(ref) = 'COBJ' then begin
      ref := wbCopyElementToFile(ref, mxPatchFile, false, true);
      if log then addMessage('Removed CNAM from COBJ ' + EditorID(ref));
      removeElement(e, 'CNAM');
    end
    else if signature(ref) = 'MISC' then begin
      disableMISC(ref);
    end
    else if signature(ref) = 'WEAP' then begin 
      addMessage('**ERROR** Omod to disable found in a weapon template: ' + EditorID(ref));
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
  for i := 0 to ReferencedByCount(e) do if isWinningOverride(ReferencedByIndex(e, i)) then begin
    ref := ReferencedByIndex(e, i);
    if signature(ref) = 'LVLI' then begin
      ref := wbCopyElementToFile(ref, mxPatchFile, false, true);
      listmods := ElementByPath(ref, 'Leveled List Entries');
      
      for j := ElementCount(listMods) downto 0 do begin
        target := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j), 'LVLO\Reference')));
        if EditorID(e) = EditorID(target)  then begin 
          if log then addMessage('Removed MISC from LVLI ' + EditorID(ref));
          removeByIndex(listMods, j, true);       
        end;
      end;     

    end
    else if signature(ref) = 'OMOD' then begin
    end
    else addMessage('**WARNING** Unregnized reference while removing misc for omod ' + Signature(ref) + ' : ' + EditorID(ref));
  end;

end;

//============================================================================  
//Gets the WEAP record for an OMOD based on the MNAM filter keyword
function getTargetWeaponForOMOD(e: IInterface): IInterface;
var
  ref, mnam: IInterface;
  i: integer;
begin
  if Signature(e) = 'COBJ' then e := winningOverride(LinksTo(ElementBySignature(e, 'CNAM')));
  mnam:= LinksTo(ElementByIndex(ElementBySignature(e, 'MNAM'), 0));
  for i := 0 to ReferencedByCount(mnam) do begin
    ref := ReferencedByIndex(mnam, i);
    if signature(ref) = 'WEAP' then begin
      result := WinningOverride(ref);
      exit;
    end;
  end;
end;

//============================================================================  
//Returns the OMOD that is preceding this in the first modcol it finds referencing it
function getDowngrade(e: IInterface): IInterface;
var
  ref, listmods, omod: IInterface;
  i, j: integer;
begin
  for i := 0 to ReferencedByCount(e) do if getElementEditValues(ReferencedByIndex(e, i), 'Record Header\record flags\Mod Collection') = '1' then begin
    listmods := ElementByPath(ReferencedByIndex(e, i), 'DATA\Includes');
    //j=1 because we don't want to consider it if it's the 0th position in the modcol
    if ElementCount(listMods) > 1 then for j := 1 to ElementCount(listMods) do begin
        omod := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j), 'Mod')));
        if getElementEditValues(e, 'EDID') = getElementEditValues(omod, 'EDID') then begin
            result := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j-1), 'Mod')));
            exit;
        end;
    end;
  end;

end;

//============================================================================  
//Returns the OMOD that is following this in the first modcol it finds referencing it
function getUpgrade(e: IInterface): IInterface;
var
  listmods, omod, f: IInterface;
  i, j: integer;
begin
  
  //addMessage('Searching for upgrade');
  //for i := 0 to ReferencedByCount(e)-1 do if isWinningOverride(ReferencedByIndex(e, i)) AND isModcol(ReferencedByIndex(e, i)) then begin
  //  listmods := ElementByPath(ReferencedByIndex(e, i), 'DATA\Includes');
    //j only goes to count-1 because we need to be able to +1
  //  if ElementCount(listMods) > 1 then for j := 0 to ElementCount(listMods)-2 do begin
  //    omod := LinksTo(ElementByPath(ElementByIndex(listMods, j), 'Mod'));
  //    if isNonStandardReceiver(omod) then begin
        //skip- this will be disabled later
  //    end 
  //    else begin
  //      result := WinningOverride(LinksTo(ElementByPath(ElementByIndex(listMods, j+1), 'Mod')));
  //      if Assigned(result) then begin
  //        addMessage('Found upgrade via modcol ' + EditorID(result));
  //        exit;
  //      end;
  //    end;
  //  end;
  //end;

  //Run a check on every loaded file for the EDID
  addMessage('Searching for EDID=' + getUpgradeString(EditorID(e)));
  for i := 0 to Pred(FileCount) do begin
		result := MainRecordByEditorID(GroupBySignature(FileByIndex(i), 'OMOD'), getUpgradeString(EditorID(e)));
    if assigned(result) then begin 
      addMessage('Found ' + EditorID(result));
      exit;
    end;
	end;

end;

//============================================================================  

function isNonStandardReceiver(omod: IInterface): boolean;
begin
  result := false;
   if log then addMessage('Checking if isNonStandardReceiver - ' + EditorID(omod));
    if omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals1')
    OR omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals2')
    OR omodHasProperty(omod, 'CriticalDamageMult')
    OR omodHasPropertyValue(omod, 'Enchantments', 'enchMod_LaserReceiver_Fire2')
    
    OR omodHasKeyword(omod, 'dn_HasReceiver_Heavy')
    OR omodHasKeyword(omod, 'dn_HasReceiver_FastBoltAction')
    OR omodHasKeyword(omod, 'dn_HasReceiver_Light')
    OR omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing1')
    OR omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing2')
    OR omodHasKeyword(omod, 'dn_HasReceiver_FastSemiAuto')
//    OR omodHasKeyword(omod, 'dn_HasReceiver_Converted') OR omodHasProperty(omod, 'Ammo')
    OR omodHasKeyword(omod, 'dn_HasReceiver_Automatic2')
    then begin  
      
      result := true;
    end;

end;

//============================================================================  

function disableLargeQuickMags(omod, cobj: IInterface): boolean;
begin
  result := false;
  
  if omodHasKeyword(omod, 'dn_HasMag_Quick') then begin 
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
  
    //omod EDID
    setElementEditValues(omod, 'EDID', getUpgradeString(EditorID(omod)));
    //omod full
    setElementEditValues(omod, 'FULL', getUpgradeString(getElementEditValues(omod, 'FULL')));
    //omod desc
    setElementEditValues(omod, 'DESC', getUpgradeString(getElementEditValues(omod, 'DESC')));
    //omod LNAM
    setElementEditValues(omod, 'LNAM', IntToHex(GetLoadOrderFormID(misc) , 8));
    
    //OMOD Properties
    
    if ContainsText(EditorID(omod), 'MoreDamage3') AND ContainsText(EditorID(omod), 'auto') then begin
      setOmodPropertyValue(omod, 'AttackDamage', '0.8');
      setOmodPropertyValue(omod, 'Weight', '0.4');
      setOmodPropertyValue(omod, 'Value', '0.85');
      setOmodDamageKeyword(omod, '3');
    
    end
    else If ContainsText(EditorID(omod), 'MoreDamage4') then begin
      setOmodPropertyValue(omod, 'AttackDamage', '1');
      setOmodPropertyValue(omod, 'Weight', '0.5');
      setOmodPropertyValue(omod, 'Value', '0.9');
      setOmodDamageKeyword(omod, '4');
    end;

    //add OMOD to Modcol
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
    
    //cobj EDID
    setElementEditValues(cobj, 'EDID', getUpgradeString(EditorID(cobj)));
    //cobj Full
    setElementEditValues(cobj, 'FULL', getUpgradeString(getElementEditValues(cobj, 'FULL')));
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

    //---- TODO verify armor piercing receivers

  result := cobj;

end;
//============================================================================  

function getUpgradeString(str: String): String;
begin
  if containsText(str, 'MoreDamage1') then 
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

  
  if not assigned(result) then addMessage('*Error - failed to upgrade string - ' + str);
  
end;

//============================================================================  

function setOmodPropertyValue(omod: IInterface; propertyToSet, newValue: String): String;
var
  properties: IInterface;
  propertyName: String;
  i: IInterface;

begin
  properties := ElementByPath(omod, 'DATA\Properties');
    for i := 0 to ElementCount(properties)-1 do begin
        propertyName := getElementEditValues(ElementByIndex(properties, i), 'Property');
        if propertyName = propertyToSet then begin
          addMessage('Found ' + propertyName + getElementEditValues(ElementByIndex(properties, i), 'Value 1'));
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
  properties := ElementByPath(omod, 'DATA\Properties');
    for i := 0 to ElementCount(properties)-1 do
    if getElementEditValues(ElementByIndex(properties, i), 'Property') = 'Keywords' then begin
      oldKeyword := getElementEditValues(ElementByIndex(properties, i), 'Value 1');
      if containsText(oldKeyword, 'dn_HasReceiver_MoreDamage') then begin
        addMessage('Found ' + oldKeyword);
        if newValue = '4' then newKeywordFormID := GetLoadOrderFormID(MainRecordByEditorID(GroupBySignature(masterFiles[3], 'KYWD'), 'dn_HasReceiver_MoreDamage'+ newValue))
        else newKeywordFormID := GetLoadOrderFormID(MainRecordByEditorID(GroupBySignature(masterFiles[0], 'KYWD'), 'dn_HasReceiver_MoreDamage'+ newValue));
        addMessage('Setting ' + IntToStr(newKeywordFormID));
        setElementEditValues(ElementByIndex(properties, i), 'Value 1', IntToHex(newKeywordFormID, 8)); 
      end;
    end;
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
var
  properties: IInterface;
  i: integer;
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

  result := getElementEditValues(getTargetWeaponForOMOD(omod), 'DNAM\AMMO');

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
  
  if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage1') OR containsText(editorID(omod), 'MoreDamage1') then
    result := 1
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage2') OR containsText(editorID(omod), 'MoreDamage2')  then
    result := 2
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage3')  OR containsText(editorID(omod), 'MoreDamage3') then
    result := 3
  else if omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage4')  OR containsText(editorID(omod), 'MoreDamage4') then
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
//=====
end.