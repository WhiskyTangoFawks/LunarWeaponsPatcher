unit wtfLib_GLOB;

//============================================================================  
// log
function getGlobal(edid: string): IInterface;
var
  prefix: string;
  i: integer;

begin
  logg(1, 'Getting load order formID for ' + edid);
  for i := 0 to (Length(masterFiles) - 1) do begin
    result := MainRecordByEditorID(GroupBySignature(masterFiles[i], 'GLOB'), edid);
    if result <> 0 then exit;
  end;
  logg(5, '**ERROR**: Masterfile not found for: ' + edid);

    
end;

end.