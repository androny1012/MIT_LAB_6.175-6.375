import Multiplexer::*;

function Bit#(1) fa_sum(Bit#(1) a, Bit#(1) b, Bit#(1) c);
    return a ^ b ^ c;
endfunction

function Bit#(1) fa_carry(Bit#(1) a, Bit#(1) b, Bit#(1) c);
    return (a&b) | (a&c) | (b&c);
endfunction

// Exercise 4
// 使用提供的全加器的两个模块，构成4bit行波进位加法器
function Bit#(5) add4(Bit#(4) a, Bit#(4) b, Bit#(1) cin);
    Bit#(4) sum;
    Bit#(5) c = 0;
    c[0] = cin;
    for(Integer i = 0; i < 4; i = i + 1) begin
        sum[i] = fa_sum(a[i],b[i],c[i]);
        c[i+1] = fa_carry(a[i],b[i],c[i]);
    end
    return {c[4],sum};
endfunction

// 加法器是作为模块而不是函数实现的，并且加入了接口；通过使用模块，多个源可以使用相同的8位加法器
interface Adder8;
    method ActionValue#(Bit#(9)) sum(Bit#(8) a,Bit#(8) b, Bit#(1) c_in);
endinterface

module mkRCAdder(Adder8);
    method ActionValue#(Bit#(9)) sum(Bit#(8) a,Bit#(8) b,Bit#(1) c_in);
        let low = add4(a[3:0], b[3:0], c_in);
        let high = add4(a[7:4], b[7:4], low[4]);
        return { high, low[3:0] };
    endmethod
endmodule

// Exercise 5
// 实现4bit进位选择加法器
module mkCSAdder(Adder8);
    method ActionValue#(Bit#(9)) sum(Bit#(8) a,Bit#(8) b,Bit#(1) c_in);
        let low = add4(a[3:0], b[3:0], c_in);
        let high0 = add4(a[7:4], b[7:4], 1'b0);
        let high1 = add4(a[7:4], b[7:4], 1'b1);
        let high = multiplexer5(low[4], high0, high1);
        return { high, low[3:0] };
    endmethod
endmodule