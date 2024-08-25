unit wtfLib_logging;

//============================================================================  
// log
function logg(msg_level: integer; msg: string): int;
var
  prefix: string;

begin
    if msg_level = 1 then prefix := 'TRACE: '
    else if msg_level = 2 then prefix := 'DEBUG: '
    else if msg_level = 3 then prefix := 'INFO: '
    else if msg_level = 4 then prefix := 'WARN: '
    else if msg_level = 5 then prefix := 'ERROR: ';

    if log_level <= msg_level then addMessage(prefix + msg);
    
end;

end.