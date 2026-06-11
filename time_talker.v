module tik(clk_sys,in,num,out,K);
    //clk 时钟,in输入触发,num次数,out输出,K是模式
    parameter freq=12000000;

    input wire clk_sys;
    input wire in;
    input wire [6:0] K;
    input wire [7:0] num;
    output reg [5:0] out; 
    
    reg inl=0;
    reg [5:0] res=0;
    reg [26:0] now=0;
    always @(posedge clk_sys)begin
        if(in==1&&inl==0)res=num;
        if(res>0)begin
            now=now+1;
            if(now==freq/2)out=63;
            if(now==freq)begin
                out=K;
                res=res-1;
                now=0;
            end
        end
        else out=K;
        inl=in;
    end
endmodule
    
module mode_change(K,out,clk_sys);
    input wire K;
    input wire clk_sys;
    output reg [5:0] out=0;
    always @(posedge clk_sys)begin
        if(K==0)out=out+1;
        if(out==63)out=0;
    end
endmodule