// import Vector::*;
// import FIFO::*;

// interface Fifo#(numeric type n, type t);
//     method Action enq(t x);
//     method Action deq;
//     method t first;
//     method Bool notEmpty;
//     method Bool notFull;
// endinterface

// // Exercise 1
// // 根据上述接口定义实现深度为3的FIFO

// // Maybe#(td) 是 BSV 预定义的一种多态类型，他能给任意类型（设类型名为 t）的数据附加上“是否有效”的信息。
// module mkFifo(Fifo#(3,t)) provisos (Bits#(t,tSz));

//     Reg#(Maybe#(t)) d[3];
//     for(Integer i = 0; i < 3; i = i + 1) begin
//         d[i] <- mkReg(tagged Invalid);
//     end

//     // 隐式条件，只有不满的时候能写FIFO
//    method Action enq(t x) if (!isValid (d[2]));
//         if (!isValid (d[0])) begin
//             d[0] <= tagged Valid x;
//         end
//         else if(!isValid (d[1])) begin
//             d[1] <= tagged Valid x;
//         end
//         else begin
//             d[2] <= tagged Valid x;
//         end
//    endmethod

//    // 隐式条件，只有不空的时候能弹FIFO
//    method Action deq() if (isValid (d[0]));
//        if (isValid (d[1])) begin
//            d[0] <= d[1];
//            d[1] <= d[2];
//            d[2] <= tagged Invalid;
//        end
//        else begin
//            d[0] <= tagged Invalid;
//        end
//    endmethod

//    // 指取第一个数，但不弹出，不空才能取
//    method t first() if (isValid (d[0]));
//        return fromMaybe (?, d[0]);
//    endmethod

//    method Bool notEmpty();
//        return isValid(d[0]);
//    endmethod

//    method Bool notFull();
//        return !isValid(d[2]);
//    endmethod
// endmodule



// // /////////////////
// // // Pipeline FIFO

// // module mkPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
// //     // n is size of fifo
// //     // t is data type of fifo
// //     Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
// //     Ehr#(2, Bit#(TLog#(n))) enqP     <- mkEhr(0);
// //     Ehr#(2, Bit#(TLog#(n))) deqP     <- mkEhr(0);
// //     Ehr#(3, Bool)           empty    <- mkEhr(True);
// //     Ehr#(3, Bool)           full     <- mkEhr(False);
// //     Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

// //     method Bool notFull = !full[1];

// //     method Action enq(t x) if( !full[1] );
// //         data[enqP[0]] <= x;
// //         empty[1] <= False;
// //         enqP[0] <= (enqP[0] == max_index) ? 0 : enqP[0] + 1;
// //         if( enqP[1] == deqP[1] ) begin
// //             full[1] <= True;
// //         end
// //     endmethod

// //     method Bool notEmpty = !empty[0];

// //     method Action deq if( !empty[0] );
// //         // Tell later stages a dequeue was requested
// //         full[0] <= False;
// //         deqP[0] <= (deqP[0] == max_index) ? 0 : deqP[0] + 1;
// //         if( deqP[1] == enqP[0] ) begin
// //             empty[0] <= True;
// //         end
// //     endmethod

// //     method t first if( !empty[0] );
// //         return data[deqP[0]];
// //     endmethod

// //     method Action clear;
// //         enqP[1] <= 0;
// //         deqP[1] <= 0;
// //         empty[2] <= True;
// //         full[2] <= False;
// //     endmethod
// // endmodule

// // ///////////////
// // // Bypass FIFO

// // module mkBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
// //     // n is size of fifo
// //     // t is data type of fifo
// //     Vector#(n, Ehr#(2,t))   data     <- replicateM(mkEhr(?));
// //     Ehr#(2, Bit#(TLog#(n))) enqP     <- mkEhr(0);
// //     Ehr#(2, Bit#(TLog#(n))) deqP     <- mkEhr(0);
// //     Ehr#(3, Bool)           empty    <- mkEhr(True);
// //     Ehr#(3, Bool)           full     <- mkEhr(False);
// //     Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

// //     method Bool notFull = !full[0];

// //     method Action enq(t x) if( !full[0] );
// //         data[enqP[0]][0] <= x;
// //         empty[0] <= False;
// //         enqP[0] <= (enqP[0] == max_index) ? 0 : enqP[0] + 1;
// //         if( enqP[1] == deqP[0] ) begin
// //             full[0] <= True;
// //         end
// //     endmethod

// //     method Bool notEmpty = !empty[1];

// //     method Action deq if( !empty[1] );
// //         // Tell later stages a dequeue was requested
// //         full[1] <= False;
// //         deqP[0] <= (deqP[0] == max_index) ? 0 : deqP[0] + 1;
// //         if( deqP[1] == enqP[1] ) begin
// //             empty[1] <= True;
// //         end
// //     endmethod

// //     method t first if( !empty[1] );
// //         return data[deqP[0]][1];
// //     endmethod

// //     method Action clear;
// //         enqP[1] <= 0;
// //         deqP[1] <= 0;
// //         empty[2] <= True;
// //         full[2] <= False;
// //     endmethod
// // endmodule