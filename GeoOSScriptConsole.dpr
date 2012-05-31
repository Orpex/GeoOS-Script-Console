program GeoOSScriptConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,     //basic utils
  Classes,      //some useful classes
  Registry,     //implement Windows registry
  Windows,      //declaration and etc., useful for us
  WinINet,      //http library for downloading
  IdAntiFreeze, //indy antifreeze library for stop freezen application, when downloading
  shellapi,     //for accessing shells (in windows :D)
  StrUtils,     //some useful string functions, such as AnsiContainsStr
  Zip;          //for opening zip files

type TWinVersion = (wvUnknown, wvWin95, wvWin98, wvWin98SE, wvWinNT, wvWinME, wvWin2000, wvWinXP, wvWinVista);

var
  paramsraw:                  string;  // implement variables for recognition of
  params:                TStringList;  // program parameters (max up to 50 params)
  CommandSplit1:         TStringList;  // for spliting of commands (main - what is command, and what are parameters)
  CommandSplit2:         TStringList;  // for spliting of commands (minor - if multiple parameters, split them too)
  reg:                     TRegistry;  // variable for accessing Windows registry
  Handle:                       HWND;  // some handle variable for shellapi
  onlinedirectory:       TStringList;  // variable to hold online script list
  UserOptions:           TStringList;  // holds user options
  ZipHandler:               TZipFile;  // for accessing zip files

function GetWinVersion: TWinVersion; //taken from GeoOS_Main.exe
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

function FreeAll(): boolean;
begin
  reg.Free;             //release memory from using registry variable
  params.Free;          //release memory from using stringlist variable
  CommandSplit1.Free;   //release memory from using main split
  CommandSplit2.Free;   //release memory from using minor split
  onlinedirectory.Free; //release memory from using online directory list
  ZipHandler.Free;      //release memory from using zip handler
end;

function TerminateMe(): boolean;
begin
  FreeAll();
  Halt(0); //terminate program
end;

function DownloadFile(const url: string; const destinationFileName: string): boolean;
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

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings); // Split what we need
//thanks to RRUZ - http://stackoverflow.com/questions/2625707/delphi-how-do-i-split-a-string-into-an-array-of-strings-based-on-a-delimiter
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter     := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

function GetParams(): string; //gets all parameters
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

function LookUpForParams(): string; //Search, how many and what parameters are used
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

function SearchForSplitParam(param: string): boolean;
var index: integer;
begin
  index:=-1;  //because index cannot be negative
  index:=params.IndexOf(param);
  if not(index=-1) then //if index of given searched string isn't found, value of 'index' is still -1 (not found)
  begin
    result:=true; //param is found
  end
  else
  begin
    result:=false; //param is not found
  end;
end;

function GetInitIndex(param: char): integer; //gets index of -i or -i parameters (of ParamStrs)
var index: integer;
begin
  index:=-1;  //because index cannot be negative
  index:=params.IndexOf('-'+param);
  //we know, that it already exists, so there is no condition for: if index is not -1
  result:=index;
end;

function IsRemote(param: string): boolean; //Local -> false | Remote -> true
var
  split1: string;
  split2: string;
  split3: string;
begin
  split1:=param[1]+param[2]+param[3]+param[4]+param[5]+param[6]+param[7];
  split2:=param[1]+param[2]+param[3]+param[4]+param[5]+param[6]+param[7]+param[8];
  split3:=param[1]+param[2]+param[3]+param[4]+param[5]+param[6];
  if(split1='http://') then result:=true        //accepting http:// as remote
  else if(split2='https://') then result:=true  //accepting https:// as remote
  else if(split3='ftp://') then result:=true    //accepting ftp:// as remote
  else result:=false; //everything else is in local computer
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

function ReadCommand(str: string): string;
begin
  Split('=',str,CommandSplit1);
  result:=CommandSplit1[0];
end;

function CommandParams(str: string): string; overload;
begin
  Split('=',str,CommandSplit1);
  result:=CommandSplit1[1];
end;

function CommandParams(str: string; index: integer): string; overload;
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

function CommandParams(str: string; index: integer; commandindex: integer): string; overload;
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

function RemoveAndReg(reg_loc: string): boolean;
var
  i: integer;
  CommandSplit3: TStringList;
begin
  CommandSplit3.Create();
  //reg.OpenKey(reg_loc,false);
  //Split('|',reg.ReadString('Sum'),CommandSplit3); for removing, not yet implemented
  CommandSplit3.Free;
  //reg.CloseKey;
  reg.DeleteKey(reg_loc);
end;

function CheckDirAndDownloadFile(url: string; path: string): boolean;
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

function ReadAndDoCommands(line: string): boolean; //the most important function!
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
    writeln('Script´s Author: ',par);
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
      writeln('File "',GetLocalDir+CommandParams(line,0),'" copied to "',GetLocalDir+CommandParams(line,1),'" failed! File "',CommandParams(line,0),'" doesn´t exists!');
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

function Install(path: string): boolean; overload;
var
  f: Text;
  line: string;
begin
  Assign(f,path);
  reset(f);
  readln(f,line);
  reset(f);
  if(ReadCommand(line)='ScriptName') then
  begin
    if(reg.KeyExists('Software\GeoOS-Script\'+CommandParams(line))) then //if exists -> update
    begin
      RemoveAndReg('Software\GeoOS-Script\'+CommandParams(line)); //delete previosly version
    end;
    repeat
      readln(f,line);
      ReadAndDoCommands(line);
    until EOF(f);
    reg.OpenKey('Software\GeoOS-Script\'+CommandParams(line),true);
    reg.WriteString('Sum',paramsraw);
    reg.WriteString('InstallDir',GetLocalDir);
    reg.CloseKey;
    writeln('--- END ---');
  end
  else
  begin
    writeln('Invalid Script Name!');
  end;
  close(f);
end;

function Install(path: string; temp: boolean): boolean; overload; // determinates, if installing script is in 'temporary' mode
var
  f: Text;
  line: string;
begin
  if(temp=true) then //if not, its normal install
  begin
    Assign(f,path);
    reset(f);
    readln(f,line);
    close(f);
    if(ReadCommand(line)='ScriptName') then
    begin
      CopyFile(PWChar(path),PWChar(GetLocalDir+CommandParams(line)+'.gos'),false);
      DeleteFile(PWChar(path));
      Install(GetLocalDir+CommandParams(line)+'.gos');
    end
    else
    begin
      writeln('Invalid script!');
      readln;
    end;
  end
  else
  begin
    Install(path);
  end;
end;

function Remove(path: string): boolean; overload;
var
  f: Text;
  line: string;
begin
  Assign(f,path);
  reset(f);
  repeat
    readln(f,line);
    writeln(line);
  until EOF(f);
  close(f);
end;

function Remove(path: string; temp: boolean): boolean; overload; // determinates, if removing script is in 'temporary' mode
var
  f: Text;
  line: string;
begin
  if(temp=true) then //if not, its normal remove
  begin
    Assign(f,path);
    reset(f);
    readln(f,line);
    close(f);
    if(ReadCommand(line)='ScriptName') then
    begin
      CopyFile(PWChar(path),PWChar(GetLocalDir+CommandParams(line)),false);
      DeleteFile(PWChar(path));
      Remove(GetLocalDir+CommandParams(line));
    end
    else
    begin
      writeln('Invalid script!');
      readln;
    end;
  end
  else
  begin
    Remove(path);
  end;
end;

function SetOption(option: string; value: string): boolean;
begin
  result:=false;
  reg.OpenKey('Software\GeoOS-Script\Options\',true);
  reg.WriteString(option,value);
  if(reg.ValueExists(option)) then
  begin
    result:=true;
  end;
  reg.CloseKey;
end;

function GetOption(option: string): string;
begin
  if(reg.KeyExists('Software\GeoOS-Script\Options\')) then
  begin
    reg.OpenKey('Software\GeoOS-Script\Options\',false);
    if(reg.ValueExists(option)) then
    begin
      result:=reg.ReadString(option);
    end
    else
    begin
      result:='';
    end;
    reg.CloseKey;
  end;
end;

function GetOptions(): boolean;
begin
  if(reg.KeyExists('Software\GeoOS-Script\Options\')) then
  begin
    result:=true;
  end
  else
  begin
    result:=false;
  end;
end;

function init(): boolean;
begin
  paramsraw:='';
  params:=TStringList.Create();
  CommandSplit1:=TStringList.Create();
  CommandSplit2:=TStringList.Create();
  // initialize registry variable
  reg:=TRegistry.Create();
  reg.RootKey:=HKEY_CURRENT_USER;
  UserOptions:=TStringList.Create();
  if(GetOptions()) then
  begin
    writeln('User options loaded.');
  end;
  onlinedirectory:=TStringList.Create();
  paramsraw:=LookUpForParams(); //Main initializon for parameters... what to do and everything else
  if(empty(paramsraw)) then //If program didn't find any parameters
  begin
    write('Write Parameters: ');
    read(paramsraw);
    readln;
    paramsraw:=StringReplace(paramsraw,' ','|',[rfReplaceAll, rfIgnoreCase]);
  end;
  Split('|',paramsraw,params); //Get every used param
  if(reg.KeyExists('Software\GeoOS-Script\')) then
  begin
    reg.OpenKey('Software\GeoOS-Script\',false);
  end
  else
  begin
    reg.CreateKey('Software\GeoOS-Script\');
    reg.OpenKey('Software\GeoOS-Script\',false);
  end;
  // end of inicializing of registry variable
  ZipHandler:=TZipFile.Create();
end;

function InsertGos(str: string): string;  //for online database
begin
  if(AnsiContainsStr(LowerCase(str),'.gos')) then
  begin
    result:=str;
  end
  else
  begin
    result:=str+'.gos';
  end;
end;

begin
  writeln('GeoOS Script in Console starting...'); // Starting of program, simple message
  // initialize needed variables
  init();
  // Now we need if it would be an install (or update) or uninstall (remove or downgrade)
  if(SearchForSplitParam('-i') and not(SearchForSplitParam('-r'))) then
  begin
    //Install script or update (-i means install)
    //If -r (-r means remove) is found too, params are incorrect
    if(IsRemote(params[GetInitIndex('i')+1])) then
    begin
      //initialize download -not fully implemented
      DownloadFile(params[GetInitIndex('i')+1],GetLocalDir+'tmpscript.gos');
      if(FileExists(GetLocalDir+'tmpscript.gos')) then
      begin
        writeln('Script downloaded!');
        Install(GetLocalDir+'tmpscript.gos',true);
      end
      else
      begin
        writeln('Script not found!');
      end;
    end
    else // parameter after -i is local? check it
    begin
      if(FileExists(params[GetInitIndex('i')+1])) then
      begin
        //file exists in computer
        Install(params[GetInitIndex('i')+1]);
      end
      else if(FileExists(GetLocalDir+ParamStr(GetInitIndex('i')+1))) then
      begin
        //file exists in local directory
        Install(GetLocalDir+params[GetInitIndex('i')+1]);
      end
      else
      begin
        //local file not found, try online directory
        DownloadFile('http://geodar.hys.cz/geoos/list.goslist',GetLocalDir+'list.goslist');
        if(FileExists(GetLocalDir+'list.goslist')) then //check if was downloading complete
        begin
          onlinedirectory.LoadFromFile(GetLocalDir+'list.goslist');
          DeleteFile(PWChar(GetLocalDir+'list.goslist')); //save hard drive, 'lol'
          writeln('Reading online directory, found ',onlinedirectory.Count,' scripts.');
          if not(onlinedirectory.IndexOf(InsertGos(params[GetInitIndex('i')+1]))=-1) then
          begin
            //is found, download
            DownloadFile('http://geodar.hys.cz/geoos/'+InsertGos(params[GetInitIndex('i')+1]),GetLocalDir+InsertGos(params[GetInitIndex('i')+1]));
            if(FileExists(GetLocalDir+InsertGos(params[GetInitIndex('i')+1]))) then
            begin
              writeln('Script downloaded from online directory!');
              Install(GetLocalDir+InsertGos(params[GetInitIndex('i')+1]));
            end
            else
            begin
              writeln('Download from online directory failed.');
              readln;
              TerminateMe(); //free memory and terminate program
            end;
          end
          else
          begin
            writeln('Script doesn´t exists!');
          end;
        end
        else
        begin
          writeln('Cannot fetch online directory!');
        end;
      end;
    end;
  end
  else if(SearchForSplitParam('-r') and not(SearchForSplitParam('-i'))) then
  begin
    //Remove script or downgrade (-r means remove)
    //If -i (-i means install) is found too, params are incorrect
    if(IsRemote(params[GetInitIndex('r')+1])) then
    begin
      //initialize download -not fully implemented
      DownloadFile(params[GetInitIndex('r')+1],GetLocalDir+'tmpscript.gos');
      if(FileExists(GetLocalDir+'tmpscript.gos')) then
      begin
        writeln('Script downloaded!');
        Remove(GetLocalDir+'tmpscript.gos',true);
      end
      else
      begin
        writeln('Script not found!');
      end;
    end
    else // parameter after -i is local? check it
    begin
      if(FileExists(params[GetInitIndex('r')+1])) then
      begin
        //file exists in computer
        Remove(params[GetInitIndex('r')+1]);
      end
      else if(FileExists(GetLocalDir+ParamStr(GetInitIndex('r')+1))) then
      begin
        //file exists in local directory
        Remove(GetLocalDir+params[GetInitIndex('r')+1]);
      end
      else
      begin
        //local file not found, try online directory
        DownloadFile('http://geodar.hys.cz/geoos/list.goslist',GetLocalDir+'list.goslist');
        if(FileExists(GetLocalDir+'list.goslist')) then //check if was downloading complete
        begin
          onlinedirectory.LoadFromFile(GetLocalDir+'list.goslist');
          DeleteFile(PWChar(GetLocalDir+'list.goslist')); //save hard drive, 'lol'
          writeln('Reading online directory, found ',onlinedirectory.Count,' scripts.');
          if not(onlinedirectory.IndexOf(InsertGos(params[GetInitIndex('r')+1]))=-1) then
          begin
            //is found, download
            DownloadFile('http://geodar.hys.cz/geoos/'+InsertGos(params[GetInitIndex('r')+1]),GetLocalDir+InsertGos(params[GetInitIndex('r')+1]));
            if(FileExists(GetLocalDir+InsertGos(params[GetInitIndex('r')+1]))) then
            begin
              writeln('Script downloaded from online directory!');
              Remove(GetLocalDir+InsertGos(params[GetInitIndex('r')+1]));
            end
            else
            begin
              writeln('Download from online directory failed.');
              readln;
              TerminateMe(); //free memory and terminate program
            end;
          end
          else
          begin
            writeln('Script doesn´t exists!');
          end;
        end
        else
        begin
          writeln('Cannot fetch online directory!');
        end;
      end;
    end;
  end
  else if(SearchForSplitParam('-o')) then
  begin
    //set options
    if(SetOption(params[GetInitIndex('o')+1],params[GetInitIndex('o')+2])) then
    begin
      writeln('Option set!');
    end
    else
    begin
      writeln('Failed to save data to the registry!');
    end;
  end
  else if(SearchForSplitParam('-c')) then
  begin
    //use simple command
    if(ReadAndDoCommands(params[GetInitIndex('c')+1])) then
    begin
      writeln('Executed');
    end
    else
    begin
      writeln('Not executed');
    end;
  end
  else if(SearchForSplitParam('-i') and SearchForSplitParam('-r')) then
  begin
    writeln('Parameters are incorrect! Found both -i and -r!');
    readln;
    TerminateMe(); //free memory and terminate program
  end
  else
  begin
    writeln('Parameters are incorrect! Parameters -i or -r weren´t recognized!');
    readln;
    TerminateMe(); //free memory and terminate program
  end;
  FreeAll();
  // THE END
  readln;
end.