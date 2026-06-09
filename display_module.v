module bin2bcd(
    input  wire       clk,
    input  wire [7:0] bin,
    output reg  [7:0] bcd,
    output reg        done
);
    reg [15:0] shift = 16'd0;
    reg [4:0]  cnt   = 4'd0;
    reg        busy  = 1'b0;

    always @(posedge clk) begin
        done <= 1'b0;
        if (!busy) begin
            shift={8'b0, bin};
            cnt=3'd0;
            busy<= 1'b1;
        end else begin
            if (shift[11:8]>=5)shift[11:8]=shift[11:8]+3;
            if (shift[15:12]>=5)shift[15:12]=shift[15:12]+3;
            shift = shift << 1;
            cnt   = cnt + 1;
            if (cnt == 8) begin
                busy <= 1'b0;
                bcd  <= shift[15:8];
                done <= 1'b1;
            end
        end
    end
endmodule

module seg14(
    input wire [7:0] digit,
    output reg  [13:0] seg
);
    always @(*) begin
        case (digit[7:4])
            4'd0: seg[13:7] = 7'b1000000; 
            4'd1: seg[13:7] = 7'b1111001; 
            4'd2: seg[13:7] = 7'b0100100; 
            4'd3: seg[13:7] = 7'b0110000; 
            4'd4: seg[13:7] = 7'b0011001; 
            4'd5: seg[13:7] = 7'b0010010; 
            4'd6: seg[13:7] = 7'b0000010; 
            4'd7: seg[13:7] = 7'b1111000;  
            4'd8: seg[13:7] = 7'b0000000;  
            4'd9: seg[13:7] = 7'b0010000;  
            default: seg[13:7] = 7'b1111111;
        endcase
        case (digit[3:0])
            4'd0: seg[6:0] = 7'b1000000; 
            4'd1: seg[6:0] = 7'b1111001; 
            4'd2: seg[6:0] = 7'b0100100; 
            4'd3: seg[6:0] = 7'b0110000; 
            4'd4: seg[6:0] = 7'b0011001; 
            4'd5: seg[6:0] = 7'b0010010; 
            4'd6: seg[6:0] = 7'b0000010; 
            4'd7: seg[6:0] = 7'b1111000;  
            4'd8: seg[6:0] = 7'b0000000;  
            4'd9: seg[6:0] = 7'b0010000;  
            default: seg[6:0] = 7'b1111111;
        endcase
        seg=~seg;
    end
endmodule

module display(
    input wire clk,
    input wire [7:0] now_hr,
    input wire [7:0] now_mn,
    input wire K,
    output reg [13:0] seg
);
    wire [7:0] hour_bcd, min_bcd;
    bin2bcd u_bcd_hr(.clk(clk), .bin(now_hr), .bcd(hour_bcd));
    bin2bcd u_bcd_mn(.clk(clk), .bin(now_mn), .bcd(min_bcd));
    
    wire [7:0] cur_digit = ~K ? hour_bcd : min_bcd;
    wire [13:0] seg_out;

    seg14 u_seg(.digit(cur_digit), .seg(seg_out));

    always @(posedge clk) begin
        seg <= seg_out;
    end
endmodule