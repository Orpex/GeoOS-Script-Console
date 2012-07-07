program GeoOSScriptConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,                                           // basic utils
  Classes,                                            // some useful classes
  Registry,                                           // implement Windows registry
  Windows,                                            // declaration and etc., useful for us
  WinINet,                                            // http library for downloading files
  shellapi,                                           // windows run scripts
  StrUtils,                                           // some useful string functions, such as AnsiContainsStr
  GeoOSScriptFunctions in 'GeoOSScriptFunctions.pas'; // functions file

var
  paramsraw:                            string;  // implement variables for recognition of
  params:                          TStringList;  // program parameters (max up to 50 params)
  reg:                               TRegistry;  // variable for accessing Windows registry
  onlinedirectory:                 TStringList;  // variable to hold online script list
  UserOptions:                     TStringList;  // holds user options
  p:                                   integer;  // variable for main program cycles
  gfunctions:   GeoOSScriptFunctions.functions;  // load functions to program

function FreeAll(): boolean;
begin
  gfunctions.FreeAll();
  reg.Free;             //release memory from using registry variable
  params.Free;          //release memory from using stringlist variable
  onlinedirectory.Free; //release memory from using online directory list
  result:=true;
end;

function TerminateMe(): boolean;
begin
  FreeAll();
  gfunctions.TerminateMe();
  result:=true;
end;

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings); // Split what we need
//thanks to RRUZ - http://stackoverflow.com/questions/2625707/delphi-how-do-i-split-a-string-into-an-array-of-strings-based-on-a-delimiter
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter     := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

function SearchForSplitParam(param: string): boolean;
var index: integer;
begin
  index:=-1;  //because index cannot be negative
  index:=params.IndexOf(param);
  if not(index=-1) then //if index of given searched string isn't found, value of 'index' is still -1 (not found)
    result:=true //param is found
  else
    result:=false; //param is not found
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
begin
  if(MidStr(param,1,7)='http://') then result:=true        //accepting http:// as remote
  else if(MidStr(param,1,8)='https://') then result:=true  //accepting https:// as remote
  else if(MidStr(param,1,6)='ftp://') then result:=true    //accepting ftp:// as remote
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

function RemoveAndReg(reg_loc: string): boolean;
var
  CommandSplit3: TStringList;
begin
  CommandSplit3:=TStringList.Create();
  //reg.OpenKey(reg_loc,false);
  //Split('|',reg.ReadString('Sum'),CommandSplit3); for removing, not yet implemented
  CommandSplit3.Free;
  //reg.CloseKey;
  reg.DeleteKey(reg_loc);
  result:=true;
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
  if(gfunctions.ReadCommand(line)='scriptname') then
  begin
    if(reg.KeyExists('Software\GeoOS-Script\'+gfunctions.CommandParams(line))) then //if exists -> update
      RemoveAndReg('Software\GeoOS-Script\'+gfunctions.CommandParams(line)); //delete previosly version
    repeat
      readln(f,line);
      gfunctions.ReadAndDoCommands(line);
    until EOF(f);
    reg.OpenKey('Software\GeoOS-Script\'+gfunctions.CommandParams(line),true);
    reg.WriteString('Sum',paramsraw);
    reg.WriteString('InstallDir',GetLocalDir);
    reg.CloseKey;
    writeln('--- END ---');
  end
  else
    writeln('Invalid Script Name!');
  close(f);
  result:=true;
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
    if(gfunctions.ReadCommand(line)='scriptname') then
    begin
      CopyFile(PWChar(path),PWChar(GetLocalDir+gfunctions.CommandParams(line)+'.gos'),false);
      DeleteFile(PWChar(path));
      Install(GetLocalDir+gfunctions.CommandParams(line)+'.gos');
    end
    else
    begin
      writeln('Invalid script!');
      readln;
    end;
  end
  else
    Install(path);
  result:=true;
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
  result:=true;
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
    if(gfunctions.ReadCommand(line)='scriptname') then
    begin
      CopyFile(PWChar(path),PWChar(GetLocalDir+gfunctions.CommandParams(line)),false);
      DeleteFile(PWChar(path));
      Remove(GetLocalDir+gfunctions.CommandParams(line));
    end
    else
    begin
      writeln('Invalid script!');
      readln;
    end;
  end
  else
    Remove(path);
  result:=true;
end;

function SetOption(option: string; value: string): boolean;
begin
  result:=false;
  reg.OpenKey('Software\GeoOS-Script\Options\',true);
  reg.WriteString(option,value);
  if(reg.ValueExists(option)) then
    result:=true;
  reg.CloseKey;
end;

function GetOption(option: string): string;
begin
  if(reg.KeyExists('Software\GeoOS-Script\Options\')) then
  begin
    reg.OpenKey('Software\GeoOS-Script\Options\',false);
    if(reg.ValueExists(option)) then
      result:=reg.ReadString(option)
    else
      result:='';
    reg.CloseKey;
  end;
end;

function GetOptions(): boolean;
begin
  if(reg.KeyExists('Software\GeoOS-Script\Options\')) then
    result:=true
  else
    result:=false;
end;

function init(): boolean;
begin
  paramsraw:='';
  params:=TStringList.Create();
  //initialize registry variable
  reg:=TRegistry.Create();
  reg.RootKey:=HKEY_CURRENT_USER;
  UserOptions:=TStringList.Create();
  if(GetOptions()) then
    writeln('User options loaded.');
  onlinedirectory:=TStringList.Create();
  paramsraw:=gfunctions.LookUpForParams(); //Main initialization for parameters... what to do and everything else
  if(empty(paramsraw)) then //If program didn't find any parameters
  begin
    write('Write Parameters: ');
    read(paramsraw);
    readln;
    paramsraw:=StringReplace(paramsraw,' ','|',[rfReplaceAll, rfIgnoreCase]);
  end;
  Split('|',paramsraw,params); //Get every used param
  if(reg.KeyExists('Software\GeoOS-Script\')) then
    reg.OpenKey('Software\GeoOS-Script\',false)
  else
  begin
    reg.CreateKey('Software\GeoOS-Script\');
    reg.OpenKey('Software\GeoOS-Script\',false);
  end;
  // end of inicializing of registry variable
  gfunctions.init();
  result:=true;
end;

function InsertGos(str: string): string;  //for online database
begin
  if(AnsiContainsStr(LowerCase(str),'.gos')) then
    result:=str
  else
    result:=str+'.gos';
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
      gfunctions.DownloadFile(params[GetInitIndex('i')+1],GetLocalDir+'tmpscript.gos');
      if(FileExists(GetLocalDir+'tmpscript.gos')) then
      begin
        writeln('Script downloaded!');
        Install(GetLocalDir+'tmpscript.gos',true);
      end
      else
        writeln('Script not found!');
    end
    else // parameter after -i is local? check it
    begin
      if(FileExists(params[GetInitIndex('i')+1])) then //file exists in computer
        Install(params[GetInitIndex('i')+1])
      else if(FileExists(GetLocalDir+ParamStr(GetInitIndex('i')+1))) then //file exists in local directory
        Install(GetLocalDir+params[GetInitIndex('i')+1])
      else
      begin
        //local file not found, try online directory
        gfunctions.DownloadFile('http://geodar.hys.cz/geoos/list.goslist',GetLocalDir+'list.goslist');
        if(FileExists(GetLocalDir+'list.goslist')) then //check if was downloading complete
        begin
          onlinedirectory.LoadFromFile(GetLocalDir+'list.goslist');
          DeleteFile(PWChar(GetLocalDir+'list.goslist')); //save hard drive, 'lol'
          writeln('Reading online directory, found ',onlinedirectory.Count,' scripts.');
          if not(onlinedirectory.IndexOf(InsertGos(params[GetInitIndex('i')+1]))=-1) then
          begin
            //is found, download
            gfunctions.DownloadFile('http://geodar.hys.cz/geoos/'+InsertGos(params[GetInitIndex('i')+1]),GetLocalDir+InsertGos(params[GetInitIndex('i')+1]));
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
            writeln('Script doesn´t exists!');
        end
        else
          writeln('Cannot fetch online directory!');
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
      gfunctions.DownloadFile(params[GetInitIndex('r')+1],GetLocalDir+'tmpscript.gos');
      if(FileExists(GetLocalDir+'tmpscript.gos')) then
      begin
        writeln('Script downloaded!');
        Remove(GetLocalDir+'tmpscript.gos',true);
      end
      else
        writeln('Script not found!');
    end
    else // parameter after -i is local? check it
    begin
      if(FileExists(params[GetInitIndex('r')+1])) then //file exists in computer
        Remove(params[GetInitIndex('r')+1])
      else if(FileExists(GetLocalDir+ParamStr(GetInitIndex('r')+1))) then //file exists in local directory
        Remove(GetLocalDir+params[GetInitIndex('r')+1])
      else
      begin
        //local file not found, try online directory
        gfunctions.DownloadFile('http://geodar.hys.cz/geoos/list.goslist',GetLocalDir+'list.goslist');
        if(FileExists(GetLocalDir+'list.goslist')) then //check if was downloading complete
        begin
          onlinedirectory.LoadFromFile(GetLocalDir+'list.goslist');
          DeleteFile(PWChar(GetLocalDir+'list.goslist')); //save hard drive, 'lol'
          writeln('Reading online directory, found ',onlinedirectory.Count,' scripts.');
          if not(onlinedirectory.IndexOf(InsertGos(params[GetInitIndex('r')+1]))=-1) then
          begin
            //is found, download
            gfunctions.DownloadFile('http://geodar.hys.cz/geoos/'+InsertGos(params[GetInitIndex('r')+1]),GetLocalDir+InsertGos(params[GetInitIndex('r')+1]));
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
            writeln('Script doesn´t exists!');
        end
        else
          writeln('Cannot fetch online directory!');
      end;
    end;
  end
  else if(SearchForSplitParam('-o')) then
  begin
    //set options
    if(SetOption(params[GetInitIndex('o')+1],params[GetInitIndex('o')+2])) then
      writeln('Option set!')
    else
      writeln('Failed to save data to the registry!');
  end
  else if(SearchForSplitParam('-c') or SearchForSplitParam('-e')) then
  begin
    //use simple command
    if(SearchForSplitParam('-e')) then
    begin
      if(gfunctions.ReadAndDoCommands(params[GetInitIndex('e')+1])) then
        writeln('Executed')
      else
        writeln('Not executed');
    end
    else
    if(SearchForSplitParam('-c')) then
    begin
      if(gfunctions.ReadAndDoCommands(params[GetInitIndex('c')+1])) then
        writeln('Executed')
      else
        writeln('Not executed');
    end;
  end
  else if(SearchForSplitParam('-l')) then
  begin
    //list online directory
    gfunctions.DownloadFile('http://geodar.hys.cz/geoos/list.goslist',GetLocalDir+'list.goslist');
    if(FileExists(GetLocalDir+'list.goslist')) then //check if was downloading complete
    begin
      onlinedirectory.LoadFromFile(GetLocalDir+'list.goslist');
      DeleteFile(PWChar(GetLocalDir+'list.goslist')); //save hard drive, 'lol'
      writeln('Reading online directory, found ',onlinedirectory.Count,' scripts.');
      for p:=0 to onlinedirectory.Count-1 do
        writeln(onlinedirectory[p]);
      writeln('Reading online directory, found ',onlinedirectory.Count,' scripts.');
    end
    else
      writeln('Can´t read online directory!');
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