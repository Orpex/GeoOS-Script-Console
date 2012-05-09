program GeoOSScriptConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,     //basic utils
  Classes,      //some useful classes
  Registry,     //implement Windows registry
  Windows,      //declaration and etc., useful for us
  IdHTTP,       //indy http library for download
  IdAntiFreeze, //indy antifreeze library for stop freezen application, when downloading
  shellapi;     //for accessing shells (in windows :D)

var
  paramsraw: string;                   // implement variables for recognition of
  params: TStringList;                 // program parameters (max up to 50 params)
  CommandSplit1: TStringList;          // for spliting of commands (main - what is command, and what are parameters)
  CommandSplit2: TStringList;          // for spliting of commands (minor - if multiple parameters, split them too)
  reg: TRegistry;                      // variable for accessing Windows registry
  fIDHTTP: TIdHTTP;                    // variable for downloading
  antifreeze: TIdAntiFreeze;           // variable for stopping freezing application, when download
  Handle: HWND;                        // some handle variable for shellapi

function DownloadFile( const aSourceURL: String;
                   const aDestFileName: String): boolean;
var
  Stream: TMemoryStream;
begin
  Result := FALSE;
  fIDHTTP := TIDHTTP.Create;
  fIDHTTP.HandleRedirects := TRUE;
  fIDHTTP.AllowCookies := FALSE;
  fIDHTTP.Request.UserAgent := 'Mozilla/4.0';
  fIDHTTP.Request.Connection := 'Keep-Alive';
  fIDHTTP.Request.ProxyConnection := 'Keep-Alive';
  fIDHTTP.Request.CacheControl := 'no-cache';
  //fIDHTTP.OnWork:=IdHTTPWork;
  //fIDHTTP.OnWorkBegin:=IdHTTPWorkBegin;           //this will be for download status -> not needed now
  //fIDHTTP.OnWorkend:=IdHTTPWorkEnd;

  Stream := TMemoryStream.Create;
  try
    try
      fIDHTTP.Get(aSourceURL, Stream);
      if FileExists(aDestFileName) then
        DeleteFile(PWideChar(aDestFileName));
      Stream.SaveToFile(aDestFileName);
      Result := TRUE;
    except
      On E: Exception do
        begin
          Result := FALSE;
        end;
    end;
  finally
    Stream.Free;
    fIDHTTP.Free;
  end;
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
  //split2: string;
  split3: string;
begin
  split1:=param[1]+param[2]+param[3]+param[4]+param[5]+param[6]+param[7];
  //split2:=param[1]+param[2]+param[3]+param[4]+param[5]+param[6]+param[7]+param[8]; //SSL not supported
  split3:=param[1]+param[2]+param[3]+param[4]+param[5]+param[6];
  if(split1='http://') then result:=true        //accepting http:// as remote
  //else if(split2='https://') then result:=true  //accepting https:// as remote
  else if(split3='ftp://') then result:=true    //accepting ftp:// as remote
  else result:=false; //everything else is in local computer
end;

function empty(str: string): boolean;
begin
  if(str='') then result:=true
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

function ReadAndDoCommands(line: string): string; //the most important function!
var
  comm,par: string;
  yn: char;
begin
  comm:=ReadCommand(line);
  par:=CommandParams(line);
  if(comm='ScriptName') then
  begin
    writeln('Script name: ',par);
  end
  else if(comm='Author') then
  begin
    writeln('Script´s Author: ',par);
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
  else if(comm='Execute') then
  begin
    if(FileExists(GetLocalDir+CommandParams(line,0))) then
    begin
      ShellExecute(Handle,'open',PWChar(GetLocalDir+CommandParams(line,0)),PWChar(StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase])),PWChar(GetLocalDir),1);
      writeln('File "',CommandParams(line,0),'" executed with "',StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase]),'" parameters.');
    end;
  end
  else if(comm='ExecuteAdmin') then
  begin
    if(FileExists(GetLocalDir+CommandParams(line,0))) then
    begin
      ShellExecute(Handle,'runas',PWChar(GetLocalDir+CommandParams(line,0)),PWChar(StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase])),PWChar(GetLocalDir),1);
      writeln('File "',CommandParams(line,0),'" executed as admin with "',StringReplace(CommandParams(line,1),'_',' ', [rfReplaceAll, rfIgnoreCase]),'" parameters.');
    end;
  end
  else if(comm='DownloadFile') then
  begin
    if(fileexists(GetLocalDir+CommandParams(line,1))) then
    begin
      if(CommandParams(line,2)='overwrite') then
      begin
        writeln('Downloading "',CommandParams(line,0),'" to "'+GetLocalDir+CommandParams(line,1),'" ... autooverwrite');
        DownloadFile(CommandParams(line,0),GetLocalDir+CommandParams(line,1)); //not check for directory created, see MkDir
      end
      else
      begin
        write('File "',GetLocalDir+CommandParams(line,1),'" already exists, overwrite? [y/n]: ');
        read(yn);
        if(yn='y') then // if user type "y" it means "yes"
        begin
          writeln('Downloading "',CommandParams(line,0),'" to '+GetLocalDir+CommandParams(line,1),'" ...');
          DownloadFile(CommandParams(line,0),GetLocalDir+CommandParams(line,1)); //not check for directory created, see MkDir
        end;
        readln;
      end;
    end
    else  //file does not exists
    begin
      writeln('Downloading "',CommandParams(line,0),'" to "'+GetLocalDir+CommandParams(line,1),'" ...');
      DownloadFile(CommandParams(line,0),GetLocalDir+CommandParams(line,1)); //not check for directory created, see MkDir
    end;
    writeln('OK');
  end
  else
  begin
    writeln('Command "',comm,'" not found!');
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
    writeln('Script completed!');
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
      CopyFile(PWChar(path),PWChar(GetLocalDir+CommandParams(line)+'.gos'),true);
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

function init(): boolean;
begin
  paramsraw:='';
  params:=TStringList.Create();
  CommandSplit1:=TStringList.Create();
  CommandSplit2:=TStringList.Create();
  paramsraw:=LookUpForParams(); //Main initializon for parameters... what to do and everything else
  if(empty(paramsraw)) then //If program didn't find any parameters
  begin
    write('No parameters detected, write one now: ');
    read(paramsraw);
    readln;
    paramsraw:=StringReplace(paramsraw,' ','|',[rfReplaceAll, rfIgnoreCase]);
  end;
  Split('|',paramsraw,params); //Get every used param
  // initialize registry variable
  reg:=TRegistry.Create();
  reg.RootKey:=HKEY_CURRENT_USER;
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
  // initialize indys
  fIDHTTP:=TIdHTTP.Create();
  antifreeze:=TIdAntiFreeze.Create();
end;

function FreeAll(): boolean;
begin
  reg.Free;           //release memory from using registry variable
  params.Free;        //release memory from using stringlist variable
  CommandSplit1.Free; //release memory from using main split
  CommandSplit2.Free; //release memory from using minor split
  //indy http lybrary is freed on every use of DownloadFile();
  antifreeze.Free;
end;

begin
  writeln('Starting...'); // Starting of script
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
        //local file not found, parameter for file is incorrect
        writeln('Parameters are incorrect! Not found proper .gos link!');
        readln;
        exit; //terminate program
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
        //local file not found, parameter for file is incorrect
        writeln('Parameters are incorrect! Not found proper .gos link!');
        readln;
        exit; //terminate program
      end;
    end;
  end
  else if(SearchForSplitParam('-i') and SearchForSplitParam('-r')) then
  begin
    writeln('Parameters are incorrect! Found both -i and -r!');
    readln;
    exit; //terminate program
  end
  else
  begin
    writeln('Parameters are incorrect! Parameters -i or -r weren´t recognized!');
    readln;
    exit; //terminate program
  end;
  FreeAll();
  // THE END
  readln;
end.