import CMemTypes::*;
import Types::*;
import Vector::*;

// 16条指令/16个32bit数据
typedef 16 CacheLineWords; // to match DDR3 width
// 64 * 8 个byte
typedef TMul#(CacheLineWords, 4) CacheLineBytes;
// 总共 8 line
typedef 32 CacheRows; // small size to improve compile times
typedef 4 CacheGroups; 
typedef TDiv#(CacheRows,CacheGroups) CacheGroupRows; 

// ( ((32 - 2) - 4) - 3 ) = 23bit tag
// |       23bit tag        |   3bit index |    4bit offset | 2bit |
typedef Bit#( TSub#(TSub#(TSub#(AddrSz, 2), TLog#(CacheLineWords)), TLog#(CacheRows)) ) CacheTag;
// |       24bit tag        |   2bit index |    4bit offset | 2bit |  2 Groups
// |       25bit tag        |   1bit index |    4bit offset | 2bit |  4 Groups
// |       26bit tag        |   0bit index |    4bit offset | 2bit |  8 Groups  全相连
typedef Bit#( TSub#(TSub#(TSub#(AddrSz, 2), TLog#(CacheLineWords)), TLog#(TDiv#(CacheRows,CacheGroups))) ) CacheGroupTag;
// CacheLine Index
typedef Bit#( TLog#(CacheRows) ) CacheIndex;
typedef Bit#( TLog#(TDiv#(CacheRows,CacheGroups)) ) CacheGIndex;
typedef Bit#( TLog#(CacheGroups) ) CacheGroupIndex;
// Line内 index
typedef Bit#( TLog#(CacheLineWords) ) CacheWordSelect;
// Line内 切分为vector
typedef Vector#(CacheLineWords, Data) CacheLine;

// Wide memory interface
// This is defined here since it depends on the CacheLine type
typedef struct{
    Bit#(CacheLineWords) write_en;  // Word write enable
    Addr                 addr;
    CacheLine            data;      // Vector#(CacheLineWords, Data)
} WideMemReq deriving(Eq,Bits);

typedef CacheLine WideMemResp;
interface WideMem;
    method Action req(WideMemReq r);
    method ActionValue#(CacheLine) resp;
endinterface

// Interface just like FPGAMemory (except no MemInit)
interface Cache;
    method Action req(MemReq r);
    method ActionValue#(MemResp) resp;
endinterface

