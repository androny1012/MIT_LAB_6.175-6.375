import TestBenchTemplates::*;
import Multipliers::*;

// Example testbenches
(* synthesize *)
module mkTbDumb();
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_signed( a, b );
    Empty tb <- mkTbMulFunction(test_function, multiply_signed, True);
    return tb;
endmodule


(* synthesize *)
module mkTbFoldedMultiplier();
    Multiplier#(8) dut <- mkFoldedMultiplier();
    Empty tb <- mkTbMulModule(dut, multiply_unsigned, True);
    return tb;
endmodule

// Exercise 1
// 编写有符号乘法和无符号乘法对比的Tb
(* synthesize *)
module mkTbSignedVsUnsigned();
    function Bit#(16) test_function( Bit#(8) a, Bit#(8) b ) = multiply_signed( a, b );
    Empty tb <- mkTbMulFunction(test_function, multiply_unsigned, True);
    return tb;
endmodule

(* synthesize *)
module mkTbEx3();
    function Bit#(16) func(Bit#(8) a, Bit#(8) b) = multiply_by_adding(a, b);
    Empty tb <- mkTbMulFunction(func, multiply_unsigned, True);
    return tb;
endmodule

// Exercise 5
(* synthesize *)
module mkTbEx5();
    Multiplier#(8) mod <- mkFoldedMultiplier();
    Empty tb <- mkTbMulModule(mod, multiply_by_adding(), True);
    return tb;
endmodule

// Exercise 7
// 编写不同位宽的Tb
(* synthesize *)
module mkTbEx7a();
    Multiplier#(8) mod <- mkBoothMultiplier();
    Empty tb <- mkTbMulModule(mod, multiply_signed, True);
    return tb;
endmodule

(* synthesize *)
module mkTbEx7b();
    Multiplier#(16) mod <- mkBoothMultiplier();
    Empty tb <- mkTbMulModule(mod, multiply_signed, True);
    return tb;
endmodule

// Exercise 9
// 编写不同位宽的Tb
(* synthesize *)
module mkTbEx9a();
    Multiplier#(32) mod <- mkBoothMultiplierRadix4();
    Empty tb <- mkTbMulModule(mod, multiply_signed, True);
    return tb;
endmodule

(* synthesize *)
module mkTbEx9b();
    Multiplier#(64) mod <- mkBoothMultiplierRadix4();
    Empty tb <- mkTbMulModule(mod, multiply_signed, True);
    return tb;
endmodule
