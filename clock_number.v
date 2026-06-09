module clock_number(val,term,upi,upo,now,clk_sys);
    parameter freq=12000000;

    input wire clk_sys;
    input wire [1:0] val;
    input wire [7:0] term;
    input wire upi;
    output reg upo=0;
    output reg [7:0] now=0;

    reg upil;
    
    always @(posedge clk_sys)begin
        upo=1'b0;
        if(val==2'b11)begin
            if(upi==1 && upil==0)now=now+1;
        end
        else if(val==2'b10)now=now+1;
        else if(val==2'b01)now=now-1;
        if(now==term)begin
            if(val==2'b11)upo=~upo;
            now=0;
        end
        else if(now==255)now=term-1;
        upil=upi;
    end
endmodule

module clock_timer(div,clk,upo);
    input wire [31:0] div;
    input wire clk;
    output reg upo=1'b0;
    reg [31:0] cnt=0;
    always @(posedge clk)begin 
        cnt=cnt+1'b1;
        if(cnt==div)begin
            upo=~upo;
            cnt=0;
        end
        else if(cnt==div/2)upo=~upo;
    end
endmodule