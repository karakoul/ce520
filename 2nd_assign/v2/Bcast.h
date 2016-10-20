
 enum {
   TIMER_PERIOD_MILLI = 1000,
   AM_ID = 20,
   MAX_ARRAY_SIZE = 2
   //20-29 channels
 };

typedef nx_struct bcastMsg {
  nx_uint16_t nodeid;
  nx_uint16_t seq_num;
} msg_t;

 
