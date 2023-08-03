import Vector::*;
import Complex::*;

import FftCommon::*;
// import Fifo::*;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

import MyFifo::*;

interface Fft;
    method Action enq(Vector#(FftPoints, ComplexData) in);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
endinterface


(* synthesize *)
module mkFftCombinational(Fft);
    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
    FIFOF#(Vector#(FftPoints, ComplexData)) inFifo  <- mkSizedFIFOF(100);
    FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkSizedFIFOF(100);
    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkMyBypassFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyBypassFifo;

    
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    rule doFft;
        inFifo.deq;
        Vector#(4, Vector#(FftPoints, ComplexData)) stage_data;
        stage_data[0] = inFifo.first;

        for (StageIdx stage = 0; stage < 3; stage = stage + 1) begin
            stage_data[stage + 1] = stage_f(stage, stage_data[stage]);
        end
        outFifo.enq(stage_data[3]);
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftInelasticPipeline(Fft);
    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;

    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkSizedFIFOF(10);
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkSizedFIFOF(10);

    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkLFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkLFIFOF;
    
    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkBypassFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkBypassFIFOF;

    // Fifo#(3,Vector#(FftPoints, ComplexData)) inFifo <- mkFifo;
    // Fifo#(3,Vector#(FftPoints, ComplexData)) outFifo <- mkFifo;

    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkMyConflictFifo();
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyConflictFifo();

    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkMyPipelineFifo();
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyPipelineFifo();

    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkMyBypassFifo();
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyBypassFifo();

    Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkMyCFFifo();
    Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyCFFifo();

    Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    Reg #(Maybe #( Vector#(FftPoints, ComplexData))) sReg1 <- mkRegU;
    Reg #(Maybe #( Vector#(FftPoints, ComplexData))) sReg2 <- mkRegU;

    Reg#(Bit#(32)) cycle_count <- mkReg(0);
    rule cycle_counter;
        $display("At: %d ", cycle_count);
        // $display("At: %d ,inFifo notFull : %d notEmpty : %d", cycle_count,inFifo.notFull,inFifo.notEmpty);
        cycle_count <= cycle_count + 1;
    endrule

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    rule doFft0;

        // At stage 0, doing the first bfly + permute stage.
        if(inFifo.notEmpty) begin
            sReg1 <= tagged Valid (stage_f(0, inFifo.first));
            inFifo.deq;
            $display("At: %d ,stage 0 get data", cycle_count);
        end
        else begin
            sReg1 <= tagged Invalid;
            $display("At: %d ,stage 0 no  data", cycle_count);
        end
    // endrule

    // rule doFft1;
        // At stage 1, doing the second bfly + permute
        case (sReg1) matches
            tagged Invalid: sReg2 <= tagged Invalid;
            tagged Valid .x: sReg2 <= tagged Valid stage_f(1, x);
        endcase
    // endrule
    // rule doFft2;
        // Last stage
        if (isValid(sReg2)) begin
            outFifo.enq(stage_f(2, fromMaybe(?, sReg2)));
        end
    endrule
    

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
        $display("At: %d ,inFifo enq", cycle_count);
    endmethod 

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        $display("At: %d ,outFifo deq", cycle_count);
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftElasticPipeline(Fft);
    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo1 <- mkFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo2 <- mkFifo;

    // 容量2?
    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo  <- mkFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo1   <- mkFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo2   <- mkFIFOF;

    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo  <- mkSizedFIFOF(100);
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkSizedFIFOF(100);
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo1   <- mkSizedFIFOF(100);
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo2   <- mkSizedFIFOF(100);

    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo  <- mkLFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkLFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo1   <- mkLFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo2   <- mkLFIFOF;

    // FIFOF#(Vector#(FftPoints, ComplexData)) inFifo  <- mkBypassFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkBypassFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo1   <- mkBypassFIFOF;
    // FIFOF#(Vector#(FftPoints, ComplexData)) fifo2   <- mkBypassFIFOF;
    
    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkMyConflictFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyConflictFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo1   <- mkMyConflictFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo2   <- mkMyConflictFifo;

    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkMyPipelineFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyPipelineFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo1   <- mkMyPipelineFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo2   <- mkMyPipelineFifo;

    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkMyBypassFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyBypassFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo1   <- mkMyBypassFifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) fifo2   <- mkMyBypassFifo;

    Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkMyCFFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyCFFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) fifo1   <- mkMyCFFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) fifo2   <- mkMyCFFifo;

    Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    Reg#(Bit#(32)) cycle_count <- mkReg(0);
    rule cycle_counter;
        // $display("At: %d ", cycle_count);
        // $display("At: %d ,inFifo notFull : %d notEmpty : %d", cycle_count,inFifo.notFull,inFifo.notEmpty);
        cycle_count <= cycle_count + 1;
    endrule

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    // You should use more than one rule
    rule stage0 if (inFifo.notEmpty && fifo1.notFull);
        fifo1.enq(stage_f(0, inFifo.first));
        inFifo.deq;
        // $display("At: %d ,stage 0 get data", cycle_count);
    endrule

    rule stage1 if (fifo1.notEmpty && fifo2.notFull);
        fifo2.enq(stage_f(1, fifo1.first));
        fifo1.deq;
        // $display("At: %d ,stage 1 get data", cycle_count);
    endrule

    rule stage2 if (fifo2.notEmpty && outFifo.notFull);
        outFifo.enq(stage_f(2, fifo2.first));
        fifo2.deq;
        // $display("At: %d ,stage 2 get data", cycle_count);
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        // $display("At: %d ,outFifo deq", cycle_count);
        return outFifo.first;
    endmethod
endmodule



// (* synthesize *)
// module mkFifoTest(Fft);

//     // Fifo#(3, int) inFifo <- mkMyBypassFifo();
//     Fifo#(3, int) inFifo <- mkMyCFFifo();

//     // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkMyCFFifo();
//     // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkMyCFFifo();


//     Reg#(Bit#(32)) cycle_count <- mkReg(0);
//     rule cycle_counter;
//         $display("At: %d ", cycle_count);
//         // $display("At: %d ,inFifo notFull : %d notEmpty : %d", cycle_count,inFifo.notFull,inFifo.notEmpty);
//         cycle_count <= cycle_count + 1;
//     endrule

//     rule doEnq;
//         inFifo.enq(0);
//         $display("At: %d ,inFifo enq", cycle_count);
//     endrule

//     rule doDeq;
//         inFifo.deq;
//         $display("At: %d ,inFifo deq", cycle_count);
//     endrule
    
    
//     method Action enq(Vector#(FftPoints, ComplexData) in);
//         // inFifo.enq(in);
//         // $display("At: %d ,inFifo enq", cycle_count);
//     endmethod 

//     method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
//         // outFifo.deq;
//         // $display("At: %d ,outFifo deq", cycle_count);
//         // return outFifo.first;
//         return ?;
//     endmethod
// endmodule