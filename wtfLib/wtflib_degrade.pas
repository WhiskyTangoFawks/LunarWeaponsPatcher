unit wtfLib_degrade;

//============================================================================  

function assignOmodDowngrade(omod: IInterface): String;
var
    mgef, ench, properties, downgradeOmodProperty, downgradeOmod, damagedOmodProperty, damagedOmod, newProperty : IInterface;
    damageLevel: integer;
  
begin
    downgradeOmod := getDamageOffsetOmod(omod, -1);
    if not Assigned(downgradeOmod) then begin
        if not (containsText(EditorId(omod), 'standard') OR containsText(EditorId(omod), 'automatic1')) then logg(5, 'Failed to find downgrade omod for ' + EditorID(omod));
        exit;
    end;
    damagedOmod := MainRecordByEditorID(GroupBySignature(masterFiles[5], 'OMOD'), 'mod_Weapon_DegradedMoreDamage' + IntToStr(getDamageLevel(omod)));
    if not Assigned(damagedOmod) then raise Exception.Create('**ERROR** Failed to find damaged omod for: ' + 'mod_Weapon_DegradedMoreDamage' + IntToStr(getDamageLevel(omod)));

    //get the template, copy and rename
    mgef := MainRecordByEditorID(GroupBySignature(masterFiles[5], 'MGEF'), 'template_DegradeOmod');
    AddRequiredElementMasters(mgef, mxPatchFile, false);
    mgef := wbCopyElementToFile(mgef, mxPatchFile, true, true);
    SetElementEditValues(mgef, 'EDID', getElementEditValues(omod, 'EDID') + '_downgradeMGEF');
      
    //assign script mgef properties
    properties := ElementByPath(ElementByindex(ElementByPath(mgef, 'VMAD\Scripts'), 0), 'Properties');
    downgradeOmodProperty := ElementByIndex(Properties, 1);
    //brokenOmod := ElementByPath(downgradeOmodProperty, 'Value\Object Union\Object V2\FormID');
    AddRequiredElementMasters(downgradeOmod, mxPatchFile, false);
    SetElementEditValues(downgradeOmodProperty, 'Value\Object Union\Object V2\FormID', IntToHex(GetLoadOrderFormID(downgradeOmod) , 8));
    AddRequiredElementMasters(damagedOmod, mxPatchFile, false);
    damagedOmodProperty := ElementByIndex(Properties, 3);
    SetElementEditValues(damagedOmodProperty, 'Value\Object Union\Object V2\FormID', IntToHex(GetLoadOrderFormID(damagedOmod) , 8));
    
    //copy ench
    ench := MainRecordByEditorID(GroupBySignature(masterFiles[5], 'ENCH'), 'ench_Template_DowngradeReceiver');
    AddRequiredElementMasters(ench, mxPatchFile, false);
    ench := wbCopyElementToFile(ench, mxPatchFile, true, true);
    SetElementEditValues(ench, 'EDID', 'ench_downgradeReceiver_' + getElementEditValues(omod, 'EDID'));

    //assign mgef to ench
    SetElementEditValues(ElementByIndex(ElementByPath(ench, 'Effects'), 0), 'EFID', IntToHex(GetLoadOrderFormID(mgef) , 8));

    //assign ench to omod
    properties := ElementByPath(omod, 'DATA\Properties');
    if not Assigned(properties) then addMessage('**ERROR** Unable so assign properties during ench assignment to omod');
    newProperty := ElementAssign(properties, HighInteger, nil, False);
    if not Assigned(newProperty) then addMessage('**ERROR** Failed to add new property during ench assignment to omod');
    SetElementEditValues(newProperty, 'Value Type', 'FormID,Int');
    SetElementEditValues(newProperty, 'Function Type', 'ADD');
    SetElementEditValues(newProperty, 'Property', 'Enchantments');
    SetElementEditValues(newProperty, 'Value 1 - FormID', IntToHex(GetLoadOrderFormID(ench) , 8));

end;
//============================================================================  
function cleanRecipe(cobj: IInterface; screwRatio, adhesiveRatio, oilRatio, commonRatio, uncommonRatio, RareRatio: float): String;
var
  WorkingComp, eFVPA, cmpo: IInterface;
  i, oldCount, newCount: integer;
  rarity: String;
begin
    eFVPA := ElementByPath(cobj, 'FVPA - Components');
    for i := ElementCount(eFVPA)-1 downto 0 do begin
        WorkingComp := ElementByIndex(eFVPA, i);
        oldCount := StrToInt(GetEditValue(ElementByIndex(WorkingComp, 1)));
        cmpo := LinksTo(ElementByIndex(WorkingComp, 0));
        rarity := getElementEditValues(cmpo, 'GNAM');
        
        if containsText(EditorID(cmpo), 'adhesive') then setEditValue(ElementByIndex(WorkingComp, 1), Round(oldCount * adhesiveRatio))
        else if containsText(EditorId(cmpo), 'screw') then setEditValue(ElementByIndex(WorkingComp, 1), Round(oldCount * screwRatio))
        else if containsText(EditorId(cmpo), 'oil') then setEditValue(ElementByIndex(WorkingComp, 1), Round(oldCount * oilRatio))
        else if containsText(rarity, 'rare') then setEditValue(ElementByIndex(WorkingComp, 1), Round(oldCount * RareRatio))
        else if containsText(rarity, 'uncommon') then setEditValue(ElementByIndex(WorkingComp, 1), Round(oldCount * uncommonRatio))
        else if containsText(rarity, 'common') then setEditValue(ElementByIndex(WorkingComp, 1), Round(oldCount * commonRatio))
        else setEditValue(ElementByIndex(WorkingComp, 1), 0);

        newCount := StrToInt(GetEditValue(ElementByIndex(WorkingComp, 1)));
        if (newCount = 0) then remove(WorkingComp);
    end;
end;
//============================================================================  
function hasGripStockSwap(omod: IINterface): Boolean;
var
    mnam, omodRef, weap: IInterface;
    hasPistol, hasRifle: Boolean;
    i: integer;
begin
    mnam := LinksTo(ElementByIndex(ElementBySignature(omod, 'MNAM'), 0));
    hasPistol := false;
    hasRifle := false;

    weap := getTargetWeaponForOMOD(omod);
    if hasKeyword(weap, 'WeaponTypeRifle') then exit;
    if hasKeyword(weap, 'WeaponTypePistol') then exit;

    for i := 0 to ReferencedByCount(mnam)-1 do begin
        omodRef := ReferencedByIndex(mnam, i);
    
        if not isWinningOverride(omodRef) then continue;
        if (Signature(omodRef) <> 'OMOD') then continue;
        if isModcol(omodRef) then continue;
        
        if omodHasKeyword(omodRef, 'WeaponTypePistol') then hasPistol := true
        else if omodHasKeyword(omodRef, 'WeaponTypeRifle') then hasRifle := true;
    end;

    result := hasPistol AND hasRifle;
end;

end.