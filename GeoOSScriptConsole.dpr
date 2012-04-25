program GeoOSScriptConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,  //Only for Windows
  Classes; //Contains several Useful things

var
  paramsraw: string;        // implement variables for recognition
  params: TStringList;      // of program parameters (max up to 50 params)

procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings); // Split what we need
//thanks to RRUZ - http://stackoverflow.com/questions/2625707/delphi-how-do-i-split-a-string-into-an-array-of-strings-based-on-a-delimiter
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter     := Delimiter;
   ListOfStrings.DelimitedText := Str;
end;

function SearchForParam(param: string): boolean; //If searched parameter is in command line
//not needed right now
var i: integer;
begin
for i:=1 to ParamCount() do
  begin
    if(ParamStr(i)=param) then
    begin
      result:=true;
    end
    else
    begin
      result:=false;
    end;
  end;
end;

function GetParams(): string; //gets all params
//needs to be proper implemented
var
  returnstr: string;
begin
returnstr:='';
for i:=1 to  do

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
  index:=-1;  //because index cannot be negative numbers
  params.Find(param,index);
  if not(index=-1) then //if index of given searched string isn't find, value of 'index' isn't changed
  begin
    result:=true; //param is found
  end
  else
  begin
    result:=false; //param is not found
  end;
end;

begin
  writeln('Starting...'); // Starting of script
  paramsraw:=LookUpForParams(); //Main initializon for parameters... what to do and everything els
  Split('|',paramsraw,params); //Get every param used
  // Now we need if it would be an install (or update) or uninstall (remove or downgrade)
  if(SearchForSplitParam('-i') and not(SearchForSplitParam('-r'))) then
  begin
    //Install script or update (-i means install)
    //If -r (-r means remove) is found too, params are incorrect

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
  writeln('Completed!'); // THE END
  readln;
end.
