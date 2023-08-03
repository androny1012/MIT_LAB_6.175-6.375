import Ehr::*;
import Vector::*;

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

// Exercise 1

module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              notEmptyP<- mkReg(False);
    Reg#(Bool)              notFullP <- mkReg(True);
    Bit#(TLog#(n))          size     = fromInteger(valueOf(n)-1);

    method Action enq (t x) if (notFullP);
        notEmptyP <= True;
        data[enqP] <= x;
        let nextEnqP = enqP + 1;
        if (nextEnqP > size) begin
            nextEnqP = 0;
        end
        if (nextEnqP == deqP) begin
            notFullP <= False;
        end
        enqP <= nextEnqP;
    endmethod

    method Action deq() if (notEmptyP);
        notFullP <= True;
        let nextDeqP = deqP + 1;
        if (nextDeqP > size) begin
            nextDeqP = 0;
        end
        if (nextDeqP == enqP) begin
            notEmptyP <= False;
        end
        deqP <= nextDeqP;
    endmethod

    method t first() if (notEmptyP);
        return data[deqP];
    endmethod

    method Bool notFull();
        return notFullP;
    endmethod

    method Bool notEmpty();
        return notEmptyP;
    endmethod

    method Action clear();
        deqP <= 0;
        enqP <= 0;
        notEmptyP <= False;
        notFullP <= True;
    endmethod

endmodule

// Exercise 2

// {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n))) enqP     <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP     <- mkEhr(0);
    Ehr#(3, Bool)           notEmptyP<- mkEhr(False);
    Ehr#(3, Bool)           notFullP <- mkEhr(True);
    Bit#(TLog#(n))          size     = fromInteger(valueOf(n)-1);

    // 0

    method Bool notEmpty();
        return notEmptyP[0];
    endmethod

    method t first() if (notEmptyP[0]);
        return data[deqP[0]];
    endmethod

    method Action deq() if (notEmptyP[0]);
        notFullP[0] <= True;
        let nextDeqP = deqP[0] + 1;
        if (nextDeqP > size) begin
            nextDeqP = 0;
        end
        if (nextDeqP == enqP[0]) begin
            notEmptyP[0] <= False;
        end
        deqP[0] <= nextDeqP;
    endmethod

    // 1

    method Bool notFull();
        return notFullP[1];
    endmethod

    method Action enq (t x) if (notFullP[1]);
        notEmptyP[1]  <= True;
        data[enqP[1]] <= x;
        let nextEnqP = enqP[1] + 1;
        if (nextEnqP > size) begin
            nextEnqP = 0;
        end
        if (nextEnqP == deqP[1]) begin
            notFullP[1] <= False;
        end
        enqP[1] <= nextEnqP;
    endmethod

    // 2

    method Action clear();
        deqP[2]     <= 0;
        enqP[2]     <= 0;
        notEmptyP[2]<= False;
        notFullP[2]  <= True;
    endmethod

endmodule

// Exercise 2

// {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Ehr#(2, t))  data     <- replicateM(mkEhrU());
    Ehr#(3, Bit#(TLog#(n))) enqP     <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP     <- mkEhr(0);
    Ehr#(3, Bool)           notEmptyP<- mkEhr(False);
    Ehr#(3, Bool)           notFullP <- mkEhr(True);
    Bit#(TLog#(n))          size     = fromInteger(valueOf(n)-1);

    // 0

    method Bool notFull();
        return notFullP[0];
    endmethod

    method Action enq (t x) if (notFullP[0]);
        notEmptyP[0] <= True;
        data[enqP[0]][0] <= x;
        let nextEnqP = enqP[0] + 1;
        if (nextEnqP > size) begin
            nextEnqP = 0;
        end
        if (nextEnqP == deqP[0]) begin
        notFullP[0] <= False;
        end
        enqP[0] <= nextEnqP;
    endmethod

    // 1

    method Bool notEmpty();
        return notEmptyP[1];
    endmethod

    method Action deq() if (notEmptyP[1]);
        notFullP[1] <= True;
        let nextDeqP = deqP[1] + 1;
        if (nextDeqP > size) begin
            nextDeqP = 0;
        end
        if (nextDeqP == enqP[1]) begin
            notEmptyP[1] <= False;
        end
        deqP[1] <= nextDeqP;
    endmethod

    method t first() if (notEmptyP[1]);
        return data[deqP[1]][1];
    endmethod

    // 2

    method Action clear();
        deqP[2] <= 0;
        enqP[2] <= 0;
        notEmptyP[2] <= False;
        notFullP[2] <= True;
    endmethod
endmodule

// Exercise 3

// {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data         <- replicateM(mkRegU());
    Ehr#(2, Bit#(TLog#(n))) enqP         <- mkEhr(0);
    Ehr#(2, Bit#(TLog#(n))) deqP         <- mkEhr(0);
    Ehr#(2, Bool)           notEmptyP    <- mkEhr(False);
    Ehr#(2, Bool)           notFullP     <- mkEhr(True);
    Ehr#(2, Bool)           req_deq      <- mkEhr(False);
    Ehr#(2, Maybe#(t))      req_enq      <- mkEhr(tagged Invalid);
    Bit#(TLog#(n))          size         = fromInteger(valueOf(n)-1);

    (*no_implicit_conditions, fire_when_enabled*) // 保证每个周期都fire
    rule canonicalize;
        // enq and deq
        if ((notFullP[0] && isValid(req_enq[1])) && (notEmptyP[0] && req_deq[1])) begin
            notEmptyP[0] <= True;
            notFullP[0] <= True;
            data[enqP[0]] <= fromMaybe(?, req_enq[1]);

            let nextEnqP = enqP[0] + 1;
            if (nextEnqP > size) begin
                nextEnqP = 0;
            end

            let nextDeqP = deqP[0] + 1;
            if (nextDeqP > size) begin
                nextDeqP = 0;
            end

            enqP[0] <= nextEnqP;
            deqP[0] <= nextDeqP;
            req_enq[1] <= tagged Invalid;
            req_deq[1] <= False;
        // deq only
        end else if (notEmptyP[0] && req_deq[1]) begin
            let nextDeqP = deqP[0] + 1;
            if (nextDeqP > size) begin
                nextDeqP = 0;
            end

            if (nextDeqP == enqP[0]) begin
                notEmptyP[0] <= False;
            end
            notFullP[0] <= True;
            deqP[0] <= nextDeqP;

            req_deq[1] <= False;
        // enq only
        end else if (notFullP[0] && isValid(req_enq[1])) begin
            let nextEnqP = enqP[0] + 1;
            if (nextEnqP > size) begin
                nextEnqP = 0;
            end

            if (nextEnqP == deqP[0]) begin
                notFullP[0] <= False;
            end
            notEmptyP[0] <= True;
            data[enqP[0]] <= fromMaybe(?, req_enq[1]);
            enqP[0] <= nextEnqP;

            req_enq[1] <= tagged Invalid;
        end

    endrule

    method Bool notFull();
        return notFullP[0];
    endmethod

    method Action enq (t x) if (notFullP[0]);
        req_enq[0] <= tagged Valid (x);
    endmethod

    method Bool notEmpty();
        return notEmptyP[0];
    endmethod

    method Action deq() if (notEmptyP[0]);
        req_deq[0] <= True;
    endmethod

    method t first() if (notEmptyP[0]);
        return data[deqP[0]];
    endmethod

    method Action clear();
        enqP[1] <= 0;
        deqP[1] <= 0;
        notEmptyP[1] <= False;
        notFullP[1] <= True;
    endmethod

endmodule
