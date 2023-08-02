//模块内可以调用function，每处调用都会实例化一个组合逻辑电路

function Bit#(1) multiplexer1_old(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    return (sel == 0)? a: b;
endfunction

function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a & b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a | b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~a;
endfunction

// Exercise 1
//使用上述提供的三个门复现multiplexer1

// —————————————————
// | a | b |sel|out|
// —————————————————
// | 0 | 0 | 0 | 0 |
// —————————————————
// | 0 | 0 | 1 | 0 |
// —————————————————
// | 0 | 1 | 0 | 0 |
// —————————————————
// | 0 | 1 | 1 | 1 |
// —————————————————
// | 1 | 0 | 0 | 1 |
// —————————————————
// | 1 | 0 | 1 | 0 |
// —————————————————
// | 1 | 1 | 0 | 1 |
// —————————————————
// | 1 | 1 | 1 | 1 |
// —————————————————

// and1作为门控，sel是对应的门控信号

function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    return or1(and1(not1(sel),a), and1(sel,b));
endfunction

// 可以看到，function在调用时，就像在调用函数一样，因为都是组合逻辑，无需考虑时序

// Exercise 2
// 使用 for 循环和多路复用器1 实现函数多路复用器5

// and5 参考代码
// for loop 在最终实现时就是全展开
function Bit#(5) and5(Bit#(5) a, Bit#(5) b); 
    Bit#(5) aggregate;
    for(Integer i = 0; i < 5; i = i + 1) begin
        aggregate[i] = and1(a[i], b[i]);
    end
    return aggregate;
endfunction

// Ex2 时取消注释
// function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b); 
//     Bit#(5) aggregate;
//     for(Integer i = 0; i < 5; i = i + 1) begin
//         aggregate[i] = multiplexer1(sel,a[i],b[i]);
//     end
//     return aggregate;
// endfunction

// 要求是必须用for loop
// function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b); 
//     Bit#(5) aggregate;
//     aggregate = (sel == 0)? a: b;
//     return aggregate;
// endfunction

// Exercise 3
// 使用多态特性，参数化输入输出位宽，不需要特定指定，会根据定义的输入输出位宽自动判别n

// n本身不是变量，需要用valueOf(n)
function Bit#(n) multiplexer_n(Bit#(1) sel, Bit#(n) a, Bit#(n) b); 
    Bit#(n) aggregate;
    for(Integer i = 0; i < valueOf(n); i = i + 1) begin
        aggregate[i] = multiplexer1(sel,a[i],b[i]);
    end
    return aggregate;
endfunction

function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
    return multiplexer_n(sel, a, b);
endfunction