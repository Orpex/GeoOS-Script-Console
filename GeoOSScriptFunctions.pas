﻿unit GeoOSScriptFunctions;
{
  Version 0.46.4
  Copyright 2012-2015 Geodar
  https://github.com/Geodar/GeoOS_Script_Functions
}
interface
  uses
    Windows, SysUtils, Classes, shellapi, Zip, StrUtils, Registry,
    WinINet, Tlhelp32
    {$IFNDEF CONSOLE}, Dialogs, IdHTTP, IdAntiFreeze, IdComponent, Forms{$ENDIF};

  type TWinVersion = (wvUnknown, wvWin95, wvWin98, wvWin98SE, wvWinNT, wvWinME, wvWin2000, wvWinXP, wvWinVista);

const
  FunctionsVersion = '0.46.4';

const //admin rights constants
  SECURITY_NT_AUTHORITY: TSIDIdentifierAuthority=(Value:(0,0,0,0,0,5));
  SECURITY_BUILTIN_DOMAIN_RID  = $00000020;
  DOMAIN_ALIAS_RID_ADMINS      = $00000220;
  DOMAIN_ALIAS_RID_USERS       = $00000221;
  DOMAIN_ALIAS_RID_GUESTS      = $00000222;
  DOMAIN_ALIAS_RID_POWER_USERS = $00000223;

  function CheckTokenMembership(TokenHandle: THandle; SidToCheck: PSID; var IsMember: BOOL): BOOL; stdcall; external advapi32;

  type functions = record
    public
    function KillTask(ExeFileName: string): integer; stdcall;
    function RunGOSCommand(line: string): boolean; stdcall;
    function GetWinVersion: TWinVersion; stdcall;
    function FreeAll(): boolean; stdcall;
    {$IFNDEF Console}
    function DownloadFile(const url: string; const destinationFileName: string): boolean; overload; stdcall;
    function DownloadFile(const url: string; const destinationFileName: string; surpressmsg: boolean): boolean; overload; stdcall;
    function DownloadFileLegacy(const url: string; const destinationFileName: string): boolean; stdcall;
    function DownloadFileGet(const url: string; const destinationFileName: string): boolean; stdcall;
    function DownloadFileToStream(const url: string): TMemoryStream; stdcall;
    {$ELSE}
    function DownloadFile(const url: string; const destinationFileName: string): boolean; stdcall;
    {$ENDIF}
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
    function CheckVersionInOnlineStore(programname: string; currversion: string): string; stdcall;
    function GetUpdateText(programname: string): string; stdcall;
    function IsRemote(param: string): boolean; stdcall;
    function GetPreqFromRemote(param: string): string; stdcall;
    function NotHttps(param: string): boolean; stdcall;
    function RunFile(scriptlocation: string): boolean; stdcall;
    function CheckAndRunFile(scriptlocation: string): boolean; stdcall;
    function SetProgramVersion(stringversion: string): boolean; stdcall;
    function GetFunctionsVersion(): string; stdcall;
    function IsUserAdmin(): boolean; stdcall;
    procedure Split(Delimiter: string; Str: string; OutputList: TStrings);
  end;

  var
    ZipHandler:                      TZipFile;  // for accessing zip files
    CommandSplit1:                TStringList;  // for spliting of commands (main - what is command, and what are parameters)
    CommandSplit2:                TStringList;  // for spliting of commands (minor - if multiple parameters, split them too)
    Handle:                              HWND;  // some handle variable for shellapi
    _log:                         TStringList;  // holds information about scripts progress
    progversion:                       string;  // program version in string
    ifinfo:                            string;  // for RunGOSCommand
    ifmode:                          smallint;  // GOScript if
    reg:                            TRegistry;  // for accessing windows registry
    {$IFNDEF CONSOLE}
    fIDHTTP:         array [1..10] of TIDHTTP;  // max support for 10 downloads at time
    Stream:    array [1..10] of TMemoryStream;  // downloading streams
    idAntiFreeze:               TIdAntiFreeze;  // stop freezing application while downloading a file
    {$ENDIF}

implementation

{$IFNDEF CONSOLE}
uses Unit1;
{$ENDIF}

procedure functions.Split(Delimiter: string; Str: string; OutputList: TStrings);
begin
  OutputList.LineBreak:=Delimiter;
  OutputList.Text:=Str;
end;

function functions.KillTask(ExeFileName: string): integer;
const
  PROCESS_TERMINATE = $0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
      Result := Integer(TerminateProcess(
                        OpenProcess(PROCESS_TERMINATE,
                                    BOOL(0),
                                    FProcessEntry32.th32ProcessID),
                                    0));
     ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

function functions.empty(str: string): boolean;
begin
  if(Length(str)=0) then
    result:=true
  else
    result:=false;
end;

function functions.GetLocalDir(): string;
begin
  result:=ExtractFilePath(ParamStr(0));
end;

function functions.CheckVersionInOnlineStore(programname: string; currversion: string): string;
var
  fFile: TStringList;
  i: integer;
begin
  fFile:=TStringList.Create();
  i:=0;
  result:='0';
  if(DownloadFile('http://geodar.hys.cz/geoos/'+programname+'.gos',GetLocalDir()+programname+'.gos')) then
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

function functions.GetUpdateText(programname: string): string;
var
  fFile: TStringList;
  i: integer;
begin
  fFile:=TStringList.Create();
  i:=0;
  result:='';
  if(DownloadFile('http://geodar.hys.cz/geoos/'+programname+'.gos',GetLocalDir()+programname+'.gos')) then
  begin
    fFile.LoadFromFile(GetLocalDir()+programname+'.gos');
    DeleteFile(GetLocalDir()+programname+'.gos');
    while ((i<fFile.Count) and (result='')) do
    begin
      if(ReadCommand(fFile.Strings[i])='updatetext') then
        result:=CommandParams(fFile.Strings[i]);
      inc(i);
    end;
  end;
  fFile.Free;
end;

function functions.GetWinVersion: TWinVersion; //taken from GeoOS_Main.exe
 var
    osVerInfo: TOSVersionInfo;
    majorVersion: integer;
    minorVersion: integer;
 begin
    result:=wvUnknown;
    osVerInfo.dwOSVersionInfoSize:=SizeOf(TOSVersionInfo);
    if(GetVersionEx(osVerInfo)) then
    begin
      minorVersion:=osVerInfo.dwMinorVersion;
      majorVersion:=osVerInfo.dwMajorVersion;
      case osVerInfo.dwPlatformId of
        VER_PLATFORM_WIN32_NT:
        begin
          if(majorVersion<=4) then
            result:=wvWinNT
          else if((majorVersion=5) and (minorVersion=0)) then
            result:=wvWin2000
          else if((majorVersion=5) and (minorVersion=1)) then
            result:=wvWinXP
          else if(majorVersion=6) then
            result:=wvWinVista;
        end;
        VER_PLATFORM_WIN32_WINDOWS:
        begin
          if((majorVersion=4) and (minorVersion=0)) then
            result:=wvWin95
          else if((majorVersion=4) and (minorVersion=10)) then
          begin
            if(osVerInfo.szCSDVersion[1]='A') then
              result:=wvWin98SE
            else
              result:=wvWin98;
          end
          else if((majorVersion=4) and (minorVersion=90)) then
            result:=wvWinME
          else
            result:=wvUnknown;
        end;
      end;
    end;
 end;

function functions.FreeAll(): boolean;
begin
  CommandSplit1.Free;   // release memory from using major split
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
  result:=false;
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

function functions.DownloadFileLegacy(const url: string; const destinationFileName: string): boolean;
var
  hInet: HINTERNET;
  hFile: HINTERNET;
  localFile: File;
  buffer: array[1..1024] of byte;
  bytesRead: DWORD;
begin
  result:=false;
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

function GetDLFreeSlot(): smallint;
var i: smallint;
begin
  result:=0;
  for i:=10 downto 1 do
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
  result:=false;
  availabledl:=GetDLFreeSlot();
  if not(availabledl=0) then
  begin
    fIDHTTP[availabledl]:=TIDHTTP.Create();
    fIDHTTP[availabledl].HandleRedirects:=true;
    fIDHTTP[availabledl].AllowCookies:=false;
    fIDHTTP[availabledl].Request.UserAgent:='GeoOSScript Mozilla/4.0';
    fIDHTTP[availabledl].Request.Connection:='Keep-Alive';
    fIDHTTP[availabledl].Request.ProxyConnection:='Keep-Alive';
    fIDHTTP[availabledl].Request.CacheControl:='no-cache';
    Stream[availabledl]:=TMemoryStream.Create();
    try
      fIDHTTP[availabledl].Head(url);
    except
       On E: Exception do
        begin
          result:=false;
          LogAdd('Could not download file, error 404!');
        end;
    end;
    if(fIDHTTP[availabledl].Response.ResponseCode=200) then
    begin
      try
        fIDHTTP[availabledl].Get(url, Stream[availabledl]);
        if FileExists(destinationFileName) then
          DeleteFile(PWideChar(destinationFileName));
        Stream[availabledl].SaveToFile(destinationFileName);
        result:=true;
      except
        On E: Exception do
        begin
          result:=false;
          LogAdd('Could not download file, not response code 200!');
        end;
      end;
    end;
    if(FileExists(destinationFileName)) then
      LogAdd('OK')
    else if not(IsUserAdmin()) then
      LogAdd('Can´t save file! Suggestion: Run this application as Administrator!')
    else if not(result) then
      LogAdd('Unknown error while downloading file!');
    FreeAndNil(Stream[availabledl]);
    FreeAndNil(fIDHTTP[availabledl]);
  end;
end;

function functions.DownloadFile(const url: string; const destinationFileName: string; surpressmsg: boolean): boolean;
var
  availabledl: smallint;
begin
  result:=false;
  availabledl:=GetDLFreeSlot();
  if not(availabledl=0) then
  begin
    fIDHTTP[availabledl]:=TIDHTTP.Create();
    fIDHTTP[availabledl].HandleRedirects:=true;
    fIDHTTP[availabledl].AllowCookies:=false;
    fIDHTTP[availabledl].Request.UserAgent:='GeoOSScript Mozilla/4.0';
    fIDHTTP[availabledl].Request.Connection:='Keep-Alive';
    fIDHTTP[availabledl].Request.ProxyConnection:='Keep-Alive';
    fIDHTTP[availabledl].Request.CacheControl:='no-cache';
    Stream[availabledl]:=TMemoryStream.Create();
    try
      fIDHTTP[availabledl].Head(url);
    except
       On E: Exception do
        begin
          result:=false;
          if not(surpressmsg) then
            LogAdd('Could not download file, error 404!');
        end;
    end;
    if(fIDHTTP[availabledl].Response.ResponseCode=200) then
    begin
      try
        fIDHTTP[availabledl].Get(url, Stream[availabledl]);
        if FileExists(destinationFileName) then
          DeleteFile(PWideChar(destinationFileName));
        Stream[availabledl].SaveToFile(destinationFileName);
        result:=true;
      except
        On E: Exception do
        begin
          result:=false;
          if not(surpressmsg) then
            LogAdd('Could not download file, not response code 200!');
        end;
      end;
    end;
    if(FileExists(destinationFileName)) then
    begin
      if not(surpressmsg) then
        LogAdd('OK');
    end
    else if not(IsUserAdmin()) then
    begin
      if not(surpressmsg) then
        LogAdd('Can´t save file! Suggestion: Run this application as Administrator!');
    end
    else if not(result) then
    begin
      if not(surpressmsg) then
        LogAdd('Unknown error while downloading file!');
    end;
    FreeAndNil(Stream[availabledl]);
    FreeAndNil(fIDHTTP[availabledl]);
  end;
end;

function functions.DownloadFileGet(const url: string; const destinationFileName: string): boolean;
var
  availabledl: smallint;
begin
  result:=false;
  availabledl:=GetDLFreeSlot();
  if not(availabledl=0) then
  begin
    fIDHTTP[availabledl]:=TIDHTTP.Create();
    fIDHTTP[availabledl].HandleRedirects:=true;
    fIDHTTP[availabledl].AllowCookies:=false;
    fIDHTTP[availabledl].Request.UserAgent:='GeoOSScript Mozilla/4.0';
    fIDHTTP[availabledl].Request.Connection:='Keep-Alive';
    fIDHTTP[availabledl].Request.ProxyConnection:='Keep-Alive';
    fIDHTTP[availabledl].Request.CacheControl:='no-cache';
    Stream[availabledl]:=TMemoryStream.Create();
    try
      fIDHTTP[availabledl].Get(url, Stream[availabledl]);
      if FileExists(destinationFileName) then
      DeleteFile(PWideChar(destinationFileName));
      Stream[availabledl].SaveToFile(destinationFileName);
      result:=true;
    except
      On E: Exception do
      begin
        result:=false;
        LogAdd('Could not download file, not response code 200!');
      end;
    end;
    if(FileExists(destinationFileName)) then
      LogAdd('OK')
    else if not(IsUserAdmin()) then
      LogAdd('Can´t save file! Suggestion: Run this application as Administrator!')
    else if not(result) then
      LogAdd('Unknown error while downloading file!');
    FreeAndNil(Stream[availabledl]);
    FreeAndNil(fIDHTTP[availabledl]);
  end;
end;

function functions.DownloadFileToStream(const url: string): TMemoryStream;
var
  availabledl: smallint;
begin
  result:=nil;
  availabledl:=GetDLFreeSlot();
  if not(availabledl=0) then
  begin
    fIDHTTP[availabledl]:=TIDHTTP.Create();
    fIDHTTP[availabledl].HandleRedirects:=true;
    fIDHTTP[availabledl].AllowCookies:=false;
    fIDHTTP[availabledl].Request.UserAgent:='GeoOSScript Mozilla/4.0';
    fIDHTTP[availabledl].Request.Connection:='Keep-Alive';
    fIDHTTP[availabledl].Request.ProxyConnection:='Keep-Alive';
    fIDHTTP[availabledl].Request.CacheControl:='no-cache';
    Stream[availabledl]:=TMemoryStream.Create();
    try
      fIDHTTP[availabledl].Head(url);
    except
       On E: Exception do
        begin
          result:=nil;
          LogAdd('Could not download file, error 404!');
        end;
    end;
    if(fIDHTTP[availabledl].Response.ResponseCode=200) then
    begin
      try
        fIDHTTP[availabledl].Get(url, Stream[availabledl]);
        result:=Stream[availabledl];
      except
        On E: Exception do
        begin
          result:=nil;
          LogAdd('Could not download file, not response code 200!');
        end;
      end;
    end;
    if not(IsUserAdmin()) then
      LogAdd('Can´t save file! Suggestion: Run this application as Administrator!')
    else if(result = nil) then
      LogAdd('Unknown error while downloading file!');
    FreeAndNil(Stream[availabledl]);
    FreeAndNil(fIDHTTP[availabledl]);
  end;
end;
{$ENDIF}

function functions.IsUserAdmin(): boolean;
var
  b: bool;
  AdministratorsGroup: PSID;
begin
  b:=AllocateAndInitializeSid(
      SECURITY_NT_AUTHORITY,
      2, //2 sub-authorities
      SECURITY_BUILTIN_DOMAIN_RID,  //sub-authority 0
      DOMAIN_ALIAS_RID_ADMINS,      //sub-authority 1
      0, 0, 0, 0, 0, 0,             //sub-authorities 2-7 not passed
      AdministratorsGroup);
  if(b) then
  begin
    if not(CheckTokenMembership(0, AdministratorsGroup, b)) then
      b:=false;
      FreeSid(AdministratorsGroup);
  end;
  result:=b;
end;

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
      result:=CommandSplit1.Strings[0]
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

function functions.GetPreqFromRemote(param: string): string;
begin
  if(MidStr(param,1,7)='http://') then result:='http://'
  else if(MidStr(param,1,8)='https://') then result:='https://'
  else if(MidStr(param,1,6)='ftp://') then result:='ftp://'
  else result:='';
end;

function functions.IsRemote(param: string): boolean; //Local -> false | Remote -> true
begin
  if(GetPreqFromRemote(param)='http://') then result:=true        //accepting http:// as remote
  else if(GetPreqFromRemote(param)='https://') then result:=true  //accepting https:// as remote
  else if(GetPreqFromRemote(param)='ftp://') then result:=true    //accepting ftp:// as remote
  else result:=false; //everything else is in local computer
end;

function functions.NotHttps(param: string): boolean;
begin
  if(GetPreqFromRemote(param)='https://') then result:=false
  else result:=true;
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
    LogAdd('-- Run file "'+ExtractFileName(scriptlocation)+'" --');
    while i<fFile.Count do
    begin
      RunGOSCommand(fFile.Strings[i]);
      inc(i);
    end;
    LogAdd('-- Run file "'+ExtractFileName(scriptlocation)+'" end --');
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
    RunGOSCommand('DownloadFile='+scriptlocation+',tmpscript.gos,overwrite');
    if(FileExists(GetLocalDir()+'tmpscript.gos')) then
    begin
      fFile.LoadFromFile(GetLocalDir()+'tmpscript.gos');
      if(ReadCommand(fFile.Strings[0])='scriptname') then
      begin
        RunGOSCommand('CopyFile=tmpscript.gos,'+CommandParams(fFile.Strings[0])+'.gos,overwrite');
        if(FileExists(GetLocalDir()+CommandParams(fFile.Strings[0])+'.gos')) then
        begin
          DeleteFile(GetLocalDir()+'tmpscript.gos');
          result:=RunFile(GetLocalDir()+CommandParams(fFile.Strings[0])+'.gos');
        end
        else
          LogAdd('Copy file failed, run file aborded');
      end
      else
        LogAdd('Script Name failed, run file aborded');
    end
    else
      LogAdd('Download failed, run file aborded');
  end
  else
  begin
    if(FileExists(GetLocalDir()+scriptlocation)) then
    begin
      LogAdd('Running file '+ExtractFileName(scriptlocation));
      result:=RunFile(GetLocalDir()+scriptlocation);
    end
    else
    begin
      LogAdd('Running file '+ExtractFileName(scriptlocation));
      result:=RunFile(scriptlocation);
    end;
  end;
  fFile.Free;
end;

function functions.RunGOSCommand(line: string): boolean;
begin
  result:=ReadAndDoCommands(line);
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
      exit;
    end
    else if(LowerCase(line)='::else::') then
    begin
      if(ifmode=1) then ifmode:=2
      else if(ifmode=2) then ifmode:=1
      else if(ifmode=3) then ifmode:=4
      else if(ifmode=4) then ifmode:=3
      else if(ifmode=5) then ifmode:=6
      else if(ifmode=6) then ifmode:=5
      else if(ifmode=7) then ifmode:=8
      else if(ifmode=8) then ifmode:=7;
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
    end
    else if(not(FileExists(ifinfo)) and (ifmode=3)) then
    begin
      result:=false;
      exit;
    end
    else if(FileExists(ifinfo) and (ifmode=4)) then
    begin
      result:=false;
      exit;
    end
    else if(not(DirectoryExists(ifinfo)) and (ifmode=5)) then
    begin
      result:=false;
      exit;
    end
    else if(DirectoryExists(ifinfo) and (ifmode=6)) then
    begin
      result:=false;
      exit;
    end
    else if(not(AnsiContainsStr(ifinfo,progversion)) and (ifmode=7)) then
    begin
      result:=false;
      exit;
    end
    else if(AnsiContainsStr(ifinfo,progversion) and (ifmode=8)) then
    begin
      result:=false;
      exit;
    end;
  if(empty(comm)) then // if command is missing, don't do anything
  begin
    LogAdd('Command whitespace');
    result:=false;
  end
  else if((comm='closeme') or (comm='terminateme')) then
  begin
    {$IFDEF CONSOLE}
    TerminateMe();
    {$ELSE}
    LogAdd('Can´t terminate program! Shut it down manually!');
    {$ENDIF}
  end
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
  else if(comm='::iffileexists') then
  begin
    ifinfo:=par;
    ifmode:=3;
  end
  else if(comm='::iffilenotexists') then
  begin
    ifinfo:=par;
    ifmode:=4;
  end
  else if((comm='::ifdirexists') or (comm='::ifdirectoryexists')) then
  begin
    ifinfo:=par;
    ifmode:=5;
  end
  else if((comm='::ifdirnotexists') or (comm='::ifdirectorynotexists')) then
  begin
    ifinfo:=par;
    ifmode:=6;
  end
  else if((comm='::ifversioncontains') or (comm='::ifversioncont')) then
  begin
    ifinfo:=par;
    ifmode:=7;
  end
  else if((comm='::ifversionnotcontains') or (comm='::ifversionnotcont')) then
  begin
    ifinfo:=par;
    ifmode:=8;
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
    RunGOSCommand('Log='+par);
    {$ENDIF}
  end
  else if(comm='logsave') then //save log to a specified file
  begin
    LogAdd('Log saved as "'+par+'".');
    _log.SaveToFile(GetLocalDir()+par);
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
    if(LowerCase(yn)='y') then
    begin
      if not(empty(CommandParams(line,1,1))) then //support for Execute
      begin
        RunGOSCommand(CommandParams(line,1)+'='+CommandParams(line,0,1)+','+CommandParams(line,1,1));
      end
      else
      begin
        RunGOSCommand(CommandParams(line,1)+'='+CommandParams(line,0,1));
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
  else if(comm='killtask') then //turn other process off
  begin
    KillTask(par);
    LogAdd('Killing task "'+par+'".');
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
    else //if(CommandParams(line,0)='HKEY_CURRENT_USER') then || use HKEY_CURRENT_USER as default
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
      LogAdd('Modification in Registry not completed! Something is missing or invalid key.');
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
          if(LowerCase(yn)='y') then // if user type "y" it means "yes"
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
      LogAdd('Opening webpage "'+StringReplace(line,ReadCommand(line,false)+'=','', [rfReplaceAll, rfIgnoreCase])+'" with default user browser.');
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
        if(LowerCase(yn)='y') then // if user type "y" it means "yes"
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
  end
  else if(comm='zipextract') then
  begin
    if(ZipHandler.IsValid(par)) then
    begin
      if(FileExists(GetLocalDir()+par)) then
      begin
        ZipHandler.ExtractZipFile(par,GetLocalDir()+'geoos\');
        LogAdd('File "'+par+'" extracted.');
      end
      else
        LogAdd('File "'+par+'" does not exists.');
    end
    else
      LogAdd('File "'+par+'" is not valid zip file!');
  end
  else if(comm='zipextractto') then
  begin
    if(ZipHandler.IsValid(CommandParams(line,0))) then
    begin
      if(FileExists(GetLocalDir()+par)) then
      begin
        ZipHandler.ExtractZipFile(CommandParams(line,0),GetLocalDir()+CommandParams(line,1));
        LogAdd('File "'+CommandParams(line,0)+'" extracted to "'+CommandParams(line,1)+'".');
      end
      else
        LogAdd('File "'+CommandParams(line,0)+'" does not exists.');
    end
    else
      LogAdd('File "'+CommandParams(line,0)+'" is not valid zip file!');
  end
  else if(comm='updatetext') then
  begin
    LogAdd('Update Text: '+par);
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

function functions.GetFunctionsVersion(): string;
begin
  result:=FunctionsVersion;
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
  _log.Add('GeoOS Script Log v'+GetFunctionsVersion()+' Init.');
  reg:=TRegistry.Create();
  progversion:='';
  ifinfo:='';
  ifmode:=0;
  {$IFNDEF CONSOLE}
  Handle:=Application.Handle;
  {$ENDIF}
  result:=true;
end;

end.
