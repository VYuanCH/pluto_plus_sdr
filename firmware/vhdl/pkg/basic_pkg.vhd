library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package basic_pkg is
  function ceil_log2(n : positive) return natural;
  function ceil_divide(a : integer; b : integer) return integer;

end package;


package body basic_pkg is
  function ceil_log2(n : positive) return natural is
    variable result : natural := 0;
    variable value  : natural := n - 1;
  begin
    while value > 0 loop
        value := value / 2;
        result := result + 1;
    end loop;
    return result;
  end;
  function ceil_divide(a : integer; b : integer) return integer is
  begin
      return (a + b - 1) / b;
  end function;
end package body;

