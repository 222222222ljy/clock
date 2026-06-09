module top(clk_sys,K,seq,clk,dig);
    parameter freq=12000000;
    parameter HR=24,MN=60,SE=60;
    
    input wire clk_sys;
    input wire [3:0]K;
    
    wire [1:0] val=K[1:0];
    
    wire upo_mn,upo_hr,upi_mn,upi_hr;
    wire [1:0] val_hr=(K[3]==1'b0)?val:2'b11;
    wire [1:0] val_mn=(K[3]==1'b1)?val:2'b11;
    wire [1:0] val_se=2'b11;
    wire [7:0] now_mn,now_hr,now_se;
    
    output wire clk;
    wire secs;
    
    clock_timer clock_se(.div(freq),.clk(clk_sys),.upo(clk));
    clock_timer sec(.div(freq),.clk(clk_sys),.upo(secs));
    
    clock_number se(.val(vel_se),.term(SE),
        .upi(secs),.upo(upi_mn),
        .now(now_se),clk_sys(clk_sys));
    
    clock_number mn(.val(val_mn),.term(MN),
        .upi(upi_mn),.upo(upo_mn),
        .now(now_mn),.clk_sys(clk_sys));
    
    clock_number hr(.val(val_hr),.term(HR),
        .upi(upo_mn),.upo(upo_hr),
        .now(now_hr),.clk_sys(clk_sys));
        
    output wire [13:0] seq;
    output wire [1:0] dig;
    assign dig=2'b00;
    
    display dis(.clk(clk_sys),.now_hr(now_hr),.now_mn(now_mn),.K(K[3]),.seg(seq));
    
endmodule