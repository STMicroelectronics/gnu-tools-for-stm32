-- { dg-do compile }

package body Task6 is

   task body T is
   begin
     accept E;
   end T;

   function Make return T is
   begin
     return Ret : T;
   end;

end Task6;
