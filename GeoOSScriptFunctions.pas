unit GeoOSScriptFunctions;

interface
  uses
    Windows, WinINet, SysUtils, Classes, Registry, shellapi, Zip, StrUtils;

  type TWinVersion = (wvUnknown, wvWin95, wvWin98, wvWin98SE, wvWinNT, wvWinME, wvWin2000, wvWinXP, wvWinVista);

  type functions = class
    public
    function GetWinVersion: TWinVersion; stdcall;
    function FreeAll(): boolean; stdcall;
    function DownloadFile(const url: string; const destinationFileName: string): boolean; stdcall;
    function GetParams(): string; stdcall;
    function LookUpForParams(): string; stdcall;
    function ReadCommand(str: string): string; stdcall;
    function CommandParams(str: string): string; overload; stdcall;
    function CommandParams(str: string; index: integer): string; overload; stdcall;
    function CommandParams(str: string; index: integer; commandindex: integer): string; overload; stdcall;
    function CheckDirAndDownloadFile(url: string; path: string): boolean; stdcall;
    function ReadAndDoCommands(line: string): boolean; stdcall;
    function TerminateMe(): boolean; stdcall;
    function init(): boolean; stdcall;
  end;

  var
    ZipHandler:               TZipFile;  // for accessing zip files
    CommandSplit1:         TStringList;  // for spliting of commands (main - what is command, and what are parameters)
    CommandSplit2:         TStringList;  // for spliting of commands (minor - if multiple parameters, split them too)
    Handle:                       HWND;  // some handle variable for shellapi

implementation

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings); // Split what we need
//thanks to RRUZ - http://stackoverflow.com/questions/2625707/delphi-how-do-i-split-a-string-into-an-array-of-strings-based-on-a-delimiter
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter     := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

function empty(str: string): boolean;
begin
  if(Length(str)=0) then result:=true
  else result:=false;
end;

function GetLocalDir(): string;   //same function as GetLocalPath()
begin
  result:=ExtractFilePath(ParamStr(0));
end;

function GetLocalPath(): string; //same function as GetLocalDir()
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
  CommandSplit1.Free;   //release memory from using main split
  CommandSplit2.Free;   //release memory from using minor split
  ZipHandler.Free;      //release memory from using zip handler
end;

function functions.DownloadFile(const url: string; const destinationFileName: string): boolean;
var
  hInet: HINTERNET;
  hFile: HINTERNET;
  localFile: File;
  buffer: array[1..1024] of byte;
  bytesRead: DWORD;
begin
  result:=False;
  hInet:=InternetOpen(PChar('GeoOSScriptConsole'),INTERNET_OPEN_TYPE_DIRECT,nil,nil,0);
  hFile:=InternetOpenURL(hInet,PChar(url),nil,0,INTERNET_FLAG_NO_CACHE_WRITE,0);
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

function functions.GetParams(): string; //gets all parameters
var
  returnstr: string;
  i: integer;
begin
  returnstr:='';
  if(ParamCount()>0) then
  begin
    for i:=1 to ParamCount() do
    begin
      returnstr:=returnstr+ParamStr(i)+'|';
    end;
  end;
  result:=returnstr;
end;

function functions.LookUpForParams(): string; //Search, how many and what parameters are used
begin
  if(ParamCount()>0) then
  begin
    result:=GetParams();
  end
  else
  begin
    result:='';
  end;
end;

function functions.ReadCommand(str: string): string;
begin
  Split('=',str,CommandSplit1);
  result:=CommandSplit1[0];
end;

function functions.CommandParams(str: string): string;
begin
  Split('=',str,CommandSplit1);
  result:=CommandSplit1[1];
end;

function functions.CommandParams(str: string; index: integer): string;
begin
  Split('=',str,CommandSplit1);
  Split(',',CommandSplit1[1],CommandSplit2);
  if((CommandSplit2.Count-1)>=index) then
  begin
    result:=CommandSplit2[index];
  end
  else
  begin
    result:='';
  end;
end;

function functions.CommandParams(str: string; index: integer; commandindex: integer): string;
begin
  Split('=',str,CommandSplit1);
  Split(',',CommandSplit1[commandindex+1],CommandSplit2);
  if((CommandSplit2.Count-1)>=index) then
  begin
    result:=CommandSplit2[index];
  end
  else
  begin
    result:='';
  end;
end;

function functions.CheckDirAndDownloadFile(url: string; path: string): boolean;
var
  splitdir:  TStringList;
  splitdir2: TStringList;
  option:       smallint;
  i:             integer;
  str:            string;
  hope:          boolean;
begin
  splitdir:=TStringList.Create;
  splitdir2:=TStringList.Create;
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
      begin
        MkDir(str);
      end;
    end;
  end;
  if((splitdir2.Count>1) and not(hope)) then // / is used for specified directory
  begin
    for i:=0 to splitdir2.Count-2 do //make directory for each one of them
    begin
      str:=str+'\'+splitdir2[i];
      if not(DirectoryExists(str)) then
      begin
        MkDir(str);
      end;
    end;
  end;
  splitdir.Free;
  splitdir2.Free;
  result:=DownloadFile(url,GetLocalPath+path);
end;

function functions.TerminateMe(): boolean;
begin
  FreeAll();
  Halt(0); //terminate program
end;

function functions.ReadAndDoCommands(line: string): boolean; //the most important function!
var
  comm,par: string;
  yn: char;
begin
  comm:=ReadCommand(line);
  par:=CommandParams(line);
  result:=true;
  if(empty(comm)) then // if command is missing, don't do anything
  begin
    writeln('Command whitespace');
    result:=false;
  end
  else if((comm='CloseMe') or (comm='TerminateMe')) then
  begin
    TerminateMe();
  end
  else if(empty(par)) then // if parameter is missing, don't do anything
  begin
    writeln('Parameter whitespace');
    result:=false;
  end
  else if(comm='ScriptName') then
  begin
    writeln('Script name: ',par);
  end
  else if(comm='Author') then //Write script's author
  begin
    writeln('Script�s Author: ',par);
  end
  else if(comm='Log') then //Write a message
  begin
    writeln(StringReplace(par,'_',' ', [rfReplaceAll, rfIgnoreCase]));
  end
  else if(comm='LogEnter') then //Write a message, user need to hit enter to continue with program
  begin
    write(StringReplace(par,'_',' ', [rfReplaceAll, rfIgnoreCase]));
    readln;
  end
  else if(comm='PromptYesNo') then //Ask user to do some command, if 'y' is prompt that command will be used
  begin
    write(StringReplace(CommandParams(line,0),'_',' ', [rfReplaceAll, rfIgnoreCase])+' [y/n]: ');
    read(yn);
    readln;
    if(yn='y') then
    begin
      if not(empty(CommandParams(line,1,1))) then //support for Execute
      begin
        writeln('You prompt: '+CommandParams(line,1)+'='+CommandParams(line,0,1)+','+CommandParams(line,1,1));
        ReadAndDoCommands(CommandParams(line,1)+'='+CommandParams(line,0,1)+','+CommandParams(line,1,1));
      end
      else
      begin
        writeln('You prompt: '+CommandParams(line,1)+'='+CommandParams(line,0,1));
        ReadAndDoCommands(CommandParams(line,1)+'='+CommandParams(line,0,1));
      end;
    end
    else
    begin
      writeln('Prompt: Do Nothing');
    end;
  end
  else if(comm='MkDir') then //Create Directory
  begin
    if not(DirectoryExists(GetLocalDir+par)) then
    begin
      mkdir(GetLocalDir+par);
      writeln('Directory "',GetLocalDir+par,'" created.');
    end;
  end
  else if(comm='RmDir') then //Remove Directory
  begin
    if(DirectoryExists(GetLocalDir+par)) then
    begin
      rmdir(GetLocalDir+par);
      writeln('Directory "',GetLocalDir+par,'" removed.');
    end;
  end
  else if(comm='RmFile') then //Remove File
  begin
    if(FileExists(GetLocalDir+par)) then
    begin
      deletefile(PWChar(GetLocalDir+par));
      writeln('File "',GetLocalDir+par,'" removed.');
    end;
  end
  else if(comm='CopyFile') then //Copy File
  begin
    if(FileExists(GetLocalDir+CommandParams(line,0))) then
    begin
      if(FileExists(GetLocalDir+CommandParams(line,1))) then
      begin
        if(CommandParams(line,2)='overwrite') then
        begin
          CopyFile(PWChar(GetLocalDir+CommandParams(line,0)),PWChar(GetLocalDir+CommandParams(line,1)),false);
          writeln('File "',GetLocalDir+CommandParams(line,0),'" copied to "',GetLocalDir+CommandParams(line,1),'". autooverwrite');
        end
        else
        begin
          write('File "',GetLocalDir+CommandParams(line,1),'" already exists, overwrite? [y/n]: ');
          read(yn);
          readln;
          if(yn='y') then // if user type "y" it means "yes"
          begin
            CopyFile(PWChar(GetLocalDir+CommandParams(line,0)),PWChar(GetLocalDir+CommandParams(line,1)),false);
            writeln('File "',GetLocalDir+CommandParams(line,0),'" copied to "',GetLocalDir+CommandParams(line,1),'".');
          end
          else
          begin
            writeln('OK');
          end;
        end;
      end
      else
      begin
        CopyFile(PWChar(GetLocalDir+CommandParams(line,0)),PWChar(GetLocalDir+CommandParams(line,1)),false);
        writeln('File "',GetLocalDir+CommandParams(line,0),'" copied to "',GetLocalDir+CommandParams(line,1),'".');
      end;
    end
    else
    begin
      writeln('File "',GetLocalDir+CommandParams(line,0),'" copied to "',GetLocalDir+CommandParams(line,1),'" failed! File "',CommandParams(line,0),'" doesn�t exists!');
    end;
  end
  else if(comm='Execute') then
  begin
    if(FileExists(GetLocalDir+CommandParams(line,0))) then
    begin
      if(GetWinVersion=wvWinVista) then
      begin
        ShellExecute(Handle,'runas',PWChar(GetLocalDir+CommandParams(line,0)),PWChar(StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase])),PWChar(GetLocalDir),1);
        writeln('File "',CommandParams(line,0),'" executed as admin with "',StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase]),'" parameters.');
      end
      else
      begin
        ShellExecute(Handle,'open',PWChar(GetLocalDir+CommandParams(line,0)),PWChar(StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase])),PWChar(GetLocalDir),1);
        writeln('File "',CommandParams(line,0),'" executed with "',StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase]),'" parameters.');
      end;
    end;
  end
  else if(comm='DownloadFile') then
  begin
    if(fileexists(GetLocalDir+CommandParams(line,1))) then
    begin
      if(CommandParams(line,2)='overwrite') then
      begin
        writeln('Downloading "',CommandParams(line,0),'" to "'+GetLocalDir+CommandParams(line,1),'" ... autooverwrite');
        CheckDirAndDownloadFile(CommandParams(line,0),CommandParams(line,1));
      end
      else
      begin
        write('File "',GetLocalDir+CommandParams(line,1),'" already exists, overwrite? [y/n]: ');
        read(yn);
        readln;
        if(yn='y') then // if user type "y" it means "yes"
        begin
          writeln('Downloading "',CommandParams(line,0),'" to '+GetLocalDir+CommandParams(line,1),'" ...');
          CheckDirAndDownloadFile(CommandParams(line,0),CommandParams(line,1));
        end;
      end;
    end
    else  //file does not exists
    begin
      writeln('Downloading "',CommandParams(line,0),'" to "'+GetLocalDir+CommandParams(line,1),'" ...');
      CheckDirAndDownloadFile(CommandParams(line,0),CommandParams(line,1));
    end;
    writeln('OK');
  end
  else if(comm='ZipExtract') then
  begin
    if(ZipHandler.IsValid(par)) then
    begin
      ZipHandler.ExtractZipFile(par,GetLocalPath+'geoos\');
      writeln('File "',par,'" extracted.');
    end
    else
    begin
      writeln('File "',par,'" is not valid zip file!');
    end;
  end
  else if(comm='ZipExtractTo') then
  begin
    if(ZipHandler.IsValid(CommandParams(line,0))) then
    begin
      ZipHandler.ExtractZipFile(CommandParams(line,0),GetLocalPath+CommandParams(line,1));
      writeln('File "',CommandParams(line,0),'" extracted to "',CommandParams(line,1),'".');
    end
    else
    begin
      writeln('File "',CommandParams(line,0),'" is not valid zip file!');
    end;
  end
  else
  begin
    writeln('Command "',comm,'" not found!');
    result:=false;
  end;
end;

function functions.init(): boolean;
begin
  CommandSplit1:=TStringList.Create();
  CommandSplit2:=TStringList.Create();
  ZipHandler:=TZipFile.Create();
end;

end.
