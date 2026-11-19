--  { dg-do run }

procedure Enum6 is

  type Base_Enum is (Ten, Twenty);

  type Derived_Enum is new Base_Enum;
  for Derived_Enum use (Ten => 10, Twenty => 20);

  type Rep_Enum is (Ten, Twenty);
  for Rep_Enum use (Ten => 10, Twenty => 20);

  OK : Boolean := True;

begin
  for E in Base_Enum loop
    if (E = Ten and then Base_Enum'Image(E) /= "TEN")
      or else (E = Twenty and then Base_Enum'Image(E) /= "TWENTY")
    then
      OK := False;
    end if;
  end loop;

  for E in Derived_Enum loop
    if (E = Ten and then Derived_Enum'Image(E) /= "TEN")
       or else (E = Twenty and then Derived_Enum'Image(E) /= "TWENTY")
    then
      OK := False;
    end if;
  end loop;

  for E in Rep_Enum loop
    if (E = Ten and then Rep_Enum'Image(E) /= "TEN")
      or else (E = Twenty and then Rep_Enum'Image(E) /= "TWENTY")
    then
      OK := False;
    end if;
  end loop;

  if not OK then
    raise Program_Error;
  end if;
end;
