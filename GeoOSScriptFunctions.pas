unit GeoOSScriptFunctions;
{
  Version 0.34
  Copyright 2012 Geodar
  https://github.com/Geodar/GeoOS_Script_Functions
}
interface
  uses
    Windows, SysUtils, Classes, shellapi, Zip, StrUtils, Registry
    {$IFDEF CONSOLE}, WinINet
    {$ELSE}, Dialogs, IdHTTP, IdAntiFreeze, IdComponent, Forms{$ENDIF};

  type TWinVersion = (wvUnknown, wvWin95, wvWin98, wvWin98SE, wvWinNT, wvWinME, wvWin2000, wvWinXP, wvWinVista);

  type functions = record
    public
    function GetWinVersion: TWinVersion; stdcall;
    function FreeAll(): boolean; stdcall;
    function DownloadFile(const url: string; const destinationFileName: string): boolean; stdcall;
    function GetParams(): string; stdcall;
    function LookUpForParams(): string; stdcall;
    function ReadCommand(str: string): string; overload; stdcall;
    function ReadCommand(str: string; lower: boolean): string; overload; stdcall;
    function CommandParams(str: string): string; overload; stdcall;
    function CommandParams(str: string; index: integer): string; overload; stdcall;
    function CommandParams(str: string; index: integer; commandindex: integer): string; overload; stdcall;
    function CheckDirAndDownloadFile(url: string; path: string): boolean; stdcall;
    function ReadAndDoCommands(line: string): boolean; stdcall;
    function TerminateMe(): boolean; stdcall;
    function LogAdd(messages: string): TStringList; stdcall;
    function ShowLog(): TStringList; stdcall;
    function init(): boolean; stdcall;
    function empty(str: string): boolean; stdcall;
    function GetLocalDir(): string; stdcall;
    function CheckVersionInOnlineStore(programname: string; currversion: string; beta: boolean): string; stdcall;
    function IsRemote(param: string): boolean; stdcall;
    function RunFile(scriptlocation: string): boolean; stdcall;
    function CheckAndRunFile(scriptlocation: string): boolean; stdcall;
    function SetProgramVersion(stringversion: string): boolean; stdcall;
    procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings);
  end;

  var
    ZipHandler:                      TZipFile;  // for accessing zip files
    CommandSplit1:                TStringList;  // for spliting of commands (main - what is command, and what are parameters)
    CommandSplit2:                TStringList;  // for spliting of commands (minor - if multiple parameters, split them too)
    Handle:                              HWND;  // some handle variable for shellapi
    _log:                         TStringList;  // holds information about scripts progress
    progversion:                       string;  // program version in string
    ifinfo:                            string;  // for ReadAndDoCommands
    ifmode:                          smallint;  // GOScript if
    reg:                            TRegistry;  // for accessing windows registry
    {$IFNDEF CONSOLE}
    fIDHTTP:          array [1..5] of TIDHTTP;  // max support for 5 downloads at time
    Stream:     array [1..5] of TMemoryStream;  // downloading streams
    idAntiFreeze:               TIdAntiFreeze;  // stop freezing application while downloading a file
    {$ENDIF}

implementation

{$IFNDEF CONSOLE}
uses Unit1;
{$ENDIF}

procedure functions.Split(Delimiter: Char; Str: string; ListOfStrings: TStrings); // Split what we need
//thanks to RRUZ - http://stackoverflow.com/questions/2625707/delphi-how-do-i-split-a-string-into-an-array-of-strings-based-on-a-delimiter
begin
  ListOfStrings.Clear;
  ListOfStrings.Delimiter     := Delimiter;
  ListOfStrings.DelimitedText := Str;
end;

function functions.empty(str: string): boolean;
begin
  if(Length(str)=0) then result:=true
  else result:=false;
end;

function functions.GetLocalDir(): string;   //same function as GetLocalPath()
begin
  result:=ExtractFilePath(ParamStr(0));
end;

function functions.GetWinVersion: TWinVersion; //taken from GeoOS_Main.exe
 var
    osVerInfo: TOSVersionInfo;
    majorVersion, minorVersion: Integer;
 begin
    Result := wvUnknown;
    osVerInfo.dwOSVersionInfoSize := SizeOf(TOSVersionInfo) ;
    if GetVersionEx(osVerInfo) then
    begin
      minorVersion := osVerInfo.dwMinorVersion;
      majorVersion := osVerInfo.dwMajorVersion;
      case osVerInfo.dwPlatformId of
        VER_PLATFORM_WIN32_NT:
        begin
          if majorVersion <= 4 then
            Result := wvWinNT
          else if (majorVersion = 5) and (minorVersion = 0) then
            Result := wvWin2000
          else if (majorVersion = 5) and (minorVersion = 1) then
            Result := wvWinXP
          else if (majorVersion = 6) then
            Result := wvWinVista;
        end;
        VER_PLATFORM_WIN32_WINDOWS:
        begin
          if (majorVersion = 4) and (minorVersion = 0) then
            Result := wvWin95
          else if (majorVersion = 4) and (minorVersion = 10) then
          begin
            if osVerInfo.szCSDVersion[1] = 'A' then
              Result := wvWin98SE
            else
              Result := wvWin98;
          end
          else if (majorVersion = 4) and (minorVersion = 90) then
            Result := wvWinME
          else
            Result := wvUnknown;
        end;
      end;
    end;
 end;

function functions.FreeAll(): boolean;
begin
  CommandSplit1.Free;   // release memory from using main split
  CommandSplit2.Free;   // release memory from using minor split
  ZipHandler.Free;      // release memory from using zip handler
  _log.Free;            // release memory from logs
  reg.Free;             // release memory from using windows registry
  {$IFNDEF CONSOLE}
  idAntiFreeze.Free;    // release memory from using indy's antifreeze
  {$ENDIF}
  result:=true;
end;

{$IFDEF CONSOLE}
function functions.DownloadFile(const url: string; const destinationFileName: string): boolean;
var
  hInet: HINTERNET;
  hFile: HINTERNET;
  localFile: File;
  buffer: array[1..1024] of byte;
  bytesRead: DWORD;
begin
  result:=False;
  hInet:=InternetOpen(PChar('GeoOSScript Mozilla/4.0'),INTERNET_OPEN_TYPE_DIRECT,nil,nil,0);
  hFile:=InternetOpenURL(hInet,PChar(url),nil,0,INTERNET_FLAG_NO_CACHE_WRITE+INTERNET_FLAG_ASYNC+INTERNET_FLAG_RELOAD,0);
  if(FileExists(destinationFileName)) then
  begin
    DeleteFile(PWChar(destinationFileName));
  end;
  if Assigned(hFile) then
  begin
    AssignFile(localFile,destinationFileName);
    Rewrite(localFile,1);
    repeat
      InternetReadFile(hFile,@buffer,SizeOf(buffer),bytesRead);
      BlockWrite(localFile,buffer,bytesRead);
    until bytesRead = 0;
    CloseFile(localFile);
    result:=true;
    InternetCloseHandle(hFile);
  end;
  InternetCloseHandle(hInet);
end;
{$ELSE}

function GetDLFreeSlot(): smallint;
var i: smallint;
begin
  result:=0;
  for i:=5 downto 1 do
  begin
    if not(Assigned(fIDHTTP[i])) then
    begin
      result:=i;
    end;
  end;
end;

function functions.DownloadFile(const url: string; const destinationFileName: string): boolean;
var
  availabledl: smallint;
begin
  result := FALSE;
  availabledl:=GetDLFreeSlot();
  if not(availabledl=0) then
  begin
    fIDHTTP[availabledl]:=TIDHTTP.Create();
    fIDHTTP[availabledl].HandleRedirects:=TRUE;
    fIDHTTP[availabledl].AllowCookies:=FALSE;
    fIDHTTP[availabledl].Request.UserAgent:='GeoOSScript Mozilla/4.0';
    fIDHTTP[availabledl].Request.Connection:='Keep-Alive';
    fIDHTTP[availabledl].Request.ProxyConnection:='Keep-Alive';
    fIDHTTP[availabledl].Request.CacheControl:='no-cache';

    Stream[availabledl] := TMemoryStream.Create;
    try
      fIDHTTP[availabledl].Head(url);
    except
       On E: Exception do
        begin
          Result := FALSE;
        end;
    end;
    if(fIDHTTP[availabledl].Response.ResponseCode=200) then
    begin
      try
        fIDHTTP[availabledl].Get(url, Stream[availabledl]);
        if FileExists(destinationFileName) then
          DeleteFile(PWideChar(destinationFileName));
        Stream[availabledl].SaveToFile(destinationFileName);
        result := TRUE;
      except
        On E: Exception do
        begin
          Result := FALSE;
        end;
      end;
    end;
    FreeAndNil(Stream[availabledl]);
    FreeAndNil(fIDHTTP[availabledl]);
  end;
end;
{$ENDIF}

function functions.GetParams(): string; //gets all parameters
var
  returnstr: string;
  i: integer;
begin
  returnstr:='';
  if(ParamCount()>0) then
    for i:=1 to ParamCount() do
      returnstr:=returnstr+ParamStr(i)+'|';
  result:=returnstr;
end;

function functions.LookUpForParams(): string; //Search, how many and what parameters are used
begin
  if(ParamCount()>0) then
    result:=GetParams()
  else
    result:='';
end;

function functions.ReadCommand(str: string): string;
begin
  Split('=',str,CommandSplit1);
  if not(CommandSplit1.Count=0) then
    result:=LowerCase(CommandSplit1.Strings[0])
  else
    result:='';
end;

function functions.ReadCommand(str: string; lower: boolean): string;
begin
  if(lower) then
    result:=ReadCommand(str)
  else
  begin
    Split('=',str,CommandSplit1);
    if not(CommandSplit1.Count=0) then
      result:=LowerCase(CommandSplit1.Strings[0])
    else
      result:='';
  end;
end;

function functions.CommandParams(str: string): string;
begin
  Split('=',str,CommandSplit1);
  if not(CommandSplit1.Count=1) then
    result:=CommandSplit1.Strings[1]
  else
    result:='';
end;

function functions.CommandParams(str: string; index: integer): string;
begin
  Split('=',str,CommandSplit1);
  Split(',',CommandSplit1[1],CommandSplit2);
  if((CommandSplit2.Count-1)>=index) then
    result:=CommandSplit2.Strings[index]
  else
    result:='';
end;

function functions.CommandParams(str: string; index: integer; commandindex: integer): string;
begin
  Split('=',str,CommandSplit1);
  Split(',',CommandSplit1[commandindex+1],CommandSplit2);
  if((CommandSplit2.Count-1)>=index) then
    result:=CommandSplit2.Strings[index]
  else
    result:='';
end;

function functions.CheckVersionInOnlineStore(programname: string; currversion: string; beta: boolean): string;
var
  fFile: TStringList;
  i: integer;
begin
  fFile:=TStringList.Create();
  result:='0';
  i:=0;
  if(beta) then
    DownloadFile('http://geodar.hys.cz/geoos/beta/'+programname+'.gos',GetLocalDir()+programname+'.gos')
  else
    DownloadFile('http://geodar.hys.cz/geoos/'+programname+'.gos',GetLocalDir()+programname+'.gos');
  if(FileExists(GetLocalDir()+programname+'.gos')) then
  begin
    fFile.LoadFromFile(GetLocalDir()+programname+'.gos');
    DeleteFile(GetLocalDir()+programname+'.gos');
    while ((i<fFile.Count) and (result='0')) do
    begin
      if(ReadCommand(fFile.Strings[i])='version') then
        if not(CommandParams(fFile.Strings[i])=currversion) then
          result:=CommandParams(fFile.Strings[i]);
      inc(i);
    end;
  end;
  fFile.Free;
end;

function functions.CheckDirAndDownloadFile(url: string; path: string): boolean;
var
  splitdir:  TStringList;
  splitdir2: TStringList;
  i:             integer;
  str:            string;
  hope:          boolean;
begin
  splitdir:=TStringList.Create();
  splitdir2:=TStringList.Create();
  str:=ExtractFileDir(ParamStr(0));
  hope:=false;
  Split('\',path,splitdir);
  Split('/',path,splitdir2);
  if(splitdir.Count>1) then //if \ is used for specified directory
  begin
    hope:=true;
    for i:=0 to splitdir.Count-2 do //make directory for each one of them
    begin
      str:=str+'\'+splitdir[i];
      if not(DirectoryExists(str)) then
        MkDir(str);
    end;
  end;
  if((splitdir2.Count>1) and not(hope)) then // / is used for specified directory
  begin
    for i:=0 to splitdir2.Count-2 do //make directory for each one of them
    begin
      str:=str+'\'+splitdir2[i];
      if not(DirectoryExists(str)) then
        MkDir(str);
    end;
  end;
  splitdir.Free;
  splitdir2.Free;
  result:=DownloadFile(url,GetLocalDir()+path);
end;

function functions.TerminateMe(): boolean;
begin
  FreeAll();
  {$IFDEF CONSOLE}
  Halt(0); //terminate console
  {$ENDIF}
  result:=true;
end;

function functions.IsRemote(param: string): boolean; //Local -> false | Remote -> true
begin
  if(MidStr(param,1,7)='http://') then result:=true        //accepting http:// as remote
  else if(MidStr(param,1,8)='https://') then result:=true  //accepting https:// as remote
  else if(MidStr(param,1,6)='ftp://') then result:=true    //accepting ftp:// as remote
  else result:=false; //everything else is in local computer
end;

function functions.RunFile(scriptlocation: string): boolean; //run GeoOS script file
var
  fFile: TStringList;
  i: integer;
begin
  result:=false;
  i:=0;
  fFile:=TStringList.Create();
  if(FileExists(scriptlocation)) then
  begin
    fFile.LoadFromFile(scriptlocation);
    LogAdd('-- Install file '+ExtractFileName(scriptlocation)+' --');
    while i<fFile.Count do
    begin
      ReadAndDoCommands(fFile.Strings[i]);
      inc(i);
    end;
    LogAdd('-- End of install file '+ExtractFileName(scriptlocation)+' --');
    result:=true;
  end;
  fFile.Free;
end;

function functions.CheckAndRunFile(scriptlocation: string): boolean; //check for script download or handling
var
  fFile: TStringList;
begin
  result:=false;
  fFile:=TStringList.Create();
  if(IsRemote(scriptlocation)) then
  begin
    LogAdd('Installing file '+ExtractFileName(scriptlocation));
    ReadAndDoCommands('DownloadFile='+scriptlocation+',tmpscript.gos,overwrite');
    if(FileExists(GetLocalDir()+'tmpscript.gos')) then
    begin
      fFile.LoadFromFile(GetLocalDir()+'tmpscript.gos');
      if(ReadCommand(fFile.Strings[0])='scriptname') then
      begin
        ReadAndDoCommands('CopyFile=tmpscript.gos,'+CommandParams(fFile.Strings[0])+'.gos,overwrite');
        if(FileExists(GetLocalDir()+CommandParams(fFile.Strings[0])+'.gos')) then
        begin
          DeleteFile(GetLocalDir()+'tmpscript.gos');
          result:=RunFile(GetLocalDir()+CommandParams(fFile.Strings[0])+'.gos');
        end
        else
          LogAdd('Copy file failed, installation aborded');
      end
      else
        LogAdd('Script Name failed, installation aborded');
    end
    else
      LogAdd('Download failed, installation aborded');
  end
  else
  begin
    if(FileExists(GetLocalDir()+scriptlocation)) then
    begin
      LogAdd('Installing file '+ExtractFileName(scriptlocation));
      result:=RunFile(GetLocalDir()+scriptlocation);
    end
    else
    begin
      LogAdd('Installing file '+ExtractFileName(scriptlocation));
      result:=RunFile(scriptlocation);
    end;
  end;
  fFile.Free;
end;

function functions.ReadAndDoCommands(line: string): boolean; //the most important function!
var
  comm,par: string;
  yn: string;
begin
  comm:=ReadCommand(line);
  par:=CommandParams(line);
  result:=true;
  if not(ifmode=0) then
    if(LowerCase(line)='end::') then
    begin
      ifinfo:='';
      ifmode:=0;
      result:=true;
      exit;
    end
    else if(not(ifinfo=progversion) and (ifmode=1)) then
    begin
      result:=false;
      exit;
    end
    else if((ifinfo=progversion) and (ifmode=2)) then
    begin
      result:=false;
      exit;
    end;
  {$IFNDEF CONSOLE}
  Handle:=Application.Handle;
  {$ENDIF}
  if(empty(comm)) then // if command is missing, don't do anything
  begin
    LogAdd('Command whitespace');
    result:=false;
  end
  {$IFDEF CONSOLE}
  else if((comm='closeme') or (comm='terminateme')) then
  begin
    TerminateMe();
    result:=true;
  end
  {$ENDIF}
  else if(empty(par)) then // if parameter is missing, don't do anything
  begin
    LogAdd('Parameter whitespace');
    result:=false;
  end
  else if(comm='::ifversion') then
  begin
    ifinfo:=par;
    ifmode:=1;
  end
  else if(comm='::ifnotversion') then
  begin
    ifinfo:=par;
    ifmode:=2;
  end
  else if(comm='scriptname') then
    LogAdd('Script name: '+par)
  else if(comm='author') then //Write script's author
    LogAdd('Script´s Author: '+par)
  else if(comm='log') then //Write a message
    LogAdd(StringReplace(par,'__',' ', [rfReplaceAll, rfIgnoreCase]))
  else if(comm='logenter') then //Write a message, user need to hit enter to continue with program
  begin
    {$IFDEF CONSOLE}
    write(StringReplace(par,'__',' ', [rfReplaceAll, rfIgnoreCase]));
    readln;
    {$ELSE}
    LogAdd('Command LogEnter is not supported under forms programs!');
    {$ENDIF}
  end
  else if(comm='version') then //Write current script version
    LogAdd('Script´s Version: '+par)
  else if(comm='promptyesno') then //Ask user to do some command, if 'y' is prompt that command will be used
  begin
    {$IFDEF CONSOLE}
    write(StringReplace(CommandParams(line,0),'__',' ', [rfReplaceAll, rfIgnoreCase])+' [y/n]: ');
    read(yn);
    readln;
    {$ELSE}
    yn:=InputBox('GeoOS Script',StringReplace(CommandParams(line,0),'__',' ', [rfReplaceAll, rfIgnoreCase])+' [y/n]: ','n');
    {$ENDIF}
    SetLength(yn,1);
    if(yn='y') then
    begin
      if not(empty(CommandParams(line,1,1))) then //support for Execute
      begin
        LogAdd('You prompt: '+CommandParams(line,1)+'='+CommandParams(line,0,1)+','+CommandParams(line,1,1));
        ReadAndDoCommands(CommandParams(line,1)+'='+CommandParams(line,0,1)+','+CommandParams(line,1,1));
      end
      else
      begin
        LogAdd('You prompt: '+CommandParams(line,1)+'='+CommandParams(line,0,1));
        ReadAndDoCommands(CommandParams(line,1)+'='+CommandParams(line,0,1));
      end;
    end
    else
      LogAdd('Prompt: Do Nothing');
  end
  else if(comm='mkdir') then //Create Directory
  begin
    if not(DirectoryExists(GetLocalDir()+par)) then
    begin
      mkdir(GetLocalDir()+par);
      LogAdd('Directory "'+GetLocalDir()+par+'" created.');
    end;
  end
  else if(comm='rmdir') then //Remove Directory
  begin
    if(DirectoryExists(GetLocalDir()+par)) then
    begin
      rmdir(GetLocalDir()+par);
      LogAdd('Directory "'+GetLocalDir()+par+'" removed.');
    end;
  end
  else if(comm='rmfile') then //Remove File
  begin
    if(FileExists(GetLocalDir()+par)) then
    begin
      deletefile(PWChar(GetLocalDir()+par));
      LogAdd('File "'+GetLocalDir()+par+'" removed.');
    end;
  end
  else if(comm='setregistry') then //set value into windows registry
  begin
    result:=false;
    if(CommandParams(line,0)='HKEY_CLASSES_ROOT') then
      reg.RootKey:=HKEY_CLASSES_ROOT
    else if(CommandParams(line,0)='HKEY_LOCAL_MACHINE') then
      reg.RootKey:=HKEY_LOCAL_MACHINE
    else if(CommandParams(line,0)='HKEY_USERS') then
      reg.RootKey:=HKEY_USERS
    else if(CommandParams(line,0)='HKEY_CURRENT_CONFIG') then
      reg.RootKey:=HKEY_CURRENT_CONFIG
    else //if(CommandParams(line,0)='HKEY_CURRENT_USER') then
      reg.RootKey:=HKEY_CURRENT_USER;
    if((reg.KeyExists(CommandParams(line,1)) or not(empty(CommandParams(line,1)))) and not(empty(CommandParams(line,2))) and not(empty(CommandParams(line,3))) and not(empty(CommandParams(line,4)))) then
    begin
      reg.OpenKey(CommandParams(line,1),true);
      if(LowerCase(CommandParams(line,2))='string') then
        reg.WriteString(CommandParams(line,3),CommandParams(line,4))
      else if((LowerCase(CommandParams(line,2))='integer') or (LowerCase(CommandParams(line,2))='int')) then
        reg.WriteInteger(CommandParams(line,3),StrToInt(CommandParams(line,4)))
      else if(LowerCase(CommandParams(line,2))='float') then
        reg.WriteFloat(CommandParams(line,3),StrToFloat(CommandParams(line,4)))
      else if((LowerCase(CommandParams(line,2))='boolean') or (LowerCase(CommandParams(line,2))='bool')) then
      begin
        if(LowerCase(CommandParams(line,4))='true') then
          reg.WriteBool(CommandParams(line,3),true)
        else
          reg.WriteBool(CommandParams(line,3),false);
      end;
      LogAdd('Modification in Registry completed!');
      result:=true;
    end
    else
      LogAdd('Modification in Registry not completed! Something is mission or invalid key.');
  end
  else if(comm='copyfile') then //Copy File
  begin
    if(FileExists(GetLocalDir()+CommandParams(line,0))) then
    begin
      if(FileExists(GetLocalDir()+CommandParams(line,1))) then
      begin
        if(CommandParams(line,2)='overwrite') then
        begin
          CopyFile(PWChar(GetLocalDir()+CommandParams(line,0)),PWChar(GetLocalDir()+CommandParams(line,1)),false);
          LogAdd('File "'+GetLocalDir()+CommandParams(line,0)+'" copied to "'+GetLocalDir()+CommandParams(line,1)+'". autooverwrite');
        end
        else
        begin
          {$IFDEF CONSOLE}
          write('File "'+GetLocalDir()+CommandParams(line,1)+'" already exists, overwrite? [y/n]: ');
          read(yn);
          readln;
          {$ELSE}
          yn:=InputBox('GeoOS Script','File "'+CommandParams(line,1)+'" already exists, overwrite? [y/n]: ','n');
          {$ENDIF}
          SetLength(yn,1);
          if(yn='y') then // if user type "y" it means "yes"
          begin
            CopyFile(PWChar(GetLocalDir()+CommandParams(line,0)),PWChar(GetLocalDir()+CommandParams(line,1)),false);
            LogAdd('File "'+GetLocalDir()+CommandParams(line,0)+'" copied to "'+GetLocalDir()+CommandParams(line,1)+'".');
          end
          else
            LogAdd('OK');
        end;
      end
      else
      begin
        CopyFile(PWChar(GetLocalDir()+CommandParams(line,0)),PWChar(GetLocalDir()+CommandParams(line,1)),false);
        LogAdd('File "'+GetLocalDir()+CommandParams(line,0)+'" copied to "'+GetLocalDir()+CommandParams(line,1)+'".');
      end;
    end
    else
      LogAdd('File "'+GetLocalDir()+CommandParams(line,0)+'" copied to "'+GetLocalDir()+CommandParams(line,1)+'" failed! File "'+CommandParams(line,0)+'" doesn´t exists!');
  end
  else if(comm='execute') then
  begin
    if(FileExists(GetLocalDir()+CommandParams(line,0))) then
    begin
      if(GetWinVersion=wvWinVista) then
      begin
        ShellExecute(Handle,'runas',PWChar(GetLocalDir()+CommandParams(line,0)),PWChar(StringReplace(CommandParams(line,1),'__',' ', [rfReplaceAll, rfIgnoreCase])),PWChar(GetLocalDir()),1);
        LogAdd('File "'+CommandParams(line,0)+'" executed as admin with "'+StringReplace(CommandParams(line,1),'__',' ', [rfReplaceAll, rfIgnoreCase])+'" parameters.');
      end
      else
      begin
        ShellExecute(Handle,'open',PWChar(GetLocalDir()+CommandParams(line,0)),PWChar(StringReplace(CommandParams(line,1),'__',' ', [rfReplaceAll, rfIgnoreCase])),PWChar(GetLocalDir()),1);
        LogAdd('File "'+CommandParams(line,0)+'" executed with "'+StringReplace(CommandParams(line,1),'__',' ', [rfReplaceAll, rfIgnoreCase])+'" parameters.');
      end;
    end
    else if(IsRemote(CommandParams(line,0))) then
    begin
      ShellExecute(Handle,'open',PWChar(StringReplace(line,ReadCommand(line,false)+'=','', [rfReplaceAll, rfIgnoreCase])),nil,PWChar(GetLocalDir()),1);
    end
    else
      LogAdd('File "'+CommandParams(line,0)+'" doesn´t exists!');
  end
  else if(comm='downloadfile') then
  begin
    if(fileexists(GetLocalDir()+CommandParams(line,1))) then
    begin
      if(CommandParams(line,2)='overwrite') then
      begin
        LogAdd('Downloading "'+CommandParams(line,0)+'" to "'+GetLocalDir()+CommandParams(line,1)+'" ... autooverwrite');
        result:=CheckDirAndDownloadFile(CommandParams(line,0),CommandParams(line,1));
      end
      else
      begin
        {$IFDEF CONSOLE}
        write('File "',GetLocalDir()+CommandParams(line,1),'" already exists, overwrite? [y/n]: ');
        read(yn);
        readln;
        {$ELSE}
        yn:=InputBox('GeoOS Script','File "'+CommandParams(line,1)+'" already exists, overwrite? [y/n]: ','n');
        {$ENDIF}
        SetLength(yn,1);
        if(yn='y') then // if user type "y" it means "yes"
        begin
          LogAdd('Downloading "'+CommandParams(line,0)+'" to '+GetLocalDir()+CommandParams(line,1)+'" ...');
          result:=CheckDirAndDownloadFile(CommandParams(line,0),CommandParams(line,1));
        end;
      end;
    end
    else  //file does not exists
    begin
      LogAdd('Downloading "'+CommandParams(line,0)+'" to "'+GetLocalDir()+CommandParams(line,1)+'" ...');
      result:=CheckDirAndDownloadFile(CommandParams(line,0),CommandParams(line,1));
    end;
    if(result) then
      LogAdd('OK')
    else
      LogAdd('Download not completed, maybe another process is using this file or remote file doesn´t exists!');
  end
  else if(comm='zipextract') then
  begin
    if(ZipHandler.IsValid(par)) then
    begin
      ZipHandler.ExtractZipFile(par,GetLocalDir()+'geoos\');
      LogAdd('File "'+par+'" extracted.');
    end
    else
      LogAdd('File "'+par+'" is not valid zip file!');
  end
  else if(comm='zipextractto') then
  begin
    if(ZipHandler.IsValid(CommandParams(line,0))) then
    begin
      ZipHandler.ExtractZipFile(CommandParams(line,0),GetLocalDir()+CommandParams(line,1));
      LogAdd('File "'+CommandParams(line,0)+'" extracted to "'+CommandParams(line,1)+'".');
    end
    else
      LogAdd('File "'+CommandParams(line,0)+'" is not valid zip file!');
  end
  else if(comm='runfile') then //run GeoOS script file within script
  begin
    if(CheckAndRunFile(par)) then
      LogAdd('Installation completed!')
    else
    begin
      LogAdd('Installation failed!');
      result:=false;
    end;
  end
  else
  begin
    LogAdd('Command "'+comm+'" not found!');
    result:=false;
  end;
end;

function functions.LogAdd(messages: string): TStringList;
begin
  _log.Add(messages);
  result:=ShowLog();
end;

function functions.ShowLog(): TStringList;
begin
  {$IFDEF CONSOLE}
  writeln(_log.Strings[_log.Count-1]);
  {$ELSE}
  Form1.HandleGeoOSScriptMsg(_log.Strings[_log.Count-1]);
  {$ENDIF}
  result:=_log;
end;

function functions.SetProgramVersion(stringversion: string): boolean;
begin
  //when you want to use ::ifversion in script, you need to get current version set with this function
  progversion:=stringversion;
  result:=true;
end;

function functions.init(): boolean;
begin
  CommandSplit1:=TStringList.Create();
  CommandSplit2:=TStringList.Create();
  ZipHandler:=TZipFile.Create();
  {$IFNDEF CONSOLE}
  idAntiFreeze:=TIdAntiFreeze.Create();
  {$ENDIF}
  _log:=TStringList.Create();
  _log.Add('GeoOS Script Log Init.');
  reg:=TRegistry.Create();
  progversion:='';
  ifinfo:='';
  ifmode:=0;
  result:=true;
end;

end.
