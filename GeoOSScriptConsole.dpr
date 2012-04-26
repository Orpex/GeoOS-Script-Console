program GeoOSScriptConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils, //basic utils
  Classes,  //some useful classes
  Registry, //implement Windows registry
  Windows;  //declaration and etc., useful for us

var
  paramsraw: string;        // implement variables for recognition of
  params: TStringList;      // program parameters (max up to 50 params)
  reg: TRegistry;           // variable for accessing Windows registry

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
for i:=1 to ParamCount() do
begin
  returnstr:=returnstr+ParamStr(i)+'|';
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
  params.Find(param,index);
  if not(index=-1) then //if index of given searched string isn't found, value of 'index' is still -1
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
  params.Find('-'+param,index);
  //we know, that it already exists, so there is no condition for: if index is not -1
  result:=index;
end;

function IsRemote(param: string): boolean; //Local -> false | Remote -> true
begin
  if(param[1]+param[2]+param[3]+param[4]='http') then result:=true //accepting http:// and https:// as remotes
  else if(param[1]+param[2]+param[3]+param[4]='ftp') then result:=true //accepting ftp as remote
  else result:=false; //everything else is in local computer
end;

begin
  writeln('Starting...'); // Starting of script
  paramsraw:=LookUpForParams(); //Main initializon for parameters... what to do and everything else
  Split('|',paramsraw,params); //Get every param used
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
  // Now we need if it would be an install (or update) or uninstall (remove or downgrade)
  if(SearchForSplitParam('-i') and not(SearchForSplitParam('-r'))) then
  begin
    //Install script or update (-i means install)
    //If -r (-r means remove) is found too, params are incorrect
    if(IsRemote(ParamStr(GetInitIndex('i')))) then
    begin

    end
    else // parameter after -i is local? check it
    begin
      {if(FileExists()) then
      begin
        //file exists
      end
      else
      begin
        //local file not found, parameter for file is incorrect
      end;}
    end;
  end
  else if(SearchForSplitParam('-r') and not(SearchForSplitParam('-i'))) then
  begin
    //Remove script or downgrade (-r means remove)
    //If -i (-i means install) is found too, params are incorrect

  end
  else
  begin
    writeln('Parameters are incorrect! Found both -i and -r!');
    exit; //terminate program
  end;
  reg.Free; //release memory from using registry variable
  writeln('Completed!'); // THE END
  readln;
//wtf
end.