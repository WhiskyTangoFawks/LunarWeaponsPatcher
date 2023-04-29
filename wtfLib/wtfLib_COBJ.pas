unit wtfLib_COBJ;

//============================================================================  
// Get condition level
function getHighCondition(r: IInterface): int;
var
  conds: IInterface;
  i: integer;
  edid: string;
begin
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
  condition, conditions, ctda: IInterface;
  i: integer;
begin
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
    SetEditValue(ElementByName(ctda, 'Perk'), IntToHex(GetLoadOrderPerkFormId(perksToAssign[0]) , 8));
    if log then addMessage('Assigned ' + perksToAssign[0]);
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
  for i := ElementCount(conditions) downto 0 do begin 
    if getElementEditValues(ElementByIndex(conditions, i), 'CTDA\Perk') = '' then begin 
      if log then addMessage('Leaving non-perk condition on '+ getElementEditValues(e, 'EDID'));
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
  conds: IInterface;
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
        setElementEditValues(ElementByIndex(conds, i), 'CTDA\Perk', IntToHex(GetLoadOrderPerkFormId(edid), 8));
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

function GetLoadOrderPerkFormId(edid: string): Integer;
var
  i: integer;
begin
  if log then addMessage('Getting load order formID for ' + edid);
  for i := 0 to (Length(masterFiles) - 1) do begin
    result := GetLoadOrderFormID(MainRecordByEditorID(GroupBySignature(masterFiles[i], 'PERK'), edid));
    if result <> 0 then exit;
  end;
  addMessage('**ERROR**: Masterfile not found for: ' + edid);

end;
    
//----
end.