unit wtfLib_COBJ;

uses 'wtfLib\wtfLib_logging';
uses 'wtfLib\wtfLib_GLOB';

//============================================================================  
// Get condition level
function getHighCondition(r: IInterface): int;
var
  conds: IInterface;
  i: integer;
  edid: string;
begin
  result := 0;
  conds := ElementByName(r, 'Conditions');
  for i := 0 to Pred(ElementCount(conds)) do begin 
    edid := getElementEditValues(ElementByIndex(conds, i), 'CTDA\Perk');
    if pos('[', edid) > 0 then edid := copy(edid, 1, pos('[', edid)-2);
    if pos('"', edid) > 0 then edid := copy(edid, 1, pos('"', edid)-2);
    
    if containsText(edid, '01') AND (1 > result) then result := 1;
    if containsText(edid, '02') AND (2 > result) then result := 2;
    if containsText(edid, '03') AND (3 > result) then result := 3;
    if containsText(edid, '04') AND (4 > result) then result := 4;
    if containsText(edid, '05') AND (5 > result) then result := 5;
  end;
  
end;

//============================================================================  

function addGlobalReqCondition(e: IInterface; edid: String): String;
var
  condition, conditions, ctda, global: IInterface;
  i: integer;
begin
  logg(2, 'Adding global condition: ' + edid);
  conditions := ElementByName(e, 'Conditions');
  if not Assigned(conditions) then begin
    conditions := Add(e, 'Conditions', true);
    condition := ElementByIndex(conditions, 0);
  end
  else condition := ElementAssign(conditions, HighInteger, nil, true);
  ctda := ElementBySignature(ElementByIndex(conditions, ElementCount(conditions)-1), 'CTDA');

  // Type is "Equal to"
  SetEditValue(ElementByName(ctda, 'Type'), '10000000');
  SetNativeValue(ElementByName(ctda, 'Comparison Value - Float'), 1.0);
  SetEditValue(ElementByName(ctda, 'Function'), 'GetGlobalValue');
  global := GetGlobal(edid);
  AddRequiredElementMasters(global, mxPatchFile, false);
  SetEditValue(ElementByName(ctda, 'Global'), IntToHex(GetLoadOrderFormID(global), 8));
  logg(3, 'Assigned ' + edid);
  
end;

//============================================================================  

function setPerkCondition(e: IInterface; perk: String): String;
var
  condition, conditions, ctda: IInterface;
  i: integer;
  list: TStringList;
begin
  AddMessage('Setting perk condition ' + perk);
  list := TStringList.create;
  list.add(perk);
  cleanExistingConditions(e);
  assignNewConditions(e, list);

end;

//============================================================================  

function assignNewConditions(e: IInterface; perksToAssign: TStringList): String;
var
  condition, conditions, ctda, perk: IInterface;
  i: integer;
begin
  cleanExistingConditions(e);
  conditions := ElementByName(e, 'Conditions');
  while perksToAssign.Count > 0 do begin       
    if not Assigned(conditions) then begin
      conditions := Add(e, 'Conditions', true);
      condition := ElementByIndex(conditions, 0);
    end
    else condition  := ElementAssign(conditions, HighInteger, nil, true);
    ctda       := ElementBySignature(ElementByIndex(conditions, ElementCount(conditions)-1), 'CTDA');

    // Type is "Equal to"
    SetEditValue(ElementByName(ctda, 'Type'), '10000000');
    SetNativeValue(ElementByName(ctda, 'Comparison Value - Float'), 1.0);
    SetEditValue(ElementByName(ctda, 'Function'), 'HasPerk');
    perk := getPerk(perksToAssign[0]);
    AddRequiredElementMasters(perk, mxPatchFile, false);
    SetEditValue(ElementByName(ctda, 'Perk'), IntToHex(GetLoadOrderFormID(perk), 8));
    logg(2, 'Assigned ' + perksToAssign[0]);
    perksToAssign.delete(0);
  end;
end;

//============================================================================  

function cleanExistingConditions(e: IInterface): String;
var
  conditions: IInterface;
  i: integer;
begin
  conditions := ElementByName(e, 'Conditions');
  for i := ElementCount(conditions)-1 downto 0 do begin 
    if getElementEditValues(ElementByIndex(conditions, i), 'CTDA\Perk') = '' then begin 
      logg(2, 'Leaving non-perk condition on '+ getElementEditValues(e, 'EDID'));
    end
    else begin 
      remove(ElementByIndex(conditions, i));
    end;
  end;
end;
//============================================================================  

function increaseRecipeCounts(cobj: IInterface): String;
var
  WorkingComp, eFVPA: IInterface;
  i, oldCount: integer;
begin
  eFVPA := ElementByPath(cobj, 'FVPA - Components');
  for i := ElementCount(eFVPA)-1 downto 0 do begin
    WorkingComp := ElementByIndex(eFVPA, i);
    oldCount := StrToInt(GetEditValue(ElementByIndex(WorkingComp, 1)));
    setEditValue(ElementByIndex(WorkingComp, 1), oldCount+1);
  end;
end;

//============================================================================  

function increasePerkReqs(cobj: IInterface): String;
var
  conds, perk: IInterface;
  i: integer;
  edid: string;
  perksToAssign: TStringList;
begin
  AddMessage('Increasing perk requirements for COBJ');
  if getHighCondition(cobj) > 0 then begin
    conds := ElementByName(cobj, 'Conditions');
      for i := 0 to Pred(ElementCount(conds)) do begin 
        edid := getElementEditValues(ElementByIndex(conds, i), 'CTDA\Perk');
        if pos('[', edid) > 0 then edid := copy(edid, 1, pos('[', edid)-2);
        if pos('"', edid) > 0 then edid := copy(edid, 1, pos('"', edid)-2);
      
        edid := StringReplace(edid, '4', '5', [rfReplaceAll, rfIgnoreCase]);
        edid := StringReplace(edid, '3', '4', [rfReplaceAll, rfIgnoreCase]);
        edid := StringReplace(edid, '2', '3', [rfReplaceAll, rfIgnoreCase]);
        edid := StringReplace(edid, '1', '2', [rfReplaceAll, rfIgnoreCase]);
        
        perk := GetPerk(edid);
        if (perk <> 0) then 
          setElementEditValues(
              ElementByIndex(conds, i), 'CTDA\Perk', 
                IntToHex(GetLoadOrderFormID(perk), 8));
      end;
  end
  else begin
    AddMessage('No requirements found for COBJ- assigning rank 1');
    perksToAssign := TStringList.create;
    if hasKeyword(getTargetWeaponForOMOD(winningOverride(LinksTo(ElementBySignature(cobj, 'CNAM')))), 'WeaponTypeBallistic') then
      perksToAssign.add('GunNut01')
    else
      perksToAssign.add('Science01');
    assignNewConditions(cobj, perksToAssign);
  end;

end;
//============================================================================  

function swapPerkReqs(cobj: IInterface; oldPerk, newPerk:String): String;
var
  conds, perk: IInterface;
  i: integer;
  edid: string;
  perksToAssign: TStringList;
begin
  
  conds := ElementByName(cobj, 'Conditions');
  if assigned(conds) then for i := 0 to Pred(ElementCount(conds)) do begin 
    
    edid := EditorId(linksTo(ElementByPath(ElementByIndex(conds, i), 'CTDA\Perk')));
    if containsText(edid, oldPerk) then begin
      logg(2, 'Swapping perk req "' +  oldPerk + '" for "' + newPerk + '"');
      edid := StringReplace(edid, oldPerk, newPerk, [rfReplaceAll, rfIgnoreCase]);

      perk := GetPerk(edid);
      if assigned(perk) then setElementEditValues(ElementByIndex(conds, i), 'CTDA\Perk', IntToHex(GetLoadOrderFormID(perk), 8))
      else logg(5, 'Failed to swap perk requirements');
    end;
  end;

end;

//============================================================================  

function GetPerk(edid: string): IInterface;
var
  i: integer;
begin
  logg(2, 'Getting load order formID for perk ' + edid);
    
  //Swap for true perks, science 01 change out to robotics expert
  if (edid = 'Science01') and assigned(masterFiles[3]) then begin 
    logg(2, 'True Perks present, swapping Science01 for RoboticsExpert01');
    result := MainRecordByEditorID(GroupBySignature(masterFiles[0], 'PERK'), 'RoboticsExpert01');
    if assigned(result) then exit;
  end
  //if True perks installed, grab blacksmith04 from it, NOT lunar
  else if (edid = 'Blacksmith04') and assigned(masterFiles[3]) then begin 
    logg(2, 'True Perks present, Getting Blacksmith04 from TruePerks');
    result := MainRecordByEditorID(GroupBySignature(masterFiles[3], 'PERK'), 'Blacksmith04');
    if assigned(result) then exit;
  end
  else for i := 0 to (Length(masterFiles) - 1) do begin
    result := MainRecordByEditorID(GroupBySignature(masterFiles[i], 'PERK'), edid);
    if assigned(result) then exit;
  end;
  logg(5, 'Get Perk: masterfile not found for: ' + edid);

end;

//============================================================================  

function assignCmpo(cobj: IInterface; edid: string; count: integer): IInterface;
var
  i: integer;
  cmpo, components : IInterface;
begin
  cmpo := MainRecordByEditorID(GroupBySignature(masterFiles[5], 'CMPO'), edid);
  if not Assigned(cmpo) then raise Exception.Create('**ERROR** Failed to find CMPO od for ' + edid);

  components := ElementAssign(ElementByPath(cobj, 'FVPA - Components'), HighInteger, nil, true);
  SetEditValue(ElementByName(components, 'Component'), IntToHex(GetLoadOrderFormID(cmpo), 8));
  SetEditValue(ElementByName(components, 'Count'), count);
 
end;

//============================================================================  

function assignModdedItemKeywordCondition(cobj: IInterface; keyword: string; hasKeyword = true, isAND = true: Boolean): IInterface;
var
  i: integer;
  condition, conditions, ctda, rec: IInterface;
begin
    conditions := ElementByName(cobj, 'Conditions');
    if not Assigned(conditions) then begin
      conditions := Add(cobj, 'Conditions', true);
      condition := ElementByIndex(conditions, 0);
    end
    else condition  := ElementAssign(conditions, HighInteger, nil, true);
    ctda       := ElementBySignature(ElementByIndex(conditions, ElementCount(conditions)-1), 'CTDA');

    // Type is "Equal to"
    if isAND then SetEditValue(ElementByName(ctda, 'Type'), '10000000')
    else SetEditValue(ElementByName(ctda, 'Type'), '10010000');
    
    if hasKeyword then SetNativeValue(ElementByName(ctda, 'Comparison Value - Float'), 1.0)
    else SetNativeValue(ElementByName(ctda, 'Comparison Value - Float'), 0.0);
    
    SetEditValue(ElementByName(ctda, 'Function'), 'ModdedItemHasKeyword');
    
    rec := GetKeyword(keyword);
    AddRequiredElementMasters(rec, mxPatchFile, false);
    SetEditValue(ElementByName(ctda, 'Keyword'), IntToHex(GetLoadOrderFormID(rec), 8));
  end;

//============================================================================  

function GetKeyword(edid: string): IInterface;
var
  i: integer;
begin
  for i := 0 to (Length(masterFiles) - 1) do begin
    result := MainRecordByEditorID(GroupBySignature(masterFiles[i], 'KYWD'), edid);
    if result <> 0 then exit;
  end;
  if not assigned(result) then raise Exception.Create('**ERROR**: Masterfile not found for: ' + edid);

end;
//----
end.