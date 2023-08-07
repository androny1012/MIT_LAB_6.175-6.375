
import ClientServer::*;
import Complex::*;
import FIFO::*;
import Reg6375::*;
import GetPut::*;
import Real::*;
import Vector::*;

// Problem 7
// import AudioProcessorTypes::*;


// Problem 6
// 需要修改，每个function的返回值和相应的provisos （provisos 本身构成了函数定义的一部分，不能省略）可对照 FFT_NoPolymorphic
// FFT_POINTS -> fft_points
// ComplexSample -> Complex#(cmplxd)
// Server类型的接口?
// 需要重写
// interface Put request 
// interface Get response

typedef Server#(
    Vector#(fft_points, Complex#(cmplxd)),
    Vector#(fft_points, Complex#(cmplxd))
) FFT#(numeric type fft_points, type cmplxd);

// Get the appropriate twiddle factor for the given stage and index.
// This computes the twiddle factor statically.
function Complex#(cmplxd) getTwiddle(Integer stage, Integer index, Integer points) provisos (RealLiteral#(cmplxd));
    Integer i = ((2*index)/(2 ** (log2(points)-stage))) * (2 ** (log2(points)-stage));
    return cmplx(fromReal(cos(fromInteger(i)*pi/fromInteger(points))),
                 fromReal(-1*sin(fromInteger(i)*pi/fromInteger(points))));
endfunction

// Generate a table of all the needed twiddle factors.
// The table can be used for looking up a twiddle factor dynamically.

typedef Vector#(
    TLog#(fft_points), 
    Vector#(TDiv#(fft_points, 2), Complex#(cmplxd))
) TwiddleTable#(numeric type fft_points, type cmplxd);

function TwiddleTable#(fft_points, cmplxd) genTwiddles() provisos (RealLiteral#(cmplxd));
    TwiddleTable#(fft_points,cmplxd) twids = newVector;
    for (Integer s = 0; s < valueOf(TLog#(fft_points)); s = s+1) begin
        for (Integer i = 0; i < valueOf(TDiv#(fft_points, 2)); i = i+1) begin
            twids[s][i] = getTwiddle(s, i, valueOf(fft_points));
        end
    end
    return twids;
endfunction

// Given the destination location and the number of points in the fft, return
// the source index for the permutation.
function Integer permute(Integer dst, Integer points);
    Integer src = ?;
    if (dst < points/2) begin
        src = dst*2;
    end else begin
        src = (dst - points/2)*2 + 1;
    end
    return src;
endfunction

// Reorder the given vector by swapping words at positions
// corresponding to the bit-reversal of their indices.
// The reordering can be done either as as the
// first or last phase of the FFT transformation.
function Vector#(fft_points, Complex#(cmplxd)) bitReverse(Vector#(fft_points,Complex#(cmplxd)) inVector);
    Vector#(fft_points, Complex#(cmplxd)) outVector = newVector();
    for(Integer i = 0; i < valueOf(fft_points); i = i+1) begin   
        Bit#(TLog#(fft_points)) reversal = reverseBits(fromInteger(i));
        outVector[reversal] = inVector[i];           
    end  
    return outVector;
endfunction

// 2-way Butterfly
function Vector#(2, Complex#(cmplxd)) bfly2(Vector#(2, Complex#(cmplxd)) t, Complex#(cmplxd) k) provisos (Arith#(Complex::Complex#(cmplxd)));
    Complex#(cmplxd) m = t[1] * k;

    Vector#(2, Complex#(cmplxd)) z = newVector();
    z[0] = t[0] + m;
    z[1] = t[0] - m; 

    return z;
endfunction

// Perform a single stage of the FFT, consisting of butterflys and a single
// permutation.
// We pass the table of twiddles as an argument so we can look those up
// dynamically if need be.
function Vector#(fft_points, Complex#(cmplxd)) stage_ft(TwiddleTable#(fft_points, cmplxd) twiddles, Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(cmplxd)) stage_in) provisos (Add#(2, a__, fft_points), Arith#(cmplxd));
    Vector#(fft_points, Complex#(cmplxd)) stage_temp = newVector();
    for(Integer i = 0; i < (valueOf(fft_points)/2); i = i+1) begin    
        Integer idx = i * 2;
        let twid = twiddles[stage][i];
        let y = bfly2(takeAt(idx, stage_in), twid);

        stage_temp[idx]   = y[0];
        stage_temp[idx+1] = y[1];
    end 

    Vector#(fft_points, Complex#(cmplxd)) stage_out = newVector();
    for (Integer i = 0; i < valueOf(fft_points); i = i+1) begin
        stage_out[i] = stage_temp[permute(i, valueOf(fft_points))];
    end
    return stage_out;
endfunction

// Problem 1
module mkCombinationalFFT (FFT#(fft_points, cmplxd)) provisos (Add#(2, a__, fft_points), Arith#(cmplxd), RealLiteral#(cmplxd), Bits#(cmplxd, b__));

  // Statically generate the twiddle factors table.
  TwiddleTable#(fft_points, cmplxd) twiddles = genTwiddles();

  // Define the stage_f function which uses the generated twiddles.
  function Vector#(fft_points, Complex#(cmplxd)) stage_f(Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(cmplxd)) stage_in);
      return stage_ft(twiddles, stage, stage_in);
  endfunction

  FIFO#(Vector#(fft_points, Complex#(cmplxd))) inputFIFO  <- mkFIFO(); 
  FIFO#(Vector#(fft_points, Complex#(cmplxd))) outputFIFO <- mkFIFO(); 

  // This rule performs fft using a big mass of combinational logic.
  rule comb_fft;

    Vector#(TAdd#(1, TLog#(fft_points)), Vector#(fft_points, Complex#(cmplxd))) stage_data = newVector();
    stage_data[0] = inputFIFO.first();
    inputFIFO.deq();

    for(Integer stage = 0; stage < valueOf(TLog#(fft_points)); stage=stage+1) begin
        stage_data[stage+1] = stage_f(fromInteger(stage), stage_data[stage]);  
    end

    outputFIFO.enq(stage_data[valueOf(TLog#(fft_points))]);
  endrule

  interface Put request;
    method Action put(Vector#(fft_points, Complex#(cmplxd)) x);
        inputFIFO.enq(bitReverse(x));
    endmethod
  endinterface

  interface Get response = toGet(outputFIFO);

endmodule

// Problem 2
// Just add Reg
module mkLinearFFT (FFT#(fft_points, cmplxd)) provisos (Add#(2, a__, fft_points), Arith#(cmplxd), RealLiteral#(cmplxd), Bits#(cmplxd, b__));

    // Statically generate the twiddle factors table.
    TwiddleTable#(fft_points, cmplxd) twiddles = genTwiddles();

    // Define the stage_f function which uses the generated twiddles.
    function Vector#(fft_points, Complex#(cmplxd)) stage_f(Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(cmplxd)) stage_in);
        return stage_ft(twiddles, stage, stage_in);
    endfunction

    FIFO#(Vector#(fft_points, Complex#(cmplxd))) inputFIFO  <- mkFIFO(); 
    FIFO#(Vector#(fft_points, Complex#(cmplxd))) outputFIFO <- mkFIFO(); 

    Vector#(TAdd#(1, TLog#(fft_points)), Reg#(Vector#(fft_points, Complex#(cmplxd)))) stage_data <- replicateM(mkRegU);
    Vector#(TAdd#(1, TLog#(fft_points)), Reg#(Bool)) stage_valid <- replicateM(mkReg(False));

    rule linear_fft;
    
        stage_data[0] <= inputFIFO.first();
        stage_valid[0] <= True;
        inputFIFO.deq();

        for(Integer stage = 0; stage < valueOf(TLog#(fft_points)); stage=stage+1) begin
            if(stage_valid[stage]) begin
                stage_data[stage+1] <= stage_f(fromInteger(stage), stage_data[stage]);  
                stage_valid[stage+1] <= True;
            end
            else begin
                stage_valid[stage+1] <= False;
            end
            
        end
        
        if(stage_valid[valueOf(TLog#(fft_points))]) begin
            outputFIFO.enq(stage_data[valueOf(TLog#(fft_points))]);
        end
    endrule

    interface Put request;
        method Action put(Vector#(fft_points, Complex#(cmplxd)) x);
            inputFIFO.enq(bitReverse(x));
        endmethod
    endinterface

    interface Get response = toGet(outputFIFO);

endmodule

// Problem 3
module mkCircularFFT (FFT#(fft_points, cmplxd)) provisos (Add#(2, a__, fft_points), Arith#(cmplxd), RealLiteral#(cmplxd), Bits#(cmplxd, b__));

    // Statically generate the twiddle factors table.
    TwiddleTable#(fft_points, cmplxd) twiddles = genTwiddles();

    // Define the stage_f function which uses the generated twiddles.
    function Vector#(fft_points, Complex#(cmplxd)) stage_f(Bit#(TLog#(TLog#(fft_points))) stage, Vector#(fft_points, Complex#(cmplxd)) stage_in);
        return stage_ft(twiddles, stage, stage_in);
    endfunction

    FIFO#(Vector#(fft_points, Complex#(cmplxd))) inputFIFO  <- mkFIFO(); 
    FIFO#(Vector#(fft_points, Complex#(cmplxd))) outputFIFO <- mkFIFO(); 

    Reg#(Vector#(fft_points, Complex#(cmplxd))) stage_data <- mkRegU;
    Reg#(Bit#(TLog#(TLog#(fft_points)))) stage <- mkReg(0);

    rule circularr_fft;
        if(stage == 0) begin
            stage_data <= stage_f(stage, inputFIFO.first());  
            inputFIFO.deq();
            stage <= stage + 1;
        end
        else if(stage == fromInteger(valueOf(TLog#(fft_points)))) begin
            outputFIFO.enq(stage_data);
            stage <= 0;
        end
        else begin
            stage_data <= stage_f(stage, stage_data);  
            stage <= stage + 1;            
        end

    endrule

    interface Put request;
        method Action put(Vector#(fft_points, Complex#(cmplxd)) x);
            inputFIFO.enq(bitReverse(x));
        endmethod
    endinterface

    interface Get response = toGet(outputFIFO);

endmodule

// Wrapper around The FFT module we actually want to use
module mkFFT (FFT#(fft_points, cmplxd)) provisos (Add#(2, a__, fft_points), Arith#(cmplxd), RealLiteral#(cmplxd), Bits#(cmplxd, b__));
    // FFT#(fft_points, cmplxd) fft <- mkCombinationalFFT();
    // FFT#(fft_points, cmplxd) fft <- mkLinearFFT();
    FFT#(fft_points, cmplxd) fft <- mkCircularFFT();
    
    interface Put request = fft.request;
    interface Get response = fft.response;
endmodule

// Inverse FFT, based on the mkFFT module.
// ifft[k] = fft[N-k]/N
module mkIFFT (FFT#(fft_points, cmplxd)) provisos (Add#(2, a__, fft_points), Arith#(cmplxd), RealLiteral#(cmplxd), Bits#(cmplxd, b__), Bitwise#(cmplxd));

    FFT#(fft_points, cmplxd) fft <- mkFFT();
    FIFO#(Vector#(fft_points, Complex#(cmplxd))) outfifo <- mkFIFO();

    Integer n = valueOf(fft_points);
    Integer lgn = valueOf(TLog#(fft_points));

    function Complex#(cmplxd) scaledown(Complex#(cmplxd) x);
        return cmplx(x.rel >> lgn, x.img >> lgn);
    endfunction

    rule inversify (True);
        let x <- fft.response.get();
        Vector#(fft_points, Complex#(cmplxd)) rx = newVector;

        for (Integer i = 0; i < n; i = i+1) begin
            rx[i] = x[(n - i)%n];
        end
        outfifo.enq(map(scaledown, rx));
    endrule

    interface Put request = fft.request;
    interface Get response = toGet(outfifo);

endmodule

