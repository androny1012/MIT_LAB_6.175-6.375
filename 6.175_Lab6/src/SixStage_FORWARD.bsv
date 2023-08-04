// Six stage
import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;
import FPGAMemory::*;

typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
} Decode2Regfile deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool epoch;
} Regfile2Execute deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} Execute2Memory deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} Memory2WriteBack deriving (Bits, Eq);

// redirect msg from Execute stage
typedef struct {
    Addr pc;
    Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
    Scoreboard#(2)   sbE<- mkCFScoreboard;
    Scoreboard#(2)   sbM<- mkCFScoreboard;
    Scoreboard#(2)   sbW<- mkCFScoreboard;
    // IMemory  iMem <- mkIMemory;
    // DMemory  dMem <- mkDMemory;
    FPGAMemory iMem <- mkFPGAMemory;
    FPGAMemory dMem <- mkFPGAMemory;
    CsrFile        csrf <- mkCsrFile;

    Btb#(6)         btb <- mkBtb; 
    Reg#(Bool) exeEpoch <- mkReg(False);

    Wire#(Maybe#(ExecInst))   neweInst_E <- mkWire;
    Ehr#(2, Maybe#(ExecInst)) neweInst_M <- mkEhr(?);
    Ehr#(2, Maybe#(ExecInst)) neweInst_W <- mkEhr(?);
    // FIFO between two stages
    Fifo#(8, Fetch2Decode)     f2dFifo <- mkCFFifo;
    Fifo#(8, Decode2Regfile)   d2rFifo <- mkCFFifo;
    Fifo#(8, Regfile2Execute)  r2eFifo <- mkCFFifo;
	Fifo#(8, Execute2Memory)   e2mFifo <- mkCFFifo;
	Fifo#(8, Memory2WriteBack) m2wFifo <- mkCFFifo;

    Bool memReady = iMem.init.done && dMem.init.done;
    rule test (!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    // fetch stage
    rule doFetch(csrf.started);
        // fetch
        iMem.req(MemReq { op: Ld, addr: pcReg[0], data: ? });
        Addr predPc = btb.predPc(pcReg[0]);

        Fetch2Decode f2d = Fetch2Decode {
            pc: pcReg[0],
            predPc: predPc,
            epoch : exeEpoch
        };
        f2dFifo.enq(f2d);

        pcReg[0] <= predPc;
        $display("[fetch    ] PC = %x", f2d.pc);
    endrule

    // decode stage
    rule doDecode(csrf.started);
        let f2d = f2dFifo.first;
        let inst <- iMem.resp;

        // decode
        DecodedInst dInst = decode(inst);

        Decode2Regfile d2r = Decode2Regfile {
            pc: f2d.pc,
            predPc: f2d.predPc,
            dInst : dInst,
            epoch : f2d.epoch
        };

        d2rFifo.enq(d2r);
        f2dFifo.deq;
        $display("[decode   ] PC = %x, expanded = ", f2d.pc, showInst(inst));
    endrule

    // // reg read stage
    // rule doRegfile(csrf.started);
    //     let d2r = d2rFifo.first;
    //     let dInst = d2r.dInst;

    //     // reg read
    //     Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
    //     Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
    //     Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

    //     // data to enq to FIFO
    //     Regfile2Execute r2e = Regfile2Execute {
    //         pc: d2r.pc,
    //         predPc: d2r.predPc,
    //         dInst: dInst,
    //         rVal1: rVal1,
    //         rVal2: rVal2,
    //         csrVal: csrVal,
    //         epoch : d2r.epoch
    //     };
        

    //     if(!sb.search1(dInst.src1) && !sb.search2(dInst.src2)) begin
    //         sb.insert(dInst.dst);
    //         r2eFifo.enq(r2e);
    //         d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
    //         $display("[register ] PC = %x", d2r.pc);
    //     end
    //     else begin
    //         $display("[register ] PC = %x (stalled)", d2r.pc);
    //     end
    // endrule

    // reg read stage
    rule doRegfile(csrf.started);
        let d2r = d2rFifo.first;
        let dInst = d2r.dInst;
        // Bool esearch = !sbE.search1(dInst.src1) && !sbE.search2(dInst.src2);
        // Bool msearch = !sbM.search1(dInst.src1) && !sbM.search2(dInst.src2);
        // Bool wsearch = !sbW.search1(dInst.src1) && !sbW.search2(dInst.src2);
        Bool esearch = True;
        Bool msearch = True;
        Bool wsearch = True;
        if (isValid(neweInst_E)) begin
            let eInstE = fromMaybe(?, neweInst_E);
            esearch = !(eInstE.dst == dInst.src1) && !(eInstE.dst == dInst.src2);
        end
        // if (isValid(neweInst_M[0])) begin
        //     let eInstM = fromMaybe(?, neweInst_M[0]);
        //     msearch = !(eInstM.dst == dInst.src1) && !(eInstM.dst == dInst.src2);
        // end
        // if (isValid(neweInst_W[0])) begin
        //     let eInstW = fromMaybe(?, neweInst_W[0]);
        //     wsearch = !(eInstW.dst == dInst.src1) && !(eInstW.dst == dInst.src2);
        // end
        Bool flag = False;
        Data rVal1 = 0;
        Data rVal2 = 0;
        if(esearch && msearch && wsearch) begin

            // reg read
            rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
            rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
            
            // sbE.insert(dInst.dst);

            d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
            $display("[register ] PC = %x", d2r.pc);
            flag = True;
        end 
        // else if(!esearch && eInstE.iType != Ld) begin
        //     if(sbE.search1(dInst.src1)) begin
        //         rVal1 = eInstE.data;
        //         rVal2 = rf.rd2(fromMaybe(?, dInst.src2));      
        //     end
        //     else begin
        //         rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        //         rVal2 = eInstE.data;
        //     end

        //     sbE.insert(dInst.dst);
        //     sbE.remove;
        //     d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
        //     $display("[register ] PC = %x", d2r.pc);  
        //     flag = True;  
            
        //     // let mDst = sbM.first;
        //     // sbM.remove;
        //     // sbW.insert(mDst);
        // end
        // else if(!msearch && eInstM.iType != Ld) begin
        //     if(sbE.search1(dInst.src1)) begin
        //         rVal1 = eInstM.data;
        //         rVal2 = rf.rd2(fromMaybe(?, dInst.src2));      
        //     end
        //     else begin
        //         rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        //         rVal2 = eInstM.data;
        //     end

        //     sbE.insert(dInst.dst);
        //     sbM.remove;
        //     d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
        //     $display("[register ] PC = %x", d2r.pc);       
        //     flag = True;
            
        //     // let eDst = sbE.first;
        //     // sbE.remove;
        //     // sbM.insert(eDst);

        // end
        // else if(!wsearch) begin
        //     if(sbE.search1(dInst.src1)) begin
        //         rVal1 = eInstW.data;
        //         rVal2 = rf.rd2(fromMaybe(?, dInst.src2));      
        //     end
        //     else begin
        //         rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        //         rVal2 = eInstW.data;
        //     end

        //     sbE.insert(dInst.dst);
        //     sbW.remove;
        //     d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
        //     $display("[register ] PC = %x", d2r.pc);       
        //     flag = True;     

        //     // let eDst = sbE.first;
        //     // sbE.remove;
        //     // sbM.insert(eDst);
        //     // let mDst = sbM.first;
        //     // sbM.remove;
        //     // sbW.insert(mDst);
        // end
        else begin
            $display("[register ] PC = %x (stalled)", d2r.pc);
        end
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        
        if(flag) begin
            // data to enq to FIFO
            Regfile2Execute r2e = Regfile2Execute {
                pc: d2r.pc,
                predPc: d2r.predPc,
                dInst: dInst,
                rVal1: rVal1,
                rVal2: rVal2,
                csrVal: csrVal,
                epoch : d2r.epoch
            };
            r2eFifo.enq(r2e);
        end
    endrule

    // exe stage
    rule doExecute(csrf.started);
        let r2e = r2eFifo.first;

        Maybe#(ExecInst) neweInst = Invalid;

        if(r2e.epoch != exeEpoch) begin
            // mispred 
            $display("[execute  ] epoch mismatch. PC = %x", r2e.pc);
        end
        else begin
            // execute
            ExecInst eInst = exec(r2e.dInst, r2e.rVal1, r2e.rVal2, r2e.pc, r2e.predPc, r2e.csrVal);  
            neweInst = Valid(eInst);
            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", r2e.pc);
                $finish;
            end

            // 这里不能像R stage那样处理 flush，如果是保持数据不往后传，这里的逻辑会反复执行
            if (eInst.iType == J || eInst.iType == Jr || eInst.iType == Br) begin
                btb.update(r2e.pc, eInst.addr);
            end
            if (eInst.mispredict) begin
                pcReg[1] <= eInst.addr;
                exeEpoch <= !exeEpoch;
            end

            $display("[execute  ] PC = %x", r2e.pc);
        end

        // 而且如果mispred，前面送来的直接deq即可，因此无论什么情况都都会deq
        r2eFifo.deq;

        let e2m = Execute2Memory{
            pc: r2e.pc,
            eInst: neweInst
        };
        e2mFifo.enq(e2m);

        neweInst_E <= neweInst;
    endrule

    // mem stage
    rule doMemory(csrf.started);
        let e2m = e2mFifo.first;
        neweInst_M[0] <= e2m.eInst;

        // memory
        if (isValid(e2m.eInst)) begin
            let eInst = fromMaybe(?, e2m.eInst);
            if(eInst.iType == Ld) begin
                dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
            end else if(eInst.iType == St) begin
                dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
            end
            $display("[memory   ] PC = %x", e2m.pc);
        end else begin
            $display("[memory   ] epoch mismatch. PC = %x", e2m.pc);
        end

        e2mFifo.deq;

        let m2w = Memory2WriteBack{
            pc: e2m.pc,
            eInst: e2m.eInst
        };
        m2wFifo.enq(m2w);
    
    endrule

    // wb stage
    rule doWriteBack (csrf.started);
        let m2w = m2wFifo.first;
        neweInst_W[0] <= m2w.eInst;
        m2wFifo.deq;
        if (isValid(m2w.eInst)) begin
            let eInst = fromMaybe(?, m2w.eInst);
            if(eInst.iType == Ld) begin
                eInst.data <- dMem.resp;
            end
            if(isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
            $display("[writeback] PC = %x", m2w.pc);
        end else begin
            $display("[writeback] epoch mismatch. PC = %x", m2w.pc);
        end
	endrule
    
    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        // $display("Start at pc 200\n");
        // $fflush(stdout);
        pcReg[0] <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

