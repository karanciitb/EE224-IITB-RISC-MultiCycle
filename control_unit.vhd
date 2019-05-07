library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
  port (
	clock,reset: in std_logic;
	DatatoMem,MemWrite,IRWrite,RF_A1,RF_A2,RegWrite,RF_D1,ALUSrcA,PCWrite,ModifyC,ModifyZ: out std_logic;
	PCSelect,IorD,RF_A3,RF_D3,ALUSrcB,ALUControl: out std_logic_vector(1 downto 0);
	Opcode: in std_logic_vector(3 downto 0);
	LASACounter: out std_logic_vector(2 downto 0);
	InstrCZ: in std_logic_vector(1 downto 0);
	ALU_Z,ALU_C,BEQ_Z: in std_logic
  ) ;
end entity ; -- control_unit

architecture arch of control_unit is
type FsmState is (
RST,fetch,add_nand,beq_jal_jlr,jal_jlr,load_all_store_all,LW_SW,beq_zero,beq);

signal fsm_state: FsmState;
signal LASACounterOutput:std_logic_vector(2 downto 0); -- Counter for Load all and Store All
signal LASACountersig:integer:=0;
begin
pro : process(clock,reset,Opcode,fsm_state,InstrCZ)
variable MemWritevar,DatatoMemvar,IRWritevar,RF_A1var,RF_A2var,RegWritevar,RF_D1var,ALUSrcAvar,PCWritevar,ModifyCvar,ModifyZvar: std_logic;
variable PCSelectvar,IorDvar,RF_A3var,RF_D3var,ALUSrcBvar,ALUControlvar: std_logic_vector(1 downto 0);
variable LASACountervar: integer;
variable LASACounterOutputvar: std_logic_vector(2 downto 0);
variable next_fsm_state: FsmState;

begin
PCSelectvar:="00";
MemWritevar:='1';
IRWritevar:='0';
RF_A1var:='0';RF_A2var:='0';
RegWritevar:='0';
RF_D1var:='1';
ALUSrcAvar:='1';ALUSrcBvar:="00";
PCWritevar:='0';
ModifyCvar:='0';ModifyZvar:='0';
IorDvar:="00";
RF_A3var:="10";
RF_D3var:="11";
ALUControlvar:="00";
next_fsm_state:=fsm_state;
DatatoMemvar:='1';
LASACountervar:=LASACountersig;
case (fsm_state) is
	when RST =>
		PCSelectvar:="10";
		PCWritevar:='1';
		next_fsm_state:=fetch;
	when fetch =>
		ALUSrcAvar:='0';ALUSrcBvar:="11";--to update PC
		PCSelectvar:="00";PCWritevar:='1';
		IRWritevar:='1';

		if(Opcode ="0000") then -- ADD,ADC,ADZ
 		  	if(InstrCZ="10" and ALU_C='1') then --ADC
 		  		next_fsm_state:=add_nand;
 			elsif (InstrCZ="01" and ALU_Z='1') then --ADZ
 				next_fsm_state:=add_nand;
 			elsif (InstrCZ="00") then -- ADD
 				next_fsm_state:=add_nand;
 			end if;
 		elsif (Opcode="0010") then -- NDU,NDC,NDZ
 			if(InstrCZ="10" and ALU_C='1') then --NDC
 		  		next_fsm_state:=add_nand;
 			elsif (InstrCZ="01" and ALU_Z='1') then --NDZ
 				next_fsm_state:=add_nand;
 			elsif (InstrCZ="00") then --NDU
 				next_fsm_state:=add_nand;
 			end if;
 		elsif (Opcode="0001") then --ADI
 			next_fsm_state:=add_nand;
 		elsif (Opcode="1001" or Opcode="1000") then -- JLR or JAL
 			next_fsm_state:=beq_jal_jlr;
 		elsif (Opcode="0110" or Opcode="0111") then -- Load All & Store All
 			next_fsm_state:=load_all_store_all;
 			LASACountervar:= 0;
 			ALUSrcBvar:="11";
 		elsif (Opcode="0100" or Opcode="0101") then -- Load LW and Store SW
 			RF_A1var:='1';
 			next_fsm_state:=LW_SW;
 		elsif (Opcode="1100") then -- BEQ
 			next_fsm_state:=beq_zero;
		elsif (Opcode="0011") then -- LHI
			RegWritevar := '1'; 
	 		RF_D3var:="10";
	 		RF_A3var:="00";
	 	elsif (Opcode(3 downto 1)="101" or Opcode="1101" or Opcode(3 downto 1)="111") then -- unused opcodes
	 		next_fsm_state:= fetch;
		end if;
 	when add_nand =>
  		ModifyZvar:='1';ModifyCvar:='1';
  		RegWritevar:='1';
  		RF_D3var:="01";
 		RF_A3var:="01";
 		if(Opcode(1)='1') then -- NAND
 			ALUControlvar:="01";ModifyCvar:='0';
 		elsif (Opcode(0)='1') then -- ADI
 			ALUSrcBvar:="01"; -- else, ADD done by default variables
 		end if;
 		next_fsm_state:=fetch;
 	when beq_jal_jlr =>
 		ALUSrcAvar:='0';
 		ALUSrcBvar:="11";
 		ALUControlvar:="10";--subtract
 		RF_D1var:='0';
 		if (Opcode(2) = '1') then -- BEQ
 			next_fsm_state := beq;
 		else	
 			next_fsm_state := jal_jlr; -- JAL AND JLR
 		end if;	
 	when jal_jlr =>
 		RF_A3var:="00";
 		RegWritevar :='1';
 		if (Opcode(0) = '0') then -- JAL
 			ALUSrcBvar:="10";
 			PCWritevar:='1';
 			next_fsm_state := fetch;	
 		else
 		PCSelectvar:="01"; -- JLR
 		PCWritevar := '1';
 		next_fsm_state := fetch;
 		end if;	
 	when load_all_store_all =>
 		if(Opcode(0)='0') then
	 	 	RF_D3var := "00";
	 		RegWritevar :='1';
	 		RF_A3var := "11";
	 		RF_D1var :='0';
	 	else
	 		RF_A2var := '0';
	 	 	DatatoMemvar:='1';
	 	 	MemWritevar := '0';
	 	 	RF_D1var :='0';
	 	end if;

 		ALUSrcBvar := "11";
 		IorDvar :="10";
 		LASACounterOutputvar:=std_logic_vector(to_unsigned(LASACountervar,3));
 		LASACountervar:=LASACountervar + 1;
 		if(LASACountervar = 8) then
 			next_fsm_state :=fetch;
 		else
 			next_fsm_state :=load_all_store_all;
 		end if;	
 	when LW_SW=>
 		ALUSrcBvar:="01";
 		IorDvar:="11";
 		RF_D1var := '0';
 		if(Opcode(0) = '0') then
	 		ModifyZvar := '1';
	 		RF_D3var := "00"; -- LW
	 		RF_A3var :="00";
	 		RegWritevar:='1';
			next_fsm_state := fetch;
		else -- SW
			RF_A1var:='0';
			
	 		MemWritevar := '0';
	 		DatatoMemvar := '0';
	 		next_fsm_state := fetch;
		end if;
 	when beq_zero =>
 		ALUControlvar := "10";
 		if (BEQ_Z = '1') then
 			next_fsm_state := beq_jal_jlr;
 		else
 			next_fsm_state := fetch;	
 		end if;	
 	when beq=>
 		ALUSrcBvar := "01";
 		PCWritevar := '1';
 		PCSelectvar:="00";
 		next_fsm_state := fetch;	
	when others =>
		null;
end case;
	DatatoMem <= DatatoMemvar;
	PCSelect <= PCSelectvar;
	MemWrite <= MemWritevar;
	IRWrite <= IRWritevar;
	RF_A1 <= RF_A1var;
	RF_A2 <= RF_A2var;
	RegWrite <= RegWritevar;
	RF_D1 <= RF_D1var;
	ALUSrcA <= ALUSrcAvar;
	ALUSrcB <= ALUSrcBvar;
	PCWrite <= PCWritevar;
	IorD <= IorDvar;
	RF_A3 <= RF_A3var;
	RF_D3 <= RF_D3var;
	ALUControl <= ALUControlvar;
	ModifyC <= ModifyCvar;
	ModifyZ <= ModifyZvar;
	LASACounter<=LASACounterOutputvar;

if(rising_edge(clock)) then
	if(reset='1') then
	fsm_state<=RST;
else
	fsm_state<=next_fsm_state;
	LASACounterOutput<=LASACounterOutputvar;
	LASACountersig<=LASACountervar;
end if;
end if;
end process;
end architecture ; -- arch