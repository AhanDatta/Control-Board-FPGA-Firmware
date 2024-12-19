//clk is input clock, sampling clock
//FCO is a ready signal
//DCO is clk * 12 (resolution), data is clocked out ddr on DCO


//differential -> single-ended for DCO, VINA,B,C,D
//ddr shift reg/SERDES clocked on DCO
// - SERDES does deserialization automatically into bytes
// - then use "gearbox" to turn bytes into 12bit words, at relative frequency
//then put into FIFO (with a trigger)