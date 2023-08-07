
import ClientServer::*;
import GetPut::*;
import Vector::*;
import PitchAdjust::*;
import FixedPoint::*;
import FShow::*;
import ComplexMP::*;

// Unit test for PitchAdjust
(* synthesize *)
module mkPitchAdjustTest (Empty);

    // For nbins = 8, S = 2, pitch factor = 2.0
    // PitchAdjust#(8, 16, 16, 16) adjust <- mkPitchAdjust(2, 2);
    SettablePitchAdjust#(8, 16, 16, 16) settablePitchAdjust <- mkPitchAdjust(valueOf(2));
    PitchAdjust#(8, 16, 16, 16) adjust = settablePitchAdjust.pitchAdjust;

    Reg#(Bool) passed <- mkReg(True);
    Reg#(Bit#(32)) feed <- mkReg(0);
    Reg#(Bit#(32)) check <- mkReg(0);
    
    Reg#(Bool) m_inited <- mkReg(False);
    rule init(!m_inited);
        m_inited <= True;
        settablePitchAdjust.setFactor.put(fromInteger(valueOf(2)));
    endrule

    function Action dofeed(Vector#(8, ComplexMP#(16, 16, 16)) x);
        action
            adjust.request.put(x);
            feed <= feed+1;
        endaction
    endfunction

    function Action docheck(Vector#(8, ComplexMP#(16, 16, 16)) wnt);
        action
            Bool pass = True;
            let x <- adjust.response.get();
            // 误差范围内可以接受
            for (Integer i = 0; i < 8; i = i + 1) begin
                if(wnt[i].phase - x[i].phase >= 3 || x[i].phase - wnt[i].phase >= 3) begin
                    pass = False;
                end
            end 
            if (!pass) begin
                $display("check: ", check);
                $display("wnt: ", fshow(wnt));
                $display("got: ", fshow(x));
                passed <= pass;
            end
            check <= check+1;
        endaction
    endfunction

// in , mag:273.000000, pha:0.000000 
// in , mag:13.480010 , pha:1.894905 
// in , mag:6.403124  , pha:2.245537 
// in , mag:6.347387  , pha:2.688567 
// in , mag:5.000000  , pha:3.141593 
// in , mag:6.347387  , pha:-2.688567
// in , mag:6.403124  , pha:-2.245537
// in , mag:13.480010 , pha:-1.894905

// out, mag:273.000000, pha:0.000000 
// out, mag:0.000000  , pha:0.000000 
// out, mag:13.480010 , pha:-2.493376
// out, mag:0.000000  , pha:0.000000 
// out, mag:6.403124  , pha:-1.792111
// out, mag:0.000000  , pha:0.000000 
// out, mag:6.347387  , pha:-0.906051
// out, mag:0.000000  , pha:0.000000 

    Vector#(8, ComplexMP#(16, 16, 16)) ti1 = newVector;
    ti1[0] = cmplxmp(273.000000, tophase(0.000000 ));
    ti1[1] = cmplxmp(13.480010 , tophase(1.894905 ));
    ti1[2] = cmplxmp(6.403124  , tophase(2.245537 ));
    ti1[3] = cmplxmp(6.347387  , tophase(2.688567 ));
    ti1[4] = cmplxmp(5.000000  , tophase(3.141593 ));
    ti1[5] = cmplxmp(6.347387  , tophase(-2.688567));
    ti1[6] = cmplxmp(6.403124  , tophase(-2.245537));
    ti1[7] = cmplxmp(13.480010 , tophase(-1.894905));

    Vector#(8, ComplexMP#(16, 16, 16)) to1 = newVector;
    to1[0] = cmplxmp(273.000000, tophase(0.000000 ));
    to1[1] = cmplxmp(0.000000  , tophase(0.000000 ));
    to1[2] = cmplxmp(13.480010 , tophase(-2.493376));
    to1[3] = cmplxmp(0.000000  , tophase(0.000000 ));
    to1[4] = cmplxmp(6.403124  , tophase(-1.792111));
    to1[5] = cmplxmp(0.000000  , tophase(0.000000 ));
    to1[6] = cmplxmp(6.347387  , tophase(-0.906051));
    to1[7] = cmplxmp(0.000000  , tophase(0.000000 ));

// in , mag:168.000000, pha:0.000000 
// in , mag:19.235570 , pha:2.099765 
// in , mag:13.038405 , pha:2.574863 
// in , mag:9.486457  , pha:2.634546 
// in , mag:6.000000  , pha:3.141593 
// in , mag:9.486457  , pha:-2.634546
// in , mag:13.038405 , pha:-2.574863
// in , mag:19.235570 , pha:-2.099765

// out, mag:168.000000, pha:0.000000 
// out, mag:0.000000  , pha:0.000000 
// out, mag:19.235570 , pha:-2.083655
// out, mag:0.000000  , pha:0.000000 
// out, mag:13.038405 , pha:-1.133458
// out, mag:0.000000  , pha:0.000000 
// out, mag:9.486457  , pha:-1.014094
// out, mag:0.000000  , pha:0.000000 

    Vector#(8, ComplexMP#(16, 16, 16)) ti2 = newVector;
    ti2[0] = cmplxmp(168.000000, tophase(0.000000 ));
    ti2[1] = cmplxmp(19.235570 , tophase(2.099765 ));
    ti2[2] = cmplxmp(13.038405 , tophase(2.574863 ));
    ti2[3] = cmplxmp(9.486457  , tophase(2.634546 ));
    ti2[4] = cmplxmp(6.000000  , tophase(3.141593 ));
    ti2[5] = cmplxmp(9.486457  , tophase(-2.634546));
    ti2[6] = cmplxmp(13.038405 , tophase(-2.574863));
    ti2[7] = cmplxmp(19.235570 , tophase(-2.099765));

    Vector#(8, ComplexMP#(16, 16, 16)) to2 = newVector;
    to2[0] = cmplxmp(168.000000, tophase(0.000000 ));
    to2[1] = cmplxmp(0.000000  , tophase(0.000000 ));
    to2[2] = cmplxmp(19.235570 , tophase(-2.083655));
    to2[3] = cmplxmp(0.000000  , tophase(0.000000 ));
    to2[4] = cmplxmp(13.038405 , tophase(-1.133458));
    to2[5] = cmplxmp(0.000000  , tophase(0.000000 ));
    to2[6] = cmplxmp(9.486457  , tophase(-1.014094));
    to2[7] = cmplxmp(0.000000  , tophase(0.000000 ));

// in , mag:45.000000, pha:0.000000 
// in , mag:14.628566, pha:1.847761 
// in , mag:8.544004 , pha:1.929567 
// in , mag:4.000631 , pha:3.123828 
// in , mag:7.000000 , pha:3.141593 
// in , mag:4.000631 , pha:-3.123828
// in , mag:8.544004 , pha:-1.929567
// in , mag:14.628566, pha:-1.847761

// out, mag:45.000000, pha:0.000000 
// out, mag:0.000000 , pha:0.000000 
// out, mag:14.628566, pha:-2.587663
// out, mag:0.000000 , pha:0.000000 
// out, mag:8.544004 , pha:-2.424051
// out, mag:0.000000 , pha:0.000000 
// out, mag:4.000631 , pha:-0.035530
// out, mag:0.000000 , pha:0.000000 

    Vector#(8, ComplexMP#(16, 16, 16)) ti3 = newVector;
    ti3[0] = cmplxmp(45.000000, tophase(0.000000 ));
    ti3[1] = cmplxmp(14.628566, tophase(1.847761 ));
    ti3[2] = cmplxmp(8.544004 , tophase(1.929567 ));
    ti3[3] = cmplxmp(4.000631 , tophase(3.123828 ));
    ti3[4] = cmplxmp(7.000000 , tophase(3.141593 ));
    ti3[5] = cmplxmp(4.000631 , tophase(-3.123828));
    ti3[6] = cmplxmp(8.544004 , tophase(-1.929567));
    ti3[7] = cmplxmp(14.628566, tophase(-1.847761));

    Vector#(8, ComplexMP#(16, 16, 16)) to3 = newVector;
    to3[0] = cmplxmp(45.000000, tophase(0.000000 ));
    to3[1] = cmplxmp(0.000000 , tophase(0.000000 ));
    to3[2] = cmplxmp(14.628566, tophase(-2.587663));
    to3[3] = cmplxmp(0.000000 , tophase(0.000000 ));
    to3[4] = cmplxmp(8.544004 , tophase(-2.424051));
    to3[5] = cmplxmp(0.000000 , tophase(0.000000 ));
    to3[6] = cmplxmp(4.000631 , tophase(-0.035530));
    to3[7] = cmplxmp(0.000000 , tophase(0.000000 ));

// in , mag:359.000000, pha:3.141593 
// in , mag:2.797933  , pha:1.315301 
// in , mag:3.000000  , pha:-1.570796
// in , mag:1.473626  , pha:-2.071270
// in , mag:1.000000  , pha:3.141593 
// in , mag:1.473626  , pha:2.071270 
// in , mag:3.000000  , pha:1.570796 
// in , mag:2.797933  , pha:-1.315301

// out, mag:359.000000, pha:-0.000000
// out, mag:0.000000  , pha:0.000000 
// out, mag:2.797933  , pha:2.630602 
// out, mag:0.000000  , pha:0.000000 
// out, mag:3.000000  , pha:-3.141593
// out, mag:0.000000  , pha:0.000000 
// out, mag:1.473626  , pha:2.140645 
// out, mag:0.000000  , pha:0.000000 

    Vector#(8, ComplexMP#(16, 16, 16)) ti4 = newVector;
    ti4[0] = cmplxmp(359.000000, tophase(3.141593 ));
    ti4[1] = cmplxmp(2.797933  , tophase(1.315301 ));
    ti4[2] = cmplxmp(3.000000  , tophase(-1.570796));
    ti4[3] = cmplxmp(1.473626  , tophase(-2.071270));
    ti4[4] = cmplxmp(1.000000  , tophase(3.141593 ));
    ti4[5] = cmplxmp(1.473626  , tophase(2.071270 ));
    ti4[6] = cmplxmp(3.000000  , tophase(1.570796 ));
    ti4[7] = cmplxmp(2.797933  , tophase(-1.315301));

    Vector#(8, ComplexMP#(16, 16, 16)) to4 = newVector;
    to4[0] = cmplxmp(359.000000, tophase(-0.000000));
    to4[1] = cmplxmp(0.000000  , tophase(0.000000 ));
    to4[2] = cmplxmp(2.797933  , tophase(2.630602 ));
    to4[3] = cmplxmp(0.000000  , tophase(0.000000 ));
    to4[4] = cmplxmp(3.000000  , tophase(-3.141593));
    to4[5] = cmplxmp(0.000000  , tophase(0.000000 ));
    to4[6] = cmplxmp(1.473626  , tophase(2.140645 ));
    to4[7] = cmplxmp(0.000000  , tophase(0.000000 ));

    rule f0 (feed == 0); dofeed(ti1); endrule
    rule f1 (feed == 1); dofeed(ti2); endrule
    rule f2 (feed == 2); dofeed(ti3); endrule
    rule f3 (feed == 3); dofeed(ti4); endrule
    
    rule c0 (check == 0); docheck(to1); endrule
    rule c1 (check == 1); docheck(to2); endrule
    rule c2 (check == 2); docheck(to3); endrule
    rule c3 (check == 3); docheck(to4); endrule

    rule finish (feed == 4 && check == 4);
        if (passed) begin
            $display("PASSED");
        end else begin
            $display("FAILED");
        end
        $finish();
    endrule

endmodule


