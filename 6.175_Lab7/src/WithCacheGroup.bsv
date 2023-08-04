// SixStageBHT.bsv
//
// This is a six stage implementation of the RISC-V processor

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
// import IMemory::*;
// import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;
// import FPGAMemory::*;
import Bht::*;

import Memory::*;
import SimMem::*;
import ClientServer::*;
import CacheTypes::*;
import WideMemInit::*;
import MemUtil::*;
import Cache::*;

typedef struct {
    Addr pc;
    Addr predPc;
    Bool decEpoch;
    Bool regEpoch;
    Bool exeEpoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool regEpoch;
    Bool exeEpoch;
} Decode2Regfile deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool exeEpoch;
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

// (* synthesize *)
module mkProc#(Fifo#(2, DDR3_Req) ddr3ReqFifo, Fifo#(2, DDR3_Resp) ddr3RespFifo)(Proc);
    Ehr#(4, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
    Scoreboard#(6)   sb <- mkCFScoreboard;
    // IMemory  iMem <- mkIMemory;
    // DMemory  dMem <- mkDMemory;
    // FPGAMemory iMem <- mkFPGAMemory;
    // FPGAMemory dMem <- mkFPGAMemory;
    CsrFile        csrf <- mkCsrFile;

    Btb#(6)         btb <- mkBtb; 
    Bht#(8)         bht <- mkBht;
    
    Reg#(Bool) decEpoch <- mkReg(False);
    Reg#(Bool) regEpoch <- mkReg(False);
    Reg#(Bool) exeEpoch <- mkReg(False);

    // FIFO between two stages
    Fifo#(6, Fetch2Decode)     f2dFifo <- mkCFFifo;
    Fifo#(6, Decode2Regfile)   d2rFifo <- mkCFFifo;
    Fifo#(6, Regfile2Execute)  r2eFifo <- mkCFFifo;
	Fifo#(6, Execute2Memory)   e2mFifo <- mkCFFifo;
	Fifo#(6, Memory2WriteBack) m2wFifo <- mkCFFifo;

    Bool memReady = True;
    WideMem           wideMemWrapper <- mkWideMemFromDDR3( ddr3ReqFifo, ddr3RespFifo );
    Vector#(2, WideMem)     wideMems <- mkSplitWideMem( memReady && csrf.started, wideMemWrapper );
    Cache iMem <- mkCacheGroup(wideMems[1]);
    Cache dMem <- mkCacheGroup(wideMems[0]);

    // fetch stage
    rule doFetch(csrf.started);
        // fetch
        iMem.req(MemReq { op: Ld, addr: pcReg[0], data: ? });
        Addr predPc = btb.predPc(pcReg[0]);

        Fetch2Decode f2d = Fetch2Decode {
            pc: pcReg[0],
            predPc: predPc,
            decEpoch : decEpoch,
            regEpoch : regEpoch,
            exeEpoch : exeEpoch
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
        if (f2d.decEpoch != decEpoch || f2d.exeEpoch != exeEpoch || f2d.regEpoch != regEpoch) begin
            $display("[decode   ] PC = %x, expanded = (killed)", f2d.pc, showInst(inst));
        end
        else begin
            DecodedInst dInst = decode(inst);

            let predPc = (dInst.iType == J || dInst.iType == Br) ? bht.ppcDP(f2d.pc, f2d.pc + fromMaybe(?, dInst.imm)) : f2d.predPc;

            if (f2d.predPc != predPc) begin
                decEpoch <= !decEpoch;
                pcReg[1] <= predPc;
                $display("[decode ] PC = %x, predPc = %x", f2d.pc, predPc);
            end

            Decode2Regfile d2r = Decode2Regfile {
                pc: f2d.pc,
                predPc: predPc,
                dInst : dInst,
                regEpoch : f2d.regEpoch,
                exeEpoch : f2d.exeEpoch
            };

            d2rFifo.enq(d2r);
            $display("[decode   ] PC = %x, expanded = ", f2d.pc, showInst(inst));
        end
        f2dFifo.deq;

    endrule

    // reg read stage
    rule doRegfile(csrf.started);
        let d2r = d2rFifo.first;
        let dInst = d2r.dInst;

        // reg read
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));


        if (d2r.exeEpoch != exeEpoch || d2r.regEpoch != regEpoch) begin
            d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
            $display("[register ] PC = %x (killed)", d2r.pc);
        end
        else if(!sb.search1(dInst.src1) && !sb.search2(dInst.src2)) begin

            let predPc = (dInst.iType == Jr) ? {truncateLSB(rVal1 + fromMaybe(?, dInst.imm)), 1'b0} : d2r.predPc;
            // 这里就算预测错了，也不需要不传给EXE级，因为这里不算预测错
            // 只是出现了更好的预测结果，具体是否接收预测，就看EXE，所以还是往下传
            // 这里的处理就是有更好的预测结果时，让前面重新处理新的指令
            // 一旦下一级的exeEpoch变化，最终还是要全部flush
            if (d2r.predPc != predPc) begin
                regEpoch <= !regEpoch;
                pcReg[2] <= predPc;
                $display("[register ] PC = %x, predPc = %x + %x", d2r.pc, rVal1, fromMaybe(?, dInst.imm));
            end

            // data to enq to FIFO
            Regfile2Execute r2e = Regfile2Execute {
                pc: d2r.pc,
                predPc: predPc,
                dInst: dInst,
                rVal1: rVal1,
                rVal2: rVal2,
                csrVal: csrVal,
                exeEpoch : d2r.exeEpoch
            };

            sb.insert(dInst.dst);
            r2eFifo.enq(r2e);
            d2rFifo.deq; // 只有不stall在deq，否则恢复时就没了数据
            $display("[register ] PC = %x", d2r.pc);
        end
        else begin
            $display("[register ] PC = %x (stalled)", d2r.pc);
        end
    endrule

    // exe stage
    rule doExecute(csrf.started);
        let r2e = r2eFifo.first;
    
        Maybe#(ExecInst) neweInst = Invalid;

        if(r2e.exeEpoch != exeEpoch) begin
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
            // 是在 mispredict 后更新btb还是只要跳转就更新btb?

            // if (eInst.iType == J || eInst.iType == Jr || eInst.iType == Br) begin
            //     btb.update(r2e.pc, eInst.addr);
            // end
            if (eInst.iType == J || eInst.iType == Br) begin
                bht.update(r2e.pc, eInst.brTaken);
            end
            if (eInst.mispredict) begin
                pcReg[3] <= eInst.addr;
                exeEpoch <= !exeEpoch;
                btb.update(r2e.pc, eInst.addr);
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

    endrule

    // mem stage
    rule doMemory(csrf.started);
        let e2m = e2mFifo.first;
        
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
        m2wFifo.deq;
        if (isValid(m2w.eInst)) begin
            let eInst = fromMaybe(?, m2w.eInst);
            if(eInst.iType == Ld) begin
                eInst.data <- dMem.resp;
            end
            if(isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
                $display("[writeback] PC = %x, RINDEX = %x, DATA = %x", m2w.pc, eInst.dst, eInst.data);
            end
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
            $display("[writeback] PC = %x", m2w.pc);
        end else begin
            $display("[writeback] epoch mismatch. PC = %x", m2w.pc);
        end
        sb.remove;
	endrule

    rule drainMemResponses( !csrf.started );
		ddr3RespFifo.deq;
	endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady && !ddr3RespFifo.notEmpty );
        csrf.start(0); // only 1 core, id = 0
        // $display("Start at pc 200\n");
        // $fflush(stdout);
        pcReg[0] <= startpc;
    endmethod

endmodule

