import Vector::*;
import Complex::*;
import Real::*;
import Randomizable::*;

import FftCommon::*;
import Fft::*;

import Fifo::*;

typedef 128 TESTNUM;

module mkTestBench#(Fft fft)();
    let fft_comb <- mkFftCombinational;
    // let fft_comb <- mkFftInelasticPipeline;

    Vector#(FftPoints, Randomize#(Data)) randomVal1 <- replicateM(mkGenericRandomizer);
    Vector#(FftPoints, Randomize#(Data)) randomVal2 <- replicateM(mkGenericRandomizer);

    Reg#(Bool) init <- mkReg(False);
    Reg#(Bit#(32)) cycle_count <- mkReg(0);
    Reg#(Bit#(8)) stream_count <- mkReg(0);
    Reg#(Bit#(8)) feed_count <- mkReg(0);

    rule initialize(init == False);
        for (Integer i = 0; i < fftPoints; i = i + 1 ) begin
            randomVal1[i].cntrl.init;
            randomVal2[i].cntrl.init;
        end
        init <= True;
    endrule

    // rule feed;
    rule feed(feed_count < fromInteger(valueOf(TESTNUM)) && init);
        Vector#(FftPoints, ComplexData) d;
        for (Integer i = 0; i < fftPoints; i = i + 1 ) begin
            let rv <- randomVal1[i].next;
            let iv <- randomVal2[i].next;
            d[i] = cmplx(rv, iv);
        end
        // $display("At %d, tb feed %d ", cycle_count, feed_count);
        fft_comb.enq(d);
        fft.enq(d);
        feed_count <= feed_count + 1;
    endrule

    rule stream(init);
        stream_count <= stream_count + 1;
        let rc <- fft_comb.deq;
        let rf <- fft.deq;
        if ( rc != rf ) begin
            $display("FAILED!");
            for (Integer i = 0; i < fftPoints; i = i + 1) begin
                $display ("\t(%x, %x) != (%x, %x)", rc[i].rel, rc[i].img, rf[i].rel, rf[i].img);
            end
            $finish;
        end
    endrule

    rule pass (stream_count == fromInteger(valueOf(TESTNUM)) && init);
        $display("PASSED");
        $finish;
    endrule

    rule timeout(init);
//WTH here?
        if( cycle_count == fromInteger(valueOf(TESTNUM)) * 3 ) begin
            $display("FAILED: Only saw %0d out of 128 outputs after %0d cycles", stream_count, cycle_count);
            $finish;
        end
        $display("Cycle %d:", cycle_count);
        cycle_count <= cycle_count + 1;
    endrule
endmodule

(* synthesize *)
module mkTbFftCombinational();
    let fft <- mkFftCombinational;
    mkTestBench(fft);
endmodule

(* synthesize *)
module mkTbFftInelasticPipeline();
    let fft <- mkFftInelasticPipeline;
    mkTestBench(fft);
endmodule

// (* synthesize *)
// module mkTbFftInelasticPipeline();
//     let fft <- mkFifoTest;
//     mkTestBench(fft);
// endmodule

(* synthesize *)
module mkTbFftElasticPipeline();
    let fft <- mkFftElasticPipeline;
    mkTestBench(fft);
endmodule



// (* synthesize *)
// module mkTestBenchFifo();
//     Fifo#(3, Bit#(32)) referenceFifo <- mkCF3Fifo();
//     Fifo#(3, Bit#(32)) testFifo <- mkFifo();
//     Randomize#(Bit#(32)) randomVal1 <- mkGenericRandomizer;

//     Reg#(Bool) init <- mkReg(False);
//     Reg#(Bit#(32)) cycle_count <- mkReg(0);
//     Reg#(Bit#(32)) delay <- mkReg(0);
//     Reg#(Bit#(8)) stream_count <- mkReg(0);
//     Reg#(Bit#(8)) feed_count <- mkReg(0);
//     Reg#(Bit#(32)) enqueue3 <-mkReg(0);
//     Reg#(Bool) success <- mkReg(False);
//     rule initialize(init == False);
//         randomVal1.cntrl.init;
//         init <= True;
//     endrule

//     rule feed (feed_count <128 && init && (enqueue3==0) );
//        let el <- randomVal1.next;
//        referenceFifo.enq(el);
//        feed_count <= feed_count + 1;
//        testFifo.enq(el);
//        $display("Enqueuing %d in the tested fifo and the reference fifo",el);
//     endrule

//     rule stream (init && (enqueue3 == 0));
//         delay <= 0;
//         testFifo.deq();
//         $display("Dequeue");
//         stream_count <= stream_count + 1;
//         referenceFifo.deq();
//         let r = referenceFifo.first();
//         let t = testFifo.first();
//         if (t!=r) begin $display("FAILED: We see %d in the reference fifo and %d in your fifo", r, t); $finish; end
//     endrule

//     rule presucces (stream_count == 128 && init);
//         $display("On the path to success");
//         enqueue3 <= 1;
//         stream_count <= stream_count + 1;
//     endrule

//     rule finish(success && stream_count == 132);
//         $display("PASSED");
//         $finish();
//     endrule

//     rule enqueueThree (enqueue3>0 && enqueue3 < 4);
//         delay <= 0;
//         enqueue3 <= enqueue3 + 1;
//         let el <- randomVal1.next;
//         referenceFifo.enq(el);
//         feed_count <= feed_count + 1;
//         testFifo.enq(el);
//         $display("Enqueuing three %d in the tested fifo and the reference fifo",el);
//     endrule

//     rule dequeueThree(enqueue3 ==4);
//        $display("Enqueued three in a row");
//        enqueue3 <= 0;
//        success <= True;
//     endrule

//     rule deadlock (delay == 200 && init );
//         $display("FAILED It seems that your fifo is deadlocking, either we are failing to enqueue, or we enqueud some stuff in it but we can't dequeue from it.");
//         $finish;
//     endrule

//     rule timeout ( init);
//         delay <= delay + 1;
//         cycle_count <= cycle_count + 1;
//     endrule
// endmodule



// import Vector::*;
// import Complex::*;
// import Real::*;
// import Randomizable::*;

// import FftCommon::*;
// import Fft::*;

// import Fifo::*;

// typedef 128 TESTNUM;

// module mkTestBench#(Fft fft)();
//     let fft_comb <- mkFftCombinational;
//     // let fft_comb <- mkFftInelasticPipeline;

//     Vector#(FftPoints, Randomize#(Data)) randomVal1 <- replicateM(mkGenericRandomizer);
//     Vector#(FftPoints, Randomize#(Data)) randomVal2 <- replicateM(mkGenericRandomizer);

//     Reg#(Bool) init <- mkReg(False);
//     Reg#(Bool) randominit <- mkReg(False);
//     Reg#(Bit#(32)) cycle_count <- mkReg(0);
//     Reg#(Bit#(8)) stream_count <- mkReg(0);
//     Reg#(Bit#(8)) feed_count1 <- mkReg(0);
//     Reg#(Bit#(8)) feed_count2 <- mkReg(0);
//     // Reg#(Vector#(FftPoints, ComplexData)) d <- mkReg(replicate(cmplx(0, 0)));
//     Vector#(TESTNUM, Reg#(Vector#(FftPoints, ComplexData))) d <- replicateM(mkReg(replicate(cmplx(0, 0))));

//     rule initialize(init == False && randominit == False);
//         for (Integer i = 0; i < fftPoints; i = i + 1 ) begin
//             randomVal1[i].cntrl.init;
//             randomVal2[i].cntrl.init;
//         end

//         randominit <= True;
//     endrule

//     rule rinitialize(randominit == True);

//         Vector#(FftPoints, ComplexData) d_i;
//         for (Integer i = 0; i < fftPoints; i = i + 1 ) begin
//             let rv <- randomVal1[i].next;
//             let iv <- randomVal2[i].next;
//             d_i[i] = cmplx(rv, iv);
//         end
//         for (Integer j = 0; j < fromInteger(valueOf(TESTNUM)); j = j + 1 ) begin

//             d[j] <= d_i;
//         end

//         init <= True;
//         randominit <= False;
//     endrule

//     rule feed1(feed_count1 < fromInteger(valueOf(TESTNUM)) && init);
//         fft_comb.enq(d[feed_count1]);
//         feed_count1 <= feed_count1 + 1;
//     endrule

//     rule feed2(feed_count2 < fromInteger(valueOf(TESTNUM)) && init);
//         fft.enq(d[feed_count2]);
//         feed_count2 <= feed_count2 + 1;
//     endrule
            
//     rule stream(init);
//         stream_count <= stream_count + 1;
//         let rc <- fft_comb.deq;
//         let rf <- fft.deq;
//         if ( rc != rf ) begin
//             $display("FAILED!");
//             for (Integer i = 0; i < fftPoints; i = i + 1) begin
//                 $display ("\t(%x, %x) != (%x, %x)", rc[i].rel, rc[i].img, rf[i].rel, rf[i].img);
//             end
//             $finish;
//         end
//     endrule

//     rule pass (stream_count == fromInteger(valueOf(TESTNUM)) && init);
//         $display("PASSED");
//         $finish;
//     endrule

//     rule timeout(init);
// //WTH here?
//         if( cycle_count == fromInteger(valueOf(TESTNUM)) * 3 ) begin
//             $display("FAILED: Only saw %0d out of 128 outputs after %0d cycles", stream_count, cycle_count);
//             $finish;
//         end
//         $display("Cycle %d:", cycle_count);
//         cycle_count <= cycle_count + 1;
//     endrule
// endmodule

// (* synthesize *)
// module mkTbFftCombinational();
//     let fft <- mkFftCombinational;
//     mkTestBench(fft);
// endmodule

// (* synthesize *)
// module mkTbFftInelasticPipeline();
//     let fft <- mkFftInelasticPipeline;
//     mkTestBench(fft);
// endmodule

// // (* synthesize *)
// // module mkTbFftInelasticPipeline();
// //     let fft <- mkFifoTest;
// //     mkTestBench(fft);
// // endmodule

// (* synthesize *)
// module mkTbFftElasticPipeline();
//     let fft <- mkFftElasticPipeline;
//     mkTestBench(fft);
// endmodule

