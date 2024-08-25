unit LunarWeaponsPatcher;

uses 'lib\mxpf';
uses 'wtfLib\wtfLib_OMOD';
uses 'wtfLib\wtfLib_COBJ';

const	
  log = true;
    //Logging
  log_level = 3; //1=trace, 2=debug, 3=info, 4=warn, 5=error
  disableNonStandardRecievers = true;
    
var
  masterFiles: array[0..5] of IInterface;
  science, gunnut: Array[0..5] of String;

//============================================================================  
  function Initialize: integer;
var
  i: integer;
  f: IInterface;
  rec : tsearchrec;
  slMasters: TStringList;
begin

  gunnut[0] := 'GunNut01';
  gunnut[1] := 'GunNut01';
  gunnut[2] := 'GunNut02';
  gunnut[3] := 'GunNut03';
  gunnut[4] := 'GunNut04';
  gunnut[5] := 'GunNut05';

  science[0] := 'Science01';
  science[1] := 'Science01';
  science[2] := 'Science02';
  science[3] := 'Science03';
  science[4] := 'Science04';
  science[5] := 'Science05';
    
  for i := 0 to Pred(FileCount) do begin
		f := FileByIndex(i);
		// locate master files - This is required only for master files that contain new perk records we're using as requirements
		if SameText(GetFileName(f), 'Fallout4.esm') then masterFiles[0] := f;
    if SameText(GetFileName(f), 'DLCCoast.esm') then masterFiles[1] := f;
    if SameText(GetFileName(f), 'DLCNukaWorld.esm') then masterFiles[2] := f;
    if SameText(GetFileName(f), 'LunarFalloutOverhaul.esp') then masterFiles[3] := f;
	end;


  //Create a TList of TStringlists of the files in WeapCmpo
  
  //Run the MXPF Patcher
  patchMXPF();
	
end;
  
  //============================================================================
function patchMXPF: integer;
var
  i, omodIndex: integer;
  e, slMasters, cnam, mnam: IInterface;
  edid, ap, misc: string;

begin
  // set MXPF options and initialize it
  DefaultOptionsMXPF;
  InitializeMXPF;
  
  // select/create a new patch file that will be identified by its author field
  PatchFileByAuthor('Lunar Weapon Patcher');
  SetExclusions('Fallout4.esm,DLCCoast.esm,DLCRobot.esm,DLCNukaWorld.esm,DLCWorkshop01.esm,DLCWorkshop02.esm,DLCWorkshop03.esm,LunarFalloutOverhaul.esp,Unofficial Fallout 4 Patch.esp');
    
    slMasters := TStringList.Create;
    slMasters.Add('LunarFalloutOverhaul.esp');
    AddMastersToFile(mxPatchFile, slMasters, False);
    
  
  //Load Records
  LoadRecords('COBJ');
  LoadRecords('OMOD');
  LoadRecords('WEAP');
  
  //Iterate Records
  for i := MaxRecordIndex downto 0 do begin
    e := GetRecord(i);
      if ContainsText(editorID(e), 'Binoculars') then removeRecord(i)
      else if ContainsText(editorID(e), 'Camera') then removeRecord(i)
      else if ContainsText(editorID(e), 'LeaderCard') then removeRecord(i)
      else if ContainsText(editorID(e), '2x2') then removeRecord(i)
      else if ContainsText(editorID(e), 'HQRoom') then removeRecord(i)
      else if ContainsText(editorID(e), 'SS2_Skin') then removeRecord(i)
      else if ContainsText(editorID(e), 'Plan') then removeRecord(i)
      else if ContainsText(editorID(e), '[SS2') then removeRecord(i)
      else if Signature(e) = 'COBJ' then begin
        cnam := LinksTo(ElementBySignature(e, 'CNAM'));
        ap := getElementEditValues(cnam, 'DATA\Attach Point');
        misc := getElementEditValues(cnam, 'LNAM');

        if ContainsText(EditorID(e), '_PA_') then RemoveRecord(i)
        //else if NOT ContainsText(EditorID(e), 'co_mod') then RemoveRecord(i)
        else if ContainsText(EditorID(e), 'mod_armor_') then RemoveRecord(i)
        else if ContainsText(EditorID(e), 'Workshop') then RemoveRecord(i)
        else if ContainsText(EditorID(e), 'melee') then RemoveRecord(i)
        //else if not assigned(cnam) then begin
        else if misc= '' then RemoveRecord(i)
        else if containsText(EditorID(cnam), 'co_DLC01Bot') then RemoveRecord(i)
        else if containsText(ap, 'melee') then RemoveRecord(i)
        else if containsText(ap, 'ap_bot') then RemoveRecord(i)
        else if containsText(ap, 'ap_DLC01Bot') then RemoveRecord(i)
        else if containsText(ap, 'ma_Template') then RemoveRecord(i);
      end
      else if Signature(e) = 'OMOD' then begin
        if not isModcol(e) then RemoveRecord(i);
      end
      else if Signature(e) = 'WEAP' then begin
        if getElementEditValues(e, 'DNAM\AMMO') = '' then removeRecord(i);
      end;
        
  end;
  
  // then copy records to the patch file
  CopyRecordsToPatch;
  
  if log then addMessage(IntToStr(MaxPatchRecordIndex) + ' Records copied to patch');

  //Process the MODCOLS
  for i := 0 to MaxPatchRecordIndex do begin
    e := GetPatchRecord(i);
    if (Signature(e) = 'OMOD') then 
        if isModcol(e) then ProcessModcol(e);
  end;

    for i := 0 to MaxPatchRecordIndex do begin
    e := GetPatchRecord(i);
    if (Signature(e) = 'OMOD') then 
        if not isModcol(e) then ProcessOmod(e);
  end;

  //Process the COBJs
  for i := 0 to MaxPatchRecordIndex do begin
    e := GetPatchRecord(i);
    if Signature(e) = 'COBJ' then ProcessCOBJ(e);
  end;

    //Process the COBJs
  for i := 0 to MaxPatchRecordIndex do begin
    e := GetPatchRecord(i);
    if Signature(e) = 'WEAP' then ProcessWeapon(e);
  end;
  


  // call PrintMXPFReport for a report on successes and failures
  PrintMXPFReport;
  
  // always call FinalizeMXPF when done
  FinalizeMXPF;
  
end;

  
//============================================================================  

function ProcessCOBJ(cobj: IInterface): integer;
var
	misc, conditions, omod, component, components, eFVPA, upgrade, properties: IInterface;
	ap, mnam, old, new, componentToAssign, conditionName, omodName, miscName, degradationAP, perkChain: String;
	i, j, n, level, componentCount: integer;
  minRange, maxRange, damage: float;
  perksToAssign, wpnKwds, newConditions: TStringList; 
	 
begin

    if log then addMessage('-------------------------------Patching COBJ ' + getElementEditValues(cobj, 'EDID') + ', ' + IntToHex(GetLoadOrderFormID(cobj), 8) + ' -------------------------------');

    //getRankFromExisting condition
    level := getHighCondition(cobj); //decremented because lists have perk level 1 at index 0
    //if log then addMessage('Found level ' + IntToStr(level+1));
    perksToAssign := TStringList.create;   
    
    //only need to copy omod for receivers
    omod := winningOverride(LinksTo(ElementBySignature(cobj, 'CNAM')));
    omod := wbCopyElementToFile(omod, mxPatchFile, false, true);

    addMEssage('Found weap' + editorID(getTargetWeaponForOMOD(omod)));
    if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then addMEssage('Found keyword WeaponTypeBallistic');

    //always copy misc
    misc := winningOverride(LinksTo(ElementBySignature(omod, 'LNAM')));
    misc := wbCopyElementToFile(misc, mxPatchFile, false, true);

    mnam := CleanEdid(EditorID(LinksTo(ElementByIndex(ElementBySignature(omod, 'MNAM'), 0))));
    ap := CleanEdid(getElementEditValues(omod, 'DATA\Attach Point'));

    if log then addMessage('AP: ' + ap);
    if log then addMessage('MNAM: ' + mnam);
    
    if log then addMessage('CNAM: ' + EditorID(omod));
    if log then addMessage('LNAM: ' + EditorID(misc));
    
    omodName := getElementEditValues(omod, 'FULL');
    miscName := getElementEditValues(misc, 'FULL');

    if containsText(EditorID(omod), 'disable') then begin 
      AddMEssage('Disable found in EDID - Disabling OMOD');
      removeElement(cobj, 'CNAM');
      disableOMOD(omod);
      setElementEditValues(cobj, 'EDID', '_disabled_'+EditorID(cobj));
      exit;
    end;
   
    if ap = 'ap_gun_receiver' then begin
       if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then 
        if isNonStandardReceiver(omod) then begin
          removeElement(cobj, 'CNAM');
          setElementEditValues(cobj, 'EDID', '_disabled_'+EditorID(cobj));
          disableOMOD(omod);
          exit;
      end;
      
      //Correct for lunar laser naming conventions
      lunarLaserModNameFix(omod, getDamageLevel(omod));
      lunarLaserModNameFix(misc, getDamageLevel(omod));
      
      CheckForArmorPiercingAmmo(omod);
      
      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then begin
        if omodHasKeyword(omod, 'WeaponTypeAutomatic') then damage := -0.15 + (getDamageLevel(omod) * 0.2)
        else damage := getDamageLevel(omod) * 0.25;
        expectOmodPropertyValueRange(omod, 'AttackDamage', damage, damage);
      end
      else begin //Laser and other energy
        if omodHasKeyword(omod, 'WeaponTypeAutomatic') then damage := -0.15 + (getDamageLevel(omod) * 0.2)
        else damage := getDamageLevel(omod) * 0.25;
        expectOmodPropertyValueTwoRange(omod, 'DamageTypeValues', '00060A81', damage, damage);
      end;

      if not ContainsText(EditorID(omod), 'Railway') 
        AND not ContainsText(EditorID(omod), 'Critical')
        AND not ContainsText(EditorID(omod), 'Junkjet')
        AND not ContainsText(EditorID(omod), 'Flamer')
        AND not ContainsText(EditorID(omod), 'COA_RR')
        then CreateTierFourReceivers(omod, misc, cobj);

      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then 
        perksToAssign.add(gunnut[getModifiedDamageLevel(omod)]) 
      else
        perksToAssign.add(science[getModifiedDamageLevel(omod)]);

      cleanExistingConditions(cobj);
      assignNewConditions(cobj, perksToAssign);

    end
    else if ap = 'ap_gun_Barrel' then begin

      level := 1;
      if omodHasKeyword(omod, 'dn_HasBarrel_Null') then level := 1
      else if omodHasKeyword(omod, 'dn_HasBarrel_Short') then level := 1
      else if omodHasKeyword(omod, 'dn_HasBarrel_Long') or ContainsText(omodName, 'Long') then level := 2
      else if omodHasKeyword(omod, 'dn_HasBarrelSuper') then level := 3
      else if omodHasKeyword(omod, 'dn_HasBarrel_Shotgun') then level := 2
      else if omodHasKeyword(omod, 'dn_HasBarrel_Flamer') then level := 3;
      
      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypePlasma') then level := level +1;
      if omodHasKeyword(omod, 'WeaponTypeAutomatic') then level := level + 1;
      if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then level := level + 1;
      if omodHasKeyword(omod, 'dn_HasBarrel_Ported') OR containsText(omodName, 'Ported') then level := level + 1;
      if omodHasKeyword(omod, 'dn_HasBarrel_Light') OR containsText(omodName, 'Light') then level := level + 1;
      if omodHasKeyword(omod, 'dn_HasBarrel_Finned') OR containsText(omodName, 'Finned') then level := level + 2;

      addMessage('Calculated level for barrel = ' + IntToStr(level));
      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then 
        perksToAssign.add(gunnut[level]) 
      else
        perksToAssign.add(science[level]);

      cleanExistingConditions(cobj);
      assignNewConditions(cobj, perksToAssign);

      addMessage('Examining barrel ' + EditorID(Omod));
      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then VerifyBallisticBarrels(omod, level)
      else if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeLaser') then VerifyLaserBarrels(omod, level, false)
      else if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypePlasma') then VerifyLaserBarrels(omod, level, true)
      else addMessage('Unrecognized weapon type while checking barrel OMOD');

    end
    else if ap = 'ap_gun_Scope' then begin     
      
      if omodHasKeyword(omod, 'dn_HasScope_ReflexSight ') then 
        if containsText(omodName, 'Glow') then perksToAssign.add('GunNut03') else perksToAssign.add('GunNut02') 
      else if containsText(EditorID(Omod), 'Short') then perksToAssign.add('GunNut01')
      else if containsText(EditorID(Omod), 'Medium') then perksToAssign.add('GunNut02')
      else if containsText(EditorID(Omod), 'Long') then perksToAssign.add('GunNut03')
      else if omodHasKeyword(omod, 'dn_HasScope_GlowSights ') OR containsText(omodName, 'Glow') then perksToAssign.add('GunNut01')
      else if omodHasKeyword(omod, 'dn_HasScope_IronSights') then removeRecipeComponents(cobj);
      
      if omodHasKeyword(omod, 'dn_HasScope_NightVision ') then perksToAssign.add('Science01');
      if omodHasKeyword(omod, 'HasScopeRecon ') then perksToAssign.add('Science03');
      cleanExistingConditions(cobj);
      assignNewConditions(cobj, perksToAssign);

    end
    else if ap = 'ap_gun_Muzzle' then begin
      
      if containsText(omodName, 'Bayonet') then begin
        if containsText(omodName, 'large') then setPerkCondition(cobj, 'Blacksmith02')
        else setPerkCondition(cobj, 'Blacksmith01');
      end;
      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') then begin
        if omodHasKeyword(omod, 'HasSilencer') then setPerkCondition(cobj, 'GunNut03')
        else if omodHasKeyword(omod, 'dn_HasMuzzle_MuzzleBreak') then setPerkCondition(cobj, 'GunNut02')
        else if omodHasKeyword(omod, 'dn_HasMuzzle_Compensator') then setPerkCondition(cobj, 'GunNut01')
      end
      else begin
        if omodHasKeyword(omod, 'HasSilencer') then setPerkCondition(cobj, 'Science03')
        else if omodHasKeyword(omod, 'dn_HasMuzzle_MuzzleBreak') then setPerkCondition(cobj, 'Science02')
        else if omodHasKeyword(omod, 'dn_HasMuzzle_Compensator') then setPerkCondition(cobj, 'Science01')
      end;
      
      if omodHasKeyword(omod, 'HasSilencer') then begin
          expectOmodPropertyValueRange(omod, 'AttackDamage', -0.05,-0.05);
          addMessage('Found silencer, nerfing damage');
      end;
    
      //Energy Weapon Splitters: less spread, more range, added "WeaponType_shotgun"
      if omodHasKeyword(omod, 'dn_HasMuzzleBeamSplitter') OR containsText(editorID(omod), 'Splitter') then begin
        expectOmodPropertyValueRange(omod, 'MinRange', -3, -5);
        expectOmodPropertyValueRange(omod, 'AmmoCapacity', -0.2, -0.2);
        expectOmodPropertyValueRange(omod, 'AimModelMinConeDegrees', 7-level, 7-level);
        expectOmodPropertyValueRange(omod, 'AimModelMaxConeDegrees', 7-level, 7-level);
        expectOmodPropertyValueRange(omod, 'AimModelRecoilMinDegPerShot', 1+level, 1+level);
        expectOmodPropertyValueRange(omod, 'NumProjectiles', 5, 5);
      end;
    end
    else if ap = 'ap_gun_Grip' then begin
      
      perksToAssign := TStringList.create;
      if omodHasKeyword(omod, 'dn_HasGrip_Recoil') then perksToAssign.add('GunNut03')
      else if omodHasKeyword(omod, 'dn_HasGrip_StockMarksmans') then perksToAssign.add('GunNut02')
      else if omodHasKeyword(omod, 'dn_HasGrip_Better2') then perksToAssign.add('GunNut03')
      else if omodHasKeyword(omod, 'dn_HasGrip_Better1') then perksToAssign.add('GunNut02')
      else perksToAssign.add('GunNut01');
      cleanExistingConditions(cobj);
      assignNewConditions(cobj, perksToAssign);

      if omodHasKeyword(omod, 'dn_HasGrip_Pistol') then 
        expectOmodPropertyValueRange(omod, 'Weight', 0.02, 0.035)
      else if omodHasKeyword(omod, 'dn_HasGrip_ShortStock') then 
        expectOmodPropertyValueRange(omod, 'Weight', 0.13, 0.17)
      else if omodHasKeyword(omod, 'dn_HasGrip_ShortStock') then 
        expectOmodPropertyValueRange(omod, 'Weight', 0.13, 0.17)
      else if omodHasKeyword(omod, 'dn_HasGrip_Rifle') then 
        expectOmodPropertyValueRange(omod, 'Weight', 0.3, 0.38);

      //Institute - stock 0.2 speed 
      if ContainsText(EditorID(omod), 'Institute') OR containsText(omodName, 'Institute') then
        expectOmodPropertyValueRange(omod, 'Speed', -0.2, -0.2);

    end
    else if ap = 'ap_gun_Mag' then begin

      perksToAssign := TStringList.create;
      
      if omodHasKeyword(omod, 'dn_HasMag_ExtraLarge') then begin
        level := 4;
        damage := StrToFloat(getPropertyValueOne(omod, 'Weight')) +0.1;
        if not isRecordLunarPatched(omod) then 
          expectOmodPropertyValueRange(omod, 'Weight', damage, damage);
      end
      else if omodHasKeyword(omod, 'dn_HasMag_Large') then level := 3
      else if omodHasKeyword(omod, 'dn_HasMag_Medium') then level := 2
      else if omodHasKeyword(omod, 'dn_HasMag_Small') then level := 1;
      addMEssage('Mag LEvel ' + IntToStr(level));
      if omodHasKeyword(omod, 'dn_HasMag_Quick') OR containsText(omodName, 'Quick') then level := level + 1;
      addMEssage('Mag LEvel quick' + IntToStr(level));
      if level = 1 then perksToAssign.add('GunNut01')
      else if level = 2 then perksToAssign.add('GunNut02')
      else if level = 3 then perksToAssign.add('GunNut03')
      else if level = 4 then perksToAssign.add('GunNut04')
      else if level = 5 then perksToAssign.add('GunNut05');

      cleanExistingConditions(cobj);
      assignNewConditions(cobj, perksToAssign);
    end
    else begin
      AddMessage('Unrecognized attachment point: ' + ap);
      if not isRecordLunarPatched(cobj) then increasePerkReqs(cobj);
    end;


    
end;
  
//============================================================================  

function ProcessModcol(modcol: IInterface): integer;
var
  listMods, omod: IInterface;
  i: integer;
begin
  
    if log then addMessage('-------------------------------Patching MODCOL ' + getElementEditValues(modcol, 'EDID') + '-------------------------------');
    
    listmods := ElementByPath(modcol, 'DATA\Includes');
    for i := 0 to ElementCount(listMods)-1 do begin
      omod := LinksTo(ElementByPath(ElementByIndex(listMods, i), 'Mod'));
      addmessage('Examining ' + EditorID(omod));
      if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeBallistic') AND isNonStandardReceiver(omod) then begin
        addMessage('Removing ' + EditorID(omod));
        removeByIndex(listMods, i, true);
      end;
    end ;

    sortModcolByLevel(modcol);

    if isRecordLunarPatched(modcol) then addMessage('Modcol already patched ' + EditorID(modcol))
    else begin   
        doubleModcolMinLevels(modcol);
    end;
end;
//============================================================================  

function ProcessWeapon(weap: IInterface): integer;
	 var
    temp: IInterface;
    ammo: String;
    factor : float;
begin

    if log then addMessage('-------------------------------Patching Weapon ' + getElementEditValues(weap, 'EDID') + '-------------------------------');

      ammo:= getElementEditValues(weap, 'DNAM\AMMO');
      addMessage('Found ammo type ' + ammo);

      factor := 1;
      if containsText(getElementEditValues(weap, 'FULL'), 'Institute') then factor := 1.05;
      if containsText(getElementEditValues(weap, 'FULL'), 'Pipe') then factor := 0.95;

      if ContainsText(ammo, '.38') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(19 * factor))
      else if ContainsText(ammo, 'shotgun') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(62 * factor))
      else if ContainsText(ammo, '10mm') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(27 * factor))
      else if ContainsText(ammo, '-70') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(80 * factor))
      else if ContainsText(ammo, '.45') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(40 * factor))
      else if ContainsText(ammo, '.44') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(70 * factor))
      else if ContainsText(ammo, '.50') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(160 * factor))
      else if ContainsText(ammo, '5mm') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(15 * factor))
      else if ContainsText(ammo, '5.56') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(52 * factor))
      else if ContainsText(ammo, '7.62') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(52 * factor))
      else if ContainsText(ammo, '2mm') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(180 * factor))
      else if ContainsText(ammo, '308') then setElementEditValues(weap, 'DNAM\Damage - Base', Round(64 * factor))
      else if ContainsText(ammo, 'fusion') then setElementEditValues(ElementByIndex(ElementByPath(weap, 'DAMA - Damage Types'), 0), 'Amount', Round(32 * factor))
      else if ContainsText(ammo, 'plasma') then begin
        setElementEditValues(ElementByIndex(ElementByPath(weap, 'DAMA - Damage Types'), 0), 'Amount', Round(40 * factor));
        setElementEditValues(weap, 'DNAM\Damage - Base', Round(25 * factor));
      end
      else addMessage('**WARNING** Weapon damage needs to be adjusted manually');
      

      //else if ContainsText(ammo, 'gamma') then damage := 19
      //else if ContainsText(ammo, 'Alien') then damage := 33

end;

//============================================================================  
function lunarLaserModNameFix(omod: String; level: integer): IInterface;
var
  conds: IInterface;
  i: integer;
  edid: string;
begin
  if (level = 2) AND containsText(getElementEditValues(omod, 'FULL'), 'Maximized') then begin
    addMessage(EditorID(omod) + ' Tier 2: Maximized --> Optimised');
    setElementEditValues(omod, 'FULL', StringReplace(getElementEditValues(omod, 'FULL'), 'Maximized', 'Optimized', [rfReplaceAll, rfIgnoreCase]));
  end;
  
  if (level=3) AND containsText(getElementEditValues(omod, 'FULL'), 'Overcharged') then begin
    setElementEditValues(omod, 'FULL', StringReplace(getElementEditValues(omod, 'FULL'), 'Overcharged', 'Maximized', [rfReplaceAll, rfIgnoreCase]));
    addMessage(EditorID(omod) + ' tier 3 : Overcharged --> Maximized');
  end;

end;

//============================================================================  
function cleanEDID(str: String): String;
begin
  result := str;
  if pos('[', result) > 0 then result := copy(result, 1, pos('[', result)-2);
  if pos('"', result) > 0 then result := copy(result, 1, pos('"', result)-2);
end;

//============================================================================  

function isRecordLunarPatched(rec: IInterface): boolean;
var
  i: Integer;
  fname: String;

begin
  result := false;
  rec := MasterOrSelf(rec);
  for i := OverrideCount(rec)-1 downTo 0 do begin
    fname := GetFileName(GetFile(OverrideByIndex(rec, i)));
    if containsText(fname, 'Lunar') 
    or containsText(fname, 'lunar')
    or SameText(fname, 'Fallout4.esm')
    or SameText(fname, 'DLCCoast.esm')
    or SameText(fname, 'DLCNukaWorld.esp') then begin
        addMessage('Patch found');
        result := true;
        exit;
    end;
  end;

end;

//============================================================================  

function CreateTierFourReceivers(omod, misc, cobj: IInterface): boolean;
var
  i: Integer;
  fname: String;

begin
  if omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing1') 
  or omodHasKeyword(omod, 'dn_HasReceiver_ArmorPiercing2') 
  or omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals1') 
  or omodHasKeyword(omod, 'dn_HasReceiver_BetterCriticals2')
  or containsText(EditorID(omod), 'ArmorPiercing') 
  or containsText(EditorID(omod), 'BetterCrit')
  then exit;
  

  if omodHasKeyword(omod, 'dn_HasReceiver_Automatic') then begin
    addMessage('Found automatic receiver');
    if not (omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage3') or containsText(EditorID(omod), 'MoreDamage3')) then begin
      addMessage('Found automatic receiver');
      if not Assigned(getDamageOffsetOmod(omod, 1)) then begin
          addMessage('Missing automatic receiver upgrade');
          processCobj(createUpgrade(omod, misc, cobj))
      end;
    end;
  end
  else if not (omodHasKeyword(omod, 'dn_HasReceiver_MoreDamage4') or containsText(EditorID(omod), 'MoreDamage4')) then begin
    addMessage('Found non-automatic receiver');
    if not Assigned(getDamageOffsetOmod(omod, 1)) then begin
      addMessage('Non-Automatic receiver upgrade missing missing');
      processCobj(createUpgrade(omod, misc, cobj));
    end;
  end;
end;
//============================================================================  

function CheckForArmorPiercingAmmo(omod: IInterface): boolean;
var
  properties: IInterface;
  i: Integer;
  ammo: String;
  hasEnchantment, hasActorValue: Boolean;

begin
    if log then AddMessage('Checking for armor piercing ammo type');
    ammo := getAmmo(omod);
    if containsText(ammo, '.50 ')
    or containsText(ammo, '.45 ')
    or containsText(ammo, '.44 ')
    or containsText(ammo, '5mm ')
    or containsText(ammo, '2mm ') then begin

      if log then AddMessage('Armor piercing ammo tyoe found: ' + ammo);
    
      hasEnchantment := false;
      hasActorValue := false;
      
      properties := ElementByPath(omod, 'DATA\Properties');
      for i := 0 to ElementCount(properties)-1 do
      if getElementEditValues(ElementByIndex(properties, i), 'Property') = 'Enchantments' then begin
        if containsText(getElementEditValues(ElementByIndex(properties, i), 'Value 1'), 'enchModArmorPenetration') then 
          hasEnchantment := true;
      end
      else if getElementEditValues(ElementByIndex(properties, i), 'Property') = 'ActorValues' then begin
        if containsText(getElementEditValues(ElementByIndex(properties, i), 'Value 1'), 'ArmorPenetration') then 
            hasActorValue := true;
      end;

      if hasEnchantment then addMessage('Found armor piercing enchantment')
      else addPropertyToOmod(omod, 'FormID,Int', 'ADD', 'Enchantments','001F4425', '1');
      
      if (hasActorValue = false) then
        addPropertyToOmod(omod, 'FormID,Float', 'ADD', 'ActorValues','00097341', '40');

    end;
end;
//============================================================================  

function VerifyBallisticBarrels(omod: IInterface; level: Integer): boolean;
var
  minRange, maxRange, damage: float;
  omodName: String;

begin
  omodName := getElementEditValues(omod, 'FULL');
  addMessage('Verifying ballistic barrel properties');

  if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeShotgun') then begin
    maxRange := 6;
    //if omodHasKeyword(omod, 'dn_HasBarrel_Null')
    if omodHasKeyword(omod, 'dn_HasBarrel_Short') or ContainsText(omodName, 'Short') then maxRange := maxRange + 2
    else if omodHasKeyword(omod, 'dn_HasBarrel_Long') or ContainsText(omodName, 'Long') then maxRange := maxRange + 6;
    minRange := (maxRange/2);
  end
  else if hasKeyword(getTargetWeaponForOMOD(omod), 'WeaponTypeRifle') then begin
    maxRange := 12;
    if containsText(omodName, 'Machine') then maxRange := maxRange - 3;
    if omodHasKeyword(omod, 'dn_HasBarrel_Short') or ContainsText(omodName, 'Short') then maxRange := maxRange + 2;
    if omodHasKeyword(omod, 'dn_HasBarrel_Long') or ContainsText(omodName, 'Long') then maxRange := maxRange + 5;
    minRange := maxRange * 0.65;
  end
  else begin //Pistols, and "other" ballistics
    maxRange := 6;
    if omodHasKeyword(omod, 'dn_HasBarrel_Short') or ContainsText(omodName, 'Short') then maxRange := maxRange + 1;
    if omodHasKeyword(omod, 'dn_HasBarrel_Long') or ContainsText(omodName, 'Long') then maxRange := maxRange + 5;
    if omodHasKeyword(omod, 'dn_HasBarrel_Null') then maxRange := 5;
    minRange := maxRange * 0.8;
  end;

  if containsText(getElementEditValues(getTargetWeaponForOMOD(omod), 'FULL'), 'Institute') then begin
    maxRange := maxRange + 2;
    minRange := minRange + 1;
  end
  else if containsText(getElementEditValues(getTargetWeaponForOMOD(omod), 'FULL'), 'Pipe') then begin
    maxRange := maxRange - 1;
    minRange := minRange - 1;
  end;

  expectOmodPropertyValueRange(omod, 'MinRange', minRange, minRange);
  expectOmodPropertyValueRange(omod, 'MaxRange', maxRange, maxRange);
end;

//============================================================================  

function VerifyLaserBarrels(omod: IInterface; level: Integer; isPlasma:boolean): boolean;
var
  minRange, maxRange, damage: float;
  omodName: String;

begin
  omodName := getElementEditValues(omod, 'FULL');
  addMessage('Verifying Laser/plasma barrel properties');

  if omodHasKeyword(omod, 'WeaponTypeAutomatic') then begin 
    if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then begin
      addMessage('Found automatic Improved barrel');
      maxRange := 12;
      maxRange := maxRange + level;
      minRange := maxRange * 0.75;
      damage := 0.05;
    end
    else begin
      addMessage('Found automatic barrel');
      maxRange := 10;
      maxRange := maxRange + level;
      minRange := maxRange * 0.75;
      damage := -0.15;
    end;
  end
  else if omodHasKeyword(omod, 'dn_HasBarrelSuper') OR containsText(omodName, 'Sniper') then begin
    if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then begin
      addMessage('Found sniper Improved barrel');
      maxRange := 15;
      maxRange := maxRange + level;
      minRange := maxRange * 0.65;
      if isPlasma then damage := 0.45 else damage := 1.25;
    end
    else begin
      addMessage('Found sniper barrel');
      maxRange := 16;
      maxRange := maxRange + level;
      minRange := maxRange * 0.65;
      if isPlasma then damage := 0.2 else damage := 0.75;
    end;
  end
  else if omodHasKeyword(omod, 'dn_HasBarrel_Shotgun') OR containsText(omodName, 'Splitter') then begin
    if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then begin
      addMessage('Found splitter Improved barrel');
      maxRange := 7;
      maxRange := maxRange + level;
      minRange := maxRange/2;
      damage := 0.35;
    end
    else begin
      addMessage('Found splitter barrel');
      maxRange := 7;
      maxRange := maxRange + level;
      minRange := maxRange * 0.75;
      damage := 0.3;
    end;
  end
  else if omodHasKeyword(omod, 'dn_HasBarrel_Long') OR containsText(omodName, 'Long') then begin
    if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then begin
      addMessage('Found Long Improved barrel');
      maxRange := 14;
      maxRange := maxRange + level;
      minRange := maxRange * 0.65;
      damage := 0.4;
    end
    else begin
      addMessage('Found Long barrel');
      maxRange := 13;
      maxRange := maxRange + level;
      minRange := maxRange * 0.65;
      damage := 0.1;
    end;
  end
  else if omodHasKeyword(omod, 'dn_HasBarrel_Null') then begin
    if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then begin
      addMessage('Found Null Improved barrel');
      maxRange := 5;
      maxRange := maxRange + level;
      minRange := maxRange * 0.8;
      damage := 0.21;
    end
    else begin
      addMessage('Found Null barrel');
      maxRange := 5;
      maxRange := maxRange + level;
      minRange := maxRange * 0.8;
      damage := 0;
    end;
  end
  else if omodHasKeyword(omod, 'dn_HasBarrel_Short') OR containsText(omodName, 'Short') then begin
    if omodHasKeyword(omod, 'dn_HasBarrel_Improved') OR containsText(omodName, 'Improved') then begin
      addMessage('Found short Improved barrel');
      maxRange := 6;
      maxRange := maxRange + level;
      minRange := maxRange * 0.8;
      damage := 0.21;
    end
    else begin
      addMessage('Found short barrel');
      maxRange := 5;
      maxRange := maxRange + level;
      minRange := maxRange * 0.8;
      damage := 0;
    end;
  end;
    
  expectOmodPropertyValueRange(omod, 'MinRange', minRange-1, minRange+1);
  expectOmodPropertyValueRange(omod, 'MaxRange', maxRange-1, maxRange+1);
  expectOmodPropertyValueTwoRange(omod, 'DamageTypeValues', '00060A81', damage, damage);
end;

//=====
end.
    
    
