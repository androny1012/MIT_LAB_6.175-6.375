import CacheTypes::*;
import MemUtil::*;
import Fifo::*;
import Vector::*;
import Types::*;
import CMemTypes::*;

module mkTranslator(WideMem wideMem, Cache ifc);

    Fifo#(2, MemReq) reqFifo <- mkCFFifo;

    method Action req(MemReq r);
        if ( r.op == Ld ) reqFifo.enq(r);
        wideMem.req(toWideMemReq(r));
    endmethod

    method ActionValue#(MemResp) resp;
        let req = reqFifo.first;
        reqFifo.deq;

        let cacheLine <- wideMem.resp;
        // 实际还是访存
        CacheWordSelect offset = truncate(req.addr >> 2);
        
        return cacheLine[offset];
    endmethod
endmodule

typedef enum {
    Ready,
    StartMiss, 
    SendFillReq, 
    WaitFillResp 
} ReqStatus deriving ( Bits, Eq );

//direct-mapped, write-miss allocate, writeback
module mkCache(WideMem wideMem, Cache ifc);

    // Cache数据大表
    Vector#(CacheRows, Reg#(CacheLine)) dataArray <- replicateM(mkRegU);
    // Tag表
    Vector#(CacheRows, Reg#(Maybe#(CacheTag))) tagArray <- replicateM(mkReg(tagged Invalid));
    // Dirty表
    Vector#(CacheRows, Reg#(Bool)) dirtyArray <- replicateM(mkReg(False));
    
    // Fifo#(1, Data) hitQ <- mkBypassFifo;
    Fifo#(1, Data) hitQ <- mkPipelineFifo;
    Reg#(MemReq) missReq <- mkRegU;
    Reg#(ReqStatus) mshr <- mkReg(Ready);

    // Fifo#(2, MemReq) memReqQ <- mkCFFifo;
    // Fifo#(2, MemResp) memRespQ <- mkCFFifo;

    
    // log2(16*32/8) = 6
    function CacheIndex getIndex(Addr addr) = truncate(addr >> 6);
    // log2(32/8) = 2
    function CacheWordSelect getOffset(Addr addr) = truncate(addr >> 2);
    function CacheTag getTag(Addr addr) = truncateLSB(addr);

    rule startMiss(mshr == StartMiss);
        let idx = getIndex(missReq.addr);
        let tag = tagArray[idx];
        let dirty = dirtyArray[idx];

        // 如果当前cache中要操作的cacheline有效，但dirty，就要先更新进去
        // 有效为什么要更新呢？因为能到这里 输入的tag 与 当前index的tag不匹配
        // 所以先更新这里的dirty data，写入mem('1 为全1)
        if (isValid(tag) && dirty) begin
            let addr = {fromMaybe(?, tag), idx, 6'b0}; 
            let data = dataArray[idx];
            wideMem.req(WideMemReq {write_en: '1, addr: addr, data: data});
        end

        mshr <= SendFillReq;   
    endrule
    
    rule sendFillReq(mshr == SendFillReq);
        // Fill missing Line
        // Q: 两个周期发起了两次mem请求，有问题吗？
        // 上一周期是写，这一周期是读，而且必定不是同一个地址
        // 因为如果是的话 就hit了
        // 这样一次cache fill完成后，既完成了取值又完成了dirty data upd
        
        WideMemReq wideMemReq = toWideMemReq(missReq);
        // 不管怎么说先读出来
        wideMemReq.write_en = 0;
        wideMem.req(wideMemReq);

        mshr <= WaitFillResp;
    endrule
    
    rule waitFillResp(mshr == WaitFillResp);
        let idx = getIndex(missReq.addr);
        let tag = getTag(missReq.addr);
        let wOffset = getOffset(missReq.addr);
        let data <- wideMem.resp;
        tagArray[idx] <= tagged Valid tag;

        if(missReq.op == Ld) begin 
            // 热乎(x)干净的数据 
        	dirtyArray[idx] <= False;
        	dataArray[idx] <= data;
        	hitQ.enq(data[wOffset]); 
        end else begin
            // 实际上是读了mem的内容，然后往里写
            // 考虑的是刚写的内容，容易读？
            // 只有再这个写入的数据tag被替代时才真正更新mem的内容
            dirtyArray[idx] <= True;
        	data[wOffset] = missReq.data; 
        	dataArray[idx] <= data;
        end     
        
        mshr <= Ready;
    endrule
    
    // 初始为ready
    method Action req(MemReq r) if (mshr == Ready);
        let idx = getIndex(r.addr); 
        let tag = getTag(r.addr);
        let wOffset = getOffset(r.addr);
        let currTag = tagArray[idx]; 
        let hit = isValid(currTag) ? fromMaybe(?, currTag) == tag : False;

        if ( hit ) begin
        	let cacheLine = dataArray[idx];
        	if ( r.op == Ld ) hitQ.enq(cacheLine[wOffset]);
        	else begin
        	    cacheLine[wOffset] = r.data;
        	    dataArray[idx] <= cacheLine;
        		dirtyArray[idx] <= True;
        	end
        end else begin
        	missReq <= r;
        	mshr <= StartMiss;
        end
    endmethod
    
    method ActionValue#(Data) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod
    
endmodule


//direct-mapped, write-miss allocate, writeback
module mkCacheGroup(WideMem wideMem, Cache ifc);

    // Cache数据大表，按组拆分
    Vector#(CacheGroups, Vector#(CacheGroupRows, Reg#(CacheLine))) dataArray <- replicateM(replicateM(mkRegU));
    // Tag表
    Vector#(CacheGroups, Vector#(CacheGroupRows, Reg#(Maybe#(CacheGroupTag)))) tagArray <- replicateM(replicateM(mkReg(tagged Invalid)));
    // Dirty表
    Vector#(CacheGroups, Vector#(CacheGroupRows, Reg#(Bool))) dirtyArray <- replicateM(replicateM(mkReg(False)));
    
    // Fifo#(1, Data) hitQ <- mkBypassFifo;
    Fifo#(1, Data) hitQ <- mkPipelineFifo;
    Reg#(MemReq) missReq <- mkRegU;
    Reg#(CacheGroupIndex) emptyGroup <- mkRegU;
    Reg#(ReqStatus) mshr <- mkReg(Ready);

    // Fifo#(2, MemReq) memReqQ <- mkCFFifo;
    // Fifo#(2, MemResp) memRespQ <- mkCFFifo;

    
    // log2(16*32/8) = 6
    // CacheIndex 2bit
    // 这俩是定的，因为ddr是512bit，指令数据是32bit

    function CacheGIndex getIndex(Addr addr) = truncate(addr >> 6);

    // log2(32/8) = 2
    // CacheWordSelect  4bit
    function CacheWordSelect getOffset(Addr addr) = truncate(addr >> 2);

    // tag 24bit(位数不定)
    function CacheGroupTag getTag(Addr addr) = truncateLSB(addr);

    rule startMiss(mshr == StartMiss);
        // 这里的idx的输入req的idx
        // tag是表里的idx对应的tag
        // 这个tag如果是dirty就要更新
        
        let idx = getIndex(missReq.addr);
        // let tag = tagArray[idx];
        // let dirty = dirtyArray[idx];
        Maybe#(CacheGroupTag) dirtyTag = tagged Invalid;
        CacheGroupIndex dirtyGroup = ?;
        Bool dirtyHit = False;

        // CacheGroupIndex tempGroup = fromInteger(valueOf(CacheGroups) - 1);
        CacheGroupIndex tempGroup = fromInteger(0);
        // 这里可以用LRU,如果没有空的,就用LRU选择
        
        // for( Integer i = 0 ; i < valueOf(CacheGroups) ; i = i+1 ) begin
        for( Integer i = valueOf(CacheGroups) - 1 ; i >= 0  ; i = i-1 ) begin
            let tag = tagArray[fromInteger(i)][idx]; 
            let dirty = dirtyArray[fromInteger(i)][idx]; 
            
            if(isValid(tag) && dirty) begin
                dirtyHit = True;
                dirtyTag = tag;
                dirtyGroup = fromInteger(i);
            end
            if(!isValid(tag)) begin
                // 如果有空的group，就写到那
                // 没有空的就是默认0
                tempGroup = fromInteger(i);
            end
        end
        emptyGroup <= tempGroup;
        
        // 如果当前cache中要操作的cacheline有效，但dirty，就要先更新进去
        // 有效为什么要更新呢？因为能到这里 输入的tag 与 当前index的tag不匹配
        // 所以先更新这里的dirty data，写入mem('1 为全1)

        // 组相连会有更新所有dirty的需求，但req只能发送一个，这会不会是性能降低的原因
        // 不会，因为dirty只是说明需要更新到mem中
        // 而性能问题是miss的次数多了
        // dirty应该是在多核之间要用到，单核还用不到
        if (dirtyHit) begin
            let addr = {fromMaybe(?, dirtyTag), idx, 6'b0}; 
            let data = dataArray[dirtyGroup][idx];
            wideMem.req(WideMemReq {write_en: '1, addr: addr, data: data});
        end

        mshr <= SendFillReq;   
    endrule
    
    rule sendFillReq(mshr == SendFillReq);
        // Fill missing Line
        // Q: 两个周期发起了两次mem请求，有问题吗？
        // 上一周期是写，这一周期是读，而且必定不是同一个地址
        // 因为如果是的话 就hit了
        // 这样一次cache fill完成后，既完成了取值又完成了dirty data upd
        
        WideMemReq wideMemReq = toWideMemReq(missReq);
        // 不管怎么说先读出来
        wideMemReq.write_en = 0;
        wideMem.req(wideMemReq);

        mshr <= WaitFillResp;
    endrule
    
    rule waitFillResp(mshr == WaitFillResp);
        // tag是地址对应的tag，还没进表里

        let idx = getIndex(missReq.addr);
        // idx应该写到哪？
        // 一个idx对应多个group
        // 优先写入 invalid的
        let grp = emptyGroup;
        let tag = getTag(missReq.addr);
        let wOffset = getOffset(missReq.addr);
        let data <- wideMem.resp;
        tagArray[grp][idx] <= tagged Valid tag;

        if(missReq.op == Ld) begin 
            // 热乎(x)干净的数据 
        	dirtyArray[grp][idx] <= False;
        	dataArray[grp][idx] <= data;
        	hitQ.enq(data[wOffset]); 
        end else begin
            // 实际上是读了mem的内容，然后往里写
            // 考虑的是刚写的内容，容易读？
            // 只有再这个写入的数据tag被替代时才真正更新mem的内容
            dirtyArray[grp][idx] <= True;
        	data[wOffset] = missReq.data; 
        	dataArray[grp][idx] <= data;
        end     
        
        mshr <= Ready;
    endrule
    
    // 初始为ready
    method Action req(MemReq r) if (mshr == Ready);
        // 根据访问的地址，得到index，一个index实际上对应多组cache line
        let idx = getIndex(r.addr); 
        // 访问地址和tag一一对应
        let tag = getTag(r.addr);
        let wOffset = getOffset(r.addr);

        Bool hit = False;
        CacheGroupIndex realGroup = ?;

        // 同时比较index对应的多组cache line 只要有一组有就是hit
        for( Integer i = 0 ; i < valueOf(CacheGroups) ; i = i+1 ) begin
            let currTag = tagArray[fromInteger(i)][idx]; 
            let hitTemp = isValid(currTag) ? fromMaybe(?, currTag) == tag : False;
            if(hitTemp) begin
                hit = True;
                realGroup = fromInteger(i);
            end
        end

        if ( hit ) begin
            let cacheLine = dataArray[realGroup][idx];
            if ( r.op == Ld ) hitQ.enq(cacheLine[wOffset]);
            else begin
                cacheLine[wOffset] = r.data;
                dataArray[realGroup][idx] <= cacheLine;
                dirtyArray[realGroup][idx] <= True;
            end
        end else begin
            missReq <= r;
            mshr <= StartMiss;
        end        
    endmethod
    
    method ActionValue#(Data) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod
    
endmodule