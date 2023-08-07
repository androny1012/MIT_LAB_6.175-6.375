import Vector::*;
import FIFO::*;
import FixedPoint::*;

import AudioProcessorTypes::*;
// import FilterCoefficients::*;
import Multiplier::*;

// Problem 4 
module mkFIRFilter (Vector#(tnp1, FixedPoint#(16, 16)) coeffs, AudioProcessor ifc);
    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    Vector#(TSub#(tnp1, 1), Reg#(Sample)) r <- replicateM(mkReg(0));

    Vector#(tnp1 , Multiplier) multiplier <- replicateM(mkMultiplier());


    rule mul_step;
        let sample = infifo.first();
        infifo.deq();

        r[0] <= sample;
        for (Integer i = 0; i < valueOf(tnp1) - 2; i = i + 1) begin
            r[i + 1] <= r[i];
        end 

        multiplier[0].putOperands(coeffs[0], sample);
        for (Integer i = 0; i < valueOf(tnp1) - 1; i = i + 1) begin
            multiplier[i + 1].putOperands(coeffs[i + 1], r[i]);
        end
    endrule 

    rule acc_out ;
        Vector#(tnp1, FixedPoint#(16, 16)) acc;

        acc[0] <- multiplier[0].getResult();
        for (Integer i = 1; i < valueOf(tnp1); i = i + 1) begin
            let temp <- multiplier[i].getResult();
            acc[i] = acc[i - 1] + temp; 
        end

        outfifo.enq(fxptGetInt(acc[valueOf(tnp1) - 1]));
    endrule

    method Action putSampleInput(Sample in);
        infifo.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outfifo.deq();
        return outfifo.first();
    endmethod

endmodule